# 상품&결제팀 코드 컨벤션

RIDI 상품&결제팀이 공통으로 쓰는 코드 작성 컨벤션이다. 에이전트(Claude/Codex 등)와 사람 모두 이 문서를 따른다. 규칙마다 "왜"를 짧게 붙였으니, 상황이 규칙과 맞지 않으면 그 이유에 비춰 판단한다.

환경 셋업·Git 운영·개인 툴링·도메인 지식은 이 문서 범위 밖이다.

---

## 1. 공통 원칙

- YAGNI를 지킨다. 요청받지 않은 기능·추상화·설정 여지를 미리 만들지 않는다.
- 문제를 푸는 최소 코드로 끝낸다. 200줄이 50줄로 될 것 같으면 다시 쓴다.
- 최소 변경만 한다. 고쳐야 하는 것만 고치고 인접 코드·주석·포맷을 겸사겸사 손대지 않는다. 내 변경이 만든 orphan(안 쓰이게 된 import·변수)만 정리하고, 원래 있던 dead code는 발견만 알리고 지우지 않는다.
- 타입·함수를 섣부르게 쪼개지 않는다. 처음엔 책임이 명확히 갈리지 않는 한 하나로 쓰고, 리팩터링할 지점은 작업 후 따로 제안한다.
- 구현 전에 가정을 명시한다. 해석이 여럿이면 하나를 조용히 고르지 말고 펼쳐 놓고, 더 단순한 방법이 있으면 말하고, 막히면 멈추고 무엇이 불명확한지 묻는다.

## 2. 네이밍

- 무의미한 suffix(`~info`, `~rows`, `~data`, `~fetched`, `Info`, `process`)를 붙이지 않는다.
- 축약어를 쓰지 않는다. `paymentMethods`를 `pm`, `entries`를 `e`로 줄이지 않고 loop/클로저 변수도 풀네임. 예외: ① `id`·`db`·`url`처럼 굳어진 약어, ② HTTP/RPC 핸들러의 `req`/`res`, ③ `import * as q from './queries'` 같은 import 네임스페이스 별칭.
- DB 컬럼이 축약형이어도 TS 변수/필드/SELECT alias는 풀 도메인 워드: `t_id → transactionId`, `b_id → bookId`, `u_idx → userIdx`(`idx`는 예외 약어라 유지). 컬럼 자체가 축약이 아니면 일반 camelCase(`coupon_id → couponId`).
- 이름은 변수가 실제 담는 값을 묘사한다. `current`/`pre`/`all` 같은 수식어는 실제 의미를 가리키지 못하면 붙이지 않는다.
- boolean은 predicate처럼(`isPreChargeAvailable`). 이중 부정(`!hasNoXxx`)은 금지.
- enum 이름은 DB 값과 별개로 정확한 도메인 워드. DB가 legacy 값(`'DOWNED'`)이어도 enum 이름은 `DOWNLOADED`, 값만 `'DOWNED'`.
- 이름만으로 뜻이 통하게 짓는다. 이름의 의도를 설명하는 주석(`// 'A' for auto button`)이 필요하면 이름이 잘못된 것이다(→ `autoDownloadButton`). `data2`·`tmp`·`result`처럼 값을 안 담는 이름 대신 실제 내용을 쓴다(예: 정산 완료된 거래 목록이면 `settledTransactions`).
- map 네이밍은 `aToBMap`(a=key, b=value) 형태 + `Map` suffix 필수(`codeToEntriesMap`). lodash `groupBy` 결과 등 plain object도 동일.
- 언어별: PHP 변수/인자는 `snake_case`, PHP 함수명은 `camelCase`. TS 변수/함수/쿼리 select alias는 `camelCase`. 파일·폴더명은 기본 `camelCase`지만 영역별로 다르다 — 예를 들어 subscribers는 kebab-case를 쓰기도 하고, 파일명을 대표 함수명 그대로 두는 곳과 함수의 범주를 파일명으로 쓰는 곳이 섞여 있다. 새 파일은 이름 규칙을 새로 정하지 말고 같은 디렉토리의 기존 컨벤션을 따른다.
- UI 용어(`badge`, `stamp`)를 DB/proto에 두지 않는다(→ `reward_label`). 한 개념엔 한 단어로 통일.

