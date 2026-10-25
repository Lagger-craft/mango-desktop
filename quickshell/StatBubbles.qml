import QtQuick
import Quickshell

// CPU / RAM / GPU bubbles for the bar's right island (S1, S2): one pill per
// metric, icon + value, separated from the tray/power controls by a divider
// drawn in shell.qml. Values come from the shared SysStats singleton, so the
// panel and the dashboard system card always agree (S5).
//
// The root fills the island's 30 px band like every other action-row child
// (Tray/AudioButton/PowerButton are all 30 tall) and centers the pills in it:
// a plain Row child would top-align with the 22 px pills and ride over the
// island's top accent line.
Item {
  id: bubbles
  height: 30
  width: bubbleRow.implicitWidth

  readonly property string mono: "JetBrainsMono Nerd Font Mono"

  component Bubble: Rectangle {
    id: bubble
    required property string glyph
    required property string value

    height: 22
    width: contentRow.implicitWidth + 14
    radius: 8
    color: Theme.surfaceUp
    border.width: 1
    border.color: Theme.accentBorder

    Row {
      id: contentRow
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

  Row {
    id: bubbleRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

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
}
