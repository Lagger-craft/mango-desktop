#!/usr/bin/env bash
set -euo pipefail

# Controller for the desktop's wallpaper renderers. It replaces the old Wofi
# selector: it no longer opens a menu (the QuickShell picker does that), it only
# exposes list/apply/restore/stop to whatever drives the choice.
#
# Two renderers back one per-monitor state map:
#   local -> mpvpaper, one instance per output, auto-pauses when any window is
#            fullscreen (-p -a FULL).
#   we    -> a single linux-wallpaperengine process, one --screen-root/--bg
#            pair per Workshop monitor, pauses when a fullscreen window is
#            active (--fullscreen-pause-only-active).
# Applying any single monitor rebuilds the whole renderer set from state so the
# two renderers can never overlap on one output.

readonly wallpaper_dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mango"
readonly state_file="$state_dir/wallpapers.json"
readonly pid_dir="$state_dir/wallpaper-pids"
readonly lwe_pid="$pid_dir/lwe.pid"
readonly render_log="$state_dir/renderer.log"

die() { printf 'wallpaper-ctl: %s\n' "$*" >&2; exit 1; }

# First Steam root that actually holds Workshop content for Wallpaper Engine
# (app 431960), in the locations linux-wallpaperengine itself recognises plus
# the flatpak/snap installs. Empty output means none found.
find_workshop_dir() {
  local root
  for root in \
    "$HOME/.local/share/Steam" \
    "$HOME/.steam/steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
    "$HOME/snap/steam/common/.local/share/Steam"; do
    if [[ -d "$root/steamapps/workshop/content/431960" ]]; then
      printf '%s\n' "$root/steamapps/workshop/content/431960"
      return 0
    fi
  done
  return 1
}

# Connected monitor names, one per line, straight from the compositor.
list_monitors() {
  mmsg get all-monitors 2>/dev/null |
    jq -r '.monitors[].name' 2>/dev/null || true
}

# ---- state -------------------------------------------------------------
# The map is {"<monitor>":{"type":"local"|"we","ref":"..."}}. An unreadable or
# missing file simply reads as an empty map so a corrupt state never crashes a
# caller.

read_state() {
  if [[ -r "$state_file" ]]; then
    jq -c '.' "$state_file" 2>/dev/null || printf '{}'
  else
    printf '{}'
  fi
}

write_state() { # $1 = json map
  mkdir -p -- "$state_dir"
  printf '%s\n' "$1" > "$state_file"
}

# ---- renderer lifecycle ------------------------------------------------

# Signal one saved PID, but only after confirming /proc still shows the process
# name we recorded — a recycled PID belonging to something else is never killed.
kill_pidfile() { # $1 = pidfile, $2 = comm prefix
  local pidfile=$1 prefix=$2 pid cur
  [[ -r "$pidfile" ]] || return 0
  read -r pid < "$pidfile" || true
  rm -f -- "$pidfile"
  [[ "${pid:-}" =~ ^[0-9]+$ ]] || return 0
  [[ -r "/proc/$pid/comm" ]] || return 0
  IFS= read -r cur < "/proc/$pid/comm" || true
  [[ "$cur" == "$prefix"* ]] || return 0
  kill "$pid" 2>/dev/null || true
  # Give it a moment to exit before escalating, so the next renderer never
  # races a still-dying surface for the same output.
  local i
  for i in $(seq 1 20); do
    [[ -r "/proc/$pid/comm" ]] || return 0
    sleep 0.05
  done
  kill -9 "$pid" 2>/dev/null || true
}

stop_all() {
  kill_pidfile "$lwe_pid" linux-wallpaper
  local f
  for f in "$pid_dir"/mpv-*.pid; do
    [[ -e "$f" ]] || continue
    kill_pidfile "$f" mpvpaper
  done
}

