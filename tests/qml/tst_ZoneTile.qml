import QtQuick
import QtTest
import Powerbar

// A zone tile's window of rows (PREFS-106): which row is under a point, which
// way a carry held there scrolls it, and what the wheel does.
TestCase {
  id: test
  name: "ZoneTile"
  when: windowShown
  visible: true
  width: 300
  height: 400

  Component {
    id: tileComponent
    ZoneTile {
      id: tile
      property int count: 10
      property int landing: -1
      x: 20
      y: 20
      width: 200
      height: 150
      animate: false
      pad: 10
      viewTop: 20
      viewBottom: 0
      chipHeight: 20
      spacing: 4
      model: rows.model
      RetainedList {
        id: rows
        recordProperty: "retainedRecord"
        records: {
          var out = [];
          for (var i = 0; i < tile.count; i++)
            out.push({ key: "r" + i, placeholder: i === tile.landing });
          return out;
        }
        factory: Component {
          Rectangle {
            required property var retainedRecord
            property bool placeholder: retainedRecord.placeholder
            property string key: retainedRecord.key
            width: tile.flowWidth
            height: tile.chipHeight
          }
        }
      }
    }
  }

  function tile(props) {
    var t = createTemporaryObject(tileComponent, test, props || {});
    verify(t, "the tile builds");
    return t;
  }
  // The middle of row `i` as the tile lays it out, in the test's coordinates.
  function rowPoint(t, i) {
    return Qt.point(t.x + t.pad + 10, t.y + t.viewTop - t.scroll + i * t.rowStep + t.chipHeight / 2);
  }

  function test_rowUnderAPoint() {
    var t = tile();
    compare(t.chipAt(test, rowPoint(t, 2)).key, "r2");
    compare(t.chipAt(test, rowPoint(t, 0)).key, "r0");
    t.scrollBy(48);
    compare(t.scroll, 48);
    compare(t.chipAt(test, rowPoint(t, 2)).key, "r2", "rows move with the scroll");
  }
  function test_rowsMapToThePoint() {
    var t = tile();
    var rows = t.mapRows(test, rowPoint(t, 1));
    compare(rows.length, 10);
    compare(rows[1].item.key, "r1");
    compare(rows[1].height, 20);
    verify(rows[1].y > 0 && rows[1].y < rows[1].height, "the point is in the second row");
    verify(rows[0].y > rows[0].height, "past the first");
    verify(rows[2].y < 0, "before the third");
  }
  function test_landingPlacesAreNotRows() {
    var t = tile({ landing: 3 });
    compare(t.mapRows(test, rowPoint(t, 0)).length, 9, "a landing place is left out");
    compare(t.chipAt(test, rowPoint(t, 3)), null, "and nothing is under it");
    compare(t.chipAt(test, rowPoint(t, 4)).key, "r4");
  }
  function test_nothingBelowOrAboveTheWindow() {
    var t = tile();
    compare(t.chipAt(test, Qt.point(t.x + t.pad + 10, t.y + t.viewTop + t.viewHeight + 2)), null, "below the window");
    t.scrollBy(60);
    compare(t.chipAt(test, Qt.point(t.x + t.pad + 10, t.y + t.viewTop - t.room - 2)), null, "above it");
    verify(t.chipAt(test, Qt.point(t.x + t.pad + 10, t.y + t.viewTop + 2)), "inside it");
  }

  function test_edgeDirection() {
    var t = tile();
    verify(t.overflows);
    var top = Qt.point(t.x + t.pad, t.y + t.viewTop + 2);
    var bottom = Qt.point(t.x + t.pad, t.y + t.viewTop + t.viewHeight - 2);
    var middle = Qt.point(t.x + t.pad, t.y + t.viewTop + t.viewHeight / 2);
    compare(t.edgeDirection(test, top), 0, "at the top it cannot go up");
    compare(t.edgeDirection(test, bottom), 1);
    compare(t.edgeDirection(test, middle), 0);
    t.scrollBy(t.maxScroll);
    compare(t.edgeDirection(test, top), -1);
    compare(t.edgeDirection(test, bottom), 0, "at the bottom it cannot go down");
  }
  function test_edgeDirectionWithoutOverflow() {
    var t = tile({ count: 2 });
    verify(!t.overflows);
    compare(t.edgeDirection(test, Qt.point(t.x + t.pad, t.y + t.viewTop + 2)), 0);
    compare(t.edgeDirection(test, Qt.point(t.x + t.pad, t.y + t.viewTop + t.viewHeight - 2)), 0);
  }

  function test_wheelScrollsARowANotch() {
    var t = tile();
    verify(t.scrollByWheel({ pixelDelta: Qt.point(0, 0), angleDelta: Qt.point(0, -120) }), "it takes the wheel");
    compare(t.scroll, t.rowStep);
    verify(t.scrollByWheel({ pixelDelta: Qt.point(0, -10), angleDelta: Qt.point(0, 0) }));
    compare(t.scroll, t.rowStep + 10, "a touchpad scrolls its pixels");
    verify(t.scrollByWheel({ pixelDelta: Qt.point(0, 0), angleDelta: Qt.point(0, 1200) }));
    compare(t.scroll, 0, "and stops at the top");
  }
  function test_wheelWithoutOverflowIsLeftAlone() {
    var t = tile({ count: 2 });
    verify(!t.scrollByWheel({ pixelDelta: Qt.point(0, 0), angleDelta: Qt.point(0, -120) }));
    compare(t.scroll, 0);
  }

  Component {
    id: edgeComponent
    EdgeScroll {}
  }
  SignalSpy {
    id: steps
    signalName: "stepped"
  }
  function test_edgeScrollRunsWhileACarryIsHeld() {
    var t = tile();
    var edge = createTemporaryObject(edgeComponent, test);
    steps.target = edge;
    steps.clear();
    var bottom = Qt.point(t.x + t.pad, t.y + t.viewTop + t.viewHeight - 2);
    edge.aim(t, test, bottom);
    compare(edge.dir, 1);
    verify(!edge.running, "not before a carry is held");
    edge.active = true;
    verify(edge.running);
    tryVerify(function () { return t.scroll > 0 && steps.count > 0 }, 1000, "it scrolls the window and says so");
    edge.aim(null);
    verify(!edge.running, "and stops when aimed at nothing");
    var at = t.scroll;
    wait(50);
    compare(t.scroll, at);
  }
}
