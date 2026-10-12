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

Refresh only when the table's local data is known to be stale and the relevant workflow permits it. Use the data-model documentation to understand the table's freshness column and time range.

## GitHub change lifecycle

Create SQL and documentation changes in the repository's `.worktrees` directory from an up-to-date `main`. Before integration, run `git -C .\.worktrees\<name> merge main`. Accept fast-forwards and non-conflicting automatic resolutions. Resolve conflicts semantically by checking SQL, model meaning, and usage docs together.

From the main worktree, use `git merge --squash <branch>`, validate the result, commit, and `git push origin main`. The db-workbench TUI then refreshes `origin/main` and automatically closes every clean worktree whose branch is represented in `main`, including squash merges. It handles Windows read-only directory attributes after the clean-state check. A change is not complete while its task worktree remains below `.worktrees`.

For a manual fallback, verify `git fetch origin`, `git diff --exit-code main origin/main`, and `git status --short --branch` before `git worktree remove .\.worktrees\<name>`. A squash branch may require `git branch -D task/<name>` after those checks; use it only after the pushed `main` contains the change.

## Foreground delivery runner

The db-workbench main menu's Delivery runner is shared by both repositories:

1. Select `db-report` or `db-workbench`, then select any worktree. The
   repository-root `main` is included even when it is dirty.
2. The TUI commits dirty selected files with the supplied message, pushes the
   selected branch, and opens the foreground runner in a new Windows Terminal
   tab through the existing WT launcher.
3. Inspect the PR conversation and complete diff in the runner. Choose squash
   merge, open the PR in a browser, hand the change back to Codex with a
   comment, or leave it open.
4. Handbacks try the originating `CODEX_SESSION_ID`, then `codex resume
   --last`, and finally a new Codex session. Failed merges and merge conflicts
   use the same handback path.

After a successful squash merge, the runner refreshes `origin/main` and closes
the clean branch worktree. A dirty repository-root `main` is left untouched;
the remote ref verifies the merge.

## Stored-procedure deployment

`db-workbench` is the TUI for this repository. Its Stored procedure development
menu drives the first Git-backed database-object workflow:

1. Sync the stored procedures from PROD into `procedures/` and LOCAL.
2. Create a task worktree below `.worktrees/` from the clean repository-root `main`.
3. Edit the procedure file and run its LOCAL smoke test. A companion test, when
   needed, is `procedures/tests/<procedure_name>.sql`.
4. Commit and push the procedure worktree from the TUI; the foreground delivery
   runner opens automatically.
5. Review the PR conversation and `main...HEAD` diff in the runner.
6. After review, type `DEPLOY` to apply the committed procedure diff to PROD.
7. After the procedure PR reaches `main`, let the TUI automatically refresh the
   repository and remove the clean procedure worktree and local branch.

The TUI refuses to sync or create a task worktree from a dirty root, refuses to
deploy uncommitted files, and uses a separate deployment credential rather than
the PROD read-only credential. Configure the report repository and deployment
credential in the db-workbench user configuration. Never commit credentials,
query output, or production extracts. Dirty worktrees are never removed by
automatic cleanup; return to the TUI after the PR merge so it can close the
clean worktree without relying on a manual Windows filesystem operation.