## 3. 코드 스타일

- `const` 우선. 조건부 1회 대입은 ternary/`?? fallback`, 콜백 캡처는 `return`해서 바깥에서 `const`로 받는다. `let`은 실제 여러 번 재할당할 때만.
- `function` 선언 대신 `const name = (...) => {}` 화살표 함수. React 페이지도 `const Page = () => {}; export default Page;`. 예외: 클래스 메서드·generator·`this` 매개변수.
- if/else 본문이 1줄이어도 중괄호를 쓴다.
- 함수 시그니처·interface 속성 순서: non-function 값 먼저(있으면 `id`/`key`를 맨 앞) → function 값 마지막, 각 그룹 안에서 알파벳 순. 리턴 객체는 shorthand 먼저, non-shorthand 나중.

## 4. 타입 안전성

- `!= null`/`== null`/truthy 체크로 존재 판단 금지 → `isDefined(x)`(`ridi-backends/utils`) 또는 명시적 `x !== undefined`. enum·숫자는 `0`이 유효값일 수 있어 특히 주의.
- fallback은 `||` 대신 `??`(0/빈값이 안 덮이게). optional은 `?`.
- 불필요한 명시적 타입 주석을 달지 않고 추론에 맡긴다. 공개 API·모듈 경계·의도적 와이드닝만 명시. 사용처 1곳인 helper interface도 인라인/추론으로 둔다.
- `// biome-ignore`·`// eslint-disable`·`// @ts-ignore`·`// @ts-expect-error` 같은 억제 코멘트를 남기지 않는다. `x!` + biome-ignore 조합 금지. type guard로 좁히거나 분기를 다르게 짠다.
- enum/status/type/string literal union 값을 추가하면 diff 밖 sibling 사용처(switch, allowlist, dropdown, DB, proto/GraphQL 변환, FE 표시)까지 grep해 누락을 확인한다.
- 경계(PHP↔JSON↔TS, DB bigint↔JS number/string, proto/GraphQL scalar, Date/string/timestamp)에서 coercion으로 hash·비교·정렬·ID 매칭이 깨지지 않는지 확인한다.
- proto3 enum 첫 값은 `_UNSPECIFIED = 0`. `optional` 필드는 부재 시 `0`/빈값 대신 `undefined`를 반환하고(구체 값이 wire에 실리면 FE가 epoch 등으로 오해석), 검증도 `undefined`를 무조건 거부하지 않는다(draft/clear 저장이 깨짐). 상호배타 payload는 `oneof`로 모델링.

## 5. 쿼리 & DB (queries.ts)

- `queries.ts` 함수는 순수 knex query builder만 리턴한다. `.transacting(trx)`·`.forUpdate()`·DB formatting·실행은 호출부(`index.ts` 등)가 담당하며, 호출부가 `trx`를 optional 인자로 받아 각 쿼리에 체이닝한다.
- query builder를 리턴하지 않는 함수(여러 쿼리 + 도메인 로직)는 `queries.ts` 바깥으로 옮긴다. 함수명은 `findXxx`/`insertXxx`/`updateXxx`, `buildFindXxxQuery` 같은 suffix 금지. `queries.ts`에는 colocated `queries.test.ts`를 둔다.
- select alias는 object 매핑으로: `.select({ userIdx: 'tb_user.idx' })`. SQL 문자열에 `as`를 끼우지 않는다(`'tb_user.idx as userIdx'` 금지). 같은 쿼리의 여러 컬럼은 한 object에 다 묶는다. 컬럼명을 그대로 camelCase 변환만 하면 되면 `selectAsCamelCase()`. `queries.ts` 결과는 camelCase로 fetch하는 것을 기본으로 한다.
- table alias(`{ alias: 'e' }`, `as pm`)를 쓰지 않는다. grep·refactor를 위해 항상 풀 테이블명(`tb_xxx.column`). self-join처럼 별칭이 의미를 가질 때만 도메인 풀네임 alias.
- 리턴 타입은 모듈 밖에서도 쓰일 때만 `export interface`로 분리. 사용처가 1곳이면 `.select<{ ... }[]>(...)` 인라인 타입.
- auto increment PK는 `bigint unsigned`. 비자명한 컬럼엔 column comment.
- 배치·CMS 조회는 replica. bulk 조회 우선(유저·메시지별 반복 조회 금지), 동시성은 `pLimit` + `Promise.all`.

