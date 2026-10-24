#!/usr/bin/env bash
# Regression probes for odd/tasks/clipboard-expiry.md
#
# Run: bash tests/verify-clipboard-expiry.sh
# Each function covers one spec item. Everything runs against scratch
# directories with fake clipboard content: HOME is redirected so the scripts
# resolve their fixed paths inside this copy of the repository, XDG_CACHE_HOME
# points at a scratch cache so the real cliphist database is never touched, and
# wl-copy/wofi shims keep the probe away from the real clipboard and the real
# menu.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mkdir -p -- "$T/home" "$T/cache" "$T/bin"
ln -s "$REPO" "$T/home/mango-desktop"
export HOME="$T/home"
export XDG_CACHE_HOME="$T/cache"

# Safety: the redirected HOME carries no cliphist config, so cliphist resolves
# its database from XDG_CACHE_HOME and the real database stays untouched.
[[ ! -e $HOME/.config/cliphist/config ]] ||
  fail "safety: unexpected cliphist config in the redirected HOME"

# Fake wl-copy records its arguments instead of touching the real clipboard.
export WL_COPY_LOG="$T/wl-copy.log"
: > "$WL_COPY_LOG"
cat > "$T/bin/wl-copy" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$WL_COPY_LOG"
SH
chmod +x "$T/bin/wl-copy"

# Fake wofi captures the list the picker would display, then cancels.
export WOPI_CAPTURE="$T/wofi-capture"
cat > "$T/bin/wofi" <<'SH'
#!/usr/bin/env bash
cat > "$WOPI_CAPTURE"
exit 1
SH
chmod +x "$T/bin/wofi"
export PATH="$T/bin:$PATH"

expire="$REPO/mango/scripts/clipboard-expire.sh"
menu="$REPO/mango/scripts/clipboard-menu.sh"
stamps_file="$XDG_CACHE_HOME/cliphist/mango-expiry"

reset_history() {
  rm -f -- "$XDG_CACHE_HOME/cliphist/db" "$stamps_file"
  : > "$WL_COPY_LOG"
  rm -f -- "$WOPI_CAPTURE"
}

# Store fake content and stamp it exactly like the watcher does.
store() {
  printf '%s' "$1" | cliphist store
  [[ -f $XDG_CACHE_HOME/cliphist/db ]] ||
    fail "safety: cliphist is not writing to the scratch database"
  "$expire" --stamp
}

newest_id() {
  local list
  list=$(cliphist list)
  list=${list%%$'\n'*}
  printf '%s\n' "${list%%$'\t'*}"
}

stamp_value() { # stamp file key -> value (empty when absent)
  local key="$1"
  [[ -f $stamps_file ]] || return 0
  awk -F'\t' -v k="$key" '$1 == k { print $2 }' "$stamps_file"
}

set_stamp() { # key value — insert or replace one stamp line
  local key="$1" value="$2" tmp="$stamps_file.tmp.$$"
  if [[ -f $stamps_file ]]; then
    awk -F'\t' -v k="$key" -v v="$value" -v OFS='\t' \
      '$1 == k { print k, v; found = 1; next } { print } END { if (!found) print k, v }' \
      "$stamps_file" > "$tmp"
  else
    printf '%s\t%s\n' "$key" "$value" > "$tmp"
  fi
  mv -f -- "$tmp" "$stamps_file"
}

# S1: entries older than 72 hours are deleted; fresh and unstamped entries
# survive; a fresh selection clock never clears the clipboard.
test_expiry() {
  reset_history
  store 'old-item'
  store 'mid-item'
  store 'new-item'
  local now out
  now=$(date +%s)
  # cliphist list is newest first: ids[0]=new, ids[1]=mid, ids[2]=old.
  local -a ids=()
  mapfile -t ids < <(cliphist list | cut -f1)
  set_stamp "${ids[2]}" $((now - 262800)) # 73 h
  set_stamp "${ids[1]}" $((now - 3600))   # 1 h
  set_stamp last "$now"

  "$expire"

  out=$(cliphist list)
  grep -q 'new-item' <<<"$out" || fail "S1: fresh entry deleted"
  grep -q 'mid-item' <<<"$out" || fail "S1: 1h-old entry deleted"
  if grep -q 'old-item' <<<"$out"; then fail "S1: 73h-old entry survived"; fi
  [[ -z $(stamp_value "${ids[2]}") ]] || fail "S1: expired stamp kept"
  [[ -n $(stamp_value "${ids[1]}") ]] || fail "S1: fresh stamp dropped"
  [[ -n $(stamp_value "${ids[0]}") ]] || fail "S1: newest entry not stamped"
  if [[ -s $WL_COPY_LOG ]]; then
    fail "S1: clipboard cleared although the selection is fresh"
  fi
}

# S1: the boundary is exact — 72 hours survives, 72 hours plus a second goes.
test_boundary() {
  reset_history
  store 'boundary-item'
  local now id out
  now=$(date +%s)
  id=$(newest_id)
  set_stamp last "$now"

  set_stamp "$id" $((now - 259200)) # exactly 72 h
  "$expire"
  out=$(cliphist list)
  grep -q 'boundary-item' <<<"$out" || fail "S1: entry exactly 72h old was deleted"

  set_stamp "$id" $((now - 259201)) # 72 h plus one second
  "$expire"
  out=$(cliphist list)
  if grep -q 'boundary-item' <<<"$out"; then
    fail "S1: entry older than 72h survived"
  fi
}

