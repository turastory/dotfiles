---
name: superset-cli
description: Use whenever creating, listing, or managing a git worktree/workspace for the ridi monorepo (or any other Superset-tracked project), spawning an agent (Claude/Codex) session inside one, opening a terminal session, or setting up a scheduled automation. Superset (the `superset` CLI, `/opt/homebrew/bin/superset`) is the tool of record for worktree management here — prefer `superset workspaces create` over a bare `git worktree add`, since it also runs the project's bootstrap script and registers the workspace so the Superset desktop app tracks it. Also use when troubleshooting a Superset-created worktree (missing node_modules, native module build failures, husky hook missing, mocha ESM alias errors).
---

# Superset CLI

사용자는 로컬 개발 워크트리를 Superset(데스크톱 앱 + CLI + 로컬 호스트 데몬)으로 관리한다. Superset의 "workspace"는 곧 git worktree 하나이고, 그 안에서 agent 세션·터미널 세션을 띄울 수 있다. `superset` 바이너리는 `/opt/homebrew/bin/superset`에 있고 (v0.2.23 기준) `superset --help`, `superset <resource> --help`, `superset <resource> <command> --help`로 3단계 도움말을 제공한다.

## 왜 `git worktree add` 대신 이걸 쓰는가

과거엔 `git worktree add ~/.superset/worktrees/<repo>/<branch> -b <branch> origin/master`로 수동 생성 후 `.superset/setup.sh`를 직접 실행해야 했다. `superset workspaces create`는 이 과정(경로 규칙 적용, 프로젝트 setup 스크립트 실행, Superset UI 등록)을 CLI 한 번에 처리한다. 수동으로 만든 워크트리는 Superset이 추적하지 못해 데스크톱 앱에 안 뜨고, 부트스트랩을 사람이 직접 챙겨야 한다.

## 전역 옵션

모든 하위 명령이 공통으로 지원:

- `--json` — JSON 출력 (CI/에이전트 환경에서는 자동 on)
- `--quiet` — ID만 출력 (스크립팅용)
- `--api-key <sk_live_…>` — OAuth 로그인 대신 API 키 사용 (`$SUPERSET_API_KEY`)

## 인증/상태 확인

```sh
superset auth whoami     # 현재 로그인 유저/조직 확인
superset auth login      # 로그인 (조직 전환 시 재실행)
superset status          # 로컬 호스트 데몬 상태 (pid, port, healthy)
superset hosts list      # 접근 가능한 호스트(맥 등) 목록
```

## 워크스페이스(워크트리) 관리 — 핵심

### 생성

```sh
PROJECT_ID="$(superset projects list | awk '$1 == "ridi" && $4 == "yes" {print $6; exit}')"

superset workspaces create \
  --project "$PROJECT_ID" --local \
  --name <short-workspace-name> \
  --branch productpay/<feature>/<details> \
  [--base-branch master] \
  [--agent claude --prompt "..."] \
  [--command "pnpm install"] \
  [--attachment <path>]
```

- `--name`은 현재 CLI에서 필수다. 사람이 알아볼 짧은 workspace 이름을 넣는다.
- `--project`는 `ridi` slug가 환경/버전에 따라 `Project is not set up on this host`로 실패할 수 있다. 생성 전에 `superset projects list`에서 `SET UP=yes`인 `ridi` 행의 `ID`를 확인해 그 UUID를 넘긴다. 값은 바뀔 수 있으니 하드코딩하지 않는다.
- `--branch`는 존재하지 않으면 `--base-branch`(기본: 프로젝트 default)에서 새로 판다.
- 기존 PR을 체크아웃하려면 `--branch` 대신 `--pr <number>` (검증된 PR head 체크아웃).
- `--agent`를 주면 생성 직후 그 워크스페이스에서 바로 에이전트 세션이 시작된다 (`--prompt` 필수). 안 주면 워크스페이스만 만들고 끝.
- `--host <machineId>`로 다른 호스트를 지정할 수도 있음 (기본은 `--local`).

브랜치 네이밍은 레포 컨벤션(`<team>/<feature>/<details>`, ridi는 team=`productpay`)을 따를 것 — Superset 경로 규칙과 무관하게 git 쪽 컨벤션은 그대로 지켜야 함.

### 조회 / 열기 / 정리

```sh
superset workspaces list [--project <project-id>] [--search <branch나 이름 substring>]
superset workspaces open <id>      # Superset 데스크톱 앱에서 열기
superset workspaces update <id> ...
superset workspaces delete <id>
```

Superset이 만든 실제 worktree 경로는 CLI 버전에 따라 `~/.superset/worktrees/ridi/...`가 아니라 `~/.superset/worktrees/<project-id>/...` 형태일 수 있다. 경로가 필요하면 `git worktree list --porcelain` 또는 `superset workspaces list`로 방금 만든 branch/name을 다시 조회한다.

