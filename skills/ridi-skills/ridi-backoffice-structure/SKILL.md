---
name: ridi-backoffice-structure
description: Use when working on the renewed RIDI Backoffice under internal-products/frontends/backoffice, internal-products/backends/src/backoffice, or internal-products/backends/backoffice references. Provides the frontend, backend, proto, routing, gRPC, auth, and verification entry points before editing code.
---

# RIDI Backoffice Structure

This skill is a short index for the renewed Backoffice.

Use it before editing Backoffice frontend pages, gRPC APIs, proto contracts, auth scopes, grids, forms, or local verification commands.

## When to use

- You are working under `internal-products/frontends/backoffice`
- You are working under `internal-products/backends/src/backoffice`
- The user mentions `internal-products/backends/backoffice`; map that to the actual path `internal-products/backends/src/backoffice`
- You need to connect a Backoffice page to a Backoffice gRPC method
- You need to add or change a `ridi/backoffice/**/*.proto` contract
- You need to choose where route, navigation, controller, query, or generated proto code belongs

## Core locations

| Purpose | Path |
| --- | --- |
| Frontend package | `internal-products/frontends/backoffice` |
| Frontend entry | `internal-products/frontends/backoffice/src/index.tsx` |
| Frontend app shell | `internal-products/frontends/backoffice/src/App.tsx` |
| Frontend route tree | `internal-products/frontends/backoffice/src/routes/index.tsx` |
| Frontend pages | `internal-products/frontends/backoffice/src/pages/` |
| Frontend navigation | `internal-products/frontends/backoffice/src/layouts/defaultLayout/config-navigation.tsx` |
| Frontend gRPC-Web transport | `internal-products/frontends/backoffice/src/hooks/useGrpcTransport.ts` |
| Frontend query defaults | `internal-products/frontends/backoffice/src/components/QueryClientBoot.tsx` |
| Backend package | `internal-products/backends` |
| Backend Backoffice app | `internal-products/backends/src/backoffice` |
| Backend entry | `internal-products/backends/src/backoffice/main.ts` |
| Backend gRPC bootstrap | `internal-products/backends/src/backoffice/bootstrap.ts` |
| Backend module/controller registration | `internal-products/backends/src/backoffice/app.module.ts` |
| Backend controllers | `internal-products/backends/src/backoffice/controllers/` |
| Backend auth resources/scopes | `internal-products/backends/src/backoffice/base/nestjs/auth/index.ts` |
| Backend proto loading list | `internal-products/backends/src/backoffice/base/grpc/protoPath.ts` |
| Backend gRPC package list | `internal-products/backends/src/backoffice/base/grpc/packages.ts` |
| Proto source | `internal-products/proto/ridi/backoffice/**/*.proto` |
| Nest generated proto package | `internal-products/proto/lib/nestjs` (`ridi-internal-proto-lib-nestjs`) |
| Frontend generated proto package | `internal-products/proto/lib/protobuf-ts` (`ridi-internal-proto-lib-protobuf-ts`) |

## Frontend map

- Package name: `backoffice-frontend`.
- Runtime: Vite + React CSR. Both Vite `base` and `BrowserRouter` basename are `/backoffice/`.
- Auth: `App.tsx` wraps the app with Keycloak `login-required`, PKCE S256, and `checkLoginIframe: false`.
- Routing: `src/routes/index.tsx` owns the large `useRoutes` tree. Authenticated routes usually render `Layout`; unauthenticated state renders `LoadingScreen`.
- Pages: domain folders live under `src/pages/`, such as `books`, `cp`, `crm`, `cs`, `event`, `finance`, `genre-home`, `osmu`, `reward`, `ridi-select`, `search`, `stat`, `store`, and `tools`.
- Navigation: `config-navigation.tsx` mixes renewed internal routes like `/cp/ticket/book-notice/list` with legacy CMS links built from `import.meta.env.VITE_CMS_URL`.
- API calls: this Backoffice does not use the main RIDI GraphQL flow. Use `useGrpcTransport()` + generated `*ServiceClient` from `ridi-internal-proto-lib-protobuf-ts/...` + `react-query`.
- Transport: `useGrpcTransport.ts` sends gRPC-Web binary requests with `credentials: 'include'` and `Authorization: Bearer ${keycloak.token}`.
- Local proxy: `vite.config.mjs` proxies `^/ridi[.]backoffice[.].*` to `http://localhost:9090`.
- Common UI: prefer existing `@/components/DataGrid`, `@/components/SearchForm`, snackbar/alert/loading contexts, and theme/settings components before adding new primitives.
- DataGrid work: read `internal-products/frontends/backoffice/.cursor/rules/data-grid.mdc` for `colType`, `rowIdKey`, editable rows, and common formatting mistakes.
- Path aliases: `@/*` maps to `src/*`; `~/public/*` maps to `public/*`.

## Backend map

