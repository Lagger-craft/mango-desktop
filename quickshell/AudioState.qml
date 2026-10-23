pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Audio state owner for the audio panel.
//
// Volumes and mutes come from PulseAudio's JSON interface (`pactl -f json`),
// NOT from Quickshell's native Pipewire service: with PipeWire 1.6 and
// WirePlumber 0.5 the device volume no longer lives in the legacy
// `node.volume` property (the node has no such property at all), so
// Quickshell's `PwNodeAudioIface` reads 0 and its writes are silent no-ops.
// The native service is used for what it does well: the live peak meter of
// the default output, whose node is matched to the PulseAudio sink by name
// (PipeWire's `node.name` is exactly PulseAudio's sink name).
//
// The models are ListModels, not plain arrays: rows keep their identity
// between polls, so a volume change updates one slider in place instead of
// rebuilding the whole panel (which would reset any drag in progress).
QtObject {
  id: audio

  // ---- published state ----

  // Outputs. Roles: key, index, name, description, volume (0..1), muted.
  property ListModel sinkModel: ListModel {}
  // Inputs. Monitor sources (".monitor") are filtered out: they are the
  // recording end of an output, not a microphone.
  property ListModel sourceModel: ListModel {}
  // Apps playing audio. Roles: key, index, app, sinkIndex, volume, muted.
  property ListModel streamModel: ListModel {}

  property string defaultSink: ""
  property string defaultSource: ""

  // Mute state of the default output, mirrored for the bar icon.
  property bool defaultSinkMuted: false

  // Native peak meter on the default output. Declared before the property
  // that reads it: the binding is evaluated while the object is built, and
  // a not-yet-created meter would make it undefined.
  property PwNodePeakMonitor meter: PwNodePeakMonitor {
    enabled: true
  }

  // Live output level of the default sink, 0..1.
  property real outputPeak: Number(meter ? meter.peak : 0) || 0

  // How many audio panels are open. A refresh triggered while one is
  // visible reads everything, not just the background devices.
  property int openCount: 0

  // True once the first successful read landed.
  property bool ready: false

  function setPanelOpen(open) {
    openCount = Math.max(0, openCount + (open ? 1 : -1));
    // Open with fresh data even if the subscriber is between reconnects:
    // the panel must never show the last cached device state as live.
    if (open)
      audio.refresh();
  }

  // ---- reading ----

  // Full read: outputs, inputs, apps and the current defaults.
  function refresh() {
    runOnce(sinksProcess);
    runOnce(sourcesProcess);
    runOnce(streamsProcess);
    runOnce(defaultSinkProcess);
    runOnce(defaultSourceProcess);
  }

  // Cheap read for the background poll: outputs and the default output.
  function refreshDevices() {
    runOnce(sinksProcess);
    runOnce(defaultSinkProcess);
  }

  function runOnce(proc) {
    if (!proc.running)
      proc.running = true;
  }

  // Average of every channel's percentage, matching how `pactl set-*-volume`
  // writes (it sets all channels at once).
  function avgPercent(vol) {
    if (!vol)
      return 0;
    let sum = 0;
    let count = 0;
    for (const channel in vol) {
      const pct = parseFloat(vol[channel].value_percent);
      if (!isNaN(pct)) {
        sum += pct;
        count++;
      }
    }
    return count ? Math.round((sum / count) / 100 * 100) / 100 : 0;
  }

  function onSinks(text) {
    let rows;
    try {
      rows = JSON.parse(text);
    } catch (e) {
      return; // Truncated or malformed output: keep the previous state.
    }
    if (!Array.isArray(rows))
      return;
    sync(sinkModel, rows.map(s => ({
      key: String(s.name),
      index: s.index,
      name: s.name,
      description: s.description || s.name,
      volume: avgPercent(s.volume),
      muted: !!s.mute
    })), "key");
    audio.ready = true;
    audio.updateDefaultMute();
    updateMeter();
  }

  // Mirror the default output's mute state for the bar icon.
  function updateDefaultMute() {
    for (let i = 0; i < sinkModel.count; i++) {
      const row = sinkModel.get(i);
      if (row.name === audio.defaultSink) {
        audio.defaultSinkMuted = row.muted;
        return;
      }
    }
    audio.defaultSinkMuted = false;
  }

  function onSources(text) {
    let rows;
    try {
      rows = JSON.parse(text);
    } catch (e) {
      return;
    }
    if (!Array.isArray(rows))
      return;
    const real = rows.filter(s => !String(s.name).endsWith(".monitor"));
    sync(sourceModel, real.map(s => ({
      key: String(s.name),
      index: s.index,
      name: s.name,
      description: s.description || s.name,
      volume: avgPercent(s.volume),
      muted: !!s.mute
    })), "key");
  }

  function onStreams(text) {
    let rows;
    try {
      rows = JSON.parse(text);
    } catch (e) {
      return;
    }
    if (!Array.isArray(rows))
      return;
    sync(streamModel, rows.map(s => {
      const props = s.properties || {};
      return {
        key: String(s.index),
        index: s.index,
        app: props["application.name"] || props["media.name"] || "Application",
        sinkIndex: s.sink,
        volume: avgPercent(s.volume),
        muted: !!s.mute,
        // Only PulseAudio clients can be rerouted by the session manager.
        // A native PipeWire client picks its own target (target.object), so
        // `pactl move-sink-input` is a silent no-op for it.
        movable: props["client.api"] === "pipewire-pulse"
      };
    }), "key");
  }

  // Update the rows in place: existing keys get their values patched, new
  // keys are appended and vanished keys are removed. Nothing is rebuilt, so
  // the panel never loses an in-progress drag or a hover state.
  function sync(model, rows, keyRole) {
    const seen = {};
    for (let i = 0; i < model.count; i++) {
      const row = model.get(i);
      seen[String(row[keyRole])] = i;
    }
    for (const row of rows) {
      const key = String(row[keyRole]);
      if (seen[key] !== undefined) {
        const i = seen[key];
        const current = model.get(i);
        for (const role in row) {
          if (current[role] !== row[role])
            model.setProperty(i, role, row[role]);
        }
      } else {
        model.append(row);
      }
    }
    for (let i = model.count - 1; i >= 0; i--) {
      const key = String(model.get(i)[keyRole]);
      if (!rows.some(r => String(r[keyRole]) === key))
        model.remove(i);
    }
  }

  // Point the native peak meter at the default output. The native node name
  // is the PulseAudio sink name, which is the join key.
  function updateMeter() {
    if (!Pipewire.ready)
      return;
    const nodes = Pipewire.nodes.values;
    for (const node of nodes) {
      if (node.isSink && !node.isStream && node.name === audio.defaultSink) {
        if (audio.meter.node !== node)
          audio.meter.node = node;
        return;
      }
    }
  }

  // ---- writing ----

  // Commands are queued through a single process: a fast drag can queue
  // several writes before the previous one finished.
  property var pending: []

  function run(command) {
    audio.pending.push(command);
    startNext();
  }

  function startNext() {
    if (!audio.pending.length) {
      // The last write landed: re-read so the panel shows it right away
      // instead of waiting for the next poll tick.
      audio.refresh();
      return;
    }
    setter.command = audio.pending[0];
    setter.running = true;
  }

  function setSinkVolume(index, volume) {
    run(["pactl", "set-sink-volume", String(index), Math.round(volume * 100) + "%"]);
  }

  function setSinkMute(index, muted) {
    run(["pactl", "set-sink-mute", String(index), muted ? "1" : "0"]);
  }

  function setDefaultSink(name) {
    audio.defaultSink = name;
    run(["pactl", "set-default-sink", name]);
  }

  function setSourceVolume(index, volume) {
    run(["pactl", "set-source-volume", String(index), Math.round(volume * 100) + "%"]);
  }

  function setSourceMute(index, muted) {
    run(["pactl", "set-source-mute", String(index), muted ? "1" : "0"]);
  }

  function setDefaultSource(name) {
    audio.defaultSource = name;
    run(["pactl", "set-default-source", name]);
  }

  function setStreamVolume(index, volume) {
    run(["pactl", "set-sink-input-volume", String(index), Math.round(volume * 100) + "%"]);
  }

  function setStreamMute(index, muted) {
    run(["pactl", "set-sink-input-mute", String(index), muted ? "1" : "0"]);
  }

  function moveStream(index, sinkIndex) {
    run(["pactl", "move-sink-input", String(index), String(sinkIndex)]);
  }

  // Move a stream to the next output, wrapping around. Returns the sink it
  // was moved to, or -1 when there is nowhere to move it.
  function moveStreamToNext(index, currentSinkIndex) {
    const targets = [];
    for (let i = 0; i < sinkModel.count; i++) {
      const row = sinkModel.get(i);
      if (row.index !== currentSinkIndex)
        targets.push(row.index);
    }
    if (!targets.length)
      return -1;
    const next = targets[0];
    moveStream(index, next);
    return next;
  }

  // Display name of an output, by its PulseAudio index.
  function sinkName(sinkIndex) {
    for (let i = 0; i < sinkModel.count; i++) {
      const row = sinkModel.get(i);
      if (row.index === sinkIndex)
        return row.description;
    }
    return "";
  }

  // ---- processes ----
  //
  // Declared as properties, not as direct children: a QtObject root has no
  // default property, so it cannot own child objects directly (same shape
  // as the NotificationServer in NotificationDaemon.qml).

  property Process sinksProcess: Process {
    command: ["pactl", "-f", "json", "list", "sinks"]
    stdout: SplitParser {
      onRead: line => {
        if (line.trim().length)
          audio.onSinks(line);
      }
    }
  }

  property Process sourcesProcess: Process {
    command: ["pactl", "-f", "json", "list", "sources"]
    stdout: SplitParser {
      onRead: line => {
        if (line.trim().length)
          audio.onSources(line);
      }
    }
  }

  property Process streamsProcess: Process {
    command: ["pactl", "-f", "json", "list", "sink-inputs"]
    stdout: SplitParser {
      onRead: line => {
        if (line.trim().length)
          audio.onStreams(line);
      }
    }
  }

  property Process defaultSinkProcess: Process {
    command: ["pactl", "get-default-sink"]
    stdout: SplitParser {
      onRead: line => {
        if (!line.trim().length)
          return;
        audio.defaultSink = line.trim();
        audio.updateDefaultMute();
        audio.updateMeter();
      }
    }
  }

  property Process defaultSourceProcess: Process {
    command: ["pactl", "get-default-source"]
    stdout: SplitParser {
      onRead: line => {
        if (line.trim().length)
          audio.defaultSource = line.trim();
      }
    }
  }

  property Process setter: Process {
    running: false
    onExited: {
      setter.running = false;
      audio.pending.shift();
      audio.startNext();
    }
  }

  // ---- native meter ----

  // ---- event-driven refresh ----
  //
  // `pactl subscribe` streams one line per Pulse/PipeWire change event, so
  // an idle desktop spawns nothing. The old background poll ran a full
  // `pactl -f json list sinks` parse every 2s forever just to keep the bar
  // icon honest; that churned ~50k allocator calls/s and kept the process
  // RSS high-water mark pinned even after the traffic stopped.

  // Long-lived subscriber. It exits when the pulse socket goes away
  // (PipeWire restart), so onExited reconnects with a short backoff.
  // Started from Component.onCompleted: a `running: true` binding in the
  // declaration does not actually spawn the process in Quickshell.
  property Process subscribeProcess: Process {
    command: ["pactl", "subscribe"]
    stdout: SplitParser {
      onRead: line => {
        // Refresh only for the object classes this state reads: sinks
        // (bar icon + panel), sources (panel) and the server (default
        // sink/source switches). Volume keys, mute keys and app streams
        // all land on one of these.
        if (line.includes("sink") || line.includes("source") || line.includes("server"))
          audio.scheduleRefresh();
      }
    }
    onExited: subscribeRestartTimer.restart()
  }

  property Timer subscribeRestartTimer: Timer {
    interval: 2000
    onTriggered: subscribeProcess.running = true
  }

  // Coalesce event bursts: the first event schedules one refresh at most
  // 250 ms out, and events arriving meanwhile do not push it further, so a
  // held volume key still updates the icon within a quarter second.
  function scheduleRefresh() {
    if (!refreshDebounce.running)
      refreshDebounce.start();
  }

  property Timer refreshDebounce: Timer {
    interval: 250
    onTriggered: {
      if (audio.openCount > 0)
        audio.refresh();
      else
        audio.refreshDevices();
    }
  }

  // Belt and suspenders: if an event was missed (subscriber still
  // connecting at startup, or the socket dropped without an exit), one
  // cheap read a minute re-syncs the state. Two pactl spawns per minute
  // instead of one every two seconds.
  property Timer safetyPoll: Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: {
      if (audio.openCount > 0)
        audio.refresh();
      else
        audio.refreshDevices();
    }
  }

  Component.onCompleted: {
    audio.subscribeProcess.running = true;
    audio.refresh();
  }
}
