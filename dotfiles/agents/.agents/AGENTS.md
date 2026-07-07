# 일반 원칙

## 응답·실행 기본

- 사용자가 영어로 말하더라도 항상 한국어로 응답할 것
- 테스트, 빌드 등 스크립트를 실행하기 전에 먼저 해당 프로젝트의 패키지 매니저 정의 파일을 확인할 것 (package.json, Cargo.toml 등)
- lint, test 실행 시 작업 내용과 무관한 변경 사항은 무시할 것

## 코드 작성

- 타입을 별도로 분리하거나, 기능을 별도 함수로 너무 섣부르게 분리하지 말 것. 처음 구현할 때는 너무 커지거나 책임이 명확하지 않는 한 하나로 작성하고, 리팩토링할 만한 지점이 있으면 작업 후에 유저에게 안내.
- 함수 구현 시 필요 이상으로 많은 파라미터를 넘기지 않도록 한다.
- (typescript) 함수 구현 시 가능한 Map을 파라미터로 넘기지 않게 한다.
- PR 리뷰 시 `review-pr` 스킬 참고

## Lint

Lint 에러가 발생하면 다음 순서로 처리한다.

1. `pnpm lint:fix` 실행. 프로젝트마다 설정이 다를 수 있으므로 문제 파일이 위치한 프로젝트로 이동한 뒤 실행
2. 설정 관련 문제가 발생하면 해당 프로젝트의 package.json에서 절차를 확인한 후 재실행
3. 그래도 방법이 없으면 직접 수정

## Shell Scripts

- 스크립트 출력은 verbose하고 machine-readable하게 작성할 것. 각 단계의 시작/완료/결과를 명확히 출력.
- 외부 도구(jq, yq 등)는 설치되어 있다고 가정하지 말고, 설치 여부를 먼저 확인한 후 없으면 설치하고 진행할 것.

## 문서 작성

- 구현 가이드 문서에 전체 코드 예제를 포함하지 말 것. 정말 필요한 경우 코드 일부나 pseudo code만 사용해서 간결하고 단순하면서도 정보가 충분하도록 작성.
- 기존 문서를 수정할 때는 기존 구조와 내용을 존중하고, 가능한 작은 변경으로 유지할 것.

## Git

- 브랜치 이름은 `productpay/<feature>/<details>` 형식을 따른다 (`productpay`는 팀명). 예: `productpay/event-participation/progress-list-backends`
- 커밋 메시지는 `feat: add event participation table`처럼 간결한 한 줄 형태 사용. 가급적 multi-line commit은 피할 것.
- merge conflict 해결 후 머지를 마무리(conclude)하는 커밋은 반드시 `--no-verify` 옵션으로 실행해서 pre-commit hook(lint/formatter)이 돌지 않게 할 것. 머지에 포함된 대량의 변경 때문에 lint-staged hook이 무관한 파일에서 실패하거나 hook이 죽으면서 git index가 손상될 수 있다 (실제 사례: `git status`가 `fatal: unable to read <sha>`로 실패 → `git reset --hard HEAD` + `git clean -fd`로 복구 후 재머지).

## GitHub CLI

- `gh` 사용 시 `gh auth status`로 로그인 상태를 먼저 확인할 것.
- 권한 문제나 repo-not-found 이슈가 있을 때는 `gh auth switch --user <user-name>`으로 활성 계정 전환.

# RIDI

## 테스트

`ridi` monorepo(`backends/`, `internal-products/backends/` 등)에서 테스트를 **작성·수정·리뷰**할 때는 반드시 `~/.agents/skills/ridi-test-guides/SKILL.md`를 먼저 읽고, 그 안의 컨벤션(fixture 배치, assertion, feature flag describe 분리, query vs API 역할, `dbFixtureHooks` 사용 등)을 빠짐없이 반영할 것. 스킬과 충돌하는 축약·헬퍼·중복 시나리오는 피하고, 기존 레퍼런스 테스트 파일 패턴을 우선 따른다. 서브에이전트에 RIDI backend 테스트 작업을 위임할 때도, 위임 프롬프트에 `ridi-test-guides`를 읽고 따르도록 명시할 것.

