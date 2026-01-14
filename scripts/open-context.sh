#!/bin/bash
# Consolidated context gathering for /open
# Outputs structured sections for Claude to parse

set -e

# === SELF-VALIDATION ===
# Check critical dependencies before running. Fail fast with clear messages.
validate_dependencies() {
    local missing=""

    # jq: required for JSON parsing of beads output
    if ! command -v jq &>/dev/null; then
        missing="$missing jq(brew install jq)"
    fi

    # stat: required for file timestamps (should always exist on macOS/Linux)
    if ! command -v stat &>/dev/null; then
        missing="$missing stat"
    fi

    if [ -n "$missing" ]; then
        echo "=== SCRIPT_ERROR ==="
        echo "ERROR: open-context.sh missing dependencies:$missing"
        echo "Install missing tools and retry."
        echo "SCRIPT_FAILED=true"
        exit 1
    fi
}

validate_dependencies

# === TIME ===
echo "=== TIME ==="
CURRENT_HOUR=$(date +%H)
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M')
CURRENT_DATETIME="$CURRENT_DATE $CURRENT_TIME"

if [ "$CURRENT_HOUR" -lt 12 ]; then
    TIME_OF_DAY="morning"
elif [ "$CURRENT_HOUR" -lt 17 ]; then
    TIME_OF_DAY="afternoon"
elif [ "$CURRENT_HOUR" -lt 21 ]; then
    TIME_OF_DAY="evening"
else
    TIME_OF_DAY="night"
fi

echo "NOW=$CURRENT_DATETIME"
echo "TIME_OF_DAY=$TIME_OF_DAY"
echo "YEAR=$(date +%Y)"

