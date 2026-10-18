# Feature: Unified QuickShell wallpaper picker (local + Wallpaper Engine)

Objective: replace the Wofi wallpaper menu with one QuickShell overlay picker
that browses both local images and Steam Workshop Wallpaper Engine backgrounds,
applies a chosen wallpaper to a selected monitor, pauses Workshop backgrounds
while a game is fullscreen, and restores per-monitor state on login.
Branch: `feature/wallpaper-picker` off `main` (baseline `c4564ce`). Delivery
strategy: stacked-to-main, one work-unit commit per unit. Test runner:
`bash -n`, `mango -p`, `wallpaper-ctl.sh` subcommand smoke tests against a
`mktemp -d` scratch state, `git diff --check`.

## Specs

- S1: Remove `mango/scripts/wallpaper-selector.sh` (the Wofi static selector).
  Add `mango/scripts/wallpaper-ctl.sh`, a controller with subcommands:
  `list` (emit JSON describing both sources), `apply <monitor> <type> <ref>`
  (set one monitor's wallpaper, persist, relaunch renderers), `restore`
  (relaunch all renderers from persisted state; used by `exec_once`), and
  `stop` (kill every renderer this profile manages). Wofi is no longer used for
  wallpaper selection (it stays for the launcher, clipboard, and power menus).
- S2: Persist state as a per-monitor JSON map at
  `${XDG_STATE_HOME:-$HOME/.local/state}/mango/wallpapers.json`, where each key
  is a monitor name and each value is `{"type":"local"|"we","ref":"<path|workshop-id>"}`.
  `restore` rebuilds renderers only for monitors still present and skips refs
  whose file/id no longer resolves; `list` reads nothing from this file.
- S3: `apply` supports two renderers from the same state map: `local` images run
  through `mpvpaper` (one instance per output, `<output> <path>`), and `we`
  backgrounds through one `linux-wallpaperengine` process using repeated
  `--screen-root <monitor> --bg <id>` pairs. Applying any single monitor
  rebuilds the whole renderer set from state so the two renderers never
  overlap on one output. `stop` kills by saved PID and verifies `/proc/<pid>/comm`
  before signalling (PID-reuse safe, matching the prior script's discipline).
- S4: Both renderers pause natively while a window is fullscreen: every `we`
  renderer launches with `--fullscreen-pause-only-active` (pauses only when the
  fullscreen window is active/focused), and every `local` `mpvpaper` instance
  keeps the prior `-p -a FULL` flags (`--auto-pause --auto-mode FULL`, pause when
  any window is fullscreen). No manual fullscreen detection loop is written.
- S5: Add `quickshell/WallpaperPicker.qml`: a fullscreen dim overlay in the
  existing Control Room aesthetic (`#171a17` surface, `#9bd45a` accent,
  `#e5e8dc`/`#e4dfcf` text, monospace font, skull/radioactive motif). It shows
  a monitor selector row (from `Quickshell.screens`), two source tabs
  `LOCALES` / `WALLPAPER ENGINE`, and a preview grid (Workshop `preview.jpg`
  and local thumbnails). Activating a preview calls
  `wallpaper-ctl.sh apply <monitor> <type> <ref>` for the selected monitor.
- S6: The picker is toggled by `Super+Alt+W` through
  `quickshell ipc call wallpaper toggle`, wired to an `IpcHandler` named
  `wallpaper` in `shell.qml`. It shows only on the active monitor, determined
  from `mmsg get all-monitors` (`"active":true`), and reloads the preview grid
  from `wallpaper-ctl.sh list` each time it opens.
- S7: Update `mango/config.conf` (`exec_once` now runs
  `wallpaper-ctl.sh restore`; the `Super+Alt+W` bind spawns the IPC toggle),
  add `linux-wallpaperengine-git` (AUR) and `jq` (official) to `install.sh`
  dependencies, and refresh `README.md` + `mango/scripts/shortcut-reference.sh`
  so no reference to the removed Wofi selector remains.

## Tasks

- T1 (S1-S4, done `db3275a`, inline): write `mango/scripts/wallpaper-ctl.sh`
  (list/apply/restore/stop + per-monitor JSON state + dual renderer). Route:
  inline (sequential, full context, no parallel-unit reason).
- T2 (S5-S6, inline): write `quickshell/WallpaperPicker.qml` and wire the
  `IpcHandler` + active-monitor overlay into `quickshell/shell.qml`.
  Route: inline (sequential; depends on T1's `list`/`apply` contract).
- T3 (S7, inline): config.conf, install.sh, README, shortcut-reference updates.

## Log

- L1 (2026-10-17, user): "Una duda, se puede llegar integrar
  wallpaperengine-linux en la quickshell al momento de escoger un wallpaper,
  asi hay dos ventanas una con local y la otra de wallpaper engine y asi poder
  utilizar los wallpapers que esten instalados por el softrware en stema."
- L2 (2026-10-17, user): "Ya instale wallpaper engine en steam con proton,
  Tambien instale linux-wallpaperengine con yay. Solo faltaria hacer la
  integracion con la quiickshell, para poder tener un menu que me permita
  seleccionar un wallpaper. La idea esque me permita pausar el wallpaper para
  cuando tenga un juego en fullscreen y asi no consuma tantos recursos. Ademas
  seleccionar el monitor a cual debe de ap[licarse."
- L3 (2026-10-17, decision): UI = QuickShell grid overlay (not Wofi submenus).
  User: previews are poor in Wofi, viable in QuickShell. Orchestrator corrected
  the "keep everything integrated" framing: the split is by task type (command
  menus stay Wofi; visual browsing becomes a QML grid), and QuickShell is
  already a project dependency.
- L4 (2026-10-17, user): "Entoncees tendriamos que quitar wofi para la
  seleccion de wallpapers estaticos, entonces asi solo quedaria el panel de
  quickshell, ademas se podria tratar de tener una estetica relacionada con mi
  sistema."
- L5 (2026-10-17, evidence): `linux-wallpaperengine --help` confirms native
  fullscreen pause (`--fullscreen-pause-only-active`,
  `--fullscreen-pause-ignore-appid`) and per-monitor `--screen-root <mon>
  --bg <id>` pairs. `mmsg get all-monitors` returns HDMI-A-1/DP-1/DP-2;
  `mmsg get all-clients` exposes `is_fullscreen`. Steam Workshop app 431960 has
  45 items, each with `preview.jpg`; assets live under
  `~/.local/share/Steam/steamapps/workshop/content/431960/<id>`. `jq` 1.8.2 and
  `linux-wallpaperengine-git` are installed. QuickShell 0.3.x exposes
  `IpcHandler` + `quickshell ipc call`, and `FloatingWindow`/`PanelWindow`.
- L6 (2026-10-17, baseline): prior uncommitted work committed as `c4564ce`
  `fix(desktop): harden wallpaper restore and seed default background` on
  `main` (user authorized: "Si puedes comitear el trabajo, ya que funciona
  correctamente. Ademas es necesario que quede como respaldo por si se aplica la
  nueva integracion con wallpaper engine y no funciona se pueda hacer un
  rollback."). `vesktop/state.json` left dirty (app window-size noise). Feature
  branched `feature/wallpaper-picker` off `c4564ce`.
- L7 (2026-10-17, evidence): `mpvpaper -p -a FULL` decodes to
  `--auto-pause --auto-mode FULL` ("pause mpv when the wallpaper is hidden …
  trigger when any window is fullscreen"), so local wallpapers pause on
  fullscreen natively just like Workshop ones — S4 updated to cover both.
  `project.json` exposes root keys `title`/`preview`/`type`, so real titles
  ("8-bit Waterfalls") and the exact `preview.jpg`/`preview.gif` filename are
  readable; 25 items use jpg, 20 gif.
- L8 (2026-10-17, T1 evidence): `bash -n` passed. Stubbed smoke test in a
  `mktemp -d` scratch (fake workshop + local dir, PATH stubs for
  `linux-wallpaperengine`/`mpvpaper`/`mmsg`) verified: `list` emits both
  sources with titles/types/preview; `apply DP-1 we <id>` records state and
  calls `linux-wallpaperengine --screen-root DP-1 --bg <id>
  --fullscreen-pause-only-active`; adding `apply HDMI-A-1 local <path>` keeps
  both renderers coexisting (lwe for DP-1, mpvpaper for HDMI-A-1); `restore`
  with empty state seeds the fallback across all three monitors from `mmsg`;
  `stop`, the usage message, and an unknown Workshop id error all behave.
  Committed as `db3275a`. Scratch removed.
