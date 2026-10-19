pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shell-wide palette. Defaults reproduce today's exact Chernobyl palette, so
// with no generated theme file the shell looks unchanged (S3). The theme file
// (~/.local/state/mango/theme.json) is written by wallpaper-ctl.sh from the
// matugen palette of the applied wallpaper and watched live: colors update
// without a shell restart. Only raw hex tokens live here — every view reads
// these properties instead of hardcoded colors.
QtObject {
  id: theme

  // Accents
  property color accent: "#9bd45a"        // strokes, active bits, titles
  property color accentBright: "#c8f08d"  // selected / highlighted text
  property color accentDim: "#3d5233"     // idle borders, dim outlines
  property color accentBorder: "#599bd45a" // translucent island borders
  property color selectedBg: "#34432b"    // selected row fill
  // Surfaces
  property color panelBg: "#b3171a17"     // bar islands (translucent)
  property color popoverBg: "#cc171a17"   // tray/toast-style popovers
  property color popupBg: "#f0171a17"     // opaque popups (bell, menus)
  property color overlayBg: "#99141714"   // full-screen dim overlays (frosted by mango blur)
  property color surface: "#171a17"       // solid card background
  property color surfaceUp: "#1b1f1a"     // dashboard panel
  property color panel: "#222722"         // picker panels
  property color panelTint: "#282d26"     // grooves/wells
  property color well: "#20241f"          // input/open wells
  property color deep: "#12150f"          // deep wells
  property color deeper: "#0c0e0c"        // deepest wells (skull teeth)
  property color hover: "#2a3126"         // hover fill
  property color buttonBg: "#20231e"      // action buttons
  property color buttonHoverBg: "#402d29" // hovered destructive header
  // Lines
  property color outline: "#4a5a41"
  property color divider: "#485044"
  // Text
  property color textPrimary: "#e5e8dc"
  property color textSecondary: "#a5a99d"
  property color textIdle: "#c8d2c0"
  property color textDim: "#5a6055"
  // States
  property color warning: "#e0a044"       // badges, muted states
  property color critical: "#d94b43"      // critical urgency
  property color criticalSoft: "#ec8064"  // destructive hover glyph

  // Apply a generated theme map {token: "#hex"}; unknown keys and missing
  // values are ignored so a stale or foreign file can only recolor, never
  // break the shell.
  function applyColors(map) {
    for (const k in map) {
      const v = map[k];
      if (typeof v === "string" && /^#[0-9a-fA-F]{6,8}$/.test(v) && theme[k] !== undefined)
        theme[k] = v;
    }
  }

  // Last applied raw JSON: reparsing identical content is skipped so the
  // poll below only recolors on a real change.
  property string lastJson: ""

  property FileView source: FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
          + "/mango/theme.json"
    watchChanges: true
    printErrors: false
    onFileChanged: this.reload()
    onTextChanged: {
      if (this.text() === theme.lastJson)
        return;
      theme.lastJson = this.text();
      try {
        theme.applyColors(JSON.parse(this.text()));
      } catch (e) {
        // Malformed theme: keep the previous palette; the next apply repairs.
      }
    }
  }

  // A theme file created after shell start is not picked up by watchChanges
  // (nothing to watch yet), so poll lightly and let the text guard dedupe.
  property Timer poll: Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: theme.source.reload()
  }
}
