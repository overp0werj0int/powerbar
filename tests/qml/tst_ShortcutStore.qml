import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "ShortcutStore"
  // Plays the bar: its config, which Preferences' setOption changes at once.
  QtObject {
    id: bar
    property var barConfig: ({})
    property var groups: []
    function canWriteConfig() { return true }
  }
  QtObject {
    id: prefs
    property string status: ""
    function title(def) { return def.id }
    function setOption(key, value) {
      var next = JSON.parse(JSON.stringify(bar.barConfig))
      if (value === undefined) delete next[key]
      else next[key] = value
      bar.barConfig = next
    }
  }
  ShortcutStore {
    id: store
    bar: bar
    preferences: prefs
  }
  // The Process that runs ShortcutApply.sh: the stub never runs it, so the
  // test ends each run by hand.
  function applyProc() {
    var found = store.data.concat(store.resources).filter(function(o) {
      return o && o.command && o.command[1] === store.applyScript
    })
    return found.length ? found[0] : null
  }
  function finish(code) {
    var p = applyProc()
    p.running = false
    p.exited(code)
  }
  function init() {
    bar.barConfig = {}
    store.busy = false
    store.error = ""
  }

  // A change made while another is still being applied is saved at once and
  // written once that one is done, so bindings.lua ends on both.
  function test_change_while_applying_is_written_after() {
    store.save("widget:audio", "SUPER + A")
    var p = applyProc()
    verify(store.busy)
    compare(p.starts, 1)
    store.save("widget:wifi", "SUPER + W")
    compare(bar.barConfig.powerbarShortcuts["widget:wifi"], "SUPER + W")
    compare(p.starts, 1, "the second change waits for the first run")
    finish(0)
    verify(store.busy, "still applying the second change")
    compare(p.starts, 2)
    verify(p.command[2].indexOf("SUPER + A") >= 0 && p.command[2].indexOf("SUPER + W") >= 0, p.command[2])
    finish(0)
    verify(!store.busy)
    compare(Object.keys(bar.barConfig.powerbarShortcuts).sort(), ["widget:audio", "widget:wifi"])
  }

  // A refused first change takes the waiting one with it: that one was made
  // on top of it, and the config goes back to what bindings.lua still holds.
  function test_refused_change_drops_the_waiting_one() {
    bar.barConfig = { powerbarShortcuts: { "widget:clock": "SUPER + C" } }
    store.save("widget:audio", "SUPER + A")
    var p = applyProc(), before = p.starts
    store.restore("widget:clock")
    finish(1)
    verify(!store.busy)
    compare(p.starts, before, "nothing else is written")
    compare(bar.barConfig.powerbarShortcuts, { "widget:clock": "SUPER + C" })
    verify(store.error !== "")
  }
}
