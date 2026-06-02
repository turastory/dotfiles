---
name: ridi-test-guides
description: Use when writing or reviewing RIDI backend tests (subscribers, APIs, Knex queries, DB fixtures, feature flags, r-bus stubs). Covers assertion style, fixture layout, query vs API test roles, and local setup conventions.
---

# RIDI Test Guides

Backend test conventions for `backends/` and `internal-products/backends/`. GraphQL resolver tests under `backends/src/apps/gql/resolvers/**/*.test.ts` follow the same patterns; see `ridi-graphql-structure` for layout.

## When to use

- Stubbing `r-bus` or other module boundaries
- Asserting nested event, API, or DB-shaped payloads
- Subscriber `eachBatch` setup
- DB fixtures, users, feature flags, Knex table types
- Knex query modules (`*.queries.test.ts`) or HTTP/API integration tests

## Test shape and tooling

- `describe(testName(), () => { ... })` when surrounding utilities use it
- Group by behavior; one scenario per `it`; prefer `async`/`await`
- Mocha + Chai + Sinon; shared helpers from `ridi-backends/test/utils` and `ridi-backends/apps/test/utils` before one-off setup
- Supertest for HTTP-level checks when the app/router is exposed that way

## Query tests vs API tests

| Layer | File | Focus |
| --- | --- | --- |
| Knex query module | `queries.test.ts` | SQL shape, filters, sort order via `toQuery()` (or equivalent) — lock the DB contract |
| Route/handler | `index.test.ts` (Supertest) | Auth, response shape, feature-flag branches, domain post-processing |

Do not duplicate full SQL assertions in API tests when `queries.test.ts` already covers them.

## r-bus stubs

Import the specific event module, not the barrel:

```ts
import * as rBusMarketingAgreementChanged from 'ridi-backends/r-bus/marketingAgreementChanged';
```

## Payload assertions

When output is deterministic, prefer one full-shape check:

```ts
expect(actualPayload).to.deep.equal(expectedPayload);
```

Build one `expected` mirroring production shape. Use partial checks only for non-deterministic fields (timestamps, generated ids).

## Subscriber `eachBatch`

Include only fields the code reads; use `as Message[]` when that drops unused keys:

```ts
messages: [{ userIdx: fixtures.tb_user[0].idx, reason: 'dormant' }] as Message[],
```

## Fixtures and DB setup

- Use `ridi-backends/test/builders` when available; override only scenario-critical fields; let defaults cover incidental columns
- Keep domain-signaling fields when they aid reading (e.g. `tb_money.amount` next to `remain_amount`)
- Omit auto-increment PKs unless the scenario needs a fixed id
- Wire child FKs from parent rows — not hand-picked constants on both sides
- After mutations, query back and assert row shape, not only that a function was called

### Avoid derived fixture helpers

Do **not** add shared callbacks that read other tables and auto-build rows (e.g. filter `tb_money` → insert `summary.point_history`). Put auxiliary table data **explicitly** in the nested `describe` that exercises that code path.

### Readability over DRY

For pagination, ordering, or any case where **values matter**, spread each table row in the fixture block. Do not fold rows behind scenario objects, `.map()`, or `.find()` — readers should see inserted values without jumping to helpers.

### FK wiring: index vs lookup

When parent fixture **insert order is part of the test contract**, link children with `results.<alias>[i].id` (parallel indices across related fixtures). Use `find` / `assertIsDefined` only when order is not guaranteed or you must match on a business key.

### `dbFixtureHooks` vs `dbFixtureHooksEach`

Both in `ridi-backends/test/utils`; first tuple element is the **fixture alias**.

| Helper | Hooks | Runs |
| --- | --- | --- |
| `dbFixtureHooks` | `before` / `after` | Once per `describe` |
| `dbFixtureHooksEach` | `beforeEach` / `afterEach` | Every `it` |

- Parents before children; child uses `(results) => [...]` and parent pk from `results.<alias>`
- **`dbFixtureHooks`:** top level or when several `it` blocks share the same rows
- **`dbFixtureHooksEach`:** fresh insert per test, or nested `describe` under a parent that already uses `dbFixtureHooksEach`

