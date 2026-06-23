---
name: review-pr
description: RIDI 백엔드(backends/Node·TS, books-backend/PHP, proto, GraphQL, SQL)와 백오피스(internal-products/NestJS gRPC, backoffice proto, backoffice 프론트) PR을 리뷰할 때 사용하는 팀 리뷰 관점·판단 기준 체크리스트. 네이밍, 쿼리/DB 설계, 테스트, 책임 분리, 죽은 코드, 주석, PR 범위, Kafka subscriber, 타입 안전성, 백오피스 gRPC handler·feature flag·proto 메시지 설계 등 카테고리별 기준을 제공한다. PR 리뷰·코드 리뷰·변경점 점검·리뷰 코멘트 작성 요청 시 사용한다. 기존 /ridi-review-checklist 요청도 이 스킬로 처리한다.
---

# Review PR

RIDI 백엔드·백오피스 PR 리뷰 시 적용하는 팀 리뷰 관점. 변경 diff를 카테고리별로 훑으며 아래 기준에 어긋나는 부분에 코멘트를 단다.

## 적용 범위

- **backends** (`backends/`): Node·TS 서비스/배치/GraphQL/Kafka subscriber.
- **books-backend** (PHP): 결제·주문 등 레거시 PHP 도메인.
- **백오피스 (internal-products)**: NestJS gRPC microservice(`internal-products/backends/src/backoffice`), backoffice proto(`internal-products/proto/ridi/backoffice/**`), backoffice 프론트(`internal-products/frontends/backoffice`, Vite+React+gRPC-Web). 구조·경로 세부는 `ridi-backoffice-structure` 스킬 참조.
- 공통 변경물: proto, GraphQL SDL, SQL/스키마, Twig/TSX.

## 적용 방법

0. 리뷰 코멘트 문구를 작성하기 전에 `../../my-tone/SKILL.md`를 읽고, RIDI 리뷰 코멘트 톤과 pending review 규칙을 따른다.
1. 변경 파일 타입 파악 — 비중: TS(backends) ≈ NestJS(internal-products/backoffice) > PHP(books-backend) > SQL/proto/GraphQL/Twig/TSX.
2. 아래 **빠른 체크리스트**(거의 매 PR 반복)를 먼저 훑는다.
3. 변경 성격에 맞는 **카테고리별 판단 기준**을 적용한다. 백오피스 PR이면 **12. 백오피스**를 함께 본다.
4. 다파일·다관점 PR이면 `조사 / 병렬 에이전트 위임`으로 성격별 검증을 나눠 돌리고, 보고를 직접 재확인한다.
5. 코멘트는 **pending review로 모으고**(아래 `코멘트 게시 방식`), **`최소 코멘트 수 & Codex 교차검증 루프`를 돌려** 개수·품질을 맞춘다. 최종 문구는 `my-tone` 기준으로 다듬는다.

## 리뷰 전 공통 패스

코멘트를 달기 전에 아래를 먼저 확인한다. 이 단계는 finding을 늘리기보다, 틀린 코멘트와 stale 코멘트를 줄이기 위한 안전장치다.

