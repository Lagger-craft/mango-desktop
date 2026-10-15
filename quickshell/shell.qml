//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

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

            Tags {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              screenName: panel.screen.name
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
