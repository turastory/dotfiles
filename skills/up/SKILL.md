---
name: up
description: Starts local dev servers for RIDI monorepo projects as background processes. Use whenever the user runs /up, says "up <target>" (e.g. "/up books-islands", "/up backoffice"), or asks to start, bring up, boot, or spin up the dev environment / dev servers for a RIDI project. A target like "books-islands" or "backoffice" maps to a fixed set of servers (frontend + backends) that get launched together in the background. Trigger even when the user just names a known target without the word "up".
---

# up — launch RIDI dev servers

Bring up the dev servers for a named target as **background** processes, then report what's running and how to reach it. The servers are long-running watchers (`ts-node-dev --respawn`, `turbo run dev`), so they must run in the background — never in the foreground, which would block.

## Targets

Each target is a set of servers launched together. Paths are relative to the worktree root (resolve it with `git rev-parse --show-toplevel`).

| Target | Servers |
|---|---|
| `books-islands` | `frontends/web/ridibooks` → `envs local pnpm dev` (frontend, port 8338) · `backends` → `envs dev pnpm start:dev` (main backends) |
| `backoffice` | `internal-products/backends` → `pnpm start:bo` (BO backend, gRPC-web on port 9090) · `internal-products/frontends/backoffice` → `pnpm dev` (Vite frontend, port 5173 at `/backoffice/`) · **prereq:** QueryPie agent on port 40032 (see below) |

When the user names a target not in this table, list the known targets and ask which they meant — don't guess and launch the wrong thing.

Adding a target later is just a new row here: a friendly name plus its `<dir> → <command>` pairs. Keep each command exactly as the user runs it by hand (the `envs <name>` prefix routes the correct `.env` — see the envs setup), so the registry stays a faithful copy of the manual workflow.

## Steps

0. **Check target prerequisites first.** Some targets depend on an external agent being up. For `backoffice`, the BO backend reaches dev DB through the **QueryPie agent on port 40032** — check it before (or alongside) launching: `nc -z localhost 40032` (or `lsof -i :40032`). If the port is dead, **don't try to start QueryPie yourself** — tell the user to log in to the QueryPie agent (the connection only works after they authenticate), then continue bringing up the servers anyway so they're ready once the agent is up.

1. **Resolve the root.** Run `git rev-parse --show-toplevel` once. Every server's `cd` is relative to this, so the skill works from any subdirectory of the worktree.

2. **Launch each server in the background.** One background Bash call per server, e.g. `cd <root>/frontends/web/ridibooks && envs local pnpm dev`. Run them in the same turn so they boot in parallel. Use the background mode of the Bash tool (not a trailing `&`) so the harness tracks each process and surfaces its output.

3. **Confirm they came up.** Dev servers take a bit to compile. Give them a moment, then check each one's background output for the "ready"/"listening" line (or that the port is accepting connections) before declaring success. Watch with a background `until grep` loop rather than blocking the foreground. If one crashes on boot — a port already in use, a missing `.env`, a worktree `node_modules` problem (see Notes) — surface the actual error from its log instead of reporting a clean start.

4. **Report.** Tell the user, per server: which command is running, the URL/port to open, and how to follow the logs. For `books-islands` the live URLs are the ridibooks frontend at `http://localhost:8338` (TLS via `https://next.local.ridi.io`) and the backends at `http://local.ridi.io:8080`. For `backoffice` the frontend is at `http://localhost:5173/backoffice/` (it proxies `/ridi.backoffice.*` to the BO backend on `localhost:9090`); also restate the QueryPie status from step 0 — if port 40032 was down, repeat that the user must log in to the QueryPie agent for the BO backend to reach dev DB. Remind them the servers keep running in the background; to stop them, kill the background tasks (`ts-node-dev … src/apps` for backends — note `--respawn` means it survives a child crash, so kill the process, don't expect the task to exit on error).

## Notes

- **One target, two servers — that's expected.** `/up books-islands` intentionally spawns both the frontend and the backends it talks to; that's the whole point of the target.
- **Don't substitute commands.** `envs dev pnpm start:dev` and `envs local pnpm dev` are the literal commands — don't "simplify" to plain `pnpm dev` or swap env names. The env routing is load-bearing.
- **Node version for backends:** backends needs the repo's Node 22 (native modules are built against it). If the default `node` is something else, prefix with `PATH=/Users/nayoonho/.nvm/versions/node/v22.22.0/bin:$PATH`.

### Superset-worktree recovery (backends)

A fresh superset worktree usually isn't fully provisioned, and `/up` will surface the boot error. The two failures, in the order they appear, and their fixes:

1. **`Cannot find module …`, stack resolving from `/Users/nayoonho/ridi/ridi/node_modules`** — `backends/node_modules` is a symlink to the root checkout, so it resolves against the wrong pnpm store. Fix: `rm backends/node_modules` then `pnpm install --frozen-lockfile --prefer-offline --ignore-scripts` at the worktree root (a plain install reports "Already up to date" and does nothing while the symlink is there — the `rm` is what matters), which relinks it to the worktree's own store.
2. **`Could not locate the bindings file … confluent-kafka-javascript.node`** — the native kafka addon has no compiled binary, because `--ignore-scripts` (and pnpm 10 blocking unapproved build scripts) skipped the build. Fastest fix is to copy the prebuilt binary from the root checkout, which is already built: `cp -R <root-checkout>/node_modules/.pnpm/@confluentinc+kafka-javascript@<ver>/node_modules/@confluentinc/kafka-javascript/build <worktree>/…/kafka-javascript/build` (match the exact `.pnpm` dir name, which includes the version + peer hash). Then relaunch backends.

This recovery is really the worktree bootstrap's job, not `/up`'s — so surface the error and the fix, don't silently run a heavy reinstall unless the user asks.
