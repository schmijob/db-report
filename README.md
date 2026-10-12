# db-report

`db-report` is the human-facing source of truth for versioned database objects,
database meaning, and safe use of the `db-workbench` TUI. The repository root is
the `main` worktree; temporary task worktrees live below the ignored `.worktrees/`
directory.

## Start here

- Read the [data model and architecture](docs/architecture/architecture.md)
  before writing or changing SQL.
- Read the [db-workbench workflows](docs/skills/using-db-workbench.md) for
  querying, LOCAL refreshes, and the stored-procedure deployment lifecycle.
- Use the [stored-procedure source guide](procedures/procedures.md) when adding
  or reviewing a procedure.

## Versioned database objects

- [Migrations](migrations/migrations.md)
- [Stored procedures](procedures/procedures.md)
- [Tables](tables/tables.md)
- [Triggers](triggers/triggers.md)
- [Views](views/views.md)

Tool implementation belongs in `db-workbench`; credentials, query output, and
production extracts must never be committed here.
