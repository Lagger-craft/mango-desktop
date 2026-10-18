#!/usr/bin/env bash
set -euo pipefail

style="$HOME/mango-desktop/mango/wofi.css"

printf '%s\n' \
  'Super+Return — Foot terminal' \
  'Super+W — Firefox' \
  'Super+Shift+W — Chromium fallback' \
  'Super+Tab — Mango overview' \
  'Super+Space — Application launcher' \
  'Super+Alt+W — Wallpaper picker' \
  'Super+V — Clipboard history (press again to close)' \
  'Super+/ — Shortcut reference' \
  'Super+H/J/K/L — Focus left/down/up/right' \
  'Super+Shift+H/J/K/L — Move window left/down/up/right' \
  'Super+Left mouse drag — Move focused window' \
  'Super+Right mouse drag — Resize focused window' \
  'Super+T — Toggle floating for focused window' \
  'Super+Q — Close focused window' \
  'Super+Shift+Q — Power menu' \
  'Super+1…9 — View tag 1…9' \
  'Super+Shift+1…9 — Move window to tag 1…9' \
  'Super+Left/Right — Previous/next tag' \
  'Alt+Arrow keys — Focus in that direction' \
  'Alt+F — Toggle fullscreen' \
  'Super+R — Reload Mango config' \
  'Super+Shift+E — Log out of Mango' \
  | wofi --dmenu --style "$style" --prompt 'Keyboard shortcuts'
