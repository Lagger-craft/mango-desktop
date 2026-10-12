# Feature: Game primary monitor + tray menu async fix

Objective: (1) make XWayland/X11 fullscreen games open on DP-1 instead of
HDMI-A-1; (2) fix the themed tray menu showing an empty background and loading
slowly on re-open.
Branch: `main` (private repo `Lagger-craft/mango-desktop`).
Delivery: single inline unit. Test runner: `mango -c <abs> -p`, verbose
QuickShell load with no errors, `git diff --check`.

## Specs

- S1: `mango/config.conf` adds `primary:1` to the `DP-1` monitor rule. Mango's
  docs: X11/XWayland clients (notably fullscreen games that confine/lock the
  pointer) use the RandR primary output for their coordinate origin; without any
  `primary:1` rule the monitor of the **first matching rule** wins — which is
  HDMI-A-1, explaining the bug. `primary:1` sets the RandR primary independently
  of position, so the coordinates stay exactly as the user specified.
- S2: Coordinates are NOT changed and must remain all-positive. Mango docs mark
  negative monitor coordinates as a known XWayland bug that breaks click events;
  moving DP-1 to (0,0) via negative HDMI coords would regress the very clicks
  the games need.
- S3: The tray `MouseArea` pre-loads the menu on hover
  (`onContainsMouseChanged` sets `trayMenuOpener.menu`), so the D-Bus
  `GetLayout` round-trip completes before the user right-clicks.
- S4: Right-click only opens the popup when `trayMenuOpener.children` is
  non-empty; otherwise it sets a pending flag and a short polling Timer opens the
  popup once content arrives. This guarantees the popup never renders an empty
  charcoal background.
- S5: Left-click (`activate`), middle-click (`secondaryActivate`), tooltip, and
  the themed entry rendering are unchanged.

## Tasks

- T1 (S1-S5, inline): add `primary:1`, rework menu open timing, validate, push.

## Log

- L1 (2026-10-12, user): games detect HDMI-A-1 as the monitor to use when it
  should be DP-1 as default; the tray menu shows the theme but re-opening shows
  only the background and takes a long time, or needs close-and-reopen.
- L2 (2026-10-12, evidence): `mmsg get all-monitors` shows HDMI-A-1 active=false
  at (0,0) logical 1080x1920, DP-1 active=true at (1080,420) 2560x1080, DP-2 at
  (3640,420). Config line 40 lists HDMI-A-1 as the FIRST monitor_rule and none
  carries `primary`. Mango wiki (monitors#primary-output) documents `primary:1`
  and the first-matching-rule default; it also warns negative x/y break XWayland
  clicks. A test config with `x:-1080,y:-420` passed the parser (exit 0) but is
  rejected by the docs' warning, so it is not used.
- L3 (2026-10-12, evidence): QuickShell docs confirm menu children load
  asynchronously over D-Bus (`QsMenuOpener.children` ObjectModel, `updateLayout()`
  for stale menus). The themed popup bound `implicitHeight` to
  `menuColumn.implicitHeight`, so with an empty/slow model it rendered a thin
  empty strip. Fix is timing (pre-load on hover + open only when populated).
- L4 (2026-10-12, verification): `xrandr --listactivemonitors` after
  `mmsg dispatch reload_config` reports `+*DP-1` — the asterisk marks DP-1 as
  the RandR primary output, confirming `primary:1` took effect for XWayland
  games. Verbose QuickShell load printed `Configuration Loaded` with zero
  errors after the menu-timing rework; live bar restarted (pid 533556). The
  guard `!trayMenu.visible` on the hover pre-load prevents swapping an already
  open menu's content when passing over another tray icon.
