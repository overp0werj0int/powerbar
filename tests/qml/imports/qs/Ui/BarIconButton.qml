import QtQuick
Item {
  property var bar: null
  property bool active: false
  property string text: ""
  property string tooltipText: ""
  property bool keepSpace: false
  property bool dimmed: false
  property bool concealed: false
  property bool interactive: true
  property bool useActiveColor: false
  property bool maintainIndicatorReveal: false
  property var revealHost: null
  property real fontSize: 12
  property real horizontalMargin: 5
  property real verticalPadding: 5
  property real fixedWidth: -1
  property real fixedHeight: -1
  readonly property bool vertical: bar ? bar.vertical : false
  implicitWidth: fixedWidth >= 0 ? fixedWidth : 24
  implicitHeight: fixedHeight >= 0 ? fixedHeight : 24
  signal pressed(int button)
}
