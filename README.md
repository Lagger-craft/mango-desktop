# Standalone MangoWM desktop

This repository is an optional personal MangoWM setup. It does not replace or
remove Niri, edit shared dotfiles, or install packages. It uses local images in
`~/Pictures/Wallpapers` and the installed MangoWM, Quickshell, Foot, Wofi,
mpvpaper, Firefox, and Chromium.

## Try it

From a TTY or another session, start Mango directly with this config:

```sh
mango -c "$HOME/mango-desktop/mango/config.conf"
```

No config symlink or copy is needed. Mango starts Quickshell and restores the
last selected wallpaper; Quickshell makes a reserved top panel for every
connected screen. The panel uses a left zone/tag hint, centered date and time,
and right-aligned system tray and power control. Its charcoal surface
is translucent but intentionally has no compositor blur. Firefox is launched
explicitly by its shortcut, while Chromium remains available as a fallback.
Firefox is configured as the XDG default browser; Chromium remains available
from its dedicated shortcut.

## Controls

| Shortcut | Action |
| --- | --- |
| Super+Return | Foot terminal |
| Super+W | Firefox |
| Super+Shift+W | Chromium fallback |
| Super+Tab | Mango overview across tags |
| Super+Space | Wofi application launcher |
| Super+Alt+W | Choose and persist a local wallpaper |
| Super+V | Choose an item from local clipboard history |
| Super+/ | Open the static keyboard shortcut reference |
| Super+H/J/K/L | Focus left/down/up/right |
| Super+Shift+H/J/K/L | Move focused window left/down/up/right |
| Super+Left mouse drag | Move focused window |
| Super+Q | Close focused window |
| Super+Shift+Q | Power menu |
| Super+Shift+S | Select an area, save a timestamped PNG screenshot, and copy it |
| Super+1…9 | View tag 1…9 |
| Super+Shift+1…9 | Move focused window to tag 1…9 |
| Super+Left/Right | Previous/next tag |
| Alt+Arrow keys | Focus in that direction |
| Alt+F | Toggle fullscreen |
| Super+R | Reload Mango config |
| Super+Shift+E | Log out of Mango |

The panel includes a clock, system tray (left-click activates, middle-click
secondary activates, right-click opens the item's menu), and power menu. Choose
wallpapers with `Super+Alt+W`; there is no redundant panel button. The Wofi
drun launcher displays desktop-entry icons. Controls have lightweight hover
easing and tooltips. The power menu offers logout, reboot, and poweroff. Mango
window and layer transitions use short slide animations; blur, shadows, and
opacity effects remain disabled.

Clipboard history is collected by one Mango-session watcher and stored locally
in cliphist's XDG cache. It retains at most 100 entries and skips individual
items larger than 1 MiB (the watcher enforces this per-item cap because the
installed cliphist 0.7.0 has no `max-store-size` option). The history may contain
sensitive copied data; clear it with `cliphist wipe`. Canceling the `Super+V`
picker leaves the current clipboard unchanged. `Super+/` displays a static list
and does not execute selected text.

The `Super+Shift+S` region screenshot is saved under
`~/Pictures/Screenshots` and copied as a PNG image. Each successful capture
replaces the current clipboard with that screenshot; canceling the selector
leaves the clipboard unchanged.

Dunst remains the sole notification daemon. The project provides
`dunst/dunstrc`; after verifying that `~/.config/dunst/dunstrc` does not already
exist, link it to `$HOME/mango-desktop/dunst/dunstrc` and apply it to the running
daemon with `dunstctl reload`. To roll back, remove only that link if it still
points to this project and run `dunstctl reload` again to restore Dunst's
default configuration. Do not start a second notification server.

The project's scripts and configuration perform no network requests and fetch
no remote assets. This guarantee applies only to this project's code; browsers
and other desktop applications may independently use the network.

The selected wallpaper is rendered at each output's own size. Pan-and-scan
preserves the image aspect ratio and fills each screen by cropping its edges;
portrait displays crop more of a landscape image. A fullscreen window pauses the
shared wallpaper renderer on all outputs.

## Rollback

Log out with Super+Shift+E, or exit the compositor normally. Stop only the
wallpaper process managed by this profile with:

```sh
"$HOME/mango-desktop/mango/scripts/wallpaper-selector.sh" --stop
```

The selection and PID are stored under `${XDG_STATE_HOME:-~/.local/state}/mango`;
remove that `mango` state directory only if you also want to forget the chosen
image. This profile uses `~/.config/mango` and sets Firefox as the XDG default.
Rollback those two user-level changes only if the Mango config link still points
to this project; the existing Niri config and `~/.config/quickshell` symlink
remain untouched. Mango's explicit output rules apply only while this profile
is running.

## Validation

```sh
mango -c "$HOME/mango-desktop/mango/config.conf" -p
bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh
git diff --check
```

The configuration and QML are declarative and have no deterministic unit-test
runner; the Quickshell runtime should be exercised from an active Wayland
session. Mango contains three explicit monitor rules using the user-authorized
layout:

| Output | Mode | Layout |
| --- | --- | --- |
| HDMI-A-1 | 1920x1080 @ 120 Hz, 90° counter-clockwise | `(0,0)`, logical size 1080x1920 |
| DP-1 (primary) | 2560x1080 @ 100 Hz | `(1080,420)` |
| DP-2 | 1920x1080 @ 72 Hz | `(3640,420)` |

The portrait screen is vertically centered against the landscape pair. Niri explicitly sets only
`eDP-1` to `1920x1080@120.030` at scale `1.0`; its position is commented out
and other outputs are automatic, so there is no complete multi-monitor layout
to transfer safely. The user's explicit Mango monitor map is used instead.
