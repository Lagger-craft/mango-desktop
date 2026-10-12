#!/usr/bin/env bash
set -euo pipefail

style="$HOME/mango-desktop/mango/wofi.css"

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
  cliphist -max-items 100 store < "$temporary_item"
  exit 0
fi

# A canceled picker must not send empty input to wl-copy.
if ! selection=$(cliphist list | wofi --dmenu --style "$style" --prompt 'Clipboard history'); then
  exit 0
fi

[[ -n "$selection" ]] || exit 0
printf '%s\n' "$selection" | cliphist decode | wl-copy
