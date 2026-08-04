# trousse

## Status

**Robustness:** Stable — used daily
**Works with:** Claude Code (plugin or manual install)
**Requires:** Claude Code CLI 2.0+

A skill drawer for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — slash commands that teach Claude specialized workflows.

## What This Does

Trousse provides skills as SKILL.md files. Each one is a structured instruction set Claude reads and follows when you invoke the slash command.

Session lifecycle (startup briefings, handoffs, tactical tracking) is handled by [bon](https://github.com/spm1001/bon), not trousse. Trousse is purely skills.

## Quick Start

### Via plugin (recommended)

```
claude plugin marketplace add spm1001/batterie
/plugin install trousse@batterie
```

### Via manual clone

```bash
git clone https://github.com/spm1001/trousse ~/repos/spm1001/trousse
```

The plugin system discovers skills from `skills/*/SKILL.md` automatically.

## Skills

<!-- GENERATED:SKILLS:START -->
6 skills, tabled from `skills/*/SKILL.md` frontmatter by [render-skills.py](https://github.com/spm1001/batterie-de-savoir/blob/main/scripts/render-skills.py) — regenerate from this repo's root with
`uv run --script ../batterie-de-savoir/scripts/render-skills.py .`

| Skill | What it does |
|-------|--------------|
| `/ardoise` | Spawns an isolated Claude with no CLAUDE.md, no skills, no hooks, no plugin context — only training weights and built-in skills |
| `/deglacer` | MANDATORY gate BEFORE running jq on any .jsonl under ~/.claude/ or reading past CC sessions |
| `/hublot` | Orchestrates a real interactive Claude Code session under tmux using a start/wait/read/stop cycle — answers its dialogs, polls its screen for patterns, tears it down cleanly |
| `/review` | Code review alias |
| `/skill-forge` | Orchestrates all skill development — required before writing or editing any SKILL.md file |
| `/titans` | Three-lens code review using parallel subagents: Epimetheus (hindsight — bugs, debt, fragility), Metis (craft — clarity, idiom, fit-for-purpose), Prometheus (foresight — vision, extensibility, future-Claude) |
<!-- GENERATED:SKILLS:END -->

## Directory Structure

```
trousse/
├── skills/                 # Skill definitions (skills/<name>/SKILL.md)
├── scripts/                # Utility scripts used by skills
├── hooks/                  # hooks.json + session-start.sh
├── tests/                  # pytest suite
└── CLAUDE.md               # Instructions Claude reads when working in this repo
```

## Updating

```bash
cd ~/repos/spm1001/trousse && git pull
# Plugin cache refreshes on next session start
```

## Uninstalling

Use `/plugin uninstall trousse` to remove the plugin.

## The Kitchen

Trousse is part of [Batterie de Savoir](https://spm1001.github.io/batterie-de-savoir/) — a suite of tools for AI-assisted knowledge work.
