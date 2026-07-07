---
name: qa
description: >-
  Execute QA against a prepared QA workspace. Finds the right QA directory (the one
  created by `qa-setup`) under ~/workspaces/project/, reads its spec.md and
  checklist.md, then works through the items by driving the app in a real browser,
  capturing screenshots, updating checklist.md statuses, and logging any defects to
  report.md. Use whenever the user says "run QA", "do the QA", "let's QA this",
  "QA 돌리자", "QA 진행", "checklist 채워줘", or asks to actually test the items in
  a QA workspace (as opposed to `qa-setup`, which only scaffolds it). Also use for
  resuming a partially-done QA pass.
---

# QA (execute)

Run through a QA checklist by actually exercising the app, then record results and
screenshots back into the workspace.

## Why this exists

`qa-setup` produces the plan; this skill produces the evidence. The value is a
tight loop: drive the real UI → observe → mark the item → screenshot the proof →
file any defect with AS-IS/TO-BE. Results must be grounded in what actually
happened in the browser, never assumed from reading code.

## 1. Locate the QA directory

Find the workspace, in this order:

1. **Branch match (preferred).** Get the current branch's last path segment
   (`git rev-parse --abbrev-ref HEAD`, take the part after the last `/`). Look for
   `~/workspaces/project/*/*<segment>*-qa/`. A clear single match wins.
2. **Most recently modified.** If no branch match, list `*-qa` dirs under
   `~/workspaces/project/*/` and pick the most recently modified.
3. **Ask.** If still ambiguous (several plausible matches), show the candidates and
   let the user choose.

Confirm the chosen path with the user before writing to it.

## 2. Read the plan and current state

Read `spec.md` (what each item means) and `checklist.md` (what's already done).
Only run items that are ⬜ unless the user asks to re-run specific IDs. Respect the
user's scope if they name an area or ID range (e.g. "just area 1").

## 3. Bring up the app under test

QA needs a running, logged-in app. Don't assume it's up.

- Start the target's dev servers if needed (see the `up` skill — e.g.
  `/up backoffice`).
- Ensure the browser session is authenticated (see `ridi-local-login-browser` for
  local RIDI preflight).
- Confirm the entry URL/page for the feature before starting.

## 4. Work through the items

Use the **playwright skill** to drive the browser. For each item:

1. Reproduce the scenario described in `spec.md` for that ID.
2. Observe the actual behavior against the item's expected result.
3. **Screenshot when it helps** — always for ❌/⏸, and for ✅ items whose result is
   visual or non-obvious. Save flat in the QA dir as `<id>-<slug>.png` (multiple:
   `-a`, `-b`), per the rules in `checklist.md`.
4. Update the item's row in `checklist.md`: set the status emoji
   (⬜→✅/❌/⏸/➖), add the screenshot link, and a short note.

Prefer verifying several related items in one browser flow rather than restarting
the app per item — it's faster and closer to real usage.

## 5. Log defects to report.md

When an item fails or you spot a problem, add an issue to `report.md` using its
template. Keep the **AS-IS → TO-BE** order (AS-IS = observed, TO-BE = spec-expected).
Set severity, link the related item IDs, and reference the screenshot. Cross-link:
the failing checklist row's note should point at the issue.

## 6. Keep the summary honest

Update the progress summary counts in `checklist.md` and the summary block in
`report.md` as you go. Report results faithfully — a blocked item is ⏸, not ✅;
if you couldn't test something, say so rather than guessing. When done, give the
user a short rollup: counts, and the list of issues found by severity.
