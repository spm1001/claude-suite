# claude-suite — Project Context

Learnings from developing and maintaining the behavioral skills.

## Titans Review Process

The `/titans` (or `/review`) skill dispatches three parallel Opus reviewers with different lenses:

| Titan | Focus | Typical findings |
|-------|-------|------------------|
| **Epimetheus** | Hindsight — bugs, debt, fragility | Silent failures, missing error handling, race conditions |
| **Metis** | Craft — clarity, idiom, structure | Stale references, naming inconsistencies, magic numbers |
| **Prometheus** | Foresight — vision, extensibility | Undocumented contracts, missing version markers |

**When to use:** After substantial work, before shipping, periodic hygiene.

**Token cost:** Three Opus agents is not cheap. Worth it for substantial work; overkill for quick fixes.

**Self-review is valuable:** The titans skill reviewing itself found real issues (stale paths, PII in scanner config). Self-blindness is real.

## Context Encoding Scheme

**Critical infrastructure, underdocumented.**

The pattern `$(pwd -P | tr '/.' '-')` converts paths to directory-safe names for handoff routing:
- `/Users/modha/Repos/claude-suite` → `-Users-modha-Repos-claude-suite`
- Both `/` and `.` are replaced (`.` because hidden directories would create `.`-prefixed encoded names)

This encoding is used in:
- `~/.claude/.session-context/<encoded>/` — per-project context files
- `~/.claude/handoffs/<encoded>/` — per-project handoff archives

**If this encoding changes, handoffs become orphaned.** Any migration would need to move existing directories.

## Skill Verification

Run `./install.sh --verify` to check all skills are properly symlinked. The verification list must be kept in sync with actual skills in `skills/` directory.

## Script Error Handling

Scripts use `set -euo pipefail` for strict error handling:
- `-e`: Exit on any command failure
- `-u`: Error on unset variables
- `-o pipefail`: Pipe failures propagate

This is stricter than the previous `set -e`. Watch for breakage if scripts relied on unset variables being empty.
