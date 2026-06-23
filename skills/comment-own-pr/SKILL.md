---
name: comment-own-pr
description: >-
  Leaves concise author-side inline comments on the user's own PR as a pending
  review, especially after PR review is already in progress and the author made
  non-trivial follow-up changes that need extra context beyond simply addressing
  reviewer comments. Resolves the PR via GitHub CLI (number, URL, or current
  branch), inspects the current diff and review context, drafts comments with
  my-tone, creates or reuses a pending review, and never submits it. Use when the
  user invokes /comment-own-pr, asks to leave explanatory comments on their own
  PR, or wants reviewers to understand large/intentional follow-up changes.
---

# Comment own PR (`/comment-own-pr`)

## Purpose

Leave short author-side inline comments on **the user's own PR** so reviewers understand non-trivial follow-up changes made during review.

Use this when review is already in progress and the author made changes that are more than a direct "applied review comment" fix:

- A reviewer comment led to a broader implementation change.
- The author added intentional behavior, a trade-off, or a scope boundary while addressing review.
- The follow-up diff is large enough that reviewers may not know what is mechanical vs meaningful.
- The author wants to guide reviewers before they re-review the PR.

Do not use this for general PR review. `review-pr` finds problems in someone else's PR and leaves review comments. `comment-own-pr` leaves explanatory author notes on the user's own PR.

## Tone and writing style

Before writing comment bodies, read `../my-tone/SKILL.md` and apply its "내 PR에 남기는 inline 설명" and "AI 작성 표기" guidance.

Comment bodies should be brief, natural, and reviewer-facing:

- Explain intent, constraint, or verification path only when it reduces reviewer friction.
- Do not over-explain simple review fixes.
- End every GitHub comment body with `_Sent by AI_`.

## Hard constraints

- **Do not submit the review.** Leave it as `PENDING` for the user to inspect and submit.
- **Do not** edit code, resolve review comments, `git commit`, or `git push`.
- **Do not** reply directly to review threads in this workflow. Use `address-pr` when processing and replying to reviewer feedback.
- **Do not** use author comments to justify code that should be fixed. If the scan finds a real issue, report it separately as "fix before commenting".

## Prerequisites

1. Run `gh auth status`. If authentication fails or the wrong account is active, follow repo conventions and retry.
2. Run `gh repo view --json nameWithOwner -q .nameWithOwner` to resolve `owner/repo`.
3. Run `git status --short`. Since this skill is read-only, do not disturb local work; use a worktree if checkout is needed.

## Resolve PR and head

| Input | Action |
|---|---|
| PR number or URL | Run `gh pr view <input> --json number,baseRefName,headRefName,headRefOid,url,title,body`. Check out only if local file context is needed. |
| No input / current branch | Run `gh pr view --json number,baseRefName,headRefName,headRefOid,url,title,body`. If no linked PR exists, stop and ask for the PR; this skill needs a GitHub PR to create pending comments. |

Record:

- PR number and URL.
- `baseRefName`, `headRefName`, and `headRefOid`.
- Local `HEAD`; if it does not match `headRefOid`, fetch or check out the PR head before trusting line numbers.

## Understand what changed during review

Build context before commenting:

1. Read PR title/body and current changed files.
2. Read current diff with `gh pr diff <number>` or `git diff <base>...HEAD`.
3. Read review context enough to understand why the follow-up change exists:
   - inline review threads via GraphQL `reviewThreads` including `isResolved`;
   - PR conversation comments with `gh pr view <number> --comments`;
   - review summaries with `gh pr view <number> --json reviews`.
4. Look at recent commits if useful, especially commits after review comments started.

Comment only where explanation helps the next review pass. Do not duplicate PR description, existing author replies, or already clear reviewer-requested changes.

## What deserves an author comment

Prioritize a few high-value comments:

| Signal | Comment purpose |
|---|---|
| Broad follow-up from a small review comment | Explain why the fix expanded beyond the original comment. |
| Large hunk or multi-file adjustment | Mark what is mechanical vs intentional. |
| Trade-off or constraint | Explain compatibility, rollout, performance, idempotency, API contract, or data constraint. |
| Scope boundary | Say what is intentionally deferred to another PR or rollout step. |
| Non-obvious verification | Point to the important test, smoke check, fixture, or manual verification path. |
| Risk-looking but intentional code | Explain why the shape is intentional, but only if it is actually sound. |

Skip:

- direct one-line review fixes;
- "renamed as requested" style changes;
- code that should be fixed instead of explained;
- comments that would repeat an existing thread reply.

## Prepare pending review comments

For each comment:

1. Use the new side of the diff: `{ "path": "...", "line": <new line>, "side": "RIGHT" }`.
2. Keep the body to 1-3 short sentences.
3. Include `_Sent by AI_` as the final line.

Example body shape:

```markdown
리뷰 반영하면서 이쪽까지 같이 정리했습니다. 기존 분기는 그대로 두면 A/B 기준이 갈라져서, 여기서 한 번에 같은 기준을 보도록 맞췄습니다.

_Sent by AI_
```

## Create or reuse a pending review

Match `review-pr`'s pending-review behavior:

1. Check whether the current user already has a pending review on the PR. GitHub allows one pending review per user per PR, so reuse it when present.
2. If there is no pending review, create one with `gh api repos/<owner>/<repo>/pulls/<number>/reviews --input <payload>`. The payload must include `commit_id` and `comments`, and must **not** include `event`.
3. If a pending review already exists, append comments to it with the GraphQL review-comment mutation available in the current environment (`addPullRequestReviewComment` for diff positions, or `addPullRequestReviewThread` when creating a new thread is required).
4. Verify the review state is `PENDING` and the expected comment count was added.
5. Do not submit.

Use `headRefOid` as `commit_id`. If line anchors fail because the diff is stale, refresh the PR head and recalculate line numbers instead of guessing.

## Output to the user

After creating or updating the pending review, report:

- PR URL.
- Pending review id if available.
- Comment count added.
- File/line summary for each comment.
- Any "fix before commenting" issues that were not commented.
- Verification result showing the review remained `PENDING`.

## Anti-patterns

- Leaving author comments before understanding current review context.
- Posting individual comments or replies instead of pending review comments.
- Submitting the pending review.
- Explaining every hunk.
- Leaving comments for changes that are just direct reviewer requests.
- Hiding real issues behind explanatory prose.

## Invocation examples

- `/comment-own-pr 26593`
- `/comment-own-pr https://github.com/org/repo/pull/123`
- `/comment-own-pr`
