# Ultimate Review Eval Notes

## Baseline

- Natural baseline behavior already mentions multiple reviewers, evidence, and validation when the prompt explicitly asks for those checks.
- Earlier unguided baseline runs were weaker on repeatability: reviewer count, fixed lanes, severity rules, deduplication, rejected-candidate handling, and stopping conditions were underspecified.

## With Skill

- All three eval prompts produced the required orchestration:
  - independent reviewer dispatch before synthesis
  - no partial-result anchoring
  - evidence and confidence schema
  - validation before final findings
  - confirmed vs needs-verification separation
  - test and residual-risk reporting
- Eval 2 correctly expanded to 6-7 lanes for a cross-system diff.
- Eval 3 correctly included rejected-candidate handling for hallucination control.

## Follow-up

- Future evals should use less leading prompts so the skill, not the eval wording, supplies the discipline.
