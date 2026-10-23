import QtQuick
import QtQuick.Controls
import Quickshell

// The wallpaper picker overlay: a dimmed full-screen backdrop with a centered
// Control Room card. The monitor row picks the apply target, the LOCALES /
// WALLPAPER ENGINE tabs switch source, and the grid previews each background.
// All state and process wiring live in the shell's `picker` Scope — this file
// is only the view.
Item {
  id: picker
  property var pickerState
  focus: true

  readonly property color surface: Theme.surface
  readonly property color accent: Theme.accent
  readonly property color accentDim: Theme.accentDim
  readonly property color textPrimary: Theme.textPrimary
  readonly property color textMuted: Theme.textSecondary
  readonly property color panel: Theme.panel
  readonly property color edge: Theme.outline
  readonly property color selected: Theme.selectedBg
  readonly property string mono: "monospace"

  readonly property var currentModel: pickerState.activeTab === "we"
    ? pickerState.weModel : pickerState.localModel

  function previewOf(item) {
    if (pickerState.activeTab === "we")
      return item.preview ? "file://" + item.preview : "";
    return "file://" + item.ref;
  }
  function titleOf(item) {
    return pickerState.activeTab === "we"
      ? (item.title || item.ref)
      : (item.name || item.ref.split("/").pop());
  }

  Keys.onEscapePressed: pickerState.close()

  // Enter: fade + rise; exit: fade while the host window stays mapped
  // (pickerState.closing, see shell.qml). Backdrop and card animate together
  // as one root-level animation.
  opacity: 1
  transform: Translate { id: pickerShift; y: 0 }
  Connections {
    target: pickerState
    function onActiveChanged() {
      if (pickerState.active)
        pickerEnter.restart();
    }
    function onClosingChanged() {
      if (pickerState.closing)
        pickerExit.restart();
      else
        picker.opacity = 1; // reset before the next enter
    }
  }
  ParallelAnimation {
    id: pickerEnter
    NumberAnimation { target: picker; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { target: pickerShift; property: "y"; from: 14; to: 0; duration: 200; easing.type: Easing.OutCubic }
  }
  SequentialAnimation {
    id: pickerExit
    NumberAnimation { target: picker; property: "opacity"; from: 1; to: 0; duration: 180; easing.type: Easing.InCubic }
  }

  // Dim backdrop; click anywhere to dismiss.
  Rectangle {
    anchors.fill: parent
    color: Theme.overlayBg
    MouseArea {
      anchors.fill: parent
      onClicked: pickerState.close()
    }
  }

  // ---- card ------------------------------------------------------------
  Rectangle {
    anchors.centerIn: parent
    width: Math.max(360, parent.width - 80)
    height: Math.max(280, parent.height - 80)
    color: picker.surface
    border.color: picker.accent
    border.width: 2
    radius: 6

    // Subtle green top edge, matching the bar.
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 2
      radius: 6
      color: picker.accent
    }

    Column {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // Header: title on the left, close on the right.
      Item {
        width: parent.width
        height: 26
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "☢  WALLPAPER // CONTROL ROOM"
          color: picker.accent
          font.family: picker.mono
          font.bold: true
          font.pixelSize: 15
        }
        Rectangle {
          id: closeRect
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: closeLabel.implicitWidth + 20
          height: 24
          radius: 4
          color: closeMouse.containsMouse ? Theme.buttonHoverBg : picker.panel
          border.color: picker.edge
          Text {
            id: closeLabel
            anchors.centerIn: parent
            text: "✕ CLOSE"
            color: closeMouse.containsMouse ? Theme.criticalSoft : picker.textMuted
            font.family: picker.mono
            font.pixelSize: 11
          }
          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pickerState.close()
          }
        }
      }

      // Monitor selector: choose which output receives the wallpaper.
      Row {
        spacing: 6
        Text {
          text: "TARGET"
          color: picker.textMuted
          font.family: picker.mono
          font.pixelSize: 11
          anchors.verticalCenter: parent.verticalCenter
        }
        Repeater {
          model: Quickshell.screens
          delegate: Rectangle {
            required property var modelData
            readonly property bool isSelected: pickerState.selectedMonitor === modelData.name
            width: monName.implicitWidth + 24
            height: 26
            radius: 4
            color: isSelected ? picker.selected : picker.panel
            border.color: isSelected ? picker.accent : picker.edge
            border.width: 1
            Text {
              id: monName
              anchors.centerIn: parent
              text: modelData.name
              color: isSelected ? Theme.accentBright : picker.textPrimary
              font.family: picker.mono
              font.pixelSize: 12
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: pickerState.selectedMonitor = modelData.name
            }
          }
        }
      }

      // Source tabs.
      Row {
        spacing: 6
        Repeater {
          model: [
            { key: "local", label: "LOCALES" },
            { key: "we", label: "WALLPAPER ENGINE" }
          ]
          delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: pickerState.activeTab === modelData.key
            width: tabLabel.implicitWidth + 28
            height: 28
            radius: 4
            color: isActive ? picker.accentDim : picker.panel
            border.color: isActive ? picker.accent : picker.edge
            border.width: 1
            Text {
              id: tabLabel
              anchors.centerIn: parent
              text: modelData.label
              color: isActive ? Theme.accentBright : picker.textMuted
              font.family: picker.mono
              font.bold: isActive
              font.pixelSize: 12
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: pickerState.activeTab = modelData.key
            }
          }
        }
        Item { width: 1; height: 1 }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          color: picker.textMuted
          font.family: picker.mono
          font.pixelSize: 11
          text: picker.currentModel.length + " available"
        }
      }

      // Preview grid.
      Rectangle {
        width: parent.width
        height: parent.height - y - 20
        color: Theme.deep
        border.color: picker.edge
        border.width: 1
        radius: 4

        GridView {
          id: grid
          anchors.fill: parent
          anchors.margins: 6
          clip: true
          model: picker.currentModel
          cellWidth: 176
          cellHeight: 132
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { }

          delegate: Item {
            id: cell
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
              anchors.fill: parent
              anchors.margins: 4
              color: Theme.well
              radius: 4
              border.color: cellMouse.containsMouse ? picker.accent : picker.edge
              border.width: 1

              Image {
                anchors.fill: parent
                anchors.bottomMargin: 20
                source: picker.previewOf(cell.modelData)
                // Decode at 2× the 176px cell instead of the wallpaper's
                // full resolution: a 4K preview costs ~0.4 MB instead of
                // 11-42 MB of decoded pixels that stay resident forever.
                sourceSize.width: 352
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
              }

              // Title strip over the bottom of the preview.
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 20
                color: Theme.popoverBg
                Text {
                  anchors.fill: parent
                  anchors.leftMargin: 6
                  anchors.rightMargin: 6
                  anchors.verticalCenter: parent.verticalCenter
                  text: picker.titleOf(cell.modelData)
                  color: picker.textPrimary
                  font.family: picker.mono
                  font.pixelSize: 10
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: cellMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: pickerState.apply(pickerState.activeTab, cell.modelData.ref)
            }
          }
        }

        // Empty state for a source with nothing in it.
        Text {
          anchors.centerIn: parent
          visible: picker.currentModel.length === 0
          color: picker.textMuted
          font.family: picker.mono
          font.pixelSize: 13
          text: pickerState.activeTab === "we"
            ? "No Workshop backgrounds found in Steam."
            : "No images in ~/Pictures/Wallpapers."
        }
      }
    }

    // Footer hint.
    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 6
      horizontalAlignment: Text.AlignHCenter
      color: picker.textMuted
      font.family: picker.mono
      font.pixelSize: 10
      text: "click a preview to apply → " + pickerState.selectedMonitor
          + "   ·   ESC or backdrop to close"
    }
  }
}
