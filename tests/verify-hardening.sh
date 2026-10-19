#!/usr/bin/env bash
# Regression probes for odd/tasks/zen-custom-theme-and-hardening.md
#
# Run: bash tests/verify-hardening.sh
# Each function covers one spec item. Nothing here touches the real profile,
# the real wallpaper directory or the host firewall: everything runs against
# scratch directories created with mktemp -d.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# S1/S2/S3: palette flows through, bad values fall back, profile resolution is
# safe, writes are atomic and foreign files are never clobbered.
test_zen_theme() {
  local H="$T/zh"
  local Z="$H/.config/zen/abc.Default (release)"
  local OLD="$H/.config/zen/old.Default (release)"
  mkdir -p "$Z/chrome" "$H/.local/state/mango"
  printf 'x' > "$Z/prefs.js"
  printf '[InstallX]\nDefault=abc.Default (release)\n' > "$H/.config/zen/profiles.ini"
  printf '{"accent":"#ff5722"}' > "$H/.local/state/mango/theme.json"
  echo '// mine' > "$Z/user.js"          # foreign user.js: must survive

  HOME="$H" "$REPO/mango/scripts/zen-theme.sh" >/dev/null
  grep -q '#ff5722' "$Z/chrome/userChrome.css" || fail "S1: palette token missing"
  [[ "$(cat "$Z/user.js")" == '// mine' ]] || fail "S1: foreign user.js clobbered"
  [[ -z "$(find "$Z/chrome" -maxdepth 1 -name '.userChrome.css.*' -print -quit)" ]] ||
    fail "S1: temporary file leaked"

  # Bad palette values fall back per token.
  printf '{"accent":"red","surface":"#ZZZZZZ"}' > "$H/.local/state/mango/theme.json"
  HOME="$H" "$REPO/mango/scripts/zen-theme.sh" >/dev/null
  grep -q '#9bd45a' "$Z/chrome/userChrome.css" || fail "S2: fallback palette missing"
  if grep -q 'red' "$Z/chrome/userChrome.css"; then fail "S2: invalid value accepted"; fi

  # No Install path with prefs.js -> fallback to the newest prefs.js profile.
  mkdir -p "$OLD"
  printf 'x' > "$OLD/prefs.js"
  touch -d '1 hour ago' "$OLD/prefs.js"
  rm -f "$Z/prefs.js"
  HOME="$H" "$REPO/mango/scripts/zen-theme.sh" >/dev/null
  [[ -f "$OLD/chrome/userChrome.css" ]] || fail "S3: stale profile not used"

  # No profile at all -> failure, nothing written.
  ! HOME="$T/empty" "$REPO/mango/scripts/zen-theme.sh" >/dev/null 2>&1 ||
    fail "S3: missing profile must fail"
}

# S4/S5: only old regular files under the screenshots dir are pruned; the
# wallpaper dir and symlinks are untouched; the directory ends up 0700.
test_cleanup() {
  local H="$T/sh"
  local D="$H/Pictures/Screenshots"
  local W="$H/Pictures/Wallpapers"
  mkdir -p "$D/sub" "$W"
  touch -d '4 days ago' "$D/old.png" "$D/sub/old.png" "$W/wall.png"
  touch -d '2 hours ago' "$D/fresh.png"
  ln -s "$W/wall.png" "$D/link.png"
  ln -s "$W" "$D/wdir"

  HOME="$H" "$REPO/mango/scripts/screenshot-cleanup.sh"
  [[ ! -e "$D/old.png" && ! -e "$D/sub/old.png" ]] || fail "S4: old file survived"
  [[ -e "$D/fresh.png" ]] || fail "S4: fresh file deleted"
  [[ -e "$W/wall.png" ]] || fail "S4: wallpaper touched"
  [[ -L "$D/link.png" && -L "$D/wdir" ]] || fail "S4: symlink touched"
  [[ "$(stat -c %a "$D")" == "700" ]] || fail "S5: permissions not 0700"
}

# S6: the ruleset validates and keeps the documented policies.
test_nftables() {
  unshare -rn nft -c -f "$REPO/nftables/nftables.conf" || fail "S6: nft -c failed"
  unshare -rn sh -c "nft -f '$REPO/nftables/nftables.conf' && nft list ruleset" > "$T/ruleset"
  grep -q 'policy drop' "$T/ruleset" || fail "S6: inbound is not default-deny"
  grep -A3 'chain output' "$T/ruleset" | grep -q 'policy accept' ||
    fail "S6: outbound is not allow-all"
  grep -q 'ipv6-icmp' "$T/ruleset" || fail "S6: ICMPv6 not allowed (breaks IPv6)"
}

# S7: telemetry pinned off, safe browsing untouched, custom CSS enabled.
test_user_js() {
  local U="$REPO/zen/user.js"
  grep -q 'toolkit.telemetry.enabled", false' "$U" || fail "S7: telemetry not pinned"
  grep -q 'datareporting.policy.dataSubmissionEnabled", false' "$U" ||
    fail "S7: data submission not pinned"
  grep -q 'legacyUserProfileCustomizations.stylesheets", true' "$U" ||
    fail "S7: custom CSS pref missing"
  if grep -q 'safebrowsing' "$U"; then fail "S7: safe browsing disabled"; fi
}

test_zen_theme
test_cleanup
test_nftables
test_user_js
printf 'all probes pass\n'
