import QtQuick

Text {
  id: clock
  color: "#e5e8dc"
  font.pixelSize: 13
  font.letterSpacing: 0.3

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, dd MMM  ·  HH:mm")
  }
}
