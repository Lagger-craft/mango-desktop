# Standalone Chernobyl-Inspired MangoWM Desktop

## Objective
Create a self-contained MangoWM desktop configuration outside the existing Niri dotfiles, with a Quickshell top bar and keyboard-driven desktop tools.

## Problem and rationale
The user wants to try a personal MangoWM setup before deciding whether to remove Niri. The existing Niri/Quickshell dotfiles are explicitly out of scope. Build a separate, reversible MangoWM configuration and reuse installed local programs rather than importing another person's configuration.

## Scope and constraints
- Keep this project at `~/mango-desktop`, separate from `~/meloworld-dotfiles`.
- Create a new `~/.config/mango` link only after confirming its target is absent; do not modify Niri or the existing `~/.config/quickshell` symlink.
- Do not change Niri. Its saved config contains no complete layout; use the user's explicit Mango monitor map below instead.
- Use MangoWM 0.18, Quickshell 0.3.2, Foot, Wofi, mpvpaper, Firefox, and Chromium already available locally. Do not install packages or fetch remote assets.
- Choose dark ash/charcoal neutrals with radioactive green and amber accents.
- Prioritize fullscreen game performance: no blur/shadows/opacity and pause the wallpaper renderer on fullscreen.
- Fit static wallpapers independently to each output while preserving aspect ratio; fill/crop rather than stretch, and document portrait-screen crop behavior.
- Keep clipboard history local and bounded; do not inspect existing clipboard contents during setup.
- Theme the existing Dunst notification daemon rather than starting a duplicate notification server.
- Firefox becomes the default browser; Chromium remains directly launchable as a fallback.
- Delivery strategy: ask-on-risk; the user selected `stacked-to-main`. Slice 1 is CM-1 (`a1509c2`); slice 2 groups CM-2–CM-5 into one 430-line follow-up profile completion, stacked on CM-1. It is slightly above the approximate 400-line budget, but splitting the integrated compositor, panel, controls, and local tools would add review overhead without independent deployment value. No push or PR is authorized.

## Authorized scope
- `mango/config.conf`
- `mango/scripts/power-menu.sh`
- `mango/scripts/wallpaper-selector.sh`
- `mango/wofi.css`
- `quickshell/shell.qml`
- `README.md`
- `mango/scripts/clipboard-menu.sh`
- `mango/scripts/shortcut-reference.sh`
- `dunst/dunstrc`

## Tasks
- [x] CM-1 (delegated direct): Built the standalone MangoWM config, QuickShell panel, power/wallpaper menus, launcher and browser shortcuts; preserved output auto-detection and documented setup/rollback.
- [x] CM-2 (delegated direct): Enabled short Mango window/layer animations and redesigned the QuickShell bar into left/center/right sections with concise icons, tooltips, and lightweight hover easing; kept decorations game-conscious and outputs automatic.
- [x] CM-3 (delegated direct): Applied the user's three-monitor geometry/rates, Super+left-drag and Vim-style HJKL window controls, Super+Q close, removed the redundant wallpaper bar button while retaining its shortcut, and enabled app icons in Wofi.
- [x] CM-4 (direct inline): Configured mpvpaper to keep static images indefinitely and fill each output at its own dimensions without stretching; recorded the crop and fullscreen-pause tradeoffs.
- [x] CM-5 (delegated direct): Added a bounded local cliphist menu on Super+V, a shortcut reference on Super+/, and a Chernobyl theme for the existing Dunst service.

