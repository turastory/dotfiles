---
name: sync-with-master
description: Syncs the current branch with the latest remote master without checking out master locally. Use when the user wants to merge master into their branch, sync with main, update from origin/master, or master is checked out in another git worktree and pull/checkout master fails.
---

# Sync with Master

Bring the **current branch** up to date with the latest remote `master`. Does **not** require checking out or pulling local `master`.

## When this applies

- `master` is checked out in **another worktree** → `git checkout master` or `git pull` on `master` in this worktree fails or is wrong
- User asks to merge master, sync with main, or catch up with `origin/master`

## Workflow

Run from the **feature worktree** (the branch you want to update).

First check for uncommitted changes:

```bash
git status --short
```

`git fetch` is always safe. `git merge` aborts cleanly (no data loss) if incoming changes touch files you have uncommitted edits in. If `git status` shows local changes, ask the user whether to commit or `git stash` before merging — don't stash/commit on your own.

```bash
git fetch origin master
git merge origin/master
```

Use **`origin/master`**, not local `master`. Local `master` may be stale when another worktree holds it and has not been pulled.

### Optional: fast-forward only

If the branch should only move forward without a merge commit:

```bash
git fetch origin master
git merge --ff-only origin/master
```

If this fails, the branch has diverged — use a normal merge or ask the user whether to rebase.

## After merge

1. If merge conflicts occur, **do not** resolve automatically unless the user asked. List conflicted files and wait for direction.
2. Report: commits merged (or "already up to date"), and whether local `master` differs from `origin/master`.

## Updating local `master` (optional)

Only needed if the user also wants the **local `master` ref** updated. That ref cannot be fast-forwarded from this worktree while `master` is checked out elsewhere.

In the worktree where `master` is checked out (e.g. `git worktree list`):

```bash
git pull origin master
```

Syncing the feature branch does **not** require this step.

## Do not

- `git pull` on `master` in the current worktree when `master` is checked out elsewhere
- `git merge master` when local `master` may lag behind `origin/master` — prefer `origin/master`
- `git fetch origin master:master` while `master` is checked out in another worktree (Git may refuse to update that ref)

## Inspect state (optional)

```bash
git worktree list
git log -1 --oneline origin/master
git log -1 --oneline master    # may be behind origin/master
```
