pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The sole notification daemon (replaces dunst, README): a NotificationServer
// inside the already-running quickshell process, so no extra daemon exists.
// History owner for the dashboard's notifications card — the only notification
// view left (S3): nothing pops up in the bar (no toasts, no bell), so each
// incoming notification is copied into the bounded history and closed at once.
QtObject {
  id: daemon

  // Newest-first normalized entries: {id, appname, summary, body, urgency,
  // timestamp}. Bounded ring so the list stays cheap to render.
  property var history: []
  readonly property int historyCount: history.length
  readonly property int historyLimit: 50

  function urgencyColor(u) {
    if (u === "CRITICAL") return Theme.critical;
    if (u === "LOW") return Theme.textDim;
    return Theme.accent;
  }

  function _entryFromNotification(n) {
    return {
      id: n.id,
      appname: n.appName || "unknown",
      summary: n.summary,
      body: n.body,
      urgency: ["LOW", "NORMAL", "CRITICAL"][n.urgency],
      timestamp: Date.now()
    };
  }

  // Copy into history and let the server close the notification right away:
  // with no toast and no bell there is nothing to keep it alive for. The
  // notification is deliberately left untracked — tracking would make this
  // owner responsible for dismissing it later, which only the removed toasts
  // ever did.
  function handle(n) {
    history = [_entryFromNotification(n)].concat(history).slice(0, historyLimit);
  }

  function clearHistory() { history = []; }

  // The one server instance. Body text is what the dashboard card renders;
  // actions and images are not advertised because no view can present them
  // (S4) — advertising them would make apps send UI nobody can reach.
  property NotificationServer server: NotificationServer {
    bodySupported: true
    bodyMarkupSupported: true
    actionsSupported: false
    imageSupported: false
    onNotification: n => daemon.handle(n)
  }
}
