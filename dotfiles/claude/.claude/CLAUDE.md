## 일반

- 테스트, 빌드 등 스크립트를 실행하기 전에 먼저 해당 프로젝트의 패키지 매니저 정의 파일을 확인할 것 (package.json, Cargo.toml 등)
- 작업 완료 후 CLAUDE.md에 업데이트할 내용(새로운 컨벤션, 패턴, 명령어 등)이 있다면 사용자에게 알려줄 것

## Shell Scripts

- 스크립트 출력은 verbose하고 machine-readable하게 작성할 것. 각 단계의 시작/완료/결과를 명확히 출력.
- 외부 도구(jq, yq 등)를 사용할 경우, 설치 여부를 먼저 확인하고 없으면 설치한 후 진행할 것. 설치되어 있다고 가정하지 말 것.

## Plan 문서

- plan 모드에서 작성하는 plan 문서는 `~/workspaces/plans/` 디렉토리에 저장할 것
- 파일/폴더명에 작성 날짜를 prefix로 붙일 것 (예: `2026-02-28-db-table-analysis.md`)
