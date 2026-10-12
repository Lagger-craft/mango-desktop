# Feature: Fix tray context menu

Objective: make right-click on system tray icons show the app's context menu.
Branch: `main` (private repo `Lagger-craft/mango-desktop`).
Delivery: single inline fix. Test runner: QuickShell verbose log must not show
the `PlatformMenuEntry`/`QApplication` error; `git diff --check`.

## Specs

- S1: `quickshell/shell.qml` declares `//@ pragma UseQApplication` as the first
  line so QuickShell starts in QApplication mode, which is required to render
  native platform menus (`PlatformMenuEntry`) such as tray context menus.
- S2: No other change to the tray MouseArea: `modelData.display(panel, x, y)`
  with `panel.mapFromItem(...)` coordinates was already correct.
- S3: The verbose QuickShell log shows `Configuration Loaded` with zero
  `Cannot display PlatformMenuEntry` errors.

## Tasks

- T1 (S1-S3, inline): add pragma, verify log, commit + push.

## Log

- L1 (2026-10-12, user): "falta el poder hacer click derecho en los systray ya
  que por mas que vea vesktop en segundo plano no puedo interactual, ya que no
  esta el menu contextual".
- L2 (2026-10-12, evidence): the menu was NOT a Vesktop/D-Bus problem. Direct
  D-Bus inspection proved the menu exists and is fully populated —
  `:1.218/org/chromium/DbusMenu/1` on interface `com.canonical.dbusmenu`
  returns Open, About, Repair Vencord, Reset Vesktop, Restart, Quit. Note
  Electron implements `com.canonical.dbusmenu`, NOT `org.kde.dbusmenu`
  (the latter returns UnknownMethod), and its `GetLayout` returns 2 values
  instead of the standard 3. The QML call signature `display(parentWindow,
  relativeX, relativeY)` and `QsWindow.mapFromItem` matched the v0.3.1 docs.
- L3 (2026-10-12, root cause): the verbose log revealed
  `Cannot display PlatformMenuEntry as quickshell was not started in
  QApplication mode. To use platform menus, add '//@ pragma UseQApplication'
  to the top of your root QML file and restart quickshell.` QuickShell defaults
  to a QML-only runtime; native platform menus need QApplication. The pragma
  was added and the error disappeared. Diagnostic dead ends recorded: a second
  quickshell process reports `SystemTray.items` count = 0 (only one process
  owns `org.kde.StatusNotifierWatcher`); `pkill -f "quickshell --path ..."`
  matches its own command line and self-terminates — kill by PID instead.
