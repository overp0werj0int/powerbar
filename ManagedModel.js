// Runtime policy, independent of QML and wall-clock timers.
function seconds(value, fallback, maximum) {
  var number = Number(value)
  return value === undefined || value === null || !isFinite(number)
    ? fallback : Math.max(1, Math.min(maximum, number))
}
function mode(entry, metadata) {
  var value = entry && entry.powerbarVisibility
  if (["shown", "managed", "hidden"].indexOf(value) !== -1) return value
  // Undiscovered entries remain unresolved until the registry supplies metadata.
  return metadata ? (metadata.firstParty === true ? "shown" : "managed") : "pending"
}
function deadline(now, duration) { return now + duration * 1000 }
function remaining(until, now) { return Math.max(0, until - now) }
function dismissDelay(sourceHovered, drawerHovered, interactionHeld, entered, entrySeconds, exitSeconds) {
  if (sourceHovered || drawerHovered || interactionHeld) return 0
  return (entered ? exitSeconds : entrySeconds) * 1000
}
function groupMenu(group) {
  return !!group && (group.memberDisplay === "name" || group.memberDisplay === "both")
}
function drawerVertical(group, barVertical) {
  return groupMenu(group) || !!barVertical
}
function drawerSurface(group) { return groupMenu(group) ? "menu" : "island" }
// Where a menu row's name starts: after the icon's cell when the row shows an
// icon, else at the icon edge (the text air), so every row's content shares
// one left edge.
function menuLabelStart(showIcon, cell, air) {
  return showIcon ? cell : air
}
// Menu width: the widest row's content plus the padding, at least four icon
// cells and at most 320 px (longer names elide).
function menuWidth(content, inset, cell) {
  return Math.min(320, Math.max(4 * cell, content + 2 * inset))
}
function clamp(start, length, screen, edge) {
  return Math.max(edge, Math.min(screen - edge - length, start))
}
// Along-axis placement of an icon strip.
//   o.length   strip length        o.screen  screen length    o.edge  bar gap
//   o.source   { start, end } of the group icon's cell, or null (managed drawer)
//   o.island   { start, end } of the zone's island, or null
//   o.zone     "left" | "center" | "right"   o.snap  half a highlight
// Centred on the source, kept a bar gap from the screen's edges, then an end
// within `snap` of the island's end snaps onto it.
function placeStrip(o) {
  var start
  if (o.source) {
    start = clamp((o.source.start + o.source.end) / 2 - o.length / 2, o.length, o.screen, o.edge)
    if (o.island) {
      if (Math.abs(start - o.island.start) <= o.snap) start = o.island.start
      else if (Math.abs(start + o.length - o.island.end) <= o.snap) start = o.island.end - o.length
    }
    return { start: start, aligned: "source" }
  }
  return { start: clamp(outerEnd(o), o.length, o.screen, o.edge), aligned: "island" }
}
function outerEnd(o) {
  var island = o.island || { start: o.edge, end: o.screen - o.edge }
  if (o.zone === "left") return island.start
  if (o.zone === "right") return island.end - o.length
  return (island.start + island.end) / 2 - o.length / 2
}
// Along-axis placement of a menu. Below a horizontal bar the first row starts
// where the source cell starts (rows end where it ends near the screen's
// end); beside a vertical bar the first row's centre is level with the
// source's centre (the last row's near the bottom).
//   o.inset, o.row (row thickness T), o.vertical, plus placeStrip's fields
function placeMenu(o) {
  if (!o.source) return { start: clamp(outerEnd(o), o.length, o.screen, o.edge), flipped: false }
  var start, flipped = false
  if (!o.vertical) {
    start = o.source.start - o.inset
    if (start + o.length > o.screen - o.edge) { start = o.source.end + o.inset - o.length; flipped = true }
  } else {
    var centre = (o.source.start + o.source.end) / 2
    start = centre - o.row / 2 - o.inset
    if (start + o.length > o.screen - o.edge) { start = centre + o.row / 2 + o.inset - o.length; flipped = true }
  }
  return { start: clamp(start, o.length, o.screen, o.edge), flipped: flipped }
}
function cursorVisible(keyboardMode, cursorActive, count) {
  return !!keyboardMode && !!cursorActive && count > 0
}
// Widgets whose presentation changes on a clock rather than on an event; an
// autohidden bar should not slide out for them every minute.
var quietWidgets = ["omarchy.clock"]
function quietActivity(id) { return quietWidgets.indexOf(String(id || "")) >= 0 }
// Whether a widget's activity may slide an autohidden bar out: never for
// clock-driven widgets, and not for widgets the user has opted out.
function peeksOnActivity(entry, id) {
  if (quietActivity(id)) return false
  return !(entry && typeof entry === "object" && entry.powerbarActivityPeek === false)
}
function snapshot(target) {
  if (!target) return ""
  var values = []
  // Public presentation values only. Never observe visibility/geometry/opacity:
  // those can be changed by Powerbar rather than the widget's own activity.
  var keys = ["powerbarActivityRevision", "powerbarIcon", "powerbarValue", "icon", "iconText", "text", "displayValue", "value"]
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    if (!(key in target)) continue
    var value = target[key]
    if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") values.push([key, value])
  }
  return JSON.stringify(values)
}
