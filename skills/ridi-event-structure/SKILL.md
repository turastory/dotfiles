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
- In `reward-user-action-campaign`, read mission properties across multiple missions through the cached/concurrency-limited aggregator (`getCachedMissionProperties` in `subscribers/services/reward-user-action-campaign/utils/campaign.ts`) — not the raw `queries.findMission*Properties` directly. A single mission can have 10k+ property rows, so it uses mget cache + `pLimit` to cap concurrent per-mission queries and avoid DB load.

## Common checks

- Event exists in `r-bus` but no consumer: inspect `subscribers/services/`
- Consumer exists but nothing happens: check outbox, publisher, group status, then subscriber code
- Same topic consumed by multiple services: confirm separate `groupId` usage

## Kafka CLI (topic / test message)

Implementation: `backends/src/cli/cmds/kafka.ts`. Run from `backends/`.

Broker selection follows `NODE_ENV` via `backends/src/kafka/config/{nodeEnv}.json` (convict in `utils/config.ts`):

| `NODE_ENV` | Brokers |
|---|---|
| `local` (default) | `localhost:9092` (`KAFKA_BROKERS` overrides) |
| `development` | dev r-bus cluster (`development.json`) |
| `production` | prod r-bus cluster — do not use for manual testing |

For **dev cluster** commands, prefix with `NODE_ENV=development`. For **local Docker Kafka**, use default `local` (or omit `NODE_ENV`) after `pnpm docker:infra`.

```bash
cd backends

# Dev cluster
NODE_ENV=development pnpm cli kafka list-topics
NODE_ENV=development pnpm cli kafka create <topic>           # default: -p 10 -r 3
NODE_ENV=development pnpm cli kafka produce <topic> '<json>'
NODE_ENV=development pnpm cli kafka consume <topic> --fromBeginning

# Local Docker (single broker — lower replication)
pnpm cli kafka create <topic> -r 1 -p 3
pnpm cli kafka produce <topic> '<json>'
pnpm cli kafka consume <topic> --fromBeginning
```

`pnpm cli:dev` (`DOT_ENV=.env.dev pnpm cli`) loads dev DB/env files; it does **not** set `NODE_ENV`. Use it when a CLI command also needs `.env.dev` (e.g. `trigger-event-check-in`), and still set `NODE_ENV=development` for dev Kafka.

### Test message shape

Subscribers parse `JSON.parse(value).data` (`subscribers/utils.ts`). Match the event’s `topic` and `type` from `r-bus/<event>/config/`.

Minimum (handler-only smoke test):

```json
{"data":{"userIdx":1}}
```

Production-like (CloudEvent — preferred when validators or `type` matter):

```json
{"specversion":"1.0","id":"cli-test-1","source":"cli","type":"com.ridi.cart","data":{"userIdx":1}}
```

`produce` takes the JSON as a single shell argument (quote it). `consume` prints the parsed `data` field.

### Other useful subcommands

`metadata`, `offset`, `describe-groups`, `get-message`, `list-groups` — see `pnpm cli kafka --help`.

Outbox-backed flows (real publish path) may be better exercised with `pnpm cli trigger-event-check-in` (dev only, requires `NODE_ENV=development`) than raw `produce`.

## Reference documents

For detail beyond this index, open:

- `.cursor/skills/ridi-event-structure/references/IMPLEMENTATION_GUIDE.md`
- `.cursor/skills/ridi-event-structure/references/QUICK_REFERENCE.md`

## Related skills

- `ridi-db-schema`
- `ridi-project-structure`
- `ridi-test-guides`
- `ridi-batch-commands`
- `kafka-dev-produce`
