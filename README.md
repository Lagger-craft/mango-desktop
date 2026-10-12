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
connected screen. Firefox is launched explicitly by its shortcut, while
Chromium remains available as a fallback. Set Firefox as the XDG default
browser separately if desired; this project intentionally does not change it.

## Controls

| Shortcut | Action |
| --- | --- |
| Super+Return | Foot terminal |
| Super+W | Firefox |
| Super+Shift+W | Chromium fallback |
| Super+Tab | Mango overview across tags |
| Super+Space | Wofi application launcher |
| Super+Alt+W | Choose and persist a local wallpaper |
| Super+Shift+Q | Power menu |
| Super+1…9 | View tag 1…9 |
| Super+Shift+1…9 | Move focused window to tag 1…9 |
| Super+Left/Right | Previous/next tag |
| Alt+Arrow keys | Focus in that direction |
| Alt+F | Toggle fullscreen |
| Super+R | Reload Mango config |
| Super+Shift+E | Log out of Mango |

The panel includes a clock, system tray (left-click activates, middle-click
secondary activates, right-click opens the item's menu), wallpaper selector,
and power menu. The power menu offers logout, reboot, and poweroff.

## Rollback

Log out with Super+Shift+E, or exit the compositor normally. Stop only the
wallpaper process managed by this profile with:

```sh
"$HOME/mango-desktop/mango/scripts/wallpaper-selector.sh" --stop
```

The selection and PID are stored under `${XDG_STATE_HOME:-~/.local/state}/mango`;
remove that `mango` state directory only if you also want to forget the chosen
image. No active Niri/Quickshell configuration, symlink, monitor mode, or
browser-default setting is touched, so there is nothing to uninstall and Niri
remains available unchanged.

## Validation

```sh
mango -c ./mango/config.conf -p
bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh
git diff --check
```

The configuration and QML are declarative and have no deterministic unit-test
runner; the Quickshell runtime should be exercised from an active Wayland
session. Mango output detection is left automatic: this profile contains no
monitor-specific rules or mode/position values.
