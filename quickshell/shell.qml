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

  // Wallpaper picker state + IPC. The overlay reads these models and calls
  // apply(); the mango bind toggles it via `quickshell ipc call wallpaper
  // toggle`. Renderers and the per-monitor state map live in wallpaper-ctl.sh.
  Scope {
    id: picker
    property bool active: false
    property string activeMonitor: ""
    property string selectedMonitor: ""
    property string activeTab: "local"
    property var localModel: []
    property var weModel: []

    readonly property string ctl:
      Quickshell.env("HOME") + "/mango-desktop/mango/scripts/wallpaper-ctl.sh"

    IpcHandler {
      target: "wallpaper"
      function toggle(): void { picker.toggle() }
    }

    // Ask the compositor which monitor is focused so the picker opens there.
    Process {
      id: monitorQuery
      command: ["mmsg", "get", "all-monitors"]
      stdout: SplitParser {
        onRead: line => {
          if (!line.trim().length)
            return;
          try {
            const mons = JSON.parse(line).monitors || [];
            for (const m of mons)
              if (m.active) {
                picker.activeMonitor = m.name;
                picker.selectedMonitor = m.name;
              }
          } catch (e) {
            // Malformed line: the next toggle re-queries.
          }
        }
      }
    }

    Process {
      id: listProcess
      command: [picker.ctl, "list"]
      stdout: SplitParser {
        onRead: line => {
          if (!line.trim().length)
            return;
          try {
            const data = JSON.parse(line);
            picker.localModel = data.local || [];
            picker.weModel = data.we || [];
          } catch (e) {
            // Malformed line: models stay as they were.
          }
        }
      }
    }

    Process {
      id: applyProcess
      command: []
    }

    function close() { active = false; }

    function reload() {
      monitorQuery.running = true;
      listProcess.running = true;
      active = true;
    }

    function toggle() {
      if (active) { active = false; return; }
      reload();
    }

    function apply(type, ref) {
      applyProcess.command = [picker.ctl, "apply", picker.selectedMonitor, type, ref];
      applyProcess.running = true;
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

  // Wallpaper picker overlay: one dimmed full-screen window per screen, shown
  // only on the active monitor while the picker is toggled on.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: pickerWindow
        required property var modelData
        screen: modelData
        visible: picker.active && modelData.name === picker.activeMonitor
        color: "transparent"
        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }
        exclusiveZone: 0
        aboveWindows: true
        focusable: true

        WallpaperPicker {
          pickerState: picker
          anchors.fill: parent
        }
      }
    }
  }
}
