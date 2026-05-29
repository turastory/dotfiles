---
name: ultimate-review
description: Use when reviewing a PR, branch, diff, or code change where the user wants rigorous bug finding, multiple agents or models, multiple review perspectives, hallucination reduction, or a high-confidence final review report.
---

# Ultimate Review

## Core Principle

Independent reviewers find candidate bugs. The lead reviewer validates them. Do not let the first result steer the whole review.

Use this skill for general code review across domains. Adapt reviewer lenses to the diff, but keep the orchestration discipline the same.

## Hard Rules

- Launch independent reviewers before doing deep original bug research yourself.
- Do not show reviewer outputs to other reviewers.
- Do not synthesize until all planned reviewers have returned or explicitly failed.
- Do not treat consensus as proof. Validate each finding against code, tests, docs, or runtime evidence.
- Do not report low-confidence speculation as a finding. Put it under "Needs Verification" or reject it.
- Prefer fewer confirmed findings over a long list of plausible guesses.

## Workflow

1. Define scope.
   - Identify base/head, changed files, PR intent, user constraints, and available test commands.
   - Gather enough diff context to brief reviewers. Avoid forming a detailed bug thesis before dispatch.

2. Choose reviewer lanes.
   - Small diff: use 3 reviewers minimum.
   - Medium or risky diff: use 5 reviewers.
   - Large, security-sensitive, data-sensitive, or cross-system diff: use 6-7 reviewers.
   - If model selection is available and the user allows it, diversify model families. If not, diversify prompts and roles.

3. Dispatch reviewers in parallel.
   - Give each reviewer the same scope and diff source.
   - Give each reviewer one primary lens and permission to note obvious cross-lens issues.
   - Require structured findings with evidence and confidence.

4. Freeze until reviewer results arrive.
   - While waiting, you may prepare the report skeleton or run neutral commands that collect scope only.
   - Do not investigate candidate bugs from a partial result until all planned reviewers have returned.

5. Validate findings.
   - Read the relevant code for every candidate.
   - Reproduce mentally or with targeted tests when practical.
   - Merge duplicates by root cause, not by file.
   - Downgrade or reject findings that depend on assumptions not supported by the code.

6. Produce the final review.
   - Findings first, sorted by severity.
   - Include only validated issues in the main findings.
   - Include rejected or uncertain items only if useful for reviewer trust.
   - End with tests run, residual risk, and suggested next pass if needed.

## Reviewer Lanes

Pick lanes that match the diff. Default lanes:

| Lane | Focus |
| --- | --- |
| Correctness & Regression | Broken behavior, edge cases, state transitions, compatibility |
| Security & Trust Boundary | Injection, authz/authn, XSS, secrets, unsafe external or LLM output |
| Data & Persistence | Schema changes, migrations, indexes, transactions, data loss, backfill safety |
| Concurrency & Performance | Races, ordering, locks, N+1, pagination, memory, expensive loops |
| Tests & Observability | Missing tests, weak assertions, logs, metrics, debuggability |
| API, UI & Contracts | Public contracts, accessibility, backwards compatibility, client/server mismatch |
| Maintainability | Dead code, unclear ownership, misleading names, unnecessary abstractions |

## Reviewer Prompt Template

Use this shape for each reviewer:

```text
You are an independent reviewer for this change. Do not assume other reviewers' conclusions.

Scope:
- Base/head or PR URL:
- User intent:
- Changed areas:
- Known constraints:

Primary lens:
- <lane name and focus>

Review rules:
- Prioritize real bugs, regressions, security/data risks, and missing tests.
- For every finding include: severity, confidence 1-10, exact code reference, evidence, impact, and suggested fix.
- If evidence is weak, label it "needs verification" instead of a finding.
- Do not comment on style unless it can cause a bug or serious maintenance risk.

Return:
1. Confirmed findings
2. Needs verification
3. Tests or commands that would increase confidence
4. One-sentence overall risk assessment
```

## Finding Schema

Normalize every candidate into this shape before synthesis:

```text
id:
source_reviewers:
severity: P0 | P1 | P2 | P3
confidence: 1-10
category:
path:
evidence:
impact:
suggested_fix:
validation_status: confirmed | needs-verification | rejected
validation_notes:
```

Severity guide:

- `P0`: exploitable security issue, data loss/corruption, outage, or irreversible production damage.
- `P1`: likely user-facing regression, broken critical path, unsafe migration/backfill, or serious security weakness.
- `P2`: real bug or test gap with bounded impact.
- `P3`: low-risk maintainability issue that can reasonably wait.

Confidence guide:

- `9-10`: Verified directly in code or by a focused command.
- `7-8`: Strong evidence and concrete failure path.
- `5-6`: Plausible but missing one key fact. Keep out of main findings unless impact is high.
- `1-4`: Speculation. Reject or list only under "Needs Verification."

## Validation Rules

- Validate with code, not reviewer confidence.
- A finding reported by multiple reviewers still needs independent validation.
- A finding from one reviewer can be critical if the evidence is strong.
- If a candidate requires domain assumptions, look for existing patterns, docs, tests, or adjacent code.
- If validation would require production data, mark the assumption and propose the smallest safe check.
- If the issue predates the diff, report it only when the diff exposes, worsens, or depends on it.

## Final Report Format

Use this structure:

```markdown
## Findings
- [P1] `path` — concise issue title
  Evidence: ...
  Impact: ...
  Fix: ...
  Confidence: 8/10

## Needs Verification
- `path` — what is uncertain and how to verify it

## Rejected Candidates
- Briefly list important false positives only when they prevent re-litigation.

## Tests
- Commands run and outcomes
- Commands not run and why

## Overall Risk
One short paragraph with merge recommendation or next review pass.
```

If there are no validated findings, say so clearly and still report test gaps or residual risk.

## Common Mistakes

| Mistake | Correction |
| --- | --- |
| Starting your own deep review before dispatch | Dispatch first, validate later |
| Letting reviewers see each other's outputs | Keep reviews independent |
| Voting on findings | Validate evidence and failure path |
| Reporting every plausible edge case | Main findings require proof or strong evidence |
| Hiding uncertainty | Use "Needs Verification" explicitly |
| Overfitting lanes to one stack | Keep lanes general and adapt to the diff |

## Completion Criteria

Stop only when:

- All planned reviewer outputs were received or explicitly marked unavailable.
- Every candidate finding is confirmed, rejected, or moved to Needs Verification.
- The final report separates validated issues from uncertainty.
- The report states what was and was not tested.
