# Feature: Mango volume OSD popup

Objective: show a small animated on-screen display when volume is raised,
lowered, or muted, styled like the rest of the Chernobyl desktop.
Branch: `main` (published, private repo `Lagger-craft/mango-desktop`).
Delivery strategy: stacked-to-main, one work-unit commit per task.
Test runner: `bash -n`, `mango -c <abs> -p`, QuickShell runtime load on
`wayland-0`, `git diff --check`. The popup itself is Wayland-visual and has no
deterministic unit test; the state-file writer is validated by parsing the live
`wpctl get-volume` output.

## Specs

- S1: A helper `mango/scripts/volume-osd.sh <up|down|mute>` performs the
  `wpctl` action (5% step, `--limit 1.0`, mute toggle) and then atomically
  writes one line `<monitor> <volume-fraction> <muted-0-or-1>` to
  `${XDG_RUNTIME_DIR}/mango-volume-osd` (temp file + `mv`). The monitor is the
  compositor-focused one, from `mmsg get all-monitors` (`"active":true`),
  parsed with `sed`/`grep` only — no new dependency on `jq`.
- S2: All four volume/mute keybindings in `mango/config.conf`
  (`Super+Up/Down`, `XF86AudioRaiseVolume/LowerVolume/Mute`) spawn the helper
  instead of calling `wpctl` inline.
- S3: The QuickShell bar shows a `PopupWindow` OSD, bottom-right of the focused
  screen, when the state file's monitor matches that screen: charcoal surface
  matching the bar, green/amber Chernobyl accent, percentage text and a
  progress bar; muted state renders distinctly (amber). It auto-hides after
  ~1.5 s and re-shows on every state change (rapid wheel steps keep it up).
- S4: The QML watches the state file with `FileView.watchChanges`, reads
  `XDG_RUNTIME_DIR` via `Quickshell.env`, tolerates a missing file at startup
  (`printErrors: false`), and does not touch the existing panel layout,
  exclusive zone, or tray.
- S5: README documents the OSD in Controls and the helper in Validation.

## Tasks

- T1 (S1-S5, inline): helper script + config bindings + QML OSD + README.
- T2 (inline): live validation (parser, runtime load, `bash -n`, `git diff
  --check`), restart the project QuickShell, commit and push.

## Log

- L1 (2026-10-12, user): "la opcion A se ve mucho mejor" — chose the QuickShell
  OSD (option A) over a Dunst progress notification, after I presented the
  tradeoff (system state vs. messaging; Dunst rules interference).
- L2 (2026-10-12, evidence): `mmsg get all-monitors` exposes `"active":true`
  for the focused monitor, so the helper can target the OSD to the right screen
  without jq (`sed 's/{"name"/\n{"name"/g' | grep '"active":true'`). Docs
  `/websites/quickshell_v0_3_1` confirm `PopupWindow`+`anchor.rect`,
  `FileView.watchChanges` + `reload()`, and `Quickshell.env(variable)`.
  `pactl`, `notify-send` and Dunst 1.13.2 are present but unused for this
  feature (user rejected option B).
- L3 (2026-10-12, evidence): two implementation gotchas found and fixed.
  (1) `wpctl` rejects `@DEFAULT_AUDIO_SINK@` when the trailing `@` is missing,
  so the helper's sink variable must be `@DEFAULT_AUDIO_SINK@` (20 chars); the
  first version had a typo that failed at runtime. (2) `ShellRoot` rejects a
  direct `QtObject` child ("Cannot assign to non-existent default property");
  the shared OSD state must live in a `Scope`. Live validation: `mango -p`
  exit 0, `bash -n` exit 0, `git diff --check` exit 0, QuickShell logged
  `Configuration Loaded` with zero errors/warnings on `wayland-0`, and the
  helper wrote `HDMI-A-1 0.60 0` (then restored volume to 0.55) with no
  follow-up errors in the new shell's log. The live QuickShell instance was
  restarted (pid 211174 -> 476677) to load the OSD.
