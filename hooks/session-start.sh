#!/bin/bash
#
# Session Start Hook
# Outputs session context to stdout (Claude sees this automatically)
# Runs heavy updates in background (no stdout)
#
# Lives in: claude-suite/hooks/
# Symlinked from: ~/.claude/hooks/session-start.sh

set -euo pipefail

# Scripts are in sibling folder, but we check via ~/.claude/scripts/ symlinks
# which is what actually matters for the user's setup
SCRIPTS_DIR="$HOME/.claude/scripts"

# === QUICK HEALTH CHECK ===
# Fast validation of critical infrastructure. Errors here = silent failures later.
quick_health_check() {
    local issues=""

    # Check critical symlinks (fast: just stat the targets)
    for script in open-context.sh close-context.sh; do
        local link="$HOME/.claude/scripts/$script"
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            issues="$issues\n  ❌ Broken symlink: $script"
        fi
    done

    # Check companion scripts exist
    if [ ! -x "$SCRIPTS_DIR/open-context.sh" ]; then
        issues="$issues\n  ❌ open-context.sh missing or not executable"
    fi

    # Check for recent extraction failures (memory indexing)
    local log_dir="$HOME/.claude/extraction-logs"
    if [ -d "$log_dir" ]; then
        local recent_failures=$(find "$log_dir" -name "*.FAILED.log" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
        local recent_successes=$(find "$log_dir" -name "*.log" ! -name "*.FAILED.log" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
        if [ "$recent_failures" -gt 0 ] && [ "$recent_successes" -eq 0 ]; then
            issues="$issues\n  ❌ Memory indexing broken: $recent_failures failures, 0 successes in last 24h"
            issues="$issues\n     Check: ls ~/.claude/extraction-logs/*.FAILED.log"
        fi
    fi

    if [ -n "$issues" ]; then
        echo "=== INFRASTRUCTURE WARNING ==="
        echo -e "Critical issues detected:$issues"
        echo ""
        echo "Run: ~/.claude/scripts/claude-doctor.sh for full diagnosis"
        echo "These issues will cause /open and /close to fail silently!"
        echo ""
    fi
}

quick_health_check

# Timing telemetry (milliseconds via perl, seconds fallback)
ms_now() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || echo $(($(date +%s) * 1000)); }
HOOK_START=$(ms_now)
TRACE_FILE="$HOME/.claude/.hook-trace"

# === CONTEXT OUTPUT (stdout → Claude) ===

# Run context gathering script (handoff, beads, time, updates)
CONTEXT_SCRIPT="$SCRIPTS_DIR/open-context.sh"
if [ -x "$CONTEXT_SCRIPT" ]; then
    CONTEXT_START=$(ms_now)
    "$CONTEXT_SCRIPT" 2>/dev/null || true
    CONTEXT_MS=$(( $(ms_now) - CONTEXT_START ))
else
    CONTEXT_MS=0
fi

# Check for incomplete /close from previous session
CHECKPOINT_FILE="$HOME/.claude/.close-checkpoint"
if [ -f "$CHECKPOINT_FILE" ]; then
    echo ""
    echo "=== INCOMPLETE CLOSE ==="
    echo "WARNING: Last session's /close was interrupted."
    echo ""
    cat "$CHECKPOINT_FILE"
    echo ""
    echo "Run '/close --resume' to complete, or delete checkpoint to ignore."
fi

# Note: Todoist @Claude items require MCP - Claude should query after seeing this context

# === BACKGROUND UPDATES (no stdout) ===
# update-all.sh stays in claude-config repo (not session-management)
UPDATE_SCRIPT="$HOME/.claude/scripts/update-all.sh"
if [ -x "$UPDATE_SCRIPT" ]; then
    nohup "$UPDATE_SCRIPT" > /dev/null 2>&1 &
fi

# Write timing telemetry
TOTAL_MS=$(( $(ms_now) - HOOK_START ))
echo "$(date '+%Y-%m-%d %H:%M:%S') total=${TOTAL_MS}ms context=${CONTEXT_MS}ms pwd=$(pwd)" >> "$TRACE_FILE"

exit 0
