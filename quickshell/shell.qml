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

              Text {
                text: "TAGS  1–9"
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
                  required property var modelData
                  width: 30
                  height: 30

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
                    onClicked: mouse => {
                      if (mouse.button === Qt.RightButton) {
                        const point = panel.mapFromItem(trayMouse, mouse.x, mouse.y);
                        modelData.display(panel, point.x, point.y);
                      } else if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                      } else {
                        modelData.activate();
                      }
                    }
                  }

                  ToolTip.visible: trayMouse.containsMouse && !!modelData.tooltip
                  ToolTip.text: modelData.tooltip || ""
                  ToolTip.delay: 500
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
