---
name: ridi-graphql-structure
description: Use when adding or changing GraphQL schema, resolvers, or web client operations in the RIDI monorepo — SDL location, backend codegen, frontend gql-client-codegen bundles, field resolvers, and end-to-end workflow.
---

# RIDI GraphQL — 작업 참고 사항 / 지침

모노레포에서 GraphQL은 **스키마 SDL → 백엔드 리졸버 → 프론트 오퍼레이션** 순으로 맞추는 것이 안전하다. 이 스킬은 경로·절차·유의사항을 한곳에 모은다.

## 용어 (짧게)

### SDL

**Schema Definition Language**: GraphQL 스키마를 `.graphql` 텍스트로 적는 문법이다. 이 레포에서는 `graphql/schema/src/**/*.graphql` 파일들이 SDL 소스이며, 빌드 시 합쳐져 `ridi-graphql-schema` 패키지가 로드하는 단일 스키마가 된다.

### Directive (디렉티브)

스키마나 쿼리에 붙는 **`@이름(...)` 메타데이터**로, 실행 엔진·툴이 해석한다. 예: `@deprecated`, 커스텀 캐시 등. 백엔드에서는 `backends/src/apps/gql/utils/directives/`에서 `mapSchema`로 스키마를 변환해 디렉티브 의미를 구현한다(예: `swrCache`). SDL에 `@foo`를 새로 정의·사용하면 **서버 쪽 변환 로직**이 같이 있어야 한다.

## 레포 구성 요약

| 구분 | 역할 | 주요 경로 |
|------|------|-----------|
| 스키마 SSOT | SDL 작성·합본 | `graphql/schema/src/**/*.graphql` → 빌드 산출 `lib/schema.graphql` (`ridi-graphql-schema`) |
| 백엔드 서버 | Apollo, `/graphql` | `backends/src/apps/gql/` (`server.ts`, `schema.ts`, `resolvers/`) |
| 백엔드 Codegen | 리졸버·모델 타입 | `backends`: `pnpm gql:codegen` (`src/apps/gql/codegen.yml` → `generated/`) |
| 웹 클라 Codegen | 오퍼레이션 + React Query 훅 | `frontends/web/shared/gql-client-codegen` (`codegen.yml`, `query/`, `mutation/` → `src/generated/`) |

## 백엔드 Codegen vs 웹 Codegen

| | 백엔드 (`backends`) | 웹 (`gql-client-codegen`) |
|---|---------------------|---------------------------|
| **입력 스키마** | `src/apps/gql/schema.ts` → `loadSDL()` (패키지 스키마) | `src/schema.ts` → `ridi-graphql-schema` default export (동일 SSOT) |
| **문서(documents)** | 없음 (`documents: null`) | `query/**/*.graphql`, `mutation/**/*.graphql` 등 **클라이언트가 보낼 쿼리/뮤테이션 파일** |
| **산출물** | `Resolvers`, `Context` 연동 타입, `models` 등 **서버 구현용** | **오퍼레이션별 타입**, `useXxxQuery` / mutation 훅, fetcher, query key 등 **클라이언트용** |
| **mappers** | `codegen.yml`의 `mappers`로 GraphQL 타입 ↔ `types/overrides` (**parent 타입 커스텀**) | 스칼라 매핑·fetcher (`codegen.yml` `plugin-config`) |

요약: **백엔드 codegen은 “스키마 전체 + 리졸버 시그니처”**, **웹 codegen은 “스키마 + 우리가 작성한 .graphql 오퍼레이션”**이다. 스키마만 바꾸고 웹 `.graphql`을 안 고치면 타입/훅은 그대로일 수 있고, **새 필드를 클라에서 쓰려면 오퍼레이션 파일을 수정하고 웹 패키지 codegen을 돌려야** 한다.

## 백엔드 구조 (리졸버)

