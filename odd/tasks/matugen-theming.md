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

T1 (S1,S2,S4): wallpaper-ctl.sh — `theme` command + hooks after apply/restore; resolve
source image (local ref / workshop preview.jpg); matugen run with dark mode; atomic theme
write. Route: inline.

T2 (S3): quickshell Theme.qml singleton (FileView watch, defaults = current colors);
replace hardcoded colors across all QML files. Route: inline.

T3 (S5): install.sh package list + README section. Route: inline.

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
