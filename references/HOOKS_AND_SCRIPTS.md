# Hooks and Scripts Architecture

A complete map of what fires when, who owns it, and how it's wired.

Last audited: 2026-02-07

---

## Quick Reference: What Fires When

### SessionStart

```
settings.json SessionStart (matcher: "startup")
  |
  +--> sync-config.sh pull           [guard: yes] [owner: claude-config]
  |      git pull ~/.claude, update submodules
  |
  +--> session-start.sh              [guard: yes] [owner: claude-suite]
         |
         +--> quick_health_check()    check symlinks + extraction failures
         +--> sync-skill-permissions.sh   report missing Skill() permissions
         +--> open-context.sh         handoffs, git, arc, beads, news -> stdout
         +--> check .close-checkpoint incomplete /close warning
         +--> update-all.sh           background (nohup &)
               |
               +-- QUICK (always): check-symlinks, submodules, bd doctor
               +-- HEAVY (daily): brew, npm, claude update, MCP deps
```

### UserPromptSubmit

```
settings.json UserPromptSubmit (matcher: "")
  |
  +--> arc-tactical.sh               [guard: yes] [owner: claude-config]
         inject current arc step into every prompt
```

### PostToolUse

```
settings.json PostToolUse
  |
  +--> [WebFetch matcher] inline     warns: AI summary, not raw content
  +--> [Bash matcher] inline         warns: detached HEAD detected
```

### SessionEnd

```
settings.json SessionEnd (matcher: "")
  |
  +--> session-end.sh                [guard: yes] [owner: claude-suite]
  |      |
  |      +--> daemonized background:
  |             mem process (index session transcript)
  |             mem scan (handoffs + beads)
  |             mem backfill --limit 10 (Meeting Notes)
  |
  +--> sync-config.sh push           [guard: yes] [owner: claude-config]
         git add/commit/push ~/.claude
```

---

## Ownership Map

Two repos provide hooks and scripts. The split is historical, not architectural.

### claude-suite (this repo)

Symlinked by `install.sh` to `~/.claude/`.

| File | Type | Symlinked to |
|------|------|-------------|
| `hooks/session-start.sh` | Hook | `~/.claude/hooks/session-start.sh` |
| `hooks/session-end.sh` | Hook | `~/.claude/hooks/session-end.sh` |
| `scripts/open-context.sh` | Script | `~/.claude/scripts/open-context.sh` |
| `scripts/close-context.sh` | Script | `~/.claude/scripts/close-context.sh` |
| `scripts/check-home.sh` | Script | `~/.claude/scripts/check-home.sh` |
| `scripts/check-symlinks.sh` | Script | `~/.claude/scripts/check-symlinks.sh` |
| `scripts/claude-doctor.sh` | Script | `~/.claude/scripts/claude-doctor.sh` |

### claude-config (~/.claude, standalone)

Not symlinked — these live directly in `~/.claude/`.

| File | Type | Location |
|------|------|----------|
| `hooks/arc-tactical.sh` | Hook | `~/.claude/hooks/arc-tactical.sh` |
| `scripts/sync-config.sh` | Script | `~/.claude/scripts/sync-config.sh` |
| `scripts/sync-skill-permissions.sh` | Script | `~/.claude/scripts/sync-skill-permissions.sh` |
| `scripts/update-all.sh` | Script | `~/.claude/scripts/update-all.sh` |
| `scripts/rescue-handoffs.sh` | Script | `~/.claude/scripts/rescue-handoffs.sh` |
| `scripts/bd-wrapper.sh` | Script | `~/.claude/scripts/bd-wrapper.sh` |
| `scripts/todoist-mcp.sh` | Script | `~/.claude/scripts/todoist-mcp.sh` |
| `scripts/todoist` | Script | `~/.claude/scripts/todoist` |
| `scripts/chrome-log` | Script | `~/.claude/scripts/chrome-log` |
| `scripts/bootstrap.sh` | Script | `~/.claude/scripts/bootstrap.sh` |
| `scripts/setup-machine.sh` | Script | `~/.claude/scripts/setup-machine.sh` |
| `scripts/setup-new-machine.sh` | Script | `~/.claude/scripts/setup-new-machine.sh` |
| `scripts/setup-symlinks.sh` | Script | `~/.claude/scripts/setup-symlinks.sh` |
| `scripts/claude-go-permission.sh` | Script | `~/.claude/scripts/claude-go-permission.sh` |
| `scripts/transcribe-jpr.sh` | Script | `~/.claude/scripts/transcribe-jpr.sh` |
| `scripts/web-init.sh` | Script | `~/.claude/scripts/web-init.sh` |
| `scripts/web-init-inline.sh` | Script | `~/.claude/scripts/web-init-inline.sh` |