- 조립: `resolvers/index.ts` → `Query`, `Mutation`, 각종 **타입별 필드 리졸버**, 스칼라.
- **루트 필드**: `resolvers/queryResolvers/index.ts`, `resolvers/mutationResolvers/index.ts`에 **스키마 필드명과 동일한 키**로 등록.
- **필드 리졸버**: `resolvers/typeResolvers/<TypeName>/resolver.ts`에서 `Resolvers['TypeName']` 형태로 필드별 함수. N+1 방지에 `context.getDataloader` 패턴이 흔함.
- **타입 매핑**: `types/overrides` + `codegen.yml` `mappers`로 parent/반환 타입을 조정.

## 웹 프론트 구성 (`@ridi-web/gql-client-codegen`)

- **스키마**: `src/schema.ts`가 `ridi-graphql-schema`를 re-export — 백엔드와 같은 스키마 버전을 쓴다.
- **오퍼레이션**: `query/`, `mutation/` 아래 `.graphql` (도메인별 폴더, 예: `query/eventDetail/`).
- **Codegen 출력**: `codegen.yml`에 따라 여러 번들(`default`, `rigrid`, `webViewer`, `library` 등)로 나뉜다. **어느 번들에 포함되는지는 `documents` glob**으로 결정된다. 새 쿼리 파일을 넣을 때 **해당 앱이 쓰는 번들에 포함되는 경로**에 두어야 한다.
- **빌드**: 패키지 `pnpm codegen` / `pnpm build`가 codegen을 포함한다(스크립트는 `package.json` 참고).

### 프론트에서 Query / Mutation 호출 흐름

1. **스키마에 필드가 있다**는 전제(백엔드 SDL + 리졸버 완료).
2. `gql-client-codegen`의 **`query/` 또는 `mutation/`에 `.graphql` 추가·수정** (operation 이름·변수는 팀 컨벤션에 맞출 것).
3. **`pnpm codegen`(또는 패키지 `build`)**으로 `src/generated/*.ts` 갱신.
4. 앱에서는 생성된 **`useXxxQuery`**, **`useXxxMutation`**, 또는 **`XxxDocument` + fetcher**를 import. 일부 앱은 `createQuery` / `createMutation` 래퍼로 감싼 훅을 둔다(예: books-islands `queries/hooks`).
5. **엔드포인트**: 백엔드 `/graphql`(앱 마운트·미들웨어는 `backends/src/apps/app.ts` 참고). 인증은 `optionalJwt` 등 기존과 동일하게.

## 변경 절차 (권장 순서)

1. **SDL**: `graphql/schema/src/`에 타입·`Query`/`Mutation` 필드 추가.
2. **스키마 패키지 빌드**: 루트 `build:gql-schema` 또는 `graphql/schema` 패키지 빌드로 `lib/schema.graphql` 갱신.
3. **백엔드**: `backends`에서 `pnpm gql:codegen` → `generated/` 갱신.
4. **리졸버**: `queryResolvers` / `mutationResolvers` / `typeResolvers` 구현 및 인덱스 등록. 필요 시 `types/overrides` + `codegen.yml` mappers.
5. **웹**: `gql-client-codegen`에 `.graphql` 추가·수정 후 codegen → 소비 앱에서 생성 훅 사용.
6. **테스트**: 백엔드 `resolver.test.ts`, 필요 시 프론트 테스트.

## 유의 사항

