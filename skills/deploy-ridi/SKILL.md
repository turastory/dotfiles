---
name: deploy-ridi
description: Deploy current branch to either dev/stage environment by applying it onto deploy/dev or deploy/stage (cherry-pick, or merge when there are too many commits or merge commits) and pushing. Triggers the "Books backends Deploy Pipeline for ecs & eks" and "Books frontend Deploy Pipeline for ecs & eks" GitHub Actions workflows. Only trigger when explicitly requested — e.g. "deploy dev", "deploy to stage", "dev deploy", "/deploy-ridi for stage". Do NOT trigger automatically or proactively. This skill is specific to the ridi/ridi repository.
---

# Deploy Ridi

Deploy the current branch to either dev/stage by applying **only that branch's own changes** onto `deploy/dev` or `deploy/stage` and pushing that branch.

The deploy branches are shared and usually lag `master` by many commits. The team convention (visible in the deploy-branch log: `... squash merge to deploy/dev`, `... dev 재배포 (squash)`) is to land **just your feature's diff**, NOT to sync `master` into the shared deploy branch. So the goal is always: add this branch's intended changes to the deploy branch and nothing else.

Available target branches:
- `deploy/dev`
- `deploy/stage`

Default to `deploy/dev` if not specified.

Before using `gh`, run `gh auth status` to check if you are authenticated.

## Steps

