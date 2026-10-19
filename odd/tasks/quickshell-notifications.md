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

T1 (S1,S2,S3): notification singleton (`NotificationServer`) owning state: live toasts,
history (bounded ring, newest first), counts, DND; toast popups per screen shown on the
focused monitor. Route: inline.

T2 (S4,S5,S6): rewrite Notifications.qml bell/popup to consume the new singleton; rewire
Dashboard.qml notifications card to the same singleton; fix first-open sizing bug (size
recomputed on every open, not only after first close/open). Route: inline.

T3 (S7): remove dunst from install.sh, delete dunst/ dir and dunstrc, rewrite README
notification sections. Route: inline.

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
