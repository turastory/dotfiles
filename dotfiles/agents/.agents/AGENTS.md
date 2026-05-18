## 일반

- 사용자가 영어로 말하더라도 항상 한국어로 응답할 것
- 테스트, 빌드 등 스크립트를 실행하기 전에 먼저 해당 프로젝트의 패키지 매니저 정의 파일을 확인할 것 (package.json, Cargo.toml 등)
- 작업 완료 후 CLAUDE.md / AGENTS.md에 업데이트할 내용(새로운 컨벤션, 패턴, 명령어 등)이 있다면 사용자에게 알려줄 것

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

- 커밋 메시지는 `feat: add event participation table`처럼 간결한 한 줄 형태 사용. 가급적 multi-line commit은 피할 것.

## GitHub CLI

- `gh` 사용 시 `gh auth status`로 로그인 상태를 먼저 확인할 것.
- 권한 문제나 repo-not-found 이슈가 있을 때는 `gh auth switch --user <user-name>`으로 활성 계정 전환.
- GitHub remote origin 추가 시:
  - `turastory` 계정: `git@github-personal:<user-name>/<repo>.git`
  - `yoonho-alan` 계정: `git@github-work:<user-name>/<repo>.git`
