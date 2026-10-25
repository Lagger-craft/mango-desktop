#!/usr/bin/env bash
# Regression probes for odd/tasks/profile-uninstall.md
#
# Run: bash tests/verify-uninstall.sh
# Each function covers one spec item. Everything runs against scratch
# directories: HOME is redirected so uninstall.sh resolves its fixed
# $HOME/mango-desktop path inside this copy of the repository, and
# systemctl/pacman/sudo/xdg-settings/pkill shims record their arguments
# instead of touching the real system, packages or processes.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Package names exactly as install.sh declares them (source of truth for S6):
# REPO_PKGS is a multi-line array with trailing comments, AUR_PKGS one line.
install_pkgs() {
  sed -n '/^REPO_PKGS=(/,/^)/p; /^AUR_PKGS=(/p' "$REPO/install.sh" |
    tr '()' '  ' | sed 's/#.*//' | tr -s ' \t' '\n' |
    grep -E '^[a-z0-9]' | sort -u
}

# Fresh scratch HOME per test: symlinked repo, shims on PATH, empty logs.
new_scratch() {
  S="$T/$1"
  mkdir -p -- "$S/home" "$S/bin" "$S/log"
  ln -s "$REPO" "$S/home/mango-desktop"
  export HOME="$S/home"
  export SHIM_LOG="$S/log"
  export PACMAN_INSTALLED="$S/log/pacman-installed"
  : > "$PACMAN_INSTALLED"

  cat > "$S/bin/systemctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SHIM_LOG/systemctl.log"
SH

  cat > "$S/bin/pacman" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SHIM_LOG/pacman.log"
if [[ ${1:-} == -Q ]]; then
  grep -qx "$2" "$PACMAN_INSTALLED"
  exit $?
fi
SH

  cat > "$S/bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH

  cat > "$S/bin/xdg-settings" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-} ${2:-}" == "get default-web-browser" ]]; then
  printf 'firefox.desktop\n'
fi
SH

  cat > "$S/bin/pkill" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SHIM_LOG/pkill.log"
SH

  chmod +x "$S/bin/"*
  export PATH="$S/bin:$PATH"
}

# The nine links install.sh creates, pointing through the scratch
# $HOME/mango-desktop symlink exactly like a real install.
make_links() {
  mkdir -p -- "$HOME/.config/MangoHud" "$HOME/.config/systemd/user"
  ln -s "$HOME/mango-desktop/mango" "$HOME/.config/mango"
  ln -s "$HOME/mango-desktop/vesktop" "$HOME/.config/vesktop"
  ln -s "$HOME/mango-desktop/zsh/.zshrc" "$HOME/.zshrc"
  ln -s "$HOME/mango-desktop/fastfetch" "$HOME/.config/fastfetch"
  ln -s "$HOME/mango-desktop/mango/mangohud/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
  local u
  for u in screenshot-cleanup.service screenshot-cleanup.timer \
           clipboard-expire.service clipboard-expire.timer; do
    ln -s "$HOME/mango-desktop/systemd/$u" "$HOME/.config/systemd/user/$u"
  done
}

make_state() {
  mkdir -p -- "$HOME/.local/state/mango/wallpaper-pids" "$HOME/.local/state/other-app"
  printf '{}' > "$HOME/.local/state/mango/wallpapers.json"
  printf '{}' > "$HOME/.local/state/mango/theme.json"
  printf '99999\n' > "$HOME/.local/state/mango/wallpaper-pids/mpv-HDMI-A-1.pid"
  printf 'log\n' > "$HOME/.local/state/mango/renderer.log"
  printf 'keep me\n' > "$HOME/.local/state/other-app/state"
}

# $1 = seed mode: identical | modified | none
make_wallpapers() {
  mkdir -p -- "$HOME/Pictures/Wallpapers"
  case "$1" in
    identical) cp -- "$REPO/mango/wallpapers/default.png" "$HOME/Pictures/Wallpapers/default.png" ;;
    modified)
      cp -- "$REPO/mango/wallpapers/default.png" "$HOME/Pictures/Wallpapers/default.png"
      printf 'user edit\n' >> "$HOME/Pictures/Wallpapers/default.png"
      ;;
    none) ;;
  esac
  printf 'mine\n' > "$HOME/Pictures/Wallpapers/other.png"
}

run_uninstall() { "$HOME/mango-desktop/uninstall.sh" "$@"; }