- **PR 브랜치 로컬 체크아웃 고려**: diff만 보면 grep·read·에이전트 탐색이 어렵다. 현재 브랜치가 아닌 PR이면 `gh pr checkout <n>`(또는 worktree)으로 받아두면 전체 파일·sibling·스키마를 그대로 탐색할 수 있다. 체크아웃 후 `git status`로 워킹트리가 깨끗한지, head sha가 코멘트 기준과 같은지 확인한다.
- **base/head 확인**: PR URL/번호가 있으면 `gh pr view`로 base branch와 head commit을 확인한다. 로컬 diff만 볼 때도 최신 base를 fetch한 뒤 비교한다.
- **diff vs 워킹트리 stale 주의**: `gh pr diff`나 캡처해둔 diff 파일은 로컬 미커밋 변경보다 뒤처질 수 있다. `git status`로 워킹트리 변경을 확인하고, 로컬 WIP가 이미 고친 항목은 코멘트에서 빼며, 최종 코멘트 라인은 `gh pr view --json headRefOid`의 head sha 기준으로 다시 잡는다.
- **전체 diff 먼저 읽기**: 특정 hunk에서 의심이 생겨도 전체 diff를 먼저 훑고, 같은 PR 안에서 이미 해결된 문제는 코멘트하지 않는다.
- **scope drift 확인**: PR 제목/본문, commit log, 관련 plan/TODO가 있으면 의도한 범위와 실제 변경 파일을 비교한다. 무관한 설정·테스트 환경·리팩터링이 섞이면 `PR 범위 / 분리` 관점으로 본다.
- **기존 bot/comment 재검증**: Greptile/Cursor/기존 reviewer 코멘트가 있으면 그대로 반복하지 말고 current head 기준으로 라인과 코드가 여전히 같은지 확인한다. 이미 수정됐거나 전제가 틀리면 철회하거나 축소한다.
- **확신도 낮은 finding 보류**: 코드 라인으로 증명하지 못한 의심은 pending review에 바로 올리지 않는다. 필요하면 "확인 요청" 톤으로 낮추거나 사용자에게 먼저 공유한다.
- **주장의 근거 확인**: "다른 곳에서 처리됨", "테스트가 있음", "안전함"을 말하려면 실제 처리 코드나 테스트 파일을 읽고 근거를 갖춘다.

## 조사 / 병렬 에이전트 위임 (대규모 PR)

다파일·다관점 PR은 혼자 순차로 보기보다 성격별로 에이전트에 나눠 위임하면 빠르고 빠짐이 적다. 작은 PR은 생략하고 바로 본다.

- **가설 먼저, 위임 나중**: 먼저 전체 diff를 직접 읽어 의심 지점을 목록화한다. 가설을 세워야 위임 프롬프트를 구체적으로 쓰고, 돌아온 결과도 검증할 수 있다.
- **성격별 병렬 위임** (한 메시지에서 동시에 띄운다):
  - 컨벤션/체크리스트 위반 — sibling 파일과 비교해 컨벤션이 실재하는지까지 확인시킨다.
  - 런타임/경계 의심 — nullability, 타입 coercion, 호출 경로 대조 등 **구체적 질문 리스트**로 위임한다.
  - 테스트 커버리지 — `ridi-test-guides`를 먼저 읽고 그 컨벤션 기준으로만 판정하도록 명시한다.
  - 무음 실패 — silent fallback, catch 삼킴, 에러 전파 누락.
- **위임 프롬프트 필수 문구**: "추측하지 말고 실제 코드를 읽고 file:line 근거를 가져와라." 출력 형식은 file·라인·severity·검증한 근거(file:line)·1~2문장 rationale으로 고정한다.
- **에이전트 보고를 그대로 신뢰하지 않는다**: 단정적 코멘트로 올리기 전에 핵심 주장(미사용 export, 헬퍼/스키마 존재, nullability 등)을 직접 grep/read로 재확인한다. 오탐을 "비문제"로 떨어뜨리는 것이 이 단계의 핵심이다.
- 에이전트가 보고한 라인 번호는 stale일 수 있으니, 최종 코멘트 라인은 head sha 기준으로 다시 잡는다(위 `리뷰 전 공통 패스` 참조).

## 코멘트 게시 방식 (중요)

- **Reply로 즉시 달지 않는다.** 개별 코멘트를 바로 게시하지 말 것.
- **"Start a review" 방식(pending review)으로 모은다.** 모든 코멘트를 pending 상태로 쌓아두고, 마지막에 사용자가 직접 검토·수정·submit 하도록 남긴다.
- **각 코멘트 본문 끝에 `Sent by AI` 꼬리표를 붙인다.** `body`마다 마지막 줄에 빈 줄을 두고 `_Sent by AI_`를 넣는다 (형식은 `my-tone`의 `AI 작성 표기` 참조).
- `gh api`로 pending review 생성 흐름:
  1. head sha 확보: `gh pr view <n> --json headRefOid -q .headRefOid`. (diff/로컬 라인이 stale할 수 있으므로 `commit_id`는 반드시 이 head sha를 쓴다.)
  2. review payload를 JSON 파일로 만든다: `{ "commit_id": "<head sha>", "comments": [ { "path", "line", "side": "RIGHT", "body" }, ... ] }`. **`event` 필드는 넣지 않는다** — 빼면 PENDING으로 남는다.
  3. `gh api repos/<owner>/<repo>/pulls/<n>/reviews --input <file>`로 생성. 결과 `state`가 `PENDING`인지 확인한다.
  4. `gh api repos/<owner>/<repo>/pulls/<n>/reviews/<id>/comments -q length`로 코멘트 수가 의도대로 올라갔는지 확인한다.
  5. **submit은 하지 않는다.** "검토 후 직접 submit 해주세요"라고 사용자에게 알린다.
