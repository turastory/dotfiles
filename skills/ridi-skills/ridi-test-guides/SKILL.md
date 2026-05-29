---
name: ridi-test-guides
description: Use when writing or reviewing RIDI backend tests for subscribers, APIs, DB fixtures, feature flags, Knex types, or r-bus boundaries, especially when you need the local assertion and setup conventions.
---

# RIDI Test Guides

This skill is a backend test convention guide for the monorepo.

Use it when adding or reviewing tests under `backends/` or `internal-products/backends/`, especially for subscribers, API handlers, DB-backed flows, and module-boundary stubs.

## When to use

- You are stubbing an `r-bus` publish function or another module boundary
- You are asserting a nested event, API, or DB-shaped payload
- You are writing subscriber tests around `eachBatch`
- You are setting up DB fixtures, users, or feature flags
- You are choosing Knex table types in test code
- You want to match the style already used in backend tests
- You are writing or reviewing **GraphQL resolver tests** under `backends/src/apps/gql/resolvers/**/*.test.ts` (follow the same Mocha/Chai/Sinon patterns; see `ridi-graphql-structure` for where resolvers live)

## Test shape

- Wrap files with `describe(testName(), () => { ... })` when the surrounding test utilities already follow that pattern
- Group cases by behavior, not by implementation detail
- Keep each `it(...)` focused on one scenario
- Prefer `async` and `await` over manual promise chaining

## Tooling defaults

- Use Mocha and Chai for suite structure and assertions
- Use Sinon for stubs and spies
- Use shared helpers from `ridi-backends/test/utils` and `ridi-backends/apps/test/utils` before adding one-off setup
- Use Supertest for HTTP-level checks when the app or router is exposed that way

## r-bus stubs

Import the specific event module instead of the top-level barrel.

Use:

```ts
import * as rBusMarketingAgreementChanged from 'ridi-backends/r-bus/marketingAgreementChanged';
```

Avoid:

```ts
import * as rBus from 'ridi-backends/r-bus';
```

This keeps the stub surface narrow and avoids accidental coupling to unrelated exports.

## Payload assertions

When the output shape is deterministic, prefer one explicit full-shape assertion:

```ts
expect(actualPayload).to.deep.equal(expectedPayload);
```

Prefer this over splitting the check into many smaller assertions such as:

- `to.have.lengthOf(...)`
- `to.deep.include(...)`
- `to.be.a('string')` for fields that can be asserted exactly

Why this is preferred:

- The final contract is readable in one place
- Payload updates are easier when the structure changes
- Redundant precursor checks disappear because the full-shape mismatch already points to the problem

## Practical assertion rule

- Build one `expected` object or array that mirrors the production shape
- Assert the full shape with `to.deep.equal` whenever practical
- Fall back to partial assertions only for intentionally non-deterministic fields such as timestamps or generated ids

## Subscriber tests and `eachBatch`

When calling `eachBatch` in tests:

- Include only the fields the code under test actually reads
- Use `as Message[]` when that avoids boilerplate for unused keys
- Extract and guard `eachBatch` with existing helper patterns when sibling tests already do that

Example:

```ts
messages: [
  {
    userIdx: fixtures.tb_user[0].idx,
    reason: 'dormant',
  },
] as Message[],
```

Why this is preferred:

- The fixture stays small
- The test makes real dependencies obvious
- The setup does not expand just to satisfy unrelated type fields

## Fixtures and DB setup

- Use builders from `ridi-backends/test/builders` when a builder exists. Prefer builder chains over raw fixture objects so defaults stay centralized and tests show only the scenario-specific differences.
- In builder chains, override only fields that are required for the scenario, the code path under test, or the assertion. Do not fill incidental columns such as `service_id`, `pg_tid`, `created_at`, `pay_id`, or `pay_type` just because the table has them; let the builder defaults cover unrelated data.
- Keep domain-signaling fields when they make the fixture easier to understand, even if the query does not read them directly. For example, `tb_money.amount` can be worth setting next to `remain_amount` because it explains the money row's original amount and remaining balance.
- Prefer auto-increment for primary keys in both `dbFixtureHooks` / `dbFixtureHooksEach` and inline inserts: omit builder `.id(...)` and hardcoded `id` in fixture rows unless the scenario truly needs a fixed id (e.g. matching pre-seeded data or asserting a specific id).
- For related rows, wire foreign keys from the parent row’s assigned id — not from a hand-picked constant on both parent and child.
- After a DB mutation, query back and assert the resulting row shape instead of only checking that a function was called

### `dbFixtureHooks` vs `dbFixtureHooksEach`

Both live in `ridi-backends/test/utils`. The first tuple element is the **fixture alias** (see below).

