---
name: ridi-backoffice-structure
description: renewed RIDI Backoffice 작업 시 사용. 프론트·백엔드·proto·gRPC·페이지 폴더 컨벤션(단순 CRUD~복잡 허브)과 검증 진입점. event/management는 최대 복잡도 예시로만 참고.
---

# RIDI Backoffice 구조

renewed Backoffice 작업용 인덱스 스킬이다.

프론트 페이지, gRPC API, proto, auth, 그리드, 폼, 로컬 검증을 수정하기 **전에** 읽는다.

**중요:** `event/management`의 풀 허브 구조(`schemas.ts` + `binding.ts` + `group/hooks/` 등)는 Backoffice **표준이 아니다**. 새 작업은 아래 **도메인 복잡도**를 먼저 고르고, 인접 도메인을 복제한다.

## 사용 시점

- `internal-products/frontends/backoffice` 또는 `internal-products/backends/src/backoffice` 작업
- `internal-products/backends/backoffice` 언급 → `internal-products/backends/src/backoffice`
- Backoffice 페이지 ↔ gRPC 연결, proto 추가·변경, 파일 배치 결정

## 핵심 경로

| 용도 | 경로 |
| --- | --- |
| 프론트 패키지 | `internal-products/frontends/backoffice` |
| 라우트 트리 | `src/routes/index.tsx` |
| 페이지 | `src/pages/` |
| 사이드 네비 | `src/layouts/defaultLayout/config-navigation.tsx` |
| gRPC-Web | `src/hooks/useGrpcTransport.ts` |
| 백엔드 앱 | `internal-products/backends/src/backoffice` |
| 컨트롤러 | `src/backoffice/controllers/` |
| proto 소스 | `internal-products/proto/ridi/backoffice/**/*.proto` |
| Nest codegen | `ridi-internal-proto-lib-nestjs` |
| FE codegen | `ridi-internal-proto-lib-protobuf-ts` |
| proto 로딩 | `base/grpc/protoPath.ts`, `packages.ts` |
| gRPC 에러 헬퍼 | `internal-products/backends/src/utils/grpc.ts` |

## 프론트엔드 맵

- 패키지: `backoffice-frontend`, Vite + React CSR, basename `/backoffice/`
- API: GraphQL 아님 → `useGrpcTransport()` + `*ServiceClient` + `react-query`
- 라우트: `routes/index.tsx` lazy `PageXxx` 등록. 네비 노출 시 `config-navigation.tsx`도 수정
- UI: `@/components/DataGrid`, `SearchForm`, snackbar/loading 우선 — `frontends/backoffice/.cursor/rules/data-grid.mdc` 참고
- path alias: `@/*` → `src/*`

## 백엔드 맵

- NestJS gRPC microservice. `app.module.ts`에 컨트롤러 직접 등록
- 폴더: `controllers/<domain>/<feature>/` — 보통 `index.ts`, 선택 `queries.ts`, `utils.ts`, `const.ts`, `types.ts`, `test/`
- `binding.ts`는 **복잡 CRUD만** (전체 controllers 중 소수)
- DB: Knex (`ridiPrimary` 등), 스키마는 `backends/src/db/schemas/`
- 인증: `@Resource`, `@Scopes` (`base/nestjs/auth`)

## 페이지 폴더 컨벤션 (공통)

기본 진입 형태:

```
pages/{top-domain}/{feature}/{list|create|detail|...}/index.tsx
```

- 화면 래퍼: `<Page />` + MUI `Card` / `Stack` 패턴이 많음
- `components/`: 대부분 도메인에 존재. 깊이는 기능 복잡도에 비례 (flat ~ 3단 nested)
- **서브피처 중첩** (`feature/components/foo-bar/`)은 event·books·genre-home처럼 **이미 그렇게 된 도메인**에서만 따르고, 새로 만들지 않는다

### 공유 파일 — 있으면 좋지만 필수 아님

