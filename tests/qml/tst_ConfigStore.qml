import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "ConfigStore"
  // Plays Omarchy: holds the config, applies a bar write to it and delivers it
  // back synchronously, as shell.qml's mutateShellConfig does.
  QtObject {
    id: shell
    property var config: ({})
    property int writes: 0
    property bool refuse: false
    function mutateShellConfig(mutator) {
      if (refuse) return false
      var copy = JSON.parse(JSON.stringify(config))
      mutator(copy)
      config = copy
      writes++
      host.deliver(copy.bar)
      return true
    }
  }
  // Plays the bar: its barConfig, assigned by the host and by the store.
  QtObject {
    id: host
    property var barConfig: ({})
    property int applied: 0
    function deliver(bar) { barConfig = JSON.parse(JSON.stringify(bar)) }
    onBarConfigChanged: if (!store.delivered(barConfig)) applied++
  }
  ConfigStore {
    id: store
    shell: shell
    barId: "p0werj0int.powerbar"
    shown: host.barConfig
    delay: 10
    onShow: function(config) { host.barConfig = config }
  }
  SignalSpy { id: failedSpy; target: store; signalName: "failed" }

  function init() {
    store.retired = false
    store.flush()
    shell.refuse = false
    shell.config = { version: 1, plugins: [{ id: "keep" }], bar: { id: "p0werj0int.powerbar", spacing: 1 } }
    shell.writes = 0
    host.deliver(shell.config.bar)
    failedSpy.clear()
  }
  function set(key, value) { return store.write(function(config) { config.bar[key] = value }) }

  function test_editShowsAtOnceAndIsWrittenOnceSettled() {
    verify(set("spacing", 4))
    compare(host.barConfig.spacing, 4, "shown at once")
    compare(shell.writes, 0, "not written yet")
    verify(set("style", "flat"))
    tryCompare(shell, "writes", 1)
    compare(shell.config.bar.spacing, 4)
    compare(shell.config.bar.style, "flat")
    compare(shell.config.plugins.length, 1, "the rest of the config is the host's")
    verify(!store.pending)
  }
  function test_waitsWhileUnsettled() {
    store.settled = false
    set("spacing", 2)
    wait(60)
    compare(shell.writes, 0)
    store.settled = true
    tryCompare(shell, "writes", 1)
  }
  function test_hostDeliveryKeepsQueuedEditsOnTop() {
    set("spacing", 5)
    host.deliver({ id: "p0werj0int.powerbar", spacing: 1, position: "bottom" })
    compare(host.barConfig.spacing, 5, "the edit stays shown")
    compare(host.barConfig.position, "bottom", "on the host's new config")
    store.flush()
    compare(shell.config.bar.spacing, 5)
  }
  function test_aConfigNotNamingPowerbarIsNeverWritten() {
    host.deliver({ layout: {} })
    verify(!store.canWrite(), "Omarchy's defaults name no bar")
    verify(!set("spacing", 9))
    verify(!store.writeNow(function(config) { config.bar.spacing = 9 }))
    compare(shell.writes, 0)
  }
  function test_queueOnAConfigThatStopsNamingPowerbarIsDropped() {
    set("spacing", 7)
    host.deliver({ layout: {} })
    ignoreWarning(/no longer names Powerbar/)
    store.flush()
    compare(shell.writes, 0, "the defaults are not saved")
    compare(failedSpy.count, 1)
    verify(!("spacing" in host.barConfig) || host.barConfig.spacing !== 7, "the bar shows the host's config again")
  }
  function test_aThrowingEditIsDroppedAndTheRestWritten() {
    set("spacing", 3)
    ignoreWarning(/a config change failed and was dropped/)
    verify(!store.write(function(config) { config.bar.layout.left.push("x") }), "the throwing edit is refused")
    verify(set("style", "flat"), "later edits still work")
    store.flush()
    compare(shell.config.bar.spacing, 3)
    compare(shell.config.bar.style, "flat")
  }
  function test_refusedWriteShowsTheHostConfigAgain() {
    set("spacing", 8)
    shell.refuse = true
    ignoreWarning(/did not save/)
    store.flush()
    compare(host.barConfig.spacing, 1)
    compare(failedSpy.count, 1)
  }
  function test_writeNowRunsOnTheHostConfig() {
    verify(store.writeNow(function(config) { config.bar.ids = true }))
    compare(shell.writes, 1)
    compare(host.barConfig.ids, true)
  }
  function test_retireSavesTheQueueThenRefusesEveryWrite() {
    set("spacing", 7)
    store.retire()
    compare(shell.writes, 1, "the queued edit is saved on the way out")
    compare(shell.config.bar.spacing, 7)
    verify(!store.canWrite())
    verify(!set("spacing", 9), "no edit is queued after")
    verify(!store.writeNow(function(config) { config.bar.ids = true }), "nor written directly")
    store.flush()
    compare(shell.writes, 1)
    compare(shell.config.bar.spacing, 7)
  }
}
