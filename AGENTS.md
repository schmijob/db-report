# db-report agent instructions

## Scope and routing

This repository owns database-specific SQL, semantics, tests, and documentation.

- Start with `README.md`.
- Read `docs/architecture/architecture.md` before SQL changes.
- Read `docs/procedures.md` for procedure source and tests.
- Before SQL or test changes, read
  `../db-workbench/docs/skills/using-db-workbench.md` from the db-report checkout root.
- Before documentation changes, read
  `../db-workbench/docs/skills/write-docs.md` from the db-report checkout root.

## Always-on rules

- Inspect actual data and documented relationships; do not infer joins from names.
