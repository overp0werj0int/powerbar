import Quickshell
import QtQuick
FloatingWindow {
  property BenchAnchors anchors: BenchAnchors {}
  property BenchMargins margins: BenchMargins {}
  property int exclusionMode: 0
  property int exclusiveZone: 0
  implicitWidth: screen ? screen.width : 800
  implicitHeight: screen ? screen.height : 600
}
