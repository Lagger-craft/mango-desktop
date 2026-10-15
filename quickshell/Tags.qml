import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Left bar section: ZONE label, per-monitor workspaces as pixel skulls
// (click one to jump to that tag), and this screen's name. Tag state streams
// from `mmsg watch tags <monitor>`; click dispatches `mmsg dispatch view,N`.
Row {
  id: tagsRoot
  spacing: 12
  required property string screenName // e.g. "DP-1"

  // 16x16 pixel skull with a hard dark outline, no anti-aliasing: angular
  // cranium, tall hollow sockets and a narrow jaw, in the spirit of State
  // of Decay's HUD art. '#' marks bone.
  readonly property var skullRows: [
    ".....######.....",
    "....########....",
    "...##########...",
    "..############..",
    "..############..",
    ".##############.",
    ".##############.",
    ".###.######.###.",
    ".###.######.###.",
    ".###.######.###.",
    "..##.######.##..",
    "..############..",
    "...####..####...",
    "...##.####.##...",
    "...##########...",
    "....##.##.##....",
  ]
  readonly property int skullSize: 16
  readonly property int skullPixel: 1

  // Cells around the bone that stay empty but sit next to it. They get
  // painted first as a hard outline, which is what gives the skull its
  // game-HUD weight instead of a flat stencil.
  readonly property var skullOutline: {
    const bone = new Set();
    for (let r = 0; r < tagsRoot.skullSize; r++)
      for (let c = 0; c < tagsRoot.skullSize; c++)
        if (tagsRoot.skullRows[r].charAt(c) === "#")
          bone.add(r * tagsRoot.skullSize + c);

    const edge = [];
    for (const cell of bone) {
      const r = Math.floor(cell / tagsRoot.skullSize);
      const c = cell - r * tagsRoot.skullSize;
      for (let dr = -1; dr <= 1; dr++)
        for (let dc = -1; dc <= 1; dc++) {
          const rr = r + dr, cc = c + dc;
          if (rr < 0 || rr >= tagsRoot.skullSize || cc < 0 || cc >= tagsRoot.skullSize)
            continue;
          const neighbour = rr * tagsRoot.skullSize + cc;
          if (!bone.has(neighbour) && !edge.includes(neighbour))
            edge.push(neighbour);
        }
    }
    return edge;
  }

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

  Text {
    text: "☢  ZONE"
    color: "#a6dc69"
    font.bold: true
    font.pixelSize: 13
    anchors.verticalCenter: parent.verticalCenter
  }

  Rectangle {
    width: 1
    height: 18
    color: "#485044"
    anchors.verticalCenter: parent.verticalCenter
  }

  // Per-monitor workspaces as pixel skulls. Click one to jump to
  // that tag on this screen.
  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    Repeater {
      model: tagState.tags

      delegate: Item {
        id: skull
        required property var modelData
        width: tagsRoot.skullPixel * tagsRoot.skullSize
        height: tagsRoot.skullPixel * tagsRoot.skullSize

        // Radioactive green for the visible tag, warning amber for
        // an urgent one, bone when it holds windows, moss when empty.
        readonly property color tint: modelData.is_active ? "#9bd45a"
                                     : modelData.is_urgent ? "#e0a030"
                                     : modelData.client_count > 0 ? "#e4dfcf"
                                     : "#3d5233"

        // Subtle pad behind the active skull only.
        Rectangle {
          anchors.fill: parent
          anchors.margins: -2
          radius: 5
          color: skull.modelData.is_active ? "#262b24" : "transparent"
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Hard outline painted under the bone.
        Repeater {
          model: tagsRoot.skullOutline

          Rectangle {
            required property int modelData
            x: (modelData % tagsRoot.skullSize) * tagsRoot.skullPixel
            y: Math.floor(modelData / tagsRoot.skullSize) * tagsRoot.skullPixel
            width: tagsRoot.skullPixel
            height: tagsRoot.skullPixel
            color: "#0c0e0c"
          }
        }

        Repeater {
          model: tagsRoot.skullSize * tagsRoot.skullSize

          Rectangle {
            required property int index
            readonly property int row: Math.floor(index / tagsRoot.skullSize)
            readonly property int col: index - row * tagsRoot.skullSize
            visible: tagsRoot.skullRows[row].charAt(col) === "#"
            x: col * tagsRoot.skullPixel
            y: row * tagsRoot.skullPixel
            width: tagsRoot.skullPixel
            height: tagsRoot.skullPixel
            color: skull.tint
            Behavior on color { ColorAnimation { duration: 150 } }
          }
        }

        MouseArea {
          id: skullMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            viewTagProcess.command = ["mmsg", "dispatch", "view," + skull.modelData.index];
            viewTagProcess.running = true;
          }
        }

        ToolTip.visible: skullMouse.containsMouse
        ToolTip.text: "Tag " + skull.modelData.index
                    + " · " + skull.modelData.client_count
                    + (skull.modelData.client_count === 1 ? " window" : " windows")
        ToolTip.delay: 400
      }
    }
  }

  Rectangle {
    width: 1
    height: 18
    color: "#485044"
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    text: tagsRoot.screenName
    color: "#a5a99d"
    font.pixelSize: 11
    anchors.verticalCenter: parent.verticalCenter
  }
}
