import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DeskModel.js" as DeskModel
import "PreferencesModel.js" as Model

// The desk of the Look and Behavior pages (docs/behavior/preferences.md
// PREFS-124 on): one of the Layout page's plates (LayerPlate: its tilt,
// turning about its top edge, flat with animations off) at the layers' top
// line, as wide as theirs and centred the same way, with no label or count
// column; its strips (DeskStrip, the page's children) share its width
// equally, 12 px apart, all as tall as the tallest. The Layout page's camera
// hangs over it with the Layout page's own arguments; each strip draws the
// cap's shade over the part of its surface under the camera. The key legend is at
// the bottom left (PREFS-103).
//
// The cursor walks the strips' controls (DeskModel.js; PREFS-126): j/k move
// the cursor, h/l move a value. j/k go down and up a strip and on, h/l to
// the next or previous chip on a row of chips, else to the same row of the
// next or previous strip; Tab and Shift+Tab to the next or previous strip's
// first control. A fader takes h/l for its value first. A control on a desk
// says how many stops it has (deskStops), which one a jump to it lands on
// (deskHome), which one it is on (deskStop, if more than one) and how to
// take the cursor (deskFocus(stop, reason)).
Item {
  id: desk
  required property var preferences
  // The Layout page's editor: its geometry and camera.
  required property var layout
  readonly property var bar: preferences.bar
  // The page's own legend lines (PREFS-131).
  property var pageLines: []
  default property alias strips: plateFace.data
  // Items on the page beside the desk, not on its plate and not in its walk
  // (the Look page's temporary camera pane, PREFS-132).
  property alias overlays: overlayLayer.data
  // The keys are a legend on the page (PREFS-103), so the footer hides; the
  // strips draw the cursor, so Preferences' focus ring stays away.
  readonly property var hints: []
  readonly property bool ownsFocusRings: true

  // ------------------------------------------------------------ geometry
  readonly property bool animate: !bar || bar.animationsEnabled
  readonly property bool lightTheme: layout.lightTheme
  readonly property real tilt: layout.tilt
  readonly property real planeDistance: layout.planeDistance
  readonly property real stripGap: Style.space(12)
  readonly property var stripList: {
    var out = [];
    var kids = plateFace.children;
    for (var i = 0; i < kids.length; i++)
      if (kids[i].isDeskStrip && kids[i].visible)
        out.push(kids[i]);
    return out;
  }
  // The plate is the layers' width, but a tall plate tilted back is seen
  // wider at its near edge: it narrows until that edge stays on the page.
  // The height it fits is measured after the strips settle, and only grows
  // until the strips or the page change, so the width cannot seesaw.
  property real fitHeight: 0
  function fit() {
    if (stripHeight > fitHeight)
      fitHeight = stripHeight;
  }
  function refit() {
    fitHeight = 0;
    Qt.callLater(fit);
  }
  onStripHeightChanged: Qt.callLater(fit)
  onWidthChanged: refit()
  readonly property int stripCount: stripList.length
  onStripCountChanged: refit()
  readonly property real spread: Model.tiltedSpread(1, Model.tiltedHeight(fitHeight, tilt, planeDistance), tilt, planeDistance)
  readonly property real plateWidth: Math.max(0, Math.min(layout.plateWidth, 2 * Math.min(layout.axis, width - layout.axis) / Math.max(1, spread)))
  readonly property real plateX: Math.max(0, Math.min(width - plateWidth, layout.axis - plateWidth / 2))
  readonly property var boxes: DeskModel.stripBoxes(plateWidth, stripList.length, stripGap)
  readonly property real stripHeight: {
    var h = 0;
    stripList.forEach(function (s) {
      h = Math.max(h, s.naturalHeight);
    });
    return Math.ceil(h);
  }
  function boxOf(strip) {
    var i = stripList.indexOf(strip);
    return i >= 0 && boxes[i] ? boxes[i] : null;
  }
  Component.onCompleted: {
    var kids = plateFace.children;
    for (var i = 0; i < kids.length; i++)
      if (kids[i].isDeskStrip)
        kids[i].desk = desk;
  }

  // ---------------------------------------------------------- the camera
  // The Layout page's, with every argument its own (PREFS-109's rule), so
  // switching pages changes nothing of its cap or shade.
  readonly property Item layoutCamera: layout.beamCamera
  readonly property bool cameraShown: layout.previewCamera && !!layout.previewNotch
  CameraShaft {
    id: shaft
    visible: desk.cameraShown
    z: -1
    axis: desk.layoutCamera.axis
    half: desk.layoutCamera.half
    line: desk.layoutCamera.line
    pageTop: desk.layoutCamera.pageTop
    beamBottom: desk.layoutCamera.beamBottom
    tilt: desk.layoutCamera.tilt
    planeDistance: desk.layoutCamera.planeDistance
    lightTheme: desk.layoutCamera.lightTheme
  }
  readonly property Item camera: shaft
  // The camera's column in the plate, and where the plate's top is seen.
  readonly property real beamLeft: shaft.axis - shaft.half - plate.x
  readonly property real beamWidth: 2 * shaft.half
  readonly property real seenTop: plate.y
  // Where the plate's near edge is seen, its slab edge under it.
  readonly property real seenBottom: plate.y + Model.tiltedHeight(stripHeight, tilt, planeDistance) + Style.space(6)
  readonly property real seenRight: layout.axis + Model.tiltedSpread(plateX + plateWidth - layout.axis, Model.tiltedHeight(stripHeight, tilt, planeDistance), tilt, planeDistance)
  readonly property real line: shaft.line

  // ------------------------------------------------------------ the plate
  Item {
    id: plate
    x: desk.plateX
    y: desk.layout.stackTop
    width: desk.plateWidth
    height: desk.stripHeight
    z: 2
    LayerPlate {
      id: plateFace
      width: plate.width
      height: plate.height
      axisX: desk.layout.axis - plate.x
      tilt: desk.tilt
      planeDistance: desk.planeDistance
      animate: desk.animate
    }
  }

  Item {
    id: overlayLayer
    anchors.fill: parent
    z: 3
  }

  // ------------------------------------------------------------- the walk
  readonly property Item focusedItem: Window.activeFocusItem
  function within(item, ancestor) {
    for (var p = item; p; p = p.parent)
      if (p === ancestor)
        return true;
    return false;
  }
  // The control the cursor is in, and its place.
  readonly property Item focusedControl: {
    var f = focusedItem;
    if (!f)
      return null;
    for (var s = 0; s < stripList.length; s++) {
      var list = stripList[s].controls;
      for (var c = 0; c < list.length; c++)
        if (within(f, list[c]))
          return list[c];
    }
    return null;
  }
  function model() {
    return stripList.map(function (s) {
      return s.controls.map(function (c) {
        return {
          stops: c.deskStops,
          home: c.deskHome
        };
      });
    });
  }
  function locate() {
    var f = focusedItem;
    for (var s = 0; s < stripList.length; s++) {
      var list = stripList[s].controls;
      for (var c = 0; c < list.length; c++)
        if (within(f, list[c]))
          return {
            strip: s,
            control: c,
            stop: list[c].deskStop !== undefined ? list[c].deskStop : 0
          };
    }
    return null;
  }
  property var remembered: null
  onFocusedControlChanged: if (focusedControl)
    remembered = locate()
  function go(place, reason) {
    if (!place || !stripList[place.strip])
      return;
    var control = stripList[place.strip].controls[place.control];
    if (control)
      control.deskFocus(place.stop, reason === undefined ? Qt.OtherFocusReason : reason);
  }
  function focusFirst() {
    var m = model();
    go(remembered ? DeskModel.valid(m, remembered) : DeskModel.first(m), Qt.TabFocusReason);
  }
  Keys.onPressed: function (event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    var m = model(), at = locate();
    var t = event.text.toLowerCase();
    var back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      go(at ? DeskModel.tab(m, at, back ? -1 : 1) : DeskModel.first(m), Qt.TabFocusReason);
    else if (t === "h" || t === "l" || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      var dir = t === "h" || event.key === Qt.Key_Left ? -1 : 1;
      go(at ? DeskModel.sideways(m, at, dir) : DeskModel.first(m));
    } else if (t === "j" || t === "k" || event.key === Qt.Key_Down || event.key === Qt.Key_Up)
      go(at ? DeskModel.vertical(m, at, t === "k" || event.key === Qt.Key_Up ? -1 : 1) : DeskModel.first(m));
    else
      return;
    event.accepted = true;
  }

  // ------------------------------------------------------------ the legend
  readonly property var legend: DeskModel.legend(pageLines, focusedControl && focusedControl.keyHints ? focusedControl.keyHints : [])
  GridLayout {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(8)
    width: Math.min(desk.width, Style.space(640))
    z: 118
    columns: 2
    columnSpacing: Style.space(14)
    rowSpacing: Style.space(10)
    Repeater {
      model: desk.legend
      Row {
        id: keysRow
        required property var modelData
        required property int index
        Layout.row: index
        Layout.column: 0
        spacing: Style.space(4)
        Repeater {
          model: String(keysRow.modelData.keys).split(" ")
          KeyCap {
            required property string modelData
            text: modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          }
        }
      }
    }
    Repeater {
      model: desk.legend
      Text {
        required property var modelData
        required property int index
        Layout.row: index
        Layout.column: 1
        Layout.fillWidth: true
        text: modelData.label
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }
  }
}
