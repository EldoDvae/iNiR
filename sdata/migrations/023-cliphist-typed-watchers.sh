#!/usr/bin/env bash
# Migration 023: Switch cliphist watcher to type-specific watchers
#
# The old `wl-paste --watch cliphist store` stores every MIME type the
# clipboard offers. Browsers offer both text/html and text/plain, so
# cliphist gets duplicate entries (one with HTML tags, one clean).
#
# Replace with two type-specific watchers:
#   wl-paste --type text --watch cliphist store
#   wl-paste --type image --watch cliphist store

set -euo pipefail

STARTUP_FILE="${HOME}/.config/niri/config.d/50-startup.kdl"

[[ -f "$STARTUP_FILE" ]] || exit 0

# Already migrated — has --type text
if grep -q 'wl-paste --type text --watch cliphist store' "$STARTUP_FILE" 2>/dev/null; then
    exit 0
fi

# Find and replace the untyped watcher
if grep -q 'wl-paste --watch cliphist store' "$STARTUP_FILE" 2>/dev/null; then
    sed -i \
        's|wl-paste --watch cliphist store|wl-paste --type text --watch cliphist store|' \
        "$STARTUP_FILE"

    # Add the image watcher right after the text watcher line
    sed -i \
        '/wl-paste --type text --watch cliphist store/a spawn-at-startup "bash" "-c" "wl-paste --type image --watch cliphist store \&"' \
        "$STARTUP_FILE"
fi
