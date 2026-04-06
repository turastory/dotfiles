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

Gather **all** of the following that exist (dedupe by author + file + line + body when possible):

| Source | Suggested `gh` usage |
|--------|----------------------|
| PR conversation / issue comments | `gh pr view <number> --comments` and/or `gh api repos/{owner}/{repo}/issues/{number}/comments` |
| Inline review comments (code threads) | `gh api repos/{owner}/{repo}/pulls/{number}/comments` |
| Review summaries (APPROVE / COMMENT / REQUEST_CHANGES) | `gh pr view <number> --json reviews` or `gh api repos/{owner}/{repo}/pulls/{number}/reviews` |

Use `--jq` filters to keep output manageable when JSON is large.

### 3. Build the plan (one entry per thread or distinct comment)

For **each** distinct piece of feedback, produce:

1. **Reference**: reviewer (or bot), optional file/path and line, link or `gh pr view` context if available.  
2. **Summary**: what the reviewer is asking for, in plain language.  
3. **Suggested fix**: concrete approach (files to touch, pattern to apply, tests to add/update).  
4. **Effort / risk** (short): trivial / moderate / larger; note if it might conflict with other items.

Group optional: by severity (blocking vs nit), or by file—whichever makes faster review for the user.

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
- User: “Address PR https://github.com/org/repo/pull/123”  
- User: “Checkout PR and list review comments with a fix plan before I code”
