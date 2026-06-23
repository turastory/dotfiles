---
name: ridi-web-guidelines
description: Use when implementing or reviewing RIDI web code, especially under frontends/web/ridibooks, frontends/web/shared, frontends/web/web-viewer, frontends/web/library, books-islands, rigrid-renderer, common/request, tracking, web server middleware, Next.js config, web GraphQL surfaces, or web-adjacent legacy bridge code. Trigger for web frontend work, web PR review, web coding style questions, structural convention checks, and attempts to avoid code that feels inconsistent with RIDI web practices.
---

# RIDI Web Guidelines

Use this skill before changing or reviewing RIDI web-related code. The goal is to match the web team's structural conventions, coding style, and recurring review expectations so new work does not feel foreign and avoidable review comments are reduced.

## Evidence Base

These guidelines were distilled from `web-approver` team inline review comments in `ridi/ridi` from `2025-12-09` to `2026-06-09`.

- Team members sampled: `fronterior`, `ridi-junhee`, `RINDAMAN2426`, `seongjunkang-ridi`, `youngdo212`
- Raw inline comments collected: 1,942
- Reviewer comments after excluding PR-author replies: 885
- Related PRs: 359
- Heaviest reviewed areas: `frontends/web/ridibooks`, `frontends/web/shared`, `frontends/web/web-viewer`, `frontends/web/library`

## First Steps

1. Locate the package and package manager before running scripts. In this repo, read the relevant `package.json` first.
2. Inspect nearby code before designing a new shape. Prefer the pattern already used in the same package or adjacent feature.
3. Identify whether the change crosses SSR/CSR, legacy PHP/Twig, GraphQL, tracking, authentication, or shared-package boundaries.
4. If reviewing, start from the user-facing entrypoint or public contract, then drill into hooks, utilities, services, and tests.

## Core Review Lens

### Structure and Responsibility

- Put code where its responsibility belongs. Avoid placing app-specific behavior in `shared/common` or generic utilities.
- Prefer existing context/hooks/providers over passing duplicated props through new paths.
- Keep state, styling, data fetching, tracking, and rendering responsibilities visibly separated when the local package does so.
- When extracting common code, verify that callers really share the same contract rather than only similar implementation details.

Common review triggers:
- A component reads a value that an existing page or section context already provides, but receives it through props instead.
- A state file starts carrying styles or rendering details.
- A shared utility depends on ridibooks-specific semantics.
- A new abstraction hides a package boundary instead of clarifying it.

### API, SSR/CSR, and Legacy Contracts

- Treat server/client boundaries as first-class. Check both SSR and CSR call sites when using `req`, cookies, headers, feature flags, or token refresh.
- Preserve legacy API casing and parameter rules deliberately. Some legacy endpoints require explicit camel/snake options.
- Be careful with `x-ridi-*`, CloudFront, auth, token, and cookie headers. Whitelists should reflect existing RIDI header conventions.
- For proxy or middleware changes, describe what downstream systems will actually observe, not only what the code sends.

Common review triggers:
- CSR path reads server-only `req` state and silently falls back.
- SSR request retry merges cookies or headers without tests.
- A proxy changes analytics semantics such as connecting IP or geo data.
- A legacy endpoint's response casing or route parameter contract is assumed instead of checked.

### React State and Data Flow

- Be explicit when changing `suspense`, `enabled`, `refetch`, `dataUpdatedAt`, lazy loading, or effect trigger behavior.
- Prefer stable, local patterns for React Query and page data loading over one-off state flow.
- Remember JSX edge cases: `condition && value` can render `0`; use a ternary/null branch when the value can be numeric.
- Avoid effect logic that depends on incidental render timing unless the behavior is tested or explained.

### Styling and UI

- Avoid inline styles when the package normally separates component and style files.
- Use theme tokens and existing web utilities for color, line clamp, typography, and common CSS patterns.
- Do not set font family manually when global/reset CSS already owns it.
- Watch CSS specificity and class order. Changes to design-system defaults can break consumer overrides.
- Match existing component/style file organization before adding a new style pattern.

### Tests and Verification

- Cover the essential changed branch, not only surrounding rendering.
- Add tests for SSR token refresh, cookie/header merge, request retry, feature-flag branching, query-option behavior, and payment/auth branches when those contracts change.
- Use the package's local test convention. For example, check whether the package uses Jest or Vitest and where `__tests__/*.spec.ts(x)` belongs.
- Do not add smoke checks or guards unless they fail at the same stage where the real problem would occur.

### Tracking, Analytics, and Observability

- Prefer the established Tracking library or event client used by the local domain.
- Explain data meaning changes in PRs: GA4 proxying, server IP vs client IP, geo loss, Sentry filtering, metric labels, and event taxonomy changes.
- Keep analytics changes tied to the intended measurement goal. Avoid adding fields or proxy behavior whose interpretation is unclear.

### Build, Dependencies, and Deployment

- Before adding build scripts or runtime guards, verify whether the failure happens at build time or runtime.
- Prefer config tied to the actual contract, such as Next.js output tracing, over disconnected lists that drift.
- Be careful with package manager and lockfile churn. Follow the relevant package's existing manager and scripts.

## Implementation Checklist

Before coding web changes:

- Read nearby implementations in the same package.
- Confirm package manager and scripts from `package.json`.
- Identify SSR/CSR and legacy bridge boundaries.
- Check whether existing context, hook, utility, theme, tracking, or request helper already covers the use case.
- Decide which branch needs tests before implementing.

Before finishing:

- Run the smallest relevant verification command from the package.
- If lint fails, run `pnpm lint:fix` from the project containing the changed file before manual lint edits.
- Re-read changed files for inconsistent naming, misplaced responsibility, duplicated code, and hidden boundary changes.
- Mention any intentional divergence from existing web patterns in the final summary or PR body.

## PR Review Checklist

When reviewing web code, look for:

- Boundary drift: app code in shared modules, shared assumptions in app code, or hidden legacy dependencies.
- SSR/CSR bugs: server-only values used in client calls, missing cookie/header merge tests, feature flags that only work on one side.
- State-flow regressions: removed suspense/lazy behavior, changed query `enabled`, unintended effect trigger changes.
- Styling drift: inline style, direct font/color values, missing theme utility, component/style organization mismatch.
- Test gaps: core branch not covered, wrong test runner convention, missing regression for request/auth/tracking behavior.
- Observability meaning changes: analytics or metrics still emit but now mean something different.
- Overbuilt safeguards: guard scripts or lists that do not catch the real failure mode.

## Useful Local Commands

```bash
gh auth status
tools/github/fetch-team-review-comments.mjs --strategy repo-comments --since 2025-12-09T00:00:00Z --skip-prs
node --check tools/github/fetch-team-review-comments.mjs
```

Use the data-collection command only when you need to refresh this guideline from current GitHub review comments.
