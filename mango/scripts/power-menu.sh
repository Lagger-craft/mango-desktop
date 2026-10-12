#!/usr/bin/env bash
set -euo pipefail

choice=$(printf '%s\n' 'Log out' 'Reboot' 'Power off' 'Cancel' |
  wofi --dmenu --prompt 'CONTROL ROOM / POWER' \
    --style "$HOME/mango-desktop/mango/wofi.css") || exit 0

case "$choice" in
  'Log out') mango -s quit ;;
  'Reboot') systemctl reboot ;;
  'Power off') systemctl poweroff ;;
  *) exit 0 ;;
esac
