import QtQuick
import QtQuick.Window
import qs.Commons

// A widget's own look at icon size: its live rendering when it is loaded, the
// last rendering Powerbar saw when it is hidden, and otherwise its glyph: the
// one the widget draws itself (Preferences.icon), or a stock one.
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
  // Images saved from a vertical bar before Powerbar stopped capturing one fall
  // back to the glyph. A horizontal image is as tall as a horizontal bar, at
  // either size; its shape says nothing, since an icon on a large bar is
  // 27 × 38.
  readonly property bool cacheUsable: useCache && cached.status === Image.Ready
    && (Math.abs(imageHeight - Style.bar.sizeHorizontal) <= 1
      || Math.abs(imageHeight - Style.bar.sizeHorizontal - (bar ? bar.largeBarLip * 2 : 0)) <= 1)
  readonly property bool hasImage: !!live || cacheUsable
  // Images are grabbed at twice their size; a large bar's slots include a lip
  // above and below the widget (beside it on a vertical bar), trimmed here so
  // the icon shows the widget alone at either bar size.
  readonly property var bar: preferences.bar
  // Saved images are grabbed at twice the widget's size, which the display
  // scale multiplies again.
  readonly property real savedScale: 2 * Math.max(1, Screen.devicePixelRatio)
  readonly property real imageWidth: live ? live.width : cached.sourceSize.width / savedScale
  readonly property real imageHeight: live ? live.height : cached.sourceSize.height / savedScale
  // Every image comes from a horizontal bar (a vertical one is never
  // captured), so only a horizontal bar's lip is ever trimmed.
  readonly property real horizontalBarSize: bar ? bar.barSizeFor(false) : 0
  readonly property real lip: bar ? Math.max(0, (horizontalBarSize - Style.bar.sizeHorizontal) / 2) : 0
  readonly property real trimX: 0
  readonly property real trimY: bar && imageHeight >= horizontalBarSize ? lip : 0
  readonly property real aspect: Math.max(1, imageWidth - trimX * 2) / Math.max(1, imageHeight - trimY * 2)
  implicitHeight: hasImage ? size : glyph.implicitHeight
  implicitWidth: hasImage ? Math.min(size * maxAspect, size * aspect) : glyph.implicitWidth
  clip: hasImage && (trimX > 0 || trimY > 0)
  Accessible.ignored: true

  Item {
    id: frame
    anchors.centerIn: parent
    width: icon.width * icon.imageWidth / Math.max(1, icon.imageWidth - icon.trimX * 2)
    height: icon.height * icon.imageHeight / Math.max(1, icon.imageHeight - icon.trimY * 2)
  }
  Image {
    anchors.fill: frame
    visible: !!icon.live
    source: icon.live ? icon.live.url : ""
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }
  Image {
    id: cached
    anchors.fill: frame
    visible: icon.cacheUsable
    source: icon.cachedUrl
    asynchronous: true
    cache: true
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