## 6. 트랜잭션

- trx 안에서 외부 API(rBus publish, 외부 HTTP/RPC)를 호출하지 않는다. outbox → subscriber로 분리하거나 commit 이후로 옮긴다. 결과가 필요 없으면 `runAsync()`로 fire-and-forget.
- trx 안에서 `Promise.all`로 병렬화하지 않는다. 같은 trx는 병렬 이득이 없고 deadlock 위험이 있으니 `for-of` 순차 실행.
- ridiPrimary/ridiReplica 트랜잭션은 repeatable read라 같은 스냅샷을 본다. 점유 시간을 늘리는 로직(외부 호출 등)을 트랜잭션 안에 두지 않는다.
- subscribers·backends 핵심 로직에서 insert하는 경우처럼 race condition 발생 여지가 있는 부분은 한 번 더 검토하고, 필요하면 `for update`로 잠근다(gap lock side effect 고려).
- 핸들러·호출부는 `Date`나 unix timestamp를 그대로 넘기고, KST 변환 등 DB formatting은 쿼리(`queries.ts`) 안에서 한다. 핸들러에서 미리 string으로 바꾸지 않는다.

## 7. 예외 / 에러 처리

- 정말 `undefined`가 없다고 보장되는 지점에서만 `assertIsDefined(data, 'msg')`로 단언한다. 값이 없을 수 있는 정상 흐름은 assertion이 아니라 분기로 처리하고, `if (!data) throw new Error(...)`를 직접 쓰지 않는다.
- 에러 로깅은 `errorHandler`(Sentry 전송). `console.error`로 삼키지 않는다.
- Custom `Error` subclass는 호출부에 `e instanceof XxxError` 분기가 실제로 있을 때만. 기본은 `Error`, extra 메타데이터가 필요하면 `ExtraError`.
- Date/Time 헬퍼를 새로 만들지 않는다. backends는 `backends/src/utils/date.ts`의 `unixTimestamp`·`formatKST`/`formatKSTDB`·`parseKST` 등을 쓴다. `Math.floor(d.getTime()/1000)` 직접 작성·1-line 래퍼 신규 생성 금지. 프론트·백오피스·books-backend에서도 각 스택의 기존 date 유틸을 찾아 쓰고 새로 만들지 않는다.

## 8. 죽은 코드 / 오버엔지니어링

- 사용처 없는 코드를 추가하지 않는다. 신규 함수/타입은 같은 PR 안에 production 사용처가 최소 1개 있어야 하고, 사용처가 1곳이면 inline 우선. premature abstraction 금지(두 번째 사용처가 실제로 생긴 시점에 추출).
- 다른 계층이 보장하는 불변식을 다시 검사하지 않는다(불필요 방어 코드 제거). 동작하지 않는 코드는 유지하지 말고 필요할 때 새로(YAGNI).
- 단순 wrapper·과한 추상화·불필요 옵셔널/`default` 지양.
- `class`를 새로 만들지 않고 함수 + 네임스페이스 import로 모델링한다(`ivCrypto.encrypt()`는 plain object나 `import * as ivCrypto`로). 인스턴스 lifecycle/내부 상태가 정말 필요할 때만 class.

## 9. 책임 분리 / 구조

- 공통 유틸/계층에 도메인·사용처 한정 코드(feature flag 헬퍼 포함)를 두지 않는다.
- 애플리케이션 간 참조 금지: `cli → apps/` import 금지. 공통은 `ridi-backends/utils`.
- 계층별 책임을 지킨다. GQL mutation/resolver는 자기 도메인의 읽기·쓰기만 담당하고, 여러 도메인에 걸친 집계나 리워드 지급 같은 후속 처리는 이벤트를 발행해 subscriber로 모은다. 한 핸들러가 남의 도메인 테이블까지 직접 건드리지 않는다.
- test-only export가 생기는 모듈은 디렉토리로 만들고 `index.ts`를 public facade로 둔다. `index.ts`는 외부 import 심볼만 re-export하고, 내부 구현은 형제 파일에 export해 colocated 테스트가 직접 import한다.
- 함수 파라미터를 필요 이상으로 넘기지 않는다. Map(lookup map 포함)을 파라미터나 리턴 타입으로 넘기지 않고, 원본 컬렉션을 받아 안에서 꺼내 쓴다.
- lodash `groupBy`/`sortBy`/`keyBy`/`uniqBy`는 string key 대신 화살표 함수를 넘긴다(`groupBy(entries, (entry) => entry.code)`).