- 코멘트를 다 추가한 뒤에는 어떤 파일·라인에 무슨 코멘트를 남겼는지 요약해 사용자가 빠르게 확인할 수 있게 한다.

## 최소 코멘트 수 & Codex 교차검증 루프 (항상 적용)

이 루프는 두 가지를 동시에 건다: **최소 개수로 리뷰 깊이를 강제**하고, **격리된 Codex로 코멘트 품질을 거른다**. 둘은 상호보완한다 — 개수 목표는 더 많은 파일·관점·sibling을 보도록 탐색을 밀어붙이고, Codex는 단순 확인용·무의미·틀린 코멘트를 잘라낸다. 개수가 품질의 바를 낮추는 게 아니라, 탐색의 넓이만 키우는 구조라는 점이 중요하다.

**불변식(가장 중요)**: 다음 라운드에서 Codex가 이미 reject한 finding을 다시 올리지 않는다. drop 사유를 누적(`seen_rejected`)해 다음 발굴 패스에 피드백하고, "진짜 새" 이슈만 찾는다. 이게 깨지면 같은 약한 코멘트를 반복 양산하며 루프가 수렴하지 않는다.

### 1) 최소 개수 N 결정
- 사용자가 "최소 N개"를 명시하면 그 값을 쓴다.
- 없으면 PR 크기로 추정: 변경 LOC 기준 `<50 → 1~2`, `50~300 → 3~5`, `300~800 → 5~8`, `800+ → 8개 이상`. 파일 수가 많거나 도메인이 흩어지면 상향. 추정값은 한 줄로 알린다("크기상 ~N개 목표로 봅니다").

### 2) 사전 조건
- 루프 전 PR 브랜치를 로컬 체크아웃한다(`리뷰 전 공통 패스` 참조). Codex가 head sha 기준 실제 파일을 읽어야 판정이 정확하다.

### 3) 라운드 (validCount ≥ N 또는 dry 라운드 K=2 도달까지)
1. **발굴 패스**: 체크리스트·카테고리 기준으로 finding을 찾되 `seen_rejected`에 있는 건 제외한다. 새 finding이 없으면 `dry++` 후 다음 라운드로.
2. **pending review 갱신**: 새 finding을 `event` 없이 pending으로 추가한다(`코멘트 게시 방식`).
3. **Codex 교차검증 위임 (격리·read-only)**: `codex:codex-rescue` 서브에이전트(Agent tool, `subagent_type: codex:codex-rescue`)에 `--fresh`로 위임한다. **판정만** 시킨다.
   - 넘기는 것: PR 번호, head sha, pending 코멘트 목록(`path`·`line`·`body`·comment id). **내(Claude) 리뷰 근거나 추론은 넘기지 않는다** — Codex가 코드를 직접 읽고 독립적으로 판단해야 객관성이 산다.
   - 지시: "각 코멘트를 head sha의 실제 코드와 대조해 유효성 판정. 단순 확인용·무의미·틀린 코멘트는 `drop`(사유 포함), 유효하면 `keep`. 파일·PR을 수정하지 말고 판정 JSON만 반환." (read-only이므로 위임 프롬프트에 수정 금지를 명시 — 그래야 codex-rescue가 `--write`를 붙이지 않는다.)
4. **삭제 적용 (Claude)**: Codex가 `drop`한 코멘트를 `gh api -X DELETE repos/<owner>/<repo>/pulls/comments/<id>`로 지운다. drop 사유는 `seen_rejected`에 누적한다. (pending draft 코멘트가 이 엔드포인트로 안 지워지면, pending review 전체를 지우고 생존분만 재생성하는 방식으로 폴백.)
5. `validCount` = 남은 pending 코멘트 수. 증가가 없으면 `dry++`, 있으면 `dry=0`.

