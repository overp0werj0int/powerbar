// What each numeric setting may be, in the units shell.json stores (spacing
// units before the theme's spacing scale; percentages for opacities). The bar
// clamps to these and Preferences' sliders offer exactly these, so a slider
// can never show a value the bar does not draw.
//   spacing        Space between widgets. Past half a glyph cell, icons stop
//                  reading as one bar and start reading as separate buttons.
//   borderWidth    Island border. Off is the Borders switch, so the slider
//                  starts at a hairline; past 3 the border outweighs the glyphs.
//   rounding       Island and drawer corners. The top is computed: half the
//                  bar's thickness is a full pill, and more draws the same.
//   shadowSize     Shadow blur. Under 2 the shadow hides under its surface;
//                  past 24 it smears into a haze wider than the bar.
//   shadowOpacity  Shadow strength. Under 5% it cannot be seen with Shadow on.
var ranges = {
  spacing: { min: 0, max: 16, step: 1, fallback: 0 },
  borderWidth: { min: 0.5, max: 3, step: 0.5, fallback: 1 },
  rounding: { min: 0, step: 1 },
  backgroundOpacity: { min: 0, max: 100, step: 5, fallback: 100 },
  shadowSize: { min: 2, max: 24, step: 1, fallback: 16 },
  shadowOpacity: { min: 5, max: 60, step: 5, fallback: 30 }
}
function clampTo(range, value, fallback) {
  var n = typeof value === "number" && isFinite(value) ? value
    : fallback !== undefined ? fallback : range.fallback
  return Math.max(range.min, Math.min(range.max !== undefined ? range.max : Infinity, n))
}
// Rounding that reads as a full pill on a bar `barSize` px thick, in stored
// units: the slider's top end.
function roundingMax(barSize, spacingScale) {
  var scale = spacingScale > 0 ? spacingScale : 1
  return Math.max(1, Math.ceil((Number(barSize) || 0) / 2 / scale))
}

// Resolve old per-surface settings once, using the main bar as the baseline.
function effects(config) {
  var c = config || {}
  function value(key, fallback) {
    if (c["powerbar" + key] !== undefined) return c["powerbar" + key]
    return c["powerbarMain" + key] !== undefined ? c["powerbarMain" + key] : fallback
  }
  function number(key, range, fallback) {
    return clampTo(range, value(key, undefined), fallback)
  }
  var opacity = typeof c.powerbarBackgroundOpacity === "number"
    ? number("BackgroundOpacity", ranges.backgroundOpacity)
    : c.powerbarMainBlur === true ? number("BackgroundOpacity", ranges.backgroundOpacity, 80) : 100
  return { blur: value("Blur", false) === true, backgroundOpacity: opacity / 100,
    shadow: value("Shadow", false) === true, shadowSize: number("ShadowSize", ranges.shadowSize),
    shadowOpacity: number("ShadowOpacity", ranges.shadowOpacity) / 100,
    readableOverlay: c.powerbarReadableOverlay !== false }
}
// Text and icons on Powerbar's surfaces: the theme's colours, or one fixed
// light or dark colour for every surface. Nothing guesses from the wallpaper:
// a window or a busy wallpaper can sit behind a see-through bar at any time.
// Light and dark are the theme's own pair (bar text and background), sorted
// by luminance, so the choice keeps the theme's hues.
//
// A choice belongs to the theme it was made in: powerbarForeground maps theme
// names to "light" or "dark", and every other theme uses its own colours. A
// choice made for a light theme would otherwise follow you into a dark one,
// where its dark colour is the bar's own background.
var foregrounds = ["theme", "light", "dark"]
function isMap(v) { return !!v && typeof v === "object" && !Array.isArray(v) }
function foreground(config, theme) {
  var v = config && config.powerbarForeground
  // A bare string predates per-theme choices and names no theme: it no longer
  // applies anywhere.
  var picked = isMap(v) && theme ? v[theme] : undefined
  return picked === "light" || picked === "dark" ? picked : "theme"
}
// Records the choice for one theme; "theme" clears it. Drops the key when no
// theme keeps a choice.
function setForeground(bar, theme, value) {
  if (!bar) return
  var map = {}
  if (isMap(bar.powerbarForeground)) for (var k in bar.powerbarForeground) map[k] = bar.powerbarForeground[k]
  if (theme) {
    if (value === "light" || value === "dark") map[theme] = value
    else delete map[theme]
  }
  if (Object.keys(map).length) bar.powerbarForeground = map
  else delete bar.powerbarForeground
}
function luminance(c) {
  function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}
function textPair(a, b) {
  return luminance(a) >= luminance(b) ? { light: a, dark: b } : { light: b, dark: a }
}
// Surfaces laid over windows (drawers, an autohiding bar) keep text readable:
// without blur they stay at least this opaque, unless the user opts out.
var readableOpacity = 0.88
function overlayOpacity(effects) {
  var e = effects || {}
  var opacity = typeof e.backgroundOpacity === "number" ? e.backgroundOpacity : 1
  return e.readableOverlay !== false && !e.blur ? Math.max(opacity, readableOpacity) : opacity
}
// The settings each Preferences tile returns to the theme's values, with the
// legacy per-surface keys the bar still reads as fallbacks.
function legacyKeys(names) {
  var keys = []
  names.forEach(function(name) {
    ["powerbar", "powerbarMain", "powerbarExtended"].forEach(function(prefix) { keys.push(prefix + name) })
  })
  return keys
}
var tileKeys = {
  shape: ["powerbarIslandBorders", "powerbarIslandBorderWidth", "powerbarIslandRounding"],
  surface: legacyKeys(["Blur", "BackgroundOpacity", "ReadableOverlay"]).concat(["powerbarForeground"]),
  shadow: legacyKeys(["Shadow", "ShadowSize", "ShadowOpacity"])
}
// Whether a tile differs from the theme: one of its keys is set. Text and
// icons count only when the current theme `theme` has a choice.
function customized(config, tile, theme) {
  var c = config || {}
  return (tileKeys[tile] || []).some(function(key) {
    return key === "powerbarForeground" ? foreground(c, theme) !== "theme" : c[key] !== undefined
  })
}
// Resets one tile, or every tile when none is named. Text and icons go back
// to the theme's colours in the current theme `theme` only; without a theme,
// every theme's choice goes.
function reset(config, tile, theme) {
  (tile ? [tile] : Object.keys(tileKeys)).forEach(function(name) {
    (tileKeys[name] || []).forEach(function(key) {
      if (key === "powerbarForeground" && theme) setForeground(config, theme, "theme")
      else delete config[key]
    })
  })
}
