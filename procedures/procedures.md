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

## Procedure tests

Keep repeatable cases beside the procedure source in
`tests/<procedure_name>/`:

```text
tests/<procedure_name>/
  fixture.sql
  source-checks.sql    # optional checks for source-data assumptions
  prod-fixture.sql     # optional representative rows from PROD
  cases/
    001_case_name/
      before.sql
      call.sql
      after.sql
      reset.sql
```

Use small synthetic rows in `fixture.sql` to express behavior precisely. Each
case checks its starting conditions in `before.sql`, invokes the procedure in
`call.sql`, checks results in `after.sql`, and restores the baseline in
`reset.sql`. Assertions must fail when expectations are false; a `SELECT` that
only prints an unexpected value does not fail a test.

For aggregation cases that need realistic source rows, `prod-fixture.sql` may
select representative rows from PROD for a fixture. Do not commit query output
or production extracts. Source-backed expectations may change as PROD changes;
record the assumptions and inspect the source query when a test fails before
classifying it as a procedure regression. `source-checks.sql` may contain
read-only checks that each return a single true/false value; use these to make
important source-data assumptions explicit.

Optional interactive smoke tests against configured LOCAL live in
`tests/<procedure_name>.sql`. See the [db-workbench architecture guide](https://github.com/schmijob/db-workbench/blob/main/docs/architecture/architecture.md#procedure-fixture-suite)
for fixture-runner behavior and the [developer workflow](https://github.com/schmijob/db-workbench/blob/main/docs/skills/skills.md#stored-procedure-workflow)
for how to run tests and prepare a candidate. The agent-to-human handoff is
defined in this repository's `AGENTS.md`.