### install.sh Registration Gap

`install.sh` only registers SessionStart in settings.json. These must be added manually:

| Event | Hook | Why not auto-registered |
|-------|------|------------------------|
| SessionEnd | session-end.sh | Added later, install.sh not updated |
| UserPromptSubmit | arc-tactical.sh | Lives in claude-config, not claude-suite |
| PostToolUse (WebFetch) | Inline | Inline command, no script to register |
| PostToolUse (Bash) | Inline | Inline command, no script to register |

---

## The Guard Pattern

### Why Guards Exist

The fork bomb incident (commit `bd19f03`): `mem backfill` spawns `claude -p` subagents. Each triggered SessionStart/SessionEnd hooks, which spawned more mem operations, recursively. Load average hit 287 with 400+ processes on a 10-core M4.

### The Standard Guard

All four scripts triggered directly by settings.json hooks use this identical pattern:

```bash
# Layer 1: Fast path — explicit env var from known subagent spawners
[ -n "${MEM_SUBAGENT:-}" ] && exit 0

# Layer 2: Slow path — walk process tree looking for claude -p
_pid=$$
for _ in 1 2 3 4 5; do
    _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
    [ -z "$_pid" ] || [ "$_pid" = "1" ] && break
    _cmd=$(ps -o args= -p "$_pid" 2>/dev/null || true)
    if [[ "$_cmd" == *"claude"* ]]; then
        [[ "$_cmd" == *" -p "* || "$_cmd" == *"--no-session-persistence"* ]] && exit 0
        break  # found interactive claude, continue with hook
    fi
done
```

**Layer 1** is fast (env var check). Known spawners like claude-mem set `MEM_SUBAGENT=1`.

**Layer 2** walks up to 5 levels of parent processes looking for `claude` with `-p` or `--no-session-persistence` flags. Catches subagents from unknown spawners.

### Guard Coverage

| Script | Triggered by | Has guard? | Notes |
|--------|-------------|------------|-------|
| `session-start.sh` | settings.json SessionStart | Yes | Direct hook |
| `session-end.sh` | settings.json SessionEnd | Yes | Direct hook |
| `arc-tactical.sh` | settings.json UserPromptSubmit | Yes | Direct hook |
| `sync-config.sh` | settings.json SessionStart + SessionEnd | Yes | Direct hook |
| `open-context.sh` | session-start.sh | No — inherited | Called by guarded parent |
| `close-context.sh` | /close skill | No — not a hook | Invoked deliberately |
| `check-symlinks.sh` | session-start.sh, update-all.sh | No — inherited | Called by guarded parent |
| `sync-skill-permissions.sh` | session-start.sh | No — inherited | Called by guarded parent |
| `update-all.sh` | session-start.sh (background) | No — inherited | Called by guarded parent |
| `check-home.sh` | /close skill | No — not a hook | Invoked deliberately |
| `claude-doctor.sh` | Manual | No — not a hook | Human runs this |

### Aboyeur Implications

Aboyeur's worker and reflector Claudes are interactive sessions (not `-p`). The guard will **not** suppress hooks for them — which is correct. Workers need SessionStart context, and SessionEnd indexing should capture their work.

However: if aboyeur ever moves to `claude -p` for workers, the guards would suppress hooks, and workers would lose their session context. This is a known coupling.

---

## Script Details

### Session Lifecycle

