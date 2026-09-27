import QtQuick
import qs.Commons

// A widget's own look at icon size: its live rendering when it is loaded, the
// last rendering Powerbar saw when it is hidden, and a stock glyph otherwise.
Item {
  id: icon
  required property var preferences
  property var record: ({})
  property real size: Style.font.iconLarge
  property real maxAspect: 3.2
  property color color: Color.popups.text
  readonly property string key: record && record.instanceKey ? record.instanceKey : ""
  readonly property var live: key ? preferences.snapshots[key] : null
  readonly property string cachedUrl: !live && key !== "" && !record.groupId ? preferences.cachedImageUrl(key) : ""
  readonly property bool useCache: cachedUrl !== ""
  readonly property bool hasImage: !!live || (useCache && cached.status === Image.Ready)
  readonly property real aspect: live ? live.width / Math.max(1, live.height)
    : cached.implicitWidth / Math.max(1, cached.implicitHeight)
  implicitHeight: hasImage ? size : glyph.implicitHeight
  implicitWidth: hasImage ? Math.min(size * maxAspect, size * aspect) : glyph.implicitWidth
  Accessible.ignored: true

  Image {
    anchors.fill: parent
    visible: !!icon.live
    source: icon.live ? icon.live.url : ""
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }
  Image {
    id: cached
    anchors.fill: parent
    visible: icon.useCache && status === Image.Ready
    source: icon.cachedUrl
    asynchronous: true
    cache: false
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }
  Text {
    id: glyph
    anchors.centerIn: parent
    visible: !icon.hasImage
    text: icon.key ? icon.preferences.icon(icon.record) : ""
    textFormat: Text.PlainText
    color: icon.record && icon.record.groupId ? Color.accent : icon.color
    font.family: icon.key ? icon.preferences.iconFont(icon.record) : Style.font.family
    font.pixelSize: Math.round(icon.size * 0.72)
  }
}
