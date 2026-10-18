# Feature: QuickShell calendar popup + dashboard (Clavis-inspired)

Objective: extend the MangoWM QuickShell bar with (1) a calendar popup on clock
island click and (2) a full-screen dashboard overlay on the "ZONE" label click,
borrowing portable patterns from github.com/StatIndet/quickshell (reviewed
2026-10-18: high quality, Niri/matugen-coupled; borrowed = PopupWindow anchor
pattern, custom month grid + cross-day refresh fix, bar-button → panel trigger).

Branch/working state: lives on `feature/wallpaper-picker` with the uncommitted
island rework of the same session; commits are proposed to the user at close.
Delivery: local only. Test runner: none exists for QML — verification is
`qmllint` per file + live hot-reload checks + grim screenshots via IPC toggles.

## Specs

- S1 (user verbatim): "Ademas de que al presionar el calendario que se habra un popup del calendario."
  Clicking the clock island toggles a `PopupWindow` anchored below it: month
  grid with localized weekday headers (`Qt.locale()` first-day-of-week), a
  `‹ month year ›` navigation header, today highlighted (green `#9bd45a`
  background, dark text), Chernobyl palette, radius 10, background `#f0171a17`,
  border `#4a5a41`. Cross-day refresh must survive caching: re-check "today"
  on `SystemClock` minutes change and on popup `visible` change (the Clavis
  fix: MonthGrid's today role is cached until model repopulation, so compute
  isToday manually from a tracked `currentDate`). No events, no network.
  Closes on outside click (`grabFocus: true`) and on clicking the clock again.
- S2 (user verbatim): "Ademas me interesa meter un dashboard".
  Cards the user selected (verbatim answer): "Notificaciones (recomendada),
  Acciones de sesión (recomendada), Sistema CPU/RAM/uptime (recomendada),
  Música MPRIS (recomendada)". Dashboard = full-screen overlay per screen,
  mirroring the WallpaperPicker structure (own PanelWindow per screen, dim
  backdrop, centered container ~900×560, radius 10, Chernobyl themed). Cards:
  - Notifications: dunst history list + live counts + "CLEAR HISTORY";
    dunst stays the sole daemon — consume the shared `Dunst` singleton only.
  - System: CPU% (busy/total deltas from `/proc/stat`), RAM used/total
    (`/proc/meminfo`), uptime (`/proc/uptime`), kernel
    (`/proc/sys/kernel/osrelease`); ~2 s refresh; progress-bar styling like
    the volume OSD.
  - Music: active MPRIS player (`Quickshell.Services.Mpris`): artwork (local
    file only — never fetch URLs), title, artist, play/pause + next/prev;
    empty state "NO PLAYER".
  - Session: three buttons — LOGOUT `mango -s quit`, REBOOT `systemctl reboot`,
    POWEROFF `systemctl poweroff` (same commands as `mango/scripts/power-menu.sh`);
    reboot/poweroff styled as danger (amber/red borders).
- S3 (user verbatim): "El dashboard se puede abrir al presionar en la parte
  izquierda de la quickshell. En donde dice Zone."
  Clicking the "☢ ZONE" label toggles the dashboard; the label gets hover
  feedback. Esc, the backdrop, or a close button dismisses it. `IpcHandler`
  targets `calendar` and `dashboard` (function `toggle`) exist for keybinding
  use and live verification.
- S4 constraints (project invariants): no network requests, no new
  dependencies, no second notification daemon, artifacts in English, Chernobyl
  palette (`#171a17` charcoal, `#9bd45a` green, `#e0a044` amber, `#d94b43`
  red, `#c8d2c0`/`#e5e8dc` text, `#5a6055` dim), Nerd Font glyphs need
  `font.family: "JetBrainsMono Nerd Font Mono"` (generic monospace resolves to
  Noto Sans Mono without icons), blur config untouched.

## Interfaces (parent-owned shared files; writers must NOT edit them)

- Parent owns `quickshell/shell.qml` and `quickshell/Tags.qml`: island clicks,
  IPC handlers, popup/overlay instantiation and anchoring.
- `CalendarPopup.qml` contract: root is a `PopupWindow` with
  `required property var panelWindow`; parent sets `anchor.window` is inside
  the component; parent sets `anchor.rect.x/y` and `visible`. Default
  `implicitWidth: 320`, height content-driven, `color: "transparent"`,
  `grabFocus: true`.
