#!/usr/bin/env bash
# Expire cliphist history entries and the live clipboard selection after 72
# hours without reuse. Re-copying an item, or picking it again from the Super+V
# menu, restarts that item's clock; a plain Ctrl+V paste cannot be observed on
# Wayland and does not restart it.
#
# Modes:
#   --stamp  record the newest history entry and the selection as just changed
#            (run by the watcher right after cliphist stores a new item)
#   --touch  record only a selection change (an emptied clipboard)
#   default  delete entries older than 72 hours and clear an expired live
#            clipboard; also run before the picker lists history and from the
#            clipboard-expire.timer
set -euo pipefail

umask 077
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist"
stamps="$cache_dir/mango-expiry"
lock="$cache_dir/.mango-expiry.lock"
max_age=$((72 * 60 * 60))
mkdir -p -- "$cache_dir"

now=$(date +%s)

# The watcher, the picker and the timer all update the same stamp file: one
# writer at a time, and a wedged holder must not stall clipboard collection.
exec 9> "$lock"
flock -w 5 9 || exit 0

declare -A stamp=()
load_stamps() {
  [[ -f $stamps ]] || return 0
  local key value
  while IFS=$'\t' read -r key value; do
    [[ -n ${key:-} && ${value:-} =~ ^[0-9]+$ ]] || continue
    stamp[$key]=$value
  done < "$stamps"
}

stamps_tmp=""
cleanup() {
  if [[ -n ${stamps_tmp:-} ]]; then rm -f -- "$stamps_tmp"; fi
}
trap cleanup EXIT

write_stamps() {
  local key
  stamps_tmp=$(mktemp "$cache_dir/.mango-expiry.XXXXXXXX")
  for key in "${!stamp[@]}"; do
    printf '%s\t%s\n' "$key" "${stamp[$key]}"
  done | sort > "$stamps_tmp"
  mv -f -- "$stamps_tmp" "$stamps"
  stamps_tmp=""
}

if [[ ${1:-} == --stamp ]]; then
  load_stamps
  list=$(cliphist list 2>/dev/null || true)
  top=${list%%$'\n'*}
  top_id=${top%%$'\t'*}
  [[ -n $top_id ]] || exit 0
  stamp[$top_id]=$now
  stamp[last]=$now
  write_stamps
  exit 0
fi

if [[ ${1:-} == --touch ]]; then
  load_stamps
  stamp[last]=$now
  write_stamps
  exit 0
fi

# Prune pass: reload, drop what ran out of time, forget orphaned stamps.
load_stamps
last="${stamp[last]:-}"
list=""
list_ok=0
if list=$(cliphist list 2>/dev/null); then list_ok=1; fi

if (( list_ok )); then
  top_id=""
  if [[ -n $list ]]; then
    top=${list%%$'\n'*}
    top_id=${top%%$'\t'*}
  fi
  expired=""
  declare -A seen=()
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    id=${line%%$'\t'*}
    seen[$id]=1
    age="${stamp[$id]:-}"
    if [[ -z $age ]]; then
      # Entries stored before this feature existed have no recorded copy time.
      # The newest one is the current selection, whose age is known from the
      # last selection change; every other entry starts counting now.
      if [[ -n $last && $id == "$top_id" ]]; then
        age=$last
      else
        age=$now
      fi
    fi
    if (( now - age > max_age )); then
      expired+="$line"$'\n'
      unset "stamp[$id]"
    else
      stamp[$id]=$age
    fi
  done <<< "$list"
  # Forget stamps whose history entry is gone (dedupe, cap eviction, wipe).
  for key in "${!stamp[@]}"; do
    if [[ $key == last ]]; then continue; fi
    if [[ -z ${seen[$key]:-} ]]; then unset "stamp[$key]"; fi
  done
  if [[ -n $expired ]]; then
    printf '%s' "$expired" | cliphist delete
  fi
fi

# The live selection keeps its own clock; when it runs out, empty the clipboard
# so nothing stale stays available to paste. The clear restarts that clock, so
# an already-empty clipboard is not cleared again on every pass.
if [[ -n ${stamp[last]:-} ]] && (( now - stamp[last] > max_age )); then
  if wl-copy --clear; then
    stamp[last]=$now
  fi
fi

write_stamps