## 10. 주석

- 코드 주석은 그 파일/디렉토리의 기존 언어를 따른다(대부분 영어면 영어, 한국어면 한국어, 관례 없으면 영어). 한쪽 언어를 강제하지 않는다.
- 처음 보는 사람이 이해할 수 있게, 무슨 일이 일어나고 왜 그렇게 했는지 풀어 쓴다. 압축 표현(`presence-based`, `null로 surface`)이나 헬퍼 이름 나열 금지.
- 여러 줄 주석은 문장 끝 마침표에서 줄을 바꾼다. 편집기 폭에 맞춘 임의 wrap 금지.
- 변경 이력 주석("기존 X를 개선") 금지, 현재 동작만 설명한다. 맥락 없는 주석(`Phase N`, 좌표, `Step 3`, AI 흔적)도 금지. 코드로 읽히는 주석은 지운다. proto 필드가 주석 없이는 이해 안 되면 주석 대신 이름을 고친다.
- 굳어진 영어 기술 용어(`feature flag`, `outbox`, `transaction`, `subscriber`, `rollback`)를 억지 번역/음차하지 않는다. 영어 단어에 한글 접두사(미-, 비-)를 붙인 혼종 신조어("미커밋") 금지, 상태를 풀어 쓴다("아직 커밋되지 않은").
- PR 본문·GitHub 리뷰 코멘트/답글은 파일 주석 언어와 무관하게 항상 한국어.

## 11. 테스트

- fixture는 `ridi-backends/test/builders`의 test builder(`createTbXxxBuilder()`)로, 시나리오에 중요한 필드만 override. auto-increment PK를 상수로 하드코딩하지 않고 생성된 id를 받아 검증한다.
- 실제 fixture로 실행 검증한다. 함수 호출 여부만 확인하지 말고 mutation 후 다시 query해서 row 형태를 assert.
- `describe(함수/기능)` + `it(시나리오 하나)`, describe/it 이름은 영어. AAA(Arrange/Act/Assert)를 빈 줄로 구분. stub 명명은 `함수명 + Stub`.
- Knex 쿼리 모듈은 `queries.test.ts`에서 `toQuery()`로 SQL 형태·필터·정렬을 고정. Route/handler는 Supertest로 인증·응답 형태·feature flag 분기. `queries.test.ts`가 커버한 SQL을 API 테스트에서 중복하지 않는다.
- fixture 배치는 `dbFixtureHooks`(describe당 1회) / `dbFixtureHooksEach`(it마다). 부모가 `dbFixtureHooksEach`면 자식도 `dbFixtureHooksEach`. alias는 테이블명(`tb_event_group`).
- 시나리오마다 sub-describe를 분리해 자기 데이터·fixture·it을 둔다. 값이 중요한 row(pagination·ordering)는 `.map()`/`.find()`나 공용 `insertX()` 뒤로 접지 말고 fixture 블록에 펼친다. 파생 fixture 헬퍼(다른 테이블 읽어 자동 생성) 지양.
- feature flag는 `mockFeatureFlag()`(수동 `sinon.stub` 지양), on/off 양쪽 커버, 경로는 `describe('with <flag> on')` 경계에서 분리.
- sinon sandbox를 수동 관리하지 않는다. 글로벌 `afterEach`의 `sinon.restore()`가 fake timer 포함 default sandbox를 복원하므로 개별 sandbox·개별 restore·`clock.restore()`를 직접 부르지 않는다.
- 결정적 payload는 부분 assertion 여러 개보다 full-shape `deep.equal` 하나. 비결정 필드(timestamp, 생성 id)만 부분 검사.
- 시간은 시간대를 명시한다(`new Date('2026-06-20T10:00:00+09:00')`). 재사용 시점은 `Date` 객체로 보관하고 사용처에서 `formatKSTDB`로 변환. 테스트 실패·빌드 실패·lint 에러가 없는 상태로만 커밋.

