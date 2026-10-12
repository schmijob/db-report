# db-report agent instructions

## Scope

`db-report` is the user-facing home for the database: versioned SQL, the data model, and instructions for querying it with `db-workbench`.

This repository explains what data means and how to access it. Tool source code and implementation details belong in `db-workbench`.

## Onboarding

- Read [`docs/architecture/`](docs/architecture/architecture.md) before writing a query.
- Read [`docs/skills/`](docs/skills/using-db-workbench.md) for query, export, and local-refresh workflows.
- Use the documented table grain, keys, relationships, freshness, and sensitivity notes. Do not infer joins from names alone.

## GitHub lifecycle

Make SQL and documentation changes in a dedicated worktree:

```powershell
git switch main
git fetch origin
git merge --ff-only origin/main
git worktree add -b task/<name> .\.worktrees\<name> main
```

If `git merge --ff-only origin/main` fails because `main` has diverged, run `git merge origin/main`. Accept a fast-forward or non-conflicting automatic resolution. If Git reports a conflict, perform a semantic merge: check the SQL, model meaning, and documentation together, then validate the result.

Work in the new worktree. Before integration, run `git -C .\.worktrees\<name> merge main`. From the main worktree, squash-merge, validate, and push:

```powershell
git switch main
git merge --squash task/<name>
git commit -m "Describe the change"
git push origin main
git fetch origin
git diff --exit-code main origin/main
git status --short --branch
git worktree remove .\.worktrees\<name>
git branch -d task/<name>
git worktree list
```

The db-workbench TUI performs the final cleanup automatically when it sees a
clean worktree's branch represented in synchronized `main`, including a squash
merge. It handles Windows read-only directory attributes after confirming the
worktree is clean. If the commands above are used manually and `git branch -d`
rejects a squash branch, use `git branch -D task/<name>` only after the remote/
main checks above succeed. A completed change has no task worktree left below
`.worktrees`.

The repository root is the `main` worktree. `.worktrees/` contains temporary,
uncommitted task worktrees and is ignored by Git; do not add SQL or documentation
changes directly to the root while a task worktree is active.

## Core commands

```powershell
db prod "SELECT ..."                         # query PROD (read only)
db local "SELECT ..."                        # query the local snapshot (read/write)
db hybrid "INSERT ..."                       # query PROD, write to LOCAL
db hybrid "SELECT * FROM local.some_table"   # explicitly query LOCAL through hybrid mode
db expand --full                              # show the complete previous result
db expand --csv "C:\\path\\result.csv"        # export the complete previous result
db refresh <table>                            # refresh one local table
```

Omit the SQL text to start an interactive session, for example `db local`. Query results show a 20-row preview; use `db expand` for the remaining rows. PROD access is read-only and applies the configured privacy policy.

For analysis, use `db prod`. For sandboxed development with small workloads on fixed datasets, use `db local`. For development on current data, full source tables, and workloads best handled by an actual server, use `db hybrid`.

## Rules

- Never commit credentials, query output, production extracts, or other sensitive data.
- Keep SQL, model documentation, and usage examples consistent.
- Treat the local snapshot as sanitized and potentially stale; check any freshness advisory before relying on it.