- **스키마 단일 소스**: `graphql/schema` 밖에 SDL을 두지 않는다. 백엔드 `schema.ts`는 패키지를 읽기만 한다.
- **순서**: SDL → 스키마 빌드 → 백엔드 codegen → 리졸버 → 웹 오퍼레이션 + 웹 codegen. 어긋나면 타입 불일치·빌드 실패가 난다.
- **JIT 경로**: `server.ts`에 일반 Apollo와 JIT 게이트웨이 두 경로가 있다. 리졸버 래핑·스키마 변환을 추가할 때 **둘 다** 고려한다.
- **디렉티브**: SDL에만 추가하고 `applyDirectives`/`mapSchema`에 처리 없으면 기대 동작이 아니다.
- **웹 번들 분리**: `graphql` 파일을 잘못된 폴더에 두면 특정 앱 번들에 쿼리가 안 들어간다. `codegen.yml`의 `documents` glob을 확인한다.
- **`graphql` 버전 정렬 필수**: `graphql/schema/package.json`의 `graphql` 의존성은 root/backends와 동일한 버전이어야 한다. 버전이 어긋나면 `backends` codegen에서 `Cannot use GraphQLNonNull "X!" from another module or realm` 오류가 나면서 `backends/src/apps/gql/generated/{resolvers,models}.ts`가 **조용히 빈 출력**으로 끝난다(상위 "Generate outputs [SUCCESS]"가 뜨더라도 개별 target은 실패). 불일치가 보이면 `graphql/schema/package.json`부터 맞추고 `pnpm install` 후 재시도.
- **생성 파일 pre-commit 회피**: `biome.jsonc`는 `src/apps/control-tower/generated/**`, `src/apps/gql/generated/**`를 excludes하지만 루트 lint-staged는 `backends/src/**/*.ts` 글로브로 전부 `biome check`에 넘기므로 **생성 파일만 스테이지된 커밋**은 biome v2의 "all paths ignored" 규칙에 걸려 exit 1. 이 경우 `--no-verify` 1회 스킵이 실용적(생성물은 이미 lint 제외 대상).
- **루트 원샷 빌드**: SDL + 백엔드 codegen + 웹 codegen을 한 번에 갱신하려면 루트에서 `pnpm run build:gql` (내부적으로 `build:gql-schema && build:gql-backends && build:gql-web`). 개별 실행 시 각 단계 출력의 `[FAILED]`를 반드시 확인한다(종합 exit code가 0이어도 하위 target이 실패할 수 있음).
- **필수 필드 additive 추가의 잠복 tsc 실패**: SDL 에 non-null 필드를 추가해도 스키마/codegen PR 단독에서는 tsc 가 통과할 수 있지만, 그 필드를 채우지 못하는 기존 리졸버 반환 shape (예: GrowthBook JSON fallback, feature-flag spread) 이 있으면 **상위 스택의 리졸버 PR에서만 tsc 가 깨진다**. 증상은 `Type '...' is not assignable to type 'Omit<X, ...> & { ... }'` 로 특정 필드를 지목하지 않는 포괄적 에러라 원인 파악이 느리다. 대응은 (a) 스키마 PR 에서 optional 로 두거나 (b) 리졸버 PR 에서 해당 경로에 defaults shim 을 추가하는 것. master 에서 tsc 가 초록인데 내 스택에서만 빨간 경우 스택 아래 SDL PR 의 **additive 필드**가 의심 1순위.
- **Parent 타입이 union/override 인 리졸버 반환 mapping**: `EventParticipationGroup` 처럼 `Omit<X, 'backgroundScheme' | ...> & { backgroundScheme?: Maybe<Union> }` 형태로 codegen 된 parent 타입을 반환하는 mapper 는, 반환 타입을 `ResolversParentTypes['X']` 로 **명시적으로 annotate** 하면 union discriminator (`{ type: 'SOLID' | 'GRADIENT' }`) 가 제대로 좁혀진다. 생략하면 `schema.X` (default model) 로 추론돼 union 필드에서 구조 불일치가 난다.

## References

- `references/event-detail.md`: event detail operation split and books-islands verification notes.

## 관련 skill

- `ridi-project-structure` — 앱 등록·`/graphql` 마운트·경로 인덱스
- `ridi-islands-structure` — books-islands에서 gql-client-codegen 훅·`createQuery` 등
- `ridi-event-structure` — r-bus와 별개인 GraphQL 계약; 이벤트/구독자와 연계할 때 경계 구분
- `ridi-db-schema` — 리졸버에서 조회하는 테이블 위치
- `ridi-test-guides` — 리졸버 `*.test.ts` 패턴
