## 일반

- 사용자가 영어로 말하더라도 항상 한국어로 응답할 것
- 테스트, 빌드 등 스크립트를 실행하기 전에 먼저 해당 프로젝트의 패키지 매니저 정의 파일을 확인할 것 (package.json, Cargo.toml 등)
- 작업 완료 후 CLAUDE.md / AGENTS.md에 업데이트할 내용(새로운 컨벤션, 패턴, 명령어 등)이 있다면 사용자에게 알려줄 것

## RIDI repo 테스트

`ridi` monorepo(`backends/`, `internal-products/backends/` 등)에서 테스트를 **작성·수정·리뷰**할 때는 반드시 `~/.agents/skills/ridi-skills/ridi-test-guides/SKILL.md`를 먼저 읽고, 그 안의 컨벤션(fixture 배치, assertion, feature flag describe 분리, query vs API 역할, `dbFixtureHooks` 사용 등)을 빠짐없이 반영할 것. 스킬과 충돌하는 축약·헬퍼·중복 시나리오는 피하고, 기존 레퍼런스 테스트 파일 패턴을 우선 따른다. 오케스트레이터가 RIDI backend 테스트 작업을 서브에이전트에 위임할 때도, 위임 프롬프트에 `ridi-test-guides`를 읽고 따르도록 명시할 것.

## Lint

Lint 에러가 발생하면 먼저 다음 절차를 따른다.

1. `pnpm lint:fix` 실행. 디렉토리마다, 프로젝트마다 설정이 다를 수 있으므로 먼저 작업 디렉토리를 문제가 되는 파일이 위치한 프로젝트로 이동한 뒤 실행
2. 만약 설정 관련 문제가 발생하면 해당 프로젝트의 package.json을 읽고 자세한 절차를 확인 후 다시 실행
3. 그래도 방법이 없으면 직접 수정

## Shell Scripts

- 스크립트 출력은 verbose하고 machine-readable하게 작성할 것. 각 단계의 시작/완료/결과를 명확히 출력.
- 외부 도구(jq, yq 등)를 사용할 경우, 설치 여부를 먼저 확인하고 없으면 설치한 후 진행할 것. 설치되어 있다고 가정하지 말 것.

## Plan 문서

- plan 모드에서 작성하는 plan 문서는 `~/workspaces/plans/` 디렉토리에 저장할 것
- 파일/폴더명에 작성 날짜를 prefix로 붙일 것 (예: `2026-02-28-db-table-analysis.md`)

## 문서 작성

- 구현 가이드 문서를 작성할 때 전체 코드 예제를 포함하지 말 것. 정말 필요한 경우 코드 일부나 pseudo code만 사용해서 가이드를 간결하고 단순하면서도 정보가 충분하도록 작성.
- 기존 문서를 수정할 때는 기존 구조와 내용을 존중하고, 가능한 작은 변경으로 유지할 것.

## Git

- 브랜치 이름은 `productpay/<feature>/<details>` 형식을 따른다. 예: `productpay/event-participation/progress-list-backends` (`productpay`는 팀명).
- 커밋 메시지는 `feat: add event participation table`처럼 간결한 한 줄 형태 사용. 가급적 multi-line commit은 피할 것.
- merge conflict 해결 후 머지를 마무리(conclude)하는 커밋은 반드시 `--no-verify` 옵션으로 실행해서 pre-commit hook(lint/formatter)이 돌지 않게 할 것. 머지에는 다른 브랜치에서 들어온 대량의 변경이 포함되어 lint-staged hook이 무관한 파일에서 실패하거나 `[KILLED]`되며 index가 손상될 수 있다. (실제로 hook이 죽으면서 git object가 깨져 `git status`가 `fatal: unable to read <sha>`로 실패한 사례 있음 → `git reset --hard HEAD` + `git clean -fd`로 복구 후 재머지 필요했음)

## PR 코멘트 답글

리뷰 스레드에 답글 초안을 제안할 때는 아래 톤을 따른다.

- **짧고 자연스럽게**: 1~2문장. 딱딱한 보고체·과한 디테일은 피한다.
- **구현 설명은 최소화**: "파싱/CSS 변환을 분리했습니다"보다 "공통은 `colorScheme.ts`, 폼 쪽은 participation으로 나눴어요"처럼 결과만 간단히.
- **말투**: 팀 동료에게 말하듯 존댓말이되, "~했습니다"만 반복하지 않고 "~해두었습니다", "~나눴습니다", "~해볼게요" 등도 자연스럽게 섞는다.
- **불필요한 격식·감사 멘트 생략**: "리뷰 감사합니다", "좋은 지적 감사합니다" 같은 보일러플레이트는 기본적으로 넣지 않는다.
- **언어 맞추기**: 리뷰 코멘트가 한국어면 한국어로, 영어면 영어로 답한다.
- **식별자는 필요할 때만**: 파일명·함수명은 답에서 꼭 짚어야 할 때만 인라인 코드로 쓴다.

예시 (너무 딱딱함): "공통 파싱/CSS 변환은 colorScheme.ts에 두고, 폼 encode/decode는 participation 쪽 모듈로 분리하겠습니다."

예시 (권장): "공통 쪽은 `colorScheme.ts`로 모으고, 폼용은 participation 쪽으로 빼두었습니다."

## GitHub CLI

- `gh` 사용 시 `gh auth status`로 로그인 상태를 먼저 확인할 것.
- 권한 문제나 repo-not-found 이슈가 있을 때는 `gh auth switch --user <user-name>`으로 활성 계정 전환.
- GitHub remote origin 추가 시:
  - `turastory` 계정: `git@github-personal:<user-name>/<repo>.git`
  - `yoonho-alan` 계정: `git@github-work:<user-name>/<repo>.git`
