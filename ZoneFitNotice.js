// Preferences' one-line note when widgets were folded off the bar
// (docs/zone-fit-lab/zone-fit-lab.html, Decisions).
//
// reports: { "<screen name>": { left: n, center: n, right: n } }
// Returns one sentence per screen with folds, sorted by screen name.

var ZONES = [["left", "Left"], ["center", "Center"], ["right", "Right"]]

function zoneList(names) {
  if (names.length < 2) return names.join("")
  return names.slice(0, -1).join(", ") + " and " + names[names.length - 1]
}

function sentence(screen, counts) {
  var total = 0, names = []
  ZONES.forEach(function(z) {
    var n = counts && counts[z[0]] > 0 ? counts[z[0]] : 0
    total += n
    if (n > 0) names.push(z[1])
  })
  if (!total) return ""
  var where = screen ? screen : "this screen"
  var first = total === 1 ? "1 widget doesn't fit on " + where + "."
    : total + " widgets don't fit on " + where + "."
  var second = (total === 1 ? "It's" : "They're") + " in the " + zoneList(names)
    + (names.length > 1 ? " drawers." : " drawer.")
  return first + " " + second
}

function lines(reports) {
  var out = []
  Object.keys(reports || {}).sort().forEach(function(screen) {
    var s = sentence(screen, reports[screen])
    if (s) out.push(s)
  })
  return out
}
