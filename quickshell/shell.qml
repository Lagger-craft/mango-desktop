import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick

ShellRoot {
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
        implicitHeight: 36
        exclusiveZone: 36
        color: "#171a17"

        Rectangle {
          anchors.fill: parent
          color: "#171a17"
          border.color: "#333a32"
          border.width: 1

          Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Text {
              text: "☢  ZONE"
              color: "#9bd45a"
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 1; height: 1 }

            Row {
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter

              Repeater {
                model: SystemTray.items
                delegate: Item {
                  required property var modelData
                  width: 24
                  height: 26

                  Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: modelData.icon
                    sourceSize.width: 20
                    sourceSize.height: 20
                    fillMode: Image.PreserveAspectFit
                  }

                  MouseArea {
                    id: trayMouse
                    anchors.fill: parent
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
                }
              }
            }

            Item { width: 1; height: 1 }

            Text {
              id: clock
              color: "#e5e8dc"
              anchors.verticalCenter: parent.verticalCenter
              Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm:ss")
              }
            }

            Text {
              text: "WALLPAPER"
              color: "#d7a64a"
              anchors.verticalCenter: parent.verticalCenter
              MouseArea {
                anchors.fill: parent
                onClicked: wallpaperProcess.running = true
              }
            }

            Text {
              text: "POWER"
              color: "#e07055"
              anchors.verticalCenter: parent.verticalCenter
              MouseArea {
                anchors.fill: parent
                onClicked: powerProcess.running = true
              }
            }

            Process {
              id: wallpaperProcess
              command: [Quickshell.env("HOME") + "/mango-desktop/mango/scripts/wallpaper-selector.sh"]
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