| 파일 | 역할 | 흔한 위치 |
| --- | --- | --- |
| `queryKey.ts` / `queryKeys.ts` | react-query 캐시 키 factory | 도메인·기능 루트 (명명 혼재 주의) |
| `types.ts` | UI·폼 타입 | 도메인 루트 |
| `const.ts` / `consts.ts` | 상수·옵션 목록 | 도메인 루트 |
| `schema.ts` / `schemas.ts` | yup 검증 | **복잡 폼 도메인만** (pages 전체 중 소수) |
| `utils.ts` | 포맷·변환·에러 매핑 | 도메인 루트 |
| `binding.ts` (FE) | 폼 → gRPC 요청 조립 | OSMU·event·point-auto 등 |
| `hooks/` | API·폼 훅 | 도메인 루트 또는 화면 하위 |

**배치 원칙**

- `schemas.ts`가 `utils.ts`를 import하면 순환 참조 위험 → **상수는 `consts.ts`**, 스키마는 `schemas.ts`, 변환·에러는 `utils.ts`
- 화면이 하나이고 폼이 단순하면 `list/schema.ts`, `detail/hooks/`처럼 **화면별 분산**이 더 흔함 (cs, crm)

## gRPC + react-query 패턴 (표준)

모든 도메인에서 사실상 동일:

```typescript
const { transport } = useGrpcTransport();
const client = new XxxServiceClient(transport);

useQuery(queryKeys.list(params), () => client.list(...));
useMutation((req) => client.upsert(req), { onSuccess: () => invalidate... });
```

훅 배치 **3가지 변형** (인접 도메인에서 하나 선택):

| 변형 | 예시 | 언제 |
| --- | --- | --- |
| 페이지/기능 인라인 | `search/boost/hooks/`, `stat/sales-rank` | read-heavy, 훅 1~2개 |
| 도메인 `hooks/` + barrel | `store/seo/hooks/index.ts`, `osmu/sale-file/hooks/` | CRUD·목록·상세 여러 화면 |
| `*Client` 훅 분리 | `finance/pre-royalty/bundle/useBundleClient.ts` | 같은 client를 여러 mutation/query가 공유 |

`queryKey` factory 예: `{ all, list(params), detail(id) }` — `pages/event/management/queryKey.ts`, `pages/osmu/contract/queryKeys.ts`

## binding 사용 기준

| 위치 | 용도 |
| --- | --- |
| FE `pages/.../binding.ts` | 폼 state → gRPC request (다단계 폼, 반복 필드) |
| BE `controllers/.../binding.ts` | DB row ↔ proto (조인·nested message) |

proto 필드 ≈ DB 컬럼이면 binding 없이 controller에서 직접 매핑하는 경우가 많다 (rainy-day, stat, cs 등).

## 도메인 복잡도별 유형

새 기능 추가 시 **먼저 유형을 고른다**. event 패턴을 무조건 복제하지 않는다.

| 유형 | 설명 | 참고 경로 |
| --- | --- | --- |
| **A — 단순 CRUD** | `hooks/` + `queryKey`, schema/binding 없거나 최소 | `store/seo`, `reward/point/rainy-day` |
| **B — OSMU형 허브** | 도메인 루트 `schemas`·`binding`·`hooks` barrel | `osmu/contract`, `osmu/sale-file`, `reward/point/point-auto` |
| **C — 대형 멀티 서브피처** | 서브폴더별 `components/`·hooks, 거대 controller | `books/discount-event` |
| **D — UI 편집기** | Context, 깊은 nested `components/` | `genre-home/views` |
| **E — 화면별 분산** | `list/schema.ts`, `detail/hooks/` — 공유 허브 거의 없음 | `cs/user`, `crm/abuse` |
| **F — 최대 복잡도 (event)** | 다중 서브피처 + 공유 mega layer + BE controller 분할 | `event/management` (아래 예시) |

## Proto · gRPC 작업 흐름

- proto 변경 → `pnpm build` (`internal-products/proto`) 또는 `pnpm --filter ridi-internal-products-proto build`
- `protoPath.ts`, `packages.ts`, controller, `app.module.ts` 동시 갱신
- FE: codegen import 경로 grep으로 stale 제거

### 서비스/proto 통합 시 순서 (도메인 공통)

1. proto merge + codegen
2. BE handler 이전, 구 controller·protoPath 제거
3. FE `*ServiceClient`·hook 교체
4. BE queries/binding/test merge, 구 폴더 삭제
5. FE 파일 flat·허브로 정리 (필요 시만)

## gRPC 폼 에러 (공통)

