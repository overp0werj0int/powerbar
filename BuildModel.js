.pragma library
// Which code this shell process really runs (`powerbar build`, INTEG-147).
// Omarchy's plugin rescan rebuilds the bar in the same process, and Qt builds
// it from the code it already holds, whatever is on disk by then. So the first
// stamp of a process is the running code, and a later one that differs means
// newer files wait for a shell restart. A library's state lives as long as
// Qt keeps the code, so this outlasts the bar and goes with the process.
var running = null
var noticed = ""

// `stamp` is BuildStamp.sh's answer as the bar loaded. Answers the running
// code, whether the files on disk differ from it, and whether to say so:
// once for each new set of files.
function observe(stamp, now) {
  if (!running && stamp.digest) running = Object.assign({ loadedAt: now }, stamp)
  var behind = !!running && !!stamp.digest && stamp.digest !== running.digest
  var notify = behind && stamp.digest !== noticed
  if (notify) noticed = stamp.digest
  return { running: running || stamp, behind: behind, notify: notify }
}