| Script | Called by | Purpose |
|--------|----------|---------|
| `open-context.sh` | session-start.sh | Computes per-project context: handoff index, git status, arc hierarchy. Writes to `~/.claude/.session-context/<encoded-cwd>/` |
| `close-context.sh` | /close skill | Gathers close-time context: git state, arc state, location check. Structured `=== SECTION ===` output |
| `check-home.sh` | /close skill | Detects CWD drift from session start |

### Health and Diagnostics

| Script | Called by | Purpose |
|--------|----------|---------|
| `check-symlinks.sh` | session-start.sh, update-all.sh | Verifies critical symlinks intact |
| `claude-doctor.sh` | Manual | Comprehensive health check: symlinks, tools, config, skills, memory, MCP |
| `sync-skill-permissions.sh` | session-start.sh | Reports skills missing `Skill()` entries in settings.json |

### Infrastructure

| Script | Called by | Purpose |
|--------|----------|---------|
| `sync-config.sh` | settings.json (pull at start, push at end) | Git sync for `~/.claude` repo |
| `update-all.sh` | session-start.sh (background) | Two-tier updater: quick (always) + heavy (daily) |

### Skill-specific Scripts

| Script | Skill | Purpose |
|--------|-------|---------|
| `skills/picture/imagen.sh` | picture | Google Imagen image generation |
| `skills/sprite/test-outer-inner.sh` | sprite | OuterClaude/InnerClaude test validation |

---

## Context Encoding

The path encoding convention used for per-project directories:

```bash
encoded=$(pwd -P | tr '/.' '-')
# /Users/modha/Repos/claude-suite -> -Users-modha-Repos-claude-suite
```

Used in:
- `~/.claude/.session-context/<encoded>/` — per-project context cache (regeneratable)
- `~/.claude/handoffs/<encoded>/` — per-project handoff archive (permanent)

**Canonical implementations:** `open-context.sh:11` and `close-context.sh:133`

**Contract:** Aboyeur depends on this encoding. Changing it orphans handoffs in both systems.

---

## Inline Hooks (settings.json)

Two PostToolUse hooks are defined inline, not as scripts:

### WebFetch Warning

```json
{ "matcher": "WebFetch",
  "hooks": [{ "type": "command",
    "command": "echo '{\"hookSpecificOutput\": ...WebFetch returns AI summaries...}'" }] }
```

Reminds Claude that WebFetch returns summarised content, not raw pages. Directs to `curl -s` instead.

### Detached HEAD Warning

```json
{ "matcher": "Bash",
  "hooks": [{ "type": "command",
    "command": "if git rev-parse --git-dir > /dev/null 2>&1; then git symbolic-ref HEAD ... fi" }] }
```

After every Bash command, checks if HEAD is detached inside a git repo. If so, warns Claude to immediately checkout a branch.

---

## Known Issues

1. **Split ownership is confusing.** Session-start and session-end hooks are in claude-suite, but arc-tactical and sync-config are in claude-config. No clear principle governs which lives where.

2. **install.sh doesn't register all hooks.** Only SessionStart gets auto-registered. SessionEnd, UserPromptSubmit, and PostToolUse were added manually to settings.json. A fresh install from install.sh alone would miss three hook events.

3. **arc-tactical.sh is orphaned from arc.** The hook that enforces arc's draw-down pattern doesn't live in the arc repo — it's a standalone file in claude-config. If arc evolves its tactical format, the hook needs manual updating.

4. **Guard duplication.** The identical 15-line guard is copy-pasted across four scripts. A shared `guard.sh` would reduce maintenance risk and ensure consistency if the detection logic changes.

5. **No hook manifest.** There's no single document (until this one) that maps what fires when. Debugging hook interactions requires reading settings.json, tracing symlinks, and reading each script.

6. **update-all.sh inherits its guard indirectly.** If it were ever triggered outside session-start.sh, it would run without a guard. Its background execution (`nohup &`) means it could outlive its parent's guard context.

7. **update-all.sh has blind spots.** The heavy tier updates brew, npm, and claude CLI, but doesn't update high-velocity tools like `gh` (GitHub CLI) and `gcloud` CLI that ship frequent releases. These drift silently.
