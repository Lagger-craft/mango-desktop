import QtQuick
import QtQuick.Controls
import Quickshell

// Calendar popup shown when the clock island is clicked. The parent
// (shell.qml) owns anchoring and visibility: it sets anchor.rect.x/y and
// visible imperatively. This component owns the month view state, the
// localized rendering, and the cross-day refresh fix (see currentDate).
PopupWindow {
  id: calendarPopup

  required property var panelWindow // PanelWindow this popup anchors to

  visible: false
  grabFocus: true // closes on any click outside (QuickShell contract)
  anchor.window: panelWindow
  implicitWidth: 320
  implicitHeight: calendarBody.implicitHeight + 20 // content-driven height
  color: "transparent"

  // Month currently displayed. QML calendar types use the JS Date
  // convention: months run 0-11.
  property int viewMonth: currentDate.getMonth()
  property int viewYear: currentDate.getFullYear()

  // "Today", tracked by hand instead of trusting MonthGrid's `today` model
  // role: that role is cached until the model repopulates, so a popup that
  // stays alive across midnight (or reopens the next day) would keep
  // highlighting yesterday. Comparing each cell's date against this
  // clock-driven value makes the highlight follow the real day. It is
  // re-checked on every SystemClock minute tick and every time the popup
  // becomes visible (the Clavis fix, S1).
  property date currentDate: clock.date

  readonly property int gridColumns: 7
  readonly property int gridSpacing: 2
  readonly property real cellWidth: (calendarBody.width - gridSpacing * (gridColumns - 1)) / gridColumns
  readonly property real cellHeight: 28

  function isSameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
  }

  // JS Date normalizes month overflow, so -1/1 handles December->January.
  function shiftMonth(delta) {
    const d = new Date(viewYear, viewMonth + delta, 1);
    viewYear = d.getFullYear();
    viewMonth = d.getMonth();
  }

  // Localized weekday headers, rotated to the locale's first day of week
  // (firstDayOfWeek and dayName share the JS convention: Sunday is 0).
  readonly property var weekdayHeaders: {
    const loc = Qt.locale();
    const headers = [];
    for (let i = 0; i < gridColumns; i++)
      headers.push(loc.dayName((loc.firstDayOfWeek + i) % 7, Locale.ShortFormat));
    return headers;
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: calendarPopup.currentDate = clock.date
  }

  // Re-check "today" and snap back to the current month when the popup is
  // shown, so a session that crossed midnight while hidden opens on the
  // real current date instead of a stale month.
  onVisibleChanged: {
    currentDate = clock.date;
    viewMonth = currentDate.getMonth();
    viewYear = currentDate.getFullYear();
  }

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: "#f0171a17"
    border.width: 1
    border.color: "#4a5a41"

    Column {
      id: calendarBody
      x: 10
      y: 10
      width: parent.width - 20
      spacing: 6

      // Navigation header: ‹ month year ›
      Item {
        width: calendarBody.width
        height: 24

        Text {
          id: prevMonthLabel
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "‹"
          color: prevMonthMouse.containsMouse ? "#9bd45a" : "#c8d2c0"
          font.pixelSize: 18
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: prevMonthMouse
            anchors.fill: parent
            anchors.margins: -6 // enlarged hit box without visual change
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarPopup.shiftMonth(-1)
          }
        }

        Text {
          anchors.centerIn: parent
          text: Qt.locale().standaloneMonthName(calendarPopup.viewMonth)
                + " " + calendarPopup.viewYear
          color: "#e5e8dc"
          font.pixelSize: 12
          font.bold: true
          font.letterSpacing: 1
        }

        Text {
          id: nextMonthLabel
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "›"
          color: nextMonthMouse.containsMouse ? "#9bd45a" : "#c8d2c0"
          font.pixelSize: 18
          Behavior on color { ColorAnimation { duration: 120 } }

          MouseArea {
            id: nextMonthMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarPopup.shiftMonth(1)
          }
        }
      }

      // Localized weekday headers, starting at the locale's first day.
      Row {
        spacing: calendarPopup.gridSpacing

        Repeater {
          model: calendarPopup.weekdayHeaders

          Text {
            required property var modelData
            width: calendarPopup.cellWidth
            text: modelData.toUpperCase()
            color: "#5a6055"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.5
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      MonthGrid {
        id: monthGrid
        width: calendarBody.width
        month: calendarPopup.viewMonth
        year: calendarPopup.viewYear
        locale: Qt.locale()
        spacing: calendarPopup.gridSpacing

        delegate: Item {
          id: cell
          required property var model

          width: calendarPopup.cellWidth
          height: calendarPopup.cellHeight

          // Computed by hand from calendarPopup.currentDate -- never from
          // the cached `today` model role (see currentDate above).
          readonly property bool isToday: calendarPopup.isSameDay(model.date, calendarPopup.currentDate)
          readonly property bool isCurrentMonth: model.month === monthGrid.month

          HoverHandler { id: cellHover }

          Rectangle { // today: green chip, dark text on top
            visible: cell.isToday
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            color: "#9bd45a"
          }

          Rectangle { // hover feedback for the days without the chip
            visible: !cell.isToday && cellHover.hovered
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            color: "#2a3126"
          }

          Text {
            anchors.centerIn: parent
            text: cell.model.day
            color: cell.isToday ? "#171a17"
                 : cell.isCurrentMonth ? "#c8d2c0" : "#5a6055"
            font.pixelSize: 11
            font.bold: cell.isToday
          }
        }
      }
    }
  }
}
