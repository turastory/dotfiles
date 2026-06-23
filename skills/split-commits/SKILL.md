---
name: split-commits
description: >-
  Split uncommitted or scoped changes into multiple logical commits on the
  current branch. Use when the user asks to split commits by scope, commit work
  in stages, divide changes into reviewable commits, or says "작업 범위 나눠서 커밋".
---

# Split Commits by Scope

현재 브랜치의 변경을 논리 단위로 나눠 순차 커밋한다. PR 분리(`split-to-prs`)와 달리 브랜치·원격은 건드리지 않는다.

## Hard rules

- 사용자가 커밋을 요청한 경우에만 커밋한다.
- `git add .` / `git add -A` 금지. 슬라이스별로 파일 경로만 stage.
- 파괴적 git 명령(`reset --hard`, force-push 등)은 사용자 명시 요청 없이 금지.
- 커밋 메시지는 `feat: ...`, `fix: ...` 한 줄 형태. multi-line 피하기.

## 1. 상태 파악

병렬 실행:

```bash
git status
git diff --stat
git log --oneline -10
```

- staged / unstaged / untracked 모두 포함해 실제 슬라이스를 식별한다.
- 채팅 맥락으로 의도(계약 → 구현 → UI 등)를 보완한다.
- `CODEOWNERS`·경로 소유권이 있으면 슬라이스 경계 힌트로 쓴다.

## 2. 슬라이스 설계

의존성 순서를 지킨다. 예시:

1. DB schema / proto / GraphQL SDL + codegen
2. feature flag 정의
3. backend API·로직 + tests
4. frontend UI
5. 기타(문서, islands 등)

원칙:

- 한 커밋 = 한 관심사. 리뷰어가 이해하기 쉬운 단위.
- 강하게 결합된 파일은 같은 커밋에 둔다(proto + 생성 코드 등).
- 무관한 수정(예: pre-commit 차단용 타입 fix)은 별도 `fix:` 커밋으로 분리하거나, 슬라이스에 섞이지 않게 처리한다.

슬라이스가 2개 이상이면 사용자에게 계획을 짧게 보여준 뒤 진행한다. 사용자가 이미 "커밋 진행"을 요청했으면 설계 후 바로 실행해도 된다.

## 3. Pre-commit 검증 (한 번만)

**첫 커밋 전에** hook이 잡을 문제를 미리 해결한다.

1. 슬라이스 순서대로 첫 번째에 넣을 파일만 stage.
2. **hook을 태우며** 커밋 시도 (아래 "첫 커밋" 참고).
3. pre-commit / lint-staged / tsc / biome 실패 시:
   - 오류 수정 (import 정렬, 타입, lint 등).
   - `git reset HEAD`로 staging 정리 후 수정 반영.
   - 다시 1번부터. **hook이 통과할 때까지 `--no-verify` 쓰지 않는다.**

hook 통과가 확인되면 이후 슬라이스는 `--no-verify`로 커밋한다.

## 4. 슬라이스별 커밋

각 슬라이스마다:

```bash
git reset HEAD          # 이전 슬라이스 잔여 staging 제거 (필요 시)
git add <file1> <file2> ...
git commit -m "$(cat <<'EOF'
feat: concise message
EOF
)"
```

### 첫 커밋

hook 검증용. 위 3절에서 통과 확인.

```bash
git commit -m "$(cat <<'EOF'
...
EOF
)"
```

### 2번째 커밋부터

검증 완료 후에는 hook 생략:

```bash
git commit --no-verify -m "$(cat <<'EOF'
...
EOF
)"
```

- 슬라이스마다 `git status`로 남은 변경 확인.
- partially staged 상태에서 hook 실패하면 `git reset HEAD` 후 파일 전체를 다시 stage.

## 5. 마무리

```bash
git status
git log --oneline -N   # N = 이번에 만든 커밋 수
```

사용자에게 전달:

- 커밋 해시·메시지·범위 표
- working tree clean 여부
- `--no-verify`를 쓴 커밋이 있음을 명시 (CI에서 검증 필요 시 알림)

## 슬라이스 예시 (이벤트 참여 현황)

| 순서 | 메시지 예시 | 파일 |
|------|-------------|------|
| 1 | `feat: add available_group_types to GetEventGroupListResponse` | proto + codegen |
| 2 | `feat: add productpay-event-participation-admin-20260608 feature flag` | `featureFlags/values.ts` |
| 3 | `feat: gate participation group admin APIs behind feature flag` | backend controller, featureFlag, tests |
| 4 | `feat: use available group types from API in event group list` | backoffice frontend |

## 주의

- GraphQL/proto 변경 후 codegen이 필요하면 해당 슬라이스에 생성물을 포함하거나, repo 규칙의 sync 명령을 먼저 실행한다.
