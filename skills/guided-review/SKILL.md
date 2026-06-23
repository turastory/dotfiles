---
name: guided-review
description: Helps review code changes by identifying the best review entrypoint, review direction, key change points, convention fit, reference files, unusual implementation notes, change scale, and small atomic commit ranges for uncommitted work. Use when the user invokes /guided-review, asks for review guidance, wants to know where to start reviewing, whether code follows codebase conventions, or wants to resolve understanding debt from recent changes.
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
   - Check `git diff --stat` (and `git diff --cached --stat` for staged-only) for changed areas.
   - Run `wc -l` or diff stat on changed paths to separate **implementation vs test** line counts.
   - If commits already exist on the branch, compare with the likely base branch to understand committed work too.

2. Produce **한눈에 보는 규모** (always include when summarizing a diff).
   - Table or bullets: 신규/수정 파일 수, `+lines / -lines` (from `git diff --stat`), implementation vs test split.
   - Call out the 1–2 largest files by line count (often `resolver.test.ts`).
   - Note staged vs unstaged vs untracked if the user is mid-commit.
   - For large features, add a **dependency layers** diagram (shared helpers → metadata path → user-progress path → thin union resolvers).

3. Produce a review entrypoint (**top-down**).
   - Start from the entry/orchestration layer the reviewer would actually call into — the resolver, route handler, page component, or public API — not from the leaf helpers.
   - Reason **downward**: open the entrypoint first to see the overall shape and branching, then follow each branch into its detailed helpers (`to*` modules, `parse*`/`build*` utils, queries) as questions arise.
   - Do NOT order the reading list bottom-up (util → consumer → resolver). Even though the code *depends* upward, a reviewer understands it faster by reading the top contract first and drilling into details on demand.
   - Name the first file or behavior the reviewer should open, explain why it is the right starting point, then list the next files in top-down order (entrypoint → branches → shared leaves).
   - Keep the dependency-layers diagram (built bottom-up) separate from the reading order (top-down); they intentionally go in opposite directions.

4. Describe the review direction.
   - State the user-facing or system-facing behavior that changed.
   - Identify the key invariants, contracts, data flow, or boundaries to verify.
   - Call out where tests, generated files, schema changes, or integration points should be checked.

5. Check codebase convention fit.
   - Look for nearby or analogous implementations in the same repository.
   - Compare naming, layering, dependency direction, state management, error handling, tests, and generated-code workflow when relevant.
   - Provide reference files the user can open to judge whether the new code matches the usual pattern.
   - Say when a pattern appears common, uncommon-but-justified, or suspicious.

6. Highlight unusual details.
   - Mention implementations that differ from the repository's usual patterns.
   - Distinguish intentional tradeoffs from possible review risks.
   - Keep this focused on details that would otherwise slow down reviewer understanding.

7. If changes are not committed yet, suggest **small atomic commit ranges**.
   - Prefer **one independent behavior per commit** (e.g. union `__resolveType` for a new field, then metadata resolver, then query layer)—not only “all backends” vs “all frontend”.
   - Each chunk should be reviewable alone: implementation + its tests together; avoid “implementation-only” commits that break CI.
   - Order commits by dependency (shared helpers → consumers → union/type glue).
   - Include suggested commit subjects (`feat: …`, concise, single line).
   - When the user asks to commit: run `pnpm lint:fix` in the relevant package (`backends`: `pnpm lint:fix src`) before commit; use `git commit --no-verify` only when the user explicitly requests fast commits without hooks.
   - Do not commit unless the user explicitly asks.

## Output Format

Use this structure:

```markdown
## 한눈에 보는 규모
| 구분 | 파일 수 | 대략 라인 |
|------|---------|-----------|
| 신규 | N | … |
| 수정 | N | +X / −Y (diff stat) |
| 구현 | … | … |
| 테스트 | … | … (often ~60–70% of diff) |

- **가장 큰 파일**: `path` (+N lines) — [why it dominates]
- **staged / unstaged / untracked**: [if relevant]

[Optional: dependency layers ASCII or bullet list for multi-layer features]

## 리뷰 진입점
**Top-down**: start from the entrypoint/orchestration layer, then drill into details.

[Start with `path/to/entry-resolver` because it shows the overall branching/contract first ...]

권장 순서 (top-down):
1. `path/to/entrypoint` — 전체 흐름·분기
2. `path/to/branch-module` — 각 분기의 상세 (`to*`, query)
3. `path/to/shared-helper` — 필요 시 마지막에 leaf util/parse

## 리뷰 방향
- [Behavior or contract to verify]
- [Important downstream or integration point]

## 특이하거나 주의할 점
- [Unusual implementation detail or tradeoff]

## 참고 레퍼런스
- `path/to/reference`: [What convention or comparable pattern it demonstrates]

## 커밋 범위 제안
Prefer **small atomic commits** (one independent behavior each). Example granularity:

1. `feat: resolve AutoRewardInfo when only pendingLinkedActionType is set` — `eventParticipationRewardInfo/resolver.ts` + test
2. `feat: add event participation objective helpers` — `resolvers/eventParticipation/parseMissionObjective.ts` …
3. …

For each item: **files**, **why it stands alone**, **suggested subject**.
```

Omit `커밋 범위 제안` when all relevant work is already committed or there are no meaningful chunks to suggest. Omit `참고 레퍼런스` only when no trustworthy analogous code can be found quickly; say that explicitly in the guidance.

## Large backend GQL features (checklist)

When reviewing stacked PRs like event participation PROGRESS/LIST, map layers explicitly. This table is a **layer map for completeness, not the reading order** — read top-down (union glue / query resolver entrypoint first, shared-domain leaves last):

| Layer | Typical paths | What to verify |
|-------|----------------|----------------|
| Union glue | `typeResolvers/<feature>/`, `*RewardInfo/` | `__resolveType` branches |
| User progress | `queryResolvers/<feature>Query/` | Activity counts, period filters, type-specific `to*` modules |
| Metadata | `typeResolvers/eventGroup/<feature>/` | Dataloader batch queries, derived fields from mission JSON |
| Shared domain | `resolvers/<feature>/parse*.ts`, `build*.ts` | Parsing, subscriber util reuse, caches |

Note duplicated queries (batch in metadata vs single in query resolver) as a convention tradeoff, not necessarily a bug.

## Guidelines

- Be concise and reviewer-oriented.
- Prefer concrete file paths and symbols over broad descriptions.
- Lead with what helps the user start reviewing immediately.
- Avoid restating the whole diff as a changelog.
- When assessing convention fit, cite reference files rather than relying on memory.
- If the diff is too broad to summarize safely, say what extra context should be gathered next.
