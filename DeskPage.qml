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
// the next or previous chip on a row of chips and past its ends, as on any
// other control, to the same row of the next or previous strip; Tab and
// Shift+Tab to the next or previous strip's first control. A fader takes
// h/l for its value first. A control on a desk
// says how many stops it has (deskStops), which one a jump to it lands on
// (deskHome), which one it is on (deskStop, if more than one) and how to
// take the cursor (deskFocus(stop, reason)).
Item {
  id: desk
  required property var preferences
  // The Layout page's editor: its geometry and camera.
  required property var layout
  readonly property var bar: preferences.bar
  // How far Preferences has slid the page off its place, as on the Layout
  // page: the plate moves in its plane under a camera that stays put.
  property real slide: 0
  // The page's own legend lines (PREFS-131).
  property var pageLines: []
  default property alias strips: plateFace.data
  // The keys are a legend on the page (PREFS-103), so the footer hides; the
  // strips draw the cursor, so Preferences' focus ring stays away.
  readonly property var hints: []
  readonly property bool ownsFocusRings: true

  // ------------------------------------------------------------ geometry
  readonly property bool animate: !bar || bar.animationsEnabled
  readonly property bool lightTheme: layout.lightTheme
  readonly property real tilt: layout.tilt
  readonly property real planeDistance: layout.planeDistance
  readonly property real stripGap: Gap.xl
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
    // While the page slides, Preferences draws the camera, still.
    opacity: desk.slide === 0 ? 1 : 0
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
  readonly property real beamLeft: shaft.axis - shaft.half - desk.slide - desk.plateX
  readonly property real beamWidth: 2 * shaft.half
  readonly property real seenTop: smoothing.y + plate.y
  readonly property real line: shaft.line

  // ------------------------------------------------------------ the plate
  // The tilted plate draws through one multisampled layer (4 samples): the
  // tilt turns every edge on it, the kit's controls' too, and only samples
  // taken after the turn smooth them all. The layer is the page's width (the
  // near edge is seen wider than the plate) and the seen plate's height with
  // room for its slab edges and, above, for the cursor's strip to rise
  // (ZoneTile, PREFS-104) without the layer cutting it; flat, there is no
  // layer. While the page slides the plate moves in its plane, where the
  // tilt draws it a little off the page's own move: the layer reaches past
  // the page's sides then.
  Item {
    id: smoothing
    readonly property real reach: desk.slide !== 0 ? Math.ceil(desk.width * 0.15) : 0
    readonly property real headroom: Style.space(12)
    x: -reach
    y: desk.layout.stackTop - headroom
    width: desk.width + 2 * reach
    height: Math.ceil(Model.tiltedHeight(desk.stripHeight, desk.tilt, desk.planeDistance)) + Style.space(24) + headroom
    z: 2
    layer.enabled: desk.tilt !== 0
    layer.samples: 4
    Item {
      id: plate
      x: desk.plateX + smoothing.reach
      y: smoothing.headroom
      width: desk.plateWidth
      height: desk.stripHeight
      LayerPlate {
        id: plateFace
        width: plate.width
        height: plate.height
        axisX: desk.layout.axis - desk.slide - desk.plateX
        tilt: desk.tilt
        planeDistance: desk.planeDistance
        animate: desk.animate
      }
    }
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
  // The control the cursor was last on, to see it give way.
  property Item lastControl: null
  onFocusedControlChanged: {
    if (focusedControl) {
      remembered = locate();
      lastControl = focusedControl;
      return;
    }
    // The control under the cursor gave way (the Notch strip's action row
    // dims once used): the cursor stays in the strip, on the nearest
    // control left, instead of leaving the desk with nothing focused.
    var gone = lastControl;
    lastControl = null;
    if (gone && !gone.enabled)
      Qt.callLater(focusFirst);
  }
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
  KeyLegend {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: Math.min(desk.width, Style.space(640))
    z: 118
    lines: desk.legend
  }
}