# S2: re-copying the same content restarts its 72-hour clock.
test_recopy_resets_clock() {
  reset_history
  store 'reusable-item'
  local now out
  now=$(date +%s)
  set_stamp "$(newest_id)" $((now - 262800))
  set_stamp last $((now - 262800))

  "$expire"
  out=$(cliphist list)
  if grep -q 'reusable-item' <<<"$out"; then
    fail "S2: aged entry should be deleted first"
  fi

  # Re-copy the same content: what Ctrl+C in the source app does, and what the
  # picker's wl-copy does when the item is selected again. The watcher stores
  # it again and stamps the fresh entry.
  store 'reusable-item'
  "$expire"
  out=$(cliphist list)
  grep -q 'reusable-item' <<<"$out" || fail "S2: re-copied entry expired again"
}

# S3: an expired selection clears the clipboard exactly once and its clock
# restarts after the clear.
test_live_clipboard_clear() {
  reset_history
  store 'doomed-item'
  local now out
  now=$(date +%s)
  set_stamp "$(newest_id)" $((now - 262800))
  set_stamp last $((now - 262800))

  "$expire"
  out=$(cliphist list)
  if grep -q 'doomed-item' <<<"$out"; then fail "S3: expired entry survived"; fi
  [[ $(cat "$WL_COPY_LOG") == '--clear' ]] ||
    fail "S3: clipboard not cleared exactly once"
  local last_now
  last_now=$(stamp_value last)
  (( now - last_now <= 5 )) || fail "S3: selection clock not restarted after clear"

  # A second pass must not clear again: the clock restarted with the clear.
  "$expire"
  [[ $(wc -l < "$WL_COPY_LOG") -eq 1 ]] ||
    fail "S3: clipboard cleared more than once"
}

# S6: --touch refreshes only the selection clock (empty-clipboard events).
test_touch() {
  reset_history
  store 'kept-item'
  local now out last_now
  now=$(date +%s)
  set_stamp last $((now - 262800))

  "$expire" --touch

  last_now=$(stamp_value last)
  (( now - last_now <= 5 )) || fail "touch: selection clock not refreshed"
  out=$(cliphist list)
  grep -q 'kept-item' <<<"$out" || fail "touch: history entry lost"
}

# S5/S2: the watcher still stores bounded input, skips empty input, and stamps
# what it stores (the clock source for reuse detection).
test_watcher_behavior() {
  reset_history
  printf 'watched-item' | "$menu" --watch
  local now out id last_now
  out=$(cliphist list)
  grep -q 'watched-item' <<<"$out" || fail "S5: watcher did not store content"
  id=$(newest_id)
  [[ -n $(stamp_value "$id") ]] || fail "S2: stored entry not stamped"
  last_now=$(stamp_value last)
  now=$(date +%s)
  (( now - last_now <= 5 )) || fail "S2: selection clock not stamped"

  # An emptied clipboard stores nothing but refreshes the clock.
  set_stamp last $((now - 262800))
  printf '' | "$menu" --watch
  out=$(cliphist list)
  [[ $(grep -c . <<<"$out") -eq 1 ]] || fail "S5: empty input changed the history"
  now=$(date +%s)
  last_now=$(stamp_value last)
  (( now - last_now <= 5 )) || fail "S2: empty selection did not refresh the clock"

  # Items above the 1 MiB cap are still rejected before storage.
  head -c 1048577 /dev/zero | "$menu" --watch
  out=$(cliphist list)
  [[ $(grep -c . <<<"$out") -eq 1 ]] ||
    fail "S5: oversized input reached the history"
}

# S1/S5: the picker prunes before listing, and a canceled picker still exits
# without writing to the clipboard.
test_picker_hides_expired() {
  if pgrep -f 'wofi --dmenu.*Clipboard history' >/dev/null; then
    echo 'SKIP: test_picker_hides_expired (a real picker is open)'
    return 0
  fi
  reset_history
  store 'expired-item'
  store 'shown-item'
  local now out
  now=$(date +%s)
  local -a ids=()
  mapfile -t ids < <(cliphist list | cut -f1)
  set_stamp "${ids[1]}" $((now - 262800)) # the older entry
  set_stamp "${ids[0]}" "$now"
  set_stamp last "$now"

  "$menu"

  out=$(cat "$WOPI_CAPTURE")
  grep -q 'shown-item' <<<"$out" || fail "S5: fresh entry missing from the picker"
  if grep -q 'expired-item' <<<"$out"; then
    fail "S1: expired entry offered by the picker"
  fi
  if [[ -s $WL_COPY_LOG ]]; then
    fail "S5: canceled picker wrote to the clipboard"
  fi
}

test_expiry
test_boundary
test_recopy_resets_clock
test_live_clipboard_clear
test_touch
test_watcher_behavior
test_picker_hides_expired
printf 'all probes pass\n'
