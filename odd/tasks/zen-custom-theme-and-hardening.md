# Zen custom theme + desktop hardening

## Specs

- S1: "Seria bueno tener custom zen browser" — Zen Browser (1.23.2b, `zen-browser-bin`)
  must render its UI with the same Material palette the shell already uses.
  **Superseded 2026-10-19 (L7):** the user saw the result and decided the Material
  colours look wrong in a browser chrome — Zen keeps its own appearance. The spec now
  covers the privacy configuration only.
- S2: The palette source is the existing matugen output, not a new pipeline:
  "matugen puede leerlo para sacar los colores del wallpaper".
- S3: The browser theme must follow the wallpaper automatically when the wallpaper changes.
  **Superseded by S8.**
- S4: "se puede hacer que se limpien cuando pasen 3 dias" — screenshots older than 3 days are
  deleted automatically. The cleanup must never touch the wallpaper source matugen samples from.
- S5: "dame el comando para poder ejecutarlo y la explicacion" — screenshot directory permissions
  must be tightened to owner-only, and the exact command explained.
- S6: "entre varias alternativas cual me recomiendas y como se deberia de configurar" — one
  firewall recommendation with a ready-to-install configuration.
- S7: Telemetry prefs must stay disabled; the actual current state must be verified and reported
  with evidence, not assumed.
- S8: "dejar como esta por defecto el tema, pero colocar config para mayor seguridad y privacidad"
  — Zen keeps its default appearance; only the privacy/security configuration is applied, and it
  must actually take effect (not just be written and silently ignored).
- S9: "personalizar vesktop, creando un tema con el estilo de mi sistema" — a Discord theme with
  the shell's palette, self-contained (no remote stylesheet imports).

## Tasks

- T1 (S1, S2, S3) — Zen theming: **closed, superseded** (`zen/userChrome.css.template` and
  `mango/scripts/zen-theme.sh` removed in L7).
