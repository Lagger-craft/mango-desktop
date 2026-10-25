# AGENTS.md

Personal Arch Linux MangoWM desktop profile: declarative compositor config, a
Quickshell QML panel, shell-script helpers, systemd user timers, and app
dotfiles. No build system, no lint, no typecheck, no CI — verification is
config parsing plus the hermetic shell probes below. `README.md` is the full
user-facing reference; this file only records what an agent would otherwise
get wrong.

## Where to work

- The git repo root is `$HOME/mango-desktop` — one level above the `mango/`
  directory. Sessions may start inside `mango/`; run repo commands from the
  repo root.
- Config and scripts reference each other through hardcoded
  `$HOME/mango-desktop/...` paths (`mango/config.conf` binds and `exec_once`,
  systemd `ExecStart=%h/mango-desktop/...`, `quickshell/shell.qml`,
  `mango/scripts/*.sh`). Moving or renaming the checkout breaks everything and
  `install.sh` refuses any other location. Tests fake it by symlinking the
  repo into a scratch `$HOME`.
- `quickshell/shell.qml` is launched by absolute path from
  `mango/config.conf` (`exec_once=quickshell --path ...`). `~/.config/quickshell`
  belongs to the coexisting Niri session and must never be touched.

## Verify before claiming done

Run from the repo root; all are fast (~1 s total) and independent:

```sh
mango -c "$HOME/mango-desktop/mango/config.conf" -p   # compositor config parses
bash -n ./install.sh ./mango/scripts/*.sh             # shell syntax (no shellcheck here)
bash ./tests/verify-hardening.sh                      # zen prefs, nftables, screenshot prune
bash ./tests/verify-clipboard-expiry.sh               # clipboard expiry end-to-end
./install.sh --dry-run                                # installer preview
unshare -rn nft -c -f ./nftables/nftables.conf        # firewall parses in a throwaway netns
git diff --check
```

- The tests are hermetic: each redirects `$HOME` to `mktemp -d`, stubs
  wofi/wl-copy/cliphist as needed, and never touches the real profile,
  clipboard, or firewall. Safe to run anytime; no session or services needed.
- QML has no test runner. Panel behavior must be exercised in a live Wayland
  session (`quickshell ipc -p $HOME/mango-desktop/quickshell/shell.qml call
  <name> toggle`). `qmllint quickshell/*.qml` is clean except `shell.qml`'s
  silent exit 255 — a recorded baseline false positive, not a failure.
  Quickshell hot-reloads QML edits (a failed load kills the watcher; restart
  with `setsid -f quickshell --path …`). `mmsg get all-monitors`'s `active`
  flag follows the user's focus and changes between probes: query the focused
  monitor in the same breath as any screenshot or popup test.
- When adding a shell script: include it in the `bash -n` line of README's
  `## Validation`, and when it gets installed, in **both** the link and
  `remove_link` lists of `install.sh`.

## Architecture wiring (not visible from filenames)

- `mango/config.conf` is the single entrypoint: `exec_once` starts wallpaper
  restore, the Quickshell panel, and the clipboard watcher; every Super-bind
  spawns a script by absolute path under `mango/scripts/`.
- Theme pipeline: `wallpaper-ctl.sh apply` runs matugen once and writes
  `${XDG_STATE_HOME:-~/.local/state}/mango/theme.json`; Quickshell watches
  that file. Never sample the wallpaper per frame, and a malformed palette
  must keep the previous theme.
- Volume OSD is file-based IPC: `volume-osd.sh` performs the `wpctl` action
  and writes `<monitor> <volume-fraction> <muted-0-or-1>` to
  `$XDG_RUNTIME_DIR/mango-volume-osd`; each screen's popup watches it.
- Audio panel state comes from `pactl -f json`, **not** Quickshell's native
  Pipewire service: on PipeWire 1.6 / WirePlumber 0.5, `node.volume` no
  longer exists, so `PwNodeAudioIface` reads zero and its writes silently
  no-op. Only the native peak meter is used. Do not "fix" this back.
- Panel stat bubbles and the dashboard SYSTEM card bind to the
  `quickshell/SysStats.qml` singleton (procfs + amdgpu sysfs, 2 s poll, one
  one-shot GPU node probe at startup). Never add per-view stat parsing or
  extra polling processes; a missing GPU node degrades the bubble to "n/a".
- Notifications are deliberately silent: `NotificationDaemon.qml` is a
  history-only owner (no toasts, no bell, no DND — the dashboard card is the
  only view). Do not reintroduce popups or advertise notification actions/
  images, which no view can present.
- Bar islands are 30 px bands: every right-island action-row child fills
  30 px and centers its content. A shorter bare `Row` child top-aligns and
  rides over the island's top accent line (real bug, fixed in 4dfb5d6).
- Nerd Font icons in QML are literal glyph characters: `"\uF035B"` is
  `\uF035` + "B" (JS `\u` escapes take exactly 4 hex digits), so escapes
  silently render as stray symbols plus letters. Use literal glyphs like the
  rest of the repo.
- Per-monitor wallpaper state and renderer PIDs live under
  `${XDG_STATE_HOME:-~/.local/state}/mango`, managed only by
  `wallpaper-ctl.sh`.

## Conventions and invariants

- `install.sh` must stay idempotent and non-destructive: it never overwrites
  an existing path (reports `SKIP`), sets the XDG default browser only when
  none exists, and `--uninstall` reverses exactly what install created.
- `tests/verify-*.sh` functions are named `test_*` and map 1:1 to `S#` spec
  items in `odd/tasks/<feature>.md` (ODD feature docs; read `## Log` last).
  Keep new behavior tracked the same way.
- Project code performs no network requests — preserve that guarantee.
- `vesktop/settings.json` and `vesktop/state.json` are tracked but rewritten
  by the running app; expect them dirty and review before committing.
  `vesktop/sessionData/` and other runtime state stay ignored.
- Commit style: conventional commits with scopes (`feat(desktop):`,
  `fix(audio):`, `docs(desktop):`); no AI attribution.
- `.atl/skill-registry.md` is the auto-generated skill index for delegation —
  do not hand-edit.
