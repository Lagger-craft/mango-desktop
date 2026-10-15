import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
  id: powerButton
  width: 83
  height: 29
  radius: 5
  color: powerMouse.containsMouse ? "#402d29" : "#282321"
  scale: powerMouse.containsMouse ? 1.035 : 1

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

  Process {
    id: powerProcess
    command: [Quickshell.env("HOME") + "/mango-desktop/mango/scripts/power-menu.sh"]
  }
}
