import QtQuick
import QtQuick.Controls
import Quickshell

// Notification center bell + review popup. NotificationDaemon (the shared
// singleton) is the sole notification daemon; this file is only the view,
// so counts/history are live bindings on the singleton instead of dunstctl
// polling. The dashboard's notifications card consumes the same singleton.
Item {
  id: notifications
  required property var panelWindow // PanelWindow the popup anchors to
  width: 26
  height: 30

  // Bell glyph (Nerd Fonts md-bell, U+F009A). The default "monospace"
  // resolves to Noto Sans Mono here, which has no patched icons, so the
  // family is explicit.
  Text {
    anchors.centerIn: parent
    text: "󰂚"
    font.family: "JetBrainsMono Nerd Font Mono"
    font.pixelSize: 16
    color: bellMouse.containsMouse || NotificationDaemon.pending > 0
         ? "#e0a044" : "#c8d2c0"
    Behavior on color { ColorAnimation { duration: 140 } }
  }

  // Badge: only for live toasts, never for the bounded history, so the icon
  // does not carry a permanent counter.
  Rectangle {
    visible: NotificationDaemon.pending > 0
    anchors {
      top: parent.top
      right: parent.right
      topMargin: -5
      rightMargin: -4
    }
    width: Math.max(14, badgeText.implicitWidth + 7)
    height: 14
    radius: 7
    color: "#e0a044"
    border.width: 1
    border.color: "#171a17"

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: NotificationDaemon.pending > 99 ? "99+" : String(NotificationDaemon.pending)
      color: "#171a17"
      font.pixelSize: 9
      font.bold: true
    }
  }

  MouseArea {
    id: bellMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (popup.visible) {
        popup.visible = false;
        return;
      }
      const point = panelWindow.mapFromItem(bellMouse, mouse.x, mouse.y);
      popup.anchor.rect.x = Math.max(8, Math.min(point.x - popup.width / 2,
                                                  panelWindow.width - popup.width - 8));
      popup.anchor.rect.y = panelWindow.implicitHeight;
      popup.visible = true;
    }
  }

  ToolTip.visible: bellMouse.containsMouse && !popup.visible
  ToolTip.text: NotificationDaemon.historyCount + " in history"
  ToolTip.delay: 500

  component ActionButton: Rectangle {
    id: actionBtn
    required property string label
    required property var action
    height: 20
    radius: 4
    color: actionMouse.containsMouse ? "#2a3126" : "#20231e"
    border.width: 1
    border.color: actionMouse.containsMouse ? "#9bd45a" : "#4a5a41"
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
      anchors.centerIn: parent
      text: actionBtn.label
      color: actionMouse.containsMouse ? "#e5e8dc" : "#a5a99d"
      font.pixelSize: 9
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

  PopupWindow {
    id: popup
    visible: false
    grabFocus: true // dismisses on any click outside (QuickShell contract)
    anchor.window: panelWindow
    implicitWidth: 340
    implicitHeight: popupBody.implicitHeight + 16
    color: "transparent"

    // First-open size bug (S6): on some monitors the popup maps with a stale
    // geometry (wrong size/anchor) and only the second open looks right.
    // Re-assert geometry right after the window is mapped via callLater,
    // which lands after the platform surface knows the monitor's scale.
    onVisibleChanged: {
      if (!visible)
        return;
      Qt.callLater(popup.reassertGeometry);
    }

    function reassertGeometry() {
      implicitWidth = 340;
      implicitHeight = popupBody.implicitHeight + 16;
      anchor.rect.y = panelWindow.implicitHeight;
      anchor.rect.x = Math.max(8, Math.min(anchor.rect.x,
                                           panelWindow.width - implicitWidth - 8));
    }

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: "#f0171a17"
      border.width: 1
      border.color: "#4a5a41"

      Column {
        id: popupBody
        x: 8
        y: 8
        width: parent.width - 16
        spacing: 6

        // Header: title + live counts.
        Item {
          width: popupBody.width
          height: 18

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "☢  NOTIFICATIONS"
            color: "#a6dc69"
            font.bold: true
            font.pixelSize: 11
            font.letterSpacing: 1
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: NotificationDaemon.historyCount + " history"
                 + (NotificationDaemon.pending > 0
                    ? "  ·  " + NotificationDaemon.pending + " active" : "")
                 + (NotificationDaemon.dnd ? "  ·  DND" : "")
            color: "#5a6055"
            font.pixelSize: 10
          }
        }

        Row {
          width: popupBody.width
          height: 20
          spacing: 6

          ActionButton {
            label: "RESHOW LATEST"
            action: () => NotificationDaemon.reshowEntry()
          }
          ActionButton {
            label: "CLOSE DISPLAYED"
            action: () => NotificationDaemon.closeAllDisplayed()
          }
          ActionButton {
            label: "CLEAR HISTORY"
            action: () => NotificationDaemon.clearHistory()
          }
        }

        Rectangle {
          width: popupBody.width
          height: 1
          color: "#485044"
        }

        Flickable {
          width: popupBody.width
          height: Math.max(24, Math.min(listColumn.implicitHeight + 4, 240))
          contentWidth: width
          contentHeight: listColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          clip: true

          Column {
            id: listColumn
            width: popupBody.width
            spacing: 4

            Text {
              visible: NotificationDaemon.history.length === 0
              width: listColumn.width
              text: "No notifications in history"
              color: "#5a6055"
              font.pixelSize: 10
              horizontalAlignment: Text.AlignHCenter
              topPadding: 4
              bottomPadding: 4
            }

            Repeater {
              model: NotificationDaemon.history

              delegate: Rectangle {
                id: entry
                required property var modelData
                width: listColumn.width
                height: entryCol.implicitHeight + 10
                radius: 6
                color: entryMouse.containsMouse ? "#2a3126" : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Column {
                  id: entryCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  anchors.topMargin: 5
                  spacing: 2

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
                      color: entry.modelData.urgency === "CRITICAL" ? "#d94b43" : "#e5e8dc"
                      font.bold: true
                      font.pixelSize: 11
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Text {
                    width: entryCol.width
                    text: entry.modelData.appname
                        + (entry.modelData.body ? "  ·  " + entry.modelData.body : "")
                    color: "#a5a99d"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 2
                  }
                }

                MouseArea {
                  id: entryMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: NotificationDaemon.reshowEntry(entry.modelData.id)
                }

                ToolTip.visible: entryMouse.containsMouse
                ToolTip.text: "Re-show this notification"
                ToolTip.delay: 500
              }
            }
          }
        }
      }
    }
  }
}
