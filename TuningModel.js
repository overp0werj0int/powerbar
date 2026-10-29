// The Tuning page's numbers (docs/behavior/preferences.md PREFS-132): the
// development numbers behind the look, in sections (one strip each), with
// their ranges and defaults, and reading them back from the cache file while
// the page is on (`powerbarTuning`, integration.md INTEG-155). The defaults
// are the look that ships. Tuning.qml keeps the values, TuningEditor.qml
// moves them, and whatever draws with one reads `Tuning.values.<key>`.
//
// Adding a number: one entry here, one binding where it is read. Lengths
// are page px; grain is thousandths of a bump per px; strengths are percent.
// A `toggle` is a switch row instead of a fader, 1 on and 0 off. Every value
// is a whole number in its range; keys are unique across sections.

var SECTIONS = [
  {
    id: "lift",
    title: "Lift",
    caption: "What rises with the cursor on the desks (PREFS-104). Widgets on Layout and Groups and the cards rise either way.",
    params: [
      { key: "controlLift", label: "Controls rise", caption: "Rows, groups of pick rows, faders and rows of chips. Off, they keep their fill and ring and stay down.", unit: "", min: 0, max: 1, value: 1, toggle: true }
    ]
  },
  {
    id: "tear",
    title: "Tear",
    caption: "Where the camera's cap tears above the plates, and how the edge wanders (PREFS-24).",
    params: [
      { key: "gapAbove", label: "Above the plates", unit: "px", min: 0, max: 40, value: 35 },
      { key: "tearDepth", label: "Tear depth", unit: "px", min: 2, max: 40, value: 8 },
      { key: "grain", label: "Grain", unit: "‰", min: 5, max: 80, value: 31 },
      { key: "octaves", label: "Detail", unit: "octaves", min: 1, max: 5, value: 3 },
      { key: "seed", label: "Seed", unit: "", min: 1, max: 60, value: 24 }
    ]
  },
  {
    id: "fringe",
    title: "Fringe",
    caption: "The paper's lighter core showing along the tear.",
    params: [
      { key: "fringeWidth", label: "Fringe width", unit: "px", min: 0, max: 12, value: 12 },
      { key: "fringeStrength", label: "Fringe strength", unit: "%", min: 0, max: 100, value: 13 },
      { key: "fringeSeed", label: "Fringe seed", unit: "", min: 1, max: 60, value: 12 }
    ]
  },
  {
    id: "shade",
    title: "Shade",
    caption: "The soft dark fall under the tear, over the plates and the gaps.",
    params: [
      { key: "shadeBlur", label: "Shade blur", unit: "px", min: 0, max: 60, value: 4 },
      { key: "shadeDrop", label: "Shade drop", unit: "px", min: 0, max: 80, value: 7 },
      { key: "shadeStrength", label: "Shade strength", unit: "%", min: 0, max: 100, value: 16 },
      { key: "shadeSpread", label: "Shade spread", unit: "px", min: 0, max: 80, value: 0 }
    ]
  }
]

var PARAMS = SECTIONS.reduce(function(all, s) { return all.concat(s.params) }, [])

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

if (typeof module !== "undefined") module.exports = { SECTIONS, PARAMS, param, defaults, clamp, parse, serialize }
