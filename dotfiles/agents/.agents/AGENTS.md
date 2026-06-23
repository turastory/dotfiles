## 일반

- 사용자가 영어로 말하더라도 항상 한국어로 응답할 것
- 테스트, 빌드 등 스크립트를 실행하기 전에 먼저 해당 프로젝트의 패키지 매니저 정의 파일을 확인할 것 (package.json, Cargo.toml 등)
- lint, test 실행 시 작업 내용과 무관한 변경 사항은 무시할 것

## 작업 시 유의 사항

- 타입을 별도로 분리하거나, 기능을 별도 함수로 너무 섣부르게 분리하지 말 것. 처음 구현할 때는 우선 너무 커지거나 책임이 명확하지 않는 한 하나로 작성하고, 리팩토링을 할만한 지점이 있으면 작업 후에 유저에게 안내.
- 함수 구현 시 파라미터로 필요 이상으로 많은 파라미터를 넘기지 않도록 한다.
- (typescript) 함수 구현 시 가능한 Map을 파라미터로 넘기지 않게 한다.
- PR 리뷰 시 ridi-review-checklist 스킬 참고

## RIDI repo 테스트

`ridi` monorepo(`backends/`, `internal-products/backends/` 등)에서 테스트를 **작성·수정·리뷰**할 때는 반드시 `~/.agents/skills/ridi-test-guides/SKILL.md`를 먼저 읽고, 그 안의 컨벤션(fixture 배치, assertion, feature flag describe 분리, query vs API 역할, `dbFixtureHooks` 사용 등)을 빠짐없이 반영할 것. 스킬과 충돌하는 축약·헬퍼·중복 시나리오는 피하고, 기존 레퍼런스 테스트 파일 패턴을 우선 따른다. 오케스트레이터가 RIDI backend 테스트 작업을 서브에이전트에 위임할 때도, 위임 프롬프트에 `ridi-test-guides`를 읽고 따르도록 명시할 것.

Superset worktree에서는 `node_modules`가 원본 repo를 가리켜 타입체크가 stale workspace `dist`를 참조할 수 있다. 테스트/타입체크 전 worktree root에서 `pnpm install --frozen-lockfile --prefer-offline --ignore-scripts`를 실행해 현재 worktree 기준 의존성 symlink를 맞춘 뒤 검증한다.

RIDI `backends` 테스트 실행 시 Node 버전이 의존성 설치 때 사용한 버전과 다르면 Mocha setup 단계에서 `ridi-backends/test/setup`을 찾지 못하거나, `@confluentinc/kafka-javascript` 같은 native module이 `NODE_MODULE_VERSION` 불일치로 실패할 수 있다. 특히 Node 25가 잡히면 Mocha 11이 `--require` 항목을 ESM `import()` 경로로 먼저 처리해 `tsconfig` path alias가 적용되지 않는 증상이 난다. 이 경우 먼저 `node --version`, `pnpm exec node --version`, `which node`, `which pnpm`을 확인하고, repo에서 설치된 Node 22 계열을 명시해 `PATH=/Users/nayoonho/.nvm/versions/node/v22.22.0/bin:$PATH pnpm <command>` 형태로 재실행한다.

## DB 접근 (QueryPie)

- dev DB와 prod DB(read-only)는 QueryPie agent를 통해 `localhost`로 접근할 수 있다. 단, 사용자가 먼저 인증해야 하므로 접속이 안 되면 직접 뚫으려 하지 말고 사용자에게 로그인을 요청할 것.
- 포트: read-only prod DB는 `40144`, dev DB는 `40032`.
- prod 접근 시 주의: 위험한 쿼리(예: 10억 row 테이블에 `WHERE` 없는 `COUNT`, full scan 유발 쿼리 등)는 피할 것. 꼭 필요하면 `LIMIT`/인덱스 조건을 먼저 확인하고 실행.

## RIDI 결제 surface

- 웹 `ridibooks.com/order/checkout`(콘텐츠 구매)는 **모던 Next 라우트가 아니라 레거시 books-backend가 렌더**한다. 모던 `frontends/web/ridibooks/src/pages/order/checkout/index.page.tsx`는 `// Not used for now (porting is in progress)` 주석이 붙은 **미사용 포팅 WIP**다.
  - 실제 렌더 경로: `OrderController::checkout()` → `order/checkout` twig → `order/checkout.order.twig`. 포인트/캐시 조절 UI는 레거시 twig(`render_asset_section`) + `CheckoutForm.js`가 담당.
  - `books-islands`의 `Ridipay`는 그 레거시 페이지에 **island로만 임베드**(`{{ islands['Ridipay'] }}`)되어 RidiPay/PG 영역만 담당하고, 포인트/캐시 금액은 `books-islands:initialized` 이벤트의 `updatedView(paymentInfo)`로 받기만 한다.
