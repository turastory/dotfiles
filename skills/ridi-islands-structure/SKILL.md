---
name: ridi-islands-structure
description: Use when changing books-islands checkout parameters, PHP-to-SSR data flow, Twig integration, or the boundary between books-islands and web/ridibooks.
---

# RIDI Islands Structure

This skill is a short guide for the books-islands flow.

Use it before changing checkout parameters or server-rendered island props.

## When to use

- You are adding a new checkout field or flag
- You are tracing data from PHP into React SSR
- You need to know whether a change belongs in books-islands or `web/ridibooks`
- You are wiring island UI to GraphQL (`@ridi-web/gql-client-codegen` operations and hooks under `books-islands`, e.g. `queries/hooks/`)

## Four layers

Every checkout parameter has to pass through all four layers:

1. PHP controller
2. Express route
3. Islands server and props
4. Twig wrapper or React component

## Core paths

| Purpose | Path |
|---|---|
| PHP source side | `ridi1/books-backend/` |
| Route bridge | `frontends/web/ridibooks/src/server/routes/booksIslandsRoutes.ts` |
| Islands app | `frontends/web/shared/books-islands/` |
| Twig integration | `ridi1/books-backend` templates |

## Main warning

`booksIslandsRoutes.ts` explicitly destructures `req.body`.

If a new parameter is not added there, it can be dropped without an obvious error. Check the route layer before debugging React props.

## Working rules

- Update all four layers for new checkout params
- Keep Twig changes outside the island-controlled HTML
- Treat `books-islands` and `web/ridibooks` as separate implementations unless code sharing is explicit

## GraphQL from islands

Event detail and similar islands often load data via **GraphQL**, not only SSR props: add or change `.graphql` under `frontends/web/shared/gql-client-codegen`, run that package’s codegen, then consume generated hooks or wrap them with `createQuery` / `createMutation` in `books-islands`. End-to-end schema and resolver steps live in `ridi-graphql-structure`.

## Reference document

For the full flow, open:

- `.cursor/skills/ridi-islands-structure/references/architecture.md`

## Related skills

- `ridi-project-structure`
