# Standalone Chernobyl-Inspired MangoWM Desktop

## Objective
Create a self-contained MangoWM desktop configuration outside the existing Niri dotfiles, with a Quickshell top bar and keyboard-driven desktop tools.

## Problem and rationale
The user wants to try a personal MangoWM setup before deciding whether to remove Niri. The existing Niri/Quickshell dotfiles are explicitly out of scope. Build a separate, reversible MangoWM configuration and reuse installed local programs rather than importing another person's configuration.

## Scope and constraints
- Keep this project at `~/mango-desktop`, separate from `~/meloworld-dotfiles`.
- Create a new `~/.config/mango` link only after confirming its target is absent; do not modify Niri or the existing `~/.config/quickshell` symlink.
- Do not hardcode monitor names, modes, scale, or positions. Let Mango discover outputs so the user can test without changing Niri's monitor configuration.
- Use MangoWM 0.18, Quickshell 0.3.2, Foot, Wofi, mpvpaper, Firefox, and Chromium already available locally. Do not install packages or fetch remote assets.
- Choose dark ash/charcoal neutrals with radioactive green and amber accents.
- Prioritize fullscreen game performance: no blur/shadows/opacity and pause the wallpaper renderer on fullscreen.
- Firefox becomes the default browser; Chromium remains directly launchable as a fallback.
- Delivery strategy: ask-on-risk. Forecast: approximately 250 authored changed lines.

## Authorized scope
- `mango/config.conf`
- `mango/scripts/power-menu.sh`
- `mango/scripts/wallpaper-selector.sh`
- `mango/wofi.css`
- `quickshell/shell.qml`
- `README.md`

## Tasks
- [x] CM-1 (delegated direct): Built the standalone MangoWM config, QuickShell panel, power/wallpaper menus, launcher and browser shortcuts; preserved output auto-detection and documented setup/rollback.

## Acceptance criteria
- `Super+Return` launches Foot; `Super+W` launches Firefox; `Super+Shift+W` launches Chromium; Firefox is the XDG default browser.
- `Super+Tab` opens Mango's native overview across open windows/tags.
- `Super+Space` opens the Wofi application menu.
- `Super+Alt+W` opens a static wallpaper selector; the bar has a wallpaper button; chosen image persists and restores on Mango startup.
- The top QuickShell panel shows a clock, system tray, wallpaper control, and power menu control on each discovered screen.
- Power menu offers logout, reboot, and poweroff.
- Mango contains no hardcoded monitor rule; Niri/dotfiles remain untouched.
- Blur, shadows, and opacity effects remain disabled; mpvpaper pauses for fullscreen windows.
- Setup/rollback steps do not overwrite existing config paths.

## Route and checks
- Route: delegated direct; multiple coordinated config, shell, and script files need existing-version research and implementation.
- TDD exception: this declarative compositor/QML setup has no meaningful deterministic RED/GREEN unit test. Validate Mango's parser, shell script syntax, QML runtime where Wayland is available, and worktree integrity.
- Checks: `mango -c ./mango/config.conf -p`; `bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh`; `quickshell --path ./quickshell/shell.qml` (interactive runtime load where available); `git diff --check`.

## Progress and evidence
- 2026-10-12: Confirmed Mango 0.18.0, Quickshell 0.3.2, Foot, Wofi, mpvpaper, Firefox, and Chromium are installed. `~/.config/mango` was absent at exploration; `~/.config/quickshell` is a symlink into the unrelated dotfiles and was not modified. Mango overview uses `toggleoverview`; mpvpaper supports `ALL` outputs and auto-pause for fullscreen. Quickshell 0.3.1 public API docs confirm screen Variants, `PanelWindow.exclusiveZone`, `SystemTray.items`, and tray activation/menu methods.
- 2026-10-12: Implemented CM-1 in `mango/config.conf`, both menu/wallpaper scripts, `mango/wofi.css`, `quickshell/shell.qml`, and `README.md`. Installed `~/.config/mango` as a link to this project, leaving `~/.config/quickshell` untouched. Set Firefox as the XDG default (`firefox.desktop`). Mango reloaded the config successfully; QuickShell loaded and displayed a top layer on each of the three auto-detected monitors. No output names, positions, resolutions, or scales are hardcoded.
- Verification: `mango -c "$HOME/.config/mango/config.conf" -p` — passed. `bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh` — passed. `git diff --cached --check` — passed. The QuickShell runtime first failed before a Wayland socket was available; after the Mango session became available, `timeout --signal=TERM 8s quickshell --path /home/lagger/mango-desktop/quickshell/shell.qml --verbose` loaded the configuration with no QML errors and exited only when the 8-second test timeout fired. A persistent QuickShell process is now running and Mango reports `quickshell` top layers on HDMI-A-1, DP-2, and DP-1. The declarative setup has no meaningful deterministic RED/GREEN unit test.
- Local security audit: No explicit remote host, URL fetch/upload, secret read, or local-file exfiltration path was found in the project source. Wallpaper files and selected path/PID state are handled locally. Browsers and tray applications can make their own normal network requests. Minor robustness note: `$HOME` is unquoted in a few Mango `exec_once`/bind entries, which is harmless for this home path but may break if a future home path contains whitespace. Wallpaper PID cleanup checks process name; PID reuse by another `mpvpaper` instance is a low-probability local process risk.
- Local verification mode: clone-local receipt-driven review is off at the user's explicit request; global default remains on. The native review had been started and consented before that choice, but was not completed. Static independent audit and local checks were used; no review receipt or approval is claimed.
- Rollback boundary: exit this Mango session and run `mango/scripts/wallpaper-selector.sh --stop`; remove `~/.config/mango` only if it still points to `~/mango-desktop/mango`; restore the previous XDG browser with `xdg-settings set default-web-browser chromium.desktop` if desired; remove only `${XDG_STATE_HOME:-$HOME/.local/state}/mango` if the stored wallpaper selection should also be forgotten. No Niri files or existing `~/.config/quickshell` symlink are changed.
- Skill resolution: `fallback-registry` — no project skill registry was present; loaded installed `work-unit-commits` skill.
- Work-unit commit: pending.

## Next step
Commit this work unit, then use `Super+Alt+W` to choose a wallpaper and manually verify the launch, power, and overview shortcuts in the live session.
