---
name: address-pr
description: >-
  Checks out a pull request with GitHub CLI (preferring a local git worktree
  under .worktrees/ when possible), collects review and discussion comments,
  immediately implements trivial fixes with commits, then presents a list of
  larger/ambiguous items for user decision. Use when the user invokes
  /address-pr, says "address PR", wants to work through PR review feedback
  systematically, or asks to checkout a PR by number or URL and plan fixes from
  review comments.
---

# Address PR (`/address-pr`)

## Purpose

**PR 리뷰 피드백을 능동적으로 처리**한다: 코멘트를 읽고 분류한 뒤, 간단한 것은 즉시 구현·커밋하고, 큰 변경이나 판단이 필요한 항목은 사용자에게 정리해서 보여준다.

흐름 요약:
```
코멘트 읽기 → 처리 계획 수립 → 이모지로 ack 남기기 (그룹 A 👍 / 그룹 B 👀)
→ 작은 코멘트들 반영 (여러 번 커밋) → 푸시 → Reply 남기기
→ 사용자 검토가 필요한 것들 리스트업
```

이후 사용자 응답에 따라 **"코멘트 반영 / 푸시 / Reply 남기기" → 남은 작업이 있을 경우 다시 검토 요청** 사이클을 반복한다.

## Tone and writing style

Reply 초안 작성 전 `../my-tone/SKILL.md`를 읽고 "리뷰 피드백 처리 계획"·"작성자로 답글 달 때" 가이드를 적용한다. 짧고 자연스러운 팀원 말투, 불필요한 격식·감사 멘트 생략.

## Prerequisites

1. `gh auth status` 실행. 인증 실패나 계정 불일치 시 안내 후 중단.
2. `gh repo view --json nameWithOwner -q .nameWithOwner`로 `owner/repo` 확인.

## PR 미지정 시 대상 결정

PR 번호/URL 없이 호출되면 아래 순서로 대상 PR을 특정한다. 임의 추론으로 바로 작업을 시작하지 말 것.

1. **현재 브랜치**: 브랜치가 PR head와 일치하면(`gh pr view --json number` 성공) 그 PR. 단, `master`/`main`이면 skip.
2. **인자·맥락 매칭**: 인자로 주어진 링크(Slack 스레드, 이슈 등)나 대화 맥락이 특정 PR 주제와 매칭되는지 확인 — `gh pr list --author "@me" --state open`으로 열린 PR 목록을 뽑아 제목·브랜치명과 대조.
3. **후보가 하나뿐**이면 그 PR로 진행하되, 첫 보고에서 "대상은 #N으로 판단했다"고 근거와 함께 명시.
4. **후보가 여럿이거나 매칭 근거가 약하면** 커밋·reply 등 되돌리기 어려운 액션 전에 사용자에게 확인.

## Prefer git worktrees

현재 해당 PR 브랜치의 전용 worktree에 있지 않은 경우, `.worktrees/pr-<number>/` 경로에 워크트리를 만들어서 작업한다. `using-git-worktrees` 스킬의 디렉터리 규칙 참고.

- 이미 해당 브랜치가 체크아웃된 상태이거나 단일 클론 환경이라면 현재 디렉터리에서 진행.
- 진행 전 `git status --short` 확인 — local 변경이 있으면 사용자에게 물어본다.

---

## Workflow

### Phase 1: PR 체크아웃 및 코멘트 수집

**1a. PR 체크아웃**

```bash
# worktree 방식 (권장)
gh pr checkout <number> --branch <branch-name>
git worktree add .worktrees/pr-<number> <branch-name>

# 또는 현재 디렉터리에서 직접
gh pr checkout <number>
```

**1b. 코멘트 수집 (read-only)**

다음 세 가지 소스를 모두 수집한다:

| Source | 방법 |
| ------ | ---- |
| Inline review threads (`isResolved` 포함) | GraphQL `reviewThreads` |
| PR conversation comments | `gh pr view --comments` |
| Review summaries (APPROVE/COMMENT/REQUEST_CHANGES) | `gh pr view --json reviews` |

