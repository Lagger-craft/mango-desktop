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
  mpvpaper -p -a FULL -o 'no-audio loop image-display-duration=inf panscan=1' ALL "$image" &
  printf '%s\n' "$!" > "$pid_file"
  printf '%s\n' "$image" > "$selection_file"
}

# Deterministic fallback: the seeded default wins so a fresh session always
# starts the same way, otherwise the alphabetically first image.
pick_fallback() {
  if [[ -f "$wallpaper_dir/default.png" ]]; then
    printf '%s\n' "$wallpaper_dir/default.png"
    return 0
  fi
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print 2>/dev/null | sort | head -n 1
}

if [[ "${1:-}" == --restore ]]; then
  selected=""
  if [[ -r "$selection_file" ]]; then
    IFS= read -r selected < "$selection_file" || true
  fi
  # Honour the persisted choice only while the file it points at still exists;
  # a deleted image must not strand the desktop on a blank screen.
  if [[ -n "${selected:-}" && "$selected" == "$wallpaper_dir"/* && -f "$selected" ]]; then
    start_wallpaper "$selected"
    exit 0
  fi
  # No valid persisted selection (fresh install, or the image was removed
  # since): fall back to whatever is present instead of exiting silently and
  # leaving the user with an empty desktop and no diagnostic.
  fallback="$(pick_fallback)"
  if [[ -n "$fallback" ]]; then
    start_wallpaper "$fallback"
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
