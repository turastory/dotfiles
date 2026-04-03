# Sync Skills To Dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable skill that audits `~/.codex/skills` and `~/.claude/skills` against `~/dotfiles/skills`, asks before changing anything, migrates missing skills into dotfiles, removes duplicate external copies, verifies the final path with `readlink -f` and `realpath`, and checks `git status` in the dotfiles repo.

**Architecture:** Keep the implementation as a single skill document in `skills/sync-skills-to-dotfiles/SKILL.md`. The skill should define the canonical directories, the comparison rules, the user-confirmation gate, the migration and cleanup commands, and the final verification flow so future agents can execute the process consistently.

**Tech Stack:** Markdown, shell commands, git

---

### Task 1: Define The Skill Contract

**Files:**
- Create: `skills/sync-skills-to-dotfiles/SKILL.md`

- [ ] **Step 1: Draft the frontmatter**

```yaml
---
name: sync-skills-to-dotfiles
description: Use when the user wants to compare skills in ~/.codex/skills and ~/.claude/skills against ~/dotfiles/skills, migrate missing skills into dotfiles, remove duplicate external copies, and verify that ~/dotfiles/skills is the final canonical destination.
---
```

- [ ] **Step 2: Describe the canonical source of truth**

```markdown
# Sync Skills To Dotfiles

Treat `~/dotfiles/skills` as the source of truth.
```

- [ ] **Step 3: Define the safety rules**

```markdown
## Guardrails

- Never move or delete anything before the user explicitly approves the proposed actions.
- Compare skill directories by their directory name and the presence of `SKILL.md`.
- Stop if either `readlink -f` or `realpath` resolves a destination outside `~/dotfiles/skills`.
- Remove only duplicate copies outside dotfiles. Never remove the copy already under `~/dotfiles/skills`.
```

### Task 2: Encode The Audit And Migration Workflow

**Files:**
- Modify: `skills/sync-skills-to-dotfiles/SKILL.md`

- [ ] **Step 1: Add the audit step**

```markdown
## Audit

1. Collect skill directories from:
   - `~/.codex/skills`
   - `~/.claude/skills`
   - `~/dotfiles/skills`
2. Compare the source directories to `~/dotfiles/skills`.
3. Report:
   - new skills not present in dotfiles
   - duplicate skills already present in dotfiles
```

- [ ] **Step 2: Add the user confirmation step**

```markdown
## Confirmation

Ask the user whether to migrate the new skills into `~/dotfiles/skills` and remove duplicate external copies. Do not continue until the user answers.
```

- [ ] **Step 3: Add the action step**

```markdown
## Apply Changes

- Move each approved new skill directory into `~/dotfiles/skills/`.
- Remove each approved duplicate directory outside dotfiles.
- If the same new skill exists in both source directories, surface both paths and ask the user which copy to keep before deleting either one.
```

### Task 3: Add Verification Requirements

**Files:**
- Modify: `skills/sync-skills-to-dotfiles/SKILL.md`

- [ ] **Step 1: Add destination verification commands**

```markdown
## Verify Final Destination

Run both commands for every migrated skill:

- `readlink -f <path>`
- `realpath <path>`

Both results must resolve under `~/dotfiles/skills`.
```

- [ ] **Step 2: Add repository verification**

```markdown
## Verify Repository State

Run `git status` in `~/dotfiles` so the user can confirm the migrated skills appear in the repository as expected.
```

- [ ] **Step 3: Run a final review**

Run: `sed -n '1,260p' /Users/nayoonho/dotfiles/skills/sync-skills-to-dotfiles/SKILL.md`
Expected: The skill includes audit, confirmation, migration, destination verification, and `git status` verification steps with no placeholders.
