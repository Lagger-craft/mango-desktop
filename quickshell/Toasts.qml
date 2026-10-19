import QtQuick
import QtQuick.Controls
import Quickshell

// Toast host for one screen: a PopupWindow anchored under the bar's right
// island showing the NotificationDaemon's live entries while this screen is
// the toast target. One instance per screen inside the bar's PanelWindow;
// only the focused screen's host is visible ("" monitor shows everywhere).
PopupWindow {
  id: toastRoot

  required property var panelWindow // PanelWindow the toasts anchor to
  readonly property bool isTarget:
    NotificationDaemon.toastMonitor === "" || NotificationDaemon.toastMonitor === panelWindow.screen.name

  visible: isTarget && NotificationDaemon.live.length > 0
  anchor.window: panelWindow
  // Below the bar, flush with its bottom edge (same geometry convention as
  // the calendar popup: Mango offsets nothing here — the bar window's own
  // bottom is the anchor origin).
  anchor.rect.y: panelWindow.implicitHeight
  anchor.rect.x: panelWindow.width - width - 8
  color: "transparent"

  // Keep flush with the bar while entries appear/disappear.
  onVisibleChanged: reanchor()
  onImplicitHeightChanged: reanchor()
  function reanchor() {
    anchor.rect.x = panelWindow.width - width - 8;
    anchor.rect.y = panelWindow.implicitHeight;
  }

  implicitWidth: 360
  implicitHeight: toastColumn.implicitHeight + 12

  Column {
    id: toastColumn
    x: 6
    y: 6
    width: parent.width - 12
    spacing: 6

    Repeater {
      // Newest first, but render oldest at top so new ones push in at the
      // bottom edge near the bar? Newest at top, oldest at the bottom.
      model: NotificationDaemon.live

      delegate: Rectangle {
        id: toast
        required property var modelData
        required property int index
        width: toastColumn.width
        height: toastBody.implicitHeight + 12
        radius: 8
        color: "#f0171a17"
        border.width: 1
        border.color: NotificationDaemon.urgencyColor(toast.modelData.urgency)

        // Enter animation: slide + fade from under the bar.
        opacity: 0
        transform: Translate { y: -8 }
        Component.onCompleted: appear.restart()
        SequentialAnimation {
          id: appear
          ParallelAnimation {
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: toast; property: "y"; from: -10; to: 0; duration: 160; easing.type: Easing.OutCubic }
          }
        }

        Column {
          id: toastBody
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          anchors.topMargin: 6
          spacing: 2

          Row {
            width: toastBody.width
            spacing: 6

            Rectangle {
              width: 6
              height: 6
              radius: 3
              anchors.verticalCenter: parent.verticalCenter
              color: NotificationDaemon.urgencyColor(toast.modelData.urgency)
            }

            Text {
              width: parent.width - 12
              text: toast.modelData.summary
              color: toast.modelData.urgency === "CRITICAL" ? "#d94b43" : "#e5e8dc"
              font.bold: true
              font.pixelSize: 11
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }

          Text {
            visible: toast.modelData.body.length > 0
            width: toastBody.width
            text: toast.modelData.appname + "  ·  " + toast.modelData.body
            color: "#a5a99d"
            font.pixelSize: 10
            elide: Text.ElideRight
            maximumLineCount: 3
            wrapMode: Text.WordWrap
          }

          Row {
            spacing: 4

            Repeater {
              model: toast.modelData.actions

              delegate: Rectangle {
                id: actBtn
                required property var modelData
                width: actText.implicitWidth + 12
                height: 18
                radius: 4
                color: actMouse.containsMouse ? "#2a3126" : "#20231e"
                border.width: 1
                border.color: actMouse.containsMouse ? "#9bd45a" : "#4a5a41"

                Text {
                  id: actText
                  anchors.centerIn: parent
                  text: actBtn.modelData.text
                  color: "#a5a99d"
                  font.pixelSize: 9
                }

                MouseArea {
                  id: actMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    const n = NotificationDaemon.trackedMap[String(toast.modelData.id)];
                    if (n)
                      for (const a of n.actions)
                        if (a.identifier === actBtn.modelData.identifier)
                          a.invoke();
                    NotificationDaemon.closeToast(toast.modelData.id);
                  }
                }
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          z: -1
          onClicked: NotificationDaemon.closeToast(toast.modelData.id)
        }
      }
    }
  }
}