link_paths() {
  printf '%s\n' \
    "$HOME/.config/mango" "$HOME/.config/vesktop" "$HOME/.zshrc" \
    "$HOME/.config/fastfetch" "$HOME/.config/MangoHud/MangoHud.conf" \
    "$HOME/.config/systemd/user/screenshot-cleanup.service" \
    "$HOME/.config/systemd/user/screenshot-cleanup.timer" \
    "$HOME/.config/systemd/user/clipboard-expire.service" \
    "$HOME/.config/systemd/user/clipboard-expire.timer"
}

assert_links_gone() {
  local p
  while IFS= read -r p; do
    [[ ! -L $p && ! -e $p ]] || fail "link still present: $p"
  done < <(link_paths)
}

assert_links_present() {
  local p
  while IFS= read -r p; do
    [[ -L $p ]] || fail "link missing: $p"
  done < <(link_paths)
}

# S1: every installer-created link is removed by delegating to
# ./install.sh --uninstall.
test_links_removed() {
  new_scratch links
  make_links
  run_uninstall </dev/null || fail "S1: uninstall.sh failed"
  assert_links_gone
}

# S2: both timers are disabled --now before anything else, and a
# daemon-reload follows the link removal.
test_timers_disabled() {
  new_scratch timers
  make_links
  run_uninstall </dev/null || fail "S2: uninstall.sh failed"
  [[ -f $SHIM_LOG/systemctl.log ]] || fail "S2: systemctl never called"
  grep -qx -- '--user disable --now screenshot-cleanup.timer clipboard-expire.timer' \
    "$SHIM_LOG/systemctl.log" || fail "S2: timers not disabled in one call"
  grep -qx -- '--user daemon-reload' "$SHIM_LOG/systemctl.log" ||
    fail "S2: daemon-reload missing"
}

# S3: the panel is killed via the fixed $HOME/mango-desktop path (never the
# real repo path) and wallpaper renderers via wallpaper-ctl stop.
test_processes_stopped() {
  new_scratch procs
  make_state
  run_uninstall </dev/null || fail "S3: uninstall.sh failed"
  [[ -f $SHIM_LOG/pkill.log ]] || fail "S3: pkill never called"
  grep -qF -- "-f $HOME/mango-desktop/quickshell/shell.qml" "$SHIM_LOG/pkill.log" ||
    fail "S3: panel kill pattern is not the fixed \$HOME path"
  if grep -qF "$REPO" "$SHIM_LOG/pkill.log"; then
    fail "S3: kill pattern contains the real repo path"
  fi
}

# S4: ${XDG_STATE_HOME:-~/.local/state}/mango is removed; other apps' state
# survives.
test_state_removed() {
  new_scratch state
  make_state
  run_uninstall </dev/null || fail "S4: uninstall.sh failed"
  [[ ! -d $HOME/.local/state/mango ]] || fail "S4: state dir kept"
  [[ -f $HOME/.local/state/other-app/state ]] || fail "S4: foreign state removed"
}

# S5: the seeded default.png is deleted only when byte-identical to the
# shipped one; user wallpapers are kept; the directory goes only when empty.
test_seeded_wallpaper() {
  new_scratch wp-identical
  make_wallpapers identical
  run_uninstall </dev/null || fail "S5: uninstall.sh failed"
  [[ ! -e $HOME/Pictures/Wallpapers/default.png ]] ||
    fail "S5: identical seed kept"
  [[ -f $HOME/Pictures/Wallpapers/other.png ]] || fail "S5: user wallpaper removed"

  new_scratch wp-modified
  make_wallpapers modified
  run_uninstall </dev/null || fail "S5: uninstall.sh failed (modified seed)"
  [[ -f $HOME/Pictures/Wallpapers/default.png ]] ||
    fail "S5: modified (user-owned) default.png removed"

  new_scratch wp-empty
  mkdir -p -- "$HOME/Pictures/Wallpapers"
  cp -- "$REPO/mango/wallpapers/default.png" "$HOME/Pictures/Wallpapers/default.png"
  run_uninstall </dev/null || fail "S5: uninstall.sh failed (empty dir)"
  [[ ! -d $HOME/Pictures/Wallpapers ]] ||
    fail "S5: empty Wallpapers directory kept"
}

