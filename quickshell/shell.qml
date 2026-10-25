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

    // closing/fadingMonitor keep the picker window alive for its exit fade.
    function close() {
      if (!active)
        return;
      active = false;
      fadingMonitor = activeMonitor;
      closing = true;
      pickerClosingTimer.restart();
    }

    property bool closing: false
    property string fadingMonitor: ""

    Timer {
      id: pickerClosingTimer
      interval: 190
      onTriggered: picker.closing = false
    }

    function reload() {
      monitorQuery.running = true;
      listProcess.running = true;
      closing = false;
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

  // Dashboard overlay state (S2/S3): toggled by the ZONE label click or the
  // `quickshell ipc call dashboard toggle` bind; opens on the focused
  // monitor. The full-screen overlay lives in the per-screen Variants below.
  // closing/fadingMonitor keep the overlay window alive for its exit fade.
  Scope {
    id: dashboard
    property bool active: false
    property string activeMonitor: ""
    property bool closing: false
    property string fadingMonitor: ""

    IpcHandler {
      target: "dashboard"
      function toggle(): void { dashboard.toggle() }
    }

    // Ask the compositor which monitor is focused so the overlay opens there.
    Process {
      id: dashboardMonitorQuery
      command: ["mmsg", "get", "all-monitors"]
      stdout: SplitParser {
        onRead: line => {
          if (!line.trim().length)
            return;
          try {
            const mons = JSON.parse(line).monitors || [];
            for (const m of mons)
              if (m.active) {
                dashboard.activeMonitor = m.name;
                break;
              }
          } catch (e) {
            // Malformed line: the next toggle re-queries.
          }
        }
      }
    }

    function close() {
      if (!active)
        return;
      active = false;
      fadingMonitor = activeMonitor;
      closing = true;
      closingTimer.restart();
    }

    Timer {
      id: closingTimer
      interval: 190
      onTriggered: dashboard.closing = false
    }

    function toggle() {
      if (active) { close(); return; }
      closing = false;
      dashboardMonitorQuery.running = true;
      active = true;
    }
  }

  // Calendar popup state (S1): toggled by a clock-island click or
  // `quickshell ipc call calendar toggle`; per-screen popups below watch
  // active and position themselves under the clock island.
  Scope {
    id: calendarState
    property bool active: false
    // Anchor requested by the latest click: the click writes the exact
    // coordinates; each screen's popup applies them when it becomes visible.
    // Anchors must not be passed by cross-Variants id here: ids of sibling
    // delegate Components do not resolve from another delegate's JS.
    property real clickX: 0

    function toggleAt(screenName, xOnPanel) {
      targetMonitor = screenName;
      clickX = xOnPanel;
      if (active) { active = false; return; }
      active = true;
    }
    property string targetMonitor: ""

    // IPC opens have no click: they resolve to the focused monitor; empty
    // targetMonitor means "delegate the choice to the monitor query".
    readonly property string requestedMonitor:
      targetMonitor !== "" ? targetMonitor : calendarTargetMonitor.monitor

    IpcHandler {
      target: "calendar"
      function toggle(): void {
        if (calendarState.active) {
          calendarState.active = false;
          return;
        }
        calendarState.targetMonitor = "";
        calendarTargetMonitor.requery();
        calendarState.active = true;
      }
    }
  }

  // Audio panel state (S1): toggled by the speaker icon in the right island
  // or the `quickshell ipc call audio toggle` bind. The panel opens on the
  // screen it was opened from; an IPC open uses the focused monitor.
  Scope {
    id: audioPanelState
    property bool active: false
    property string targetMonitor: ""

    // An IPC open has no click: it delegates the choice to the monitor query.
    readonly property string requestedMonitor:
      targetMonitor !== "" ? targetMonitor : audioTargetMonitor.monitor

    IpcHandler {
      target: "audio"
      function toggle(): void {
        if (audioPanelState.active) {
          audioPanelState.active = false;
          return;
        }
        audioPanelState.targetMonitor = "";
        audioTargetMonitor.requery();
        audioPanelState.active = true;
      }
    }

    function toggleAt(monitor) {
      if (active && targetMonitor === monitor) {
        active = false;
        return;
      }
      targetMonitor = monitor;
      active = true;
    }
  }

  // The one screen the audio panel appears on when it is opened without a
  // click: the currently focused monitor, re-queried on every IPC open.
  Scope {
    id: audioTargetMonitor
    property string monitor: ""

    function requery() { audioMonitorQuery.running = true; }

    Process {
      id: audioMonitorQuery
      command: ["mmsg", "get", "all-monitors"]
      stdout: SplitParser {
        onRead: line => {
          if (!line.trim().length)
            return;
          try {
            const mons = JSON.parse(line).monitors || [];
            for (const m of mons)
              if (m.active) {
                audioTargetMonitor.monitor = m.name;
                break;
              }
          } catch (e) {
            // Keep the previous monitor on a malformed line.
          }
        }
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
        implicitHeight: 44
        exclusiveZone: 44
        color: "transparent"

        // Volume OSD: bottom-right, only on the screen the helper reported as
        // focused.
        VolumeOsd {
          panelWindow: panel
          osdState: osd
        }

        // The bar renders as three floating islands instead of one solid
        // strip: translucent charcoal + green hairline border, so Mango's
        // layer blur (blur_layer=1) frosts only the island bodies while the
        // gaps stay crisp wallpaper.

        // Left island: zone label, tag skulls, screen name.
        Rectangle {
          id: leftIsland
          anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
          }
          height: 30
          width: tagsRow.implicitWidth + 24
          radius: 10
          color: Theme.panelBg
          border.width: 1
          border.color: Theme.accentBorder

          Rectangle { // toxic top accent, inset past the rounded corners
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 2
            color: Theme.accent
          }

          Row {
            id: tagsRow
            anchors.centerIn: parent
            Tags {
              screenName: panel.screen.name

              onZoneClicked: dashboard.toggle()
            }
          }
        }

        // Center island: clock.
        Rectangle {
          id: centerIsland
          anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
          }
          height: 30
          width: clock.implicitWidth + 28
          radius: 10
          color: Theme.panelBg
          border.width: 1
          border.color: Theme.accentBorder

          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 2
            color: Theme.accent
          }

          Clock {
            id: clock
            anchors.centerIn: parent
          }

          // Clock island click -> calendar popup below the island (S1). The
          // popup anchors to the bar window's bottom edge, horizontally
          // centered on the island (same geometry as the tray menu popup).
          // Open on clicked (after release), not on pressed: opening during
          // the press installs an input grab, and the same click's release
          // then arrives as an "outside click", closing the popup instantly.
          // The heavy lifting lives in calendarState.toggleAt().
          MouseArea {
            id: clockMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const point = panel.mapFromItem(centerIsland, centerIsland.width / 2, 0);
              calendarState.toggleAt(panel.screen.name, point.x);
            }
          }
        }

        // Right island: stat bubbles, system tray, audio and power icons.
        // Notifications are silent: no toasts, no bell — the dashboard card
        // is the only view (S3).
        Rectangle {
          id: rightIsland
          anchors {
            right: parent.right
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          height: 30
          width: actionsRow.implicitWidth + 20
          radius: 10
          color: Theme.panelBg
          border.width: 1
          border.color: Theme.accentBorder

          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 2
            color: Theme.accent
          }

          Row {
            id: actionsRow
            anchors.centerIn: parent
            spacing: 6

            // CPU / RAM / GPU bubbles (S1/S2), split from the controls by a
            // hairline divider. Both sit centered in the 30 px action band
            // like every sibling (the Row top-aligns its children).
            StatBubbles {}

            Rectangle {
              width: 1
              height: 16
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.divider
            }

            Tray {
              panelWindow: panel
            }

            AudioButton {
              panelWindow: panel
              panelState: audioPanelState
            }

            PowerButton {}
          }
        }
      }
    }
  }

  // Calendar popup: every screen owns one anchored below its clock island;
  // only the popup on the target screen becomes visible.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: calendarWindow
        required property var modelData
        screen: modelData
        color: "transparent"
        anchors { top: true; left: true; right: true }
        implicitHeight: 44
        // Anchor-only host for the calendar popup; the bar itself reserves
        // the exclusive zone, so reserving again here would push the bar
        // down by 44px (stacked exclusive zones).
        exclusiveZone: 0

        // Mango shifts same-edge sibling layer surfaces below the bar's
        // exclusive zone, so this empty 44px host lands in the strip right
        // under the bar. Without an explicit empty region it intercepts
        // clicks there even with the calendar closed (browsers couldn't be
        // clicked at the top of their window). Click-through everywhere;
        // the visible PopupWindow is a separate surface and keeps its input.
        mask: Region {}

        property bool isTarget: modelData.name === calendarState.targetMonitor

        CalendarPopup {
          panelWindow: calendarWindow
          visible: calendarState.active && calendarWindow.isTarget

          // Anchor application: a mouse click wrote exact coordinates
          // (calendarState.clickX); an IPC open falls back to centered
          // under the clock island (centered on the bar) flush with the
          // bar's bottom edge: Mango offsets this host window below the
          // bar's exclusive zone, so the host's top IS the bar's bottom;
          // keep the popup glued to it (no extra 44px gap).
          onVisibleChanged: {
            if (!visible)
              return;
            anchor.rect.y = 0;
            if (calendarState.clickX > 0) {
              anchor.rect.x = Math.max(8, Math.min(calendarState.clickX - width / 2, calendarWindow.width - width - 8));
              calendarState.clickX = 0;
            } else {
              anchor.rect.x = Math.max(8, (calendarWindow.width - width) / 2);
            }
          }
        }
      }
    }
  }

  // The one screen the calendar popup appears on: the currently focused
  // monitor, re-queried each time the IPC toggle opens it.
  Scope {
    id: calendarTargetMonitor
    property string monitor: ""

    function requery() { calendarMonitorQuery.running = true; }

    Process {
      id: calendarMonitorQuery
      command: ["mmsg", "get", "all-monitors"]
      stdout: SplitParser {
        onRead: line => {
          if (!line.trim().length)
            return;
          try {
            const mons = JSON.parse(line).monitors || [];
            for (const m of mons)
              if (m.active) {
                calendarTargetMonitor.monitor = m.name;
                break;
              }
          } catch (e) {
            // Keep the previous monitor on a malformed line.
          }
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: pickerWindow
        required property var modelData
        screen: modelData
        visible: (picker.active && modelData.name === picker.activeMonitor)
              || (picker.closing && modelData.name === picker.fadingMonitor)
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

  // Dashboard overlay: one dimmed full-screen window per screen, shown only
  // on the focused monitor while the dashboard is toggled on (S3). The brief
  // non-active visibility during dashboard.closing keeps the window mapped
  // while the exit fade runs.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: dashboardWindow
        required property var modelData
        screen: modelData
        visible: (dashboard.active && modelData.name === dashboard.activeMonitor)
              || (dashboard.closing && modelData.name === dashboard.fadingMonitor)
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

        Dashboard {
          dashboardState: dashboard
          anchors.fill: parent
        }
      }
    }
  }
}
