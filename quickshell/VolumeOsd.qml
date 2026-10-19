import QtQuick
import Quickshell

// Volume OSD: bottom-right, only on the screen the helper reported as
// focused. State comes from the shared Scope in shell.qml, which the
// volume-osd.sh helper feeds over its runtime file.
PopupWindow {
  id: osdPopup
  required property var panelWindow // PanelWindow this popup anchors to
  required property var osdState    // shared Scope: active/monitor/volume/muted

  visible: osdState.active && osdState.monitor === panelWindow.screen.name
  anchor.window: panelWindow
  anchor.rect.x: panelWindow.screen.width - width - 20
  anchor.rect.y: panelWindow.screen.height - height - 20
  implicitWidth: 240
  implicitHeight: 64
  color: "transparent"

  onVisibleChanged: if (visible)
    osdEnter.restart()

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: Theme.popupBg
    border.width: 1
    border.color: osdState.muted ? Theme.warning : Theme.accentDim
    opacity: 0
    transform: Translate { id: osdShift; y: 0 }

    ParallelAnimation {
      id: osdEnter
      NumberAnimation { target: parent; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
      NumberAnimation { target: osdShift; property: "y"; from: 10; to: 0; duration: 160; easing.type: Easing.OutCubic }
    }

    Row {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 10

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: osdState.muted ? "🔇" : "🔊"
        font.pixelSize: 20
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 44
        spacing: 6

        Text {
          text: osdState.muted ? "MUTED" : "VOLUME " + Math.round(osdState.volume * 100) + "%"
          color: osdState.muted ? Theme.warning : Theme.accent
          font.bold: true
          font.pixelSize: 12
          font.letterSpacing: 0.5
        }

        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: Theme.panelTint

          Rectangle {
            width: parent.width * (osdState.muted ? 0 : osdState.volume)
            height: parent.height
            radius: 3
            color: osdState.muted ? Theme.warning : Theme.accent

            Behavior on width {
              NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }
  }
}
