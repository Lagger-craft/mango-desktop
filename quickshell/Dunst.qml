pragma Singleton

import QtQuick
import Quickshell.Io

// The single dunst integration point. Dunst stays the only notification
// daemon (README), so this never registers a second server: everything here
// goes through dunstctl. Both the bell's review popup (Notifications.qml)
// and the dashboard's notifications card (Dashboard.qml) consume this
// singleton, so the counts/history are fetched once and shared instead of
// each view spawning its own processes.
QtObject {
  id: dunst

  // Dunst's three pools: pending popups, on-screen popups, history.
  property int waiting: 0
  property int displayed: 0
  property int historyCount: 0
  property var history: [] // normalized entries: {id, appname, summary, body, urgency}
  readonly property int pending: waiting + displayed

  function stripTags(s) {
    return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  }

  function urgencyColor(u) {
    if (u === "CRITICAL") return "#d94b43";
    if (u === "LOW") return "#5a6055";
    return "#9bd45a";
  }

  function parseCounts(text) {
    const w = text.match(/Waiting:\s*(\d+)/);
    const d = text.match(/displayed:\s*(\d+)/);
    const h = text.match(/History:\s*(\d+)/);
    if (w) dunst.waiting = parseInt(w[1], 10);
    if (d) dunst.displayed = parseInt(d[1], 10);
    if (h) dunst.historyCount = parseInt(h[1], 10);
  }

  // Relaunching a finished Process needs an explicit toggle: setting
  // running = true on an already-true Process is a no-op.
  function relaunch(proc) {
    proc.running = false;
    proc.running = true;
  }

  function refreshCounts() { relaunch(countProc); }
  function refreshHistory() { relaunch(historyProc); }

  // With an id, re-show that history entry; without one, pop the latest.
  function reopenEntry(id) {
    popProc.command = id === undefined ? ["dunstctl", "history-pop"]
                                       : ["dunstctl", "history-pop", String(id)];
    relaunch(popProc);
  }

  function clearHistory() { relaunch(clearProc); }
  function closeAllDisplayed() { relaunch(closeAllProc); }

  property Process countProc: Process {
    command: ["dunstctl", "count"]
    stdout: StdioCollector {
      onStreamFinished: dunst.parseCounts(this.text)
    }
  }

  // `dunstctl history` prints pretty-printed multi-line JSON, so the whole
  // buffer is collected first (SplitParser line-JSON would fail on it).
  property Process historyProc: Process {
    command: ["dunstctl", "history"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const parsed = JSON.parse(this.text);
          // GVariant wrapper: data[0] is the entry list, newest first.
          const entries = (parsed.data && parsed.data[0]) || [];
          dunst.history = entries.map(e => ({
            id: e.id.data,
            appname: e.appname.data || "unknown",
            summary: dunst.stripTags(e.summary.data),
            body: dunst.stripTags(e.body.data),
            urgency: e.urgency.data
          }));
        } catch (err) {
          // Malformed payload: keep the previous list; the next refresh
          // repairs it.
        }
      }
    }
  }

  property Process clearProc: Process {
    command: ["dunstctl", "history-clear"]
    onExited: { dunst.refreshCounts(); dunst.refreshHistory(); }
  }

  property Process closeAllProc: Process {
    command: ["dunstctl", "close-all"]
    onExited: dunst.refreshCounts()
  }

  property Process popProc: Process {
    command: ["dunstctl", "history-pop"]
    onExited: { dunst.refreshCounts(); dunst.refreshHistory(); }
  }

  Component.onCompleted: refreshCounts()
}
