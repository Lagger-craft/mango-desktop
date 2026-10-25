import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Full-screen dashboard overlay, mirroring the WallpaperPicker structure
// (dim backdrop + centered card). All state lives in the shell's `dashboard`
// Scope, passed by reference as dashboardState: `active` says when to show,
// `close()` dismisses. The notifications card consumes the shared
// NotificationDaemon singleton. Nothing
// here touches the network: artwork is local-file-only and the system card
// reads procfs.
Item {
  id: dashboard
  required property var dashboardState // Scope: property bool active, function close()
  focus: true
  anchors.fill: parent

  readonly property color surface: Theme.surface
  readonly property color accent: Theme.accent
  readonly property color amber: Theme.warning
  readonly property color red: Theme.critical
  readonly property color textPrimary: Theme.textPrimary
  readonly property color textSecondary: Theme.textIdle
  readonly property color textDim: Theme.textDim
  readonly property color panel: Theme.surfaceUp
  readonly property color edge: Theme.outline
  readonly property string mono: "JetBrainsMono Nerd Font Mono"

  Keys.onEscapePressed: dashboardState.close()

  // ---- system stats -----------------------------------------------------
  // CPU/RAM live on the shared SysStats singleton (one parser for the panel
  // bubbles and this card); only uptime/kernel are read here (procfs).
  property string uptimeText: "…"
  property string kernelText: "…"

  function parseUptime(text) {
    const s = parseFloat((text || "").trim().split(/\s+/)[0]);
    if (!isFinite(s))
      return;
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    dashboard.uptimeText = d > 0 ? d + "d " + h + "h"
                         : h > 0 ? h + "h " + m + "m"
                                 : m + "m";
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    printErrors: false
    onTextChanged: dashboard.parseUptime(this.text())
  }
  FileView { // kernel never changes while running; read once
    path: "/proc/sys/kernel/osrelease"
    printErrors: false
    onTextChanged: dashboard.kernelText = this.text().trim()
  }

  Timer {
    id: sysTimer
    interval: 500
    running: dashboard.dashboardState.active
    repeat: true
    property int ticks: 0
    onTriggered: {
      ticks++;
      if (ticks % 4 === 0) // uptime changes too slowly to churn every tick
        uptimeFile.reload();
      // CPU/RAM are polled by the shared SysStats singleton; notification
      // state is live on the NotificationDaemon singleton. No polling here.
    }
  }

  Connections {
    target: dashboard.dashboardState
    function onActiveChanged() {
      if (!dashboard.dashboardState.active)
        return;
      // CPU/RAM come pre-warmed from SysStats' continuous polling; only the
      // slow-changing fields need a refresh at open.
      uptimeFile.reload();
      sysTimer.restart();
      dashboardEnter.restart();
    }
    function onClosingChanged() {
      if (dashboard.dashboardState.closing)
        dashboardExit.restart();
      else
        dashboard.opacity = 1; // reset before the next enter
    }
  }

  // Enter: fade + rise of the whole overlay; exit: fade (the host window
  // stays mapped during dashboard.closing, see shell.qml).
  opacity: 1
  transform: Translate { id: dashShift; y: 0 }
  ParallelAnimation {
    id: dashboardEnter
    NumberAnimation { target: dashboard; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { target: dashShift; property: "y"; from: 14; to: 0; duration: 200; easing.type: Easing.OutCubic }
  }
  SequentialAnimation {
    id: dashboardExit
    NumberAnimation { target: dashboard; property: "opacity"; from: 1; to: 0; duration: 180; easing.type: Easing.InCubic }
  }

  // ---- MPRIS --------------------------------------------------------------
  // Prefer the player that is actually playing; else any known player.
  readonly property var player: {
    const list = Mpris.players.values;
    for (const p of list)
      if (p.playbackState === MprisPlaybackState.Playing)
        return p;
    return list.length > 0 ? list[0] : null;
  }
  // Artwork: local file URLs only. Players often advertise http(s) cover
  // URLs; fetching those would be a network request (S4 forbids it), so
  // anything that is not file:// renders the placeholder glyph instead.
  readonly property string artSource: {
    const url = player ? String(player.trackArtUrl) : "";
    return url.indexOf("file://") === 0 ? url : "";
  }

  // ---- session actions (same commands as mango power-menu.sh) ------------
  Process { id: logoutProc; command: ["mango", "-s", "quit"] }
  Process { id: rebootProc; command: ["systemctl", "reboot"] }
  Process { id: poweroffProc; command: ["systemctl", "poweroff"] }

  // ---- inline components -------------------------------------------------
  component Bar: Rectangle {
    id: bar
    property real value: 0 // 0..1
    readonly property color fillColor: value > 0.90 ? dashboard.red
                                       : value > 0.75 ? dashboard.amber
                                                      : dashboard.accent
    width: parent.width
    height: 6
    radius: 3
    color: Theme.panelTint

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, bar.value))
      height: parent.height
      radius: 3
      color: bar.fillColor

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }
  }

  component Card: Rectangle {
    id: card
    required property string title
    property string meta: ""
    default property alias content: cardBody.data

    color: dashboard.panel
    radius: 6
    border.width: 1
    border.color: dashboard.edge

    Text {
      id: cardTitle
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: 10
      anchors.topMargin: 10
      text: card.title
      color: dashboard.accent
      font.family: dashboard.mono
      font.bold: true
      font.pixelSize: 12
      font.letterSpacing: 1
    }
    Text {
      anchors.right: parent.right
      anchors.baseline: cardTitle.baseline
      anchors.rightMargin: 10
      text: card.meta
      color: dashboard.textDim
      font.family: dashboard.mono
      font.pixelSize: 10
    }
    Rectangle {
      id: cardDivider
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: cardTitle.bottom
      anchors.topMargin: 8
      height: 1
      color: Theme.divider
    }
    Column {
      id: cardBody
      anchors.top: cardDivider.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 10
      spacing: 6
    }
  }

  component ActionButton: Rectangle {
    id: actionBtn
    required property string label
    required property var action
    width: actionLabel.implicitWidth + 24
    height: 22
    radius: 4
    color: actionMouse.containsMouse ? Theme.hover : Theme.buttonBg
    border.width: 1
    border.color: actionMouse.containsMouse ? dashboard.accent : dashboard.edge
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
      id: actionLabel
      anchors.centerIn: parent
      text: actionBtn.label
      color: actionMouse.containsMouse ? dashboard.textPrimary : dashboard.textSecondary
      font.family: dashboard.mono
      font.pixelSize: 10
      font.bold: true
      font.letterSpacing: 0.5
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionBtn.action()
    }
  }

  component SessionButton: Rectangle {
    id: sessBtn
    required property string label
    required property string command
    property string tone: "normal" // "normal" | "amber" | "red"
    required property var action

    readonly property color toneColor: tone === "red" ? dashboard.red
                                       : tone === "amber" ? dashboard.amber
                                                          : dashboard.edge
    // Danger tones keep a permanent (dimmed) amber/red border, brightening
    // on hover; the neutral action blends in until hovered.
    readonly property color baseTone: tone === "normal" ? dashboard.edge
                                      : Qt.rgba(toneColor.r, toneColor.g, toneColor.b, 0.45)
    width: parent.width
    height: 42
    radius: 6
    color: sessMouse.containsMouse ? Theme.hover : Theme.buttonBg
    border.width: 1
    border.color: sessMouse.containsMouse ? toneColor : baseTone
    opacity: enabled ? 1 : 0.4
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: sessBtn.label
      color: sessMouse.containsMouse || sessBtn.tone !== "normal"
           ? sessBtn.toneColor : dashboard.textPrimary
      font.family: dashboard.mono
      font.bold: true
      font.pixelSize: 12
      font.letterSpacing: 1
      Behavior on color { ColorAnimation { duration: 120 } }
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: sessBtn.command
      color: dashboard.textDim
      font.family: dashboard.mono
      font.pixelSize: 10
    }

    MouseArea {
      id: sessMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: sessBtn.action()
    }
  }

  component TransportButton: Rectangle {
    id: transportBtn
    required property string glyph
    required property var action
    width: 36
    height: 30
    radius: 4
    color: transportMouse.containsMouse ? Theme.hover : Theme.buttonBg
    border.width: 1
    border.color: transportMouse.containsMouse ? dashboard.accent : dashboard.edge
    opacity: enabled ? 1 : 0.4
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
      anchors.centerIn: parent
      text: transportBtn.glyph
      color: transportMouse.containsMouse ? dashboard.accent : dashboard.textSecondary
      font.family: dashboard.mono
      font.pixelSize: 14
    }
    MouseArea {
      id: transportMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: transportBtn.action()
    }
  }

  // ---- overlay ------------------------------------------------------------
  // Dim backdrop; click anywhere to dismiss.
  Rectangle {
    anchors.fill: parent
    color: Theme.overlayBg
    MouseArea {
      anchors.fill: parent
      onClicked: dashboard.dashboardState.close()
    }
  }

  // ---- card ---------------------------------------------------------------
  Rectangle {
    anchors.centerIn: parent
    width: Math.min(900, parent.width - 60)
    height: Math.min(560, parent.height - 60)
    color: dashboard.surface
    border.color: dashboard.accent
    border.width: 2
    radius: 10

    // Subtle green top edge, matching the bar.
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 2
      radius: 10
      color: dashboard.accent
    }

    // Header: title on the left, close on the right.
    Item {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 16
      height: 26

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "☢  DASHBOARD"
        color: dashboard.accent
        font.family: dashboard.mono
        font.bold: true
        font.pixelSize: 15
      }
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: closeLabel.implicitWidth + 20
        height: 24
        radius: 4
        color: closeMouse.containsMouse ? Theme.buttonHoverBg : Theme.panel
        border.color: dashboard.edge
        Text {
          id: closeLabel
          anchors.centerIn: parent
          text: "✕ CLOSE"
          color: closeMouse.containsMouse ? Theme.criticalSoft : dashboard.textSecondary
          font.family: dashboard.mono
          font.pixelSize: 11
        }
        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: dashboard.dashboardState.close()
        }
      }
    }

    // 2x2 card grid, plain geometry like the rest of the shell (no layouts).
    Item {
      id: cardsArea
      anchors.top: header.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.topMargin: 12
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      anchors.bottomMargin: 16

      // -- Notifications: bounded history on the NotificationDaemon
      // singleton — the only notification view left (S3).
      Card {
        title: "NOTIFICATIONS"
        meta: NotificationDaemon.historyCount + " history"
        x: 0
        y: 0
        width: (parent.width - 12) / 2
        height: (parent.height - 12) / 2

        Row {
          spacing: 6

          ActionButton {
            label: "CLEAR HISTORY"
            action: () => NotificationDaemon.clearHistory()
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Theme.divider
        }

        Flickable {
          width: parent.width
          height: Math.max(40, parent.height - y)
          contentWidth: width
          contentHeight: notifColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          Column {
            id: notifColumn
            width: parent.width
            spacing: 4

            Text {
              visible: NotificationDaemon.history.length === 0
              width: notifColumn.width
              text: "No notifications in history"
              color: dashboard.textDim
              font.family: dashboard.mono
              font.pixelSize: 10
              horizontalAlignment: Text.AlignHCenter
              topPadding: 8
            }

            Repeater {
              model: NotificationDaemon.history

              delegate: Rectangle {
                id: entry
                required property var modelData
                width: notifColumn.width
                height: entryCol.implicitHeight + 8
                radius: 6
                color: "transparent"

                Column {
                  id: entryCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  anchors.topMargin: 4
                  spacing: 1

                  Row {
                    width: entryCol.width
                    spacing: 6

                    Rectangle {
                      width: 6
                      height: 6
                      radius: 3
                      anchors.verticalCenter: parent.verticalCenter
                      color: NotificationDaemon.urgencyColor(entry.modelData.urgency)
                    }

                    Text {
                      width: parent.width - 12
                      text: entry.modelData.summary
                      color: entry.modelData.urgency === "CRITICAL" ? dashboard.red : dashboard.textPrimary
                      font.family: dashboard.mono
                      font.bold: true
                      font.pixelSize: 10
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Text {
                    width: entryCol.width
                    text: entry.modelData.appname
                        + (entry.modelData.body ? "  ·  " + entry.modelData.body : "")
                    color: dashboard.textSecondary
                    font.family: dashboard.mono
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    maximumLineCount: 2
                  }
                }
              }
            }
          }
        }
      }

      // -- System: CPU/RAM from SysStats, uptime/kernel straight from procfs.
      Card {
        title: "SYSTEM"
        meta: dashboard.uptimeText + " up"
        x: (parent.width + 12) / 2
        y: 0
        width: (parent.width - 12) / 2
        height: (parent.height - 12) / 2

        Item {
          width: parent.width
          height: 16
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "CPU"
            color: dashboard.textSecondary
            font.family: dashboard.mono
            font.pixelSize: 11
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(SysStats.cpuPct) + "%"
            color: dashboard.textPrimary
            font.family: dashboard.mono
            font.bold: true
            font.pixelSize: 11
          }
        }
        Bar { value: SysStats.cpuPct / 100 }

        Item {
          width: parent.width
          height: 16
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "RAM"
            color: dashboard.textSecondary
            font.family: dashboard.mono
            font.pixelSize: 11
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: SysStats.memUsedGiB.toFixed(1) + " / "
                + SysStats.memTotalGiB.toFixed(1) + " GiB"
            color: dashboard.textPrimary
            font.family: dashboard.mono
            font.bold: true
            font.pixelSize: 11
          }
        }
        Bar { value: SysStats.memTotalGiB > 0 ? SysStats.memUsedGiB / SysStats.memTotalGiB : 0 }

        Item {
          width: parent.width
          height: 16
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "UP"
            color: dashboard.textSecondary
            font.family: dashboard.mono
            font.pixelSize: 11
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: dashboard.uptimeText
            color: dashboard.textPrimary
            font.family: dashboard.mono
            font.bold: true
            font.pixelSize: 11
          }
        }

        Text {
          width: parent.width
          text: "_kernel  " + dashboard.kernelText
          color: dashboard.textDim
          font.family: dashboard.mono
          font.pixelSize: 10
          elide: Text.ElideRight
        }
      }

      // -- Music: active MPRIS player, local artwork only.
      Card {
        title: "MUSIC"
        meta: dashboard.player ? dashboard.player.identity : ""
        x: 0
        y: (parent.height + 12) / 2
        width: (parent.width - 12) / 2
        height: (parent.height - 12) / 2

        Item {
          width: parent.width
          height: Math.max(40, parent.height - y)

          Text {
            anchors.centerIn: parent
            visible: dashboard.player === null
            text: "NO PLAYER"
            color: dashboard.textDim
            font.family: dashboard.mono
            font.bold: true
            font.pixelSize: 14
            font.letterSpacing: 2
          }

          Row {
            anchors.fill: parent
            visible: dashboard.player !== null
            spacing: 12

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 88
              height: 88
              radius: 6
              color: Theme.deep
              border.width: 1
              border.color: dashboard.edge

              Image {
                anchors.fill: parent
                anchors.margins: 2
                visible: dashboard.artSource !== ""
                source: dashboard.artSource
                // Decode at 2x the 88px box instead of the source's full
                // resolution: album art can be several MB decoded for a
                // thumbnail nobody sees bigger than 88px.
                sourceSize.width: 176
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
              Text { // placeholder when there is no local artwork
                anchors.centerIn: parent
                visible: dashboard.artSource === ""
                text: "󰀁"
                color: dashboard.textDim
                font.family: dashboard.mono
                font.pixelSize: 30
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 100
              spacing: 4

              Text {
                width: parent.width
                text: (dashboard.player && dashboard.player.trackTitle) || "Unknown track"
                color: dashboard.textPrimary
                font.family: dashboard.mono
                font.bold: true
                font.pixelSize: 13
                elide: Text.ElideRight
                maximumLineCount: 1
              }
              Text {
                width: parent.width
                text: (dashboard.player && dashboard.player.trackArtist) || "Unknown artist"
                color: dashboard.textSecondary
                font.family: dashboard.mono
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              Row {
                spacing: 8

                TransportButton {
                  glyph: "󰒮" // md-skip-previous
                  enabled: dashboard.player ? dashboard.player.canGoPrevious : false
                  action: () => dashboard.player.previous()
                }
                TransportButton {
                  glyph: (dashboard.player && dashboard.player.isPlaying) ? "󰏤" : "󰐊" // pause / play
                  enabled: dashboard.player ? dashboard.player.canTogglePlaying : false
                  action: () => dashboard.player.togglePlaying()
                }
                TransportButton {
                  glyph: "󰒭" // md-skip-next
                  enabled: dashboard.player ? dashboard.player.canGoNext : false
                  action: () => dashboard.player.next()
                }
              }
            }
          }
        }
      }

      // -- Session: the same commands as mango power-menu.sh.
      Card {
        title: "SESSION"
        meta: "power"
        x: (parent.width + 12) / 2
        y: (parent.height + 12) / 2
        width: (parent.width - 12) / 2
        height: (parent.height - 12) / 2

        SessionButton {
          label: "LOGOUT"
          command: "mango -s quit"
          action: () => logoutProc.running = true
        }
        SessionButton {
          label: "REBOOT"
          command: "systemctl reboot"
          tone: "amber"
          action: () => rebootProc.running = true
        }
        SessionButton {
          label: "POWEROFF"
          command: "systemctl poweroff"
          tone: "red"
          action: () => poweroffProc.running = true
        }
      }
    }

    // Footer hint.
    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      horizontalAlignment: Text.AlignHCenter
      color: dashboard.textDim
      font.family: dashboard.mono
      font.pixelSize: 9
      text: "ESC or backdrop to close"
    }
  }
}
