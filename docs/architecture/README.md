# Data architecture

This section is the home for the database's data model and the reasoning behind it.

Document the domain vocabulary, entities, relationships, ownership, lifecycle, sensitive fields, compatibility expectations, and the relationship between versioned SQL and the model. When a SQL change alters the model, update the relevant explanation and usage guidance with it.

Prefer explicit, reviewable, reversible changes; clear names and constraints; and examples that are representative without exposing production data. Keep tool implementation details in `db-workbench` and put operational procedures in [`../skills/`](../skills/README.md).