## 12. Feature Flag

- flag key는 `backends/src/utils/featureFlags/values.ts` 한 곳에 정의하고 import한다(문자열 산재 금지). 여러 런타임이 공용해도 같은 키 문자열.
- 신규 key는 `productpay-<content>-<YYYYMMDD>` prefix.
- 읽을 때 `getFeatureFlag`(sync)를 쓰고 `fetchFeatureFlag`(async)를 신규 추가하지 않는다. 라우팅 분기는 `featureFlagRouter('flag', subRouter)`.
- 유저 사이드 영향이 있는 작업은 기본적으로 flag 도입을 고려한다. on/off는 GrowthBook.

## 13. React / 프론트엔드

- 파생 상태는 state·effect가 아니라 렌더 중 계산한다. state 미러링 + `useEffect` 동기화는 stale·이중 렌더의 근원.
- memoize는 기본값이 아니다. `useMemo`/`useCallback`은 계산이 실제로 비싸거나 참조 동일성이 필요할 때만. 원시값 파생·비교 몇 번은 인라인이 정답.
- `useEffect`는 외부 시스템 동기화 전용(구독·타이머·수동 DOM·fetch). 이벤트 응답은 핸들러에서, props→state 변환은 렌더 중 파생으로. `exhaustive-deps`를 끄지 않는다.
- 폼 값은 react-hook-form이 SSOT. 별도 `useState`로 복제하지 않고 `useWatch`/파생으로 읽는다. `setValue`는 필요하면 `{ shouldDirty: true, shouldValidate: true }` 명시.
- 리스트 key는 안정적 식별자. index key는 순서 변경·삽입/삭제에서 상태를 꼬이게 한다.
- 렌더 경로에서 throw하지 않는다. 운영자 입력(색상·URL 등) 검증 실패는 렌더를 중단하지 말고 fallback/default로. 필요하면 로깅/트래킹.
- SSR/hydration 안전하게: client-only 코드는 조건부 렌더로 보호(`window` 사용 컴포넌트는 데이터 준비 전 `null` 반환).

## 14. Git · 커밋 · PR

- 커밋 메시지는 `[scope] 설명 (#PR)` 형태의 간결한 한 줄. scope는 영향받은 프로젝트, 설명은 한국어. 예: `[web] 이중호출 제거를 위해 payment 요청 backends 직결 (#28165)`. multi-line 지양.
- merge conflict 해결 마무리 커밋은 `--no-verify`로 실행한다. 대량 변경 때문에 lint-staged hook이 무관한 파일에서 죽으면 git index가 손상될 수 있다.
- PR 본문에는 배경(왜 필요한지, 문제·현재 한계)과 개요(무엇을 했는지 요약)를 둔다. 코드 변경을 1:1로 나열하지 않고, 추가 설명이 필요하면 본문을 늘리지 말고 해당 diff 위치에 인라인 코멘트를 단다.
- stacked PR은 배경·배포 순서 섹션을 모든 PR에 동일하게 첨부해 각 PR만 봐도 전체 맥락과 위치를 알 수 있게 한다.
- PR 제목은 구체적이고 짧게. `update`·`misc`·`fix stuff`처럼 범위가 흐린 단어를 피한다.

## 15. 코드 리뷰 & 코멘트

- 코멘트는 결론 + 근거 1~3문장으로 간결하게. 순서는 관찰한 사실 → 생길 수 있는 문제 → 수정 방향/확인 요청.
- 톤은 팀 동료에게 말하듯 존댓말, 제안형("~하면 좋겠습니다", "어떨까요?"). 명확한 버그는 흐리지 말고 무슨 문제가 생기는지 먼저 설명한다. 추궁·명령·자동응답형 감사("좋은 지적 감사합니다")를 피한다.
- 확신이 낮은 지적은 단정하지 말고 "확인 요청" 톤으로 낮춘다.
- 사소하거나 후속으로 넘겨도 되는 항목은 "이번 PR에서 안 해도 됨", "optional로 봐주세요"로 우선순위를 표시한다.
- 정책·기획이 모호한 지점은 리뷰어가 직접 결정하지 말고 기획자 확인 요청으로 남긴다.
