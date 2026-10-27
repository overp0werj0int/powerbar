// The camera's torn cap (docs/behavior/preferences.md PREFS-24, PREFS-132):
// its twelve numbers, their ranges and defaults, and reading them back from
// the cache file. The numbers are being tuned: CameraLook.qml keeps them, the
// Look page's temporary pane moves them, shaders/beam.frag draws them.
//
// Lengths are page px; grain is thousandths of a bump per px; strengths are
// percent. Every value is a whole number in its range.

var PARAMS = [
  { key: "gapAbove", label: "Above the plates", unit: "px", min: 0, max: 40, value: 8 },
  { key: "tearDepth", label: "Tear depth", unit: "px", min: 2, max: 40, value: 14 },
  { key: "grain", label: "Grain", unit: "‰", min: 5, max: 80, value: 25 },
  { key: "octaves", label: "Detail", unit: "octaves", min: 1, max: 5, value: 3 },
  { key: "seed", label: "Seed", unit: "", min: 1, max: 60, value: 7 },
  { key: "fringeSeed", label: "Fringe seed", unit: "", min: 1, max: 60, value: 7 },
  { key: "fringeWidth", label: "Fringe width", unit: "px", min: 0, max: 12, value: 2 },
  { key: "fringeStrength", label: "Fringe strength", unit: "%", min: 0, max: 100, value: 80 },
  { key: "shadeBlur", label: "Shade blur", unit: "px", min: 0, max: 60, value: 18 },
  { key: "shadeDrop", label: "Shade drop", unit: "px", min: 0, max: 80, value: 10 },
  { key: "shadeStrength", label: "Shade strength", unit: "%", min: 0, max: 100, value: 45 },
  { key: "shadeSpread", label: "Shade spread", unit: "px", min: 0, max: 80, value: 0 }
]

function param(key) {
  for (var i = 0; i < PARAMS.length; i++)
    if (PARAMS[i].key === key) return PARAMS[i]
  return null
}

function defaults() {
  var out = {}
  PARAMS.forEach(function(p) { out[p.key] = p.value })
  return out
}

// A value for `key`, whole and in its range; anything that is not a finite
// number is the default.
function clamp(key, v) {
  var p = param(key)
  if (!p) return undefined
  var n = typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" ? Number(v) : NaN
  if (!isFinite(n)) return p.value
  return Math.max(p.min, Math.min(p.max, Math.round(n)))
}

// The cache file's text as a full set of values: a missing, empty or broken
// file, or one that is not an object, is the defaults; a key it lacks or
// holds badly is that key's default; unknown keys are dropped.
function parse(text) {
  var data = null
  try { data = JSON.parse(String(text || "")) } catch (e) { data = null }
  var ok = !!data && typeof data === "object" && !Array.isArray(data)
  var out = {}
  PARAMS.forEach(function(p) { out[p.key] = ok && p.key in data ? clamp(p.key, data[p.key]) : p.value })
  return out
}

function serialize(values) {
  var out = {}
  PARAMS.forEach(function(p) { out[p.key] = clamp(p.key, values ? values[p.key] : undefined) })
  return JSON.stringify(out, null, 1) + "\n"
}

// Where the pane goes on the Look page: its bottom `margin` above the page's
// bottom while that keeps it `gap` under the desk; else with its gaps
// shrunk (compactHeight); else just under the desk, at its right edge.
function panePlace(pageHeight, deskBottom, height, compactHeight, margin, gap) {
  var y = pageHeight - margin - height
  if (y >= deskBottom + gap) return { y: y, compact: false }
  y = pageHeight - margin - compactHeight
  if (y >= deskBottom + gap) return { y: y, compact: true }
  return { y: deskBottom + gap, compact: true }
}

if (typeof module !== "undefined") module.exports = { PARAMS, param, defaults, clamp, parse, serialize, panePlace }
