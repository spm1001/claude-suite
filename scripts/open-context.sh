#!/bin/bash
# Session context gathering
# Stdout: compact briefing for human and Claude to orient from
# Disk: full detail (arc.txt, handoffs.txt) for Claude to read on demand

set -euo pipefail

# === PATHS ===
BASE_CONTEXT_DIR="$HOME/.claude/.session-context"
CWD=$(pwd -P)
ENCODED_PATH=$(echo "$CWD" | tr '/.' '-')
CONTEXT_DIR="$BASE_CONTEXT_DIR/$ENCODED_PATH"
mkdir -p "$CONTEXT_DIR"

# === SELF-VALIDATION ===
validate_dependencies() {
    local missing=""
    if ! command -v jq &>/dev/null; then
        missing="$missing jq(brew install jq)"
    fi
    if ! command -v stat &>/dev/null; then
        missing="$missing stat"
    fi
    if [ -n "$missing" ]; then
        echo "ERROR: missing dependencies:$missing"
        exit 1
    fi
}
validate_dependencies

# === HELPERS ===
time_ago() {
    local seconds=$1
    local timestamp=$2
    local absolute=$(date -r "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null)
    local relative
    if [ "$seconds" -lt 3600 ]; then
        local mins=$((seconds / 60))
        [ "$mins" -le 1 ] && relative="just now" || relative="${mins}m ago"
    elif [ "$seconds" -lt 86400 ]; then
        local hours=$((seconds / 3600))
        relative="${hours}h ago"
    elif [ "$seconds" -lt 172800 ]; then
        relative="yesterday"
    else
        local days=$((seconds / 86400))
        relative="${days}d ago"
    fi
    echo "$relative"
}

# === LOCAL HANDOFF WARNING ===
LOCAL_HANDOFFS=$(find . -maxdepth 1 -name '.handoff*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$LOCAL_HANDOFFS" -gt 0 ]; then
    echo "Warning: $LOCAL_HANDOFFS orphaned local .handoff* files (should move to ~/.claude/handoffs/)"
    echo ""
fi

# === GATHER TO DISK (silent) ===

# --- Handoff index ---
ARCHIVE_DIR="$HOME/.claude/handoffs"
NOW=$(date +%s)
PROJECT_FOLDER="$ARCHIVE_DIR/$ENCODED_PATH"
HANDOFF_INDEX="$CONTEXT_DIR/handoffs.txt"
LATEST_FILE=""
LATEST_PURPOSE=""
LATEST_STR=""

if [ -d "$PROJECT_FOLDER" ]; then
    HANDOFF_FILES=$(ls -t "$PROJECT_FOLDER"/*.md 2>/dev/null || true)
    HANDOFF_COUNT=$(echo "$HANDOFF_FILES" | grep -c . 2>/dev/null || echo 0)

    if [ "$HANDOFF_COUNT" -gt 0 ]; then
        # Write full index to disk
        echo "# Generated for: $CWD" > "$HANDOFF_INDEX"
        echo "" >> "$HANDOFF_INDEX"
        echo "$HANDOFF_FILES" | while IFS= read -r f; do
            [ -z "$f" ] && continue
            FILE_TIME=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null)
            SECONDS_AGO=$((NOW - FILE_TIME))
            TIME_STR=$(time_ago $SECONDS_AGO $FILE_TIME)
            FILENAME=$(basename "$f" .md)
            PURPOSE=$(grep "^purpose:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
            if [ -z "$PURPOSE" ]; then
                PURPOSE=$(grep -A1 "^## Done" "$f" 2>/dev/null | tail -1 | sed 's/^- //' | cut -c1-50 || true)
            fi
            [ -z "$PURPOSE" ] && PURPOSE="(no summary)"
            echo "$FILENAME | $TIME_STR | $PURPOSE" >> "$HANDOFF_INDEX"
            echo "PATH:$f" >> "$HANDOFF_INDEX"
        done

        # Extract latest handoff details for stdout
        LATEST_FILE=$(echo "$HANDOFF_FILES" | head -1)
        LATEST_TIME=$(stat -f '%m' "$LATEST_FILE" 2>/dev/null || stat -c '%Y' "$LATEST_FILE" 2>/dev/null)
        LATEST_AGO=$((NOW - LATEST_TIME))
        LATEST_STR=$(time_ago $LATEST_AGO $LATEST_TIME)
        LATEST_PURPOSE=$(grep "^purpose:" "$LATEST_FILE" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
        if [ -z "$LATEST_PURPOSE" ]; then
            LATEST_PURPOSE=$(grep -A1 "^## Done" "$LATEST_FILE" 2>/dev/null | tail -1 | sed 's/^- //' | cut -c1-60 || true)
        fi
    else
        rm -f "$HANDOFF_INDEX"
    fi
else
    rm -f "$HANDOFF_INDEX"
fi

# --- Arc context to disk ---
ARC_FILE="$CONTEXT_DIR/arc.txt"
ARC_CMD=""
ARC_LIST_OUTPUT=""
ARC_READY_OUTPUT=""
ARC_CURRENT_OUTPUT=""

if [ -d ".arc" ]; then
    ARC_CMD=$(command -v arc 2>/dev/null || echo "$HOME/Repos/arc/.venv/bin/arc")

    if [ -x "$ARC_CMD" ]; then
        ARC_LIST_OUTPUT=$("$ARC_CMD" list 2>/dev/null || true)
        ARC_READY_OUTPUT=$("$ARC_CMD" list --ready 2>/dev/null || true)
        ARC_CURRENT_OUTPUT=$("$ARC_CMD" show --current 2>/dev/null || true)

        # Write full hierarchy to disk
        {
            echo "# Arc Context (generated $(date '+%Y-%m-%d %H:%M'))"
            echo "# Generated for: $CWD"
            echo ""
            echo "## Ready Work"
            echo "$ARC_READY_OUTPUT"
            echo ""
            echo "## Full Hierarchy"
            echo "$ARC_LIST_OUTPUT"
        } > "$ARC_FILE"
    else
        rm -f "$ARC_FILE"
    fi
else
    rm -f "$ARC_FILE"
fi

# === STDOUT BRIEFING ===
echo "=== SESSION ==="

# --- Greeting ---
CURRENT_HOUR=$(date +%H)
if [ "$CURRENT_HOUR" -lt 12 ]; then
    TIME_OF_DAY="morning"
elif [ "$CURRENT_HOUR" -lt 17 ]; then
    TIME_OF_DAY="afternoon"
elif [ "$CURRENT_HOUR" -lt 21 ]; then
    TIME_OF_DAY="evening"
else
    TIME_OF_DAY="night"
fi
echo "Good $TIME_OF_DAY. It's $(date '+%-d %b %Y, %H:%M')."
echo ""

# --- Arc: outcomes + zoom ---
if [ -d ".arc" ] && [ -n "$ARC_CMD" ] && [ -x "$ARC_CMD" ]; then
    if [ -n "$ARC_READY_OUTPUT" ]; then
        echo "Outcomes we're working towards:"
        echo "$ARC_READY_OUTPUT" | while IFS= read -r line; do
            [ -n "$line" ] && echo "  $line"
        done
        echo ""
    fi

    # Zoom: show the outcome with active tactical steps
    if [ -n "$ARC_CURRENT_OUTPUT" ]; then
        # arc show --current format: "Working: <title> (<id>)"
        CURRENT_ACTION_ID=$(echo "$ARC_CURRENT_OUTPUT" | head -1 | grep -oE '\([a-zA-Z0-9-]+\)' | tr -d '()' || true)
        if [ -n "$CURRENT_ACTION_ID" ]; then
            # Get parent outcome
            PARENT_ID=$("$ARC_CMD" show "$CURRENT_ACTION_ID" --json 2>/dev/null | jq -r '.parent // empty' 2>/dev/null || true)
            if [ -n "$PARENT_ID" ]; then
                PARENT_TITLE=$("$ARC_CMD" show "$PARENT_ID" --json 2>/dev/null | jq -r '.title // empty' 2>/dev/null || true)
                if [ -n "$PARENT_TITLE" ]; then
                    echo "Last worked on: $PARENT_TITLE"
                    # Show actions from list output — find outcome and its children
                    PRINTING=false
                    while IFS= read -r line; do
                        if echo "$line" | grep -qF "$PARENT_ID"; then
                            PRINTING=true
                            continue
                        fi
                        if [ "$PRINTING" = true ]; then
                            if echo "$line" | grep -qE '^\s+[0-9]+\.'; then
                                # Trim leading whitespace, re-indent consistently
                                TRIMMED=$(echo "$line" | sed 's/^[[:space:]]*//')
                                echo "  $TRIMMED"
                            else
                                break
                            fi
                        fi
                    done <<< "$ARC_LIST_OUTPUT"
                    echo ""
                fi
            fi
        fi
    fi
elif [ -d ".arc" ]; then
    echo "Arc: .arc/ exists but arc CLI not found"
    echo ""
fi

# --- Handoff summary ---
if [ -n "$LATEST_FILE" ]; then
    echo "Last session ($LATEST_STR): $LATEST_PURPOSE"

    # Extract key sections from the handoff
    DONE_LINES=$(sed -n '/^## Done/,/^## /{/^## Done/d;/^## /d;p;}' "$LATEST_FILE" 2>/dev/null | head -3 | sed 's/^- //' || true)
    NEXT_LINES=$(sed -n '/^## Next/,/^## /{/^## Next/d;/^## /d;p;}' "$LATEST_FILE" 2>/dev/null | head -3 | sed 's/^- //' || true)
    GOTCHA_LINES=$(sed -n '/^## Gotchas/,/^## /{/^## Gotchas/d;/^## /d;p;}' "$LATEST_FILE" 2>/dev/null | head -2 | sed 's/^- //' || true)

    if [ -n "$DONE_LINES" ]; then
        echo "  Did:"
        echo "$DONE_LINES" | while IFS= read -r line; do
            [ -n "$line" ] && echo "    $line"
        done
    fi
    if [ -n "$NEXT_LINES" ]; then
        echo "  Next:"
        echo "$NEXT_LINES" | while IFS= read -r line; do
            [ -n "$line" ] && echo "    $line"
        done
    fi
    if [ -n "$GOTCHA_LINES" ]; then
        echo "  Watch out:"
        echo "$GOTCHA_LINES" | while IFS= read -r line; do
            [ -n "$line" ] && echo "    $line"
        done
    fi
    echo ""
fi

# --- Beads deprecation ---
if [ -d ".beads" ]; then
    echo "Beads (deprecated): .beads/ found — consider arc migrate --from-beads .beads/"
    echo ""
fi

# --- News (only mention if present) ---
NEWS_FILE="$HOME/.claude/.update-news"
if [ -f "$NEWS_FILE" ]; then
    echo "News available: $NEWS_FILE"
fi
