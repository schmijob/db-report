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
and LOCAL, create an ignored `.worktrees/<name>` task worktree, test the change,
commit and push it, review the GitHub diff, and explicitly deploy the reviewed
worktree. Optional LOCAL smoke tests live in `tests/<procedure_name>.sql`.

The repository root stays on `main`; `.worktrees/` is temporary and must never
be committed.
