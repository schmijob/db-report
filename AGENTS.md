# Project guide

## Scope

`db-report` owns versioned SQL, data-model documentation, and how-to guidance for using the database through the tool.

Tool source code, runtime behavior, and tool architecture belong in `db-workbench`.

## Start here

- Read [`docs/skills/`](docs/skills/README.md) for SQL workflows and operations.
- Read [`docs/architecture/`](docs/architecture/README.md) for the data model and design principles.

## Rules

- Use the `db` command on `PATH`; do not call `db.bat` directly.
- Never commit credentials, query output, production extracts, or other sensitive data.
- Keep SQL changes, model documentation, and usage guidance consistent.
- State compatibility and rollback considerations for schema changes.
- Put tool implementation changes in `db-workbench`.