## Acceptance criteria
- `Super+Return` launches Foot; `Super+W` launches Firefox; `Super+Shift+W` launches Chromium; Firefox is the XDG default browser.
- `Super+Tab` opens Mango's native overview across open windows/tags.
- `Super+Space` opens the Wofi application menu.
- `Super+Alt+W` opens a static wallpaper selector; the chosen image persists and restores on Mango startup.
- The top QuickShell panel shows a clock, system tray, and power menu control on each discovered screen; wallpaper selection is keyboard-driven, not a redundant bar button.
- Power menu offers logout, reboot, and poweroff.
- Mango uses only the three monitor rules requested by the user; Niri/dotfiles remain untouched.
- Blur, shadows, and opacity effects remain disabled; mpvpaper pauses for fullscreen windows.
- Setup/rollback steps do not overwrite existing config paths.
- Mango window/layer transitions are smooth and short; fullscreen-game rendering remains free of blur/shadows/opacity.
- The QuickShell bar uses organized sections, clear icons, restrained radioactive/amber accents, and lightweight hover/transition effects.
- Niri remains untouched; Mango positions use only the monitor map the user explicitly supplied and the stated centered portrait alignment.
- `DP-1` is primary at 2560x1080@100; `DP-2` is 1920x1080@72 to its right; `HDMI-A-1` is 1920x1080@120, rotated 90° CCW, to the left. The portrait output is vertically centered against the landscape displays.
- `Super` + left mouse drag moves the focused window; `Super+H/J/K/L` moves focus left/down/up/right, with `Super+Shift+H/J/K/L` moving the window.
- `Super+Q` closes the focused application.
- The wallpaper selector remains available through `Super+Alt+W` without a redundant QuickShell wallpaper button; `Super+Space` Wofi drun displays desktop icons.
- The selected static wallpaper adapts to each output's dimensions independently, preserves its aspect ratio, and stays displayed until changed.
- `Super+V` opens a Wofi clipboard-history picker; history is local and limited to 100 entries with a documented clear command.
- `Super+/` opens a themed reference of the configured keyboard shortcuts.
- Dunst keeps its existing notification ownership but uses a matching charcoal/green/amber theme.

## Route and checks
- Route: delegated direct; multiple coordinated config, shell, and script files need existing-version research and implementation.
- TDD exception: this declarative compositor/QML setup has no meaningful deterministic RED/GREEN unit test. Validate Mango's parser, shell script syntax, QML runtime where Wayland is available, and worktree integrity.
- Checks: `mango -c ./mango/config.conf -p`; `bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh`; `quickshell --path ./quickshell/shell.qml` (interactive runtime load where available); `mmsg get all-monitors`; `git diff --check`.
- CM-4 check: `bash -n ./mango/scripts/wallpaper-selector.sh`; mpvpaper option behavior is verified from its installed manual/upstream source, with no wallpaper process launched during validation.
- CM-5 checks: `bash -n` for both helper scripts, Mango config parser, and `git diff --check`; Dunst reload through the existing daemon; manual shortcut checks without reading or overwriting existing clipboard contents.

