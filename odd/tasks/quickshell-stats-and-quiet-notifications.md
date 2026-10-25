# Quickshell stat bubbles + quiet notifications

Objective: add CPU / RAM / GPU bubbles to the bar's right island and silence
notifications in the bar entirely (no toasts, no bell) so the dashboard
notifications card is the only place they are shown. Branch
`feature/panel-stats-quiet-notifications` (stacked on `feature/clipboard-expiry`
tip 3c8f35e, which is what the live session runs). Test runner: none for QML —
`qmllint` + live hot-reload probes (grim screenshots, notify-send); repo checks
per AGENTS.md `## Verify before claiming done`.

## Specs

S1: User: "Puedes ayudarme agregar a la quickshell unas burbujas que me
muestren la memoria ram, uso de cpu y uso de la grafica." — the bar shows three
stat bubbles: RAM, CPU usage and GPU usage. Values agreed with the user: CPU as
a percentage, RAM as used/total in GiB, GPU as a percentage.

S2: User decision ("En la isla derecha", the option "Las tres burbujas dentro
de la isla derecha, junto al tray y los controles", preview
`[ 󰍛 12% 󰘚 8.2/32G 󰢮 5% | tray 🔊 ⏻ ]`): the three bubbles live inside the
existing right island, before the tray/power controls, separated by a divider.
User correction: "Hay un problema con la manera que muestra la ram, cpu y
grafica ya que se muestra mas arriba y se superpone en la quickshell. Fijate
que este centrado y dentro de la quickshell" — the bubbles must be vertically
centered in the island and fully inside it (never riding over the island's
top accent line or outside the bar).

