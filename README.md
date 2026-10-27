# db-report

`db-report` contains the versioned database objects and documentation for this
database's meaning, relationships, and known limitations.

## Start here

- Read the [data model and architecture](docs/architecture/architecture.md)
  before writing or changing SQL.
- Use the [stored-procedure source guide](docs/procedures.md) when adding
  or reviewing a procedure.

## Versioned database objects

- [Migrations](migrations/migrations.md)
- [Stored procedures](procedures/)
- [Tables](tables/tables.md)
- [Triggers](triggers/triggers.md)
- [Views](views/views.md)

For query commands and human-operated delivery steps, see the
[db-workbench README](https://github.com/schmijob/db-workbench/blob/main/README.md)
and its [agent skills](https://github.com/schmijob/db-workbench/blob/main/docs/skills/skills.md).
Never commit credentials, query output, or production extracts.
