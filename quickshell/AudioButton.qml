import QtQuick
import QtQuick.Controls
import Quickshell

// Speaker glyph in the right island: opens the audio panel. The glyph
// reflects the mute state of the default output, so a mute done with the
// keyboard (XF86AudioMute) is visible in the bar too.
Item {
  id: button
  required property var panelWindow // PanelWindow the panel anchors to
  required property var panelState  // shared Scope: open/closed + target screen

  width: 26
  height: 30

  Text {
    anchors.centerIn: parent
    // Nerd Font glyphs: F0580 (󰖀) renders as the volume waves, F057E (󰕾)
    // as the slashed (muted) speaker — this mapping was inverted before.
    text: AudioState.defaultSinkMuted ? "󰕾" : "󰖀"
    font.family: "JetBrainsMono Nerd Font Mono"
    font.pixelSize: 16
    color: hover.hovered || button.panelState.active
         ? (AudioState.defaultSinkMuted ? Theme.warning : Theme.accent)
         : Theme.textIdle
    Behavior on color { ColorAnimation { duration: 140 } }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.panelState.toggleAt(button.panelWindow.screen.name)
  }

  ToolTip.visible: hover.containsMouse && !button.panelState.active
  ToolTip.text: AudioState.defaultSinkMuted ? "Audio muted" : "Audio"
  ToolTip.delay: 500

  AudioPanel {
    id: panel
    panelWindow: button.panelWindow
    monitor: button.panelWindow.screen.name
    panelState: button.panelState
  }
}