| Helper | Mocha hooks | Runs |
| --- | --- | --- |
| `dbFixtureHooks` | `before` / `after` | Once per `describe` |
| `dbFixtureHooksEach` | `beforeEach` / `afterEach` | Before every `it` |

- List parent fixtures before children; on the child, use `(results) => [...]` and read the parent pk from `results.<alias>`.
- **`dbFixtureHooks`:** use at the top level, or inside a `describe` when several `it` blocks can share the same DB rows for the whole block.
- **`dbFixtureHooksEach`:** use when each test needs a fresh insert, or when adding fixtures in a **nested** `describe` under a parent that already uses `dbFixtureHooksEach`.

**Nested describes:** if the parent suite already uses `dbFixtureHooksEach`, child fixture setup must use **`dbFixtureHooksEach`**, not `dbFixtureHooks`. Mocha runs a child `before` before the parent’s `beforeEach`, so `dbFixtureHooks` can insert into the same table first and collide with the parent’s fixed ids (e.g. auto-increment row taking `id=1` before the parent inserts `id=1`).

### Fixture alias

- Prefer the **table name** as the alias: `tb_event_group`, `tb_event_participation`.
- Avoid domain nicknames (`participationGroup`, `participationStamps`) unless the file already standardizes on something else.
- Access rows as `fixture.tb_event_group[0].id`, and reference other fixtures in callbacks as `results.tb_event_group[0].id`.

### Describe layout (fixture vs assertion)

- Put `dbFixtureHooks` / `dbFixtureHooksEach` on a **nested `describe`** per scenario (e.g. `when participation exists`), and keep `it` blocks focused on calls + assertions.
- Each nested `describe` should be readable on its own: duplicate overlapping fixture definitions when scenarios differ, instead of a shared `insertParticipationGroup()` that forces readers to jump around.
- Prefer `dbFixtureHooksEach` + builders over manual `beforeEach` + `ridiPrimary().insert(...)` when the scenario is table-shaped fixture data.

### Inline inserts

When not using the hooks, insert the parent first (`insertAndGetIdentifiers` or a follow-up query), then set child FKs and locate API results using the returned id.

## User fixtures

- For app-level or auth-shaped user setup, prefer `appsUserHook` from `ridi-backends/apps/test/utils`
- Use lower-level row builders only when the scenario is specifically about raw table contents

## Feature flags

- Prefer `mockFeatureFlag` from `ridi-backends/test/utils`
- Avoid manual `sinon.stub(...)` flag setup unless you need control that the helper does not provide

This keeps flag setup consistent across tests and reduces brittle stubs.

## Knex table types

Prefer direct table type imports from `knex/types/tables`.

Use:

```ts
import type { tb_user_action_campaign } from 'knex/types/tables';
```

Avoid importing `Tables` only to index a single table type.

Direct imports are more explicit and match common usage in existing tests.

## Isolation and clarity

- Stub side effects at the boundary you own, not deep inside unrelated helpers
- Do not bloat one test with multiple behaviors that should be separate cases
- If several `it` blocks differ only in **inputs or assertions** with the **same DB rows**, share one fixture `describe` or helper
- If cases need **different DB rows**, use separate nested `describe` blocks with their own fixture hooks (duplication is fine)
- Keep tests readable without requiring the reader to mentally reconstruct the payload from many small assertions

## Good files to copy patterns from

- `backends/src/subscribers/services/amplitude-event/signUp/userSignupVerified.test.ts`
- `backends/src/subscribers/services/braze-event/signUp/userSignupVerified.test.ts`
- `internal-products/backends/src/backoffice/controllers/event/management/event-participation/index.test.ts` — `dbFixtureHooksEach` with table-name aliases and `(results)` chains
- `internal-products/backends/src/backoffice/controllers/event/management/event-group/index.test.ts` — nested `describe` + per-scenario `dbFixtureHooksEach` under a parent fixture suite

## Common mistakes

- Stubbing from the top-level `r-bus` barrel
- Splitting one deterministic payload check into many partial assertions without a reason
- Adding unused fields to `eachBatch` messages
- Rewriting feature flag stubs manually when a helper already exists
- Importing `Tables` for a single row type
- Writing oversized fixtures that hide which columns actually matter
- Hardcoding auto-increment PKs or FKs when only parent–child linkage is needed
- Using `dbFixtureHooks` inside a nested `describe` whose parent already uses `dbFixtureHooksEach` (hook order / PK collisions)
- Fixture aliases that do not match table names (`participationGroup` instead of `tb_event_group`)
- Putting large insert blocks inside `it` or a shared helper when `dbFixtureHooksEach` on a nested `describe` would separate fixture from assertion

## Related skills

- `ridi-event-structure`
- `ridi-project-structure`
