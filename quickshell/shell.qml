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
        // focused. Restyled by the Behavior animations below on every step.
        PopupWindow {
          id: volumeOsd
          visible: osd.active && osd.monitor === panel.screen.name
          anchor.window: panel
          anchor.rect.x: panel.screen.width - width - 20
          anchor.rect.y: panel.screen.height - height - 20
          implicitWidth: 240
          implicitHeight: 64
          color: "transparent"

          Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#f0171a17"
            border.width: 1
            border.color: osd.muted ? "#e0a030" : "#3d5233"

            Row {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 10

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: osd.muted ? "🔇" : "🔊"
                font.pixelSize: 20
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44
                spacing: 6

                Text {
                  text: osd.muted ? "MUTED" : "VOLUME " + Math.round(osd.volume * 100) + "%"
                  color: osd.muted ? "#e0a030" : "#a6dc69"
                  font.bold: true
                  font.pixelSize: 12
                  font.letterSpacing: 0.5
                }

                Rectangle {
                  width: parent.width
                  height: 6
                  radius: 3
                  color: "#282d26"

                  Rectangle {
                    width: parent.width * (osd.muted ? 0 : osd.volume)
                    height: parent.height
                    radius: 3
                    color: osd.muted ? "#e0a030" : "#9bd45a"

                    Behavior on width {
                      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                  }
                }
              }
            }
          }
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

            Text {
              id: clock
              anchors.centerIn: parent
              color: "#e5e8dc"
              font.pixelSize: 13
              font.letterSpacing: 0.3

              Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, dd MMM  ·  HH:mm")
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 5

              Repeater {
                model: SystemTray.items
                delegate: Item {
                  id: trayItem
                  required property var modelData
                  width: 30
                  height: 30

                  // Right-click must not render before the D-Bus menu children
                  // arrive; this pending flag bridges that async gap.
                  property bool menuPending: false

                  Timer {
                    id: menuWait
                    interval: 40
                    repeat: true
                    running: trayItem.menuPending
                    onTriggered: {
                      if (trayMenuOpener.children.values.length > 0) {
                        trayMenu.visible = true;
                        trayItem.menuPending = false;
                      }
                    }
                  }

                  Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: modelData.icon
                    sourceSize.width: 18
                    sourceSize.height: 18
                    fillMode: Image.PreserveAspectFit
                  }

                  MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    // Pre-load the menu over D-Bus while the user hovers, so a
                    // right-click usually finds the children already present.
                    // Skip when a menu is already open, or hovering another icon
                    // would swap the visible menu's content underneath it.
                    onContainsMouseChanged: {
                      if (containsMouse && modelData.hasMenu && !trayMenu.visible)
                        trayMenuOpener.menu = modelData.menu;
                    }

                    onClicked: mouse => {
                      if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                          const point = panel.mapFromItem(trayMouse, mouse.x, mouse.y);
                          trayMenu.anchor.rect.x = Math.max(8, Math.min(point.x - trayMenu.width / 2, panel.width - trayMenu.width - 8));
                          trayMenu.anchor.rect.y = panel.implicitHeight;
                          trayMenuOpener.menu = modelData.menu;
                          if (trayMenuOpener.children.values.length > 0) {
                            trayMenu.visible = true;
                          } else {
                            // Children still loading: wait for them so the popup
                            // never renders as an empty themed rectangle.
                            trayItem.menuPending = true;
                          }
                        }
                      } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                      } else {
                        modelData.activate();
                      }
                    }
                  }

                  ToolTip.visible: trayMouse.containsMouse && !trayMenu.visible && !!modelData.tooltip
                  ToolTip.text: modelData.tooltip || ""
                  ToolTip.delay: 500
                }
              }

              // Themed tray context menu. The native display() menu renders as
              // a PlatformMenuEntry through the system Qt theme and cannot be
              // styled from QML, so the item's QsMenuHandle is rendered here
              // with the bar's Chernobyl palette instead.
              QsMenuOpener { id: trayMenuOpener }

              PopupWindow {
                id: trayMenu
                visible: false
                grabFocus: true
                anchor.window: panel
                implicitWidth: 240
                implicitHeight: menuColumn.implicitHeight + 12
                color: "transparent"

                Rectangle {
                  anchors.fill: parent
                  radius: 8
                  color: "#f0171a17"
                  border.width: 1
                  border.color: "#3d5233"

                  Column {
                    id: menuColumn
                    x: 6
                    y: 6
                    spacing: 1

                    Repeater {
                      model: trayMenuOpener.children

                      delegate: Item {
                        id: entry
                        required property var modelData
                        width: 228
                        height: modelData.isSeparator ? 9 : 30

                        MouseArea {
                          id: entryMouse
                          anchors.fill: parent
                          visible: !entry.modelData.isSeparator
                          enabled: entry.modelData.enabled
                          hoverEnabled: true
                          cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                          onClicked: {
                            entry.modelData.triggered();
                            trayMenu.visible = false;
                          }
                        }

                        // Separator rule
                        Rectangle {
                          visible: entry.modelData.isSeparator
                          anchors.centerIn: parent
                          width: parent.width - 12
                          height: 1
                          color: "#485044"
                        }

                        // Hover highlight behind the row content
                        Rectangle {
                          visible: !entry.modelData.isSeparator
                          anchors.fill: parent
                          radius: 5
                          color: entryMouse.containsMouse && entry.modelData.enabled ? "#2a3126" : "transparent"
                          Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Row {
                          visible: !entry.modelData.isSeparator
                          anchors.fill: parent
                          anchors.leftMargin: 10
                          anchors.rightMargin: 10
                          spacing: 8

                          // Check / radio mark
                          Text {
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            width: visible ? 14 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓"
                            color: entry.modelData.checkState === Qt.Checked ? "#9bd45a" : "#5a6055"
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                          }

                          // Item label
                          Text {
                            width: parent.width - parent.spacing - (entry.modelData.buttonType !== QsMenuButtonType.None ? 22 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.text
                            color: !entry.modelData.enabled ? "#5a6055"
                                 : entryMouse.containsMouse ? "#e5e8dc" : "#a5a99d"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 120 } }
                          }

                          // Submenu arrow (rendered, not yet expandable)
                          Text {
                            visible: entry.modelData.hasChildren
                            width: visible ? 12 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: "#5a6055"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                          }
                        }
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: 1
                height: 20
                color: "#485044"
                anchors.verticalCenter: parent.verticalCenter
                visible: SystemTray.items.count > 0
              }

              Rectangle {
                id: powerButton
                width: 83
                height: 29
                radius: 5
                color: powerMouse.containsMouse ? "#402d29" : "#282321"
                scale: powerMouse.containsMouse ? 1.035 : 1
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Row {
                  anchors.centerIn: parent
                  spacing: 6
                  Text { text: "⏻"; color: "#ec8064"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                  Text { text: "POWER"; color: "#e4dfcf"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  id: powerMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: powerProcess.running = true
                }
                ToolTip.visible: powerMouse.containsMouse
                ToolTip.text: "Log out, reboot, or power off"
                ToolTip.delay: 500
              }
            }

            Process {
              id: powerProcess
              command: [Quickshell.env("HOME") + "/mango-desktop/mango/scripts/power-menu.sh"]
            }
          }
        }
      }
    }
  }
}