- Backoffice 폼 검증용 **proto error enum 추가 금지**
- BE: `createInvalidArgumentError(message)` (`utils/grpc.ts`)
- FE: `utils.ts`에서 메시지 부분 문자열로 `setError` — 미매핑은 snackbar만
- BE가 FE 파싱용 메시지 포맷에 의존하면 카피 변경 시 포맷 유지

## 백엔드 테스트

- `InvalidArgument`: `rejectedWith` + **메시지** (proto enum `expectErrorCode` 지양)
- 폴더 이동 시 `*.test.ts` 같은 커밋 단계에서 merge
- 한글 assert 메시지 고정된 테스트 많음 — validation 문구 변경 시 테스트 동시 수정

## 검증 명령

| 영역 | 명령 |
| --- | --- |
| 프론트 dev/lint | `internal-products/frontends/backoffice` → `pnpm dev` / `pnpm lint` |
| 프론트 tsc | `pnpm exec tsc --noEmit` |
| 백엔드 dev/test | `internal-products/backends` → `pnpm start:bo` / `pnpm test:bo` |
| proto | `internal-products/proto` → `pnpm build`, `pnpm test` (buf, baseline 주의) |

## 로컬 기동 체크리스트

1. QueryPie DB 터널 `127.0.0.1:40032`
2. `backends` → `pnpm docker:infra` (gRPC-Web `9090`, Redis, Kafka)
3. `pnpm start:bo` → `Nest microservice successfully started`, `8088`
4. `pnpm dev` → `http://localhost:5173/backoffice/`
5. `upstream connect error` → `9090`·`8088`. Kafka `9092` dead 시 `kafka.init()` 블로킹

## 작업 규칙

- 인접 도메인·동일 유형(A~F) 폴더를 먼저 연다
- 네비 노출: `routes/index.tsx` + `config-navigation.tsx`
- `ridi-graphql-structure` 아님 — internal proto + gRPC-Web
- 다단계 리팩터: `.cursor/docs/`에 phase 메모 (파일 매핑, 검증 명령)

---

## 예시: 복잡 도메인 `event/management` (유형 F)

이벤트만의 **최대 구성**. 다른 도메인에 그대로 적용하지 말 것.

### event만의 특징

- 서브피처 `event/`, `group/`, `components/`가 **같은** `schemas.ts`·`utils.ts`·`queryKey.ts` 공유
- `group/hooks/` — react-hook-form + yup + dirty store + navigate orchestration (**event 전용**)
- BE controller 분할: `event/`, `event-group/`, `eventScheduledBanner/`
- 그룹 타입(notice, book, calendar, image, participation) — 형제 타입 패턴 복제

### event 프론트 레이아웃

| 계층 | 경로 |
| --- | --- |
| 허브 | `pages/event/management/` — `schemas`, `types`, `utils`, `consts`, `binding`, `queryKey`, `hooks/` |
| 그룹 UI | `group/components/` — **flat** `EventGroup{Type}*.tsx` |
| 복잡 폼 hook | `group/hooks/` (participation 등) |

네이밍: `EventGroup{Feature}*`, `EventGroup{Feature}Schema`, 상수는 `consts.ts`

### event 그룹 API hook

`useEventGroupNotice.ts` / `useEventGroupParticipation.ts` 참고:

- 조회: `getEventGroupDetail` + `eventGroupDetailKeys` (타입별 detail key 추가 금지)
- 저장: `EventGroupService` 타입별 upsert RPC, `Empty`
- 삭제: `deleteEventGroup` — **그룹** 삭제 UX, list invalidate + `/event/management/detail/:eventId/groups`

### event 백엔드

- 로직 colocate: `controllers/event/management/event-group/` (`index`, `queries`, `binding`, `utils`, `consts`)
- 공용 비즈 헬퍼: `src/backoffice/utils/` (예: `color.ts`)
- `deleteEventGroup` + participation: 트랜잭션 내 participation soft-delete 후 그룹 삭제

### event 리팩터 참고 문서

- `.cursor/docs/event-participation-refactor-phase-*.md`
- proto 통합·FE flat·error code 제거 순서는 해당 plan/docs 참고

---

## 관련 스킬

- `ridi-project-structure` — 앱 경계·메인 백엔드
- `ridi-db-schema` — DB 스키마
- `ridi-test-guides` — 백엔드 테스트
- `ridi-graphql-structure` — 메인 GraphQL (Backoffice 아님)
