# Stored procedures

This directory is the Git source of truth for stored procedures. Each procedure
is a top-level `<procedure_name>.sql` file with this executable envelope:

```sql
DROP PROCEDURE IF EXISTS `procedure_name`//
CREATE DEFINER=CURRENT_USER PROCEDURE `procedure_name`(...)
SQL SECURITY DEFINER
BEGIN
  -- procedure body
END//
```

Use the `db-workbench` TUI to synchronize PROD procedures into this directory
and LOCAL, then create an ignored `.worktrees/<name>` task worktree. Inspect
data and validate query logic as SQL before writing the procedure.

For automated cases, add an isolated suite in
`tests/<procedure_name>/`:

```text
tests/<procedure_name>/
  fixture.sql
  source-checks.sql    # optional one-boolean read-only checks against PROD
  prod-fixture.sql      # optional privacy-filtered rows staged from PROD
  cases/
    001_case_name/
      before.sql
      call.sql
      after.sql
      reset.sql
```

Use assertions that fail the MariaDB client when a condition is false; a
successful `SELECT` that merely prints an unexpected value does not fail a test.
For example, `fixture.sql` can define a small assertion routine:

```sql
DELIMITER //
CREATE PROCEDURE assert_true(IN passed BOOLEAN, IN message VARCHAR(255))
BEGIN
  IF NOT passed THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = message;
  END IF;
END//
DELIMITER ;
```

Then `before.sql` and `after.sql` can call it with scalar checks, and a failing
assertion stops the suite with MariaDB's error.

The runner first executes optional `source-checks.sql` statements against PROD.
Each statement must be read-only, query the configured PROD database, and
return exactly one boolean value that is true. A false result stops the suite
before procedure tests and is reported as possible source drift or a stale
check. The runner then creates one disposable schema on the existing LOCAL
MariaDB server, creates a temporary account limited to that schema, executes
`fixture.sql` once, optionally runs `prod-fixture.sql`, then runs each case in
directory-name order. The four case scripts run in order; `reset.sql` restores
the baseline before the next case. A failed
stage stops the suite. The runner removes the disposable schema and temporary
account whether the suite passes or fails. The configured LOCAL account needs
permission to create/drop schemas and temporary accounts. Fixture setup must
use synthetic rows and must not reference configured PROD or LOCAL schemas.
Known schema qualifiers in the procedure and case scripts are redirected to
the fixture schema.

For aggregation cases that need representative source rows, `prod-fixture.sql`
may contain one or more hybrid inserts in the form
`INSERT INTO local.<fixture_table> (columns...) SELECT ... FROM prod.<table>`.
The runner uses the configured PROD read-only credential and existing privacy
policy, streams results into the disposable schema through its restricted test
account, and stores no query output or extract file. Targets must use the
`local.` virtual qualifier and list columns; source relations may use `prod.`
or an unqualified table name from the configured PROD database. Source-backed
expected values can change when PROD changes; inspect the source query and its
assumptions when a test fails before labeling it a regression or updating the
expected result.

After the fixture suite passes, install the candidate procedures into configured
LOCAL for interactive review. Optional LOCAL smoke tests live in
`tests/<procedure_name>.sql`. Then commit and push the task branch, review its
pull request, explicitly deploy the reviewed worktree to PROD, and use the
Delivery runner for the separate squash-merge approval.

The repository root stays on `main`; `.worktrees/` is temporary and must never
be committed.