**resolved된 thread는 반드시 제외.** GraphQL로 `isResolved` 필터링:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100) {
          nodes {
            isResolved
            path
            line
            originalLine
            comments(first:50) {
              nodes { author{login} body url diffHunk createdAt }
            }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
```

`pageInfo.hasNextPage`가 true이면 계속 페이지네이션.

**특정 리뷰어의 코멘트만 처리할 때(예: "RINDAMAN2426의 코멘트 처리")는 스레드 첫 작성자가 아니라 스레드 안의 *아무* 코멘트라도 그 리뷰어가 단 경우를 모두 수집한다.** 작성자가 시작한 스레드에 리뷰어가 답글로 질문·제안을 남기는 경우가 흔하므로, `.comments.nodes[0].author.login == <reviewer>`로 거르면 이런 스레드를 놓친다. 대신 `any`로 거른다:

```bash
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved | not)
        | select(any(.comments.nodes[]; .author.login == "<reviewer>"))'
```

---

### Phase 2: 처리 계획 수립

수집한 코멘트를 분석해서 두 그룹으로 나눈다.

**유효성 판단 먼저**: 코멘트가 잘못된 전제, 이미 반영된 내용, 또는 무관한 FYI/praise라면 → skip 처리하고 이유를 명시.

**코멘트를 표면 그대로 반영하지 말고, 한 번 더 생각해서 근본 개선으로 확장한다.** 리뷰어의 코멘트는 대개 "이 지점에서 뭔가 걸린다"는 신호이지, 반드시 문자 그대로 따라야 할 스펙이 아니다. 반영에 들어가기 전에 두 가지를 생각한다:

1. **코멘트 뒤의 의도를 읽고, 더 나은 방향이 있으면 그쪽으로.** 리뷰어가 지적한 표면 증상만 고치면 정작 그가 신경 쓴 근본 문제는 그대로 남을 수 있다. 주변 코드를 함께 보고, 코멘트가 가리키는 진짜 문제를 더 깔끔하게 푸는 방법(기존 코드베이스의 패턴 재사용, 같은 문제가 반복되는 다른 지점까지 함께 정리 등)이 있으면 그 방향으로 반영한다. 문자 그대로의 요청과 다른 방향을 택했다면 reply에서 왜 그렇게 했는지 짧게 설명한다.
2. **변경의 파급을 끝까지 따라간다.** 하나의 코멘트를 반영하면 그것을 참조하는 다른 코드, 그 코드에 대한 테스트, 관련 주석/문서까지 영향을 받을 수 있다. 예를 들어 "이 코드 삭제해도 될 것 같아요"는 그 코드만 지우는 게 아니라 → 그걸 부르던 호출부 정리, 이제 죽은(dead) 다른 코드나 불필요해진 테스트 제거, 오래된 주석 갱신까지 포함한다. 반쪽짜리 반영은 리뷰어가 다시 지적하게 만든다.

이건 "관련 없는 드라이브바이 리팩터링"(Anti-patterns 참조)과는 다르다 — 코멘트가 **인과적으로 요구하거나 코멘트가 짚은 문제를 직접 개선하는** 변경은 반영 범위 안이고, 코멘트와 무관한 김에 하는 청소는 범위 밖이다.

이 관점은 그룹 분류에도 영향을 준다. 표면적으론 trivial해 보여도 파급이 크거나 방향 판단이 필요하면 그룹 B로 올려 사용자에게 확인한다. 반대로 파급까지 포함해도 자명하면 그룹 A에서 파급분까지 한 번에 처리한다.

**비슷한 변경끼리 묶기**: 같은 파일·같은 패턴에 해당하는 코멘트는 하나의 처리 단위로 묶어도 된다. 단, 원문은 모두 보존.

#### 그룹 A: 즉시 처리 (trivial)
- 단순 오탈자, 네이밍 변경, 명확한 버그 수정, 스타일 통일 등
- 트레이드오프 없이 구현 방향이 자명한 것

#### 그룹 B: 사용자 검토 필요
- 구현 규모가 큰 변경
- "왜 이렇게 했나요?" 같은 단순 질문 (답변으로 해결)
- 트레이드오프가 있거나 판단이 필요한 것
- 리뷰어의 의도가 불분명한 것

**의도를 묻는 질문의 답변 초안은 `justify-pr` 스킬을 참조한다.** "왜 이렇게 구현했는지", "이게 최선인지" 류의 코멘트면 `../justify-pr/SKILL.md`의 분석 관점(왜 이렇게 할 수밖에 없었는가 / 이게 최선인가, 대안 stress-test와 근거 인용)을 읽고 그 기준으로 답변을 잡는다. stress-test 결과 리뷰어 지적이 맞다면 정당화 답변 대신 수정 항목으로 사용자에게 보고한다.

---

### Phase 2.5: 이모지로 ack 남기기

**커밋·푸시·구현을 시작하기 전에**, 분류한 각 코멘트에 이모지 reaction을 달아 "코멘트를 확인했다"는 신호를 먼저 남긴다. (reply가 아니라 **reaction**이다.)

| 그룹 | 이모지 | 의미 |
| --- | --- | --- |
| 그룹 A (즉시 처리) | 👍 `+1` | "확인했고, 좋아 보입니다 — 곧 반영할게요" |
| 그룹 B (검토 필요) | 👀 `eyes` | "확인했고, 고민 중입니다" |

각 thread의 **리뷰어가 단 대표 코멘트**(보통 thread를 시작한 코멘트, 또는 처리 대상이 된 그 코멘트)에 reaction을 단다. PR review comment의 reaction endpoint를 쓴다:

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions \
  -f content="+1"    # 그룹 A
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/reactions \
  -f content="eyes"  # 그룹 B
```

- `comment_id`는 Phase 1에서 수집한 comment `url`의 `#discussion_r{comment_id}`에서 추출한다.
- 이미 같은 reaction이 달려 있으면 GitHub이 중복 없이 처리하므로 그대로 두면 된다.
- skip 처리한(유효하지 않다고 판단한) 코멘트에는 reaction을 달지 않는다 — 그건 reply로 이유를 설명한다.

---

### Phase 3: 즉시 처리 (그룹 A)

> **EXPERIMENTAL (2026-07-02, 시험 적용)** — 되돌릴 때는 이 블록을 통째로 지우고 아래
> "Fallback: 직접 구현"의 제목을 다시 "Phase 3: 즉시 처리 (그룹 A)"로 바꾸면 된다. 또는
> 이 변경을 도입한 커밋을 `git revert`.
>
> 그룹 A 구현을 Claude가 직접 하는 대신 `codex:codex-rescue` 서브에이전트에 **그룹 A
> 전체를 한 번에** 위임해본다.

**위임 절차:**

1. 그룹 A 각 항목을 `{file, line, comment body, comment url, 제안하는 수정 방향}`으로
   정리한다(Phase 2에서 이미 분류한 내용을 그대로 씀).
2. `Agent` 도구로 `subagent_type: "codex:codex-rescue"`를 **한 번만** 호출해서 정리한
   항목 전체를 하나의 태스크로 넘긴다. 프롬프트에 반드시 포함할 것:
   - 항목 목록 전체(파일/라인/코멘트 원문/코멘트 URL/수정 방향)
   - 커밋 규칙: 항목(또는 묶음)마다 `git commit --no-verify -m "fix: <설명>"`으로 커밋
   - 출력 계약: 커밋 SHA와 그 커밋이 반영한 코멘트 URL(또는 항목 번호)의 매핑을 마지막에
     정리해서 반환 — Phase 5 reply의 커밋 링크에 필요
   - 각 항목은 코멘트를 문자 그대로가 아니라 의도대로 반영하고, 변경의 파급(호출부·
     죽은 코드·불필요해진 테스트·오래된 주석)까지 함께 정리할 것 (Phase 2의 "근본 개선으로
     확장" 원칙을 그대로 전달)
   - 단, 코멘트와 무관한 드라이브바이 리팩터링은 금지
3. `--write` 여부는 `codex:codex-rescue`가 기본으로 write-capable 실행을 택하므로 별도
   지정 불필요. 규모가 작고 명확하므로 foreground로 진행한다.
4. Codex 세션이 끝나면 검증한다:
   - `git log --oneline -<그룹A 항목 수>`로 커밋 개수가 항목 수와 맞는지
   - `git status --short`로 커밋 안 된 변경이 남아있지 않은지
   - 보고받은 SHA-코멘트 매핑이 실제 커밋 메시지/diff와 맞는지
   - 이상하면 Phase 4로 넘어가지 말고 사용자에게 먼저 알린다.
5. 검증 통과 시 Codex가 보고한 SHA 매핑을 Phase 5의 "코멘트-커밋 SHA" 기록으로 그대로
   사용한다.

Codex 결과가 기대에 못 미치면(엉뚱한 수정, 커밋 컨벤션 무시 등) 이번 실행분만 되돌리고
(`git reset --hard` 전에 `git status` 확인) 아래 Fallback으로 직접 구현한다.

---

#### Fallback: 직접 구현 (되돌릴 때 이 제목을 "Phase 3: 즉시 처리 (그룹 A)"로 바꿔서 사용)

그룹 A에 해당하는 항목을 순서대로 구현한다.

**커밋 규칙:**
- 코멘트 하나(또는 묶음)를 반영할 때마다 커밋
- 반드시 `--no-verify` 옵션으로 pre-commit hook 우회
- 커밋 메시지: `fix: <간결한 설명>` (예: `fix: rename variable for clarity`)

```bash
git add <changed-files>
git commit --no-verify -m "fix: <description>"
```

**커밋 후 SHA를 기록한다.** Phase 5 reply에서 "이 커밋에서 고쳤다"고 링크하기 위해, 각 코멘트(또는 묶음)와 그걸 반영한 커밋 SHA를 짝지어 둔다.

```bash
git rev-parse HEAD   # 방금 만든 커밋의 SHA
```

---

### Phase 4: 푸시

그룹 A 처리 및 커밋이 모두 완료되면, Reply를 남기기 전에 **한 번** 푸시한다.

```bash
git push
```

---

### Phase 5: Reply 남기기

`my-tone` 스킬을 참고해서 각 처리 완료 코멘트에 적절한 Reply를 남긴다.

**Reply를 남기기 전에 관련 커밋이 먼저 푸시되어 있어야 한다.** Reply에 다는 커밋 링크는 push된 뒤에야 유효하고, 리뷰어가 "고쳤다"는 답을 보고 바로 변경을 확인할 수 있어야 하기 때문이다. 로컬에만 커밋된 상태에서 reply부터 달지 말 것 — Phase 4에서 push를 끝낸 뒤 reply를 남긴다. (Phase 6의 반복 사이클에서도 동일: 새로 반영한 커밋은 reply 전에 push.)

**Reply를 남기기 전 확인:**
- 해당 thread에 이미 적절한 응답이 달려있으면 → **skip** (중복 방지)
- Reply가 없거나 "처리했다"는 내용이 없으면 → 새 reply 작성

**수정 커밋 링크를 붙인다.** 코드 변경으로 처리한 코멘트(그룹 A, 또는 그룹 B 중 반영한 것)는 reply 끝에 Phase 3에서 기록해 둔 수정 커밋 SHA 링크를 붙여 리뷰어가 바로 변경을 확인할 수 있게 한다. 링크 형식:

```
https://github.com/{owner}/{repo}/pull/{number}/commits/{sha}
```

- 한 코멘트를 여러 커밋으로 나눠 처리했으면 해당 커밋들을 모두 링크한다.
- 단순 답변(코드 변경 없음)이나 skip 코멘트에는 커밋 링크를 붙이지 않는다.

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies \
  -f body="<reply text>

<commit-url>"
```

Reply 톤: 짧고 자연스럽게, 1~2문장. 한국어 코멘트엔 한국어로, 영어엔 영어로. 커밋 링크는 본문과 한 줄 띄워 마지막에 둔다.

### Pending review가 있을 때 (예: review-pr과 같은 세션)

내 계정의 pending review가 열려 있으면 위 REST reply endpoint가 422(`user_id can only have one pending review per pull request`)로 실패한다. GitHub이 reply를 새 단건 리뷰로 만들려다 pending 1개 제한에 걸리는 것.

- **순서 권장**: 같은 세션에서 `review-pr` 등으로 pending review를 만들 계획이면, **공개 reply를 먼저 모두 남긴 뒤** pending review를 생성한다. (`justify-pr`는 pending review 없이 바로 다는 방식이라 이 제약과 무관하지만, 반대로 내 pending review가 이미 열려 있으면 `justify-pr`의 직접 코멘트가 422로 막힌다.)
- **이미 pending이 있으면**: GraphQL `addPullRequestReviewThreadReply`에 `pullRequestReviewId`(pending review의 node id, `PRR_...`)와 `pullRequestReviewThreadId`(`PRRT_...`)를 넘겨 답글을 pending review에 합류시킨다. 이 답글은 **pending review submit 시점에야 공개**되므로, 사용자 보고에 그 사실을 명시한다.

```bash
# pending review id와 thread id 조회
gh api graphql -f query='query { repository(owner:"O", name:"R") { pullRequest(number:N) {
  reviews(first:10, states:PENDING) { nodes { id author{login} } }
  reviewThreads(first:100) { nodes { id comments(first:1) { nodes { fullDatabaseId } } } }
} } }'
# 답글을 pending review에 추가
gh api graphql -f query='mutation($threadId:ID!, $reviewId:ID!, $body:String!) {
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId, pullRequestReviewId:$reviewId, body:$body}) { comment { url } }
}' -F threadId=... -F reviewId=... -f body="..."
```

---

### Phase 6: 사용자에게 보고 (그룹 A 요약 + 그룹 B 리스트업)

사용자에게 보고할 때는 **먼저 그룹 A(이미 처리한 작은 변경)를 짧게 요약**한 뒤, **그룹 B(검토 필요)를 리스트업**한다. 그래야 사용자가 "내가 자리를 비운 사이 뭐가 처리됐고, 뭘 봐야 하는지"를 한눈에 본다.

**그룹 A 요약** — 한 줄씩, 각 항목에 코멘트 링크와 커밋 링크를 붙인다:

```markdown
## 처리 완료 (그룹 A)

