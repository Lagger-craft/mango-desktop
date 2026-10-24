#!/usr/bin/env bash
set -euo pipefail

style="$HOME/mango-desktop/mango/wofi.css"
expire="$HOME/mango-desktop/mango/scripts/clipboard-expire.sh"

if [[ ${1:-} == --watch ]]; then
  # cliphist 0.7.0 supports max-items but not max-store-size; cap input bytes
  # before storing, without logging or otherwise displaying clipboard data.
  umask 077
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist"
  mkdir -p -- "$cache_dir"
  temporary_item=$(mktemp "$cache_dir/.mango-clipboard.XXXXXXXX")
  trap 'rm -f -- "$temporary_item"' EXIT
  trap 'exit 1' HUP INT TERM
  head -c 1048577 > "$temporary_item"
  cat > /dev/null
  item_size=$(wc -c < "$temporary_item")
  if (( item_size > 1048576 )); then
    exit 0
  fi
  if (( item_size == 0 )); then
    # An emptied clipboard stores nothing; only its selection clock moves.
    "$expire" --touch || true
    exit 0
  fi
  cliphist -max-items 100 store < "$temporary_item"
  # Bookkeeping only: a failed stamp must never break clipboard collection.
  "$expire" --stamp || true
  exit 0
fi

# A canceled picker must not send empty input to wl-copy.
# Toggle: if a picker is already open, Super+V closes it instead of stacking
# another instance (previously each press spawned a new wofi).
picker_pattern='wofi --dmenu.*Clipboard history'
if pgrep -f -- "$picker_pattern" > /dev/null; then
  pkill -f -- "$picker_pattern"
  exit 0
fi

# Expire stale history first so the picker never offers it. Best-effort: a
# failed prune must not block the menu.
"$expire" || true

if ! selection=$(cliphist list | wofi --dmenu --style "$style" --prompt 'Clipboard history'); then
  exit 0
fi

[[ -n "$selection" ]] || exit 0
printf '%s\n' "$selection" | cliphist decode | wl-copy