실행 환경의 알려진 함정:

- **Superset worktree**: `node_modules`가 원본 repo를 가리켜 타입체크가 stale workspace `dist`를 참조할 수 있다 → 테스트/타입체크 전 worktree root에서 `pnpm install --frozen-lockfile --prefer-offline --ignore-scripts` 실행 후 검증.
- **Node 버전 불일치**: 의존성 설치 때와 다른 Node 버전으로 실행하면 Mocha setup에서 `ridi-backends/test/setup`을 못 찾거나, `@confluentinc/kafka-javascript` 같은 native module이 `NODE_MODULE_VERSION` 불일치로 실패한다. 특히 Node 25가 잡히면 Mocha 11이 `--require` 항목을 ESM `import()` 경로로 처리해 `tsconfig` path alias가 적용되지 않는다 → `node --version`, `which node`, `which pnpm`으로 먼저 확인하고, repo에 맞는 Node 22 계열을 명시해 `PATH="$HOME/.nvm/versions/node/v22.x.x/bin:$PATH" pnpm <command>` 형태로 재실행.

## DB 접근 (QueryPie)

- dev DB와 prod DB(read-only)는 QueryPie agent를 통해 `localhost`로 접근할 수 있다. 단, 사용자가 먼저 인증해야 하므로 접속이 안 되면 직접 뚫으려 하지 말고 사용자에게 로그인을 요청할 것.
- 포트: read-only prod DB는 `40144`, dev DB는 `40032`.
- prod 접근 시 주의: 위험한 쿼리(예: 10억 row 테이블에 `WHERE` 없는 `COUNT`, full scan 유발 쿼리 등)는 피할 것. 꼭 필요하면 `LIMIT`/인덱스 조건을 먼저 확인하고 실행.

## 로컬 환경 서브시스템

- `ridi` monorepo에서 backends/backoffice 계열 로컬 환경을 부팅할 때는 `backends/setup.sh`를 source of truth로 먼저 확인한다. 이 스크립트는 Traefik reverse proxy, 인증서, backend Docker infra, books-backend 초기화까지 포함한다.
- 단순히 `up backoffice` 같은 agent harness로 앱 서버를 띄우는 경우에는 전체 `setup.sh`를 무조건 실행하지 말고, 부작용이 큰 단계(패키지 설치 프롬프트, `/etc/hosts` sudo 변경, books-backend Composer/Docker setup)를 피하면서 필요한 하위 단계만 따른다: `tools/traefik`에서 `make certs && docker compose up -d`, `internal-products/backends`에서 `pnpm docker:infra`.
- 확인 포트: Traefik `80/443/8090`, Envoy `9090`, BO backend `8088`, backoffice Vite `5173`, Redis `6379`, Redis cluster `17000-17005`, dev DB QueryPie `40032`.

## 결제 surface

- 웹 `ridibooks.com/order/checkout`(콘텐츠 구매)는 **모던 Next 라우트가 아니라 레거시 books-backend가 렌더**한다. 모던 `frontends/web/ridibooks/src/pages/order/checkout/index.page.tsx`는 `// Not used for now (porting is in progress)` 주석이 붙은 **미사용 포팅 WIP**다.
  - 실제 렌더 경로: `OrderController::checkout()` → `order/checkout` twig → `order/checkout.order.twig`. 포인트/캐시 조절 UI는 레거시 twig(`render_asset_section`) + `CheckoutForm.js`가 담당.
  - `books-islands`의 `Ridipay`는 그 레거시 페이지에 **island로만 임베드**(`{{ islands['Ridipay'] }}`)되어 RidiPay/PG 영역만 담당하고, 포인트/캐시 금액은 `books-islands:initialized` 이벤트의 `updatedView(paymentInfo)`로 받기만 한다.