- <한 줄 요약> — [코멘트](<comment-url>) · [커밋](<commit-url>)
- ...
```

- `comment-url`은 Phase 1에서 수집한 thread comment의 `url`(형식: `https://github.com/{owner}/{repo}/pull/{number}#discussion_r{comment_id}`)을 그대로 쓴다.
- 코드 변경 없이 답변/skip만 한 항목도 처리했다면 여기에 한 줄로 남기되, 커밋 링크는 생략한다.

**그룹 B 리스트업** — 각 항목 제목에 **반드시 코멘트 링크를 건다**. 사용자가 제목을 클릭해 바로 그 코멘트로 이동할 수 있어야 한다:

```markdown
## 검토가 필요한 코멘트

### 1. [<reviewer> — <source type>](<comment-url>)
**원문:**
> <verbatim comment body>

**한 줄 요약:** <무엇을 요청하는지>

**변경 제안:** <구체적인 접근법 / 질문이면 "답변 필요" 명시>

**Effort:** trivial / moderate / larger
```

- `comment-url`은 그룹 A와 동일하게 thread comment의 `url`을 쓴다. 여러 코멘트가 묶인 항목이면 제목에 대표 링크를 걸고, 나머지는 본문에 추가로 나열한다.

리스트업 후 사용자 응답 대기. 사용자가 각 항목에 대해 지시를 주면:
- 반영하기로 한 것 → 구현 → 커밋(`--no-verify`) → 푸시 → Reply
- 스킵하기로 한 것 → Reply만 (또는 "의도한 방향입니다" 등 짧은 설명)
- 추가 논의가 필요한 것 → 다시 질문