## Progress and evidence
- 2026-10-12: Confirmed Mango 0.18.0, Quickshell 0.3.2, Foot, Wofi, mpvpaper, Firefox, and Chromium are installed. `~/.config/mango` was absent at exploration; `~/.config/quickshell` is a symlink into the unrelated dotfiles and was not modified. Mango overview uses `toggleoverview`; mpvpaper supports `ALL` outputs and auto-pause for fullscreen. Quickshell 0.3.1 public API docs confirm screen Variants, `PanelWindow.exclusiveZone`, `SystemTray.items`, and tray activation/menu methods.
- 2026-10-12: Niri's `outputs.kdl` explicitly configures only `eDP-1` at `1920x1080@120.030`, scale `1.0`; its position is commented out, and no other output rules exist. Therefore Niri does not contain a complete multi-monitor coordinate layout to copy; other outputs use automatic placement.
- 2026-10-12: User supplied the exact Mango layout: DP-1 2560x1080@100 main; DP-2 1920x1080@72 on its right; HDMI-A-1 1920x1080@120 rotated 90° on its left. EDID confirms the requested refresh rates (DP-1 99.943 Hz, DP-2 71.910 Hz, HDMI-A-1 120.000 Hz). Planned positive-coordinate geometry places HDMI at (0,0), DP-1 at (1080,420), and DP-2 at (3640,420), vertically centering the portrait display; Mango `rr:1` is 90° counter-clockwise.
- 2026-10-12: Confirmed `mpvpaper ALL` renders output-sized surfaces using each output's dimensions, with one shared mpv option set; `--panscan=1` fills mismatched aspect ratios by cropping rather than stretching, and `--image-display-duration=inf` keeps still images open.
- 2026-10-12: Confirmed Dunst 1.13.2 is the running notification daemon; no Dunst user config exists. Cliphist 0.7.0, wl-copy, and wl-paste are installed; no history watcher is running. Use a local 100-item history and the existing Dunst daemon rather than introducing another notifications server.
- 2026-10-12: CM-2 enables Mango slide animations with 150–200 ms durations and a smooth cubic-bezier curve. The panel now has a left zone/tag hint, centered date/time, and right system tray plus wallpaper/power controls, with a restrained green top edge, amber/red control accents, tooltips, and lightweight hover color/scale easing. It uses a translucent charcoal fill without compositor blur; the tray's left/middle/right actions and existing process controls are preserved. Blur, shadows, opacity effects, and fullscreen wallpaper auto-pause behavior remain unchanged.
- CM-2 verification: `mango -c "$HOME/.config/mango/config.conf" -p` — passed (exit 0, no diagnostics); `WAYLAND_DISPLAY=wayland-0 timeout --signal=TERM 8s quickshell --path /home/lagger/mango-desktop/quickshell/shell.qml --verbose` — reported `Configuration Loaded`, then exited at the intentional timeout (124); `quickshell list --all` — confirmed the project QML running on `wayland/wayland-0`; `git diff --check` — passed. The shell initially inherited stale `WAYLAND_DISPLAY=wayland-1`, whose connection was refused; using the live `wayland-0` restored and verified the project-managed QuickShell panel. The Mango parser was checked, but animation appearance was not visually verified in a live compositor session.
- CM-2 commit status: not staged or committed. CM-1 has 436 authored lines and delivery remains `ask-on-risk`; obtain the chain-strategy choice before the next work-unit commit. No push or PR was made.
- CM-3: authorized scope remains `mango/config.conf`, `quickshell/shell.qml`, `mango/wofi.css`, `README.md`, and this task document. The wallpaper script continues to be used by its existing shortcut, not a bar button.
- CM-3 implementation: added explicit `monitor_rule` entries for only HDMI-A-1, DP-1, and DP-2 at the user-specified modes/positions/rotations; added Super+left-drag, HJKL focus/move, and Super+Q while retaining Super+Shift+Q; Wofi drun now passes `--allow-images`; removed only the QuickShell wallpaper button and its Process, retaining the power control and wallpaper shortcut. Hardened tray tooltip bindings after the live QuickShell log exposed missing-tooltip warnings.
- CM-3 verification: `mango -c "$HOME/.config/mango/config.conf" -p` — passed (exit 0, no diagnostics); `bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh` — passed (exit 0); `git diff --check` — passed (exit 0). `wofi --help` lists `--allow-images`; the project QML is running on `wayland-0`. After `mmsg dispatch reload_config`, `mmsg get all-monitors` reported HDMI-A-1 at logical 1080x1920 (0,0), DP-1 2560x1080 at (1080,420), and DP-2 1920x1080 at (3640,420); the requested rates are supported by EDID and in the loaded rules. Keyboard and pointer shortcuts are configured and parser-validated, but were not simulated; the user should manually verify them.
- CM-4: `wallpaper-selector.sh` passes `image-display-duration=inf` and `panscan=1` to mpvpaper for its shared `ALL` renderer. It scales each output independently, preserves aspect ratio, and crops to fill; landscape images will lose substantial side content on the portrait output. A fullscreen window can pause wallpaper rendering across all outputs because the mpv instance is shared.
- CM-4 verification: `bash -n ./mango/scripts/wallpaper-selector.sh` — passed; `mpv --no-config --panscan=1 --image-display-duration=inf --list-options` — passed; `git diff --check` — passed. No wallpaper process was started during the check; visual crop behavior remains to be confirmed after the user selects an image.
- CM-5 implementation: added one Mango `exec_once` clipboard watcher with a 100-entry cliphist limit and a 1 MiB per-item cap enforced in the watcher helper; cliphist 0.7.0 does not support its documented `max-store-size` option. It keeps its database in cliphist's default local XDG cache. `Super+V` uses a Wofi picker, exits harmlessly on cancellation, and sends the chosen item through `cliphist decode` to `wl-copy`; `Super+/` shows a static Wofi shortcut list using Mango's parser-accepted `slash` key symbol. Added a concise Dunst 1.13-compatible theme in `dunst/dunstrc`, while retaining Dunst as the sole notification daemon. README covers controls, local retention and `cliphist wipe`, Dunst setup/reload/rollback, and the project's limited no-network guarantee.
- CM-5 verification: helper-script syntax, Mango parser, and `git diff --check` passed. The Dunst config link points to this project; `dunstctl reload` succeeded and the existing service stayed active. A benign test notification was displayed. Mango config reload succeeded and exactly one bounded `wl-paste --watch` process is running. Clipboard/history contents were not read or overwritten; the live picker was not opened to avoid displaying existing entries.
- CM-5 privacy note: cliphist stores future clipboard selections in its local XDG cache, bounded to 100 entries and 1 MiB per item; `cliphist wipe` clears that local history. Dunst remains the sole notification daemon.
- CM-5 status: not staged or committed. Delivery remains `ask-on-risk`; no push or PR was made.
- 2026-10-12: Implemented CM-1 in `mango/config.conf`, both menu/wallpaper scripts, `mango/wofi.css`, `quickshell/shell.qml`, and `README.md`. Installed `~/.config/mango` as a link to this project, leaving `~/.config/quickshell` untouched. Set Firefox as the XDG default (`firefox.desktop`). Mango reloaded the config successfully; QuickShell loaded and displayed a top layer on each of the three auto-detected monitors. No output names, positions, resolutions, or scales are hardcoded.
- Verification: `mango -c "$HOME/.config/mango/config.conf" -p` — passed. `bash -n ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-selector.sh` — passed. `git diff --cached --check` — passed. The QuickShell runtime first failed before a Wayland socket was available; after the Mango session became available, `timeout --signal=TERM 8s quickshell --path /home/lagger/mango-desktop/quickshell/shell.qml --verbose` loaded the configuration with no QML errors and exited only when the 8-second test timeout fired. A persistent QuickShell process is now running and Mango reports `quickshell` top layers on HDMI-A-1, DP-2, and DP-1. The declarative setup has no meaningful deterministic RED/GREEN unit test.
- Local security audit: No explicit remote host, URL fetch/upload, secret read, or local-file exfiltration path was found in the project source. Wallpaper files and selected path/PID state are handled locally. Browsers and tray applications can make their own normal network requests. Minor robustness note: `$HOME` is unquoted in a few Mango `exec_once`/bind entries, which is harmless for this home path but may break if a future home path contains whitespace. Wallpaper PID cleanup checks process name; PID reuse by another `mpvpaper` instance is a low-probability local process risk.
- Local verification mode: clone-local receipt-driven review is off at the user's explicit request; global default remains on. The native review had been started and consented before that choice, but was not completed. Static independent audit and local checks were used; no review receipt or approval is claimed.
- Delivery: CM-1's 436 authored lines exceed the approximate review-slice budget. User-selected `stacked-to-main` keeps CM-1 as slice 1 and CM-2–CM-5 as one 430-line local follow-up slice. The slight overage is intentional to keep the complete, usable desktop profile together; no remote action is authorized.
- Rollback boundary: exit this Mango session and run `mango/scripts/wallpaper-selector.sh --stop`; remove `~/.config/mango` only if it still points to `~/mango-desktop/mango`; restore the previous XDG browser with `xdg-settings set default-web-browser chromium.desktop` if desired; remove only `${XDG_STATE_HOME:-$HOME/.local/state}/mango` if the stored wallpaper selection should also be forgotten. No Niri files or existing `~/.config/quickshell` symlink are changed.
- Skill resolution: `fallback-registry` — no project skill registry was present; loaded installed `work-unit-commits` skill.
- Work-unit commit: `a1509c2` (`feat(desktop): add standalone Chernobyl MangoWM setup`).

## Next step
CM-1 through CM-5 are implemented and locally validated. Create the local CM-2–CM-5 follow-up work-unit commit, record its identity, and do not push or open a PR. Manually verify Super+V and Super+/ without exposing prior clipboard data; use `Super+Alt+W` to choose a wallpaper and confirm the portrait crop.
