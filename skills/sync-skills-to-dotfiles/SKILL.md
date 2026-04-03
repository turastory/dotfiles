---
name: sync-skills-to-dotfiles
description: Use when the user wants to compare skills in ~/.codex/skills and ~/.claude/skills and ~/.agents/skills against ~/dotfiles/skills, migrate missing skills into dotfiles, remove duplicate external copies, and verify that ~/dotfiles/skills is the final canonical destination.
---

# Sync Skills To Dotfiles

Treat `~/dotfiles/skills` as the source of truth for personal skills.

## Guardrails

- Never move or delete anything before the user explicitly approves the proposed actions.
- Compare skill directories by directory name and the presence of `SKILL.md`.
- Remove only duplicate copies outside `~/dotfiles/skills`. Never remove the copy already in dotfiles.
- Stop if either `readlink -f` or `realpath` resolves a final path outside `~/dotfiles/skills`.
- Run `git status` in `~/dotfiles` before finishing.

## Directories

- Codex skills: `~/.codex/skills`
- Claude skills: `~/.claude/skills`
- Agents skills: `~/.agents/skills`
- Canonical skills: `~/dotfiles/skills`

## Audit

1. Collect skill directories from `~/.codex/skills`, `~/.claude/skills`, `~/.agents/skills`, and `~/dotfiles/skills`.
2. Compare each source directory to `~/dotfiles/skills`.
3. Report two groups:
   - New skills: present in a source directory, missing from `~/dotfiles/skills`
   - Duplicate skills: present in both a source directory and `~/dotfiles/skills`

Use commands like these to gather the directories:

```bash
find ~/.codex/skills ~/.claude/skills ~/.agents/skills ~/dotfiles/skills -mindepth 1 -maxdepth 1 -type d
find ~/.codex/skills ~/.claude/skills ~/.agents/skills ~/dotfiles/skills -maxdepth 2 -name SKILL.md
```

## Confirmation

Show the user the new skills and duplicate skills. Ask whether to:

- migrate the new skills into `~/dotfiles/skills`
- remove duplicate copies outside `~/dotfiles/skills`

Do not continue until the user answers.

If the same new skill appears in both `~/.codex/skills` and `~/.claude/skills` and `~/.agents/skills`, show both source paths and ask which copy to keep before moving or deleting anything.

## Apply Changes

For each approved new skill:

```bash
mv <source-skill-dir> ~/dotfiles/skills/
```

For each approved duplicate skill outside dotfiles:

```bash
rm -rf <duplicate-source-skill-dir>
```

Never remove the copy already under `~/dotfiles/skills`.

## Verify Final Destination

For every migrated skill, run both commands:

```bash
readlink -f <skill-dir>
realpath <skill-dir>
```

Both results must resolve under `~/dotfiles/skills`. If any command resolves elsewhere, stop and report the mismatch.

## Verify Repository State

Run this command from the dotfiles repository:

```bash
git -C ~/dotfiles status
```

Use the output to confirm the migrated skills now appear in `~/dotfiles` as expected.
