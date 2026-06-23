---
name: design-compliance-review
description: >-
  Verify that an implemented UI component matches its design source of truth (a Figma
  node, a mockup, a screenshot, or a written design spec) and fix the discrepancies in
  code. Use this whenever the user asks to check whether the UI matches the design, do a
  "design QA" pass, audit visual/pixel compliance against Figma or a mockup, fix spacing/
  color/size/typography drift, or asks "does this look like the design?" — even if they
  don't say the word "Figma". Reach for it for both directions of the question: "is this
  correct?" (review only) and "make this match" (review + fix).
---

# Design Compliance Review

The goal is to make an implemented component match its design source of truth, and to do
it in a way that is **auditable** — every change traceable to a specific measured
difference, not a vibe. The most common failure is eyeballing a screenshot and "fixing"
things by feel; that misses exact token values and, worse, misses structural layout
differences entirely. The discipline below exists to prevent that.

## When to use

- "Does this component match the design?" / "verify against Figma" / "design QA"
- "Fix the spacing/colors/sizes to match the mockup"
- A PR or branch that implements a design and needs a compliance pass before review
- A reported visual difference between what's shipped and what was designed

If the user only wants a behavioral/functional check (does the feature work), that is a
different task — this skill is about *visual* compliance: size, color, spacing,
typography, and layout structure.

## Workflow

### 1. Locate both sides

- **The implementation.** Find the component's render file(s) and its style file(s). Read
  them fully. Note which styles are *local* to this component and which come from
  *shared* modules (a shared card, a design-system primitive, a theme). This distinction
  governs scope later.
- **The design source.** Get the exact reference: a Figma node id + file key, a mockup
  image, or a written spec. If the user gave a Figma URL, extract the node id and file
  key from it. If you only have a vague "the design," ask for the specific node/file.
- **Project conventions.** Find the project's theme/token file (named colors, spacing,
  typography scales) and the styling approach (CSS-in-JS, Tailwind, CSS modules, etc.).
  You will express fixes in *the project's own tokens*, not raw hex/px copied from the
  design tool. If a domain/style guideline skill exists for this codebase, consult it.

### 2. Extract authoritative specs from the design — not just a screenshot

A single screenshot tells you what looks roughly off but not the exact values, and it
hides layout structure. Pull structured data:

- **Structure first.** Get the node tree / metadata to understand the hierarchy and find
  the specific sub-node you care about (the assembled component, not a documentation
  frame). Names like "spec", "examples", or "states" are usually annotation, not the
  thing to copy.
- **Exact values.** Pull the design context / generated code for the target node — this
  gives precise px, font, weight, line-height, gaps, padding, radius, and the layout
  tree (how children are grouped, which element is flex-1, what's right-aligned).
- **Exact tokens.** Pull variable/token definitions for the node so colors and sizes come
  back as named tokens with hex values, not guessed hex.
- **Disambiguate states with targeted captures.** Some things don't appear in a spec dump
  — the color of a disabled vs. enabled state, an active vs. inactive icon, hover. Take a
  *high-resolution* screenshot of the specific element in each state and inspect it
  directly to confirm.

If the design source is Figma via MCP, see `references/figma-extraction.md` for the exact
tool order and gotchas. The principles above apply to any design tool.

### 3. Map design tokens to project tokens

For every color/size/spacing value from the design, find the matching named token in the
project's theme. Match by *value*, then prefer the *semantic* token name when one exists
(e.g. a "disabled background" token over a raw grey step that happens to share the hex) —
it keeps the code readable and theme-correct. If a design value has no token, flag it;
don't silently hardcode unless the codebase already does so locally.

The inverse comes up too: a value that already renders correctly but is hardcoded as raw
hex/px where a matching token exists. Converting it is a *consistency cleanup*, not a
visual fix — do it when you're already editing that style block and local convention
favors tokens, and label it as cleanup in the report so it isn't mistaken for a behavior
or appearance change.

### 4. Build a discrepancy table before editing

Write the comparison out explicitly, one row per element/property. This is the core
artifact — it makes the review reviewable and stops you from missing items.

```
| # | Element | Property | Current | Design |
|---|---------|----------|---------|--------|
| 1 | check icon | size | 24px | 20px |
| 2 | count text | color | grey400 | grey500 (#a5a5a5) |
| 3 | count text | placement | pushed right (flex:1 title) | grouped left, after title |
```

Separate two kinds of differences — they need different care:

- **Cosmetic**: size, color, weight, radius, spacing. Usually a one-line token swap.
- **Structural**: how the DOM/flex tree is grouped (which elements share a flex parent,
  what's `flex:1`, what's right-aligned, ellipsis ownership). These are the highest-impact
  and the easiest to miss from a screenshot. The design's layout tree (from step 2) is the
  authority here. Expect at least to check grouping, not just values.

A structural *difference* is only a discrepancy if it changes the rendered result. A
codebase legitimately reaches a design's layout by other mechanics — absolute positioning
plus a `calc()` where the design used flex `space-between`, grid where the design used
flow. When the output matches at the relevant widths and states, leave it; don't rewrite
working code to mirror the design tool's node structure. The defect is a wrong *result*,
not a different *mechanism*.

### 5. Respect scope boundaries

If a difference lives in a *shared* component (a shared card, a design-system primitive,
a token used across many surfaces), changing it to satisfy this one screen can regress
every other consumer. Default to: **fix what is local to the component under review;
report shared-component differences as findings and ask before changing them**, unless
you can confirm the change is correct for all consumers. Honor any explicitly out-of-scope
items the user named (e.g. "X is handled in another PR") — note them, don't touch them.

### 6. Apply fixes

Edit the local styles/markup to match the table. Use project tokens. For structural fixes,
restructure the markup (e.g. wrap title+count in a flex group) rather than hacking margins
to fake the spacing. Match the surrounding code's conventions (comment density, naming,
how other style blocks are written).

### 7. Verify

- Run the project's typecheck and lint on the changed files (find the package's scripts
  first; don't assume a command).
- Visually verify when feasible. Be aware the dev pipeline may serve stale/cached assets —
  if the running app doesn't reflect your change, confirm you're looking at fresh output
  (rebuild, cache-bust, or a component harness) before concluding either way.
- Don't claim compliance you didn't check. If you verified by spec-mapping rather than a
  live render, say so.

### 8. Report

Lead with the discrepancy table (now showing the fix applied), then state what was
deliberately left out of scope and why, and how you verified. Keep it tight — the table
carries the detail.

## Principles

- **Measure, don't guess.** Every fix maps to a value pulled from the design, not an
  impression from a screenshot.
- **Structure over surface.** A grouping/flex difference changes layout at every width; a
  2px color shift doesn't. Check structure first.
- **Tokens over hex.** Express fixes in the codebase's named tokens so they stay
  theme-correct and reviewable.
- **Scope honestly.** Shared code and explicitly-deferred items are reported, not silently
  changed.
- **Verify before claiming.** Typecheck + lint at minimum; flag when a live render couldn't
  be trusted.