- T1b (S8) — Zen privacy config: `zen/user.js` (source of truth), `mango/scripts/zen-config.sh`
  (writes the prefs into the profile's `prefs.js`), `zen/policies.json` (enterprise policies).
  Route: inline.
- T2 (S4, S5) — Screenshot retention: `mango/scripts/screenshot-cleanup.sh`,
  `systemd/screenshot-cleanup.{service,timer}`, `mango/scripts/screenshot-area.sh` hardening.
  Route: inline.
- T3 (S6) — Firewall: `nftables/nftables.conf` (nftables, not firewalld/ufw) + install commands.
  Route: inline.
- T4 (S7) — Pref audit and hardening: `zen/user.js` telemetry/privacy prefs, evidence in Log.
  Route: inline.
- T5 (S9) — Vesktop theme: `vesktop/themes/mango.theme.css` + `mango/scripts/vesktop-theme.sh`.
  Route: inline.

## Log

- L1: "Sabes si se puede mejorar la apariencia de zen-browser segun mi sestema o no es viable.
  Ademas de ver si hay algo que se pueda optimizar de mango si esque es necesario y merece la pena
  el esfuerzo, ademas de ver si hay algo que mejorar en el apartado de seguridad"
- L2: "Ya active la de view.use-single-toolbar de zen. Seria bueno tener custom zen browser."
- L3: "Sobre las screenshot, se puede hacer que se limpien cuando pasen 3 dias. Siempre y cuando
  sea las que estan hechas con matugen."
- L4: "Sobre el firwall, si e pensado lo mismo, pero entre varias alternativas cual me recomiendas y
  como se deberia de configurar."
- L5: "Ambas sobre telemetria estan bloqueadas. Alguna estan en false."
- L6: "Tambiens obre los permisos de las screenshot dame el comando para poder ejecutarlo y la
  explicacion, ademas hay que ver si matugen puede leerlo para sacar los colores del wallpaper."
- L7: "Si se aplica, pero no como los otros navegadores, puedes dejar como esta por defecto el tema,
  pero colocar config para mayor seguridad y privacidad, ya que con matugen se ve rarisimo los
  colores. Lo que si tambien se podria hacer es personalizar vesktop, creando un tema con el
  estilo de mi sistema."

### Analysis (2026-10-19)

- Zen 1.23.2b exposes its design tokens as `--zen-*` CSS custom properties. Verified by extracting
  `chrome/browser/content/browser/zen-styles/*` from `/opt/zen-browser-bin/browser/omni.ja`:
  `--zen-primary-color`, `--zen-main-browser-background`, `--zen-navigator-toolbox-background`,
  `--zen-urlbar-background`, `--zen-dialog-background`, `--zen-colors-input-bg`,
  `--zen-colors-border`, `--zen-input-border-color`, `--zen-accent-button-background`,
  `--zen-accent-button-color`, `--zen-loading-progress-bar-color`, `--zen-branding-dark`.
  `--zen-primary-color` defaults to the system `AccentColor` and every other surface is derived
  from it with `color-mix`, so overriding it plus the base surfaces recolors the whole UI.
- `userChrome.css` support requires `toolkit.legacyUserProfileCustomizations.stylesheets=true`
  (Zen docs: Live Editing Zen Theme). The active profile has no `chrome/userChrome.css` today and
  `zen.themes.disable-all=true`.
- Palette source: `mango/scripts/wallpaper-ctl.sh` samples the wallpaper image (or the Workshop
  preview) with matugen and writes `~/.local/state/mango/theme.json` (28 tokens). Screenshots in
  `~/Pictures/Screenshots` are NOT a matugen input, so pruning them cannot change the theme.
- Zen profile directory name is dynamic (`y2h5enmo.Default (release)`); the generator resolves it
  from `~/.config/zen/profiles.ini` and falls back to the profile with the newest `prefs.js`.
- Telemetry evidence (2026-10-19, `prefs.js` of the active profile): `toolkit.telemetry.enabled`,
  `toolkit.telemetry.unified` and `datareporting.policy.dataSubmissionEnabled` are **absent**, i.e.
  they keep their defaults (`true`). Only `toolkit.telemetry.reportingpolicy.firstRun=false` is set,
  which merely means the policy dialog was already shown. The user's belief that both telemetry
  prefs are already blocked does not match the profile. They are now pinned to `false` in
  `zen/user.js`.
- Firewall recommendation: plain `nftables` (`inet filter` table). `firewalld` is not installed and
  is not in the Arch repos used here; `ufw` is not installed either and is an iptables-legacy
  wrapper. `nftables.service` exists and is disabled, with a stock `/etc/nftables.conf`.

### Verification (2026-10-19)

- Independent verifier (gentle-ai-verify) over commits `a41f38a` and `28e1732`: S1–S7 all MET,
  **0 blockers**. Probes ran in scratch directories outside the workspace.
- One advisory, accepted and fixed: `find -mtime +3` floors the age to whole days, so pruning
  happened at ~96h instead of 72h. The cleanup now uses `-mmin +4320` (exact 72h).
- The verifier's probes are committed as `tests/verify-hardening.sh`
  (`bash tests/verify-hardening.sh` → `all probes pass`).
- Not verifiable headlessly: Zen actually applying the CSS (needs a GUI restart). The generated
  `chrome/userChrome.css` and the `user.js` symlink were verified on disk.
- Native review was not run: the clone-local receipt-driven development switch is **off**
  (`gentle-ai review mode status` → `off (decided by clone_local)`), so delivery stays under
  ordinary repository policy.

### Round 2 (2026-10-19, after L7)

**Zen theming removed.** `zen/userChrome.css.template` and `mango/scripts/zen-theme.sh` were
deleted, the generated `chrome/userChrome.css` removed from the profile, and the hook in
`wallpaper-ctl.sh` reverted. Zen keeps its own appearance.

**Why the prefs had never applied.** Firefox only reads `user.js` while it is newer than
`prefs.js`, and `prefs.js` is rewritten on every shutdown — so the symlinked `user.js` was
silently ignored (evidence: `toolkit.telemetry.enabled` was absent from `prefs.js`). The prefs
are now written directly into `prefs.js` by `mango/scripts/zen-config.sh`, which refuses to run
while the profile is in use (`.parentlock` / a live `zen-bin` on that profile), because the
browser rewrites `prefs.js` from memory when it exits and would drop the injected lines.
`zen/policies.json` is the tamper-resistant alternative (enterprise policies, read at every
start, root-owned at `/opt/zen-browser-bin/distribution/policies.json`).

**Vesktop theme.** `vesktop/themes/mango.theme.css` maps the shell tokens onto Discord's
current variable surface. Findings from the debugging session (all verified by restarting
Vesktop and sampling the rendered pixels):

- Vencord **is** active in this install (`sessionData/vencordFiles/`, plugins start in the
  renderer log) and its data directory is `~/.config/vesktop` — which this repo symlinks — so
  `vesktop/settings/settings.json` (`enabledThemes`) and `vesktop/themes/*.theme.css` are the
  live paths.
- Vencord loads a local theme with `@import url("vencord:///themes/<file>?v=<ts>")`; the file
  must end in `.css` and the `enabledThemes` entry must be the **file name**. The header block
  between the first `/**` and `*/` supplies `@name`/`@version`; prose inside that block
  pollutes `@version`, so it must stay outside.
- Discord's current build **does not read** `--background-primary` / `--brand-experiment` for
  its surfaces any more. It exposes its own variable surface and applies it only inside
  `@container root style(--colors: on)`, which requires `@property --colors` **and**
  `container-name: root` on `:root` (plus `container-name: body` on `body`). Without the
  container names the query never matches and the theme renders exactly like the default one.
- The palette slots Discord maps from are `--bg-1..4`, `--text-0..5`, `--accent-1..5`,
  `--hover`, `--active`, `--active-2`, `--message-hover`, `--border`, `--border-light`,
  `--border-hover`, `--button-border`, `--green/red/blue/yellow/purple-1..5` and
  `--accent-new`. The mapping block is adapted from midnight-discord (MIT).
- Result verified: the window renders `#171a17` surfaces and the green accent button.


