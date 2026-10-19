#!/usr/bin/env bash
set -euo pipefail

# Installs the "mango" theme (the shell palette) into Vesktop and enables it.
#
# Vesktop has no theming of its own: Discord's desktop app is restyled through
# Vencord, whose theme files live in <data>/themes and are listed in
# <data>/settings/settings.json ("enabledThemes"). This script finds Vencord's
# data directory, copies the theme in and enables it.
#
# Usage:
#   vesktop-theme.sh              # install + enable
#   vesktop-theme.sh --check      # only report what would happen

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
theme_source="$repo_dir/vesktop/themes/mango.theme.css"
theme_name="mango.theme.css"

die() { printf 'vesktop-theme: %s\n' "$*" >&2; exit 1; }

# Candidate Vencord data directories, in order of likelihood.
candidates=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/vesktop/VencordData"
  "${XDG_CONFIG_HOME:-$HOME/.config}/VencordData"
  "${XDG_CONFIG_HOME:-$HOME/.config}/vesktop/Vencord"
  "${XDG_CONFIG_HOME:-$HOME/.config}/Vencord"
  "${XDG_CONFIG_HOME:-$HOME/.config}/vesktop"
)

# The directory that actually holds Vencord's settings store.
resolve_data_dir() {
  local dir
  for dir in "${candidates[@]}"; do
    if [[ -f "$dir/settings/settings.json" ]] || [[ -d "$dir/themes" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  return 1
}

main() {
  local mode="${1:-install}" data_dir themes_dir settings_file

  [[ -r "$theme_source" ]] || die "missing theme source: $theme_source"

  if ! data_dir=$(resolve_data_dir); then
    die "Vencord's data directory was not found.
     Vesktop only themes Discord through Vencord, and in this install Vencord
     is present but not running (it has never created its data directory).
     Enable it once: Vesktop -> Settings -> Vencord -> Install (or Reinstall),
     then run this script again."
  fi

  themes_dir="$data_dir/themes"
  settings_file="$data_dir/settings/settings.json"

  printf 'vesktop-theme: Vencord data dir: %s\n' "$data_dir"

  if [[ "$mode" == "--check" ]]; then
    [[ -d "$themes_dir" ]] && printf 'themes dir: %s\n' "$themes_dir"
    [[ -f "$settings_file" ]] && printf 'settings: %s\n' "$settings_file"
    return 0
  fi

  mkdir -p -- "$themes_dir" "$data_dir/settings"
  if [[ "$(readlink -f -- "$theme_source")" != "$(readlink -f -- "$themes_dir/$theme_name" 2>/dev/null || echo missing)" ]]; then
    cp -- "$theme_source" "$themes_dir/$theme_name"
  else
    printf 'vesktop-theme: theme file already in place (%s)\n' "$themes_dir/$theme_name"
  fi

  # Enable the theme (and only it) in Vencord's settings store.
  if [[ -f "$settings_file" ]]; then
    python3 - "$settings_file" "$theme_name" <<'PY'
import json, sys
path, theme = sys.argv[1], sys.argv[2]
with open(path) as fh:
    data = json.load(fh)
themes = [t for t in data.get("enabledThemes", []) if t != theme]
data["enabledThemes"] = [theme] + themes
data["useQuickCss"] = True
with open(path, "w") as fh:
    json.dump(data, fh, indent=4)
print(f"vesktop-theme: enabledThemes = {data['enabledThemes']}")
PY
  else
    printf '{"enabledThemes": ["%s"], "useQuickCss": true}\n' "$theme_name" > "$settings_file"
    printf 'vesktop-theme: created %s\n' "$settings_file"
  fi

  printf 'vesktop-theme: installed %s\n' "Restart Vesktop to apply it."
}

main "$@"
