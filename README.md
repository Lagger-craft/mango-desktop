# Standalone MangoWM desktop

This repository is an optional personal MangoWM setup. It does not replace or
remove Niri and leaves shared dotfiles untouched. Package installation is
opt-in through the included `install.sh` (see `## Install`). It uses local
images in `~/Pictures/Wallpapers` and Steam Workshop Wallpaper Engine
backgrounds, driven by the MangoWM, Quickshell, Foot, Wofi, mpvpaper,
linux-wallpaperengine, Firefox, and Chromium stack described below. A default
background is shipped at `mango/wallpapers/default.png` so that a fresh install
always renders a desktop rather than a blank screen.

## Try it

From a TTY or another session, start Mango directly with this config:

```sh
mango -c "$HOME/mango-desktop/mango/config.conf"
```

No config symlink or copy is needed. Mango starts Quickshell and restores each
monitor's last wallpaper; when no valid selection exists yet (a fresh install,
or the selected file was removed since) it falls back to the shipped default
background instead of starting blank. Quickshell makes a reserved top panel for
every connected screen. The panel renders as three floating islands with
compositor layer blur: a left zone/tag island, a centered clock island, and a
right island with the system tray, the notification center, and the power icon.
Their charcoal surface is translucent, so the live backdrop behind the bar
frosts into the island bodies (glass effect); windows stay opaque, so window
blur never shows. Firefox is launched
explicitly by its shortcut, while Chromium remains available as a fallback.
Firefox is configured as the XDG default browser; Chromium remains available
from its dedicated shortcut.

## Install

Clone this repository to exactly `$HOME/mango-desktop` (the config references
that path), then run the installer:

```sh
git clone <this-repo> "$HOME/mango-desktop"
cd "$HOME/mango-desktop"
./install.sh            # install and link
./install.sh --dry-run  # preview every action, change nothing
./install.sh --uninstall # remove only the symlinks the installer created
```

Dependency policy: official-repo packages are installed with `pacman`
(`mangowm`, `quickshell`, `foot`, `wofi`, `cliphist`, `wl-clipboard`, `jq`,
`grim`, `slurp`, `matugen`, `firefox`, `chromium`, `xdg-utils`, `fastfetch`); AUR-only packages go
through the first available helper among `yay` and `paru` (`mpvpaper`,
`linux-wallpaperengine-git`). Set `AUR_HELPER=<helper>` to force one. The
installer is idempotent and
non-destructive: it never overwrites an existing config path (an occupied
`~/.config/mango`, `~/.config/vesktop`,
`~/.config/fastfetch`, or
`~/.zshrc` is reported as `SKIP` and left alone), it only sets the XDG default
browser when none is configured, and it never touches Niri or
`~/.config/quickshell`. Packages are left installed on `--uninstall`; see
`## Rollback` for the rest.

The repository ships the live configuration for this profile: `mango/`
(compositor config and scripts), `quickshell/shell.qml` (the panel, started
directly from `mango/config.conf`, no symlink needed),
`vesktop/` (themes and settings; `vesktop/sessionData/` is runtime state and
stays untracked), `zsh/.zshrc`, and `fastfetch/` (the terminal system-info
config and its custom skull ASCII logo). The installer links all of them into
place.

## Controls

| Shortcut | Action |
| --- | --- |
| Super+Return | Foot terminal |
| Super+W | Zen browser |
| Super+Shift+W | Chromium fallback |
| Super+Up / Super+Down | Raise / lower volume by 5% |
| Keyboard volume wheel/keys | Raise / lower volume by 5% |
| Wheel press (`XF86AudioMute`) | Toggle mute |

