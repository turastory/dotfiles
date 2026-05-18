---
name: address-pr
description: >-
  Checks out a pull request with GitHub CLI (preferring a local git worktree
  under .worktrees/ when possible), collects review and discussion comments, and
  produces a
  per-comment action plan for user confirmation before any implementation. Does
  not post GitHub comments or create commits. Use when the user invokes
  /address-pr, says "address PR", wants to work through PR review feedback
  systematically, or asks to checkout a PR by number or URL and plan fixes from
  review comments.
---

# Address PR (`/address-pr`)

## Purpose

Speed up **responding to PR review feedback** by: checking out the PR locally, **aggregating all feedback**, and producing a **numbered, confirmable plan**—without leaving GitHub comments or making commits during this workflow.

## Hard constraints (non-negotiable)

- **Do not** post replies or review comments on GitHub (`gh pr comment`, review submissions, issue/PR comment APIs used to *write*).
- **Do not** `git commit`, `git push`, or open/update PRs unless the user **explicitly** asks outside this skill’s planning phase.
- This skill ends at a **confirmed plan**; implementation is a **separate** step after the user approves which items to address.

## Prerequisites

1. Run `gh auth status`. If authentication fails or the wrong account is active, follow repo conventions (e.g. `gh auth switch --user <user>`) and retry.
2. Prefer running from the **target repository** clone (or worktree). Resolve `owner/repo` via `gh repo view --json nameWithOwner -q .nameWithOwner` when needed.

## Prefer git worktrees

**When not already on a dedicated worktree for this PR**, prefer isolating the PR branch in a **separate worktree** so the main clone keeps its current branch and working tree.

- **Location:** Prefer a **project-local** path under **`.worktrees/`** at the repository root (e.g. `.worktrees/pr-26593/`). Use `worktrees/` only if the project already standardizes on it; follow **using-git-worktrees** for directory rules and safety checks (`git check-ignore`, `.gitignore` if needed).
- Typical pattern from the **main repo** root: fetch the PR head into a local branch ref, then `git worktree add .worktrees/pr-<number> <branch>` (or an equivalent path under `.worktrees/`) and run subsequent `gh` / file reads from that path (or pass `-C <path>` where supported).
- **If** the user explicitly wants to stay in the current directory or a worktree is impractical (e.g. single shallow clone), fall back to `gh pr checkout` in place and state that trade-off briefly.

## Workflow

### 1. Resolve input and check out the PR

Accept either:

- A **PR number** (e.g. `26593`), or  
- A **PR URL** (e.g. `https://github.com/org/repo/pull/26593`).

**Preferred:** check out via a **worktree** under **`.worktrees/`** (see § Prefer git worktrees).

**Fallback** when not using a worktree: check out the branch in the current clone:

```bash
gh pr checkout <number-or-url>
```

If checkout fails (wrong repo, missing access, merge conflicts), report the error clearly and stop until the user fixes the environment.

### 2. Collect review feedback (read-only)

Gather **all** of the following that exist:

| Source | Suggested `gh` usage |
| ------ | -------------------- |
| Inline review threads (code threads, with `isResolved` flag) | GraphQL via `gh api graphql` on `repository.pullRequest.reviewThreads` — see snippet below |
| PR conversation / issue comments | `gh pr view <number> --comments` and/or `gh api repos/{owner}/{repo}/issues/{number}/comments` |
| Review summaries (APPROVE / COMMENT / REQUEST_CHANGES) | `gh pr view <number> --json reviews` or `gh api repos/{owner}/{repo}/pulls/{number}/reviews` |

**Skip resolved threads.** Inline review comments are grouped into threads, and each thread has an `isResolved` flag. Filter these out *before* building the plan — the user has already dealt with them. Use GraphQL because the REST `pulls/{number}/comments` endpoint does not expose `isResolved`:

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

For PR conversation comments and review summaries (which are not thread-scoped and have no resolved state), include them all.

**Do not dedupe.** Every unresolved comment goes into the report as its own entry — even if two reviewers say similar things, keep both so the user can see the full picture.

### 3. Build the plan (one entry per comment)

The report must include **every** unresolved comment collected in step 2 — one entry per comment, no summarization-away, no merging "similar" items. For each entry, produce:

