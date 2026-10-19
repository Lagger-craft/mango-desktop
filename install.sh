#!/usr/bin/env bash
# Auto-installer for the standalone MangoWM desktop profile.
#
# Installs missing dependencies (official repo via pacman, AUR via the first
# available yay/paru helper), links this repository's configs into place, and
# validates the result. Idempotent and non-destructive: it never overwrites an
# existing config path. Run with --dry-run to preview, --uninstall to reverse
# only what this script created.
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Shipped fallback background, seeded on first install so a fresh machine
# renders a desktop instead of a blank screen (see wallpaper-ctl.sh).
readonly DEFAULT_WALLPAPER="$REPO_DIR/mango/wallpapers/default.png"

# Official-repo packages used by this profile.
REPO_PKGS=(
  mangowm      # compositor
  quickshell   # top panel + wallpaper picker
  foot         # terminal (Super+Return)
  wofi         # launcher, clipboard and power menus
  cliphist     # bounded clipboard history
  wl-clipboard # wl-copy / wl-paste
  jq           # wallpaper-ctl JSON state and listing
  grim         # screenshots
  slurp        # region selection
  firefox      # default browser
  chromium     # fallback browser (Super+Shift+W)
  xdg-utils    # xdg-settings default-browser handling
  fastfetch    # system info in the terminal
)

# AUR-only packages: no official-repo package provides these.
AUR_PKGS=(mpvpaper linux-wallpaperengine-git)

DRY_RUN=0
MODE=install
SKIPPED=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [--uninstall] [-h|--help]

  (no flags)    Install missing dependencies and link configs into place.
  --dry-run     Print every action without changing anything.
  --uninstall   Remove only the symlinks this installer created; packages stay.
  -h, --help    Show this help.

Dependency policy: official packages via pacman, AUR packages via the first
available helper (yay or paru; override with AUR_HELPER=<helper>). The script
refuses to overwrite an existing config path.
EOF
}

note() { printf '  %s\n' "$*"; }
warn() { printf '  SKIP: %s\n' "$*" >&2; SKIPPED=$((SKIPPED + 1)); }
die()  { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

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
    --uninstall) MODE=uninstall ;;
    -h|--help)   usage; exit 0 ;;
    *)           usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

command -v pacman >/dev/null 2>&1 || die "pacman not found: this installer supports Arch Linux only."
[[ "$REPO_DIR" == "$HOME/mango-desktop" ]] ||
  die "clone location: Mango's config references \$HOME/mango-desktop, but this repository is at $REPO_DIR. Move or clone it to \$HOME/mango-desktop."

# True when the directory already holds at least one background image.
wallpapers_present() {
  [[ -n "$(find "$1" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -print -quit 2>/dev/null)" ]]
}

# Symlink src -> dest, refusing to touch anything that already exists there.
link_config() {
  local src=$1 dest=$2
  run mkdir -p "$(dirname -- "$dest")"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink -- "$dest")" == "$src" ]]; then
      note "ok: $dest already points to $src"
    else
      warn "$dest -> $(readlink -- "$dest") (points elsewhere; move it manually to switch)"
    fi
  elif [[ -e "$dest" ]]; then
    warn "$dest exists and is not a symlink (never overwritten; move it aside to switch)"
  else
    run ln -s -- "$src" "$dest"
    ((DRY_RUN)) || note "linked: $dest -> $src"
  fi
}

remove_link() {
  local dest=$1
  if [[ -L "$dest" ]] && [[ "$(readlink -- "$dest")" == "$REPO_DIR/"* ]]; then
    run rm -- "$dest"
    ((DRY_RUN)) || note "removed: $dest"
  elif [[ -e "$dest" ]]; then
    warn "$dest was not created by this installer; left untouched"
  else
    note "absent: $dest"
  fi
}

if [[ "$MODE" == uninstall ]]; then
  echo "Reversing installer-created links (packages and wallpaper state stay):"
  remove_link "$HOME/.config/mango"
  remove_link "$HOME/.config/vesktop"
  remove_link "$HOME/.config/fastfetch"
  remove_link "$HOME/.zshrc"
  echo "For the rest (wallpaper process, wallpaper state, XDG browser), see README > Rollback."
  exit 0
fi

echo "Checking dependencies (pacman for official packages, AUR helper for the rest):"

missing_repo=()
for pkg in "${REPO_PKGS[@]}"; do
  pacman -Q "$pkg" >/dev/null 2>&1 || missing_repo+=("$pkg")
done

if ((${#missing_repo[@]})); then
  note "missing from the official repo: ${missing_repo[*]}"
  run sudo pacman -S --needed "${missing_repo[@]}"
else
  note "all official-repo packages installed"
fi

missing_aur=()
for pkg in "${AUR_PKGS[@]}"; do
  pacman -Q "$pkg" >/dev/null 2>&1 || missing_aur+=("$pkg")
done

if ((${#missing_aur[@]})); then
  helper="${AUR_HELPER:-}"
  if [[ -z "$helper" ]]; then
    for candidate in yay paru; do
      if command -v "$candidate" >/dev/null 2>&1; then helper="$candidate"; break; fi
    done
  fi
  [[ -n "$helper" ]] && command -v "$helper" >/dev/null 2>&1 ||
    die "AUR packages required (${missing_aur[*]}) but neither yay nor paru is installed. Install one of them, then re-run, or set AUR_HELPER=<helper>."
  note "missing from the AUR: ${missing_aur[*]} (via $helper)"
  run "$helper" -S --needed --noconfirm "${missing_aur[@]}"
else
  note "all AUR packages installed"
fi

echo "Linking configuration (existing paths are never overwritten):"
link_config "$REPO_DIR/mango" "$HOME/.config/mango"
link_config "$REPO_DIR/vesktop" "$HOME/.config/vesktop"
link_config "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
link_config "$REPO_DIR/fastfetch" "$HOME/.config/fastfetch"

echo "Preparing user state:"
run mkdir -p "$HOME/Pictures/Wallpapers"

# Seed the shipped default only when the user has no background of their own;
# an existing image is never overwritten. Without at least one image,
# wallpaper-ctl.sh restore has nothing to fall back on and the desktop comes
# up blank with no diagnostic.
if wallpapers_present "$HOME/Pictures/Wallpapers"; then
  note "wallpapers already present; nothing seeded"
elif [[ -f "$DEFAULT_WALLPAPER" ]]; then
  run cp -- "$DEFAULT_WALLPAPER" "$HOME/Pictures/Wallpapers/default.png"
  ((DRY_RUN)) || note "seeded default wallpaper: $HOME/Pictures/Wallpapers/default.png"
else
  warn "shipped default wallpaper missing at $DEFAULT_WALLPAPER"
fi

if command -v xdg-settings >/dev/null 2>&1; then
  current_browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  if [[ -z "$current_browser" ]]; then
    run xdg-settings set default-web-browser firefox.desktop
    ((DRY_RUN)) || note "XDG default browser set to firefox.desktop"
  else
    note "XDG default browser kept: $current_browser"
  fi
fi

echo "Validating:"
if command -v mango >/dev/null 2>&1; then
  run mango -c "$HOME/.config/mango/config.conf" -p
  ((DRY_RUN)) || note "Mango config parses cleanly"
else
  warn "mango binary not available yet; config not parsed"
fi

if ((SKIPPED)); then
  echo "Done with $SKIPPED skipped step(s) (see SKIP lines above)."
else
  echo "Done."
fi
echo "Start the profile with: mango -c \$HOME/.config/mango/config.conf"
