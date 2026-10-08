# Data architecture

Document the database's domain vocabulary, entities, relationships, ownership, lifecycle, sensitive fields, compatibility expectations, and the link between versioned SQL and the model.

Update model and usage documentation with every SQL change that alters behavior or structure. Prefer explicit, reviewable, reversible changes; clear names and constraints; and representative examples that do not expose production data.

Keep tool implementation details in `db-workbench` and operational procedures in [`../skills/`](../skills/README.md).
