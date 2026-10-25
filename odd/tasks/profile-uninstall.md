# Profile uninstall (full rollback + packages)

Objective: a standalone `uninstall.sh` that reverses everything `install.sh`
creates — symlinks, systemd user timers, wallpaper state, the running
quickshell panel — and additionally removes every package the installer
installs, so the machine returns to its pre-profile state. Test runner:
`bash ./tests/verify-uninstall.sh`.

## Specs

S1 — Symlink reversal reuses the installer. Route: inline. Checks:
`test_links_removed`.
The user's request: "Se puede crear un archivo que me desintale la config de mi
quickshell y los programas que instala?" with the chosen scope "Rollback
completo del perfil": "Revierte todo: symlinks, timers systemd, estado de
wallpaper (~/.local/state/mango), panel quickshell y paquetes."
Acceptance: `uninstall.sh` delegates link removal to `./install.sh
--uninstall` so the `remove_link` list can never drift; foreign paths (not
created by the installer) are left untouched.

S2 — Timers disabled before their unit links are removed. Route: inline.
Checks: `test_timers_disabled`.
Acceptance: `systemctl --user disable --now screenshot-cleanup.timer
clipboard-expire.timer` runs before `install.sh --uninstall`, and a
`daemon-reload` follows the link removal, so no dangling `timers.target.wants`
entries survive.

S3 — Runtime processes stopped. Route: inline. Checks: `test_processes_stopped`.
Acceptance: wallpaper renderers are stopped via `wallpaper-ctl.sh stop` (its
PID files validate `/proc` before signalling); the running panel is killed by
matching the fixed `$HOME/mango-desktop/quickshell/shell.qml` path — never
`$REPO_DIR`, so a test's scratch repo path can never match the real panel.

S4 — Wallpaper/theme state removed. Route: inline. Checks: `test_state_removed`.
The chosen scope names it verbatim: "estado de wallpaper
(~/.local/state/mango)".
Acceptance: `${XDG_STATE_HOME:-~/.local/state}/mango` is removed recursively;
nothing else under `.local/state` is touched.

S5 — Seeded wallpaper removed only when still the shipped copy. Route: inline.
Checks: `test_seeded_wallpaper`.
Acceptance: `~/Pictures/Wallpapers/default.png` is deleted only when
byte-identical to `mango/wallpapers/default.png` (i.e. still the installer
seed); a modified `default.png` and any other user wallpaper are kept, and the
`Wallpapers` directory is removed only when left empty (`rmdir`, never
recursive).

S6 — All installer packages removed. Route: inline. Checks:
`test_packages_removed`, `test_no_packages`.
The user chose "Todos los de install.sh": "Los 16 oficiales + 2 AUR: mangowm,
quickshell, foot, wofi, firefox, chromium, etc."
Acceptance: the installed subset of `REPO_PKGS + AUR_PKGS` (same lists as
`install.sh`) is removed with one `sudo pacman -Rns` call that keeps pacman's
own confirmation prompt (no `--noconfirm`); when none are installed, pacman is
never invoked.

S7 — Niri and foreign paths are never touched. Route: inline. Checks:
`test_niri_untouched`.
Constraint from AGENTS.md: "`~/.config/quickshell` belongs to the coexisting
Niri session and must never be touched."
Acceptance: `~/.config/quickshell` (fake Niri dir in the test), any foreign
path the installer skipped, and the repository itself all survive a full run.

S8 — `--dry-run` changes nothing. Route: inline. Checks: `test_dry_run`.
Acceptance: with every removable artifact present, a dry run prints its plan
and leaves links, state, wallpaper and packages untouched (no `rm`, no
`pacman -Rns`, no `systemctl disable` reach the system).

S9 — Idempotent. Route: inline. Checks: `test_idempotent`.
Acceptance: a second full run exits 0 and reports everything already absent.

S10 — Docs and validation wiring. Route: inline. Checks: `bash -n`,
`./install.sh --dry-run`, README/AGENTS grep.
Project convention (AGENTS.md): a new shell script goes into the `bash -n`
line of README's `## Validation`.
Acceptance: README `## Rollback` documents `./uninstall.sh`, README
`## Validation` and AGENTS.md's verify block gain `./uninstall.sh` in the
`bash -n` line and `bash ./tests/verify-uninstall.sh` as a probe.

## Tasks

T1 — This spec document (S1–S10). Route: inline.
T2 — `tests/verify-uninstall.sh`, hermetic RED probes, one `test_*` per S#.
Route: inline.
T3 — `uninstall.sh` at the repo root (GREEN). Route: inline.
T4 — README (`## Rollback`, `## Validation`) and AGENTS.md verify block (S10).
Route: inline.
T5 — Full verification suite plus `gentle_review` assess (item 1: deletes
state and removes packages). Route: inline.

## Log

L1 — Original request (verbatim): "Se puede crear un archivo que me desintale
la config de mi quickshell y los programas que instala?"

L2 — Scope decisions (user, via ask_user_question): "Rollback completo del
perfil" ("Revierte todo: symlinks, timers systemd, estado de wallpaper
(~/.local/state/mango), panel quickshell y paquetes. Deja la máquina como
antes del perfil.") and "Todos los de install.sh" ("Los 16 oficiales + 2 AUR:
mangowm, quickshell, foot, wofi, firefox, chromium, etc. Ojo: algunos pueden
servirte fuera de este perfil."). Constraints stated by the orchestrator and
accepted: `~/.config/quickshell` is Niri's and is never touched; the
quickshell panel config is never installed outside the repo, so "uninstalling
it" means stopping the panel and removing the package — there is no external
config path to delete.

L5 — Delivery: one commit holds T1–T4 on `feature/panel-stats-quiet-notifications`
(the repo's live working line; per AGENTS.md the checkout is the live config
via symlinks, so no branch switch under the running session). Pushed to
`origin/feature/panel-stats-quiet-notifications`. The user will exercise
`./uninstall.sh --dry-run` and the probes manually at a later session; that
manual pass replaces the refused independent verifier (see L4).
`vesktop/settings.json` and `zsh/.zshrc` were already dirty with unrelated
user changes and were deliberately left out of the commit.

L4 — Verification evidence: RED observed before implementation
(`uninstall.sh: No such file or directory`); GREEN after, all 10 probes
pass; full AGENTS.md verify block green (mango -p, bash -n, both existing
verify-*.sh, install.sh --dry-run, nft parse, git diff --check).
`gentle_review` assess returned risk=high with plan
{writerSelfVerification: true, independentVerifier: true} from the item-1
escalation. The gentle-ai-verify launch was refused by its admission gate
(the delegated task must carry a literal `Risk: item N` line) with an
explicit no-retry instruction, so independent verification is unavailable
and reported as missing proof instead of retried.

L3 — Evidence gathered before writing: `install.sh --uninstall` already
reverses exactly the nine links and leaves packages; `wallpaper-ctl.sh stop`
no-ops safely with no state (pid glob guarded by `[[ -e $f ]]`);
`install.sh` seeds `~/Pictures/Wallpapers/default.png` only when the directory
holds no images, so the seeded copy is identified by byte-compare against
`mango/wallpapers/default.png`. Zen privacy prefs and the Vencord theme are
applied without backup by the installer, so they cannot be reversed — the
script reports them as manual leftovers instead of guessing.