1. **Reference**: reviewer (or bot) login, source type (inline thread / PR conversation / review summary), and **code location** when applicable — file path and line number (use `line` for inline comments; fall back to `originalLine` if the line has shifted). Format code locations as `<path>:L<line>` so the user can jump directly to the referenced position. Include the comment URL when available.
2. **Original text (verbatim)**: the comment `body` as-is, quoted in a markdown blockquote. Do not paraphrase or trim. If the comment is long, still include it fully.
3. **Summary**: what the reviewer is asking for, in plain language (this is *in addition to* the verbatim text, not a replacement).
4. **Suggested fix**: concrete approach (files to touch, pattern to apply, tests to add/update). For comments that are pure praise or non-actionable ("nice!", "lgtm"), state explicitly that no action is needed.
5. **Suggested reply (draft)**: a **short** reply the user could post back to the reviewer — 1–2 sentences max, plain prose, no boilerplate ("Thanks for the review!"). Always wrap the full draft reply in double quotes. Match the comment's language (e.g. Korean comment → Korean reply). Use inline code quotes only where they are necessary for exact identifiers, paths, commands, or symbols; avoid code quotes for ordinary prose. Concrete examples: "맞는 지적이라 `foo`로 변경했습니다.", "의도된 동작입니다. `bar`는 nullable이라 체크가 필요합니다.", "다음 PR에서 별도로 다루겠습니다." This is a **draft only**; the skill never posts it.
6. **Effort / risk** (short): trivial / moderate / larger; note if it might conflict with other items.

Group optional: by severity (blocking vs nit), or by file — whichever makes faster review for the user. Grouping must not drop or collapse entries.

### Report style and example

Use a consistent, scan-friendly report. Start with a short note about checkout/worktree status, then list the actionable entries. Keep the original comment verbatim and do not collapse multiple unresolved comments into one item.

Recommended structure:

```markdown
PR <number> is checked out on <branch/worktree status>. I skipped resolved threads and collected <N> unresolved inline threads plus any PR conversation comments or review summaries.

## Response Plan

### 1. <author> <source type>
Reference: `<path>:L<line>`  
URL: <comment URL>

Original:
> <verbatim comment body>

Summary: <plain-language interpretation>

Suggested fix: <specific files/pattern/tests>

Suggested reply: "<1-2 sentence draft reply>"

Effort / risk: <trivial / moderate / larger, plus conflict note if any>

## Confirmation

Please choose which items to address, defer, or skip.
```

Example based on a Backoffice PR review:

```markdown
PR 27727 is already on the matching head branch, so I did not check it out again. I skipped resolved threads and collected 5 unresolved inline threads plus PR conversation/review-summary items.

## Response Plan

### 1. cursor inline thread
Reference: `internal-products/frontends/backoffice/src/pages/event/management/group/components/event-group-participation/useEventGroupParticipationForm.ts:L184`  
URL: https://github.com/ridi/ridi/pull/27727#discussion_r3245679381

Original:
> ### `onDelete` lacks error handling, fails silently
>
> `onDelete` 콜백에 try-catch가 없어서 `deleteEventParticipation`이 실패하면 사용자에게 에러 피드백 없이 실패합니다.

Summary: Deleting participation can fail without user-facing feedback.

Suggested fix: Add try/catch around `deleteEventParticipation`, show an error snackbar using the server message when available, and keep success/reset behavior unchanged.

Suggested reply: "`onDelete` 실패 시에도 snackbar로 오류가 보이도록 처리하겠습니다."

Effort / risk: trivial.

### 2. gyu-kang inline thread
Reference: `internal-products/frontends/backoffice/src/components/forms/ListField.tsx:L148`  
URL: https://github.com/ridi/ridi/pull/27727#discussion_r3246587825

Original:
> visibleRowCount typing이 optional number니까, visibleRowCount !== undefined가 이해가 쉬운 표현 같네요~

Summary: The condition should reflect the optional-number type directly.

Suggested fix: Replace `typeof visibleRowCount === 'number'` with `visibleRowCount !== undefined` wherever the visible-row branch is selected.

Suggested reply: "맞습니다. optional number 의도가 더 잘 드러나도록 조건을 바꾸겠습니다."

Effort / risk: trivial.

## Confirmation

Please choose: address all, address only specific item numbers, defer, or skip.
```

### 4. User confirmation (required)

Present a **checklist** the user can answer explicitly, for example:

- Address / defer / skip — per item or by group.  
- Clarifications needed from the reviewer (list questions only; **do not** post them to GitHub inside this skill unless the user later asks).

**Stop** after the user confirms scope. Do not start implementation inside this skill run unless the user clearly asks to proceed to coding in the same thread.

### 5. Handoff

After confirmation, the next step is normal implementation work (only for approved items), following the user’s usual commit/PR conventions—**outside** the constraints of § Hard constraints once the user requests commits/pushes.

## Anti-patterns

- Posting “done” or “fixed” on the PR automatically.  
- Silent partial scope (always make defer/skip explicit).  
- Mixing this workflow with drive-by refactors unrelated to review comments.

## Invocation examples

- User: `/address-pr 26593`  
- User: “Address PR <https://github.com/org/repo/pull/123>”  
- User: “Checkout PR and list review comments with a fix plan before I code”