Volume changes show a small OSD popup at the bottom-right of the
compositor-focused screen (percentage and progress bar; amber when muted). It
auto-hides after 1.5 seconds and comes from `mango/scripts/volume-osd.sh`,
which performs the `wpctl` action and writes the state for the QuickShell
popup.
| Super+Tab | Mango overview (drag apps to tags/monitors) |
| Super+Space | Wofi application launcher |
| Super+Alt+W | Open the wallpaper picker (local + Steam Workshop) |
| Super+Alt+A | Open the audio panel (outputs, inputs, per-app volume) |
| Super+V | Choose an item from local clipboard history (press again to close) |
| Super+/ | Open the static keyboard shortcut reference |
| Super+H/J/K/L | Focus left/down/up/right |
| Super+Shift+H/J/K/L | Move focused window left/down/up/right |
| Super+Left mouse drag | Move focused window |
| Super+Right mouse drag | Resize focused window |
| Super+T | Toggle floating for focused window |
| Super+Q | Close focused window |
| Super+Shift+Q | Power menu (press again to close) |
| Super+Shift+S | Select an area, save a timestamped PNG screenshot, and copy it |
| Super+1…9 | View tag 1…9 |
| Super+Shift+1…9 | Move focused window to tag 1…9 |
| Super+Left/Right | Previous/next tag |
| Alt+Arrow keys | Focus in that direction |
| Alt+F | Toggle fullscreen |
| Super+R | Reload Mango config |
| Super+Shift+E | Log out of Mango |
| Super+N | Cycle the tag layout (tile <-> vertical_tile) |

Window layouts are per tag. Every tag starts in Mango's `vertical_tile`
layout via a tag rule (`master plus windows tiled side by side in
horizontal rows`; plain `tile` stacks them vertically); `Super+N` cycles
the current tag through `circle_layout` in `mango/config.conf`
(`vertical_tile` <-> `tile`) and a reload resets to the default.

