---
status: accepted
owner: platform
---

# ADR-0007: Use a base-table RPC for list counts

## Status
Accepted

## Context
The list-counts query ran against a wide view and took 51 seconds, breaching the statement timeout.

## Decision
We will read list counts from a base-table RPC with a composite index, never from the wide view.

## Consequences
The 51-second counts query is eliminated; future wide-view column changes no longer regress list latency. A third party can time the cold-cache list page and observe sub-2-second counts.
