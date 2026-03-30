---
name: deploy-ridi
description: Deploy current branch to either dev/stage environment by merging into deploy/dev or deploy/stage and pushing. Triggers the "Books backends Deploy Pipeline for ecs & eks" and "Books frontend Deploy Pipeline for ecs & eks" GitHub Actions workflows. Only trigger when explicitly requested — e.g. "deploy dev", "deploy to stage", "dev deploy", "/deploy-ridi for stage". Do NOT trigger automatically or proactively. This skill is specific to the ridi/ridi repository.
---

# Deploy Ridi

Deploy the current branch to either dev/stage by merging it into `deploy/dev` or `deploy/stage` and pushing that branch.

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
5. Merge the original branch into the target branch.
   - If target is `deploy/dev`, merge into `deploy/dev`.
   - If target is `deploy/stage`, merge into `deploy/stage`.
   - If merge conflicts occur, do not resolve them automatically. Notify the user and wait.
6. Push the target branch to remote to trigger the deploy pipeline.
7. Check out the original branch and restore the stash with `git stash pop`.
8. After restoring the stash, inspect `git status` and tell the user if files were restored as staged changes.
9. Monitor both deploy pipelines with `gh` until they succeed, fail, or time out.
   - Check both workflows:
     - `Books backends Deploy Pipeline for ecs & eks`
     - `Books frontend Deploy Pipeline for ecs & eks`
   - Use `gh workflow list --limit 30 | head -40` to confirm the workflow names.
   - For each workflow, use `gh run list --workflow "<workflow-name>" --branch <target-branch> --limit 5` to find the latest run.
   - For each workflow, use `gh run view <run-id> --json conclusion,status,url,displayTitle` to capture the result and share the run URL with the user.
   - For each workflow, use `gh run watch <run-id> --exit-status` to block until completion.

## Notes

- For this repository, the deploy workflows observed in practice were `Books backends Deploy Pipeline for ecs & eks` and `Books frontend Deploy Pipeline for ecs & eks`.
- `git stash pop` can restore the previous index state, so unrelated files may come back as staged. Always mention that explicitly in the final report.
- Include the target branch, pushed commit range if available, both workflow results, and both run URLs in the final report.

IMPORTANT NOTE:

- If any of the steps fail, notify the user, explain the situation in detail and wait for explicit direction.
- If merge conflicts happen during the merge step, DO NOT try to resolve them automatically. Notify the user and wait for explicit direction.