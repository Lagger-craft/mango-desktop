# Quickshell native notifications (dunst removal)

Objective: replace the dunst daemon with Quickshell's built-in NotificationServer so
notifications are handled inside the already-running quickshell process, and remove dunst
from the repo. Also fix the notifications popup sizing bug on DP-1.
Branch: master (work-unit commits, ask-on-risk delivery). Test runner: qmllint (Qt6) + live
`qs -p` probes with `notify-send`; no unit framework in this repo.

## Specs

S1: User: "Me interesaria cambiar dunst por la quickshell para manejar las notificaciones y
asi tener menos procesos extras y elminar dunst si no se utilizara." — Quickshell's
NotificationServer is the sole notification daemon; dunst is removed (no dunstctl calls
anywhere in the shell).

S2: Incoming notifications (notify-send, apps) render as styled toasts consistent with the
shell theme (dark charcoal island, green accent, same fonts), auto-dismiss per urgency,
dismissible by click; critical urgency persists until dismissed or clicked.

S3: Toasts appear on the focused monitor (same mmsg get all-monitors query pattern the
picker/dashboard use).

S4: The bell icon + review popup keeps its current UX (badge with pending count, history
list, urgency dot colors) but reads/writes the in-shell notification state, not dunstctl.
History, reshow/close/clear actions keep equivalent behavior: CLOSE DISPLAYED closes on-screen
toasts, CLEAR HISTORY clears the retained history, clicking an entry re-shows it.

S5: The dashboard notifications card consumes the same shared notification singleton (one
data owner; no duplicate polling).

S6: User bug report: "al hacer click en el icono de notificaciones de quickshell, se rompe
un poco el design, ya que estando en el monitor DP-1 se ancha el menu de notis, pero si lo
cierro y lo vuelvo abrir de hay mismo con un click se arregla la resolucion del menu de
notificaciones." — the notifications popup opens with correct size on first open on every
monitor, including DP-1.

S7: dunst is removed from the project: install.sh package list, dunstrc link/unlink steps,
the `dunst/` directory, and README sections updated to describe the new daemon. Removing the
dunst package from the user's system is a separate user decision (documented, not automated).

## Tasks

T1 (S1,S2,S3): done — `quickshell/NotificationDaemon.qml` singleton (NotificationServer,
bounded history 50, DND flag, per-urgency expiry incl. critical persist-forever, sweep
timer, mmsg focused-monitor placement) + `quickshell/Toasts.qml` per-screen popup (enter
slide/fade, urgency-styled, action buttons via tracked Notification objects). Route: inline.
Commit 7b29138. Evidence: qmllint exit 0 (shell.qml's silent 255 repeats at baseline);
D-Bus name `org.freedesktop.Notifications` owned by the quickshell process (busctl PID =
shortshell); grim screenshots show normal toast rendered + critical persisting past the
auto-expiry window. Fixed during verify: critical (expire 0) was swept immediately because
expireAt was stamped `now+0`; TTL 0 now means no expiry.

T2 (S4,S5,S6): done — `Notifications.qml` rewritten on the singleton (badge, history list,
RESHOW LATEST / CLOSE DISPLAYED / CLEAR HISTORY, no polling timers); `Dashboard.qml` card
rewired, dunstRefresh polling removed; first-open geometry re-asserted via `Qt.callLater`
after map (S6 fix candidate — needs human confirmation on DP-1). Route: inline.
Commit 7b29138.

T3 (S7): done — dunst removed from install.sh (package list, unlink step), link step
dropped, `dunst/` directory removed, README sections rewritten (in-shell server, masking
override at ~/.local/share/dbus-1/services, race caveat). `~/.config/dunst/dunstrc` repo
symlink removed. The dunst package itself stays installed (user decision); mask file
currently active on this system. Commit f8d3f32.

## Log

L1 (2026-10-19): User request verbatim: "Me interesaria cambiar dunst por la quickshell para
manejar las notificaciones y asi tener menos procesos extras y elminar dunst si no se
utilizara. Sobre matugen, me parece buena idea entonces. Si es viable con fondos animados a
traves de la preview me parece bien, evitemos esa opcion pro que sea tomando screenshot ya
que vendra con una perdida de rendimiento por estar tomando constantemente fotos. Una vez
implementado el cambio de las notificaciones podemos seguir con las animaciones de la barra.
Aunque queda decir que al hacer click en el icono de notificaciones de quickshell, se rompe
un poco el desing, ya que estando en el monitor DP-1 se ancha el menu de notis, pero si lo
cierro y lo vuelvo abrir de hay mismo con un click se arregla la resolucion del menu de
notificaciones."

Notes: matugen (via wallpaper preview.jpg) and bar animations are separate features tracked
after this one. Quickshell version on system: 0.3.2 per prior feature doc. Baseline evidence:
dunst not exec'd by mango config (D-Bus activated), Required By: None, matugen 4.2.0 in extra.

L2 (2026-10-19): Implementation notes. Dunst's package D-Bus activation file
(/usr/share/dbus-1/services/org.freedesktop.Notifications.service) resurrects dunst on
every notify — killing the process is not enough. Masked at user level with
~/.local/share/dbus-1/services/org.freedesktop.Notifications.service Exec=/bin/false, then
restarted quickshell (PID 207889) which now owns the name. Historical feature docs
(chernobyl, shell-dashboard-calendar) still mention dunst — they are records, not live docs.
Two commits: 7b29138 (code), f8d3f32 (repo cleanup). Pending human checks: bell popup
first-open sizing on DP-1 (S6 visual), toast action buttons, dashboard card, critical-toast
click-to-dismiss. Next features: matugen via wallpaper preview.jpg, then bar animations.

L3: Risk line — Risk: item 3 (the notification delivery contract for every app routes
through this shell; verified with notify-send probes normal + critical, screenshot-evidenced).

L4 (2026-10-19): User confirmed: "Las notis funcionan correctamente e igual que abrir las
notificaciones desde la quickshell." All three tasks closed; feature complete. Next feature:
matugen theming.