S3: User: "Tambiens eria bueno quitar las notificacioens de la quickshell y
solo dejar el del dashboard para ver las notificaciones." User decision
("Toasts y campana", "Silencio total en la barra: nada de toasts ni campana.
Las notificaciones solo se ven en el dashboard."): the toast popups and the
bell + review popup are both removed from the bar; the dashboard notifications
card is the only notification view left.

S4: The dashboard notifications card keeps working as that single view: live
history list with urgency colors, counts, and CLEAR HISTORY. Every
toast-dependent affordance goes away with the toasts: RESHOW LATEST, CLOSE
DISPLAYED, the DND flag and click-an-entry-to-reshow.

S5: Project invariants (AGENTS.md): stats come from procfs and amdgpu sysfs
only — no network, no recurring helper processes (one one-shot GPU sysfs
resolution at startup is allowed), and one shared stats owner feeds both the
bubbles and the dashboard system card (no duplicate parsing/polling). A missing
GPU sysfs node degrades the GPU bubble to "n/a", never a broken shell.

## Tasks

- T1 (S1,S2,S5): `quickshell/SysStats.qml` singleton (procfs CPU delta + meminfo
  + amdgpu `gpu_busy_percent`) and `quickshell/StatBubbles.qml`, wired into the
  right island; dashboard system card rebinds to the singleton — inline.
  Commit b8ddf2c (layout fix in the T5 commit).
- T2 (S3,S4): delete `quickshell/Toasts.qml` and `quickshell/Notifications.qml`,
  prune `NotificationDaemon.qml` to a history-only owner, adapt the Dashboard
  notifications card and `shell.qml` — inline. Commit a8767dc.
- T3 (S1-S5): README + AGENTS.md updates, repo checks, live hot-reload probes
  (bar render, notify-send silence + dashboard history), work-unit commits,
  independent verifier (risk item 6), RDD assess — inline.

- T5 (S2, user bug report in L5): center the bubbles in the island band —
  inline. Commit 4dfb5d6.

## Log

L1 (2026-07-25) — user's original request verbatim (sent twice):
"Hola buenas. Puedes ayudarme agregar a la quickshell unas burbujas que me
muestren la memoria ram, uso de cpu y uso de la grafica. Tambiens eria bueno
quitar las notificacioens de la quickshell y solo dejar el del dashboard para
ver las notificaciones."

L2 (2026-07-25) — two scope decisions asked in one questionnaire:
(1) notifications removal scope → "Toasts y campana": "Silencio total en la
barra: nada de toasts ni campana. Las notificaciones solo se ven en el
dashboard."; (2) bubble layout → "En la isla derecha": "Las tres burbujas
dentro de la isla derecha, junto al tray y los controles", with the agreed
preview `[ 󰍛 12% 󰘚 8.2/32G 󰢮 5% | tray 🔊 ⏻ ]` and values CPU %, RAM
usada/total en GiB, GPU %.

L3 (2026-07-25) — evidence gathered before writing: GPU is an AMD RX 7600
(Navi 33) driven by amdgpu; `/sys/class/drm/card1/device/gpu_busy_percent`
reports 8 and `mem_info_vram_used/total` exist (8 GiB), so no external tool is
needed. The dashboard already parses `/proc/stat` (busy/total delta) and
`/proc/meminfo` with FileView + Timer, which becomes the shared SysStats
parser. Theme.qml proves the `pragma Singleton` mechanism works without a
qmldir in this project. No `notifications` IPC target exists in mango/config.conf,
so removing the bell/toasts breaks no keybind contract. Quickshell runs live
(PID 1494) and hot-reloads QML, so the panel can be verified in place.

L4 (2026-07-25) — implementation + live evidence. Two rendering traps found
and fixed during live probes: (a) a JS `"\uF035B"` escape is TWO tokens (`\uF035`
+ literal "B") — JS `\u` takes exactly 4 hex digits — so the bubbles first
rendered as stray symbols plus letters; the repo convention of literal glyph
chars is now used, and the icons were remapped to their real names (U+F061A
md-chip = CPU, U+F035B md-memory = RAM, U+F08AE md-expansion_card = GPU);
(b) `mmsg get all-monitors`'s `active` flag follows the user's focus, which
moved between probes — the dashboard had opened on DP-2 while screenshots
captured DP-1, looking like a broken overlay. Live probes (grim screenshots):
bubbles render in the right island (`chip 4% | memory 8.6/31G | expansion_card
13%`) with the divider before tray/power; dashboard SYSTEM card shows CPU/RAM
from the same SysStats values as the bubbles (8.4/31G panel == 8.4/31.3 GiB
card); after `notify-send` no toast appears anywhere and the bell is gone from
the island; three probe notifications landed in the dashboard's history card
("3 history", plain rows, CLEAR HISTORY only). Repo checks all green:
`mango -c … -p`, `bash -n`, verify-hardening, verify-clipboard-expiry,
`install.sh --dry-run`, `unshare -rn nft -c -f`, `git diff --check`. The three
probe notifications remain in the in-memory history until CLEAR HISTORY or a
shell restart.

L5 (2026-07-25) — user bug report (verbatim): "Hay un problema con la manera
que muestra la ram, cpu y grafica ya que se muestra mas arriba y se superpone
en la quickshell. Fijate que este centrado y dentro de la quickshell".
Reproduced before fixing (zoomed grim crop showed the pills riding over the
island's top accent line): root cause was layout, not rendering — every
action-row child (Tray 30x30, AudioButton 26x30, PowerButton 26x30) fills the
island's 30 px band while StatBubbles was a bare 22 px Row, which the parent
Row top-aligns, lifting the pills 8 px and onto the accent line. Fix: the
StatBubbles root is now a 30 px Item with the pill Row centered in it (and the
divider got `anchors.verticalCenter`), so all siblings share one centerline.
Verified live on DP-2 (same code as DP-1, which a fullscreen window covered):
zoomed crop shows pills centered inside the island, clear of the accent line,
divider centered. qmllint: StatBubbles exit 0; shell.qml exit 255 is the
recorded baseline false positive. Commit recorded in ## Tasks.

L6 (2026-07-25) — slice boundaries (work-unit slice gate). This feature's own
authored work is three commits: b8ddf2c (T1, ~273 authored lines), a8767dc
(T2, ~22 authored + 644 deletions of the two removed views), 4dfb5d6 (T5 fix,
~48), plus this docs commit — well inside the ~400-line work-unit budget per
commit and per feature. The branch-level counter (7k+ lines across 49 commits
vs origin/main) is the pre-existing stacked base of earlier features
(clipboard-expiry chain), not this feature's slice. Delivery strategy: the
cached chain strategy from odd/tasks/clipboard-expiry.md L7 applies and must
not be mixed — chain `stacked-to-main`, delivery `ask-on-risk`; the PR-time
`size:exception` decision for the stacked base is already pending there. Push
and PR creation remain unauthorized until the user asks.
