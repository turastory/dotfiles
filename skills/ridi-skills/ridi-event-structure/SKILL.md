---
name: ridi-event-structure
description: Use when locating RIDI event definitions, Outbox-based publishing, subscribers, CRM event consumers, or backfill entry points before adding or debugging event-driven behavior.
---

# RIDI Event Structure

This skill is a short map for the event system.

Use it before adding a new event, subscriber, or backfill job.

## When to use

- You need to find where an event is defined
- You need to publish inside a DB transaction
- You are adding a subscriber or checking consumer boundaries
- You are tracing CRM event flow such as Amplitude or Airbridge
- You need the starting point for a backfill or one-off batch

## Core locations

| Purpose | Path |
|---|---|
| Event definitions and helpers | `backends/src/r-bus/` |
| Subscriber framework and services | `backends/src/subscribers/` |
| One-off batch and backfill commands | `backends/src/batch/cmds/one-off-cmds/` |
| Schema context for outbox | `backends/src/db/schemas/` |

## Read this tree first

- `backends/src/r-bus/utils.ts`
- `backends/src/r-bus/<event-name>/config/`
- `backends/src/r-bus/<event-name>/index.ts`
- `backends/src/subscribers/utils.ts`
- `backends/src/subscribers/services/`

## Working rules

- If publishing must stay atomic with DB writes, use the outbox path
- Treat subscriber handlers as independent consumers with their own `groupId`
- Use existing event folders as templates instead of inventing a new structure
- Check `one-off-cmds` for existing backfill patterns before creating another script

## Common checks

- Event exists in `r-bus` but no consumer: inspect `subscribers/services/`
- Consumer exists but nothing happens: check outbox, publisher, group status, then subscriber code
- Same topic consumed by multiple services: confirm separate `groupId` usage

## Reference documents

For detail beyond this index, open:

- `.cursor/skills/ridi-event-structure/references/IMPLEMENTATION_GUIDE.md`
- `.cursor/skills/ridi-event-structure/references/QUICK_REFERENCE.md`

## Related skills

- `ridi-db-schema`
- `ridi-project-structure`
- `ridi-test-guides`
- `ridi-batch-commands`