### 4) 종료·보고
- `validCount ≥ N`이면 종료. `dry`가 K에 닿으면 N 미만이어도 멈춘다(클린한 작은 PR에서 약한 코멘트를 억지로 채우지 않기 위함).
- **정직하게 보고**: "유효 코멘트 M개(요청/추정 N개). M<N이면 이 PR에서 더 끌어낼 유효 finding이 없었음." Codex가 무엇을 왜 drop했는지 요약한다. submit은 사용자가 직접 한다.

## 빠른 체크리스트 (최우선)

```
- [ ] 네이밍·언어별 컨벤션 (PHP snake_case / TS·쿼리 select camelCase / proto·enum 값은 주석 없이 이해되는 이름)
- [ ] queries.ts는 쿼리 빌더만 리턴 (.transacting·formatting·실행은 바깥, KST 등 DB 변환은 쿼리 안)
- [ ] 테스트는 test builder + 실제 fixture (stub·수동 PK 지정 지양, 도메인 mock 헬퍼 활용)
- [ ] 공통 유틸/계층에 도메인·사용처 한정 코드가 섞이지 않았는가 (feature flag 코드 포함)
- [ ] 사용처 없는 코드·동작 안 하는 코드·불필요 방어 코드 제거
- [ ] 맥락 없는 주석(Phase N, 좌표, AI 흔적) 제거
- [ ] 이 PR 범위에 무관한 변경(설정 파일 등)이 섞이지 않았는가
- [ ] enum/status/type 값 추가 시 diff 밖 sibling value 사용처까지 확인했는가
- [ ] PHP/JSON/TS/proto/GraphQL 경계에서 타입·날짜·ID coercion이 깨지지 않는가
- [ ] 날짜·기간·타임존 기준이 관련 기능끼리 일관적인가
- [ ] (백오피스) handler가 대상 존재·타입을 검증하는가 / legacy vs new 컬럼을 올바로 보는가
```

---

## 카테고리별 판단 기준

### 1. 네이밍 (가장 빈번)
- **확장성**: 특정 케이스에 묶인 이름 지양. 새 액션/타입 추가 시 또 고쳐야 하면 NG.
- **언어 컨벤션**: PHP 변수 `snake_case`, backends 쿼리 `select`는 `camelCase`.
- **축약어 금지**: `dp`→`decimal_places`, `bg`→`background`. 쿼리 alias(`cc`, `et`)를 함수·변수명에 넣지 않기.
- **이름만으로 이해 가능**: enum/식별자 값에 `// 'A' for auto button` 같은 해설 주석이 필요하면 NG → `Button`/`Image`처럼 값 자체가 의미를 담게.
- **prefix/postfix 느낌 지양, 의미 구체화**: `before_text`/`after_text`는 prefix/postfix처럼 읽힘 → `before_participation_text`/`after_participation_text`, `before_event_start_image`/`after_event_end_image`처럼 "무엇의 전/후"를 담기.
- **이름 = 동작**: `onConflict ignore`면 `upsert`가 아닌 `insert`. boolean 판별 함수면 의미가 정확한지.
- **불용어 제거**: `~data`, `~fetched`, `~row`, `Info`, `process` 등 정보 없는 수식어.
- **시제**: 로그성은 p.p(`created_at`), 미래 담기면 `start_at`/`end_at`.
- **계층 분리**: UI 용어(`badge`, `stamp`)를 DB/proto에 두지 않기 → `reward_label` 등.
- **도메인 용어 통일**: 한 개념에 한 단어(`raffle` vs `slot`, `participation` vs `check_in`).

