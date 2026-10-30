import QtQuick
import QtTest
import "../../BoardModel.js" as BoardModel

// BoardModel.js keeps Qt's key and modifier codes as numbers so node can test
// the key decoding; this compares each with Qt's own.
TestCase {
  name: "BoardModel"
  function test_keyCodesAreQts() {
    var K = BoardModel.KEY;
    compare(K.escape, Qt.Key_Escape);
    compare(K.ret, Qt.Key_Return);
    compare(K.enter, Qt.Key_Enter);
    compare(K.del, Qt.Key_Delete);
    compare(K.left, Qt.Key_Left);
    compare(K.up, Qt.Key_Up);
    compare(K.right, Qt.Key_Right);
    compare(K.down, Qt.Key_Down);
    compare(K.space, Qt.Key_Space);
    compare(K.shift, Qt.ShiftModifier);
    compare(K.control, Qt.ControlModifier);
    compare(K.alt, Qt.AltModifier);
  }
  function test_keyCommandReadsQtsEvents() {
    var k = BoardModel.keyCommand(Qt.Key_J, "J", Qt.ShiftModifier);
    compare(k.dy, 1);
    verify(k.carry);
    compare(BoardModel.keyCommand(Qt.Key_J, "j", Qt.ControlModifier), null);
  }
}