- `Dashboard.qml` contract: root is an `Item` filling its parent; parent hosts
  it inside a fullscreen PanelWindow (visible when `dashboardState.active` and
  the screen matches); `required property var dashboardState` provides
  `property bool active` and `function close()`.
- `Dunst.qml` contract: `pragma Singleton` QtObject `Dunst` owning ALL
  dunstctl logic currently inlined in `Notifications.qml`: `waiting`,
  `displayed`, `historyCount`, `history` (normalized entries
  `{id, appname, summary, body, urgency}`), `refreshCounts()`,
  `refreshHistory()`, `reopenEntry(id)`, `clearHistory()`,
  `closeAllDisplayed()`, `stripTags(s)`, `urgencyColor(u)`. `Notifications.qml`
  is rewired to consume it; the dashboard notifications card consumes it too.
  (If `pragma Singleton` does not resolve at runtime, the fallback is a plain
  QtObject instantiated once in shell.qml and passed by reference — report it,
  do not invent a qmldir.)

## Tasks

- T1 (delegated worker A): `quickshell/CalendarPopup.qml` per S1 — new file only. Status: done — file created, `qmllint` exit 0, all other QML files still lint clean; live anchor/close checks deferred to T3. Note: doc's pattern path TrayMenu.qml does not exist; worker followed `quickshell/Tray.qml` instead.
- T2 (delegated worker B): `quickshell/Dunst.qml` + rewrite `quickshell/Notifications.qml` to consume it + `quickshell/Dashboard.qml` per S2 — three files only. Status: done — qmllint (Qt5 + Qt6) exit 0; live `qs -p` probes green (singleton resolves without qmldir under QuickShell 0.3.2; dunst history 10 entries normalized; GridLayout removed in favor of anchored geometry per project convention, caught only by runtime probe). Session/Mpris runtime smoke + screenshots deferred to T3.
- T3 (inline parent): wire shell.qml (islands clicks, IPC, Variants overlay for dashboard, anchor for calendar) and Tags.qml (zoneClicked signal); live verification: hot-reload log clean, qmllint all, IPC-toggle screenshots of calendar and dashboard on DP-1, dunst card populated from the existing test notifications, system numbers sane, MPRIS empty-state check. Status: done — Tags.qml `zoneClicked` + hover; shell.qml `calendar`/`dashboard` Scopes + IpcHandler targets, clock-island MouseArea with island-center anchoring, per-screen CalendarPopup + dashboard overlay Variants. Fixed a real bug: child ids are not addressable across Scopes (`calendarTargetMonitor.calendarMonitorQuery` → TypeError), exposed via `requery()`; default anchor for IPC opens (centered under clock) guarded by `calendarState.anchored`. Verified live: hot-reload clean, qt6 qmllint exit 0 on all touched files (Qt5 lint's old 255 on shell.qml is a Qt5-declarative limitation, repeats at baseline), calendar popup screenshot OK (today highlighted), dashboard screenshot OK with all four cards populated live (dunst history 12, CPU 5%, RAM 9.9/31.3 GiB, uptime, kernel 7.2.11-arch1-1, MPRIS Firefox with artwork + transport). Pending human checks: ZONE-label click and Esc-handled close are component+interaction paths only a human on the seat can exercise comfortably.
- T4 (inline parent): README panel section update, feature-doc close, Risk line, report with commit proposal. Status: done — README panel paragraph extended for calendar popup + dashboard; feature doc closed with this entry.

## Log

- L1 (user, verbatim, 2026-10-18): "Puedes revisar el siguiente repo: https://github.com/StatIndet/quickshell.git\n\nAdemas me interesa meter un dashboard, ademas de que al presionar el calendario que se habra un popup del calendario. El dashboard se puede abrir al presionar en la parte izquierda de la quickshell. En donde dice Zone."
- L2 (user, verbatim, 2026-10-18): cards answer — "Notificaciones (recomendada), Acciones de sesión (recomendada), Sistema CPU/RAM/uptime (recomendada), Música MPRIS (recomendada)".
- L3: Repo review findings (parent): Clavis is Niri/matugen/systemd-coupled; portable patterns named in the Objective; its calendar cross-day fix quoted in S1; its `SidebarButton.qml` is the ZONE-trigger analogue.