1. Record the original branch name.
2. Stash all local changes with `git add --all && git stash push`.
3. Delete the local target branch if it already exists.
4. Fetch the target branch from remote and check it out.
5. Apply the original branch's changes onto the target branch. First figure out what the branch actually contributes, then pick the strategy.
   - **Always compute the branch's real contribution first**: `git diff --stat origin/master...<original-branch>` (three-dot = vs merge-base). This is the set of files/changes that must end up on the deploy branch.
   - Also inspect divergence: `git rev-list --count HEAD..<original-branch>` and `git rev-list --merges HEAD..<original-branch>`. A large count with merge commits usually means the branch has merged `master` and the deploy branch lags `master` — so a plain cherry-pick/merge would drag the **entire `master` catch-up** (often hundreds of unrelated files) onto the shared deploy branch. Don't do that.
   - **Decide the strategy:**
     - **Squash-only (preferred default).** When the branch's real contribution (the three-dot diff) is much smaller than the full `HEAD..<branch>` delta — i.e. a direct merge/cherry-pick would also pull in `master` catch-up — land just the branch's own diff:
       1. Produce a correctly-resolved snapshot of just those files. Easiest: do a throwaway `git merge --no-ff <original-branch>`, resolve conflicts (for files unrelated to your feature take the deploy branch's side with `git checkout --ours`; for your feature's files do a real 3-way resolution combining the deploy branch's work with yours), commit it, and note its SHA.
       2. `git reset --hard origin/<target-branch>` to discard the merge and return to a clean deploy branch.
       3. `git checkout <merge-sha> -- <each file from the three-dot diff>` to stage exactly your feature's files at their resolved content. Verify with `git status --short` that **only** those files are staged.
       4. Commit as one squash commit, then push.
     - **Cherry-pick.** When the branch sits directly on (a recent) `master` with no merge commits and few commits, and `HEAD..<branch>` contains only the branch's own commits: `git cherry-pick <commit1> <commit2> ...` in chronological order.
     - **Merge (`git merge --no-ff <original-branch>`).** Only when you actually intend to bring the branch's full history (including any `master` it carries) onto the deploy branch — rare for a feature dev-test.
   - Verify before checking the feature's intended changes (the three-dot file set) are all present on the result; confirm no unrelated files are being pushed.
   - If conflicts occur, attempt to resolve them yourself. Preserve the deploy branch's existing work AND land your feature's intended changes.
     - Stop and notify the user only when a conflict is genuinely ambiguous — i.e. you cannot confidently determine the correct resolution (e.g. both sides made meaningful, conflicting logic changes to the same code). Explain the specific conflict and wait for direction.
     - Also stop and confirm with the user before pushing if the diff being landed (`git diff --stat origin/<target-branch> HEAD`) is far larger than the branch's three-dot contribution — that signals unintended `master` catch-up reaching a shared branch.
   - **Incidental lint failures from divergence.** The pre-commit hook (lint-staged) may fail on your feature's files because the deploy branch lacks a `master`-only dependency the branch added (e.g. a devDependency added in a separate `master` commit not on dev), or because the deploy branch's Biome version/config differs from `master`. When the failures are clearly from this divergence (not a defect you introduced), commit with `--no-verify`. The proper lint gate runs when the branch merges to `master`.
6. Push the target branch to remote to trigger the deploy pipeline.
7. Check out the original branch and restore the stash with `git stash pop`.
8. After restoring the stash, inspect `git status` and tell the user if files were restored as staged changes.
9. Watch the triggered deploy pipeline(s) in the background instead of blocking on `gh run watch`.
   - Only the pipeline(s) for the areas you changed will run. A frontend-only change (e.g. `frontends/web/...`, `books-islands`) triggers only `Books frontend Deploy Pipeline for ecs & eks`; a backends change triggers `Books backends Deploy Pipeline for ecs & eks`. Don't wait on a pipeline that won't run — match the watched workflows to your changed paths.
   - Find your commit's runs with `gh run list --branch <target-branch> --limit 6 --json workflowName,status,conclusion,databaseId,displayTitle` (match by your squash commit's `displayTitle`).
   - For each relevant run, start one `Monitor` call (one per run id if more than one pipeline triggered) with a command that polls and exits on completion, e.g.:
     ```sh
     prev=""
     while true; do
       s=$(gh run view <run-id> --json status,conclusion,url,displayTitle)
       cur=$(echo "$s" | jq -r .status)
       [ "$cur" != "$prev" ] && echo "status=$cur"
       prev=$cur
       [ "$cur" = "completed" ] && { echo "$s" | jq -r '"conclusion=\(.conclusion) url=\(.url) title=\(.displayTitle)"'; break; }
       sleep 20
     done
     ```
     Give it a `description` naming the workflow (e.g. "backends deploy pipeline run"), and a `timeout_ms` generous enough for a deploy pipeline (e.g. 1800000 = 30 min, up to the 3600000 max). This lets you keep working or hand control back to the user instead of sitting idle on a blocking watch.
   - If the `Monitor` tool is not available (e.g. not present in the current tool list), fall back to `gh run watch <run-id> --exit-status` per run instead — don't block the whole flow on trying to make `Monitor` work.
   - When a monitor's completion line arrives, report the conclusion and run URL to the user, and send one `PushNotification` per finished pipeline summarizing pass/fail (deploy pipelines run long enough that the user may have stepped away) — e.g. `"deploy/dev backends pipeline: success"` or `"deploy/dev frontend pipeline: FAILED — see run URL"`. Skip `PushNotification` too if it isn't available; just report results in chat as each `gh run watch` returns.

## Notes

- For this repository, the deploy workflows observed in practice were `Books backends Deploy Pipeline for ecs & eks` and `Books frontend Deploy Pipeline for ecs & eks`. Only the workflow(s) matching your changed paths actually run.
- `git stash pop` can restore the previous index state, so unrelated files may come back as staged. Always mention that explicitly in the final report. (If step 2 reported "No local changes to save", there is no stash to pop — leave any pre-existing unrelated stash entries alone.)
- Include the target branch, the strategy used (squash-only / cherry-pick / merge), the branch's three-dot contribution, the pushed commit range, and the triggered workflow result(s) and run URL(s) in the final report.
- The target branches are shared. When resolving conflicts, never drop other people's work that is already on `deploy/dev` / `deploy/stage` — resolve so both their changes and the original branch's intended changes survive. And never push unintended `master` catch-up onto them (see step 5: prefer squash-only).

IMPORTANT NOTE:

- If any of the steps fail, notify the user, explain the situation in detail and wait for explicit direction.
- For conflicts, attempt resolution yourself (see step 5). Only stop and ask the user when the correct resolution is genuinely ambiguous — then explain the specific conflict and wait for explicit direction.
