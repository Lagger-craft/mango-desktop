//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls

ShellRoot {
  // Shared volume OSD state: the volume-osd.sh helper writes
  // "<monitor> <volume-fraction> <muted-0-or-1>" to this file; every screen's
  // popup watches it and only the focused screen's popup shows.
  Scope {
    id: osd
    property bool active: false
    property string monitor: ""
    property real volume: 0
    property bool muted: false
    readonly property string path: Quickshell.env("XDG_RUNTIME_DIR") + "/mango-volume-osd"

    function show() {
      active = true;
      hideTimer.restart();
    }

    Timer {
      id: hideTimer
      interval: 1500
      onTriggered: osd.active = false
    }

    FileView {
      path: osd.path
      watchChanges: true
      printErrors: false
      onFileChanged: this.reload()
      onTextChanged: {
        const parts = this.text().trim().split(/\s+/);
        if (parts.length !== 3)
          return;
        osd.monitor = parts[0];
        osd.volume = Math.max(0, Math.min(1, parseFloat(parts[1]) || 0));
        osd.muted = parts[2] === "1";
        osd.show();
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData
        anchors {
          top: true
          left: true
          right: true
        }
        implicitHeight: 40
        exclusiveZone: 40
        color: "transparent"

        // Volume OSD: bottom-right, only on the screen the helper reported as
        // focused.
        VolumeOsd {
          panelWindow: panel
          osdState: osd
        }

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
          for (let r = 0; r < panel.skullSize; r++)
            for (let c = 0; c < panel.skullSize; c++)
              if (panel.skullRows[r].charAt(c) === "#")
                bone.add(r * panel.skullSize + c);

          const edge = [];
          for (const cell of bone) {
            const r = Math.floor(cell / panel.skullSize);
            const c = cell - r * panel.skullSize;
            for (let dr = -1; dr <= 1; dr++)
              for (let dc = -1; dc <= 1; dc++) {
                const rr = r + dr, cc = c + dc;
                if (rr < 0 || rr >= panel.skullSize || cc < 0 || cc >= panel.skullSize)
                  continue;
                const neighbour = rr * panel.skullSize + cc;
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
          command: ["mmsg", "watch", "tags", panel.screen.name]

          stdout: SplitParser {
            onRead: line => {
              if (!line.trim().length)
                return;
              try {
                const state = JSON.parse(line);
                if (state.monitor === panel.screen.name)
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

        Rectangle {
          anchors.fill: parent
          color: "#e8171a17"

          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: "#9bd45a"
          }

          Item {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 12

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
                    width: panel.skullPixel * panel.skullSize
                    height: panel.skullPixel * panel.skullSize

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
                      model: panel.skullOutline

                      Rectangle {
                        required property int modelData
                        x: (modelData % panel.skullSize) * panel.skullPixel
                        y: Math.floor(modelData / panel.skullSize) * panel.skullPixel
                        width: panel.skullPixel
                        height: panel.skullPixel
                        color: "#0c0e0c"
                      }
                    }

                    Repeater {
                      model: panel.skullSize * panel.skullSize

                      Rectangle {
                        required property int index
                        readonly property int row: Math.floor(index / panel.skullSize)
                        readonly property int col: index - row * panel.skullSize
                        visible: panel.skullRows[row].charAt(col) === "#"
                        x: col * panel.skullPixel
                        y: row * panel.skullPixel
                        width: panel.skullPixel
                        height: panel.skullPixel
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
                text: panel.screen.name
                color: "#a5a99d"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Clock {
              anchors.centerIn: parent
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 5

              Tray {
                panelWindow: panel
              }

              PowerButton {
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
        }
      }
    }
  }
}