이 사이클을 남은 항목이 없을 때까지 반복한다.

---

### Phase 7: 스킬 개선 제안

모든 코멘트 처리가 완료되면, 이번 작업에서 발견한 내용 중 **다음 스킬에 반영할 만한 것**이 있는지 확인하고 정리해서 사용자에게 보여준다.

대상 스킬:
- **`/address-pr`** (이 스킬): 반복되는 패턴, 놓쳤던 케이스, 워크플로우 개선 아이디어
- **`/review-pr`**: 리뷰어가 자주 지적하는 유형, 프로젝트별 컨벤션
- **`/my-tone`**: reply 톤·표현 중 어색했거나 개선할 여지가 있는 것

없으면 이 Phase는 생략한다. 있을 경우 아래 형식으로 짧게 정리:

```markdown
## 스킬 개선 제안

- **`/address-pr`**: <제안 내용>
- **`/review-pr`**: <제안 내용>
- **`/my-tone`**: <제안 내용>
```

사용자가 반영하겠다고 하면 해당 스킬 파일을 직접 수정한다.

---

## GraphQL snippet 참고 (replyUrl 포함 버전)

thread의 첫 번째 comment URL을 기반으로 reply endpoint를 찾는다:

```bash
# comment URL 형식: https://github.com/{owner}/{repo}/pull/{number}#discussion_r{comment_id}
# REST reply: POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/replies
```

---

## Anti-patterns

- resolved thread에 reply 달기
- 구현 없이 "처리했다"고만 reply 달기
- 그룹 A 처리 전에 그룹 B를 보여주기 (순서 지키기)
- 푸시 전에 reply 달기 — reply에 링크한 커밋이 아직 push되지 않으면 링크가 죽는다. 관련 커밋을 먼저 push하고 reply를 남긴다.
- pending review 생성 후에 공개 reply 시도하기 — REST reply가 422로 막힌다. 공개 reply를 먼저 끝내고 pending review를 만들거나, GraphQL로 pending에 합류시킨다.
- 관련 없는 드라이브바이 리팩터링 섞기

---

## Invocation examples

- User: `/address-pr 26593`
- User: "Address PR <https://github.com/org/repo/pull/123>"
- User: "PR 리뷰 코멘트 처리해줘"
