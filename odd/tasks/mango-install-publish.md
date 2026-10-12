# Feature: Mango autoinstall + GitHub publish

Objective: add an idempotent auto-install script with dependency resolution
(pacman first, yay/paru fallback for AUR), document it, and publish the
repository to a private GitHub repo.
Branch: `main` (local-only today; publish authorized as private repo
`mango-desktop`). Delivery strategy: stacked-to-main, one work-unit commit per
task. Test runner: `bash -n`, `install.sh --dry-run`, `mango -p`, `git diff --check`.

## Specs

- S1: Commit the pending, already-verified volume shortcut work that sits
  uncommitted in the worktree: `Super+Up / Super+Down` raise/lower volume by 5%
  and `XF86AudioRaiseVolume / XF86AudioLowerVolume` do the same from the
  hardware volume wheel, capped at 100% (`--limit 1.0`), plus their README rows.
  Record it in the existing `odd/tasks/chernobyl-mango-desktop.md` log.
- S2: Bind mute to the hardware wheel only: `XF86AudioMute` spawns
  `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`. No `Super+M`-style keyboard mute
  shortcut ("el mutear el volumen es innecesario de momento... si se puede
  aplicar el mutear a la rueda"). Add the README row.
- S3: `install.sh` at the repository root installs missing dependencies:
  official-repo packages via `pacman` (`mangowm quickshell foot wofi cliphist
  wl-clipboard grim slurp dunst firefox xdg-utils libnotify mpv`), then AUR-only
  packages via the first available helper among `yay` and `paru` (`mpvpaper`).
  It must detect helpers rather than assume one, `--needed`-install, and print a
  clear error if an AUR package is required and neither helper exists.
- S4: `install.sh` is idempotent and non-destructive ("Setup/rollback steps do
  not overwrite existing config paths"): it creates `~/.config/mango` as a
  symlink to the repo's `mango/` only when absent (refuses with instructions if
  a real directory exists), links `~/.config/dunst/dunstrc` to the repo theme
  only when absent or already pointing here, ensures `~/Pictures/Wallpapers`
  exists, sets the XDG default browser to Firefox only when unset or already a
  browser, and never touches Niri or `~/.config/quickshell`.
- S5: `install.sh --dry-run` prints every action (installed/missing packages,
  symlink targets) and mutates nothing; `install.sh --uninstall` reverses only
  what the installer created (symlinks pointing into this repo, nothing else)
  and leaves package installation alone, pointing to the README rollback for the
  rest.
- S6: The script validates the result with
  `mango -c "$HOME/.config/mango/config.conf" -p` when the link exists, and
  exits non-zero with an actionable message on any failed step.
- S7: README gains an `## Install` section documenting `./install.sh`,
  `--dry-run`, `--uninstall`, the pacman/yay/paru dependency policy, and that
  the script never overwrites an existing config path.
- S8: Publish to a **private** GitHub repository named `mango-desktop`
  (user-selected: "Privado (Recomendado)") and push the stacked work-unit
  commits. `gh auth login` must be re-run by the user first (current token for
  account `Lagger-craft` is invalid). No force-push, no PR, no public visibility.

## Tasks

- T1 (S1, inline): commit pending volume shortcuts + record in CM task doc.
- T2 (S2, inline): add wheel mute binding + README row.
- T3 (S3-S6, inline): write `install.sh` with `--dry-run`/`--uninstall`.
- T4 (S7, inline): README `## Install` section.
- T5 (S8, inline): user re-authenticates `gh`; create private repo; push.

## Log

- L1 (2026-10-12, user): "Sobre el punto 2 funciona todo eso correctamente.
  Sobre el mutear el volumen es innecesario de momento. El tema de la rueda para
  mover el volumen si funciona. aunque si se puede aplicar el mutear a la rueda.
  Tambien la idea era poder subirlo a un repo de github y tener un script de
  autoinstalacion. Junto con las dependencias que se necesitan. Tanto sea con
  yay o paru para poder descargar algunas de las dependencias si las necesita."
- L2 (2026-10-12, decision): repo visibility = private, name `mango-desktop`,
  chosen via direct question ("Privado (Recomendado)").
- L3 (2026-10-12, evidence): `mangowm 0.18.0-1`, `quickshell 0.3.2-1`, `foot`,
  `wofi`, `cliphist`, `wl-clipboard`, `grim`, `slurp`, `dunst`, `firefox` are
  official-repo packages; `mpvpaper 1.9-1` is foreign (AUR) per `pacman -Qm`,
  so the yay/paru branch is required. Both helpers are installed. `gh` token for
  account `Lagger-craft` is invalid (`gh auth status`).
- L4 (2026-10-12, evidence): all Mango bindings and scripts hardcode
  `$HOME/mango-desktop/...`; the installer therefore documents the clone path
  requirement at `~/mango-desktop`.
- L5 (2026-10-12, evidence): `install.sh` implemented with `--dry-run` and
  `--uninstall`; `bash -n` passed. Real run was idempotent (all packages
  present, both symlinks already correct, `mango -p` exit 0). Dry-run mutated
  nothing; `--dry-run --uninstall` printed the exact `rm` actions. Wrong clone
  path exits 1 with an actionable message. `chromium` was added to the official
  dependency list because `Super+Shift+W` spawns it. Dry-run output was made
  truthful: action-confirming notes (`linked/removed/set/parses cleanly`) no
  longer print when the action was only simulated.
