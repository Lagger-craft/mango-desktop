import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Icon-only power control: the frame and the "POWER" label are gone, so
// the island just carries the glyph with hover feedback and tooltip.
Item {
  id: powerButton
  width: 26
  height: 30

  Text {
    anchors.centerIn: parent
    text: "⏻"
    color: powerMouse.containsMouse ? Theme.criticalSoft : Theme.textIdle
    font.pixelSize: 17
    Behavior on color { ColorAnimation { duration: 140 } }
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
