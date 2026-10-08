# Data model

This is the user-facing reference for understanding the database before querying it.

## Data trust

- **PROD** is the current source and is accessed read-only through the configured credential.
- **LOCAL** is a sanitized snapshot for analysis and development. It may omit data, transform sensitive fields, or lag behind PROD.
- **HYBRID** routes an operation between PROD and LOCAL. Use it only when the intended source and target are clear.

## How to read the model

For each domain area, document and read:

1. the business grain of each table or view;
2. primary keys and stable identifiers;
3. relationships and approved join paths;
4. date, status, and freshness fields;
5. sensitive or transformed fields; and
6. the authoritative source and known snapshot limitations.

Versioned SQL defines the database structure. This directory explains its meaning, relationships, and safe usage. Update both when a SQL change alters the model or the way analysts should query it.
