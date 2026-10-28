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

For query commands and human-operated delivery steps, see
`../db-workbench/README.md` and
`../db-workbench/docs/skills/using-db-workbench.md` from the db-report checkout
root.
Never commit credentials, query output, or production extracts.
