import QtQuick
import QtQuick.Controls

// One workspace tag rendered as a 16x16 pixel skull with a hard dark outline,
// no anti-aliasing: angular cranium, tall hollow sockets and a narrow jaw, in
// the spirit of State of Decay's HUD art. '#' marks bone. Click dispatches
// tagClicked(index); the parent decides what to run.
Item {
  id: skullTag
  required property var modelData
  signal tagClicked(int tagIndex)

  // 16x16 pixel skull with a hard dark outline, no anti-aliasing: angular
  // cranium, tall hollow sockets and a narrow jaw, in the spirit of State
  // of Decay's HUD art. '#' marks bone.
  readonly property var skullRows: [
    ".....######.....",
    "....########....",
    "...##########...",
    "..############..",
    "..############..",
    ".##############.",
    ".##############.",
    ".###.######.###.",
    ".###.######.###.",
    ".###.######.###.",
    "..##.######.##..",
    "..############..",
    "...####..####...",
    "...##.####.##...",
    "...##########...",
    "....##.##.##....",
  ]
  readonly property int skullSize: 16
  readonly property int skullPixel: 1

  // Cells around the bone that stay empty but sit next to it. They get
  // painted first as a hard outline, which is what gives the skull its
  // game-HUD weight instead of a flat stencil.
  readonly property var skullOutline: {
    const bone = new Set();
    for (let r = 0; r < skullTag.skullSize; r++)
      for (let c = 0; c < skullTag.skullSize; c++)
        if (skullTag.skullRows[r].charAt(c) === "#")
          bone.add(r * skullTag.skullSize + c);

    const edge = [];
    for (const cell of bone) {
      const r = Math.floor(cell / skullTag.skullSize);
      const c = cell - r * skullTag.skullSize;
      for (let dr = -1; dr <= 1; dr++)
        for (let dc = -1; dc <= 1; dc++) {
          const rr = r + dr, cc = c + dc;
          if (rr < 0 || rr >= skullTag.skullSize || cc < 0 || cc >= skullTag.skullSize)
            continue;
          const neighbour = rr * skullTag.skullSize + cc;
          if (!bone.has(neighbour) && !edge.includes(neighbour))
            edge.push(neighbour);
        }
    }
    return edge;
  }

  width: skullTag.skullPixel * skullTag.skullSize
  height: skullTag.skullPixel * skullTag.skullSize

  // Radioactive green for the visible tag, warning amber for
  // an urgent one, bone when it holds windows, moss when empty.
  readonly property color tint: modelData.is_active ? Theme.accent
                               : modelData.is_urgent ? Theme.warning
                               : modelData.client_count > 0 ? Theme.accentBright
                               : Theme.accentDim

  // Subtle pad behind the active skull only.
  Rectangle {
    anchors.fill: parent
    anchors.margins: -2
    radius: 5
    color: skullTag.modelData.is_active ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  // Hard outline painted under the bone.
  Repeater {
    model: skullTag.skullOutline

    Rectangle {
      required property int modelData
      x: (modelData % skullTag.skullSize) * skullTag.skullPixel
      y: Math.floor(modelData / skullTag.skullSize) * skullTag.skullPixel
      width: skullTag.skullPixel
      height: skullTag.skullPixel
      color: Theme.deeper
    }
  }

  Repeater {
    model: skullTag.skullSize * skullTag.skullSize

    Rectangle {
      required property int index
      readonly property int row: Math.floor(index / skullTag.skullSize)
      readonly property int col: index - row * skullTag.skullSize
      visible: skullTag.skullRows[row].charAt(col) === "#"
      x: col * skullTag.skullPixel
      y: row * skullTag.skullPixel
      width: skullTag.skullPixel
      height: skullTag.skullPixel
      color: skullTag.tint
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  MouseArea {
    id: skullMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: skullTag.tagClicked(skullTag.modelData.index)
  }

  ToolTip.visible: skullMouse.containsMouse
  ToolTip.text: "Tag " + skullTag.modelData.index
              + " · " + skullTag.modelData.client_count
              + (skullTag.modelData.client_count === 1 ? " window" : " windows")
  ToolTip.delay: 400
}