## 생성 후 부트스트랩이 안 됐다면 (`.superset/setup.sh`)

`superset workspaces create`가 정상 동작하면 프로젝트의 `.superset/setup.sh`를 자동 실행해준다. 다만 `--local`이 아니거나, plain `git worktree add`로 예전 방식대로 만들었거나, setup 도중 실패한 흔적(아래 증상)이 보이면 수동으로 재실행:

```sh
SUPERSET_ROOT_PATH=/Users/nayoonho/ridi/ridi bash .superset/setup.sh
```

ridi monorepo 기준 setup.sh가 하는 일:

1. branch-local `pnpm install --frozen-lockfile --prefer-offline --ignore-scripts`
2. **native addon 복구** — `--ignore-scripts`로 못 빌드된 gyp-build 네이티브 모듈을 메인 repo(`/Users/nayoonho/ridi/ridi`)의 빌드된 `build/`에서 복사. 대상은 소스빌드되는 `sharp@0.32.6`(build/+vendor/libvips)과 `@confluentinc/kafka-javascript`(build/) 둘뿐 — 나머지는 tarball에 prebuilt가 동봉되어 install만으로 해결됨.
3. `pnpm prepare` (husky `.husky/_/husky.sh` 생성)
4. `.env`/config 심링크, 워크스페이스 문서/로그 심링크(`.cursor`/`.claude` → `~/workspaces/*`)
5. ridi1 PHP/static 빌드 (비치명, 실패해도 앞 단계는 이미 끝나 있음)

**증상 → 원인**: `pnpm test`가 `mocha: command not found`/`node_modules missing`, native `.node` 못 찾음(`Cannot find module ...confluent-kafka-javascript.node`), 커밋이 `.husky/_/husky.sh: No such file or directory`로 막힘 → setup.sh 미완료. 위 명령으로 재실행하면 됨.

### 왜 branch-local install인가 (symlink를 버린 이유)

과거엔 `node_modules`를 메인 repo로 통째로 symlink했다. 문제: 메인 node_modules가 가변 공유 자원이 되어, 어느 워크트리든 `pnpm install`을 돌리면 메인의 workspace 링크(ridi-backends, proto lib 등)가 그 워크트리로 덮어써지고, 메인을 심링크한 다른 워크트리들이 형제 워크트리의 상태를 보게 됐다(kafka/sharp 미빌드, proto stale → 백엔드 크래시·vite 빌드 실패 반복). 지금은 branch-local install로 각 워크트리를 자기소유로 격리한다.

- **메인 node_modules가 오염됐으면**: 메인에서 `CI=true pnpm install --frozen-lockfile --prefer-offline --ignore-scripts`로 복구. 단 이 재설치가 메인의 sharp/kafka `build/`도 지우므로, 먼저 그 `build/`(+sharp vendor/)를 백업했다가 install 후 되돌릴 것 (setup.sh의 native 복구 소스가 메인이라 메인은 반드시 native 빌드를 유지해야 함).
- **symlink가 잔존하는 경우** (옛 방식으로 만든 워크트리, 또는 setup.sh 실행 전): `node_modules`가 여전히 원본 repo symlink면 워크스페이스 패키지(proto lib, codebook, graphql/schema, design-system 등)가 원본 repo 소스를 봐서 워크트리에서 바꾼 변경이 무시된다 (vite/tsc/jest/next 전부 영향). Vite는 추가로 `server.fs.allow`가 워크트리 밖 파일 서빙을 차단해 realpath가 원본 repo인 외부 의존성도 "outside of Vite serving allow list"로 즉시 터진다.
  - 프론트 typecheck 함정: `internal-products/frontends/backoffice/node_modules`가 main으로 심링크돼 있으면 master의 stale proto lib을 해석해 feature 브랜치에만 있는 필드가 `has no exported member`로 무더기 에러가 남. `realpath node_modules/ridi-internal-proto-lib-protobuf-ts`로 먼저 어디로 빠지는지 확인.
  - 해결: symlink만 먼저 제거(`find . -maxdepth 5 -name node_modules -type l -delete`) → `pnpm install --frozen-lockfile --prefer-offline --ignore-scripts` (no-TTY 환경이면 `CI=true` 필요). pnpm store가 공유라 hardlink 재사용으로 빠름(다운로드 0).
  - proto를 그 브랜치에서 직접 바꿨다면 install 전에 `internal-products/proto/lib`에서 `make build/all`로 재생성해 둘 것.
  - `server.fs.allow`에 원본 경로를 추가하는 우회는 stale 소스 문제를 못 고치므로 금지.
  - Node 22 PATH 고정과 함께 쓸 것 (다음 섹션 참고).

