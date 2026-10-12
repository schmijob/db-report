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

From the main worktree, use `git merge --squash <branch>`, validate the result, commit, and `git push origin main`. Delete the worktree and its branch only after the push succeeds.
