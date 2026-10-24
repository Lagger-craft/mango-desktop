# Clipboard 72-hour expiry

Objective: delete clipboard history entries and clear the live clipboard after
72 hours without reuse, restarting each item's clock when it is re-copied or
re-selected from the picker. Branch `feature/clipboard-expiry`; delivery
strategy `ask-on-risk` (forecast ≈ 300 authored lines → one work-unit, under
the 400-line budget, so no chain-strategy question applies). Test runner:
`bash ./tests/verify-clipboard-expiry.sh`.

## Specs

S1 — Automatic 72-hour deletion. Route: inline. Checks:
`tests/verify-clipboard-expiry.sh` (`test_expiry`, `test_boundary`).
The user's request: "si es algo que supere las 72Hhrs desde que se copio por
priemra vez, debera de borrarse" and "si es una frase o una imagen o lo que sea
y no se vuelve a utilizarse en 72hrs debe de borrarse para limpiar la clipboard".
Acceptance: an entry whose recorded copy time is more than 72 hours old is
deleted from the cliphist history; an entry exactly 72 hours old survives.

S2 — Reuse restarts the clock. Route: inline. Checks: `test_recopy_resets_clock`,
`test_watch_stamps`, `test_picker_hides_expired`.
The user's request: "En cambio si se utiliza una misma varias veces pues debe de
reinciarse el contador de esa misma seccion", "si tengo en la clipboard una
imagen y en la clipboard la vuelvo a seleccionar para pegar de nuevo, el reloj
de esa misma foto debe de empezar de cero" and "Lo mismo que si es una frase y
la vuelvo a copiar para pegar nuevamente debe de reinciarse".
Acceptance: re-copying the same content, or selecting it again from the
`Super+V` picker, restarts that entry's 72-hour clock.

S3 — Scope: history plus the live clipboard. Route: inline. Checks:
`test_live_clipboard_clear`.
The user selected the option "Historial + portapapeles (Recomendado)": "se
borra la entrada de Super+V y, si es lo que está ahora en el portapapeles,
también se vacía el portapapeles".
Acceptance: when the selection's own clock runs out, the history entry is
deleted and the clipboard is emptied once, then that clock restarts.

S4 — Timer wiring. Route: inline. Checks: `bash -n`, `./install.sh --dry-run`.
The chosen option states: "Requiere un timer systemd nuevo siguiendo el patrón
de screenshot-cleanup".
Acceptance: `systemd/clipboard-expire.service` and `systemd/clipboard-expire.timer`
mirror the `screenshot-cleanup` units; `install.sh` links, enables and unlinks
them like the screenshot units.

S5 — Existing behavior preserved. Route: inline. Checks:
`test_watcher_behavior`, `test_picker_hides_expired`, `bash ./tests/verify-hardening.sh`.
The watcher keeps its documented bounds ("It retains at most 100 entries and
skips individual items larger than 1 MiB"), the picker toggle and cancel paths
keep working, `cliphist wipe` still clears everything, and no clipboard content
is logged, displayed or written anywhere.

S6 — Assumption (marked as assumption, not a user requirement): a plain `Ctrl+V`
paste of the current clipboard cannot be observed on Wayland, so it does not
restart the clock; the clock restarts only on a selection change (re-copying, or
re-selecting from the picker). An entry that predates this feature has no
recorded copy time: its clock starts when it is first observed — except the
newest entry (the current selection), which uses the last recorded selection
change.

## Tasks

- T1 (S1-S3, S6): probe tests first (RED), then `mango/scripts/clipboard-expire.sh` plus its `--watch` and picker hooks in `mango/scripts/clipboard-menu.sh` — inline — done — RED: `clipboard-expire.sh: No such file or directory` (exit 127); GREEN: `all probes pass` (7 probes).
- T2 (S4): `systemd/clipboard-expire.{service,timer}` and `install.sh` wiring — inline — done — `./install.sh --dry-run` plans both links, `daemon-reload` and `enable --now clipboard-expire.timer`.
- T3 (S5): README updates (clipboard paragraph, timers, rollback links, validation list) — inline — done.
- T4 (S1-S5): full checks (new suite, verify-hardening suite, `bash -n`, `mango -p`, `git diff --check`), work-unit commit, RDD assess — inline — in progress.

## Log

L1 (2026-10-23) — user's original request verbatim:
"Se puede hacer que la clipboard tenga una manera de limpiarse automaticamente. Osea si es algo que supere las 72Hhrs desde que se copio por priemra vez, debera de borrarse. En cambio si se utiliza una misma varias veces pues debe de reinciarse el contador de esa misma seccion. Es decir si tengo en la clipboard una imagen y en la clipboard la vuelvo a seleccionar para pegar de nuevo, el reloj de esa misma foto debe de empezar de cero. Lo mismo que si es una frase y la vuelvo a copiar para pegar nuevamente debe de reinciarse. Pero si es una frase o una imagen o lo que sea y no se vuelve a utilizarse en 72hrs debe de borrarse para limpiar la clipboard."

L2 (2026-10-23) — scope decision: one blocking question asked; the user chose
"Historial + portapapeles (Recomendado)" — delete the expired history entry and,
when it is the current selection, also empty the clipboard; this requires a new
systemd timer following the screenshot-cleanup pattern.

L3 (2026-10-23) — evidence gathered before writing: cliphist 0.7.0 has no
age-based pruning (only `-max-items` and `-max-dedupe-search`). Verified with
fake content in a scratch db: re-storing identical content deletes the old row
and inserts a new one with a new id at the top of `cliphist list`, so the newest
id after a store is the just-copied item; `cliphist delete` accepts several full
list lines in one call and exits 0 for missing ids; empty input is never stored.
`wl-paste --watch` runs its command on every selection change and once more
when a new watcher connects while content exists (probe discarded the bytes
without logging them); at login the selection is empty, so that first event only
refreshes the empty-selection clock. `wl-copy --clear` exists and
`WAYLAND_DISPLAY` is present in the systemd user manager environment, so the
timer can clear the live clipboard.

L4 (2026-10-23) — T1/T2/T3 evidence: RED observed before implementation
(`tests/verify-clipboard-expiry.sh` → exit 127, clipboard-expire.sh missing);
after implementation GREEN: `bash ./tests/verify-clipboard-expiry.sh` →
`all probes pass` (7 probes covering S1-S3, S5, S6). Full checks: `bash -n` on
install.sh and all helper scripts → OK; `bash ./tests/verify-hardening.sh` →
`all probes pass`; `mango -c … -p` → OK; `git diff --check` → OK;
`./install.sh --dry-run` → plans both clipboard-expire links, daemon-reload and
`enable --now clipboard-expire.timer`. Differential old-vs-new (fake content,
scratch caches): watcher stdout/stderr/exit and resulting history identical;
picker stdout/stderr/exit and displayed list identical; the only difference is
the new stamp file. No probe touched the real clipboard or the real cliphist
database.
