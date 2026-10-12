#!/usr/bin/env bash
# Volume control with an OSD state signal for the QuickShell popup.
#
# Usage: volume-osd.sh <up|down|mute>
#
# Performs the wpctl action, then atomically writes
#   <focused-monitor> <volume-fraction> <muted-0-or-1>
# to $XDG_RUNTIME_DIR/mango-volume-osd. The QuickShell bar watches that file
# and shows the OSD on the monitor the compositor reports as focused.
set -euo pipefail

sink="@DEFAULT_AUDIO_SINK@"
state_file="${XDG_RUNTIME_DIR:-/tmp}/mango-volume-osd"

case "${1:-}" in
  up)   wpctl set-volume "$sink" 5%+ --limit 1.0 ;;
  down) wpctl set-volume "$sink" 5%- ;;
  mute) wpctl set-mute "$sink" toggle ;;
  *)    echo "usage: $0 <up|down|mute>" >&2; exit 1 ;;
esac

# wpctl get-volume prints: "Volume: 0.55" or "Volume: 0.55 [MUTED]"
status="$(wpctl get-volume "$sink")"
volume="$(awk '{print $2}' <<<"$status")"
muted=0
[[ "$status" == *"[MUTED]"* ]] && muted=1

monitor="$(mmsg get all-monitors | sed 's/{"name"/\n{"name"/g' | grep -m1 '"active":true' | sed -E 's/^\{"name":"([^"]+)".*/\1/')"
[[ -n "$monitor" ]] || monitor="unknown"

tmp="$(mktemp "${state_file}.XXXXXX")"
printf '%s %s %s\n' "$monitor" "$volume" "$muted" >"$tmp"
mv -f "$tmp" "$state_file"
