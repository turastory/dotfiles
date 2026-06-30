---
name: clean-up-pr
description: >-
  Cleans up AI-reviewer noise on a GitHub PR: collects unresolved inline review
  threads from the `claude` and `cursor` (Cursor Bugbot) bots, auto-resolves the
  ones whose suggestion is already applied in the current code, and deletes the
  stale superseded "Claude finished …" conversation comments from claude (keeping
  the newest). Use when the user invokes /clean-up-pr, says "clean up the PR",
  "PR 정리", wants to clear out resolved/outdated bot review threads, or remove
  the pile of stale claude bot comments cluttering a PR conversation.
---

# Clean up PR (`/clean-up-pr`)

## Purpose

PR에 쌓인 **AI 리뷰어(claude / cursor) 노이즈를 정리**한다. 두 가지를 한다:

1. **이미 반영된 inline 리뷰 스레드를 resolve** — `claude`·`cursor`가 단 미해결 inline 코멘트 중, 현재 코드에 제안이 실제로 반영된 것만 닫는다.
2. **stale해진 claude conversation 코멘트를 삭제** — `**Claude finished … task**` 류의 자동 리뷰 요약 코멘트가 푸시할 때마다 쌓이는데, 최신 1개만 남기고 옛것들을 지운다.

claude는 GitHub Action이 푸시마다 새 리뷰 요약 코멘트를 올려서 대화 탭에 같은 류의 코멘트가 십수 개씩 쌓인다. 그 대부분은 옛 커밋 기준이라 의미가 없다. inline 스레드도 고친 뒤 resolve를 안 해두면 미해결로 남아 리뷰 상태를 가린다. 이 스킬은 그 두 잡음을 안전하게 걷어낸다.

## 안전 원칙 (이게 핵심)

- **inline resolve는 자동**으로 한다 — resolve는 되돌릴 수 있고(스레드 unresolve 가능), 정보를 잃지 않는다.
- **코멘트 삭제는 되돌릴 수 없다.** 삭제 대상 목록을 먼저 사용자에게 보여주고 **승인을 받은 뒤에만** 지운다.
- **claude/cursor 외 사람의 코멘트·스레드는 절대 건드리지 않는다.** cursor의 `<!-- BUGBOT_REVIEW -->` 요약 코멘트도 그대로 둔다(삭제 대상은 claude conversation 코멘트뿐).
- inline 스레드를 resolve할 때 **`isOutdated`만 보고 닫지 않는다.** outdated는 "그 줄 근처 코드가 바뀌었다"는 뜻일 뿐 "고쳤다"가 아니다. 현재 코드를 읽어 제안이 실제 반영됐을 때만 닫는다.

## Prerequisites

1. `gh auth status` 실행. 인증 실패·계정 불일치 시 안내 후 중단. 이 repo는 `yoonho-alan` 계정 기준.
2. `gh repo view --json nameWithOwner -q .nameWithOwner`로 `owner/repo` 확인.
3. PR 식별:
   - 번호/URL이 주어지면 그것을 사용.
   - 없으면 현재 브랜치의 PR을 `gh pr view --json number,headRefName,headRefOid,url`로 찾는다. 연결된 PR이 없으면 중단하고 PR을 물어본다.
4. **현재 코드 기준 확인**: Phase 2의 "반영 여부" 판단은 PR head 기준이어야 한다. 로컬 `HEAD`가 `headRefOid`와 다르면 해당 브랜치를 checkout하거나 fetch한 뒤 진행한다. 로컬에 없으면 파일 내용을 `gh api repos/{owner}/{repo}/contents/{path}?ref={headRefOid}`로 읽어도 된다.

---

## Phase 1: 수집 (read-only)

