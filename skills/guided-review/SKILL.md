---
name: guided-review
description: Helps review code changes by identifying the best review entrypoint, review direction, key change points, convention fit, reference files, unusual implementation notes, and meaningful commit ranges for uncommitted work. Use when the user invokes /guided-review, asks for review guidance, wants to know where to start reviewing, whether code follows codebase conventions, or wants to resolve understanding debt from recent changes.
---

# Guided Review

## Purpose

Help the user review code changes more effectively and resolve understanding debt quickly.

Use this skill when:
- Some implementation work has just been completed.
- The user manually asks for review guidance.
- The user asks where to start reviewing, what matters most, or how to split uncommitted changes.

## Workflow

1. Inspect the current changes.
   - Check `git status` for untracked, staged, and unstaged files.
   - Check `git diff --stat` and targeted diffs for changed areas.
   - If commits already exist on the branch, compare with the likely base branch to understand committed work too.

2. Produce a review entrypoint.
   - Name the first file or behavior the reviewer should open.
   - Explain why it is the right starting point.
   - Point to the next files to inspect in order.

3. Describe the review direction.
   - State the user-facing or system-facing behavior that changed.
   - Identify the key invariants, contracts, data flow, or boundaries to verify.
   - Call out where tests, generated files, schema changes, or integration points should be checked.

4. Check codebase convention fit.
   - Look for nearby or analogous implementations in the same repository.
   - Compare naming, layering, dependency direction, state management, error handling, tests, and generated-code workflow when relevant.
   - Provide reference files the user can open to judge whether the new code matches the usual pattern.
   - Say when a pattern appears common, uncommon-but-justified, or suspicious.

5. Highlight unusual details.
   - Mention implementations that differ from the repository's usual patterns.
   - Distinguish intentional tradeoffs from possible review risks.
   - Keep this focused on details that would otherwise slow down reviewer understanding.

6. If changes are not committed yet, suggest commit ranges.
   - Group changed files into meaningful chunks.
   - Prefer reviewable slices by behavior or system boundary, not by file type alone.
   - Include suggested commit subjects only when useful.
   - Do not commit unless the user explicitly asks.

## Output Format

Use this structure:

```markdown
## 리뷰 진입점
[Start with `path/to/file` because ...]

## 리뷰 방향
- [Behavior or contract to verify]
- [Important downstream or integration point]

## 특이하거나 주의할 점
- [Unusual implementation detail or tradeoff]

## 참고 레퍼런스
- `path/to/reference`: [What convention or comparable pattern it demonstrates]

## 커밋 범위 제안
- `[chunk name]`: [files or areas], [why they belong together]
```

Omit `커밋 범위 제안` when all relevant work is already committed or there are no meaningful chunks to suggest. Omit `참고 레퍼런스` only when no trustworthy analogous code can be found quickly; say that explicitly in the guidance.

## Guidelines

- Be concise and reviewer-oriented.
- Prefer concrete file paths and symbols over broad descriptions.
- Lead with what helps the user start reviewing immediately.
- Avoid restating the whole diff as a changelog.
- When assessing convention fit, cite reference files rather than relying on memory.
- If the diff is too broad to summarize safely, say what extra context should be gathered next.
