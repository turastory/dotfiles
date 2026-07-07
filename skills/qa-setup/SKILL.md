---
name: qa-setup
description: >-
  Turn a spec into a ready-to-run QA workspace. Given a source of truth for what
  changed — an Asana task link, a Slack thread, pasted text, or the current local
  git branch diff — this creates a dated QA directory under ~/workspaces/project/
  containing spec.md (uniquely numbered QA items), checklist.md (progress tracker
  with screenshot slots), and report.md (results + issue log). Use this whenever
  the user says "ready to qa", "setup qa", "QA 셋업", "QA 준비", "I want to QA
  this", "이거 QA 항목 만들자", or otherwise wants to prepare structured QA items
  before actually testing. It only scaffolds the workspace; the separate `qa`
  skill runs the tests and fills it in.
---

# QA Setup

Prepare a structured QA workspace from a spec. The output is three markdown files
in a dated directory that the `qa` skill later executes against.

## Why this exists

Good QA items are grounded in **both** the intended behavior (what the spec/PM
discussion decided) **and** the actual implementation (what the code really does).
A checklist written only from a Slack thread misses regressions the code
introduced; one written only from the diff misses the product intent. This skill's
job is to reconcile the two into concrete, uniquely-addressable test items.

## Workflow

### 1. Resolve the spec source

Figure out which kind of source the user gave and gather it:

- **Asana link** — fetch the task (and relevant subtasks/comments) via the Asana
  MCP tools. Pull the decided behavior, not just the title.
- **Slack thread** — read the whole thread via the Slack MCP tools. Capture the
  final decisions, including reversals later in the thread (early "let me think"
  is often superseded).
- **Pasted text** — use it as the intent directly.
- **Local branch diff** — `git diff <base>...HEAD` (base is usually `master`).
  Read the changed files, not just the diff stat, so items reflect real logic.

Whenever a source exists, also **read the actual implementation**. If the source is
a discussion, find the branch/PR that implements it and read the changed code so
items match what ships. Note in `report.md`'s open-questions any decision from the
discussion that isn't reflected in the diff (it may live in another branch).

### 2. Derive QA items grouped into areas

Group items into a small number of **areas** (feature themes), then list concrete,
checkable items under each. Each item must be:

- **Objectively checkable** — a tester can mark pass/fail without debate.
- **Uniquely numbered** as `<area>-<n>` (e.g. `1-1`, `1-12`, `2-5`). Numbering is
  sequential within an area; the same ID is used across all three files so a
  screenshot, a checklist row, and a report issue all point to the same thing.

Cover happy paths, edge cases the discussion raised, count/limit boundaries, and
**regression** of the pre-existing flow the change touched (a common miss).

### 3. Choose the workspace directory

Target: `~/workspaces/project/<project>/<YYYY-MM-DD>-<slug>-qa/`

- `<project>` — reuse an existing folder under `~/workspaces/project/` if one fits
  (e.g. `event-participation`); otherwise create a sensibly named one.
- `<YYYY-MM-DD>` — today (from the environment's current date).
- `<slug>` — short kebab-case feature name, ideally matching the git branch's last
  path segment so the `qa` skill can find it by branch name later.

### 4. Generate the three files

Copy the templates in `assets/` and fill them in:

- **spec.md** — the numbered item definitions (from step 2). This is the source of
  truth for *what* to test.
- **checklist.md** — one tracker row per item ID, mirroring spec.md, with status +
  screenshot + note columns. This is *what got tested and its result*.
- **report.md** — summary, an issue template, and an open-questions list.

Keep the fixed boilerplate from the templates (status legend, screenshot naming
rules, issue template with **AS-IS → TO-BE** order). Only replace the marked
placeholders and the item lists/rows.

### 5. Confirm

Tell the user the directory path and the item count per area, and point out any
open questions (e.g. decisions not found in the diff). Offer to run the `qa` skill
next.

## Templates

- `assets/spec.md` — item-definition scaffold
- `assets/checklist.md` — progress tracker scaffold (holds the screenshot rules)
- `assets/report.md` — results + issue-log scaffold

Placeholders use `{{DOUBLE_BRACES}}`. Replace every one; delete the example rows
once real items are in.