### 2. 쿼리 & DB 설계
- **`queries.ts` 패턴**: 쿼리 빌더만 리턴. `.transacting(trx)`·DB formatting·실행은 호출부에서.
- **재사용보다 최적화**: 쿼리는 공통 유틸로 빼지 말고 디렉토리 내 inline 정의(필요 컬럼만 select).
- **`EXPLAIN` 근거**: filesort/full scan/index intersect/covering index 등 실행계획을 확인하고 첨부. (세부 절차는 `mysql-query-optimizer` 스킬 참조)
- **인덱스**: unique key로 별도 인덱스 대체 가능 여부, cardinality 낮은 컬럼 인덱스 지양, range 컬럼 분리.
- **Date/시각 전달**: handler·호출부는 `Date` 객체나 unix timestamp를 그대로 넘기고, DB formatting(KST 변환 등)은 쿼리(`queries.ts`) 안에서. handler에서 미리 string으로 변환하지 않기.
- **커넥션**: 배치·CMS 조회는 replica, 서비스 코드에서 검증성 쿼리 지양. 트랜잭션 안에서 `find`는 바깥으로(커넥션 일관성).
- **bulk + 동시성**: 메시지·유저별 반복 조회 금지 → bulk 조회, `pLimit`+`Promise.all`. 트랜잭션 안 `Promise.all`은 무의미.
- **불필요 제거**: not nullable이면 `coalesce` 불필요, bigint→int 형변환 금지.
- **동시성**: race condition 가능 구간엔 `for update`(단, gap lock side effect 고려).

### 3. 테스트
- **test builder 사용**: `createTbXxxBuilder()`로 필요한 컬럼만 지정.
- **auto increment PK 직접 지정 금지**: 생성된 id를 받아서 검증.
- **`toQuery` 테스트 필수**, 쿼리/트랜잭션 stub 대신 실제 fixture로 실행 검증.
- **fixture 분리**: `dbFixtureHooks`/`dbFixtureHooksEach` 또는 `describe` 블록으로 테스트 로직과 분리.
- **도메인 mock 헬퍼 활용**: feature flag는 `mockFeatureFlag()` 등 기존 헬퍼 사용. `import * as featureFlags` 후 직접 stub하는 식 지양.
- **sandbox·중복 restore 제거**: global `afterEach`에 `sinon.restore()`가 있으면 개별 sandbox 정의·개별 restore 불필요. `sinon.stub()` 직접 호출로 충분.
- **커버리지**: feature flag on/off 양쪽, 성공 시나리오 누락, 타임존(+09:00) 명시.
- **과한 검증·불필요 케이스 제거**: spy `callCount`, 무관한 함수 stub 검증. 빈 입력 등 다른 계층이 책임지는 케이스 테스트 제거.

### 4. 책임 분리 / 응집도
- **공통 유틸에 도메인 한정 코드 금지**: 이벤트 코드는 이벤트 디렉토리로. (백오피스에서도 동일 — feature flag 헬퍼가 이벤트 한정이면 `backoffice/utils/`가 아니라 `controllers/.../event-group/` 사용처로.)
- **애플리케이션 간 참조 금지**: cli → apps 하위 참조 X. 공통은 `ridi-backends/utils`.
- **계층 책임**: GQL mutation은 자기 도메인 처리만, 집계/리워드 로직은 subscriber에 응집.
- **함수 책임 축소**: 파라미터 mutate(`&response`) 대신 리턴값 사용. `Map`을 파라미터로 넘기는 구조 지양.

### 5. 죽은 코드 / 오버엔지니어링
- 사용처 없는 함수·코드 제거.
- 동작하지 않는 코드(예: CMS에서 막힌 `quantity > 0`)는 유지 말고 필요 시 새로(YAGNI).
- **불필요 방어 코드 제거**: 다른 계층이 보장하는 불변식을 또 검사하지 않기 (예: 빈 `adminId` 처리는 추출 함수 책임이므로 handler의 `if (!adminId)` 가드 불필요).
- 단순 wrapper 함수·과한 추상화·불필요한 옵셔널/`default` 블록 지양.

### 6. 주석 / AI 흔적
- **맥락 없는 코멘트 제거**: `Phase 6`, 좌표(`1942:45767`), `Step 3`, `canonical path` 등 다른 사람이 이해 못 하는 코멘트.
- 코드로 충분히 읽히는 주석 제거. 필요하면 figma/Slack/Notion 링크로 대체.
- proto 필드/enum에 해설 주석이 있어야 이해된다면 주석 대신 **이름**을 고친다(1. 네이밍 참조).