# S6: one `sudo pacman -Rns` removes exactly the installed subset of
# install.sh's package lists.
test_packages_removed() {
  new_scratch pkgs
  install_pkgs > "$PACMAN_INSTALLED"
  run_uninstall </dev/null || fail "S6: uninstall.sh failed"
  [[ -f $SHIM_LOG/pacman.log ]] || fail "S6: pacman never called"
  [[ $(grep -c '^-Rns ' "$SHIM_LOG/pacman.log") -eq 1 ]] ||
    fail "S6: expected exactly one pacman -Rns call"
  if grep -q -- '--noconfirm' "$SHIM_LOG/pacman.log"; then
    fail "S6: removal must keep pacman's confirmation prompt"
  fi
  local expected actual
  expected=$(install_pkgs)
  actual=$(grep '^-Rns ' "$SHIM_LOG/pacman.log" | head -n1 |
    cut -d' ' -f2- | tr ' ' '\n' | grep -E '^[a-z0-9]' | sort -u)
  [[ $actual == "$expected" ]] ||
    fail "S6: removed set differs from install.sh's lists:$(diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true)"
}

# S6 (empty case): with none of the packages installed, pacman -Rns never
# runs and the script still succeeds.
test_no_packages() {
  new_scratch no-pkgs
  : > "$PACMAN_INSTALLED"
  run_uninstall </dev/null || fail "S6: uninstall.sh failed with no packages"
  if [[ -f $SHIM_LOG/pacman.log ]] && grep -q '^-Rns ' "$SHIM_LOG/pacman.log"; then
    fail "S6: pacman -Rns ran with nothing to remove"
  fi
}

# S7: Niri's ~/.config/quickshell, other foreign paths (including paths the
# installer never created, like a real ~/.config/mango directory) and the
# repository itself survive a full run.
test_niri_untouched() {
  new_scratch niri
  make_links
  mkdir -p -- "$HOME/.config/quickshell" "$HOME/.config/niri"
  printf 'niri panel config\n' > "$HOME/.config/quickshell/shell.qml"
  rm -- "$HOME/.config/mango"
  mkdir -p -- "$HOME/.config/mango"
  printf 'foreign mango config\n' > "$HOME/.config/mango/config.conf"
  run_uninstall </dev/null || fail "S7: uninstall.sh failed"
  [[ -f $HOME/.config/quickshell/shell.qml ]] ||
    fail "S7: Niri's ~/.config/quickshell touched"
  [[ -f $HOME/.config/mango/config.conf ]] ||
    fail "S7: foreign ~/.config/mango touched"
  [[ -f $REPO/uninstall.sh && -d $REPO/quickshell ]] ||
    fail "S7: repository damaged"
}

# S8: --dry-run leaves links, state, wallpaper and packages untouched and
# never reaches systemctl, pkill or a removing pacman.
test_dry_run() {
  new_scratch dry
  make_links
  make_state
  make_wallpapers identical
  install_pkgs > "$PACMAN_INSTALLED"
  run_uninstall --dry-run </dev/null || fail "S8: uninstall.sh --dry-run failed"
  assert_links_present
  [[ -d $HOME/.local/state/mango ]] || fail "S8: state dir removed in dry-run"
  [[ -f $HOME/Pictures/Wallpapers/default.png ]] ||
    fail "S8: seed removed in dry-run"
  [[ ! -f $SHIM_LOG/systemctl.log ]] || fail "S8: systemctl reached in dry-run"
  [[ ! -f $SHIM_LOG/pkill.log ]] || fail "S8: pkill reached in dry-run"
  if [[ -f $SHIM_LOG/pacman.log ]] && grep -q '^-Rns ' "$SHIM_LOG/pacman.log"; then
    fail "S8: pacman -Rns reached in dry-run"
  fi
}

# S9: a second full run exits 0 with everything already absent.
test_idempotent() {
  new_scratch twice
  make_links
  make_state
  make_wallpapers identical
  install_pkgs > "$PACMAN_INSTALLED"
  run_uninstall </dev/null || fail "S9: first run failed"
  run_uninstall </dev/null || fail "S9: second run failed"
  assert_links_gone
  [[ ! -d $HOME/.local/state/mango ]] || fail "S9: state reappeared"
}

test_links_removed
test_timers_disabled
test_processes_stopped
test_state_removed
test_seeded_wallpaper
test_packages_removed
test_no_packages
test_niri_untouched
test_dry_run
test_idempotent

echo "verify-uninstall: all probes passed"
