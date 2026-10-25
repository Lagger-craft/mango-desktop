import QtQuick
import Quickshell

// CPU / RAM / GPU bubbles for the bar's right island (S1, S2): one pill per
// metric, icon + value, separated from the tray/power controls by a divider
// drawn in shell.qml. Values come from the shared SysStats singleton, so the
// panel and the dashboard system card always agree (S5).
Row {
  id: bubbles
  spacing: 4

  readonly property string mono: "JetBrainsMono Nerd Font Mono"

  component Bubble: Rectangle {
    id: bubble
    required property string glyph
    required property string value

    height: 22
    width: bubbleRow.implicitWidth + 14
    radius: 8
    color: Theme.surfaceUp
    border.width: 1
    border.color: Theme.accentBorder

    Row {
      id: bubbleRow
      anchors.centerIn: parent
      spacing: 4

      // Nerd Fonts md glyphs (chip, memory, expansion_card); the default
      // "monospace" family has no patched icons, so the family is explicit.
      // Literal glyphs on purpose: a JS "\u" escape only takes 4 hex digits,
      // so "\uF035B" would render as U+F035 plus a stray "B".
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bubble.glyph
        font.family: bubbles.mono
        font.pixelSize: 11
        color: Theme.accent
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bubble.value
        font.family: bubbles.mono
        font.pixelSize: 10
        font.bold: true
        color: Theme.textPrimary
      }
    }
  }

  Bubble {
    glyph: "󰘚" // md-chip
    value: Math.round(SysStats.cpuPct) + "%"
  }

  Bubble {
    glyph: "󰍛" // md-memory
    value: SysStats.memUsedGiB.toFixed(1) + "/"
         + Math.round(SysStats.memTotalGiB) + "G"
  }

  Bubble {
    glyph: "󰢮" // md-expansion_card
    value: SysStats.gpuAvailable ? Math.round(SysStats.gpuPct) + "%" : "n/a"
  }
}
