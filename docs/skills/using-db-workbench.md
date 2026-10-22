# BI workflows

## Query contexts

```powershell
db prod "SELECT column_a, column_b FROM schema.table WHERE ..."
db local "SELECT column_a, column_b FROM schema.table WHERE ..."
```

`prod` queries the current database with the configured read-only credential. `local` queries the sanitized MariaDB snapshot. Local results can include a freshness advisory when the snapshot is behind PROD.

Use hybrid mode when the operation needs explicit context routing:

```powershell
db hybrid "SELECT * FROM local.some_table"
db hybrid "INSERT INTO target_table SELECT ... FROM source_table"
```

In hybrid SQL, unqualified read relations default to PROD and mutation targets default to LOCAL. Explicit mixed PROD/LOCAL SELECTs may be rejected when the tool cannot preserve their semantics.

## Results and exports

Every SELECT is buffered and previewed at 20 rows.

```powershell
db expand
db expand --full
db expand --csv "C:\\path\\result.csv"
```

`--csv` exports the complete buffered result, including the previewed rows.

## Refreshing local data

```powershell
db refresh <table>
db refresh <table> YYYY-MM-DD YYYY-MM-DD
```

Inspect actual data before writing or reviewing a procedure. Start with `db prod` or `db hybrid` to understand current PROD rows and validate the intended query logic as SQL before converting it into a stored procedure. Prefer PROD for expensive calculations; use LOCAL when fast data transfer and iteration matter. PROD remains read-only.

After validating the query logic, install the task worktree's procedure definitions into LOCAL and test them there. Inspect results in LOCAL or DBeaver as needed; passing a smoke test alone does not establish that the procedure handles meaningful data correctly.

Use the isolated procedure fixture suite for repeatable automated cases. Inspect realistic combinations in PROD or LOCAL, then encode only the minimal synthetic rows needed in `fixture.sql`; do not copy query output or production extracts into the repository. For aggregation tests that need current source rows, optional `prod-fixture.sql` can use explicit hybrid inserts such as `INSERT INTO local.fixture_table (columns...) SELECT ... FROM prod.source_table`. The runner streams PROD results through the configured privacy policy into the disposable fixture schema; it never writes these rows to configured LOCAL or saves an extract. Optional `source-checks.sql` can assert one-boolean invariants against PROD before procedure tests; failures identify a source-drift or stale-check issue separately. Record assumptions that depend on observed data because PROD-backed expectations can drift.

LOCAL is sanitized and may be stale. Check freshness advisories and refresh only the needed table or date range with `db refresh` or the TUI's targeted refresh actions. A full sandbox rebuild is expensive; do not use it as the default response to stale test data.

## GitHub change lifecycle

Create SQL and documentation changes in the repository's `.worktrees` directory from an up-to-date `main`. Before delivery, run `git -C .\.worktrees\<name> merge main`. Accept fast-forwards and non-conflicting automatic resolutions. Resolve conflicts semantically by checking SQL, model meaning, and usage docs together, then repeat the relevant local data checks.

Commit and push the task branch, create or open its pull request, and review the diff. Do not merge the task branch or push task changes directly to `main` from the repository root. For stored procedures, install and test the candidate in LOCAL, review its behavior, deploy the reviewed worktree to PROD with the explicit `DEPLOY` confirmation, then start the db-workbench Delivery runner and choose squash merge. Deployment and merge are separate actions; follow the deploy-before-merge order.

After the runner merges the PR, return to the TUI. It refreshes `origin/main` and automatically closes the clean worktree and local branch, including after squash merges. It handles Windows read-only directory attributes after the clean-state check. A change is not complete while its task worktree remains below `.worktrees`.

## Foreground delivery runner

The db-workbench main menu's Delivery runner is shared by both repositories:

1. Select `db-report` or `db-workbench`, then select the task worktree.
2. The TUI opens the foreground runner in a new Windows Terminal tab through
   the existing WT launcher. Starting the runner is the human approval point.
3. Inspect the PR conversation and complete diff in the runner. Choose squash
   merge, open the PR in a browser, hand the change back to Codex with a
   comment, or leave it open.
4. Handbacks try the originating `CODEX_SESSION_ID`, then `codex resume
   --last`, and finally a new Codex session. Failed merges and merge conflicts
   use the same handback path.

After a successful squash merge, the runner refreshes `origin/main` and closes
the clean task worktree. Return to the TUI to fast-forward its repository-root
`main` and finish automatic cleanup.

## Stored-procedure deployment

`db-workbench` is the TUI for this repository. Its Stored procedure development
menu drives the first Git-backed database-object workflow:

1. Create a task worktree below `.worktrees/` from the clean repository-root `main`.
2. Inspect representative PROD and LOCAL rows. Validate expensive query logic
   with `db prod` or `db hybrid` before wrapping it as a procedure.
3. Add an isolated fixture suite under
   `procedures/tests/<procedure_name>/`. `fixture.sql` creates synthetic rows
   once. An optional `prod-fixture.sql` streams selected rows from PROD into
   fixture tables through the hybrid executor and the existing privacy policy.
   Optional `source-checks.sql` runs read-only PROD `SELECT` statements before
   the suite; each must return exactly one boolean value that is true.
   `prod-fixture.sql` statements must explicitly target
   `local.<fixture_table>`, list target columns, and read only the configured
   PROD database. Each `cases/<name>/`
   directory has `before.sql`, `call.sql`, `after.sql`, and `reset.sql`. The
   TUI runs cases in name order on one
   disposable schema and one existing LOCAL MariaDB server. Reset restores the
   baseline between cases; a failing stage stops the sequence and the schema
   and temporary schema-limited account are removed. The configured LOCAL
   account needs permission to create/drop schemas and temporary accounts.
4. Run the isolated fixture suite from the TUI. Setup SQL must target only the
   disposable schema and may not refer to configured PROD or LOCAL schemas.
   The runner redirects known PROD/LOCAL qualifiers in candidate procedure and
   case SQL to the disposable schema. The optional PROD fixture file is a
   separate read-only source path; only its hybrid `INSERT ... SELECT` writes
   are routed to the disposable schema. A false or stale source check stops
   before procedure tests; if checks pass and a procedure assertion fails,
   inspect the candidate and expected results. Failures in source-backed assertions
   may reflect procedure regressions or changed PROD data, so inspect the query
   and source assumptions before changing expected values.
5. Install the task worktree's procedures into configured LOCAL. Run any
   LOCAL smoke test and inspect actual results, including in DBeaver when
   useful. Optional LOCAL smoke-test SQL belongs in
   `procedures/tests/<procedure_name>.sql`.
6. Commit and push the procedure worktree from the TUI.
7. Review the diff and create or open the pull request.
8. After LOCAL review, type `DEPLOY` in the separate PROD deployment action.
   A successful deployment publishes an annotated `prod-procedure-deploy/...`
   receipt tag with the deployed source commit and per-procedure hashes.
9. Start the foreground Delivery runner as the human approval point and choose
   squash merge when ready.
10. Return to the TUI so it can refresh the repository and remove the clean
   procedure worktree and local branch.

The TUI refuses to sync or create a task worktree from a dirty root, refuses to
deploy uncommitted files, and uses a separate deployment credential rather than
the PROD read-only credential. Configure the report repository and deployment
credential in the db-workbench user configuration. If configured credentials
are unavailable, use the normal setup error. Never commit credentials, query
output, or production extracts. Dirty worktrees are never removed by automatic
cleanup.
