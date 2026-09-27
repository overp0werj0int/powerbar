// Read live properties from each hosted widget. No polling or copied service.
var badgeCandidates = ["unseenCount", "downCount", "updateCount", "badgeCount", "notificationCount", "unreadCount", "alertCount", "pendingCount", "count"]
var urgentCandidates = ["hasUnseenPerson", "urgent", "isUrgent", "critical", "hasAlert", "severe"]
function propertyName(value, allowNone) {
  var name = String(value || "").trim()
  return name === "" || (allowNone && name === "none") || /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name) ? name : ""
}
function sample(item, badgeOverride, urgentOverride) {
  if (!item || badgeOverride === "none") return { count: 0, urgent: false }
  var names = badgeOverride ? [propertyName(badgeOverride, false)] : badgeCandidates
  var found = "", count = 0
  for (var i = 0; i < names.length; i++) {
    var value = names[i] && item[names[i]]
    if (typeof value === "number" && isFinite(value) && value > 0) {
      found = names[i]; count = Math.min(9999, Math.floor(value)); break
    }
  }
  if (!count) return { count: 0, urgent: false }
  var urgent = false
  if (urgentOverride) {
    var name = propertyName(urgentOverride, false)
    urgent = !!name && item[name] === true
  } else {
    var matched = false
    for (var j = 0; j < urgentCandidates.length; j++) {
      var v = item[urgentCandidates[j]]
      if (typeof v === "boolean") { urgent = v; matched = true; break }
    }
    if (!matched) urgent = found === "downCount" || found === "alertCount"
  }
  return { count: count, urgent: urgent }
}
function aggregate(samples, mode) {
  var count = 0, urgent = false
  ;(samples || []).forEach(function(s) {
    if (!s || !s.count) return
    count += mode === "members" ? 1 : s.count
    urgent = urgent || s.urgent === true
  })
  return { count: count, urgent: urgent }
}
