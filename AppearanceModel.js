// Resolve old per-surface settings once, using the main bar as the baseline.
function effects(config) {
  var c = config || {}
  function value(key, fallback) {
    if (c["powerbar" + key] !== undefined) return c["powerbar" + key]
    return c["powerbarMain" + key] !== undefined ? c["powerbarMain" + key] : fallback
  }
  function number(key, fallback, max) {
    var n = value(key, fallback)
    return typeof n === "number" && isFinite(n) ? Math.max(0, Math.min(max, n)) : fallback
  }
  var opacity = typeof c.powerbarBackgroundOpacity === "number"
    ? number("BackgroundOpacity", 100, 100)
    : c.powerbarMainBlur === true ? number("BackgroundOpacity", 80, 100) : 100
  return { blur: value("Blur", false) === true, backgroundOpacity: opacity / 100,
    shadow: value("Shadow", false) === true, shadowSize: number("ShadowSize", 16, 32),
    shadowOpacity: number("ShadowOpacity", 30, 45) / 100,
    readableOverlay: c.powerbarReadableOverlay !== false }
}
// Surfaces laid over windows (drawers, an autohiding bar) keep text readable:
// without blur they stay at least this opaque, unless the user opts out.
var readableOpacity = 0.88
function overlayOpacity(effects) {
  var e = effects || {}
  var opacity = typeof e.backgroundOpacity === "number" ? e.backgroundOpacity : 1
  return e.readableOverlay !== false && !e.blur ? Math.max(opacity, readableOpacity) : opacity
}
function reset(config) {
  ["Blur", "BackgroundOpacity", "Shadow", "ShadowSize", "ShadowOpacity", "ReadableOverlay"].forEach(function(key) {
    ["powerbar", "powerbarMain", "powerbarExtended"].forEach(function(prefix) { delete config[prefix + key] })
  });
  ["Borders", "BorderWidth", "Rounding"].forEach(function(key) { delete config["powerbarIsland" + key] })
}
