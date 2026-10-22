# db-report agent instructions

## Scope

`db-report` is the user-facing home for the database: versioned SQL, the data model, and instructions for querying it with `db-workbench`.

This repository explains what data means and how to access it. Tool source code and implementation details belong in `db-workbench`.

## Onboarding

- Read [`docs/architecture/`](docs/architecture/architecture.md) before writing a query or changing SQL.
- Read [`docs/skills/`](docs/skills/using-db-workbench.md) for query, export, and local-refresh workflows.
- Use the documented table grain, keys, relationships, freshness, and sensitivity notes. Do not infer joins from names alone.

## Data-driven procedure development

- Inspect representative data before choosing test cases. Use `db prod` or `db hybrid` to examine current PROD rows and validate expensive query logic as SQL before wrapping it in a stored procedure. PROD access is read-only.
- Prefer PROD for expensive calculations. Use LOCAL when fast data transfer and iteration matter; LOCAL is a sanitized snapshot and may be stale.
- Run automated procedure cases in the db-workbench isolated fixture suite before installing a candidate into the configured LOCAL schema. The suite creates one disposable schema and one short-lived account limited to that schema on the existing LOCAL MariaDB server, loads its fixture once, runs cases sequentially, and removes both afterward.
- Put suites in `procedures/tests/<procedure_name>/`: `fixture.sql` creates synthetic tables and rows; each lexically ordered directory under `cases/` contains `before.sql`, `call.sql`, `after.sql`, and `reset.sql`. The reset script restores the fixture baseline before the next case. DDL does not roll back reliably, so reset scripts are explicit restore points. A failing stage stops the suite and the disposable schema is removed.
- Make `before.sql` and `after.sql` assert meaningful behavior by raising a MariaDB error when expectations fail; a `SELECT` that only prints a wrong value is not a failing test.
- Keep `fixture.sql` synthetic and scoped to the test schema. Do not qualify its writes with configured PROD or LOCAL schema names. Use real data to understand row shape and edge cases, then encode a minimal synthetic example. For aggregations that need representative source rows, use optional `prod-fixture.sql` with explicit hybrid inserts into `local.<fixture_table>` from the configured PROD database. The runner reads with the PROD read-only credential, applies the configured privacy policy, and writes only into the disposable schema; it saves no extract. Optional `source-checks.sql` can contain read-only PROD queries that each return one boolean; failed checks stop procedure tests and indicate changed source data or a stale check. PROD-backed expectations can drift, so record assumptions and inspect source data when a failure may reflect changed data. Never commit query output or production extracts. The isolated runner rewrites configured PROD/LOCAL qualifiers in procedure and case SQL, but not in `fixture.sql`.
- The configured LOCAL account needs permission to create/drop schemas and temporary accounts. If those privileges or credentials are unavailable, report the normal setup error.
- After the isolated suite passes, install the task worktree procedures into configured LOCAL for interactive checks. Inspect actual LOCAL results, including from DBeaver when useful; a green fixture suite alone is not enough to validate business behavior. For manual DBeaver checks, a sanitized sample may be staged into LOCAL with `db hybrid`, which applies the configured privacy transforms.
- Check freshness advisories before relying on LOCAL. If only a table or date range is stale, refresh that table or range with `db refresh` or the TUI's targeted refresh action. Avoid a full sandbox rebuild unless it is necessary; restoring the complete local snapshot is expensive.
- Use configured credentials. If a required credential is unavailable, report the normal setup error rather than requesting secrets in chat or storing them in the repository.

## GitHub lifecycle

Make SQL and documentation changes in a dedicated worktree from an up-to-date `main`:

```powershell
git switch main
git fetch origin
git merge --ff-only origin/main
git worktree add -b task/<name> .\.worktrees\<name> main
```

If `git merge --ff-only origin/main` fails because `main` has diverged, run `git merge origin/main`. Accept a fast-forward or non-conflicting automatic resolution. If Git reports a conflict, perform a semantic merge: check the SQL, model meaning, and documentation together.

Work only in the task worktree. Before delivery, run `git -C .\.worktrees\<name> merge main`, then repeat the relevant local data checks and tests. Commit and push the task branch, create or open its PR, and review the PR diff. Do not merge the branch or push task changes directly to `main` from the repository root.

For stored-procedure changes, use the db-workbench TUI as separate steps: install and test in LOCAL, review the PR and LOCAL behavior, deploy the reviewed worktree to PROD with the explicit `DEPLOY` confirmation, then start the Delivery runner and choose squash merge. A successful PROD deployment publishes an annotated `prod-procedure-deploy/...` receipt tag. Deployment and merge remain separate actions; keep the recommended deploy-before-merge order.

After the runner merges the PR, return to the TUI so it can refresh `origin/main` and automatically remove the clean worktree and local branch. It handles Windows read-only directory attributes after checking that the worktree is clean. A completed change has no task worktree left below `.worktrees`.

The repository root remains the `main` worktree. `.worktrees/` contains temporary task worktrees and is ignored by Git. Do not add SQL or documentation changes directly to the root while a task worktree is active.

## Core commands

```powershell
db prod "SELECT ..."                         # query current PROD (read only)
db local "SELECT ..."                        # query the local snapshot (read/write)
db hybrid "INSERT ..."                       # query PROD, write to LOCAL
db hybrid "SELECT * FROM local.some_table"   # explicitly query LOCAL through hybrid mode
db expand --full                              # show the complete previous result
db expand --csv "C:\\path\\result.csv"        # export the complete previous result
db refresh <table>                            # refresh one local table
```

Omit the SQL text to start an interactive session, for example `db local`. Query results show a 20-row preview; use `db expand` for the remaining rows. PROD access is read-only and applies the configured privacy policy.

## Rules

- Never commit credentials, query output, production extracts, or other sensitive data.
- Keep SQL, model documentation, and usage examples consistent.
- Treat LOCAL as sanitized and potentially stale; inspect the data and freshness advisory before relying on it.