### 7. PR 범위 / 분리
- 무관한 변경(tsconfig, jest config, 테스트 환경)은 별도 PR.
- 사용처 제거 PR과 코드 제거 PR 분리.
- 코드량 많으면 영향 범위 축소 위해 분리.
- 실수로 섞여 들어간 파일 제거. (codegen 산출물은 소스 변경과 함께 가는지 확인 — `ridi-internal-proto-lib-*` 생성물 등.)
- PR 제목/본문/commit log가 말하는 의도와 diff가 어긋나면 scope drift로 본다. "하면서 같이 정리"한 변경이 blast radius를 키우면 분리 제안.
- 계획된 요구사항이 PR에서 빠졌거나 일부만 구현됐으면 missing requirement로 남긴다. 단, diff로 증명 불가능한 외부 작업은 수동 확인 항목으로 분리한다.

### 8. Kafka / 이벤트 subscriber
- **outbox로 DB-Kafka consistency**: DB insert와 메시지 발행을 같은 트랜잭션으로.
- `eachBatch` 비동기 루프마다 `heartbeat()`. timestamp는 unix second로 통일.
- **`eachBatch` window 내 순서**: opt_in/opt_out, 작성→삭제→재작성 시나리오에서 `maxBy`/`uniqBy` 함정 점검.
- subscriber는 throw로 재시도(부분 재시도는 오버헤드), 부하 우려 시 `eachBatchSize` 축소.
- **적재 기준 = 집계 기준**: 액티비티 적재 조건과 당첨 집계 쿼리 조건이 일치해야 함.
- 외부 API 중복 호출 방지, 순서 보장 필요 시 동기/v2 API 검토, retry는 exponential backoff.

### 9. 타입 안전성 (TS / proto / GraphQL)
- **enum/value completeness**: enum, status, type, string literal union 값이 추가되면 diff 안만 보지 말고 sibling value 사용처를 grep/read한다. switch/case, allowlist/filter array, dropdown option, DB 저장/조회, GraphQL/proto 변환, FE 표시가 새 값을 누락하지 않는지 확인한다.
- GraphQL `ID!` 대신 `Int!`로 불필요한 `Number.isFinite` 검증 제거.
- `||` 대신 `??`(과허용 방지), optional은 `?`, `!=/!==` 대신 `isDefined()`.
- proto 타입을 DB 컬럼과 일치(`uint64` 등), proto3 enum 첫 값은 `_UNSPECIFIED = 0`.
- **경계 타입 coercion**: PHP → JSON → TS, DB bigint → JS number/string, proto/GraphQL scalar, Date/string/timestamp 경계에서 타입이 바뀌어 hash·비교·정렬·ID 매칭이 깨지지 않는지 확인한다.
- **proto `optional` 필드 부재 시 `undefined` 반환**: 없을 때 `0`/빈값을 넣으면 wire에 구체 값으로 직렬화되어 FE가 epoch(1970) 등으로 오해석. 기존 builder(`makeCalendarItem`, `makeImageItem`)의 "없으면 `undefined`" 패턴을 따른다.
- **optional 필드 검증은 부재를 허용**: `optional`로 선언했으면 `undefined`를 무조건 거부하지 말 것(draft/clear 저장이 깨짐). 거부는 "값이 있는데 invalid"인 조합에만.
- **상호배타 필드는 `oneof`**: 둘 중 하나만 유효한 payload는 `oneof`로 모델링. NestJS binding이 oneof를 2개 optional 필드로 풀어주고 both-set 케이스가 제거되므로 handler의 "둘 다 set" 분기를 없앨 수 있다.
- 불필요한 `export type` 지양, inline 타입 정의.

### 10. 정책 / 협업
- 정책 모호 시 직접 결정 말고 기획자(소정님/선영님 등) 확인 요청.
- 결정 근거는 Slack 쓰레드·Notion·figma 링크로 남기기.
- 환경변수는 AWS Secret Manager로 일관 관리, 환경별(dev/local/prod) 분기, airflow는 KST 시간.
- 기존 bot/reviewer 코멘트를 근거로 삼을 때는 current head에서 여전히 유효한지 다시 확인한다. stale comment를 그대로 반복하지 않는다.
- 문서/운영 절차에 설명된 기능을 바꾸는 PR이면 README/AGENTS/운영 문서가 stale해지지 않는지 정보성으로 확인한다.

