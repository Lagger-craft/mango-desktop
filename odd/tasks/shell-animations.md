# Shell bar animations

Objective: enter animations (slide + fade) for the shell's popups and overlays, matching
the Clavis/end-4 feel, without changing any behavior or layout.
Branch: master (work-unit commits, ask-on-risk). Test runner: qmllint + live hot-reload
screenshots; no test framework in this repo.

## Specs

S1: User: "Lasianimaciones en la barra me llaman la atencion." — smooth enter animations on
the shell's surfaces: calendar popup, wallpaper picker, dashboard overlay, volume OSD.
Toasts already animate (earlier feature).

S2: Exits stay instant except where a surface is a full-screen window we own (dashboard,
picker): fade-out before the window hides. Small popups (calendar) close instantly.

S3: Animations are subtle (150-220 ms, OutCubic), never block input longer than the old
instant behavior did, and add no new dependencies.

S4: Tags/hover feedback stays as-is unless trivially improvable (existing color Behaviors
stay; no layout changes).

## Tasks

T1 (S1,S2): done — CalendarPopup + VolumeOsd enter fade/slide on the chrome (animating the
window root would move the window, content-only animation); Dashboard + WallpaperPicker
enter fade+rise and exit fade via closing/fadingMonitor Scope state in shell.qml that
keeps the full-screen window mapped for 190 ms. Route: inline. Commit 6e1cbab. Fixed at
verify: duplicate `closingTimer` id across sibling Scopes (renamed pickerClosingTimer).

T2 (S3,S4): done — qmllint clean on all touched files (shell.qml baseline 255 unchanged);
live IPC toggle + grim pixel evidence: dashboard open dimmed (avg #13171B), closed bright
(#201D20), picker open dimmed (#0D1315), closed bright (#201E20); Esc close goes through
the same close() path (Keys.onEscapePressed -> pickerState/dashboard close). Toast enter
animation pre-existed.

## Log

L1 (2026-10-19): User request verbatim: "Lasianimaciones en la barra me llaman la
atencion." (from the original ideas thread). Preceded by user confirmation of matugen and
notifications features.

L2: Scope decision (parent): enter animations on all four surfaces; fade-out only for
full-screen owned windows (dashboard, picker); calendar and OSD exits instant — window
hide cannot be delayed without state plumbing, kept contained per S3.

L3: Risk line — Risk: none (animations only touch visual transition properties; open/close
semantics and IPC paths verified unchanged via live toggles and pixel evidence).

L4 (2026-10-19): User reported: volume OSD never appeared after the animation feature.
Root cause: `target: parent` inside osdEnter's ParallelAnimation resolves to the PopupWindow's
parent (null), so the chrome stayed at its `opacity: 0` initial value forever. Fixed in
a50a9c5 by targeting the chrome via explicit id (osdChrome). Verified live: pactl volume
change renders the OSD (pixel evidence: popup surface + border colors in the crop). Lesson:
in QML property animations, `parent` does not resolve to the enclosing Item — always target
by id.