- 결제 화면 작업 전 surface를 먼저 구분할 것: ① 앱 인앱 웹뷰(`frontends/web/ridibooks` `inapp/checkout`, 라이브) ② 작품홈 회차별 즉시결제(serial popup, 레거시 twig+jQuery) ③ 웹 `/order/checkout`(위처럼 레거시 렌더). "모던 라우트가 보인다"고 그게 라이브라고 가정하지 말 것.

## Feature Flag

기본적으로 유저 사이드에 영향이 생길 수 있는 곳에서 작업을 할 때는 Feature Flag 도입을 고려한다.
구체적인 내용은 backends/src/utils/featureFlags/values.ts 참조.

- 네이밍 규칙:
  - productpay-<content>-<date> 형식.
  - team은 기본적으로 productpay를 사용. date는 YYYYMMDD 형식

boolean (true/false) 형태의 플래그가 일반적이고, Growthbook 으로 관리되어 런타임에 주입받는 값 등으로 특정 유저에게만 true로 하는 등의 작업도 가능하다.

## Lint

Lint 에러가 발생하면 먼저 다음 절차를 따른다.

1. `pnpm lint:fix` 실행. 디렉토리마다, 프로젝트마다 설정이 다를 수 있으므로 먼저 작업 디렉토리를 문제가 되는 파일이 위치한 프로젝트로 이동한 뒤 실행
2. 만약 설정 관련 문제가 발생하면 해당 프로젝트의 package.json을 읽고 자세한 절차를 확인 후 다시 실행
3. 그래도 방법이 없으면 직접 수정

## Shell Scripts

- 스크립트 출력은 verbose하고 machine-readable하게 작성할 것. 각 단계의 시작/완료/결과를 명확히 출력.
- 외부 도구(jq, yq 등)를 사용할 경우, 설치 여부를 먼저 확인하고 없으면 설치한 후 진행할 것. 설치되어 있다고 가정하지 말 것.

## Plan 문서 / 에이전트 워크스페이스

에이전트 워크스페이스는 `~/workspaces/` 에 있다(repo 밖, repo 삭제돼도 유지). `~/workspaces/README.md` 참고.
카테고리: `draft/`(임시·언제든 삭제 가능) · `project/<name>/`(진행 중 작업, 문서·로그·이미지·시드 한곳) · `domain/`(코드베이스 know-how) · `archive/`(끝난 프로젝트).

- plan 모드에서 작성하는 plan 문서는 기본적으로 `~/workspaces/draft/` 에 저장하고, 특정 프로젝트에 속하면 `~/workspaces/project/<name>/` 에 둘 것
- 파일/폴더명에 작성 날짜를 prefix로 붙일 것 (예: `2026-02-28-db-table-analysis.md`)

## 문서 작성

- 구현 가이드 문서를 작성할 때 전체 코드 예제를 포함하지 말 것. 정말 필요한 경우 코드 일부나 pseudo code만 사용해서 가이드를 간결하고 단순하면서도 정보가 충분하도록 작성.
- 기존 문서를 수정할 때는 기존 구조와 내용을 존중하고, 가능한 작은 변경으로 유지할 것.

## Git

- 브랜치 이름은 `productpay/<feature>/<details>` 형식을 따른다. 예: `productpay/event-participation/progress-list-backends` (`productpay`는 팀명).
- 커밋 메시지는 `feat: add event participation table`처럼 간결한 한 줄 형태 사용. 가급적 multi-line commit은 피할 것.
- merge conflict 해결 후 머지를 마무리(conclude)하는 커밋은 반드시 `--no-verify` 옵션으로 실행해서 pre-commit hook(lint/formatter)이 돌지 않게 할 것. 머지에는 다른 브랜치에서 들어온 대량의 변경이 포함되어 lint-staged hook이 무관한 파일에서 실패하거나 `[KILLED]`되며 index가 손상될 수 있다. (실제로 hook이 죽으면서 git object가 깨져 `git status`가 `fatal: unable to read <sha>`로 실패한 사례 있음 → `git reset --hard HEAD` + `git clean -fd`로 복구 후 재머지 필요했음)

## PR 코멘트 답글

필수: 직접 코멘트를 남길 때는 _Sent by AI_ 꼬리말을 반드시 포함할 것.
리뷰 스레드에 답글 초안을 제안할 때는 `my-tone` 스킬을 참조할 것

## GitHub CLI

- `gh` 사용 시 `gh auth status`로 로그인 상태를 먼저 확인할 것.
- 권한 문제나 repo-not-found 이슈가 있을 때는 `gh auth switch --user <user-name>`으로 활성 계정 전환.
- GitHub remote origin 추가 시:
  - `turastory` 계정: `git@github-personal:<user-name>/<repo>.git`
  - `yoonho-alan` 계정: `git@github-work:<user-name>/<repo>.git`
