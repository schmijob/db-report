# db-report agent instructions

## Scope

This repository contains database-specific SQL and documentation: object
definitions, business meaning, data relationships, and known source limitations.
Changes to the db-workbench application or its implementation docs belong in
that repository.

## Investigate and validate

- Read [`docs/architecture/architecture.md`](docs/architecture/architecture.md)
  and the relevant object documentation before changing SQL. Do not infer joins
  from names alone.
- Inspect representative rows in PROD or LOCAL. Validate expensive query logic
  as read-only SQL against PROD or through `db hybrid` before wrapping it in a
  stored procedure. Prefer PROD for expensive calculations and LOCAL when data
  transfer and iteration speed matter.
- Use the local sandbox to inspect actual behavior and validate the candidate.
  Install changed procedures into LOCAL before handoff when practical. A green
  synthetic test alone does not establish business correctness.
- For procedure test fixtures, assertions, source-backed cases, and drift
  handling, follow [`procedures/procedures.md`](procedures/procedures.md).
  Distinguish a procedure regression from changed source data or stale test
  assumptions; record which data the result depends on.
- Never commit credentials, query output, production extracts, or other
  sensitive data. Use configured credentials and the repository's privacy
  policy.

## Agent and human responsibilities

The agent owns database investigation, edits, automated tests, LOCAL validation,
and preparing a draft pull request. Work in an isolated task worktree. Include
the test results, the LOCAL checks performed, and any source-data assumptions
in the handoff. Stop after the draft pull request is ready. Do not perform the
final review, start the Delivery runner, deploy to PROD, merge the pull request,
or refresh local data as a delivery step. The agent may use local test actions
for candidate validation; those actions do not approve production delivery.

The human reviews the pull request and manually checks the candidate in LOCAL,
using DBeaver when useful. The human deploys the reviewed candidate to PROD
through the explicit db-workbench action. After deployment succeeds, starting
the Delivery runner is the approval to squash-merge the pull request. Keep
deployment and merge as separate actions, in that order. If the human requests
changes, resume the agent work and return a revised draft for review.

For db-workbench commands and human-operated delivery steps, use the
[db-workbench user guide](https://github.com/schmijob/db-workbench/blob/main/docs/user-guide.md).
