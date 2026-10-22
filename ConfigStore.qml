import QtQuick
import qs.Commons
import "BarModel.js" as BarModel
import "SectionsModel.js" as SectionsModel

// The bar's config edits, from the moment they show to the moment shell.json
// has them. Omarchy handles a config write by re-registering every bar widget,
// once for the write and again when it reloads the file, which can block the
// whole shell for hundreds of milliseconds. So each edit is applied at once to
// a copy of the host's config, exactly as the host applies a bar's edit (to a
// copy of the bar subtree), shown as the bar's config, and queued; a quiet
// moment then writes the queue as one config change: no gesture under way
// (`settled`) and the user away from the bar (`idle`), or, still at the bar,
// `idleWait` after the last edit.
//
// The bar's `barConfig` has two writers: the host, which assigns the config it
// holds, and this store, which shows the host's config with the queued edits
// on top (`show`). Every assignment the bar sees goes through `delivered()`:
// one from the host while edits wait is kept as the new base and the edits are
// shown on top of it again.
//
// Edits run again on the host's config, so they must capture plain values,
// never live slot state, and must not invent values (writeNow is for those).
// An edit that throws is dropped with a warning, so it cannot block the rest.
//
// Writes go through the shell only while its config names Powerbar as the bar
// (BarModel.ownsBarConfig): Omarchy saves its whole config with every write,
// and when it could not read shell.json it holds its defaults, which name no
// bar; a write then would save them over the user's file (INTEG-144).
QtObject {
  id: store

  property var shell: null
  property string barId: ""
  // The config the bar shows now (its barConfig).
  property var shown: ({})
  // No drag, glide or bar move under way: the queue may be written.
  property bool settled: true
  // The pointer and the keys are away from the bar: a write's stall goes
  // unseen. Not idle only delays the write, up to idleWait after the last edit.
  property bool idle: true
  property int delay: 300
  property int idleWait: 20000
  property real lastEdit: 0
  // Written `delay` after the moment comes, not at the next retry.
  onSettledChanged: if (settled && pending) flushDelay.restart()
  onIdleChanged: if (idle && pending) flushDelay.restart()

  // Ask the bar to show a config; the assignment comes back through delivered().
  signal show(var config)
  // The queue was not saved; the bar shows the host's config again.
  signal failed()

  property var edits: []
  // The host's config under the queued edits: a failed write restores it.
  property var host: null
  readonly property bool pending: edits.length > 0
  property bool applying: false

  property Timer flushDelay: Timer {
    interval: store.delay
    onTriggered: {
      if (store.settled && (store.idle || Date.now() - store.lastEdit >= store.idleWait)) store.flush()
      else restart()
    }
  }

  function shellCanWrite() { return !!shell && typeof shell.mutateShellConfig === "function" }
  // Edits run on the five zone lists (SectionsModel): each write reads the
  // saved layout into them first, and writes them back in the shape this
  // Omarchy keeps.
  function mutate(mutator) {
    var six = SectionsModel.sixSections(Util.barSections)
    return shell.mutateShellConfig(function(config) {
      if (Util.isPlainObject(config.bar)) SectionsModel.read(config.bar)
      try { mutator(config) } finally { if (Util.isPlainObject(config.bar)) SectionsModel.write(config.bar, six) }
    })
  }
  function canWrite() { return !retired && shellCanWrite() && BarModel.ownsBarConfig(pending ? host : shown, barId) }

  // The bar is going away (its Component.onDestruction): what is queued is
  // saved now, and nothing is written after, whatever still runs late.
  property bool retired: false
  function retire() {
    flush()
    retired = true
  }

  // Queue an edit and show it at once. False when it cannot be written, or
  // when it threw on the host's config.
  function write(mutator) {
    if (typeof mutator !== "function" || !canWrite()) return false
    if (!pending) host = shown
    edits = edits.concat([mutator])
    lastEdit = Date.now()
    showEdits()
    flushDelay.restart()
    return edits.indexOf(mutator) >= 0
  }

  // A direct write for edits that must run on the host's config itself, such
  // as new instance ids, which would differ if invented twice.
  function writeNow(mutator) {
    if (typeof mutator !== "function" || !canWrite()) return false
    return mutate(mutator) !== false
  }

  // Every assignment to the bar's config. True when it came from the host
  // while edits wait: the store has shown the edits on top of it again and the
  // bar should not treat it as a new config.
  function delivered(config) {
    if (applying || !pending) return false
    host = config
    showEdits()
    return true
  }

  // Each queued edit on the config, dropping (and naming) any that throws.
  function runEdits(config) {
    var kept = []
    for (var edit of edits) {
      try {
        edit(config)
        kept.push(edit)
      } catch (error) {
        console.warn("powerbar: a config change failed and was dropped: " + error)
      }
    }
    return kept
  }

  // The host's config with every queued edit applied, shown as the bar's config.
  function showEdits() {
    var scoped = { bar: JSON.parse(JSON.stringify(Util.isPlainObject(host) ? host : {})) }
    var kept = runEdits(scoped)
    if (kept.length !== edits.length) edits = kept
    if (!Util.isPlainObject(scoped.bar)) return
    showConfig(scoped.bar)
  }

  function showConfig(config) {
    applying = true
    try { show(config) } finally { applying = false }
  }

  function flush() {
    flushDelay.stop()
    var queued = edits, restore = host
    if (!queued.length) return
    edits = []
    host = null
    if (!BarModel.ownsBarConfig(restore, barId)) {
      console.warn("powerbar: the shell's config no longer names Powerbar as the bar; " + queued.length + " change(s) not saved")
      showConfig(restore)
      failed()
      return
    }
    var saved = !retired && shellCanWrite() && mutate(function(config) {
      for (var edit of queued) {
        try { edit(config) } catch (error) { console.warn("powerbar: a config change failed and was dropped: " + error) }
      }
    }) !== false
    if (!saved) {
      console.warn("powerbar: the shell did not save " + queued.length + " change(s) to shell.json; the bar shows the saved config again")
      showConfig(restore)
      failed()
    }
  }
}
