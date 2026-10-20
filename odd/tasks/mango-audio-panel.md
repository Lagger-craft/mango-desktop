# Feature: Mango audio panel

Objective: add an audio management panel to the QuickShell bar: outputs,
inputs and per-application volume/mute, with a live output level meter.
Branch: `feature/wallpaper-picker` (the audio panel ships on the branch the
desktop was last developed on).
Delivery strategy: single work-unit commit.
Test runner: `qmllint` (static), QuickShell runtime load on `wayland-0`
(the shell reloads itself when the config directory changes), live
`pactl` verification of every write, `git diff --check`. The panel itself is
Wayland-visual and has no deterministic unit test; its state layer is
verified against the live `pactl -f json` output.

## Specs

- S1: The right island of the bar carries a speaker icon that opens the
  audio panel. The glyph is the muted variant (amber) while the default
  output is muted, so a mute done with the keyboard is visible in the bar.
- S2: The panel opens as a popup under the bar, on the screen it was opened
  from; an IPC open (`quickshell ipc call audio toggle`, bound to
  `Super+Alt+A`) uses the compositor-focused monitor. Clicking outside the
  panel closes it.
- S3: The panel has three sections. `OUTPUT` lists every playback device with
  a volume bar and a mute button; the filled dot marks the default output and
  clicking it (or the device name) makes that device the default. `INPUT`
  lists the capture devices the same way, with monitor sources (`.monitor`)
  filtered out. `APPLICATIONS` lists every app currently playing with its own
  volume bar, mute button and a chip naming the output it plays through;
  clicking the chip moves the app to the next output.
- S4: The volume and mute state of every device and application, and the
  default output/input, come from PulseAudio's JSON interface
  (`pactl -f json list sinks|sources|sink-inputs`, `pactl get-default-sink`,
  `pactl get-default-source`). Every change is a normal PulseAudio call
  (`set-sink-volume`, `set-sink-mute`, `set-default-sink`, `set-source-*`,
  `set-sink-input-*`, `move-sink-input`), so applications see it at once.
- S5: The native QuickShell Pipewire service is used only for the live level
  meter of the default output (`PwNodePeakMonitor` on the native node whose
  name matches the default sink), shown as a thin bar in the panel header.
  Its volume and mute properties are NOT used: they read zero and their
  writes are no-ops on this PipeWire/WirePlumber version.
- S6: The panel updates in place. A poll refreshes the state every 700 ms
  while a panel is open and every 2 s while it is closed (so the bar icon
  stays honest when the volume keys are used), and a change made in the
  panel re-reads the state as soon as the write lands. Rows keep their
  identity between refreshes: a volume change patches one slider, it never
  rebuilds the list and never interrupts a drag in progress.
- S7: An application that talks to PipeWire natively (not through the
  PulseAudio compatibility layer) picks its own output and cannot be moved
  from the panel. Its chip is shown dimmed and does nothing when clicked.

## Tasks

- T1 (S1-S7, inline): `quickshell/AudioState.qml` (state owner),
  `quickshell/AudioPanel.qml` (popup UI), `quickshell/AudioButton.qml` (bar
  icon), the `shell.qml` wiring (scope, IPC handler, monitor query, bar
  island), the `mango/config.conf` keybind and the README section.

## Log

- L1 (2026-10-20, user): "Acabo de ver el problema de la config, me falta
  tener un panel para administrar el audio. Mi duda es si se puede hacer con
  quickshell?" - L2 (2026-10-20, user): "Si armalo porfavor".
- L3 (2026-10-20, evidence): the answer is yes, but not with the native API
  alone. Verified live against PipeWire 1.6.9 + WirePlumber 0.5 with
  Quickshell 0.3.2: `Quickshell.Services.Pipewire` enumerates every node
  (46 of them, with descriptions and the current default sink), can switch
  the default sink (`preferredDefaultAudioSink`) and reports live peaks
  (`PwNodePeakMonitor` returned 0.53 with per-channel values), but
  `node.audio.volume` always reads 0, `node.audio.muted` always reads false
  and writing either is a no-op. Cause: WirePlumber 0.5 no longer stores the
  device volume in the legacy `node.volume` property (neither `pw-cli info`
  nor `wpctl inspect` shows it on the sink), while `PwNodeAudioIface` reads
  and writes exactly that property. Quickshell's changelog carries volume
  fixes up to 0.3.2 but none covers this WirePlumber change. `node.properties`
  is also an empty map, so the panel reads everything else from `pactl`.
- L4 (2026-10-20, evidence): the volume/mute writes themselves do work through
  PulseAudio: `pactl set-sink-volume 71 30%` moved the HDMI sink to 0.30 and
  `pactl set-sink-mute 71 1` muted it, and the panel's write path was
  verified end to end (write -> model updated -> system state confirmed ->
  restored). `pactl move-sink-input` reroutes a PulseAudio client (Zen moved
  to the HDMI sink and back); it is a silent no-op for a native PipeWire
  client, which is why S7 exists.
- L5 (2026-10-20, evidence): three implementation traps found and fixed.
  (1) A `pragma Singleton` root has no default property, so the `Process` and
  `Timer` objects of `AudioState.qml` have to be declared as properties, not
  as children ("Cannot assign to non-existent default property"). (2) An
  inline component used as a `Repeater` delegate does not see the delegate
  context: `model` is undefined inside it, so the row binds to
  `required property var modelData` (the pattern the notification list
  already uses) and the row dispatches its own actions by kind. (3) The popup
  never showed up while its anchor was assigned imperatively in
  `onVisibleChanged`: the surface had already tried to map with the old
  anchor and was never re-anchored. `anchor.rect.x`/`anchor.rect.y` as
  bindings (the volume OSD's pattern) fixed it.
- L6 (2026-10-20, evidence): the panel was validated live in the running
  shell: it opens over the Discord window (layer-surface popup above normal
  windows), lists both outputs, the three real inputs and the five playing
  applications, and a click outside closes it. The `ListModel` rows keep
  their identity across refreshes (verified: the delegate build count stays
  constant while a role changes), so the sliders update in place.
