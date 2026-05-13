---
name: ridi-batch-commands
description: Use when adding, editing, or debugging batch commands under backends/src/batch/, including yargs module conventions, commandDir wiring, Airflow DAG setup, and common gotchas.
---

# RIDI Batch Commands

This skill covers the batch CLI system under `backends/src/batch/`.

Use it before adding a new batch command, modifying an existing one, or debugging CLI registration issues.

## When to use

- You are adding a new batch command or command group
- You are debugging why a command is not recognized or loads incorrectly
- You need to understand how yargs commandDir wiring works in this repo
- You are setting up an Airflow DAG for a new batch

## Architecture
### Entry point

`backends/src/batch/index.ts` boots the CLI:

1. Initializes Datadog trace, Kafka, libsodium
2. `yargs.commandDir('cmds', { extensions: ['ts', 'js'] })` loads all top-level files in `cmds/`
3. `.demandCommand(1)` requires at least one command
4. Gracefully shuts down DB, Kafka, Redis, Sentry, GrowthBook on exit
5. Waits 2 seconds after completion for Datadog trace flush

Run locally: `pnpm batch <group> <subcommand> [options]`

### Two-level command hierarchy

```
batch <group> <subcommand>
  │       │         └── Leaf command in *-cmds/ folder
  │       └── Router file in cmds/ (commandDir → *-cmds/)
  └── Entry (index.ts → commandDir → cmds/)
```

**Level 1 — Router (namespace):** Each `cmds/<group>.ts` file delegates to a subfolder via `commandDir`.

**Level 2 — Leaf command:** Each file in `cmds/<group>-cmds/` exports `command`, `desc`, and `handler`.

### Exception: direct leaf at top level

`finance-monitor.ts` is the only top-level file that acts as a leaf command (has its own `handler`) rather than a router. It uses a registry pattern with side-effect imports to load check modules.

## File conventions

### Router file template

```ts
import type { CommandBuilder } from 'yargs';

export const command = '<group-name> <command>';
export const desc = '<group-name> commands';

export const builder: CommandBuilder = (yargs) =>
  yargs.commandDir('<group-name>-cmds', {
    extensions: ['ts', 'js'],
    exclude: /(.test.ts|queries.ts)/,
  });
```

### Leaf command exports

| Export | Required | Notes |
|---|---|---|
| `command` | yes | CLI string, may include positional args |
| `desc` or `description` | yes | Both work in yargs; most files use `desc` |
| `builder` | no | Define options and positionals |
| `handler` | yes | Async function with the actual logic |

### Folder naming

- Most subfolders follow `<group-name>-cmds` (e.g. `finance-cmds`, `order-cmds`)
- Exceptions: `book-category` and `reading-books` do not use the `-cmds` suffix

## Gotchas

### commandDir exclude — files that get auto-loaded

Every router uses `exclude: /(.test.ts|queries.ts)/` to prevent test and query files from being registered as commands. If you add a new helper file (e.g. `utils.ts`, `types.ts`, `config/`) to a `-cmds` folder, check whether the exclude regex covers it. By default it does **not** — only `finance-revenue.ts` extends the pattern:

```
exclude: /(\.test\.ts|queries\.ts|types\.ts|\/config\/|\/utils\/)/
```

Any `.ts` file in a `-cmds` folder that is NOT excluded will be loaded as a command module by yargs. If it does not export `command` + `handler`, it may cause silent errors or confusing help output.

### Escape inconsistency in exclude regex

Most routers use unescaped dots `(.test.ts|queries.ts)` while a few use properly escaped `(\.test\.ts|queries\.ts)`. Both work in practice for these patterns, but be aware when adding new exclusions.

### desc vs description

The codebase predominantly uses `desc`. Only `periodic-cash-charge-cmds` leaf commands use `description`. Both are valid yargs fields. Prefer `desc` for consistency.

### No handler means broken command

If a file in a `-cmds` folder exports only `command` and `desc` without a `handler`, yargs will register it but it will do nothing when invoked. Always provide `handler`.

### commandDir only loads direct children

`yargs.commandDir` loads files from the **immediate directory** only, not recursively. Deeper subdirectories (e.g. `gmarket-api-cmds/sub/`) are regular TS modules imported by leaf commands, not auto-loaded commands.

### Process exit delay

The batch runner waits 2 seconds (`DELAY_IN_MILLISECONDS_FOR_TRACE`) after all work completes before exiting. Factor this into timeout calculations for Airflow tasks and health checks.

### Kafka and DB are always initialized

Even if a command does not need Kafka or DB, the entry point initializes them and tears them down. There is no opt-out mechanism per command.

## Adding a new batch command

1. **New leaf in existing group:** Add a `.ts` file to the `<group>-cmds/` folder. Export `command`, `desc`, `handler`. Done — the router's `commandDir` picks it up.
2. **New command group:** Create `cmds/<name>.ts` (router) + `cmds/<name>-cmds/` (leaf folder). Follow the router template above.
3. **Airflow DAG:** Follow `backends/src/batch/README.md`. Add a DAG file in `ridi-devops` with the `backends-batch-<name>` id pattern.
4. **One-off execution:** Use the existing `backends-batch-cli` Airflow DAG with `{ "command": ["group", "subcommand", ...] }` JSON config.

### Airflow schedule timezone

- Treat Airflow batch cron expressions in this repo as **UTC** when choosing `schedule_interval`
- Convert intended KST runtime to UTC explicitly instead of assuming the cron string is evaluated in KST
- Keep this in mind even when the DAG file sets `kst = pendulum.timezone('Asia/Seoul')`; that value is commonly used for `start_date`, not as proof that the cron itself is written in KST

## Testing

- Tests live alongside commands as `*.test.ts` in the same `-cmds` folder
- They are excluded from commandDir via the `exclude` regex
- `queries.test.ts` validates generated SQL strings (snapshot-style)
- Command module tests import the module directly and call `handler()` — not through yargs
- Follow `ridi-test-guides` skill conventions for fixtures, stubs, and assertions

## Related skills

- `ridi-project-structure` — backend app layout and entry points
- `ridi-event-structure` — r-bus events and one-off backfill commands
- `ridi-test-guides` — test conventions for backend code
