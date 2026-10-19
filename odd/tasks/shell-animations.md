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

T1 (S1,S2): CalendarPopup + Dashboard + WallpaperPicker enter slide/fade; dashboard and
picker fade-out exit; VolumeOsd enter fade/slide. Route: inline.

T2 (S3,S4): qmllint all, live screenshots of each popup open, and Esc-path smoke (dashboard
still closes). Route: inline.

## Log

L1 (2026-10-19): User request verbatim: "Lasianimaciones en la barra me llaman la
atencion." (from the original ideas thread). Preceded by user confirmation of matugen and
notifications features.

L2: Scope decision (parent): enter animations on all four surfaces; fade-out only for
full-screen owned windows (dashboard, picker); calendar and OSD exits instant — window
hide cannot be delayed without state plumbing, kept contained per S3.