# Time-aware language: converts timestamp to human-readable with absolute anchor
# Usage: time_ago <seconds_ago> <epoch_timestamp>
time_ago() {
    local seconds=$1
    local timestamp=$2
    local absolute=$(date -r "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null)

    local relative
    if [ "$seconds" -lt 60 ]; then
        relative="just now"
    elif [ "$seconds" -lt 3600 ]; then
        local mins=$((seconds / 60))
        [ "$mins" -eq 1 ] && relative="1 minute ago" || relative="$mins minutes ago"
    elif [ "$seconds" -lt 86400 ]; then
        local hours=$((seconds / 3600))
        [ "$hours" -eq 1 ] && relative="1 hour ago" || relative="$hours hours ago"
    elif [ "$seconds" -lt 172800 ]; then
        relative="yesterday"
    else
        local days=$((seconds / 86400))
        relative="$days days ago"
    fi

    echo "$relative ($absolute)"
}

# === LOCAL HANDOFF WARNING ===
# Check for orphaned local .handoff* files that /open won't read
LOCAL_HANDOFFS=$(ls -1 .handoff* 2>/dev/null | head -5)
if [ -n "$LOCAL_HANDOFFS" ]; then
    echo "=== LOCAL_HANDOFF_WARNING ==="
    echo "WARNING: Found local .handoff* files that /open ignores:"
    echo "$LOCAL_HANDOFFS" | sed 's/^/  /'
    echo ""
    echo "These may be orphaned handoffs. To rescue:"
    echo "  mv .handoff* ~/.claude/handoffs/<encoded-path>/"
    echo ""
    echo "ORPHANED_HANDOFFS=true"
    echo ""
fi

# === HANDOFF ===
echo "=== HANDOFF ==="

# Central location only (matches Claude Code session folder pattern)
ARCHIVE_DIR="$HOME/.claude/handoffs"
CWD=$(pwd -P)  # -P resolves symlinks for consistent encoding
NOW=$(date +%s)

# Encode path to match Anthropic's folder structure: / and . both become -
ENCODED_PATH=$(echo "$CWD" | tr '/.' '-')
PROJECT_FOLDER="$ARCHIVE_DIR/$ENCODED_PATH"

if [ -d "$PROJECT_FOLDER" ]; then
    # List all handoffs, sorted by modification time (newest first)
    HANDOFF_FILES=$(ls -t "$PROJECT_FOLDER"/*.md 2>/dev/null)
    HANDOFF_COUNT=$(echo "$HANDOFF_FILES" | grep -c . 2>/dev/null || echo 0)

    if [ "$HANDOFF_COUNT" -gt 0 ]; then
        echo "HANDOFF_COUNT=$HANDOFF_COUNT"
        echo ""

        if [ "$HANDOFF_COUNT" -eq 1 ]; then
            # Single handoff: show it directly (original behavior)
            MATCH_FILE=$(echo "$HANDOFF_FILES" | head -1)
            FILE_TIME=$(stat -f '%m' "$MATCH_FILE" 2>/dev/null || stat -c '%Y' "$MATCH_FILE" 2>/dev/null)
            SECONDS_AGO=$((NOW - FILE_TIME))
            TIME_STR=$(time_ago $SECONDS_AGO $FILE_TIME)
            echo "# Handoff ($TIME_STR)"
            echo ""
            cat "$MATCH_FILE"
            echo ""
            echo "HANDOFF_EXISTS=true"
            echo "HANDOFF_AGE_SECONDS=$SECONDS_AGO"
        else
            # Multiple handoffs: show picker list
            echo "# Multiple handoffs available"
            echo ""
            INDEX=1
            # Use while read to handle paths with spaces
            echo "$HANDOFF_FILES" | while IFS= read -r f; do
                [ -z "$f" ] && continue
                FILE_TIME=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null)
                SECONDS_AGO=$((NOW - FILE_TIME))
                TIME_STR=$(time_ago $SECONDS_AGO $FILE_TIME)
                FILENAME=$(basename "$f" .md)

                # Extract purpose from header, or first Done bullet, or filename
                PURPOSE=$(grep "^purpose:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
                if [ -z "$PURPOSE" ]; then
                    # Try first Done bullet (strip leading "- ")
                    PURPOSE=$(grep -A1 "^## Done" "$f" 2>/dev/null | tail -1 | sed 's/^- //' | cut -c1-60)
                fi
                if [ -z "$PURPOSE" ]; then
                    PURPOSE="$FILENAME"
                fi

                echo "  $INDEX. $FILENAME · $TIME_STR"
                echo "     $PURPOSE"
                echo ""
                INDEX=$((INDEX + 1))
            done

            echo "HANDOFF_EXISTS=true"
            echo "HANDOFF_MULTIPLE=true"
            echo ""
            echo "# Most recent handoff (default):"
            echo ""
            MATCH_FILE=$(echo "$HANDOFF_FILES" | head -1)
            cat "$MATCH_FILE"
        fi
    else
        echo "HANDOFF_EXISTS=false"
    fi
else
    echo "HANDOFF_EXISTS=false"
fi

# === GIT STATUS ===
echo ""
echo "=== GIT ==="
if [ -d ".git" ]; then
    # Filter out noise: beads metadata, local settings, memory internals
    DIRTY=$(git status --porcelain 2>/dev/null | grep -v -E '\.beads/|settings\.local\.json|\.update-news|^..\s*memory/(config|glossary)\.yaml' || true)
    UNPUSHED=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    if [ -n "$DIRTY" ] || [ "$UNPUSHED" -gt 0 ]; then
        echo "WARNING: Uncommitted/unpushed work detected"
        if [ -n "$DIRTY" ]; then
            echo "  Uncommitted:"
            echo "$DIRTY" | head -5 | sed 's/^/    /'
            TOTAL=$(echo "$DIRTY" | wc -l | tr -d ' ')
            [ "$TOTAL" -gt 5 ] && echo "    ... and $((TOTAL - 5)) more"
        fi
        [ "$UNPUSHED" -gt 0 ] && echo "  Unpushed: $UNPUSHED commits"
        echo "GIT_DIRTY=true"
    else
        # Silent when clean - nothing to act on
        echo "GIT_DIRTY=false"
    fi
else
    # Silent when not a repo - nothing to act on
    echo "GIT_DIRTY=false"
fi

# === BEADS ===
echo ""
echo "=== BEADS ==="
if [ -d ".beads" ]; then
    # --no-daemon: avoid 5s timeout if daemon not running (startup speed)
    bd ready --no-daemon 2>/dev/null | head -15

    # Show recently closed (context for what just finished)
    RECENTLY_CLOSED=$(bd list --no-daemon --status closed 2>/dev/null | head -5)
    if [ -n "$RECENTLY_CLOSED" ]; then
        echo ""
        echo "Recently closed:"
        echo "$RECENTLY_CLOSED"
    fi

    echo "BEADS_EXISTS=true"

    # === BEADS_HIERARCHY ===
    # Show beads grouped by epic (max 2 levels: epic -> tasks)
    # Detect nested epics (epic under epic) and flag for flattening
    EPICS=$(bd list --no-daemon --type epic --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)
    if [ -n "$EPICS" ]; then
        echo ""
        echo "=== BEADS_HIERARCHY (SHOW TO USER) ==="

        # Collect ALL children of ALL epics to find which epics are nested
        ALL_CHILDREN=""
        for epic_id in $EPICS; do
            children=$(bd list --no-daemon --parent "$epic_id" --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)
            ALL_CHILDREN="$ALL_CHILDREN $children"
        done

        # Show only top-level epics (not a child of another epic)
        for epic_id in $EPICS; do
            # Skip if this epic is a child of another epic
            if echo "$ALL_CHILDREN" | grep -q "$epic_id"; then
                continue
            fi
            epic_title=$(bd show --no-daemon "$epic_id" --json 2>/dev/null | jq -r '.[0].title' 2>/dev/null)
            echo "📦 $epic_id: $epic_title"
            # Show children, flagging any that are epics (nested - bad structure)
            bd list --no-daemon --parent "$epic_id" --json 2>/dev/null | jq -r '.[] | if .issue_type == "epic" then "   ├── ⚠️ \(.id): \(.title) [NESTED EPIC - flatten]" else "   ├── \(.id): \(.title)" end' 2>/dev/null
        done

        # Standalone tasks (no parent, not epic)
        ORPHANS=$(bd list --no-daemon --json 2>/dev/null | jq -r '.[] | select(.issue_type != "epic") | select(.dependency_count == 0) | "\(.id): \(.title)"' 2>/dev/null)
        if [ -n "$ORPHANS" ]; then
            echo ""
            echo "Standalone (no epic):"
            echo "$ORPHANS" | sed 's/^/• /'
        fi
    fi

    # Check for bd version updates (valuable given rapid development)
    WHATS_NEW=$(bd info --no-daemon --whats-new 2>/dev/null | head -30)
    if [ -n "$WHATS_NEW" ]; then
        echo ""
        echo "=== BEADS_NEWS ==="
        echo "$WHATS_NEW"
    fi
else
    # Silent when no beads - not all projects use them
    echo "BEADS_EXISTS=false"
fi

# === UPDATE NEWS ===
echo ""
echo "=== UPDATE_NEWS ==="
if [ -f "$HOME/.claude/.update-news" ]; then
    cat "$HOME/.claude/.update-news"
    echo "UPDATE_NEWS_EXISTS=true"
else
    # Silent when no news
    echo "UPDATE_NEWS_EXISTS=false"
fi

# === TODOIST ===
echo ""
echo "=== TODOIST ==="
echo "Check @Claude inbox for pending items (use Todoist MCP)."
