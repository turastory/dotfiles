---
name: create-pr
description: >-
  Creates a GitHub draft pull request with a well-written title and body using
  `gh pr create --draft`. Use this skill when the user invokes /create-pr, /pr,
  says "create PR", "open PR", "PR 작성", or asks to prepare a pull request
  from the current branch. It inspects the user's recent PRs first and matches
  their style, tone, and level of detail.
---

# Create PR (`/create-pr`, `/pr`)

## Purpose

Prepare a practical PR title and body for the current branch, then create a draft PR with:

```bash
gh pr create --draft --title "<title>" --body "<body>"
```

The PR should be created as draft so the user can review it before marking it ready.

## Tone and writing style

Before drafting the PR title/body, read `../my-tone/SKILL.md` and apply its PR title/body guidance. Keep this skill focused on GitHub workflow and diff accuracy; use `my-tone` for wording, density, markdown restraint, and the user's usual PR voice.

## Hard constraints

- Use `gh pr create --draft` for the final PR creation step.
- Do not use `gh pr create -w`.
- Do not create a ready-for-review PR unless the user explicitly asks.
- Do not run extra GitHub reads after creation just to verify the PR. Use the URL printed by `gh pr create`.
- Do not commit, push, rebase, or otherwise modify git history unless the user explicitly asks.
- If the branch has not been pushed and `gh pr create --draft` requires a push, ask before pushing.

## Workflow

### 1. Check GitHub auth

Run:

```bash
gh auth status
```

If authentication fails or the wrong account is active, explain the visible account state. Switch accounts only when the intended account is clear from repository instructions or the user tells you which account to use.

### 2. Learn the user's PR style

Resolve the current GitHub username, then inspect recent PRs authored by that user:

```bash
gh api user --jq .login
gh pr list --author <login> --state all --limit 5 --json number,title,body,url
```

Use these PRs to match:

- title style: prefix use, Korean/English mix, imperative vs noun phrase
- body structure: headings, checklist style, test section, issue links
- detail level: short summary vs fuller context
- tone: follow `my-tone`, then tune it to the user's own recent PRs

If recent PR bodies are empty or unavailable, fall back to a concise structure that fits the repository.

### 3. Understand the current branch

Gather enough context to write an accurate PR without over-exploring:

```bash
git status --short
git branch --show-current
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
git log --oneline <base>..HEAD
git diff --stat <base>...HEAD
git diff <base>...HEAD
```

Prefer the PR base branch if it is already known. Otherwise use the repository default branch. If the diff is very large, inspect the changed file list and key hunks first, then read focused files only as needed.

### 4. Draft the title

Keep the title specific and short. Prefer the user's recent PR title pattern over generic conventions.

Good title traits:

- says what changed in one line
- avoids vague words like "update", "misc", or "fix stuff" unless the recent style clearly uses them
- uses a prefix only when the user's recent PRs or repo convention do

### 5. Draft the body

Accuracy matters, but readability comes first. Write like a teammate preparing a reviewable PR, not a formal report. For wording, markdown density, heading choices, and boilerplate restraint, follow `my-tone`.

Typical body shape, only when it matches the user's style:

```markdown
## Summary
- ...

## Test
- ...
```

If the user's recent PRs use Korean headings, shorter labels, issue links, or no headings, follow that instead.

### 6. Create the draft PR

Run the final command with a heredoc for the body so formatting is preserved:

```bash
gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

After this command, stop. Report the PR URL printed by the command, but do not run follow-up GitHub reads just to verify creation.

## Handling common blockers

- If the current branch has no commits compared with the base branch, tell the user there is no PR-ready diff.
- If uncommitted changes exist, include them in your assessment only as local context. Do not stage or commit them unless asked.
- If `gh pr create --draft` says the branch must be pushed, ask the user before running `git push -u origin HEAD`.
- If recent PR lookup fails because of permissions or repo access, report that and continue with the diff-based draft only if enough local context is available.

## Invocation examples

- `/create-pr`
- `/pr`
- `현재 브랜치로 draft PR 만들어줘`
- `PR 제목이랑 본문 적당히 써서 draft로 만들어줘`
