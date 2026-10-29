import QtQuick
import qs.Commons
import qs.Commons as Commons

// A widget's icon in a chip's square on the Layout and Groups pages: the
// middle of its ink, or a wide face's first glyph, so nothing sticks out of
// the square (docs/behavior/preferences.md PREFS-22). `layout` is the Layout
// page's editor, which knows how the bar draws each widget (barFace).
Item {
    id: inkIcon
    required property var layout
    property var record: ({})
    property real box: Style.space(20)
    readonly property bool hasImage: picture.hasImage
    readonly property var face: record && record.instanceKey ? layout.barFace(record) : null
    width: box
    height: box
    // Widget images in the bar's text colour that barely show on the
    // Preferences background get a backing (LayoutEditor.inkBacked).
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Style.space(2)
        visible: inkIcon.layout.inkBacked && picture.hasImage
        radius: Style.space(3)
        color: Commons.Color.popups.text
    }
    // A wide face shows its first glyph only: about the bar icon's own width.
    readonly property bool wide: {
        var f = face;
        return hasImage && !!f && f.kind === "image" && f.w > 0 && f.inkLength / f.w * picture.width > box;
    }
    Item {
        width: inkIcon.wide ? Math.round(inkIcon.box * 0.62) : parent.width
        height: parent.height
        clip: true
        WidgetIcon {
            id: picture
            preferences: inkIcon.layout.preferences
            record: inkIcon.record
            size: inkIcon.box
            maxAspect: 8
            anchors.verticalCenter: parent.verticalCenter
            x: {
                var f = inkIcon.face;
                if (!hasImage || !f || f.kind !== "image" || !(f.w > 0))
                    return Math.round((inkIcon.box - width) / 2);
                // Ink wider than the box starts at its leading icon, not mid-word.
                var scale = width / f.w;
                if (inkIcon.wide)
                    return Math.round(-f.inkStart * scale);
                return Math.round(inkIcon.box / 2 - (f.inkStart + f.inkLength / 2) * scale);
            }
        }
    }
}
