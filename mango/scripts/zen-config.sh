#!/usr/bin/env bash
set -euo pipefail

# Applies the privacy/security configuration to the Zen Browser profile.
#
# Why not user.js: Firefox only reads user.js when it is NEWER than prefs.js,
# and prefs.js is rewritten on every browser shutdown — so user.js silently
# stops applying. The prefs are therefore written straight into prefs.js.
#
# The browser rewrites prefs.js from memory when it exits, so this must run
# with Zen CLOSED. When Zen is running the script refuses to touch anything
# and prints the command to run afterwards.
#
# Usage:
#   zen-config.sh            # apply the prefs to the active profile
#   zen-config.sh --print    # only show the prefs that would be applied
#   zen-config.sh --check    # report which prefs are missing/outdated

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
zen_dir="${ZEN_CONFIG_DIR:-$HOME/.config/zen}"
prefs_source="$repo_dir/zen/user.js"

die() { printf 'zen-config: %s\n' "$*" >&2; exit 1; }

# Resolve the profile directory (the name is dynamic):
#   1. profiles.ini default install path, when it holds a prefs.js
#   2. the profile with the most recently written prefs.js
resolve_profile() {
  local ini="$zen_dir/profiles.ini" path best="" best_time=0 dir time
  [[ -r "$ini" ]] || return 1
  path=$(awk -F= '
    /^\[Install/ { in_install = 1; next }
    /^\[/ { in_install = 0 }
    in_install && /^Default=/ { print substr($0, index($0, "=") + 1); exit }
  ' "$ini")
  if [[ -n "$path" && -f "$zen_dir/$path/prefs.js" ]]; then
    printf '%s\n' "$zen_dir/$path"
    return 0
  fi
  for dir in "$zen_dir"/*/; do
    [[ -f "$dir/prefs.js" ]] || continue
    time=$(stat -c %Y "$dir/prefs.js")
    if (( time > best_time )); then
      best_time=$time
      best="${dir%/}"
    fi
  done
  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

# Is this profile in use? A profile is in use when its .parentlock exists (the
# browser creates it on start and removes it on a clean exit) or when a running
# zen-bin was started with it explicitly.
profile_in_use() {
  local profile="$1" pid cmd
  [[ -e "$profile/.parentlock" ]] && return 0
  for pid in $(pgrep -x zen-bin 2>/dev/null || true); do
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
    [[ "$cmd" == *"-contentproc"* ]] && continue
    [[ "$cmd" == *"$profile"* ]] && return 0
  done
  return 1
}

# The prefs we manage, taken verbatim from zen/user.js.
read_prefs() {
  grep -E '^user_pref\(' "$prefs_source" | sed 's/;[[:space:]]*$//'
}

# Compare one pref in prefs.js with the wanted line.
current_value() {
  local key="$1" file="$2"
  grep -E "^user_pref\(\"$key\"," "$file" 2>/dev/null | head -1 | sed 's/;[[:space:]]*$//' || true
}

main() {
  local mode="${1:-apply}" profile prefs_file wanted key current missing=0 changed=0

  [[ -r "$prefs_source" ]] || die "missing $prefs_source"

  if [[ "$mode" == "--print" ]]; then
    read_prefs
    return 0
  fi

  profile=$(resolve_profile) || die "no Zen profile found under $zen_dir"
  prefs_file="$profile/prefs.js"

  if [[ "$mode" != "--check" ]] && profile_in_use "$profile"; then
    die "the Zen profile is in use ($profile). Close Zen and run this again:
     the browser rewrites prefs.js when it exits and would drop the changes."
  fi

  while IFS= read -r wanted; do
    [[ -n "$wanted" ]] || continue
    key=$(printf '%s' "$wanted" | sed -E 's/^user_pref\("([^"]+)".*/\1/')
    current=$(current_value "$key" "$prefs_file")
    if [[ -z "$current" ]]; then
      missing=$((missing + 1))
    elif [[ "$current" != "$wanted" ]]; then
      changed=$((changed + 1))
    fi
    [[ "$mode" == "--check" ]] && printf '%-70s %s\n' "$key" "${current:-<missing>}"
  done < <(read_prefs)

  if [[ "$mode" == "--check" ]]; then
    printf '\n%s missing, %s with a different value\n' "$missing" "$changed"
    return 0
  fi

  if (( missing == 0 && changed == 0 )); then
    printf 'zen-config: %s is already up to date\n' "$prefs_file"
    return 0
  fi

  # Rewrite prefs.js: replace the lines we manage, append the missing ones.
  local tmp
  tmp=$(mktemp "$profile/.prefs.js.XXXXXX")
  trap 'rm -f -- "$tmp"' EXIT
  cp -- "$prefs_file" "$tmp"

  while IFS= read -r wanted; do
    [[ -n "$wanted" ]] || continue
    key=$(printf '%s' "$wanted" | sed -E 's/^user_pref\("([^"]+)".*/\1/')
    if grep -qE "^user_pref\(\"$key\"," "$tmp"; then
      # Replace the existing line, keeping the file's own ordering.
      awk -v key="$key" -v line="$wanted" '
        index($0, "user_pref(\"" key "\",") == 1 { print line; next }
        { print }
      ' "$tmp" > "$tmp.new" && mv -f -- "$tmp.new" "$tmp"
    else
      printf '%s\n' "$wanted" >> "$tmp"
    fi
  done < <(read_prefs)

  chmod 600 -- "$tmp"
  mv -f -- "$tmp" "$prefs_file"
  trap - EXIT

  printf 'zen-config: applied %s pref(s) to %s\n' "$((missing + changed))" "$prefs_file"
}

main "$@"
