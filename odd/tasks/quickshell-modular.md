# Quickshell modular refactor

Objective: split the monolithic `quickshell/shell.qml` (621 lines) into focused modules, extracting low-risk units first and verifying each stage before the next. Branch: `refactor/quickshell-modular`. Delivery: local work-unit commits per green stage, final merge to `main` when all stages pass (no PR chain). Test runner: `qmllint` + quickshell hot-reload log check + `grim` screenshot diff.

## Specs

- **S1** Extract modules incrementally in ascending risk order, exactly as agreed: `Clock` (mínimo), `PowerButton` (mínimo), `VolumeOsd` (medio), `Tray` (medio-alto), `Tags` (alto), then final cleanup. Quote: "si se puede seria bueno ir haciéndola modular o por lo menos lo que tiene menos riesgo de romperse hacerlo modular y dejar lo de alto riesgo para el final".
- **S2** After each extraction, verify before touching the next module. Continue only when green. Quote: "Una vez que se vaya separando por modulos se va probando y si funciona y no muestra errores se continua con la siguiente implementacion". Green = all of: `qmllint` clean on every QML file; no new QML errors in `~/.local/share/sddm/wayland-session.log`; quickshell PID still alive after hot reload; screenshot shows the bar unchanged.
- **S3** Final layout: `quickshell/shell.qml` keeps `ShellRoot`, the shared `osd` Scope (cross-process FileView state), and the `Variants`/`PanelWindow` orchestrator only (~60-100 lines). New files: `quickshell/Clock.qml`, `quickshell/PowerButton.qml`, `quickshell/VolumeOsd.qml`, `quickshell/Tray.qml`, `quickshell/Tags.qml`.
- **S4** Pure refactor: zero visual or behavioral change. Same colors, layout, animations, tooltips, click behavior, tray menu async timing, OSD file protocol, and `mmsg` tag streaming. No restyling, no new features.
- **S5** Sub-split of Tags.qml (user-approved): extract `SkullTag.qml` holding the skull art (bitmap + outline computation) and the per-tag delegate rendering; click dispatches through a `tagClicked(int)` signal handled by Tags.qml. Tags keeps `tagState`, the `mmsg` processes, and the bar layout.

## Tasks

| ID | S# | Route | Status | Commit |
|----|----|-------|--------|--------|
| T1 | S1,S2,S4 | inline | verified | 5c0b9c5 |
| T2 | S1,S2,S4 | inline | verified | 03254d7 |
| T3 | S1,S2,S4 | inline | verified | bd3bd76 |
| T4 | S1,S2,S4 | inline | verified | a4da16f |
| T5 | S1,S2,S4 | inline | verified | 82a2cec |
| T6 | S3,S2,S4 | inline | verified | 48492c6 |
| T7 | S5,S2,S4 | inline | verified | 4b04c5d |

Route note: every stage is a small, fully-understood extraction verified inline (qmllint + reload log + screenshot); no parallel units and no context backstop, so no writer delegation trigger fires.

## Log

- **L1** (user, original request): "Me gusta el orden que me muestras de como deberia de quedar. Pero si se puede seria bueno ir haciéndola modular o por lo menos lo que tiene menos riesgo de romperse hacerlo modular y dejar lo de alto riesgo para el final. Una vez que se vaya separando por modulos se va probando y si funciona y no muestra errores se continua con la siguiente implementacion"
- **L2** (user decision): checkpoint strategy = feature branch + one conventional commit per verified stage, merge to `main` at the end.
- **L3** Environment: quickshell runs with `--path quickshell/shell.qml` (PID from `exec_once` in `mango/config.conf:60`), `Quickshell.watchFiles` defaults to true → hot reload on save; errors log to `~/.local/share/sddm/wayland-session.log`; baseline `qmllint quickshell/shell.qml` = exit 0, no output.
- **L4** (T2): `qmllint` gives a FALSE GREEN on Quickshell module types — it missed `Process is not a type` (fixed by `import Quickshell.Io`). The authoritative check is the session log after lint.
- **L5** (T2): after failed config loads the hot-reload watcher stops firing entirely (even real content edits). Recovery: restart quickshell — `kill <pid>` then `setsid -f quickshell --path $HOME/mango-desktop/quickshell/shell.qml >> ~/.local/share/sddm/wayland-session.log 2>&1`. Each instance gets a fresh qslog under `/run/user/1000/quickshell/by-id/<id>/`.
- **L6** (T2): botched probe-line cleanup left `}1792038805` at EOF → one extra failed load (`Unexpected token numeric literal`), fixed before restart. New instance loads clean.
- **L7** (T5): verified with a 600x40 pixel crop of the left bar, baseline vs post-change — identical (ZONE, 9 skulls with active green, screen name, clock). The 3 `mmsg watch tags` processes (DP-1, DP-2, HDMI-A-1) run from inside Tags.qml, proving the extracted stream populates tagState.
- **L8** (T3/T6): OSD verified functionally twice: `volume-osd.sh` trigger and manual state-file write (`HDMI-A-1 0.42 0`) → popup renders "VOLUME 42%". Note: screenshots are 5560x1920 (3 outputs: 1920+2560+1080); bottom-right OSD crop zones must account for output scale — a black crop does not prove absence, always confirm on the full frame.
- **L9** (T6): `shell.qml` final = 115 lines, pure orchestrator (ShellRoot > osd Scope + Variants > PanelWindow > VolumeOsd/Tags/Clock/Tray/PowerButton). Total QML: 672 lines across 7 files (was 621 in 1). Unused imports after extraction: `Quickshell.Services.SystemTray`, `QtQuick.Controls`.
- **L10** (user): tray interactions confirmed working by the user — left and right click, "sin ningún problema". This closes the interaction verification gap left open at T4/T5 close.
- **L11** (user decision): sub-split Tags.qml. Verdict was that the problem is NOT the same as the original T5 — state/protocols already isolated, only pure rendering moves. Result: Tags.qml 100 lines (state + mmsg + layout), SkullTag.qml 127 lines (art + delegate + `tagClicked` signal), pixel-identical skulls after reload. Note: T7 committed directly on `main` (single verified stage after the branch was merged).
