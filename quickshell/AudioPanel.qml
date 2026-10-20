import QtQuick
import QtQuick.Controls
import Quickshell

// Audio panel: one popup with the outputs, the inputs and the apps that are
// currently playing. It reads its state from the AudioState singleton and
// writes through the same PulseAudio interface, so a change made here is
// immediately visible to every other client (and the other way round).
//
// The panel is anchored under the bar of the screen it belongs to; it is only
// visible on the target screen, so the other screens' copies stay hidden.
PopupWindow {
  id: panel
  required property var panelWindow
  required property string monitor
  required property var panelState // shared Scope: open/closed + target screen

  visible: false
  grabFocus: true // dismisses on any click outside (QuickShell contract)
  anchor.window: panelWindow
  // Right-aligned under the bar. Set as a binding, like the volume OSD: an
  // imperative assignment in onVisibleChanged lands after the surface has
  // already tried to map, and the popup never shows up.
  anchor.rect.x: Math.max(8, panelWindow.width - implicitWidth - 8)
  anchor.rect.y: panelWindow.implicitHeight
  implicitWidth: 380
  implicitHeight: Math.min(body.implicitHeight + 16, 560)
  color: "transparent"

  // The visibility is applied imperatively instead of as a binding: when the
  // grab dismisses the popup, QuickShell writes `visible` on the window
  // itself, and that write can drop a binding on the same property, which
  // would leave the panel unable to open again.
  function syncVisibility() {
    visible = panelState.active && monitor === panelState.requestedMonitor;
  }

  onMonitorChanged: syncVisibility()

  Connections {
    target: panelState
    function onActiveChanged() { panel.syncVisibility(); }
    function onRequestedMonitorChanged() { panel.syncVisibility(); }
  }

  // The panel belongs to the screen it was opened from.
  readonly property bool onTargetScreen:
    panelState.active && monitor === panelState.requestedMonitor

  // Opening the panel pulls fresh state; closing it drops the fast poll.
  onVisibleChanged: {
    AudioState.setPanelOpen(visible);
    if (visible) {
      AudioState.refresh();
      return;
    }
    // Dismissed by a click outside (the grab closes the popup on its own).
    // The shared state has to follow, or the next toggle would close the
    // panel instead of opening it. A panel that is hidden because the
    // target screen changed keeps the shared state untouched.
    if (panelState.active && monitor === panelState.requestedMonitor)
      panelState.active = false;
  }

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: Theme.popupBg
    border.width: 1
    border.color: Theme.outline

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: 8
      contentWidth: width
      contentHeight: body.implicitHeight
      clip: true

      Column {
        id: body
        width: flick.width
        spacing: 4

        // Header: title and the live output level of the default sink.
        Item {
          width: body.width
          height: 18

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "☢  AUDIO"
            color: Theme.accent
            font.bold: true
            font.pixelSize: 11
            font.letterSpacing: 1
          }

          // Output meter: the native PipeWire peak of the default sink.
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            height: 5
            radius: 2.5
            color: Theme.panelTint

            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, AudioState.outputPeak))
              height: parent.height
              radius: 2.5
              color: Theme.accent
              Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
          }
        }

        Item { width: body.width; height: 4 }

        // ---- outputs ----
        SectionLabel {
          width: body.width
          text: "OUTPUT"
        }

        Repeater {
          model: AudioState.sinkModel

          delegate: DeviceRow {
            width: body.width
            kind: "sink"
          }
        }

        EmptyNote {
          width: body.width
          visible: AudioState.sinkModel.count === 0
          text: "No outputs found"
        }

        Item { width: body.width; height: 6 }

        // ---- inputs ----
        SectionLabel {
          width: body.width
          text: "INPUT"
        }

        Repeater {
          model: AudioState.sourceModel

          delegate: DeviceRow {
            width: body.width
            kind: "source"
          }
        }

        EmptyNote {
          width: body.width
          visible: AudioState.sourceModel.count === 0
          text: "No inputs found"
        }

        Item { width: body.width; height: 6 }

        // ---- applications ----
        SectionLabel {
          width: body.width
          text: "APPLICATIONS"
        }

        Repeater {
          model: AudioState.streamModel

          delegate: DeviceRow {
            width: body.width
            kind: "stream"
          }
        }

        EmptyNote {
          width: body.width
          visible: AudioState.streamModel.count === 0
          text: "Nothing is playing"
        }
      }
    }
  }

  // ---- components ----

  component SectionLabel: Text {
    height: implicitHeight
    font.pixelSize: 10
    font.bold: true
    font.letterSpacing: 1
    color: Theme.textDim
  }

  component EmptyNote: Text {
    height: implicitHeight
    font.pixelSize: 10
    color: Theme.textDim
    font.italic: true
  }

  // One device or application: name, volume bar, mute button, and an
  // optional chip showing which output it plays through. The row is bound to
  // one model row (`modelData`); the kind decides what the actions do, so
  // the same component serves outputs, inputs and applications.
  component DeviceRow: Item {
    id: row
    required property var modelData
    property string kind: "sink" // sink | source | stream
    property bool showDefault: true
    property string muteGlyph: "󰖀"
    property string unmuteGlyph: "󰕾"

    readonly property bool isDefault:
      kind === "sink" ? modelData.name === AudioState.defaultSink
      : kind === "source" ? modelData.name === AudioState.defaultSource
      : false

    readonly property string title:
      kind === "stream" ? (modelData.app || "Application")
      : (modelData.description || modelData.name)

    readonly property string chipText:
      kind === "stream" ? AudioState.sinkName(modelData.sinkIndex) : ""

    // Only PulseAudio clients can be rerouted; a native PipeWire client
    // picks its own output, so moving it is a no-op.
    readonly property bool chipClickable:
      kind === "stream" && modelData.movable === true

    readonly property string chipTooltip:
      chipClickable ? "Move to another output" : "This app picks its own output"

    implicitHeight: 40
    height: 40

    function commitVolume(volume) {
      if (kind === "sink")
        AudioState.setSinkVolume(modelData.index, volume);
      else if (kind === "source")
        AudioState.setSourceVolume(modelData.index, volume);
      else
        AudioState.setStreamVolume(modelData.index, volume);
    }

    function toggleMute() {
      if (kind === "sink")
        AudioState.setSinkMute(modelData.index, !modelData.muted);
      else if (kind === "source")
        AudioState.setSourceMute(modelData.index, !modelData.muted);
      else
        AudioState.setStreamMute(modelData.index, !modelData.muted);
    }

    function pickDefault() {
      if (kind === "sink")
        AudioState.setDefaultSink(modelData.name);
      else if (kind === "source")
        AudioState.setDefaultSource(modelData.name);
    }

    function moveOutput() {
      const next = AudioState.moveStreamToNext(modelData.index, modelData.sinkIndex);
      if (next >= 0)
        AudioState.refresh();
    }

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 4

      Item {
        width: parent.width
        height: 15

        // Default-output marker: a filled dot for the active one.
        Rectangle {
          id: dot
          visible: row.showDefault
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 9
          height: 9
          radius: 4.5
          color: row.isDefault ? Theme.accent : "transparent"
          border.width: 1
          border.color: row.isDefault ? Theme.accent : Theme.divider

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: row.pickDefault()
          }
        }

        Text {
          anchors.left: row.showDefault ? dot.right : parent.left
          anchors.leftMargin: row.showDefault ? 7 : 0
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - (row.showDefault ? 16 : 0) - (row.chipText ? 130 : 0)
          elide: Text.ElideRight
          text: row.title
          color: row.isDefault ? Theme.accentBright : Theme.textPrimary
          font.pixelSize: 12
          font.bold: row.isDefault
        }

        // Output chip for application rows: which sink it plays through.
        Rectangle {
          visible: row.chipText.length > 0
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 124
          height: 15
          radius: 3
          color: Theme.buttonBg
          border.width: 1
          border.color: row.chipClickable ? Theme.divider : Theme.panelTint

          Text {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: row.chipText
            color: row.chipClickable ? Theme.textSecondary : Theme.textDim
            font.pixelSize: 9
          }

          MouseArea {
            anchors.fill: parent
            enabled: row.chipClickable
            cursorShape: Qt.PointingHandCursor
            onClicked: row.moveOutput()
          }
          ToolTip.visible: chipMouse.containsMouse && row.chipTooltip.length > 0
          ToolTip.text: row.chipTooltip
          ToolTip.delay: 400
          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
        }
      }

      Item {
        width: parent.width
        height: 16

        VolumeBar {
          id: bar
          anchors.left: parent.left
          anchors.right: muteGlyph.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          height: 16
          value: row.modelData.volume
          muted: row.modelData.muted
          onCommitted: v => row.commitVolume(v)
        }

        Text {
          id: muteGlyph
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.muted ? row.muteGlyph : row.unmuteGlyph
          color: row.modelData.muted ? Theme.warning : Theme.textIdle
          font.family: "JetBrainsMono Nerd Font Mono"
          font.pixelSize: 14

          MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggleMute()
          }
          ToolTip.visible: muteMouse.containsMouse
          ToolTip.text: row.modelData.muted ? "Unmute" : "Mute"
          ToolTip.delay: 400
          MouseArea {
            id: muteMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
          }
        }
      }
    }
  }

  // Volume bar: a plain track plus a draggable fill. It is drawn by hand
  // instead of using a Slider so the drag never fights a live data binding.
  component VolumeBar: Item {
    id: bar
    required property real value
    required property bool muted
    signal committed(real volume)

    property real current: value
    property bool dragging: false

    onValueChanged: {
      if (!dragging)
        current = value;
    }

    function setFromX(x) {
      if (bar.width <= 0)
        return;
      bar.current = Math.max(0, Math.min(1, x / bar.width));
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: Theme.panelTint

      Rectangle {
        width: parent.width * (bar.muted ? 0 : bar.current)
        height: parent.height
        radius: 3
        color: bar.muted ? Theme.warning : Theme.accent
        Behavior on width {
          enabled: !bar.dragging
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: {
        bar.dragging = true;
        bar.setFromX(mouse.x);
      }
      onPositionChanged: {
        if (bar.dragging)
          bar.setFromX(mouse.x);
      }
      onReleased: {
        bar.dragging = false;
        bar.committed(bar.current);
      }
    }
  }
}
