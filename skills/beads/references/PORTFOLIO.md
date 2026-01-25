# Cross-Project Portfolio View

See all beads across repos in a single view.

## Quick Start

```bash
# From any repo with beads, see cross-project view:
bd list --all-repos
```

This scans all repos with `.beads/` directories and shows:
- Desired Outcomes (epics) grouped by repo
- Ready work sorted by priority
- In-progress items

## How It Works

**Read-only aggregation.** The `bd list --all-repos` command:
1. Finds all `~/Repos/*/.beads/` directories
2. Queries each database
3. Displays aggregated results

**Never writes.** No sync, no database updates, no corruption risk.

## When to Use

- **Session start** — See what's ready across all projects
- **Weekly review** — Understand workload distribution
- **Context switching** — Decide where to focus next

## Output

```
Beads Portfolio — Cross-Repo View
2026-01-24 20:25 — Read-only aggregation

=== Portfolio: All Repos ===
ℹ Scanning 21 repos...

Desired Outcomes:

  [itv-slides-formatter]
    📦 itv-slides-formatter-9yi: Made ITV presentation formatting automatic
    ...

  [claude-go]
    📦 claude-go-tvd: Claude Go: Self-hosted Claude Code web client
    ...

=== Ready Work (Unblocked) ===

  • mise-2h2: Handle rowSpan in table parsing [P1]
  • claude-go-dt5: Systemd deployment [P1]
  ...

=== In Progress ===

  ⏳ mise-gtg: Factor Office file extraction into adapter

=== Summary ===

  Total issues: 290 across all repos
  Open: 286
  Desired Outcomes: 28 active epics
  In Progress: 4

  Repos scanned:
    itv-slides-formatter (54 issues)
    claude-go (80 issues)
    ...
```

## Working on a Specific Project

After seeing the portfolio, switch to the project:

```bash
cd ~/Repos/mise-en-space
bd ready           # What's unblocked
bd list --status in_progress  # What's active
bd show mise-xyz   # Details on specific bead
```

## Integration with Session Lifecycle

- **/open** — Portfolio informs where to focus
- **/close** — Portfolio shows session impact

## Customization

The script scans `~/Repos/`. To change:

```bash
# Edit the REPOS_DIR variable in:
~/.claude/scripts/beads-portfolio.sh
```
