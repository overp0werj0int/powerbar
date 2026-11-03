import QtQuick
import qs.Commons

// The boards' edge scroll (PREFS-106): while a pointer carry is held in a
// window's top or bottom band (ZoneTile.edgeDirection), the window scrolls
// 3 px every 16 ms and `stepped` lets the page re-aim the landing place.
Timer {
    id: edge
    // The page's pointer lift.
    property bool active: false
    property Item tile: null
    property int dir: 0
    signal stepped
    // Aim at the window a point is over, or at nothing (`win` null).
    function aim(win, from, point) {
        var d = win ? win.edgeDirection(from, point) : 0;
        tile = d ? win : null;
        dir = d;
    }
    interval: 16
    repeat: true
    running: !!tile && dir !== 0 && active
    onTriggered: {
        tile.scrollBy(dir * Style.space(3));
        stepped();
    }
}
