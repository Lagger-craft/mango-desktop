# Matugen dynamic theming from wallpaper

Objective: generate the shell palette from the applied wallpaper via matugen. For Wallpaper
Engine (animated) wallpapers the palette source is the item's static preview.jpg; no
screenshot sampling (user explicitly declined the dynamic/frame-capture option).
Branch: master (work-unit commits, ask-on-risk). Test runner: `bash -n`, qmllint, live
`apply` probes + screenshots; no test framework in this repo.

## Specs

S1: User: "Sobre matugen, me parece buena idea entonces. Si es viable con fondos animados a
traves de la preview me parece bien, evitemos esa opcion pro que sea tomando screenshot ya
que vendra con una perdida de rendimiento por estar tomando constantemente fotos."
— matugen runs once per wallpaper apply/restore from a static source: the wallpaper image
itself for local, the Workshop item's preview for `we`. Palette never resamples while the
animated wallpaper plays.

S2: The theme follows the most recently applied wallpaper (the just-`apply`ed monitor's
source). On `restore`, the first entry of persisted state sources the palette; an empty
state falls back to the seeded default image.

S3: Quickshell consumes a generated theme file watched live (FileView watchChanges): colors
update without restarting the shell. Hardcoded shell colors become Theme singleton tokens;
absent theme file falls back to today's exact colors (graceful degradation).

S4: Generated file: theme JSON under the existing mango state dir, written atomically by
wallpaper-ctl.sh; quickshell only reads.

S5: README/install updated: matugen package added to the installer list; README documents
the pipeline and the animated-wallpaper preview behavior.

## Tasks

T1 (S1,S2,S4): done — `theme` command in wallpaper-ctl.sh + hooks after apply/restore;
source resolution local image / Workshop preview (project.json preview or preview.*
candidates); matugen 4.2 `--json hex --prefer saturation -m dark`; atomic write. Fixed at
verify: matugen 4.2's actual shape is `.colors.<key>.{dark,default}.color` (not flat, not
`.colors.dark`), and `--prefer` is required non-interactively. Route: inline.
Commits b087493, a574f3a.

T2 (S3): done — Theme.qml singleton (28 tokens, defaults = previous palette) watched by
FileView + 2s poll (watchChanges cannot watch a file created after shell start; content
guard dedupes); full hex→token sweep across all 13 QML files (zero leftover palette hexes
except Theme.qml defaults). Route: inline. Commits b087493, a574f3a.

T3 (S5): done — matugen added to install.sh package list and README palette section.
Commit b887580.

Verification evidence: theme.json generated from WE item 3804810496's preview.jpg; Theme
singleton logged the applied map; pixel sampling of both monitors' bars after apply shows
the blue matugen palette (DP-1 avg #4A4A5A, HDMI-A-1 #4B5C66), zero green; no ERROR lines
in the shell log.

## Log

L1 (2026-10-19): User request verbatim (full quote in quickshell-notifications.md L1):
"Sobre matugen, me parece buena idea entonces. Si es viable con fondos animados a traves de
la preview me parece bien, evitemos esa opcion pro que sea tomando screenshot ya que vendra
con una perdida de rendimiento por estar tomando constantemente fotos." Matugen decision:
palette from preview.jpg for WE wallpapers; screenshot sampling explicitly rejected.

L2 (2026-10-19): Scope decision (parent, matching user intent): theme source = the
just-applied wallpaper; restore uses the first state entry; empty state falls back to
default.png. Status knob: none — theme regenerates on every apply/restore, no manual toggle
for now.

L3 (2026-10-19): Implementation notes. matugen 4.2 CLI: `matugen image <img> -m dark --json
hex --quiet --prefer saturation` (prefer values: darkness, lightness, saturation,
less-saturation, value, closest-to-fallback; non-TTY requires it). Output shape:
`.colors.<key>.{dark,default}.color`. The `--json` wiki example (flat per-scheme objects)
does not match the 4.2 build — always verify against the installed binary. Quickshell
FileView watchChanges cannot watch a file that does not exist at load time: Theme.qml polls
every 2s with a lastJson guard. Mass hex→token sed must exclude the Theme.qml definition
file (it self-references) and unquote the produced tokens. Theme source = first state entry
on restore, monitor's own entry on apply. To recover the original green Chernobyl identity,
delete theme.json (defaults take over) or apply a green wallpaper. Risk: item 3 (whole-shell
recolor contract; verified by pixel sampling both monitors).

L4: Status: feature complete pending user visual confirmation. Next: bar animations.

L5 (2026-10-19): User noted workspaces stayed green after theming — traced to an
incomplete token set (accentDim absent from the generated theme.json). Fixed in 7559a26:
the full 28-token palette is generated, idle skulls now follow the wallpaper palette.
User may prefer green skulls permanently: if so, pin accentDim/accentBright in Theme.qml
(exclude them from cmd_theme's generated map). Awaiting user word.

L6 (2026-10-19): User: dashboard backdrop read as solid black; asked for a blurred
background instead. blur_layer=1 already frosted the overlay layer surface — the d9 alpha
(~85%) just hid it. overlayBg token dropped to 99 (~60%), theme regenerated (0249d4f).
Screenshot: windows/wallpaper visible frosted behind the dashboard card, text readable.
Applies to the picker too (same token).
