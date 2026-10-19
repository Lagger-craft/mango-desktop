pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The sole notification daemon (replaces dunst, README): a NotificationServer
// inside the already-running quickshell process, so no extra daemon exists.
// State owner for every notification view: live toast entries, bounded
// history, DND. The bell popup, dashboard card and the toasts consume this
// singleton instead of spawning processes.
QtObject {
  id: daemon

  // Do-not-disturb: incoming notifications go to history only, no toast.
  property bool dnd: false

  // Newest-first normalized entries: {id, appname, summary, body, urgency,
  // image, actions: [{identifier, text}], timestamp}. Bounded ring so the
  // badge never carries an ever-growing counter.
  property var history: []
  readonly property int historyCount: history.length

  // On-screen toast entries (newest first). "Display-only" reshow entries
  // come from history and have no backing Notification object.
  property var live: []
  readonly property int pending: live.length

  // Focused monitor when the latest notification arrived (mmsg query); ""
  // means "unknown — show on every screen".
  property string toastMonitor: ""

  function stripTags(s) {
    return (s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  }

  function urgencyColor(u) {
    if (u === "CRITICAL") return Theme.critical;
    if (u === "LOW") return Theme.textDim;
    return Theme.accent;
  }

  // Auto-dismiss per urgency; 0 = persist until dismissed (critical).
  function expireMs(u) {
    if (u === "LOW") return 3500;
    if (u === "CRITICAL") return 0;
    return 5000;
  }

  readonly property int historyLimit: 50

  // id -> backing Notification object, for dismiss()/invoke() calls. JS
  // object keys are fine: ids are server-assigned uints.
  property var trackedMap: ({})

  function _entryFromNotification(n) {
    return {
      id: n.id,
      appname: n.appName || "unknown",
      summary: n.summary,
      body: n.body,
      urgency: ["LOW", "NORMAL", "CRITICAL"][n.urgency],
      image: n.image || "",
      actions: n.actions.map(a => ({ identifier: a.identifier, text: a.text })),
      timestamp: Date.now()
    };
  }

  function handle(n) {
    const entry = _entryFromNotification(n);
    history = [entry].concat(history).slice(0, historyLimit);
    if (dnd) {
      // Not tracked: the server reports it closed on our behalf.
      return;
    }
    n.tracked = true;
    trackedMap[String(n.id)] = n;
    n.closed.connect(() => {
      delete trackedMap[String(n.id)];
      live = live.filter(e => e.id !== n.id);
    });
    toastMonitorQuery.running = true;
    const ttl = expireMs(entry.urgency);
    live = [Object.assign({}, entry,
        { expireAt: ttl > 0 ? Date.now() + ttl : 0 })].concat(live);
  }

  function sweep() {
    const now = Date.now();
    let expired = [];
    live = live.filter(e => {
      if (e.expireAt > 0 && e.expireAt <= now) {
        expired.push(e);
        return false;
      }
      return true;
    });
    for (const e of expired) {
      const n = trackedMap[String(e.id)];
      if (n)
        n.expire();
      else
        _dropDisplayOnly(e.id);
    }
  }

  // Display-only entries (reshows) have no Notification object: dropping
  // them from live is all the cleanup needed.
  function _dropDisplayOnly(id) {
    live = live.filter(e => e.id !== id);
  }

  function closeToast(id) {
    const n = trackedMap[String(id)];
    if (n)
      n.dismiss();
    else
      _dropDisplayOnly(id);
  }

  function closeAllDisplayed() {
    for (const e of live)
      closeToast(e.id);
  }

  function clearHistory() { history = []; }

  // With an id, re-show that history entry; without one, the latest. Reshow
  // entries are display-only, expire like a normal toast and get negative
  // ids so they can never collide with (or dismiss) real ones.
  function reshowEntry(id) {
    let entry = null;
    for (const e of history)
      if (id === undefined || e.id === id) { entry = e; break; }
    if (!entry)
      return;
    const nextId = -(++_reshowCounter);
    live = [Object.assign({}, entry, {
      id: nextId,
      expireAt: Date.now() + expireMs(entry.urgency)
    })].concat(live);
  }

  property int _reshowCounter: 0

  // The one server instance. Capabilities match what dunstrc handled: body,
  // markup, actions, images. Inline reply is not exposed by the shell UI.
  property NotificationServer server: NotificationServer {
    bodySupported: true
    bodyMarkupSupported: true
    actionsSupported: true
    imageSupported: true
    onNotification: n => daemon.handle(n)
  }

  // Focused-monitor query for toast placement, same pattern as the picker
  // and dashboard: the compositor is the only source of truth for focus.
  property Process toastMonitorQuery: Process {
    command: ["mmsg", "get", "all-monitors"]
    stdout: SplitParser {
      onRead: line => {
        if (!line.trim().length)
          return;
        try {
          const mons = JSON.parse(line).monitors || [];
          for (const m of mons)
            if (m.active) {
              daemon.toastMonitor = m.name;
              return;
            }
        } catch (e) {
          // Malformed line: keep the previous monitor ("" shows everywhere).
        }
      }
    }
  }

  // One sweep timer instead of a QTimer per toast: cheap and restarts only
  // while toasts are on screen.
  property Timer sweepTimer: Timer {
    interval: 250
    running: daemon.live.length > 0
    repeat: true
    onTriggered: daemon.sweep()
  }

}
