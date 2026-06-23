---
name: write-design-doc
description: Use when the user wants to draft, structure, polish, or review a design doc, technical design document, RFC, design proposal, "기술 설계 문서", RIDI-style Design Doc, or any pre-implementation write-up for a non-trivial system or feature. Also use when the user is unsure whether work warrants a design doc, needs to clarify trade-offs before implementation, or wants to turn rough feature context into a reviewable engineering proposal.
---

# Write a Design Doc

A design doc is a pre-implementation document that explains the implementation strategy, key decisions, and trade-offs. Its value is not the template; it is making risks and disagreements visible while change is still cheap.

Write in the team's working language. For this user, default to Korean unless told otherwise. Prefer the team's familiar headings over generic translations.

## Should this be a design doc?

Writing one is overhead. Lean toward a design doc when several of these are true:

- It's unclear what the right design is.
- Senior/cross-team input would meaningfully help.
- The approach is contentious enough that consensus matters.
- The team tends to overlook cross-cutting concerns (security, privacy, observability, migration).
- A high-level doc is needed because it touches a legacy system with no current docs.

If the solution is obvious, or the doc would only list classes/files to edit, tell the user that a design doc is not useful and proceed with the more appropriate artifact.

## Structure

Adapt to the project. For RIDI-style product/engineering docs, this compact shape usually works:

1. **배경** — Link PRD, Figma, issue, or investigation first. Summarize why the work exists without re-copying requirements.
2. **문제와 목표** — State current behavior, the concrete problem, the target metric or success condition, and the proposed direction.
3. **대상/범위 판정** — If multiple screens, clients, backends, data stores, or legacy paths are involved, add a small table showing what is in scope, who decides the behavior, and what was verified.
4. **목표와 비목표** — Goals should be actionable. Non-goals should name plausible adjacent work deliberately excluded; avoid obvious negatives.
5. **설계** — Start with the chosen approach. Add a diagram or flow when it clarifies behavior. Sketch APIs/data only at the level needed to judge the design; do not paste full schemas or definitions.
6. **핵심 결정** — Break the design into named decisions and show both benefits and costs.
7. **고려한 대안** — Include realistic alternatives and why their trade-offs lost to the chosen approach.
8. **함께 살펴볼 점** — Cover correctness, observability, rollout, migration, privacy/security, legacy validation, data/schema, and testing only where relevant.
9. **미해결 질문** — End with open decisions as checkboxes. Name the owner or next evidence when known.

For non-RIDI docs, translate the same intent into the team's headings: context/scope, goals/non-goals, design, alternatives, cross-cutting concerns, and open questions.

Large projects may need 10-20 pages. Incremental work should usually be a 1-3 page mini design doc. If it grows past what reviewers will read, split the problem.

## Decision writing

When a design has important choices, use explicit decision blocks. This is especially useful in RIDI docs because reviewers can quickly see both the benefit and the cost:

```markdown
**1. [Decision name]**
- 얻는 것 — [What this unlocks, simplifies, reduces, or protects.]
- 비용 — [What gets more complex, riskier, less flexible, or needs extra verification.]
```

If there is no real cost, it may not be a design decision. If the cost is serious, explain how the design contains it. Use "검증 완료" only when code, data, prototype, or manual checks confirmed the assumption; otherwise say "가정" or "미검증".

## Writing style

Keep the doc short enough for a busy reviewer and complete enough to judge the design.

- Be neutral in background and opinionated in alternatives.
- Prefer evidence: "I tried it and it works" is stronger than speculation.
- Keep implementation plans, PR breakdowns, and exact local paths in a separate plan unless a code boundary affects the design.
- Use Korean polite written tone such as "~합니다" for this user.
- Choose terms teammates understand fastest; do not force awkward translations.
- Keep bold, italic, inline code, quotes, and callouts sparse. Use emphasis only where it changes how the reviewer should read the sentence.
- Split dense paragraphs. Avoid parenthetical asides, abstract filler, and consecutive callout blocks.
- In rich-text docs, subtle green/red background highlights can mark "얻는 것" and "비용"; in Markdown, simple bullets are enough.

## Working with the user

Prefer drafting the user's actual doc over explaining the template. Ask only for facts you cannot infer: core problem, constraints, target metric, current behavior, and explicit non-goals.

When the user provides a PRD, Figma, issue, or Notion reference, read it first and extract:

- the product objective and measurable target;
- screens, clients, backends, data stores, and legacy paths involved;
- assumptions that need verification before the design is credible;
- adjacent work that looks tempting but should be a non-goal;
- alternatives that reviewers are likely to ask about.

When polishing an existing doc, preserve its section order and team voice where possible. Improve reasoning, scope boundaries, and decision trade-offs before changing formatting.

Mention lifecycle when relevant: draft with a few trusted colleagues, review broadly enough to catch cross-team risks, and update the doc when implementation reality diverges.
