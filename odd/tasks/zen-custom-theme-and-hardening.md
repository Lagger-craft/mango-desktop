# Zen custom theme + desktop hardening

## Specs

- S1: "Seria bueno tener custom zen browser" — Zen Browser (1.23.2b, `zen-browser-bin`)
  must render its UI with the same Material palette the shell already uses.
- S2: The palette source is the existing matugen output, not a new pipeline:
  "matugen puede leerlo para sacar los colores del wallpaper".
- S3: The browser theme must follow the wallpaper automatically when the wallpaper changes.
- S4: "se puede hacer que se limpien cuando pasen 3 dias" — screenshots older than 3 days are
  deleted automatically. The cleanup must never touch the wallpaper source matugen samples from.
- S5: "dame el comando para poder ejecutarlo y la explicacion" — screenshot directory permissions
  must be tightened to owner-only, and the exact command explained.
- S6: "entre varias alternativas cual me recomiendas y como se deberia de configurar" — one
  firewall recommendation with a ready-to-install configuration.
- S7: Telemetry prefs must stay disabled; the actual current state must be verified and reported
  with evidence, not assumed.

## Tasks

- T1 (S1, S2, S3) — Zen theming: `zen/userChrome.css.template`, `mango/scripts/zen-theme.sh`,
  `zen/user.js`, hook in `mango/scripts/wallpaper-ctl.sh`. Route: inline.
- T2 (S4, S5) — Screenshot retention: `mango/scripts/screenshot-cleanup.sh`,
  `systemd/screenshot-cleanup.{service,timer}`, `mango/scripts/screenshot-area.sh` hardening.
  Route: inline.
- T3 (S6) — Firewall: `nftables/nftables.conf` (nftables, not firewalld/ufw) + install commands.
  Route: inline.
- T4 (S7) — Pref audit and hardening: `zen/user.js` telemetry/privacy prefs, evidence in Log.
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
