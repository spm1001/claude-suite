#!/bin/bash
# check-home.sh - Compare expected directory (from system prompt) to actual pwd
#
# Usage: check-home.sh "/expected/path"
#
# The expected path should come from Claude's system prompt "Working directory:" field,
# which is immutable for the session. This prevents confabulation about current location.

expected="$1"
actual="$PWD"

if [[ -z "$expected" ]]; then
    echo "ERROR=No expected directory provided"
    echo "# Usage: check-home.sh \"/path/from/system/prompt\""
    exit 1
fi

# Normalize paths (resolve symlinks, remove trailing slashes)
expected_norm=$(cd "$expected" 2>/dev/null && pwd -P) || expected_norm="$expected"
actual_norm=$(pwd -P)

if [[ "$expected_norm" != "$actual_norm" ]]; then
    echo "CD_REQUIRED=true"
    echo "HOME_DIR=$expected"
    echo "# DRIFT DETECTED"
    echo "#   Session started: $expected"
    echo "#   Currently at:    $actual"
    echo "#"
    echo "# Run: cd \"$expected\""
else
    echo "CD_REQUIRED=false"
    echo "HOME_DIR=$actual"
fi
