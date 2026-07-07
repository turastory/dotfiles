---
name: justify-pr
description: >-
  Analyzes the user's own PR from the "왜 이렇게 할 수밖에 없었는가 / 이게
  최선인가" perspective and posts author-side inline comments that justify
  non-obvious implementation decisions to reviewers. Resolves the PR via GitHub
  CLI (number, URL, or current branch), finds the decision points reviewers
  would question, stress-tests each against realistic alternatives, drafts
  comments with my-tone, and posts them directly (immediately visible, no
  pending review). Use when the user invokes /justify-pr, asks to justify a PR
  or a design decision, wants "왜 이렇게 했는지" explanation comments before
  requesting review, or needs reviewer-facing rationale for risky-looking code.
---

# Justify PR (`/justify-pr`)

## Purpose

Leave author-side inline comments on **the user's own PR** that justify non-obvious implementation decisions, so reviewers understand why the code is shaped the way it is.

Every comment must answer one of two questions for a spot where a reviewer would otherwise stop and wonder:

- **왜 이렇게 할 수밖에 없었는가** — what constraint, failed alternative, or external requirement forced this shape.
- **이게 최선인가** — among the realistic alternatives, why this one wins.

Typical timing: right before requesting review on a PR with non-trivial design choices, or during review when a follow-up change needs context. Do not use this for reviewing someone else's PR (`review-pr`) or for processing reviewer feedback (`address-pr`).

## Tone and writing style

Before writing comment bodies, read `../my-tone/SKILL.md` and apply its "내 PR에 남기는 inline 설명" and "AI 작성 표기" guidance.

Comment bodies should be brief, natural, and reviewer-facing:

- State facts (constraints, alternatives tried, verification), not persuasion. 정당화 코멘트는 설득이 아니라 사실 전달이어야 한다.
- Conclusion first; reasons in one short paragraph.
- End every GitHub comment body with the AI footer from my-tone (e.g. `_Sent by Fable_`).

## Hard constraints

- **Do not** edit code, resolve review threads, `git commit`, or `git push`.
- **Do not** reply to reviewer threads in this workflow. Use `address-pr` when processing and replying to reviewer feedback.
- **Do not justify code that should be fixed.** The analysis step exists precisely to catch this: if a realistic alternative is actually simpler or safer, report it to the user as "fix before justifying" instead of writing a defensive comment.

## Prerequisites

1. Run `gh auth status`. If authentication fails or the wrong account is active, follow repo conventions and retry.
2. Run `gh repo view --json nameWithOwner -q .nameWithOwner` to resolve `owner/repo`.
3. Run `git status --short`. Since this skill is read-only, do not disturb local work; use a worktree if checkout is needed.

## Resolve PR and head

| Input | Action |
|---|---|
| PR number or URL | Run `gh pr view <input> --json number,baseRefName,headRefName,headRefOid,url,title,body`. Check out only if local file context is needed. |
| No input / current branch | Run `gh pr view --json number,baseRefName,headRefName,headRefOid,url,title,body`. If no linked PR exists, stop and ask for the PR; this skill needs a GitHub PR to comment on. |

Record:

- PR number and URL.
- `baseRefName`, `headRefName`, and `headRefOid`.
- Local `HEAD`; if it does not match `headRefOid`, fetch or check out the PR head before trusting line numbers.

## Analyze: find and stress-test the decisions

This is the heart of the skill. Justification that hasn't been stress-tested is just marketing.

1. Read PR title/body, the current diff (`gh pr diff <number>` or `git diff <base>...HEAD`), recent commits, and any existing review context (inline threads via GraphQL `reviewThreads`, conversation comments, review summaries). Closed/superseded sibling PRs are prime evidence — check for them.
2. List the decision points a reviewer is likely to question: a new component or abstraction instead of patching an existing one, off-pattern or hacky-looking code, forced/overridden options, dropped functionality or trade-offs, scope boundaries, unusual verification paths.
3. For each decision point, answer honestly before writing anything:
   - What are the realistic alternatives? (patching the existing code, a library built-in, a smaller fix, a different structure, not doing it at all)
   - Why does each alternative fail or lose? Cite concrete evidence: a closed PR that tried it, a library limitation, a QA/PM requirement, a verification result.
   - If the honest answer to "이게 최선인가" is "no" or "unclear" — do not write a comment. Surface it to the user as a "fix before justifying" finding.
4. Skip what the PR body or code comments already explain. Inline justify comments add what only the author's history knows: alternatives tried, external constraints, verification paths.

## What deserves a justify comment

Prioritize a few high-value comments:

| Signal | Comment purpose |
|---|---|
| New component/abstraction instead of patching existing code | Explain which alternatives were tried or considered and why they lose. |
| Risk-looking but intentional code (DOM hacks, forced flags, off-pattern shape) | Explain the constraint that makes this shape intentional — only if it is actually sound. |
| Trade-off | Explain compatibility, rollout, performance, dropped functionality, API contract, or data constraint, and why it was accepted. |
| Scope boundary | Say what is intentionally deferred to another PR or rollout step. |
| Non-obvious verification | Point to the important test, harness, fixture, or manual verification path. |

Skip:

- code whose intent is obvious from the diff;
- anything the PR description or a code comment already covers;
- code that should be fixed instead of explained;
- explaining every hunk.

## Post comments directly

Unlike `review-pr`, do **not** collect comments into a pending review. Justify comments must be visible before reviewers start reading, so post each one immediately.

1. First check for an existing pending review by the current user (GraphQL `reviews(states: PENDING)`). If one exists, the REST endpoint below fails with 422 (`user_id can only have one pending review per pull request`) — tell the user and ask whether to submit/discard the pending review first or append the comments to it instead.
2. Post each comment on the new side of the diff:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments \
  -f commit_id=<headRefOid> -f path=<path> -F line=<line> -f side=RIGHT \
  -f body=@<body-file>
```

3. If a line anchor fails because the diff is stale, refresh the PR head and recalculate line numbers instead of guessing.

## Output to the user

After posting, report:

- PR URL.
- Comment count and the URL of each posted comment.
- File/line and one-line gist for each comment.
- Any "fix before justifying" findings that were not commented.

## Anti-patterns

- Writing justification without stress-testing the decision first (persuasion comments).
- Hiding real issues behind explanatory prose.
- Duplicating the PR description or existing code comments.
- Collecting comments into a pending review — this skill posts directly.
- Replying to reviewer threads instead of using `address-pr`.
- Explaining every hunk.

## Invocation examples

- `/justify-pr 29897`
- `/justify-pr https://github.com/org/repo/pull/123`
- "리뷰어분들이 왜 이렇게 했는지 궁금해할 것 같은데, 설명 코멘트 달아줘"
