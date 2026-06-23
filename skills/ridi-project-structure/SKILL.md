---
name: ridi-project-structure
description: Use when working in the RIDI monorepo and you need to locate backend app boundaries, route registration, legacy PHP integration points, or API and schema entry paths before editing code.
---

# RIDI Project Structure

This skill is a short index for where things live.

Use it before editing routes, proxies, or backend app code.

## When to use

- You are adding or changing a route in `backends`
- You need to decide between a path-based app and a legacy vhost app
- You need to know whether a flow lives in TypeScript `backends` or PHP `ridi1/books-backend`
- You need the main entry paths for OpenAPI or DB schema work

## Core locations

| Purpose | Path |
|---|---|
| Main app registration | `backends/src/apps/app.ts` |
| App-level config | `backends/src/apps/config/` |
| Global config and PCL hosts | `backends/src/config/` |
| Backend app modules | `backends/src/apps/` |
| Default books route area | `backends/src/apps/books/routes/` |
| Legacy proxy bridge | `backends/src/apps/books/proxies/` |
| Legacy PHP app | `ridi1/books-backend/` |
| DB schema source | `backends/src/db/schemas/` |
| OpenAPI specs | `backends/src/apps/*/spec/openapi.yaml` |
| GraphQL SDL (SSOT) | `graphql/schema/src/**/*.graphql` → package `ridi-graphql-schema` |
| GraphQL server and resolvers | `backends/src/apps/gql/` (mounted at `/graphql` from `app.ts`) |

## App map

Typical path-based apps in `backends/src/apps/`:

- `books`
- `account`
- `pay`
- `library`
- `select`
- `reading-data`
- `s2s`
- `gql`

Legacy or mixed-routing areas still exist in the same tree, including `api`, `book-api`, `bestseller-api`, `search-api`, `download`, `notification`, `preview`, and `web-viewer`.

## Working rules

- Prefer path-based routes for new work
- Treat vhost-based apps as legacy unless existing code already requires them
- Check `backends/src/apps/app.ts` before assuming an app is mounted
- If a feature still lives in PHP, inspect the books proxies before reimplementing it

## Boundaries to remember

- `ridi1/books-backend` handles legacy PHP pages and some order UI preparation
- `backends` handles the TypeScript API layer and current backend flows
- Schema truth lives in `backends/src/db/schemas/`
- REST/OpenAPI contract truth lives in each app's `spec/`
- GraphQL contract truth lives in `graphql/schema` (SDL), not in `spec/openapi.yaml`

## Related skills

- `ridi-graphql-structure` — SDL, resolvers, backend/web codegen, and client operation flow
- `ridi-db-schema`
- `ridi-event-structure`
- `ridi-test-guides`
- `ridi-batch-commands`