### 11. 시간 / 기간 / 경계값
- 이벤트 시작/종료, 쿠폰/포인트 만료, 배치 기준일처럼 시간 window가 있는 기능은 inclusive/exclusive 기준을 확인한다.
- KST 변환 위치가 일관적인지 확인한다. handler에서 string으로 미리 바꾸지 않고 쿼리나 공통 util의 기존 패턴을 따른다.
- 관련 기능끼리 window 기준이 다르면 사용자에게 보이는 상태와 배치/집계 결과가 어긋날 수 있으므로 코멘트한다.
- 최초 타이머/폴링/캐시 갱신이 boundary 직후 상태를 늦게 반영하지 않는지 확인한다.

### 12. 백오피스 (internal-products / NestJS gRPC)
- **handler 사전 검증**: upsert/update RPC는 대상 row가 **존재하는지 + 타입이 맞는지** 먼저 확인한다(인접 `upsertEventBookGroup` 패턴). 검증 없이 id로 바로 쓰면, 잘못된 id가 무관한 row를 no-op/덮어쓰거나 다른 그룹 타입의 `ui_options`를 엉뚱한 JSON으로 오염시킬 수 있다.
- **legacy vs new 컬럼 함정**: 가드·조회는 생성 경로가 **실제로 쓰는** 컬럼을 봐야 한다. 예) 생성(`insertEmptyEventGroup`)이 `new_group_type`에만 기록하면, 가드가 legacy `group_type`을 검사할 경우 운영 데이터에서 항상 우회된다 → `new_group_type` 검사.
- **copy/clone은 분리 테이블까지 복제**: payload는 `tb_event_group.ui_options` JSON, window는 `tb_event_check_in`처럼 분리 저장한 경우, copy 트랜잭션이 분리 테이블을 빠뜨리면 복사본이 깨진다(window 0, 사용자 동작 실패). 관련 테이블을 모두 복제한다.
- **feature flag (GrowthBook)**:
  - flag key는 한 곳(`backends/src/utils/featureFlags/values.ts`)에 정의하고 import해서 쓴다(문자열 산재 금지).
  - admin 가드는 `assertXxxAllowed(adminId)` → 미허용 시 `RpcException({ code: Status.PERMISSION_DENIED })`.
  - `adminId`는 기존 `extractCmsUserIdFromKeycloak`(Keycloak `preferred_username`의 `@` 앞부분) 재사용. 빈 값 처리는 추출 함수 책임 → handler에서 다시 막지 않는다.
  - 이벤트 등 특정 도메인 한정 flag 헬퍼는 공통 `backoffice/utils/`가 아니라 사용처 디렉토리에 둔다(4. 책임 분리).
  - 테스트는 `mockFeatureFlag()` 헬퍼로 on/off 양쪽.
- **payload 저장 설계**: 가변·중첩 payload는 별도 컬럼 난립 대신 `ui_options` 같은 JSON 컬럼으로 통합(이미지 파일명 등 포함). 단, **병렬 read·독립 갱신이 필요한 값**(예: 참여 window)은 별도 테이블로 분리해 read 시 두 쿼리를 병렬화.
- **토큰 / URL 조립 util**:
  - URL query에 토큰을 끼울 때 인코딩 안전성 확인 — `base64url`(URL-safe 알파벳)이면 그대로 OK, standard base64(`+`,`/`,`=`)면 `encodeURIComponent` 필요.
  - URL 경로 segment 누락 점검(예: `/event/check-in/enter`의 `/enter`), 환경별 base URL 분기(dev→`dev.ridi.io`, local→로컬 주소).
  - 암복호화 대상은 최소화 — 불필요한 prefix(`event-check-in:` 등)를 붙이면 복호화 후 slice 부담만 늘어난다. 식별자만 암복호화.
- **codegen 동기화**: proto 변경 시 NestJS(`ridi-internal-proto-lib-nestjs`)·FE(`ridi-internal-proto-lib-protobuf-ts`) 생성물이 함께 갱신됐는지, 소스 proto와 일치하는지 확인.
