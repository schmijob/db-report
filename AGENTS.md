# db-report agent instructions

## Scope and routing

This repository owns database-specific SQL, semantics, tests, and documentation.
Use db-workbench for general tool operation and delivery workflow.

- Start with [README.md](README.md).
- Read [database architecture](docs/architecture/architecture.md) before SQL changes.
- Read [procedure guidance](docs/procedures.md) for procedure source and tests.
- Before SQL or test changes, read the
  [db-workbench SQL-project guide](https://github.com/schmijob/db-workbench/blob/main/docs/skills/using-db-workbench.md).
- Before documentation changes, read the
  [db-workbench writing guide](https://github.com/schmijob/db-workbench/blob/main/docs/skills/write-docs.md).

## Always-on rules

- Inspect actual data and documented relationships; do not infer joins from names.
- Treat PROD as read-only and LOCAL as sanitized, potentially stale data.
- Never commit credentials, query output, or production extracts.
- Do not hand off local-only work. Commit and push the candidate, open a draft
  PR, and include its URL. The human owns final review, PROD deployment, and
  starting the Delivery runner to approve merge. Keep deployment and merge
  separate, in that order.
