pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared system-metric owner: CPU %, RAM used/total and GPU %, read straight
// from procfs and the amdgpu sysfs nodes. The panel bubbles and the dashboard
// system card bind to these properties: one parser, one poll loop (S5). No
// recurring helper processes and no network — the single Process below only
// resolves, once at startup, which drm card node exposes the amdgpu load file.
// Without such a node gpuAvailable stays false and the GPU bubble degrades to
// "n/a" instead of lying with a stale 0%.
QtObject {
  id: sysStats

  // -- published metrics -------------------------------------------------
  property real cpuPct: 0
  property real memUsedGiB: 0
  property real memTotalGiB: 0
  property real gpuPct: 0
  property string gpuBusyPath: ""
  readonly property bool gpuAvailable: gpuBusyPath !== ""

  // -- CPU: busy/total delta of /proc/stat -------------------------------
  // First line: cpu user nice system idle iowait irq softirq steal guest
  // guest_nice. guest is already counted inside user, so the total stops at
  // steal. Usage % is the busy/total delta between two reads.
  property double lastBusy: -1
  property double lastTotal: -1

  function parseCpu(text) {
    const parts = (text || "").trim().split(/\s+/);
    if (parts.length < 6 || parts[0] !== "cpu")
      return;
    let total = 0;
    for (let i = 1; i <= 8 && i < parts.length; i++)
      total += Number(parts[i]) || 0;
    const idleAll = (Number(parts[4]) || 0) + (Number(parts[5]) || 0); // idle + iowait
    const busy = total - idleAll;
    if (sysStats.lastTotal >= 0 && total > sysStats.lastTotal) {
      const pct = 100 * (busy - sysStats.lastBusy) / (total - sysStats.lastTotal);
      sysStats.cpuPct = Math.max(0, Math.min(100, pct));
    }
    sysStats.lastBusy = busy;
    sysStats.lastTotal = total;
  }

  // -- RAM: MemTotal / MemAvailable of /proc/meminfo ---------------------
  function parseMem(text) {
    const total = /MemTotal:\s+(\d+)/.exec(text || "");
    const avail = /MemAvailable:\s+(\d+)/.exec(text || "");
    if (!total || !avail)
      return;
    sysStats.memTotalGiB = Number(total[1]) / 1048576;
    sysStats.memUsedGiB = (Number(total[1]) - Number(avail[1])) / 1048576;
  }

  // -- GPU: amdgpu gpu_busy_percent -------------------------------------
  function parseGpu(text) {
    const v = parseFloat((text || "").trim());
    if (!isFinite(v))
      return;
    sysStats.gpuPct = Math.max(0, Math.min(100, v));
  }

  // One-shot startup probe: the card number is not stable across hardware,
  // so resolve the first readable amdgpu load node instead of hardcoding
  // card1. Started from Component.onCompleted: a `running: true` binding in
  // the declaration does not actually spawn the process in Quickshell.
  property Process gpuProbe: Process {
    command: ["sh", "-c",
              "for f in /sys/class/drm/card*/device/gpu_busy_percent; do " +
              "[ -r \"$f\" ] && { printf '%s\\n' \"$f\"; exit 0; }; done"]
    stdout: SplitParser {
      onRead: line => {
        const path = line.trim();
        if (path.length)
          sysStats.gpuBusyPath = path;
      }
    }
  }

  property FileView statFile: FileView {
    path: "/proc/stat"
    printErrors: false
    onTextChanged: sysStats.parseCpu(this.text())
  }

  property FileView memFile: FileView {
    path: "/proc/meminfo"
    printErrors: false
    onTextChanged: sysStats.parseMem(this.text())
  }

  property FileView gpuFile: FileView {
    path: sysStats.gpuBusyPath // stays unloaded until the probe resolves
    printErrors: false
    onTextChanged: sysStats.parseGpu(this.text())
  }

  // 2 s cadence: cheap procfs/sysfs reads, smooth enough for bar text. The
  // CPU % needs consecutive samples, so the first real value lands one tick
  // after startup.
  property Timer poll: Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      statFile.reload();
      memFile.reload();
      if (sysStats.gpuAvailable)
        gpuFile.reload();
    }
  }

  Component.onCompleted: sysStats.gpuProbe.running = true
}
