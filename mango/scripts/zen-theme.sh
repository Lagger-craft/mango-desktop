#!/usr/bin/env bash
set -euo pipefail

# Writes the Zen Browser userChrome.css from the current Material palette.
#
# The palette is the one matugen already produces for the shell
# (~/.local/state/mango/theme.json, written by mango/scripts/wallpaper-ctl.sh).
# This script is the second consumer of that single source: the browser UI
# therefore follows the wallpaper exactly like the panel does.
#
# It also links zen/user.js into the active profile so the custom-CSS pref and
# the privacy prefs are applied on every browser start.
#
# Usage:
#   zen-theme.sh          # regenerate from the current theme.json
#   zen-theme.sh --print  # only print the resolved CSS (no writes)

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
zen_dir="${ZEN_CONFIG_DIR:-$HOME/.config/zen}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mango"
theme_file="$state_dir/theme.json"
template="$repo_dir/zen/userChrome.css.template"
user_js="$repo_dir/zen/user.js"

# Chernobyl palette: the shell's built-in defaults. Used when no theme file
# exists yet, so the browser is never unstyled.
declare -A fallback=(
  [accent]="#9bd45a"          [accentBright]="#c8f08d"
  [accentDim]="#3d5233"       [accentBorder]="#599bd45a"
  [selectedBg]="#34432b"      [panelBg]="#b3171a17"
  [popoverBg]="#cc171a17"     [popupBg]="#f0171a17"
  [overlayBg]="#99141714"     [surface]="#171a17"
  [surfaceUp]="#1b1f1a"       [panel]="#222722"
  [panelTint]="#282d26"       [well]="#20241f"
  [deep]="#12150f"            [deeper]="#0c0e0c"
  [hover]="#2a3126"           [buttonBg]="#20231e"
  [buttonHoverBg]="#402d29"   [outline]="#4a5a41"
  [divider]="#485044"         [textPrimary]="#e5e8dc"
  [textSecondary]="#a5a99d"   [textIdle]="#c8d2c0"
  [textDim]="#5a6055"         [warning]="#e0a044"
  [critical]="#d94b43"        [criticalSoft]="#ec8064"
)

die() { printf 'zen-theme: %s\n' "$*" >&2; exit 1; }

# Resolve the profile directory. The name is dynamic (Zen hashes it), so:
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

# Material tokens from theme.json, falling back to the built-in palette for
# every token the file does not carry.
read_tokens() {
  local key value
  for key in "${!fallback[@]}"; do
    value=""
    if [[ -r "$theme_file" ]] && command -v jq >/dev/null 2>&1; then
      value=$(jq -r --arg k "$key" '.[$k] // empty' "$theme_file" 2>/dev/null || true)
    fi
    if [[ ! "$value" =~ ^#[0-9a-fA-F]{6,8}$ ]]; then
      value="${fallback[$key]}"
    fi
    printf -v "token_$key" '%s' "$value"
  done
}

render_css() {
  local template_text key varname value
  template_text=$(cat "$template")
  for key in "${!fallback[@]}"; do
    varname="token_$key"
    value=${!varname}
    template_text=${template_text//\{\{$key\}\}/$value}
  done
  printf '%s\n' "$template_text"
}

main() {
  local print_only=0 profile css target
  [[ "${1:-}" == "--print" ]] && print_only=1

  [[ -r "$template" ]] || die "template not found: $template"
  read_tokens
  css=$(render_css)

  if (( print_only )); then
    printf '%s\n' "$css"
    return 0
  fi

  profile=$(resolve_profile) || die "no Zen profile found under $zen_dir"
  mkdir -p -- "$profile/chrome"
  target="$profile/chrome/userChrome.css"

  # Atomic replace: Zen may be running and re-reads the file on save.
  local tmp
  tmp=$(mktemp "$profile/chrome/.userChrome.css.XXXXXX")
  trap 'rm -f -- "$tmp"' EXIT
  printf '%s\n' "$css" > "$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$target"
  trap - EXIT

  # user.js: pinned prefs (custom CSS + telemetry/privacy). Symlinked so the
  # repo stays the single source of truth.
  if [[ -r "$user_js" ]]; then
    if [[ -L "$profile/user.js" ]]; then
      ln -sfn -- "$user_js" "$profile/user.js"
    elif [[ ! -e "$profile/user.js" ]]; then
      ln -s -- "$user_js" "$profile/user.js"
    else
      printf 'zen-theme: %s/user.js exists and is not ours; left untouched\n' "$profile" >&2
    fi
  fi

  printf 'zen-theme: wrote %s (accent %s)\n' "$target" "${token_accent}"
}

main "$@"
