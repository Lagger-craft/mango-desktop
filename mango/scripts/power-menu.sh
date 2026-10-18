#!/usr/bin/env bash
set -euo pipefail

# Toggle: if the power menu is already open, pressing the bind closes it
# instead of stacking another instance (same guard as clipboard-menu.sh).
menu_pattern='wofi --dmenu.*CONTROL ROOM / POWER'
if pgrep -f -- "$menu_pattern" > /dev/null; then
  pkill -f -- "$menu_pattern"
  exit 0
fi

choice=$(printf '%s\n' 'Log out' 'Reboot' 'Power off' 'Cancel' |
  wofi --dmenu --prompt 'CONTROL ROOM / POWER' \
    --style "$HOME/mango-desktop/mango/wofi.css") || exit 0

case "$choice" in
  'Log out') mango -s quit ;;
  'Reboot') systemctl reboot ;;
  'Power off') systemctl poweroff ;;
  *) exit 0 ;;
esac