- Package name: `internal-backend`; it also contains `src/select-b2b`, so stay inside `src/backoffice` for Backoffice work.
- Runtime: NestJS gRPC microservice, not REST or GraphQL.
- Startup: `main.ts` calls `bootstrap.ts`; `bootstrap.ts` creates a gRPC microservice with `Transport.GRPC`, `protoPath`, and `grpcPackages`.
- Default gRPC address comes from `config.grpcUrl`; local frontend traffic usually reaches the service through the gRPC-Web proxy stack.
- `app.module.ts` registers the domain controllers directly. When adding a controller, import it and add it to the `controllers` array.
- Controller folders usually live at `controllers/<domain>/...` and often keep `index.ts`, `queries.ts`, `athena-queries.ts`, `const.ts`, `types.ts`, and `test/` nearby.
- DB access commonly uses `ridi-backends/db` Knex clients such as `ridiPrimary`, `ridiReplica`, and CMS replica clients. Shared schema truth remains under `backends/src/db/schemas/`.
- List helpers live in `src/backoffice/base/knex/index.ts`.
- Some stats/reporting code uses Athena utilities under `src/backoffice/utils/athenaQueries`.
- Auth is global Keycloak guards from `app.module.ts`. Use `@Resource(...)` and `@Scopes(...)` from `base/nestjs/auth`; `@Public()` is for public endpoints such as health checks.
- For gRPC errors, prefer existing helpers in `internal-products/backends/src/utils/grpc.ts`.
- Path aliases: `internal-backends/*` maps to `internal-products/backends/src/*`; `ridi-backends/*` maps to the main `backends/src/*`.

## Proto and gRPC workflow

- Proto contracts live in `internal-products/proto/ridi/backoffice/**/*.proto`.
- Backend Nest types/decorators come from `ridi-internal-proto-lib-nestjs`.
- Frontend protobuf-ts clients come from `ridi-internal-proto-lib-protobuf-ts`.
- After adding a new proto file, keep both backend loading files aligned:
  - `internal-products/backends/src/backoffice/base/grpc/protoPath.ts`
  - `internal-products/backends/src/backoffice/base/grpc/packages.ts`
- Add or update the backend controller implementation in `src/backoffice/controllers/...` and register it in `app.module.ts`.
- Add or update the frontend hook/page code to instantiate the generated protobuf-ts `*ServiceClient` with `useGrpcTransport()`.
- From `internal-products/proto`, run `pnpm build` to regenerate both Nest and protobuf-ts libraries. Run `pnpm test` for `buf lint`.

## Verification commands

Run commands from the package directory unless a task-specific script says otherwise.

| Area | Command |
| --- | --- |
| Frontend dev | `pnpm dev` in `internal-products/frontends/backoffice` |
| Frontend build | `pnpm build` in `internal-products/frontends/backoffice` |
| Frontend lint | `pnpm lint` in `internal-products/frontends/backoffice` |
| Backend dev | `pnpm start:bo` in `internal-products/backends` |
| Backend Backoffice tests | `pnpm test:bo` in `internal-products/backends` |
| Backend lint | `pnpm lint` in `internal-products/backends` |
| Proto lint | `pnpm test` in `internal-products/proto` |
| Proto codegen/build | `pnpm build` in `internal-products/proto` |

## Local startup checklist

Use this order when bringing up the renewed Backoffice locally:

1. Start the QueryPie dev DB tunnel first. The default `.env.dev` expects dev DB access on `127.0.0.1:40032`; if this port is closed, gRPC requests commonly fail with `connect ECONNREFUSED 127.0.0.1:40032`.
2. Start local infrastructure from `backends` with `pnpm docker:infra`. The Backoffice needs the Envoy gRPC-Web proxy on `9090`, Redis on `6379`, and Kafka on `9092`.
3. Start the Backoffice backend from `internal-products/backends` with `pnpm start:bo`. It is healthy when logs include `Nest microservice successfully started` and `8088` is listening.
4. Start the Backoffice frontend from `internal-products/frontends/backoffice` with `pnpm dev`. Open `http://localhost:5173/backoffice/`.
5. If the browser shows `upstream connect error`, check that `9090` and `8088` are both listening. If backend startup hangs before `Nest microservice successfully started`, check whether Kafka is listening on `9092`; a dead Kafka container can block `kafka.init()`.

## Verification notes

- Frontend dev is healthy when Vite prints `Local: http://localhost:5173/backoffice/`; `/backoffice/` should return HTTP 200.
- Backend dev is healthy when logs include `Nest microservice successfully started` and the configured gRPC port, usually `8088`, is listening.
- The local gRPC-Web proxy is separate from `pnpm start:bo`; check whether `9090` is already provided by the local Docker stack when frontend API calls fail.
- `pnpm test` in `internal-products/proto` runs `buf lint`, but the current repo baseline may report existing lint violations from generated-package `node_modules` and legacy proto naming. Use `pnpm build` for proto codegen/compile validation, and interpret `pnpm test` failures against the files you actually changed.

## Working rules

- Start from the existing domain folder before creating a new one. Mirror nearby page/controller/query/test structure.
- For a new screen, update both `src/routes/index.tsx` and `config-navigation.tsx` when it should be reachable from the side navigation.
- For a new backend gRPC service, update proto, generated libraries, `protoPath.ts`, `packages.ts`, controller implementation, and `app.module.ts` together.
- Do not route Backoffice work through `ridi-graphql-structure`; renewed Backoffice uses internal proto + gRPC-Web.
- Prefer existing `DataGrid`, `SearchForm`, react-query, Keycloak, Knex, Athena, and gRPC error helpers over new local abstractions.
- Keep legacy CMS links as `VITE_CMS_URL` navigation entries when the feature still belongs to the old CMS.
- For backend tests, follow Mocha/Chai/Sinon patterns in sibling `*.test.ts` and `*.e2e-test.ts` files; also use `ridi-test-guides` for fixture and assertion conventions.

## Related skills

- `ridi-project-structure` — broader RIDI app boundaries and main backend paths
- `ridi-db-schema` — database domains and schema files before writing queries
- `ridi-test-guides` — backend test conventions and fixture patterns
- `ridi-graphql-structure` — only for the main RIDI GraphQL stack, not renewed Backoffice gRPC
