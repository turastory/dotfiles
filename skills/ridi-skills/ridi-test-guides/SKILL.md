---
name: ridi-test-guides
description: Use when writing or reviewing RIDI backend tests for subscribers, APIs, DB fixtures, feature flags, Knex types, or r-bus boundaries, especially when you need the local assertion and setup conventions.
---

# RIDI Test Guides

This skill is a backend test convention guide for the monorepo.

Use it when adding or reviewing tests under `backends/`, especially for subscribers, API handlers, DB-backed flows, and module-boundary stubs.

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

- Prefer builders from `ridi-backends/test/builders` when a builder already exists
- Keep fixture rows minimal and only fill columns the scenario needs
- Avoid manually assigning auto-increment primary keys unless the test truly depends on a fixed id
- After a DB mutation, query back and assert the resulting row shape instead of only checking that a function was called

### FK-dependent fixtures with `dbFixtureHooks`

When a table has a `FOREIGN KEY ... ON DELETE CASCADE` (e.g. `tb_event_participation_group.event_group_id → tb_event_group.id`), you cannot hardcode the child's FK column and let MySQL assign the parent id independently — the insert fails with `Cannot add or update a child row: a foreign key constraint fails`.

Pattern:

1. Put the parent fixture earlier in the `dbFixtureHooks(...)` tuple list so it inserts first.
2. Use the `(results) => [...]` callback form for the child fixture and read `results.<parent_fixture_name>[0].id` to wire the FK.
3. Don't hand-pick an `event_group_id: 10` style constant on the child — let the builder default PK to `0` (MySQL AUTO_INCREMENT) and always reference `results[...]`.

See `backends/src/apps/gql/resolvers/typeResolvers/eventGroup/resolver.test.ts` (`with DB-backed participation group`) for the `tb_event_group` → `tb_event_participation_group` → `tb_event_participation_stamp` chain as a reference.

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
- If several cases differ only in input shape, share setup helpers instead of copying fixture blocks
- Keep tests readable without requiring the reader to mentally reconstruct the payload from many small assertions

## Good files to copy patterns from

- `backends/src/subscribers/services/amplitude-event/signUp/userSignupVerified.test.ts`
- `backends/src/subscribers/services/braze-event/signUp/userSignupVerified.test.ts`

## Common mistakes

- Stubbing from the top-level `r-bus` barrel
- Splitting one deterministic payload check into many partial assertions without a reason
- Adding unused fields to `eachBatch` messages
- Rewriting feature flag stubs manually when a helper already exists
- Importing `Tables` for a single row type
- Writing oversized fixtures that hide which columns actually matter

## Related skills

- `ridi-event-structure`
- `ridi-project-structure`
