#!/usr/bin/env bash
# Full rollback for the standalone MangoWM desktop profile.
#
# Reverses everything install.sh creates — stops the quickshell panel and the
# wallpaper renderers, disables the systemd user timers, removes the
# installer's symlinks (by delegating to ./install.sh --uninstall), deletes
# ~/.local/state/mango and the seeded default wallpaper when still unmodified
# — and additionally removes every package the installer installs (pacman
# -Rns keeps its own confirmation prompt). Run with --dry-run to preview.
#
# Never touches Niri or ~/.config/quickshell, wallpapers of your own, or this
# repository. Spec: odd/tasks/profile-uninstall.md
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Shipped default background, used to tell the installer-seeded copy apart
# from a wallpaper the user chose (byte-identical = still the seed).
readonly DEFAULT_WALLPAPER="$REPO_DIR/mango/wallpapers/default.png"

# Keep these two lists in sync with install.sh: tests/verify-uninstall.sh
# diffs the removed set against install.sh's arrays, so drift fails the probe.
REPO_PKGS=(
  mangowm      # compositor
  quickshell   # top panel + wallpaper picker
  foot         # terminal (Super+Return)
  wofi         # launcher, clipboard and power menus
  cliphist     # bounded clipboard history
  wl-clipboard # wl-copy / wl-paste
  jq           # wallpaper-ctl JSON state and listing
  matugen      # Material-You palette from the applied wallpaper
  grim         # screenshots
  slurp        # region selection
  nftables     # host firewall ruleset (see nftables/nftables.conf)
  firefox      # default browser
  chromium     # fallback browser (Super+Shift+W)
  xdg-utils    # xdg-settings default-browser handling
  fastfetch    # system info in the terminal
  mangohud     # in-game performance overlay
)

# AUR-only packages: no official-repo package provides these.
AUR_PKGS=(mpvpaper linux-wallpaperengine-git)

DRY_RUN=0
SKIPPED=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [--dry-run] [-h|--help]

  (no flags)    Reverse everything install.sh created and remove its packages.
  --dry-run     Print every action without changing anything.
  -h, --help    Show this help.

Removes: the running panel and wallpaper renderers, the screenshot-cleanup
and clipboard-expire timers, the installer's symlinks (via ./install.sh
--uninstall), ~/.local/state/mango, the seeded default wallpaper when it is
still the unmodified shipped copy, and every package install.sh installs
(pacman -Rns asks for confirmation; nothing is forced).

Never touches: Niri, ~/.config/quickshell, wallpapers of your own, config
paths the installer did not create, and this repository.
EOF
}

note() { printf '  %s\n' "$*"; }
warn() { printf '  warning: %s\n' "$*" >&2; SKIPPED=$((SKIPPED + 1)); }
die()  { printf 'uninstall.sh: %s\n' "$*" >&2; exit 1; }

run() {
  if ((DRY_RUN)); then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

while (($#)); do
  case "$1" in
    --dry-run)   DRY_RUN=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)           usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

command -v pacman >/dev/null 2>&1 || die "pacman not found: this uninstaller supports Arch Linux only."
[[ "$REPO_DIR" == "$HOME/mango-desktop" ]] ||
  die "profile location: expected this repository at \$HOME/mango-desktop, but it is at $REPO_DIR."

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/mango"
wallpapers_dir="$HOME/Pictures/Wallpapers"

echo "Stopping runtime pieces (panel and wallpaper renderers):"

# The panel is matched on the fixed $HOME/mango-desktop path, never on
# $REPO_DIR: any other quickshell instance (or this repo at another path) is
# left alone. pkill exits 1 when nothing matches.
run pkill -f "$HOME/mango-desktop/quickshell/shell.qml" || true
((DRY_RUN)) || note "panel stopped (if it was running)"

if [[ -x "$REPO_DIR/mango/scripts/wallpaper-ctl.sh" ]]; then
  if ((DRY_RUN)); then
    printf '  [dry-run] %s\n' "$REPO_DIR/mango/scripts/wallpaper-ctl.sh stop"
  elif "$REPO_DIR/mango/scripts/wallpaper-ctl.sh" stop; then
    note "wallpaper renderers stopped"
  else
    warn "wallpaper-ctl.sh stop failed; check for leftover mpvpaper/linux-wallpaperengine processes"
  fi
fi

echo "Disabling systemd user timers (before their unit links are removed):"
if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user disable --now screenshot-cleanup.timer clipboard-expire.timer
else
  note "systemctl not available; skipping timer disable"
fi

echo "Removing installer-created links (delegating to install.sh --uninstall):"
if ((DRY_RUN)); then
  "$REPO_DIR/install.sh" --dry-run --uninstall
else
  "$REPO_DIR/install.sh" --uninstall
fi

if command -v systemctl >/dev/null 2>&1; then
  run systemctl --user daemon-reload
fi

echo "Removing profile state ($state_dir):"
if [[ -d "$state_dir" ]]; then
  run rm -rf -- "$state_dir"
  ((DRY_RUN)) || note "removed: $state_dir (wallpaper choices and theme palette forgotten)"
else
  note "absent: $state_dir"
fi

echo "Removing the seeded default wallpaper (only while it is the shipped copy):"
if [[ -f "$wallpapers_dir/default.png" ]]; then
  if [[ -f "$DEFAULT_WALLPAPER" ]] && cmp -s -- "$DEFAULT_WALLPAPER" "$wallpapers_dir/default.png"; then
    run rm -- "$wallpapers_dir/default.png"
    ((DRY_RUN)) || note "removed: $wallpapers_dir/default.png (identical to the shipped seed)"
  else
    note "kept: $wallpapers_dir/default.png (modified or no longer the shipped seed)"
  fi
else
  note "absent: $wallpapers_dir/default.png"
fi
# The installer created ~/Pictures/Wallpapers; give it back only when empty.
if [[ -d "$wallpapers_dir" ]] &&
  [[ -z "$(find "$wallpapers_dir" -mindepth 1 -print -quit)" ]]; then
  run rmdir -- "$wallpapers_dir"
  ((DRY_RUN)) || note "removed empty directory: $wallpapers_dir"
fi

echo "Removing packages (pacman -Rns asks for confirmation):"
installed=()
for pkg in "${REPO_PKGS[@]}" "${AUR_PKGS[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    installed+=("$pkg")
  fi
done

if ((${#installed[@]})); then
  note "installed profile packages: ${installed[*]}"
  run sudo pacman -Rns "${installed[@]}"
  if command -v xdg-settings >/dev/null 2>&1 &&
    [[ "$(xdg-settings get default-web-browser 2>/dev/null)" == firefox.desktop ]]; then
    note "XDG default browser is firefox.desktop; pick a new one with xdg-settings set default-web-browser <desktop-file>"
  fi
else
  note "none of the profile's packages are installed"
fi

cat <<EOF

Rollback complete. Leftovers this script deliberately does not touch:
  - Zen browser privacy prefs (the installer applies them without backup):
    reset them from about:config if you want stock Zen back
  - the "mango" theme inside Vesktop's Vencord
  - /etc/nftables.conf and the nftables service, if you enabled them
    (see README > Firewall)
  - this repository at $REPO_DIR (delete it manually if wanted)
  - Niri and ~/.config/quickshell are never touched
EOF

if ((SKIPPED)); then
  echo "Done with $SKIPPED warning(s) (see above)."
else
  echo "Done."
fi