The panel includes a clock (clicking it toggles a calendar popup under the
island, or `Super`-bindable `quickshell ipc call calendar toggle`), a ZONE
label that opens the dashboard, a system tray (left-click activates,
middle-click secondary activates, right-click opens the item's menu), a
notification icon that opens a review panel (history, re-show one or the
latest, clear history, close displayed), a speaker icon that opens the audio
panel, and an icon-only power control. The dashboard is a dimmed full-screen
overlay (the ZONE label or
`quickshell ipc call dashboard toggle`) with notification history,
live CPU/RAM/uptime/kernel figures, the active MPRIS player, and session
actions (logout, reboot, poweroff). The `Super+Alt+W` wallpaper picker is a QuickShell overlay, not a Wofi menu (see
`## Wallpapers`); there is no redundant panel button. The Wofi
drun launcher displays desktop-entry icons. Controls have lightweight hover
easing and tooltips. The power menu offers logout, reboot, and poweroff. Mango
window and layer transitions use short zoom/fade animations (open zoom, close
fade, tag/move slides under 150 ms); shadows and opacity effects remain
disabled. The island panels use real compositor blur: `blur=1` plus
`blur_layer=1` with `blur_optimized=0`, so the islands frost whatever is
behind the bar (the cheaper `blur_optimized=1` mode only renders a flat dark
backdrop). Windows stay at opacity 1.0 so window blur never visibly renders,
and Steam games carry `no_blur:1` to keep the fullscreen path free of
window blur.

Clipboard history is collected by one Mango-session watcher and stored locally
in cliphist's XDG cache. It retains at most 100 entries and skips individual
items larger than 1 MiB (the watcher enforces this per-item cap because the
installed cliphist 0.7.0 has no `max-store-size` option). Entries expire 72
hours after they were copied: re-copying an item, or picking it again from the
`Super+V` menu, restarts that item's clock, while an item that stays unused is
deleted from the history and, when it is the current selection, also cleared
from the clipboard. A plain `Ctrl+V` paste cannot be observed on Wayland, so it
does not restart the clock. An hourly systemd user timer runs the same pass, so
an idle session is still cleaned up:

```sh
systemctl --user list-timers clipboard-expire.timer
```

The expiry bookkeeping stores only cliphist entry ids and timestamps, never
clipboard content; entries that already existed when the feature was installed
start their clock the first time they are observed. The history may contain
sensitive copied data; clear it with `cliphist wipe`. Canceling the `Super+V`
picker leaves the current clipboard unchanged, and pressing `Super+V` while the
picker is open closes it instead of opening a second one. `Super+/` displays a
static list and does not execute selected text.

The `Super+Shift+S` region screenshot is saved under
`~/Pictures/Screenshots` and copied as a PNG image. Each successful capture
replaces the current clipboard with that screenshot; canceling the selector
leaves the clipboard unchanged.

Notifications are handled entirely inside QuickShell: its `NotificationServer`
is the sole notification daemon, so there is no extra process. Incoming
notifications render as themed toasts under the bar on the focused monitor;
critical ones persist until dismissed. The bell icon reads the same shell
singleton (bounded history, badge with live count). If dunst is installed it
should be removed: it D-Bus-activates on the first `notify-send` and races the
shell for `org.freedesktop.Notifications`. A user-level override at
`~/.local/share/dbus-1/services/org.freedesktop.Notifications.service` with
`Exec=/bin/false` masks that activation without touching system files.

The shell palette is generated by matugen from the applied wallpaper.
`wallpaper-ctl.sh apply/restore` runs matugen once against a static source —
the wallpaper image for local posters, the Workshop item's preview for
animated Wallpaper Engine scenes — and writes the token file
`${XDG_STATE_HOME:-~/.local/state}/mango/theme.json`. QuickShell watches that
file, so recoloring is live and there is no per-frame sampling while an
animated wallpaper plays. Missing matugen or a malformed palette keeps the
previous theme.

The project's scripts and configuration perform no network requests and fetch
no remote assets. This guarantee applies only to this project's code; browsers
and other desktop applications may independently use the network.

## Audio panel

The speaker icon in the right island of the bar (or `Super+Alt+A`, or
`quickshell ipc call audio toggle`) opens a panel with three sections:

- **Output**: every playback device, its volume slider and mute button. The
  filled dot marks the default output; clicking the dot (or the device name)
  makes it the default.
- **Input**: the same for capture devices. Monitor sources are hidden: they
  are the recording end of an output, not a microphone.
- **Applications**: every app currently playing, with its own volume slider,
  mute button and a chip showing which output it plays through. Clicking the
  chip moves the app to the next output.

The bar at the top of the panel is a live output level meter for the default
sink. The speaker icon in the bar turns amber while the default output is
muted, so a mute done with the keyboard is visible without opening the panel.

State comes from PulseAudio's JSON interface (`pactl -f json`), not from
QuickShell's native Pipewire service: with PipeWire 1.6 and WirePlumber 0.5
the device volume no longer lives in the legacy `node.volume` property, so
QuickShell's `PwNodeAudioIface` reads zero and its writes are silent no-ops.
The native service is used for what it does work: the live level meter, taken
from the native peak monitor of the default sink. Every change made in the
panel is a normal PulseAudio call, so applications see it immediately.

One limitation: an app that talks to PipeWire natively (instead of through
the PulseAudio compatibility layer) picks its own output and cannot be moved
from the panel; its chip is shown dimmed and does nothing when clicked.

## Wallpapers

`Super+Alt+W` opens a QuickShell wallpaper picker: a dimmed overlay with a
target-monitor row, `LOCALES` / `WALLPAPER ENGINE` source tabs, and a preview
grid. Pick a monitor, switch source, and click a preview to apply it to that
monitor; each monitor keeps its own wallpaper. `Esc`, the backdrop, or the
close button dismisses it.

- **Locales** are images in `~/Pictures/Wallpapers` (png/jpg/jpeg/webp), each
  rendered by its own `mpvpaper` instance.
- **Wallpaper Engine** backgrounds are your Steam Workshop subscriptions under
  `steamapps/workshop/content/431960/<id>`, rendered by a single
  `linux-wallpaperengine` process. This requires Wallpaper Engine installed via
  Steam (with Proton) so the base assets are present, plus
  `linux-wallpaperengine` from the AUR.

While any window is fullscreen (a game), the renderers pause automatically so
they stop consuming resources: Workshop backgrounds via
`--fullscreen-pause-only-active`, and local ones via `mpvpaper -p -a FULL`.
Local images are rendered at each output's own size; pan-and-scan preserves the
aspect ratio and fills each screen by cropping its edges, so portrait displays
crop more of a landscape image.

The picker is driven by `mango/scripts/wallpaper-ctl.sh` (`list`, `apply`,
`restore`, `stop`); the per-monitor state map and renderer PIDs live under
`${XDG_STATE_HOME:-~/.local/state}/mango`.

`install.sh` copies `mango/wallpapers/default.png` into `~/Pictures/Wallpapers`
only when that directory holds no image yet, so an existing background is never
overwritten. Once you pick your own image with `Super+Alt+W` the default is
simply another entry in the list; delete it from `~/Pictures/Wallpapers` to
remove it.

## Zen Browser privacy

Zen Browser keeps its own appearance — the shell palette is **not** applied to
it, on purpose: the Material colours do not suit a browser chrome.

What the profile does ship is a hardened privacy configuration
(`zen/user.js`, applied by `mango/scripts/zen-config.sh`):

- telemetry off (`toolkit.telemetry.enabled`, `toolkit.telemetry.unified`,
  `datareporting.policy.dataSubmissionEnabled`, `datareporting.healthreport.uploadEnabled`),
- HTTPS-only mode, DNS over HTTPS, strict tracking protection and fingerprinting
  protection,
- camera, microphone, geolocation and notifications set to "ask".

The prefs are written straight into the profile's `prefs.js` because Firefox
only reads `user.js` while it is newer than `prefs.js` — and `prefs.js` is
rewritten on every shutdown. For the same reason the script refuses to run
while the browser is open:

```sh
mango/scripts/zen-config.sh          # apply
mango/scripts/zen-config.sh --check  # report what is missing
```

`zen/policies.json` holds the same guarantees as enterprise policies, which
enforce them on every start regardless of timestamps:

```sh
sudo cp ~/mango-desktop/zen/policies.json /opt/zen-browser-bin/distribution/policies.json
```

The policies are read on the next start of the browser.

## Vesktop theme

`vesktop/themes/mango.theme.css` is the shell palette applied to Discord:
charcoal surfaces, the green accent, soft corners and the shell's borders.

Vesktop has no theming of its own: Discord is restyled through Vencord, whose
theme files live in `<data>/themes` and are listed in
`<data>/settings/settings.json` under `enabledThemes`. The helper installs and
enables it:

```sh
mango/scripts/vesktop-theme.sh
```

Two details matter on the current Discord build, and they are why a theme that
only sets `--background-primary` looks like the default one:

- Discord exposes its own variable surface (`--app-frame-background`,
  `--background-base-*`, `--background-surface-*`, `--background-mod-*`,
  `--badge-*`, `--interactive-*`, …) and applies it **only** inside
  `@container root style(--colors: on)`. That container query needs both
  `@property --colors` and `container-name: root` on `:root`, otherwise it never
  matches.
- The theme must therefore define the palette slots Discord maps from
  (`--bg-1..4`, `--text-0..5`, `--accent-1..5`, `--hover`, `--active`,
  `--border`, …). The mapping block in `mango.theme.css` is adapted from
  midnight-discord (MIT).

Unlike the store themes (`midnight`, `system24`) this file fetches no
stylesheet and no font from the network.


## Screenshots

`Super+Shift+S` grabs a region into `~/Pictures/Screenshots`. The directory is
owner-only (`0700`) because screenshots routinely contain private content, and
a daily systemd user timer prunes files older than 3 days:

```sh
systemctl --user list-timers screenshot-cleanup.timer
```

The prune only ever touches `~/Pictures/Screenshots`; the wallpaper directory
that matugen samples for the palette is never modified.

## MangoHud

MangoHud is the in-game performance overlay. It is an overlay for the running
application, not a desktop-wide monitor: it draws inside the Vulkan/OpenGL
window of the app it is attached to. The shell's own dashboard keeps showing
system-wide CPU usage.

The configuration lives in `mango/mangohud/MangoHud.conf` and is linked to
`~/.config/MangoHud/MangoHud.conf` by the installer. It reuses the shell
palette (green accents over a deep charcoal surface) and is tuned for an
RX 7600 (Navi 33): GPU load, core and memory clocks, edge/junction/memory
temperatures, package power and VRAM usage out of 8 GB, aggregated
CPU load/frequency/temperature, system RAM, average and 1% low FPS,
frametime with its graph, the active FPS limit and the GPU throttling reason.
Per-core CPU rows are disabled (`core_load=0`, `core_bars=0`), so a 32-core
CPU does not turn the overlay into a wall of bars.

Read it like this: GPU at 99% with CPU at 30% means the game is GPU-bound and
the frame rate is capped by the card; CPU pinned at 100% with the GPU idle
means it is CPU-bound (draw calls, simulation); `THROTTLED` next to the
frametime graph means the card is power- or temperature-limited.

The three temperatures on the GPU row are not redundant: the plain value is
the edge temperature, the one marked `Jnc` is the junction (hotspot) and the
one on the VRAM row is the memory junction. All three are exposed by the
RX 7600 and they tell different stories — a card can sit at 70 °C edge while
its memory is already at 80 °C.

The graph at the bottom of the overlay is the frametime history in
milliseconds (green line, with `min`/`max` for the window shown) and the yellow
line marks the frames that were power-throttled. `throttling_status_graph`
draws that reason on the graph itself, next to the `throttling_status` text
in the frames column.

MangoHud can also draw proper charts with numbered axes through the
`graphs=` option, for example `graphs=gpu_load,cpu_load,gpu_temp`. It is off
by default because the overlay already reads well without it.

For Steam games, set the launch options of each game to:

```
mangohud %command%
```

With gamescope, keep the overlay inside the compositor's own layer:

```
gamescope -- mangohud %command%
```

Inside the app:

- `Shift_R+F12` toggles the HUD on and off.
- `Shift_R+F11` moves the HUD to another corner.
- `Shift_L+F4` reloads `MangoHud.conf` without restarting the app, so palette
  tweaks show up immediately.

For anything outside Steam, launch the app through the overlay directly:

```sh
mangohud firefox
```

## Firewall

The host firewall is plain `nftables` (`nftables/nftables.conf`): default-deny
inbound, allow all outbound, with explicit allowances for loopback, established
traffic, ICMP/ICMPv6, DHCP, mDNS and Steam LAN. Install it with:

```sh
sudo cp "$HOME/mango-desktop/nftables/nftables.conf" /etc/nftables.conf
sudo systemctl enable --now nftables.service
sudo nft list ruleset
```

## Rollback

Log out with Super+Shift+E, or exit the compositor normally. Stop only the
wallpaper renderers managed by this profile with:

```sh
"$HOME/mango-desktop/mango/scripts/wallpaper-ctl.sh" stop
```

The per-monitor state map and renderer PIDs are stored under
`${XDG_STATE_HOME:-~/.local/state}/mango`; remove that `mango` state directory
only if you also want to forget the chosen wallpapers. `./install.sh --uninstall` deliberately leaves `~/Pictures/Wallpapers`
alone, so a seeded `default.png` stays behind until you delete it yourself.
This profile links `~/.config/mango`,
`~/.config/vesktop`, `~/.zshrc` and the `screenshot-cleanup` and
`clipboard-expire` systemd user units, and sets Firefox as the XDG default;`./install.sh --uninstall` reverses exactly those links, while the Niri config
and `~/.config/quickshell` are never touched. Mango's explicit output rules
apply only while this profile is running.

## Validation

```sh
mango -c "$HOME/mango-desktop/mango/config.conf" -p
bash -n ./install.sh ./mango/scripts/power-menu.sh ./mango/scripts/wallpaper-ctl.sh ./mango/scripts/volume-osd.sh ./mango/scripts/zen-config.sh ./mango/scripts/screenshot-cleanup.sh ./mango/scripts/vesktop-theme.sh ./mango/scripts/clipboard-expire.sh ./mango/scripts/clipboard-menu.sh
bash ./tests/verify-hardening.sh
bash ./tests/verify-clipboard-expiry.sh
./install.sh --dry-run
unshare -rn nft -c -f ./nftables/nftables.conf
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