**Nested describes:** if the parent already uses `dbFixtureHooksEach`, children must use **`dbFixtureHooksEach`**, not `dbFixtureHooks` (hook order can cause PK collisions).

### Fixture alias and layout

- Prefer **table name** as alias: `tb_event_group`, `point_history`
- Access `fixture.tb_event_group[0].id`; reference other fixtures as `results.tb_event_group[0].id`
- Put hooks on a **nested `describe` per scenario**; keep `it` to calls + assertions
- Duplicate overlapping fixtures across scenarios when that keeps each block self-contained — avoid shared `insertX()` that hides what was seeded
- Prefer `dbFixtureHooksEach` + builders over manual `beforeEach` + `ridiPrimary().insert(...)` for table-shaped data
- Inline inserts: parent first (`insertAndGetIdentifiers` or query), then child FKs from returned ids

## Feature flags

- Prefer `mockFeatureFlag` from `ridi-backends/test/utils`; avoid manual `sinon.stub` unless necessary
- Split paths at **describe** boundaries: `describe('with <flag> on')` + `mockFeatureFlag` in `beforeEach`
- Path-specific fixtures (e.g. summary index rows) live **only** inside that block
- Do **not** re-run every legacy scenario under FF on when shared post-processing is already covered by FF-off tests — add FF-on cases for the new read path (e.g. pagination/order) only

## Pagination and order

- Seed multiple rows with distinguishable fields (`comments`, `t_id`, amounts, dates)
- Call API with `offset`/`limit`; assert `count`/`length` plus **one** identifying field on the returned slice
- When sort keys differ by path (e.g. `created_at` vs `pay_id`), say so in the **`it` title**

## Supertest helpers

Wrap only repeated **request + response parse** in a thin helper (e.g. `fetchPointHistory`). Keep fixtures and assertions in `describe` / `it`.

## User fixtures

- App/auth setup: `appsUserHook` from `ridi-backends/apps/test/utils`
- Raw row builders only when testing table contents directly

## Knex table types

```ts
import type { tb_user_action_campaign } from 'knex/types/tables';
```

Avoid `Tables['...']` for a single table.

## Isolation

- Stub at boundaries you own
- One behavior per `it`
- Same DB rows, different inputs/assertions → shared fixture `describe`
- Different DB rows → separate nested `describe` with own hooks (duplication OK)
- Prefer one full-shape assertion over many small ones when the contract is deterministic

## Reference files

- `backends/src/subscribers/services/amplitude-event/signUp/userSignupVerified.test.ts`
- `backends/src/subscribers/services/braze-event/signUp/userSignupVerified.test.ts`
- `internal-products/backends/src/backoffice/controllers/ridi-select/voucher-campaign/index.test.ts` — `dbFixtureHooksEach`, table aliases, `(results)` chains; nested `describe` + per-scenario hooks
- `internal-products/backends/src/backoffice/controllers/event/management/event-group/index.test.ts` — shared `dbFixtureHooksEach` suite fixtures; `describe` per controller method
- `backends/src/apps/books/routes/api/order/histories/point/queries.test.ts` — `toQuery()` contracts
- `backends/src/apps/books/routes/api/order/histories/point/index.test.ts` — `describe('with summary.point_history (feature flag on)')` block: FF-on pagination/order, inline fixtures, `(results)` FK wiring

## Common mistakes

- Stubbing top-level `r-bus` barrel
- Many partial assertions on one deterministic payload
- Unused `eachBatch` fields
- Manual feature-flag stubs when `mockFeatureFlag` exists
- `Tables` import for one row type
- Oversized fixtures hiding which columns matter
- Hardcoded PKs/FKs when index linkage suffices
- `dbFixtureHooks` nested under parent `dbFixtureHooksEach`
- Non-table fixture aliases (`participationGroup` vs `tb_event_group`)
- Large inserts in `it` or shared helpers instead of nested `describe` hooks
- Derived fixture callbacks (auto summary rows from money)
- Scenario `.map()` / `.find()` hiding pagination seed data
- Duplicating every API scenario under FF on when legacy path already covers post-processing
- SQL/order checks in API tests instead of `queries.test.ts`

## Related skills

- `ridi-event-structure`
- `ridi-project-structure`
