#!/usr/bin/env bash
set -euo pipefail

readonly wallpaper_dir="$HOME/Pictures/Wallpapers"
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mango"
readonly selection_file="$state_dir/wallpaper"
readonly pid_file="$state_dir/wallpaper.pid"
readonly style="$HOME/mango-desktop/mango/wofi.css"

stop_managed_wallpaper() {
  if [[ -r "$pid_file" ]]; then
    local pid comm
    read -r pid < "$pid_file" || true
    if [[ "${pid:-}" =~ ^[0-9]+$ && -r "/proc/$pid/comm" ]]; then
      IFS= read -r comm < "/proc/$pid/comm" || true
      if [[ "$comm" == mpvpaper ]]; then
        kill "$pid" 2>/dev/null || true
      fi
    fi
    rm -f -- "$pid_file"
  fi
}

start_wallpaper() {
  local image=$1
  [[ -f "$image" ]] || return 1
  mkdir -p -- "$state_dir"
  stop_managed_wallpaper
  mpvpaper -p -a FULL -o 'no-audio loop' ALL "$image" &
  printf '%s\n' "$!" > "$pid_file"
  printf '%s\n' "$image" > "$selection_file"
}

if [[ "${1:-}" == --restore ]]; then
  if [[ -r "$selection_file" ]]; then
    IFS= read -r selected < "$selection_file" || true
    if [[ -n "${selected:-}" && "$selected" == "$wallpaper_dir"/* ]]; then
      start_wallpaper "$selected"
    fi
  fi
  exit 0
fi
if [[ "${1:-}" == --stop ]]; then
  stop_managed_wallpaper
  exit 0
fi

mapfile -d '' -t images < <(find "$wallpaper_dir" -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
  -print0 2>/dev/null | sort -z)
((${#images[@]})) || exit 0

labels=()
for image in "${images[@]}"; do
  labels+=("${image#"$wallpaper_dir"/}")
done
choice=$(printf '%s\n' "${labels[@]}" |
  wofi --dmenu --prompt 'SELECT WALLPAPER' --style "$style") || exit 0

for index in "${!labels[@]}"; do
  if [[ "${labels[$index]}" == "$choice" ]]; then
    start_wallpaper "${images[$index]}"
    exit 0
  fi
done
exit 0
