# Feature: Themed tray context menu

Objective: replace the native tray context menu (unstyleable `display()` /
`PlatformMenuEntry`) with a custom QML menu matching the Chernobyl bar.
Branch: `main` (private repo `Lagger-craft/mango-desktop`).
Delivery: single inline unit. Test runner: QuickShell verbose log loads with no
errors, the Vesktop menu entries render via `QsMenuOpener`, `git diff --check`.

## Specs

- S1: `quickshell/shell.qml` renders the tray context menu itself via
  `QsMenuOpener { id: trayMenuOpener }` + a `PopupWindow`, instead of calling
  `modelData.display(...)`. Right-click sets `trayMenuOpener.menu` to the item's
  `QsMenuHandle` and shows the popup below the bar near the clicked icon.
- S2: Entries use the real `QsMenuEntry` property names verified in the v0.3.1
  docs: `text` (NOT `label` — that is the D-Bus name), `icon`, `enabled`,
  `isSeparator`, `hasChildren`, `buttonType`, `checkState`. `triggered()` fires
  the entry and the menu closes.
- S3: Styling matches the bar/OSD palette: charcoal `#f0171a17` surface, 8px
  radius, `#3d5233` border, hover `#2a3126`, muted text `#a5a99d`, disabled
  `#5a6055`, green `#9bd45a` for check/radio marks. Separators render as a 1px
  `#485044` line; `enabled: false` items are inert with an arrow cursor change.
- S4: `grabFocus: true` dismisses the menu on an outside click; left-click
  (`activate`) and middle-click (`secondaryActivate`) behavior is unchanged.
- S5: Known limitation, documented honestly: items with `hasChildren` render an
  arrow but do not open a nested submenu (Vesktop's menu is flat). Extend when a
  tray app that needs submenus is added.

## Tasks

- T1 (S1-S5, inline): custom menu QML, validate load + entries, commit + push.

## Log

- L1 (2026-10-12, user): "Ya funciona el menu contextual y bien. Lo que falta
  esque tenga la estetica de la quickshell."
- L2 (2026-10-12, decision): the native `display()` menu cannot be styled from
  QML (it is a `PlatformMenuEntry` rendered by the system Qt platform theme).
  Decision: render the menu in QML via `QsMenuOpener` so it inherits the
  Chernobyl palette, trading native look-and-feel for full visual consistency
  with the bar and OSD.
- L3 (2026-10-12, evidence): API verified in v0.3.1 docs before coding —
  `QsMenuEntry.text`, `.icon`, `.enabled`, `.isSeparator`, `.hasChildren`,
  `.buttonType` (QsMenuButtonType None/CheckBox/RadioButton), `.checkState`
  (Qt.CheckState), `triggered()`; `QsMenuOpener.menu` + `.children`
  (ObjectModel<QsMenuEntry>). Vesktop's live menu (from D-Bus) is flat: Open,
  About, Repair Vencord, Reset Vesktop, separator, Restart, Quit.
- L4 (2026-10-12, implementation): replaced `modelData.display(panel, x, y)`
  with a per-panel `PopupWindow` fed by `QsMenuOpener`. Right-click sets
  `trayMenuOpener.menu = modelData.menu`, clamps the anchor x to stay on
  screen, and opens below the bar. Entries render text/icon/separator with the
  Chernobyl palette; `triggered()` then closes. The tooltip is suppressed while
  the menu is open. Verified: verbose load prints `Configuration Loaded` with
  zero errors; `QsMenuButtonType` and `QsMenuOpener` resolve (no ReferenceError
  or "not a type"). Live bar restarted (pid 522386). Visual confirmation of the
  themed menu is pending the user's right-click.
