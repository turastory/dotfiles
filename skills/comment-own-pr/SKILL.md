---
name: comment-own-pr
description: >-
  Suggests where and what to write as PR inline comments so reviewers understand
  non-obvious changes before review. Resolves the PR via GitHub CLI (number, URL,
  or current branch), compares against the target branch (usually main), and
  outputs a placement guide plus draft wording only—never posts to GitHub. Use
  when the user invokes /comment-own-pr, asks for pre-review PR notes, or wants
  to justify tricky diffs to reviewers proactively.
---

# Comment own PR (`/comment-own-pr`)

## Purpose

Help the author **prepare** inline PR comments (explanations, trade-offs, context) so reviewers understand the change **before** deep review. The agent **only suggests** placement and wording; the user copies comments into GitHub.

## Hard constraints (non-negotiable)

- **Do not** post comments, reviews, or replies on GitHub (`gh pr comment`, `gh api` writes, review submission APIs, etc.).
- **Do not** `git commit` or `git push` unless the user explicitly asks for something unrelated after this workflow.
- Output is a **suggestion list** for the user to paste manually.

## Prerequisites

1. Run `gh auth status`. If authentication fails or the wrong account is active, follow repo conventions (e.g. `gh auth switch --user <user>`) and retry.
2. Run commands from the **repository clone** (or worktree) that contains the PR branch.

## Resolve PR and base branch

### Input

| Case | Action |
|------|--------|
| **PR number** (e.g. `26593`) | `gh pr checkout <number>` then proceed (or use `-C` on a worktree). |
| **PR URL** | Same as number: `gh pr checkout <url>`. |
| **Nothing / “current branch”** | Stay on the current branch. Resolve PR with `gh pr view --json number,baseRefName,headRefName,url` (no args uses the branch’s linked PR). If no PR exists, treat the branch as the head and use **manual diff** against the target branch only (see below). |

Prefer a **git worktree** under `.worktrees/` when checking out would disturb the user’s main working tree—same spirit as **address-pr** (optional; fall back to in-place checkout if the user prefers).

### Target branch (merge base)

- Prefer **`baseRefName`** from `gh pr view --json baseRefName` when a PR exists.
- Default **`<target>`** = `main` if not specified; also try `origin/main` when local `main` is missing or stale.
- Record the effective diff command: **`git diff <target>...HEAD`** (three-dot) or **`gh pr diff <number>`** for the same logical change set as the PR.

If `gh pr checkout` is not used, ensure **HEAD** is the branch that will be merged (the PR head).

## Build the diff picture

1. **Stats (optional but useful):** `git diff --stat <target>...HEAD` to spot large files.
2. **Full diff:** `git diff <target>...HEAD` or `gh pr diff <number>` (no posting).
3. **File list:** changed files from `git diff --name-only <target>...HEAD`.

Use this to prioritize **where** explanations help most.

## What to flag for “needs a comment”

Prioritize suggestions (not every line—only high-value spots):

| Signal | Why comment |
|--------|-------------|
| **Large diff** in one file or many hunks | Orient reviewers: scope, ordering of changes, what is mechanical vs intentional. |
| **Non-typical patterns** for this codebase | e.g. unusual control flow, raw SQL, feature-flag gates, tight coupling, copied boilerplate with a twist. |
| **Behavioral trade-offs** | Performance vs clarity, backwards compatibility, API contract, idempotency, retries. |
| **Reviewer traps** | Renames mixed with logic edits; moved code; generated or auto-formatted chunks; test-only or fixture-heavy files. |
| **Security / data / PII** | Anything that looks risky without context (even if correct). |
| **Follow-ups** | Intentional deferrals; link to ticket if the user provides one. |

De-prioritize: obvious renames, trivial one-line fixes, standard patterns already common in the repo—unless the user asks for exhaustive coverage.

## Output format (for the user)

For **each** suggested inline comment, produce:

1. **Location**: `path` and approximate **line or line range** on the **new** side of the diff (post-merge view in GitHub). If line numbers are ambiguous, name the **hunk** (function name, unique string) instead.
2. **Why here**: one short sentence on what might confuse reviewers.
3. **Suggested comment text**: concise, ready to paste (bullet or short paragraph). Neutral tone; explain **intent**, **constraints**, or **how to verify**.

Optional summary block at the top:

- **PR**: number or URL (if resolved)
- **Base → head**: `<target>...<branch>`
- **Themes**: 2–4 bullets of what the PR is doing overall (for PR description or first comment, not necessarily inline).

## Anti-patterns

- Posting suggestions to GitHub automatically.
- Dumping a wall of low-value comments on every hunk.
- Rewriting the whole PR as prose—stay scoped to reviewer friction points.

## Invocation examples

- `/comment-own-pr 26593`
- `/comment-own-pr https://github.com/org/repo/pull/123`
- `/comment-own-pr` (current branch’s PR or diff vs `main`)
