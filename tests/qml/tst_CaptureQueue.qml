import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "BoundedPreviewCapture"
  when: windowShown
  property var callbacks: []
  property var accepted: []
  property bool live: true
  property bool failGrab: false
  QtObject {
    id: source
    function grabToImage(callback, size) {
      if (test.failGrab) return false
      test.callbacks.push(callback)
      return true
    }
  }
  CaptureQueue { id: queue; limit: 2 }
  function job(key) {
    return { key: key, item: source, size: Qt.size(20, 20),
      valid: function() { return test.live }, accept: function(result) { test.accepted.push(key + ":" + result.url) } }
  }
  function complete(at, url) { callbacks[at]({ url: url }); wait(1) }
  function cleanup() { live = false; for (var i = 0; i < callbacks.length; i++) if (callbacks[i]) { var cb = callbacks[i]; callbacks[i] = null; cb(null) }; wait(1); callbacks = []; accepted = []; live = true; failGrab = false }
  function test_boundAndSupersededResults() {
    queue.enqueue([job("a"), job("b"), job("c")])
    compare(queue.inFlight, 2); compare(callbacks.length, 2)
    queue.enqueue([job("a")])
    var cb = callbacks[0]; callbacks[0] = null; cb({ url: "old" }); wait(1)
    compare(accepted.length, 0); compare(callbacks.length, 3)
    cb = callbacks[1]; callbacks[1] = null; cb({ url: "b" }); wait(1)
    compare(callbacks.length, 4); compare(accepted[0], "b:b")
    cb = callbacks[3]; callbacks[3] = null; cb({ url: "new" }); wait(1)
    compare(accepted[1], "a:new")
    live = false
    cb = callbacks[2]; callbacks[2] = null; cb({ url: "closed" }); wait(1)
    compare(accepted.length, 2); compare(queue.inFlight, 0)
  }
  function test_failedGrabsDoNotBlockQueue() {
    failGrab = true; queue.enqueue([job("bad1"), job("bad2"), job("bad3")])
    compare(queue.inFlight, 0); compare(queue.pending.length, 0)
    failGrab = false; queue.enqueue([job("okay")]); compare(queue.inFlight, 1)
    var cb = callbacks[0]; callbacks[0] = null; cb({ url: "okay" }); wait(1)
    compare(accepted.length, 1); compare(queue.inFlight, 0)
  }
}