# Rebuild every renderer from the current state map: stop everything, then start
# one linux-wallpaperengine for the Workshop monitors and one mpvpaper per local
# monitor.
apply_all() {
  stop_all
  local state
  state="$(read_state)"
  mkdir -p -- "$pid_dir"

  local we_args=() local_pairs=() mon type ref
  while IFS=$'\t' read -r mon type ref; do
    [[ -n "${mon:-}" ]] || continue
    if [[ "$type" == we ]]; then
      we_args+=(--screen-root "$mon" --bg "$ref")
    elif [[ "$type" == local && -f "$ref" ]]; then
      local_pairs+=("$mon"$'\t'"$ref")
    fi
  done < <(jq -r 'to_entries[] | [.key, .value.type, .value.ref] | @tsv' \
    <<< "$state" 2>/dev/null)

  # Workshop: one process covers every Workshop monitor. Each renderer gets its
  # own stdin/stdout/stderr (a log file, never the caller's pipes): a
  # backgrounded renderer that inherits the caller's stdout keeps that pipe
  # open, which hangs a `cmd | ...` caller and stalls QuickShell's apply Process
  # (it waits for a stream EOF only the forever-running renderer can close).
  if ((${#we_args[@]})); then
    linux-wallpaperengine "${we_args[@]}" --fullscreen-pause-only-active \
      </dev/null >>"$render_log" 2>&1 &
    printf '%s\n' "$!" > "$lwe_pid"
  fi

  # Local: one mpvpaper per output; -p -a FULL auto-pauses on a fullscreen
  # window, and panscan fills each output by cropping rather than stretching.
  local line
  for line in "${local_pairs[@]}"; do
    mon=${line%%$'\t'*}
    ref=${line#*$'\t'}
    mpvpaper -p -a FULL \
      -o 'no-audio loop image-display-duration=inf panscan=1' \
      "$mon" "$ref" \
      </dev/null >>"$render_log" 2>&1 &
    printf '%s\n' "$!" > "$pid_dir/mpv-$mon.pid"
  done
}

# ---- subcommands -------------------------------------------------------

# Emit both sources as ONE compact JSON line. The QuickShell picker reads this
# through a line-splitting parser and JSON.parses each line, so it must be a
# single line — pretty-printed multi-line JSON would be discarded line by line
# and the picker would show nothing.
cmd_list() {
  local out f
  out='{"local":[],"we":[]}'

  while IFS= read -r -d '' f; do
    out=$(jq -c --arg ref "$f" --arg name "$(basename "$f")" \
      '.local += [{ref:$ref, name:$name}]' <<< "$out")
  done < <(find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print0 2>/dev/null | sort -z)

  local workshop d id title preview ptype
  if workshop="$(find_workshop_dir)"; then
    while IFS= read -r -d '' d; do
      id=$(basename "$d")
      title=$(jq -r '.title // empty' "$d/project.json" 2>/dev/null || true)
      preview=$(jq -r '.preview // empty' "$d/project.json" 2>/dev/null || true)
      if [[ -z "$preview" || ! -f "$d/$preview" ]]; then
        preview=""
        local cand
        for cand in preview.jpg preview.gif preview.png; do
          [[ -f "$d/$cand" ]] && { preview=$cand; break; }
        done
      fi
      ptype=$(jq -r '.type // "unknown"' "$d/project.json" 2>/dev/null || echo unknown)
      out=$(jq -c --arg ref "$id" --arg title "${title:-$id}" \
        --arg preview "$([[ -n "$preview" ]] && printf '%s/%s' "$d" "$preview")" \
        --arg type "$ptype" \
        '.we += [{ref:$ref, title:$title, preview:$preview, type:$type}]' <<< "$out")
    done < <(find "$workshop" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  fi

  printf '%s\n' "$out"
}

cmd_apply() { # $1 = monitor, $2 = local|we, $3 = ref
  local mon=${1:-} type=${2:-} ref=${3:-}
  [[ -n "$mon" && -n "$type" && -n "$ref" ]] ||
    die "usage: apply <monitor> <local|we> <ref>"
  case "$type" in
    local) [[ -f "$ref" ]] || die "local wallpaper not found: $ref" ;;
    we)
      local ws
      ws="$(find_workshop_dir || true)"
      [[ -n "$ws" && -d "$ws/$ref" ]] || die "workshop background not found: $ref"
      ;;
    *) die "unknown type: $type (expected local or we)" ;;
  esac

  local state
  state="$(read_state)"
  state=$(jq --arg m "$mon" --arg t "$type" --arg r "$ref" \
    '.[$m] = {type:$t, ref:$r}' <<< "$state")
  write_state "$state"
  apply_all
}

cmd_restore() {
  # Rebuild renderers from persisted state, dropping any entry whose monitor or
  # backing file/id no longer resolves. On a fresh install (empty state) seed
  # every connected monitor with the fallback image so the desktop is never
  # blank.
  local state kept mon type ref ws fb
  state="$(read_state)"
  ws="$(find_workshop_dir || true)"
  kept='{}'
  while IFS=$'\t' read -r mon type ref; do
    [[ -n "${mon:-}" ]] || continue
    if [[ "$type" == local && -f "$ref" ]]; then
      kept=$(jq --arg m "$mon" --arg t "$type" --arg r "$ref" \
        '.[$m]={type:$t, ref:$r}' <<< "$kept")
    elif [[ "$type" == we && -n "$ws" && -d "$ws/$ref" ]]; then
      kept=$(jq --arg m "$mon" --arg t "$type" --arg r "$ref" \
        '.[$m]={type:$t, ref:$r}' <<< "$kept")
    fi
  done < <(jq -r 'to_entries[] | [.key, .value.type, .value.ref] | @tsv' \
    <<< "$state" 2>/dev/null)

  if [[ "$(jq 'length' <<< "$kept")" == 0 ]]; then
    fb="$(pick_fallback)"
    if [[ -n "$fb" ]]; then
      while IFS= read -r mon; do
        [[ -n "$mon" ]] || continue
        kept=$(jq --arg m "$mon" --arg r "$fb" \
          '.[$m]={type:"local", ref:$r}' <<< "$kept")
      done < <(list_monitors)
    fi
  fi

  write_state "$kept"
  apply_all
}

# Deterministic image for a blank start: the seeded default wins, otherwise the
# alphabetically first image.
pick_fallback() {
  if [[ -f "$wallpaper_dir/default.png" ]]; then
    printf '%s\n' "$wallpaper_dir/default.png"
    return 0
  fi
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print 2>/dev/null | sort | head -n 1
}

cmd_stop() { stop_all; }

case "${1:-}" in
  list)    cmd_list ;;
  apply)   shift; cmd_apply "${1:-}" "${2:-}" "${3:-}" ;;
  restore) cmd_restore ;;
  stop)    cmd_stop ;;
  *)
    printf 'usage: %s {list|apply <monitor> <local|we> <ref>|restore|stop}\n' \
      "${0##*/}" >&2
    exit 2
    ;;
esac
