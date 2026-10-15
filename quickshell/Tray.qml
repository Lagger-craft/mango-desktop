import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray

// Right-side system tray: icons, hover-preloaded themed context menu, and
// the separator that hides when the tray is empty.
Row {
  id: tray
  spacing: 5
  required property var panelWindow // PanelWindow the menu popup anchors to

  Repeater {
    model: SystemTray.items
    delegate: Item {
      id: trayItem
      required property var modelData
      width: 30
      height: 30

      // Right-click must not render before the D-Bus menu children
      // arrive; this pending flag bridges that async gap.
      property bool menuPending: false

      Timer {
        id: menuWait
        interval: 40
        repeat: true
        running: trayItem.menuPending
        onTriggered: {
          if (trayMenuOpener.children.values.length > 0) {
            trayMenu.visible = true;
            trayItem.menuPending = false;
          }
        }
      }

      Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: modelData.icon
        sourceSize.width: 18
        sourceSize.height: 18
        fillMode: Image.PreserveAspectFit
      }

      MouseArea {
        id: trayMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        // Pre-load the menu over D-Bus while the user hovers, so a
        // right-click usually finds the children already present.
        // Skip when a menu is already open, or hovering another icon
        // would swap the visible menu's content underneath it.
        onContainsMouseChanged: {
          if (containsMouse && modelData.hasMenu && !trayMenu.visible)
            trayMenuOpener.menu = modelData.menu;
        }

        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            if (modelData.hasMenu) {
              const point = panelWindow.mapFromItem(trayMouse, mouse.x, mouse.y);
              trayMenu.anchor.rect.x = Math.max(8, Math.min(point.x - trayMenu.width / 2, panelWindow.width - trayMenu.width - 8));
              trayMenu.anchor.rect.y = panelWindow.implicitHeight;
              trayMenuOpener.menu = modelData.menu;
              if (trayMenuOpener.children.values.length > 0) {
                trayMenu.visible = true;
              } else {
                // Children still loading: wait for them so the popup
                // never renders as an empty themed rectangle.
                trayItem.menuPending = true;
              }
            }
          } else if (mouse.button === Qt.MiddleButton) {
            modelData.secondaryActivate();
          } else {
            modelData.activate();
          }
        }
      }

      ToolTip.visible: trayMouse.containsMouse && !trayMenu.visible && !!modelData.tooltip
      ToolTip.text: modelData.tooltip || ""
      ToolTip.delay: 500
    }
  }

  // Themed tray context menu. The native display() menu renders as
  // a PlatformMenuEntry through the system Qt theme and cannot be
  // styled from QML, so the item's QsMenuHandle is rendered here
  // with the bar's Chernobyl palette instead.
  QsMenuOpener { id: trayMenuOpener }

  PopupWindow {
    id: trayMenu
    visible: false
    grabFocus: true
    anchor.window: panelWindow
    implicitWidth: 240
    implicitHeight: menuColumn.implicitHeight + 12
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: "#f0171a17"
      border.width: 1
      border.color: "#3d5233"

      Column {
        id: menuColumn
        x: 6
        y: 6
        spacing: 1

        Repeater {
          model: trayMenuOpener.children

          delegate: Item {
            id: entry
            required property var modelData
            width: 228
            height: modelData.isSeparator ? 9 : 30

            MouseArea {
              id: entryMouse
              anchors.fill: parent
              visible: !entry.modelData.isSeparator
              enabled: entry.modelData.enabled
              hoverEnabled: true
              cursorShape: entry.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                entry.modelData.triggered();
                trayMenu.visible = false;
              }
            }

            // Separator rule
            Rectangle {
              visible: entry.modelData.isSeparator
              anchors.centerIn: parent
              width: parent.width - 12
              height: 1
              color: "#485044"
            }

            // Hover highlight behind the row content
            Rectangle {
              visible: !entry.modelData.isSeparator
              anchors.fill: parent
              radius: 5
              color: entryMouse.containsMouse && entry.modelData.enabled ? "#2a3126" : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
            }

            Row {
              visible: !entry.modelData.isSeparator
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              // Check / radio mark
              Text {
                visible: entry.modelData.buttonType !== QsMenuButtonType.None
                width: visible ? 14 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓"
                color: entry.modelData.checkState === Qt.Checked ? "#9bd45a" : "#5a6055"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
              }

              // Item label
              Text {
                width: parent.width - parent.spacing - (entry.modelData.buttonType !== QsMenuButtonType.None ? 22 : 0)
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.text
                color: !entry.modelData.enabled ? "#5a6055"
                     : entryMouse.containsMouse ? "#e5e8dc" : "#a5a99d"
                font.pixelSize: 12
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
              }

              // Submenu arrow (rendered, not yet expandable)
              Text {
                visible: entry.modelData.hasChildren
                width: visible ? 12 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: "#5a6055"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }
    }
  }

  Rectangle {
    width: 1
    height: 20
    color: "#485044"
    anchors.verticalCenter: parent.verticalCenter
    visible: SystemTray.items.count > 0
  }
}
