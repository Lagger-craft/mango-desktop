import QtQuick
import Quickshell.Io

// Left bar section: ZONE label, per-monitor workspaces as pixel skulls
// (click one to jump to that tag), and this screen's name. Tag state streams
// from `mmsg watch tags <monitor>`; click dispatches `mmsg dispatch view,N`.
Row {
  id: tagsRoot
  spacing: 12
  required property string screenName // e.g. "DP-1"

  // Emitted when the ZONE label is clicked; shell.qml toggles the
  // dashboard overlay on it (S3).
  signal zoneClicked()

  // Live tag state for this screen only. `mmsg watch tags <monitor>`
  // keeps the IPC socket open and streams one JSON object per line on
  // every tag change (active tag, urgent flag, window count).
  QtObject {
    id: tagState
    property var tags: []
  }

  Process {
    id: tagWatch
    running: true
    command: ["mmsg", "watch", "tags", tagsRoot.screenName]

    stdout: SplitParser {
      onRead: line => {
        if (!line.trim().length)
          return;
        try {
          const state = JSON.parse(line);
          if (state.monitor === tagsRoot.screenName)
            tagState.tags = state.tags;
        } catch (e) {
          // Malformed or partial line: skip it, the next update fixes it.
        }
      }
    }

    // Restart if the stream ever drops (compositor restart, socket hiccup).
    onExited: tagRestart.restart()
  }

  Timer {
    id: tagRestart
    interval: 1000
    onTriggered: tagWatch.running = true
  }

  Process {
    id: viewTagProcess
    command: ["mmsg", "dispatch", "view,1"]
  }

  // Dashboard trigger (S3): the ZONE label opens the dashboard. Hover
  // recolor gives touch feedback; press emits zoneClicked. Anchors are
  // forbidden for Row children, so the hit area is a plain sibling Item
  // wrapping the label.
  Item {
    width: zoneLabel.width + 12
    height: parent.height
    anchors.verticalCenter: parent.verticalCenter

    Text {
      id: zoneLabel
      anchors.centerIn: parent
      text: "☢  ZONE"
      color: zoneMouse.containsMouse ? Theme.accentBright : Theme.accent
      font.bold: true
      font.pixelSize: 13

      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: zoneMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: tagsRoot.zoneClicked()
    }
  }

  Rectangle {
    width: 1
    height: 18
    color: Theme.divider
    anchors.verticalCenter: parent.verticalCenter
  }

  // Per-monitor workspaces as pixel skulls. Click one to jump to
  // that tag on this screen.
  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Repeater {
      model: tagState.tags

      delegate: SkullTag {
        onTagClicked: tagIndex => {
          viewTagProcess.command = ["mmsg", "dispatch", "view," + tagIndex];
          viewTagProcess.running = true;
        }
      }
    }
  }

  Rectangle {
    width: 1
    height: 18
    color: Theme.divider
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    text: tagsRoot.screenName
    color: Theme.textSecondary
    font.pixelSize: 11
    anchors.verticalCenter: parent.verticalCenter
  }
}
