import QtQuick

// Per-key replacement, bounded GPU readbacks, and a caller-owned validity guard.
Item {
  id: queue
  property int limit: 2
  property int inFlight: 0
  property var pending: []
  property var latest: Object.create(null)
  property int serial: 0
  visible: false
  function enqueue(jobs) {
    for (var job of jobs) {
      job.serial = ++serial
      latest[job.key] = job.serial
      pending.push(job)
    }
    pump()
  }
  function current(job) {
    return latest[job.key] === job.serial && (!job.valid || job.valid())
  }
  function finish(job, result) {
    inFlight--
    if (current(job) && result && result.url) job.accept(result)
    if (latest[job.key] === job.serial) delete latest[job.key]
    Qt.callLater(pump)
  }
  function start(job) {
    if (job.prepare && !job.prepare(job)) {
      if (latest[job.key] === job.serial) delete latest[job.key]
      return
    }
    inFlight++
    var accepted = job.item.grabToImage(function(result) { queue.finish(job, result) }, job.size)
    if (!accepted) finish(job, null)
  }
  function pump() {
    while (inFlight < limit && pending.length) {
      var job = pending.shift()
      if (!current(job)) {
        if (latest[job.key] === job.serial) delete latest[job.key]
        continue
      }
      start(job)
    }
  }
}
