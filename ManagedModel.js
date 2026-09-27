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
function menuLabelStart(showNative, naturalWidth, inset, iconGap) {
  return showNative ? naturalWidth + iconGap : inset
}
function cursorVisible(keyboardMode, cursorActive, count) {
  return !!keyboardMode && !!cursorActive && count > 0
}
// Widgets whose presentation changes on a clock rather than on an event; an
// autohidden bar should not slide out for them every minute.
var quietWidgets = ["omarchy.clock"]
function quietActivity(id) { return quietWidgets.indexOf(String(id || "")) >= 0 }
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