## backends mocha 테스트 잔존 이슈 (setup.sh 이후에도)

Superset 워크트리에서 `backends` DB 테스트(`pnpm test`)가 Node 22여도 두 가지로 막힐 수 있다:

1. **Mocha 11이 `--require`를 ESM `import()`로 처리** → `.mocharc.yaml`의 `ridi-backends/test/setup` 같은 tsconfig path alias가 `tsconfig-paths`로 해소 안 됨 (`ERR_MODULE_NOT_FOUND .../ridi-backends/test/setup`). 우회: mocha를 직접 호출하며 CJS require 훅을 명시하고 alias 대신 상대경로를 쓴다.
2. **`--ignore-scripts` 설치라 네이티브 모듈 미빌드** → `@confluentinc/kafka-javascript` 바인딩(`*.node`) 없음 (setup.sh가 복구했어야 하지만 안 됐으면). 우회: 해당 패키지 디렉토리에서 `node-pre-gyp install`.

로컬 실행 성공 레시피 (2026-07 검증, 총 ~2.5분 DB 셋업 + 테스트 시간):

1. **kafka broker**: `setup.ts`가 `kafka.init()`으로 localhost:9092에 붙는다. `backends-kafka` docker 컨테이너가 Created 상태로 멈춰 있으면 `docker start backends-kafka` (zookeeper는 별도 컨테이너로 이미 떠 있어야 함). broker 없으면 시작 단계에서 무한 hang.
2. **`--exit` 플래그 필수**: teardown(`kafka.end()` 등)이 hang해 프로세스가 안 죽을 수 있다. mocha에 `--exit`를 주면 대체로 정상 종료되지만, summary 출력 후에도 프로세스가 남으면 `pkill -f <testfile>`로 정리.
3. 실행 예:
   ```sh
   DOT_ENV=.env.test NODE_ENV=test DD_TRACE_ENABLED=false SYNCHRONIZE_TEST_DB=false \
   node --no-experimental-strip-types -r ts-node/register -r tsconfig-paths/register \
   node_modules/mocha/bin/_mocha --require ./src/test/setup.ts --exit --grep "<pattern>" <file>
   ```
   (Node 22 PATH 고정. `SYNCHRONIZE_TEST_DB=false`여도 "Setting up test DB" ~2.5분은 매번 든다 → `--grep`으로 좁혀 반복 비용 최소화.)

빠른 검증만 필요하면 `docker compose -p test run --rm backends test`(repo 표준 경로, docker 필요)도 고려.

## 에이전트 / 터미널 세션

```sh
superset agents create --workspace <id> --agent claude --prompt "..." [--attachment <path>]
superset agents list                      # 호스트에 설정된 에이전트 프리셋 목록
superset terminals create --workspace <id>  # 에이전트 없이 순수 터미널 세션
```

## 작업(tasks) / 자동화(automations)

칸반형 작업 관리와 cron 스타일 자동화도 같은 CLI로 다룰 수 있다.

```sh
superset tasks create --title "..." --priority high --assignee <userId> --due-date 2026-07-10
superset tasks list / get <id> / update <id> / delete <id>
superset tasks statuses ...   # 상태(컬럼) 관리

superset automations create ...
superset automations pause|resume|run <id>
superset automations prompt <id>     # 프롬프트 읽기/수정
superset automations logs <id>       # 실행 이력
```

## 프로젝트 / 조직

```sh
superset projects list                                   # 등록된 프로젝트 (ridi 등)와 ID 확인
superset projects create ...
superset projects setup <id> --path <repo> [--parent-dir ...] [--import ...] [--allow-relocate]

superset organization list / switch / members
```

ridi 프로젝트는 이미 `/Users/nayoonho/ridi/ridi`에 setup 완료 상태로 등록되어 있다 (`superset projects list`로 UUID 확인 가능 — 값은 바뀔 수 있으니 하드코딩하지 말고 매번 조회).

## 트러블슈팅 순서 요약

1. `superset status`로 로컬 호스트 데몬이 healthy한지 먼저 확인.
2. 워크트리 관련 문제(모듈 없음/훅 없음/native 바인딩 없음)는 `.superset/setup.sh` 재실행부터 (위 "생성 후 부트스트랩" 섹션).
3. tsc/vite/jest가 워크트리에서 바꾼 코드를 무시하는 것처럼 보이면 `node_modules`가 아직 메인 repo symlink인지 `realpath`로 의심.
4. backends 테스트가 hang/실패하면 kafka broker 기동 여부와 `--exit` 플래그부터 확인.
