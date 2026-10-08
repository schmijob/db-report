# AGENTS.md

This is the always-on bootstrap and document router for `db-report`.

## Bootstrap

1. Read this file first, then read the repository documentation index and the relevant document under `docs/` before changing SQL or data-model guidance.
2. Check the working tree before editing and preserve unrelated user changes.
3. Keep this repository focused on the content of the database: versioned SQL changes, data-model documentation, and how-to guidance for using the database through the tool.
4. Tool implementation, runtime behavior, and tool architecture belong in the sibling `db-workbench` repository. Coordinate cross-repository changes explicitly.

## Document router

- `docs/README.md` is the documentation index.
- `docs/skills/` contains workflows and operational procedures for SQL changes, validation, and using the database through the tool.
- `docs/architecture/` contains the data model, domain vocabulary, ownership boundaries, and data-oriented design philosophy.

Add detailed guidance to the appropriate document rather than growing this file into a manual. Update the relevant router when adding a new document.

## Always-on instructions

- Assume the `db` command is already on `PATH`. Use `db prod`, `db local`, and `db hybrid` as appropriate. Do not instruct agents to invoke `db.bat` manually or to install the wrapper unless the task specifically asks about setup.
- Never commit credentials, query-buffer output, production extracts, or other sensitive database content. Prefer representative, sanitized examples in documentation.
- Treat SQL changes as reviewable database changes: make scope, assumptions, compatibility, and rollback considerations clear, and keep related model documentation in sync.
- Keep this repository about database content and its use. If a request changes tool behavior rather than SQL or data guidance, make the implementation change in `db-workbench`.
- Validate SQL and documentation with the safest relevant environment and report any validation that could not be performed.
