import QtQuick

// Visual only: hover and drag ownership stay with the enclosing widget.
//
// One width rule per mode, so marks of the same kind always agree:
//  - "icon": the stroke spans the visible ink of `contentItem` (or an explicit
//    `contentWidth`), never the padded slot around it. Slot padding, margins
//    and spacing differ between widgets; the painted glyph is what the eye
//    compares.
//  - "row": the stroke spans the mark less `horizontalInset` on each side.
//    Give every menu row a mark of the full row width and all rows match.
// The stroke always runs along the bottom edge and grows from the centre.
Item {
  id: mark
  property bool active: false
  property bool motionEnabled: true
  property color accent: "transparent"
  property string mode: "icon"
  // Item whose painted content the icon stroke measures.
  property Item contentItem: null
  // Explicit visible width; a negative value measures `contentItem` instead.
  property real contentWidth: -1
  // Used only when nothing measurable is painted (for example a rotated label).
  property real expandedFraction: 0.58
  property real horizontalInset: 4
  property real bottomInset: 2
  property real lineThickness: 2
  property real minimumWidth: lineThickness * 3
  property int motionDuration: 160

  readonly property Item textSource: labelSource(contentItem, 0)
  readonly property real measuredContentWidth: contentWidth >= 0 ? contentWidth : inkWidth(contentItem, 0)
  readonly property real expandedWidth: {
    var available = Math.max(0, width)
    if (mode === "row") return Math.max(0, available - horizontalInset * 2)
    if (measuredContentWidth > 0)
      return Math.min(available, Math.max(minimumWidth, measuredContentWidth))
    return Math.min(Math.max(0, available - horizontalInset * 2), available * expandedFraction)
  }
  readonly property real strokeWidth: stroke.width
  readonly property real strokeX: stroke.x

  function positive(item, key) {
    if (!item || !(key in item)) return 0
    var value = Number(item[key])
    return isFinite(value) && value > 0 ? value : 0
  }
  function rotatedLabel(item) {
    return "textRotation" in item && Math.abs(Number(item.textRotation) % 180) === 90
  }
  // Children that paint something: pointer areas and hidden or empty items
  // do not widen the mark.
  function paintedChildren(item) {
    var result = []
    var children = item.children || []
    for (var i = 0; i < children.length; i++) {
      var child = children[i]
      if (!child || child === mark || !child.visible || child.opacity <= 0 || child.width <= 0 || child.height <= 0) continue
      if ("acceptedButtons" in child) continue
      result.push(child)
    }
    return result
  }
  function measuredLeaf(item) {
    return "hoverUnderlineWidth" in item || "glyphPaintedWidth" in item || "labelWidth" in item
      || "paintedWidth" in item
  }
  // The single WidgetButton-style label the stroke measures, if any, so its
  // ink bounds can be taken from font metrics rather than its advance width.
  function labelSource(item, depth) {
    if (!item || depth > 4) return null
    if ("labelWidth" in item && "fontFamily" in item && "fontSize" in item && "text" in item)
      return rotatedLabel(item) ? null : item
    if (measuredLeaf(item)) return null
    var children = paintedChildren(item)
    return children.length === 1 ? labelSource(children[0], depth + 1) : null
  }
  function inkWidth(item, depth) {
    if (!item || depth > 4) return 0
    var hint = positive(item, "hoverUnderlineWidth")
    if (hint > 0) return hint
    if ("glyphPaintedWidth" in item) {
      var glyph = positive(item, "glyphPaintedWidth")
      return glyph > 0 ? glyph : positive(item, "opticalSize")
    }
    if ("labelWidth" in item) {
      if (rotatedLabel(item)) return 0
      if (item === textSource && inkMetrics.tightBoundingRect.width > 0)
        return Math.min(inkMetrics.tightBoundingRect.width, Math.max(1, item.width))
      var label = positive(item, "labelWidth")
      if (label > 0) return label
      // A hidden label means the button paints its own children instead,
      // such as the vertical clock's stack of lines.
    }
    if ("paintedWidth" in item) return positive(item, "paintedWidth")
    var children = paintedChildren(item)
    if (children.length === 1) {
      var inner = inkWidth(children[0], depth + 1)
      if (inner > 0) return inner
    }
    // The widget's own open-panel mark width, when its parts cannot be told
    // apart from here.
    hint = positive(item, "openPanelIndicatorWidth")
    if (hint > 0) return hint
    if (children.length > 1) {
      var left = Infinity
      var right = -Infinity
      for (var i = 0; i < children.length; i++) {
        left = Math.min(left, children[i].x)
        right = Math.max(right, children[i].x + children[i].width)
      }
      return Math.max(0, right - left)
    }
    return depth > 0 ? Math.max(0, item.width) : 0
  }

  TextMetrics {
    id: inkMetrics
    font.family: mark.textSource ? mark.textSource.fontFamily : ""
    font.pixelSize: mark.textSource ? Math.max(1, Math.round(mark.textSource.fontSize)) : 12
    text: mark.textSource && mark.textSource.labelWidth > 0 ? mark.textSource.text : ""
  }

  Rectangle {
    id: stroke
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - height - mark.bottomInset
    width: mark.active ? mark.expandedWidth : 0
    height: mark.lineThickness
    radius: height / 2
    color: mark.accent
    opacity: mark.active ? 1 : 0
    Behavior on width {
      enabled: mark.motionEnabled
      NumberAnimation { duration: mark.motionDuration; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
      enabled: mark.motionEnabled
      NumberAnimation { duration: Math.min(120, mark.motionDuration); easing.type: Easing.OutCubic }
    }
  }
}
