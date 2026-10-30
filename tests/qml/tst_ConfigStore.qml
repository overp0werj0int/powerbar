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
    property var lastApplied: null
    function deliver(bar) { barConfig = JSON.parse(JSON.stringify(bar)) }
    onBarConfigChanged: if (!store.delivered(barConfig)) { applied++; lastApplied = barConfig }
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
    store.heal = null
    store.idle = true
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
  function test_retireSavesTheQueueThenRefusesEveryWrite() {
    set("spacing", 7)
    store.retire()
    compare(shell.writes, 1, "the queued edit is saved on the way out")
    compare(shell.config.bar.spacing, 7)
    verify(!store.canWrite())
    verify(!set("spacing", 9), "no edit is queued after")
    store.flush()
    compare(shell.writes, 1)
    compare(shell.config.bar.spacing, 7)
  }

  // A heal that gives the bar an id once, decided outside its edit, and keeps
  // the configs it was asked about.
  property var asked: []
  // Another writer saves the config, and the host delivers it.
  function otherWriter(bar) {
    shell.config = { version: 1, plugins: [{ id: "keep" }], bar: bar }
    host.deliver(bar)
  }
  function healIds() {
    asked = []
    store.heal = function(bar) {
      asked.push(JSON.parse(JSON.stringify(bar)))
      if (bar.ids) return null
      var id = "id-" + asked.length
      return function(config) { if (!config.bar.ids) config.bar.ids = id }
    }
  }
  function test_aConfigFromTheHostShowsHealedAndIsWrittenOnce() {
    healIds()
    var applied = host.applied
    otherWriter({ id: "p0werj0int.powerbar", spacing: 1, position: "bottom" })
    compare(host.barConfig.ids, "id-1", "shown healed at once")
    compare(host.barConfig.position, "bottom")
    compare(host.applied, applied + 1, "applied once")
    compare(host.lastApplied.ids, "id-1", "healed: the unhealed config is never applied")
    compare(shell.writes, 0)
    tryCompare(shell, "writes", 1)
    compare(shell.config.bar.ids, "id-1", "the id it showed")
    wait(60)
    compare(shell.writes, 1, "the healed config delivered back heals to nothing")
    verify(!store.pending)
  }
  function test_theHealWaitsWhileTheUserIsAtTheBar() {
    healIds()
    store.idle = false
    otherWriter({ id: "p0werj0int.powerbar", spacing: 1 })
    compare(host.barConfig.ids, "id-1")
    wait(80)
    compare(shell.writes, 0, "no write under the pointer")
    store.idle = true
    tryCompare(shell, "writes", 1)
    compare(shell.config.bar.ids, "id-1")
  }
  function test_aHealIsDecidedOnTheConfigTheBarWouldShowAndKeepsQueuedEdits() {
    healIds()
    set("spacing", 4)
    otherWriter({ id: "p0werj0int.powerbar", spacing: 1, position: "left" })
    compare(asked[asked.length - 1].spacing, 4, "the queued edit is on the config it heals")
    compare(host.barConfig.spacing, 4)
    compare(host.barConfig.ids, "id-1")
    set("style", "flat")
    otherWriter({ id: "p0werj0int.powerbar", spacing: 1, position: "right" })
    compare(host.barConfig.ids, "id-1", "a newer host config shows the same id")
    store.flush()
    compare(shell.writes, 1)
    compare(shell.config.bar.spacing, 4)
    compare(shell.config.bar.style, "flat")
    compare(shell.config.bar.position, "right")
    compare(shell.config.bar.ids, "id-1")
  }
  function test_aConfigNotNamingPowerbarIsShownUnhealed() {
    healIds()
    var applied = host.applied
    host.deliver({ layout: {} })
    compare(host.applied, applied + 1, "shown as delivered")
    verify(!("ids" in host.barConfig))
    verify(!store.pending)
  }
  function test_aRefusedHealIsNotTriedAgainOnTheConfigItFailedOn() {
    healIds()
    otherWriter({ id: "p0werj0int.powerbar", spacing: 2 })
    shell.refuse = true
    ignoreWarning(/did not save/)
    store.flush()
    compare(failedSpy.count, 1)
    verify(!("ids" in host.barConfig), "the host's config again")
    verify(!store.pending, "not queued again")
  }
  function test_aHealThatThrowsStillShowsTheConfig() {
    store.heal = function(bar) { throw new Error("malformed") }
    var applied = host.applied
    ignoreWarning(/could not be healed/)
    otherWriter({ id: "p0werj0int.powerbar", spacing: 6 })
    compare(host.applied, applied + 1)
    compare(host.barConfig.spacing, 6)
    verify(!store.pending)
  }
}