- 결제 화면 작업 전 surface를 먼저 구분할 것: ① 앱 인앱 웹뷰(`frontends/web/ridibooks` `inapp/checkout`, 라이브) ② 작품홈 회차별 즉시결제(serial popup, 레거시 twig+jQuery) ③ 웹 `/order/checkout`(위처럼 레거시 렌더). "모던 라우트가 보인다"고 그게 라이브라고 가정하지 말 것.

## Feature Flag

유저 사이드에 영향이 생길 수 있는 곳에서 작업할 때는 기본적으로 Feature Flag 도입을 고려한다. 구체적인 내용은 `backends/src/utils/featureFlags/values.ts` 참조.

- 네이밍 규칙: `productpay-<content>-<date>` 형식. team은 기본적으로 `productpay`, date는 `YYYYMMDD`.
- boolean (true/false) 형태의 플래그가 일반적이고, Growthbook으로 관리되어 런타임에 주입받는 값으로 특정 유저에게만 true로 하는 등의 작업도 가능하다.

# 개인 환경

이 아래는 개인 머신·계정·개인 스킬에 의존하는 항목. 이 파일을 복사해 쓸 경우 이 영역은 자기 환경에 맞게 교체할 것.

## 에이전트 워크스페이스 / Plan 문서

에이전트 워크스페이스는 `~/workspaces/`에 있다 (repo 밖, repo 삭제돼도 유지). `~/workspaces/README.md` 참고.
카테고리: `draft/`(임시·언제든 삭제 가능) · `project/<name>/`(진행 중 작업, 문서·로그·이미지·시드 한곳) · `domain/`(코드베이스 know-how) · `archive/`(끝난 프로젝트).

- plan 모드에서 작성하는 plan 문서는 기본적으로 `~/workspaces/draft/`에 저장하고, 특정 프로젝트에 속하면 `~/workspaces/project/<name>/`에 둘 것
- 파일/폴더명에 작성 날짜를 prefix로 붙일 것 (예: `2026-02-28-db-table-analysis.md`)

## 개인 스킬·하네스

- **PR 트리/체인 관리**: 의존 PR 트리(stacked PR 포함)는 `pr-tree` 스킬(`~/.agents/skills/pr-tree/`)로 관리. 트리 정의는 워크스페이스 프로젝트의 `pr-tree.tsv`(single source of truth)에 두고, 스킬의 `check-pr-tree.sh --tree <tsv>`로 deterministic 점검·cascade. tree/forest(여러 base)와 선형 체인 모두 지원. 단일 브랜치를 master와 맞추는 것은 `sync-with-master` 스킬.
- **PR 코멘트 답글**: 직접 코멘트를 남길 때는 작성한 에이전트를 알리는 꼬리말을 반드시 포함할 것 (Claude면 실행 중인 모델 이름 _Sent by Opus_ / _Sent by Sonnet_ / _Sent by Fable_, Codex면 _Sent by Codex_). 자세한 규칙과 리뷰 스레드 답글 초안 톤은 `my-tone` 스킬 참조.
- **종합 코드 리뷰 하네스**: "종합 코드 리뷰", "4개 관점 리뷰", "이 PR 통합 리뷰" 등 여러 관점을 병렬로 돌려 통합 리포트가 필요한 요청엔 `comprehensive-code-review` 스킬 사용 — architecture·security·performance·style 4개 리뷰어가 병렬 검토 후 단일 리포트로 병합, RIDI 모노레포 특화(결제 surface·Knex/replica·Kafka subscriber 등). 단일 관점 빠른 지적은 `code-review`/`review-pr`로 충분. 에이전트 정의는 `~/.claude/agents/{architecture,security,performance,style}-reviewer.md` + `review-synthesizer.md`. 실행 시 대상 repo 루트에 `.review-workspace/`가 생성되며, repo `.gitignore`에 없으면 스킬이 사용자에게 알리거나 스크래치패드 경로를 대신 쓴다.

## GitHub 계정

- GitHub remote origin 추가 시:
  - `turastory` 계정: `git@github-personal:<user-name>/<repo>.git`
  - `yoonho-alan` 계정: `git@github-work:<user-name>/<repo>.git`