### 1a. 미해결 inline 스레드 (claude / cursor)

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$number:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$number){
        reviewThreads(first:100){
          pageInfo { hasNextPage endCursor }
          nodes {
            id isResolved isOutdated path line originalLine
            comments(first:20){ nodes { author{login} body diffHunk url createdAt } }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
        | select(.isResolved | not)
        | select(any(.comments.nodes[]; .author.login == "claude" or .author.login == "cursor"))'
```

- `pageInfo.hasNextPage`가 true면 `endCursor`로 계속 페이지네이션.
- 각 스레드의 `id`는 resolve mutation에 필요하니 보관.
- 사람이 끼어든 스레드(claude/cursor가 시작했지만 리뷰어/작성자가 답글로 논의 중)는 자동 resolve 대상에서 빼고 Phase 4에서 따로 보고한다 — 논의가 끝나지 않았을 수 있다.

### 1b. claude conversation 코멘트

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$number:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$number){
        comments(first:100){
          pageInfo { hasNextPage endCursor }
          nodes { databaseId author{login} createdAt url body }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number> \
  --jq '.data.repository.pullRequest.comments.nodes[] | select(.author.login=="claude")'
```

- `databaseId`는 삭제 REST 호출에 쓴다.
- 이건 PR **대화(conversation/issue) 코멘트**다. claude의 빈 review 요약 객체(`reviews`, body 없음)는 inline 코멘트의 컨테이너이므로 **수집·삭제 대상이 아니다** — 건드리면 inline 코멘트가 고아가 된다.

---

## Phase 2: inline 스레드 resolve (자동)

수집한 각 미해결 claude/cursor 스레드에 대해:

1. 스레드의 봇 코멘트 본문과 `diffHunk`를 읽어 **무엇을 제안했는지** 파악한다.
2. **현재 코드(PR head)** 의 `path` 위치를 읽는다. 줄 번호는 코멘트 이후 이동했을 수 있으니 줄에만 의존하지 말고 주변 코드를 본다.
3. 판단:
   - 제안이 **실제로 반영됨** → resolve.
   - 제안이 더 이상 적용 불가(코드가 통째로 사라지거나 대체되어 지적이 무의미) → resolve.
   - **아직 미반영인데 코드가 그대로/유효** → **resolve하지 않고** Phase 4 보고에 남긴다. `isOutdated`라도 마찬가지 — 줄만 밀렸을 수 있다.

resolve mutation:

```bash
gh api graphql -f query='
  mutation($threadId:ID!){
    resolveReviewThread(input:{threadId:$threadId}){
      thread { id isResolved }
    }
  }' -F threadId=<thread-id>
```

resolve한 스레드는 `path:line`과 "무엇이 어디서 반영됐는지" 한 줄을 기록해 둔다(보고용).

---

## Phase 3: stale claude 코멘트 삭제 (승인 후)

### 3a. 삭제 대상 선정

Phase 1b에서 모은 claude conversation 코멘트를 `createdAt` 기준 정렬한다.

- **가장 최신 1개는 남긴다** (현재 head 기준 리뷰 = 의미 있는 기록).
- 나머지(더 오래된 것)는 모두 삭제 대상.
- 코멘트가 1개뿐이면 삭제할 게 없다.

### 3b. 계획 제시 → 승인 대기

삭제는 비가역이므로 **반드시 먼저 목록을 보여주고 멈춘다.** Phase 2에서 자동으로 resolve한 결과도 함께 요약한다:

```markdown
## 정리 계획

### ✅ resolve 완료 (자동, N개)
- ProgressSection.tsx:53 — null 가드 반영됨(현재 코드 확인)
- rewardInfoState.ts:131 — 제안대로 변경됨
- ...

### 🗑 삭제 예정 — claude conversation 코멘트 (M개)
> 최신 1개는 남깁니다: [issuecomment-<id>](<url>) (<createdAt>)

- [issuecomment-<id>](<url>) — <createdAt> — "Claude finished … 58s" (superseded)
- ...

### 🔎 그대로 둔 미해결 스레드 (K개)
- SomeFile.ts:88 (cursor) — 아직 미반영으로 판단, 확인 필요
- OtherFile.ts:12 (claude) — 사람이 답글 단 진행 중 논의

이 코멘트들을 삭제할까요?
```

사용자가 승인하면 3c로. "최신도 지워라" / "이건 빼라" 같은 조정 지시는 반영한다.

### 3c. 삭제 실행

승인된 각 코멘트:

```bash
gh api -X DELETE repos/<owner>/<repo>/issues/comments/<databaseId>
```

---

## Phase 4: 보고

```markdown
## 정리 완료

- inline 스레드 resolve: N개
- claude 코멘트 삭제: M개 (최신 1개 유지)
- 그대로 둔 미해결 스레드: K개 ↓

### 확인이 필요한 미해결 스레드
- [<path:line> (<bot>)](<comment-url>) — <왜 안 닫았는지 한 줄>
```

미해결로 남긴 스레드는 사용자가 직접 봐야 하므로 코멘트 링크와 이유를 함께 보여준다. 없으면 그 섹션은 생략.

---

## Anti-patterns

- `isOutdated`만 보고 inline 스레드를 닫기 — 줄만 밀린 것을 "고쳤다"로 오인.
- 미반영 스레드를 자동 resolve해서 유효한 지적을 묻어버리기.
- 삭제 목록을 보여주지 않고 바로 코멘트 삭제하기.
- 최신 claude 리뷰 코멘트까지 지워 현재 기준 기록을 없애기(사용자가 명시적으로 시키지 않는 한).
- cursor의 `BUGBOT_REVIEW` 요약이나 사람의 코멘트·스레드를 건드리기.
- claude의 빈 review 컨테이너를 삭제해 inline 코멘트를 고아로 만들기.

## Invocation examples

- `/clean-up-pr` (현재 브랜치 PR)
- `/clean-up-pr 29363`
- `/clean-up-pr https://github.com/ridi/ridi/pull/29363`
- "이 PR claude/cursor 코멘트 정리해줘"
