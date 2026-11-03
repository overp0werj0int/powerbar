import QtQuick
import QtQuick.Layouts
import qs.Commons
import "DeskModel.js" as DeskModel

// A board inspector's body as a small desk (docs/behavior/preferences.md
// PREFS-26, PREFS-116): its strips (DeskStrip, its children) side by side,
// flat, l apart, all as tall as the tallest, walked with the Look and
// Behavior pages' keys (DeskWalk). No camera falls on it. Its actions (a
// DeskRow that ends something, such as Dissolve) stand on their own under
// the strips, at the right, in line with the last strip's text; the walk
// reaches them after the last strip.
Item {
  id: desk
  // The Layout page's editor: the theme and the Animations switch.
  required property var layout
  // Where the cursor starts when the inspector takes focus; the desk's first
  // control when it cannot take it.
  property Item start: null
  // The legend's Esc line.
  property string escLabel: ""
  default property alias strips: face.data
  property alias actions: actionColumn.data
  // Its controls draw the cursor, so Preferences' focus ring stays away.
  readonly property bool ownsFocusRings: true

  // What a strip asks of its desk.
  readonly property bool animate: layout.bar.animationsEnabled
  readonly property bool lightTheme: layout.lightTheme
  readonly property bool cameraShown: false
  readonly property real tilt: 0
  readonly property real planeDistance: 1600
  readonly property Item camera: null
  readonly property real beamLeft: 0
  readonly property real beamWidth: 0
  readonly property real seenTop: 0
  readonly property real line: 0
  readonly property var stripList: {
    var out = [];
    var kids = face.children;
    for (var i = 0; i < kids.length; i++)
      if (kids[i].isDeskStrip && kids[i].visible)
        out.push(kids[i]);
    return out;
  }
  readonly property var boxes: DeskModel.stripBoxes(width, stripList.length, Gap.l)
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
  readonly property var actionControls: {
    var list = [];
    var kids = actionColumn.children;
    for (var i = 0; i < kids.length; i++)
      if (kids[i].deskStops !== undefined && kids[i].visible && kids[i].enabled)
        list.push(kids[i]);
    return list;
  }
  readonly property bool hasActions: actionColumn.implicitHeight > 0
  implicitHeight: stripHeight + (hasActions ? Gap.l + actionColumn.implicitHeight : 0)
  Component.onCompleted: {
    var kids = face.children;
    for (var i = 0; i < kids.length; i++)
      if (kids[i].isDeskStrip)
        kids[i].desk = desk;
  }
  Item {
    id: face
    width: parent.width
    height: desk.stripHeight
  }
  ColumnLayout {
    id: actionColumn
    readonly property var lastBox: desk.boxes.length ? desk.boxes[desk.boxes.length - 1] : null
    x: lastBox ? lastBox.x + Gap.l : 0
    width: lastBox ? lastBox.width - 2 * Gap.l : 0
    y: desk.stripHeight + Gap.l
    spacing: Gap.xs
  }
  // The actions as one more strip for the walk.
  QtObject {
    id: actionStrip
    readonly property var controls: desk.actionControls
  }

  DeskWalk {
    id: walk
    strips: desk.actionControls.length ? desk.stripList.concat([actionStrip]) : desk.stripList
    focusedItem: desk.Window.activeFocusItem
  }
  readonly property Item focusedControl: walk.focusedControl
  function usable(control) {
    return walk.strips.some(function (s) {
      return s.controls.indexOf(control) >= 0;
    });
  }
  function focusFirst() {
    if (start && usable(start))
      start.deskFocus(start.deskHome, Qt.TabFocusReason);
    else
      walk.go(DeskModel.first(walk.model()), Qt.TabFocusReason);
  }
  Keys.onPressed: function (event) {
    walk.key(event);
  }

  // While a control edits text, only its own keys work.
  readonly property var legend: focusedControl && focusedControl.editing ? focusedControl.keyHints : DeskModel.legend([
    {
      keys: "j k",
      label: "Down the strip, on to the next"
    },
    {
      keys: "h l",
      label: "Same row, next strip"
    },
    {
      keys: "tab",
      label: "Next strip"
    },
    {
      keys: "esc",
      label: escLabel
    }
  ], focusedControl && focusedControl.keyHints ? focusedControl.keyHints : [])
}
