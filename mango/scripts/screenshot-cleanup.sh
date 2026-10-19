#!/usr/bin/env bash
set -euo pipefail

# Prunes screenshots older than 3 days and keeps the directory owner-only.
#
# Scope is deliberately narrow: only regular files inside the screenshots
# directory are considered. The wallpaper directory (the matugen palette
# source) and every other path are never touched, so pruning can never change
# the theme colours.

readonly screenshots_dir="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
readonly max_age_days="${SCREENSHOT_MAX_AGE_DAYS:-3}"

[[ -d "$screenshots_dir" ]] || exit 0

# Owner-only: screenshots routinely contain private content.
chmod 700 -- "$screenshots_dir" 2>/dev/null || true

# -mtime +N means "strictly older than N*24h". Recursive, so a screenshot kept
# in a subfolder expires on the same schedule.
find "$screenshots_dir" -mindepth 1 -type f -mtime "+$max_age_days" -delete

# Drop directories left empty by the prune.
find "$screenshots_dir" -mindepth 1 -type d -empty -delete 2>/dev/null || true
