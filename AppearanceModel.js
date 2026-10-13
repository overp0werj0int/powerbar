// What each numeric setting may be, in the units shell.json stores (spacing
// units before the theme's spacing scale; percentages for opacities). The bar
// clamps to these and Preferences' sliders offer exactly these, so a slider
// can never show a value the bar does not draw.
//   spacing        Space between widgets. Past half a glyph cell, icons stop
//                  reading as one bar and start reading as separate buttons.
//                  The default, 4, spaces icons 27 px apart on the standard
//                  bar: Omarchy's own icon slot (Style.bar.iconSlot).
//   borderWidth    Island border. Off is the Borders switch, so the slider
//                  starts at a hairline; past 3 the border outweighs the glyphs.
//   rounding       Island and drawer corners. The top is computed: half the
//                  bar's thickness is a full pill, and more draws the same.
//   shadowSize     Shadow blur. Under 2 the shadow hides under its surface;
//                  past 24 it smears into a haze wider than the bar.
//   shadowOpacity  Shadow strength. Under 5% it cannot be seen with Shadow on.
var ranges = {
  spacing: { min: 0, max: 16, step: 1, fallback: 4 },
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
// themeOpacity (0–1): the theme's own bar background alpha, used when no
// opacity is set (Omarchy's bar draws its theme background as it is).
function effects(config, themeOpacity) {
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
    : c.powerbarMainBlur === true ? number("BackgroundOpacity", ranges.backgroundOpacity, 80)
    : typeof themeOpacity === "number" ? Math.round(Math.max(0, Math.min(1, themeOpacity)) * 100) : 100
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
// Omarchy's bar background: "opaque", "glassy" or "none" (`omarchy bar
// background`). A config from an Omarchy before background says
// `transparent` instead, which is none or opaque.
var backgrounds = ["opaque", "glassy", "none"]
function barBackground(barConfig) {
  var c = barConfig || {}
  if (backgrounds.indexOf(c.background) >= 0) return c.background
  return c.transparent === true ? "none" : "opaque"
}
// The step a double click on the bar takes: clear, glassy, opaque and around,
// as Omarchy's bar does. An Omarchy without glassy toggles clear and opaque.
function nextBackground(current, glassyOffered) {
  if (!glassyOffered) return current === "none" ? "opaque" : "none"
  return current === "none" ? "glassy" : current === "glassy" ? "opaque" : "none"
}
// A glassy bar is see-through at most this much, as Omarchy's is.
var glassOpacity = 0.35
// The bar's own surface. Omarchy's bar background (`omarchy bar background`,
// the menu's Transparency) clears it or makes it glassy as it does Omarchy's
// bar; an autohiding bar lies over windows and keeps its readable minimum.
// Drawers and overlays keep the surface opacity: Omarchy's setting is the bar's.
function barOpacity(effects, autoHide, transparent, glassy) {
  var e = effects || {}
  var opacity = typeof e.backgroundOpacity === "number" ? e.backgroundOpacity : 1
  var base = transparent === true ? 0 : glassy === true ? Math.min(opacity, glassOpacity) : opacity
  if (!autoHide) return base
  return overlayOpacity({ backgroundOpacity: base, blur: e.blur || glassy === true, readableOverlay: e.readableOverlay })
}
// Whether the bar's text takes the colour Omarchy reads from the wallpaper
// behind a transparent bar: only where nothing is drawn behind it, and only
// while Text and icons follow the theme (a Light or Dark choice wins).
function wallpaperText(surfaceAlpha, choice) {
  return surfaceAlpha === 0 && (choice || "theme") === "theme"
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
// ---- Appearance scopes (docs: README "Theme or yours") ---------------------
// Shape, Surface and Shadow each follow one of three scopes, chosen per theme:
//   "theme"  the theme's values: its powerbar.toml where it ships one, then
//            Omarchy's and Hyprland's (what the bar draws with nothing set)
//   "all"    the user's values shared by every theme
//   "this"   the user's values for the current theme only
// A value is looked up key by key along the chosen scope's chain (this → all
// → theme file), so a layer holds only what was changed. Text and icons are
// stored per theme only: a light or dark choice can't be shared between light
// and dark themes. Stored as bar.powerbarAppearance:
//   { all: { shape: {…}, surface: {…}, shadow: {…} },
//     themes: { "<theme>": { shape: { use: "this", rounding: 10 }, text: "dark" } } }
var scopeTiles = {
  shape: ["rounding", "borders", "borderWidth"],
  surface: ["opacity", "blur"],
  shadow: ["enabled", "softness", "strength"]
}
var scopes = ["theme", "all", "this"]
// The flat keys the bar's drawing code reads, one per value.
var flatKeys = {
  rounding: "powerbarIslandRounding", borders: "powerbarIslandBorders", borderWidth: "powerbarIslandBorderWidth",
  opacity: "powerbarBackgroundOpacity", blur: "powerbarBlur",
  enabled: "powerbarShadow", softness: "powerbarShadowSize", strength: "powerbarShadowOpacity"
}
function filled(o) { return isMap(o) && Object.keys(o).some(function(k) { return k !== "use" && o[k] !== undefined }) }
function pick(o, key) { return isMap(o) && o[key] !== undefined ? o[key] : undefined }

// A theme's powerbar.toml: [shape] rounding, borders, border-width;
// [surface] opacity, blur, text; [shadow] enabled, softness, strength. Every
// key is optional; unknown sections and keys are ignored. Returns
// { shape: {…}, surface: {…}, shadow: {…} } holding only what the file sets.
var lookKeys = {
  shape: { rounding: "rounding", borders: "borders", "border-width": "borderWidth" },
  surface: { opacity: "opacity", blur: "blur", text: "text" },
  shadow: { enabled: "enabled", softness: "softness", strength: "strength" }
}
function parseLook(text) {
  var look = {}, section = ""
  String(text || "").split(/\r?\n/).forEach(function(line) {
    var l = line.replace(/\s+#.*$/, "").replace(/^\s*#.*$/, "").trim()
    if (!l) return
    var head = l.match(/^\[\s*([A-Za-z-]+)\s*\]$/)
    if (head) { section = head[1].toLowerCase(); return }
    var kv = l.match(/^([A-Za-z-]+)\s*=\s*(.+)$/)
    if (!kv || !lookKeys[section]) return
    var key = lookKeys[section][kv[1].toLowerCase()]
    if (!key) return
    var raw = kv[2].trim(), value
    if (raw === "true" || raw === "false") value = raw === "true"
    else if (/^-?\d+(\.\d+)?$/.test(raw)) value = Number(raw)
    else if (/^"[^"]*"$/.test(raw) || /^'[^']*'$/.test(raw)) value = raw.slice(1, -1)
    else return
    if (key === "text" && value !== "light" && value !== "dark" && value !== "theme") return
    if (!look[section]) look[section] = {}
    look[section][key] = value
  })
  return look
}

// The stored appearance, or one built in memory from the flat keys of
// earlier versions (so the bar draws the same before migrate() writes it).
function appearanceOf(bar, theme) {
  var b = bar || {}
  return isMap(b.powerbarAppearance) ? b.powerbarAppearance : fromLegacy(b, theme)
}
var legacyNames = ["IslandRounding", "IslandBorders", "IslandBorderWidth", "Blur", "BackgroundOpacity",
  "Shadow", "ShadowSize", "ShadowOpacity"]
function legacyPresent(bar) {
  var b = bar || {}
  if (b.powerbarForeground !== undefined) return true
  return legacyKeys(legacyNames).some(function(k) { return b[k] !== undefined })
    || b.powerbarMainReadableOverlay !== undefined || b.powerbarExtendedReadableOverlay !== undefined
}
// Earlier versions' values belong to the theme they were made in (`theme`,
// the one on screen when Powerbar updates): its This theme. Every other theme
// starts on Theme; nothing becomes shared unless the user picks All themes.
function fromLegacy(bar, theme) {
  var b = bar || {}, all = {}, themes = {}
  function put(tile, key, value) { if (value !== undefined) { if (!all[tile]) all[tile] = {}; all[tile][key] = value } }
  function legacy(name) {
    return b["powerbar" + name] !== undefined ? b["powerbar" + name] : b["powerbarMain" + name]
  }
  put("shape", "rounding", typeof b.powerbarIslandRounding === "number" ? b.powerbarIslandRounding : undefined)
  put("shape", "borders", typeof b.powerbarIslandBorders === "boolean" ? b.powerbarIslandBorders : undefined)
  put("shape", "borderWidth", typeof b.powerbarIslandBorderWidth === "number" ? b.powerbarIslandBorderWidth : undefined)
  // Opacity as the bar drew it: set explicitly, or 80 for an old blurred main bar.
  var opacity = legacy("BackgroundOpacity")
  put("surface", "opacity", typeof opacity === "number" ? opacity : b.powerbarMainBlur === true ? 80 : undefined)
  var blur = legacy("Blur")
  put("surface", "blur", typeof blur === "boolean" ? blur : undefined)
  ;["Shadow", "ShadowSize", "ShadowOpacity"].forEach(function(name, i) {
    var v = legacy(name)
    put("shadow", ["enabled", "softness", "strength"][i], typeof v === (i ? "number" : "boolean") ? v : undefined)
  })
  if (isMap(b.powerbarForeground)) for (var t in b.powerbarForeground) {
    var c = b.powerbarForeground[t]
    if (c === "light" || c === "dark") themes[t] = { text: c }
  }
  if (theme && Object.keys(all).length) {
    if (!themes[theme]) themes[theme] = {}
    for (var tile in all) {
      themes[theme][tile] = { use: "this" }
      for (var key in all[tile]) themes[theme][tile][key] = all[tile][key]
    }
  }
  return Object.keys(themes).length ? { themes: themes } : {}
}
// Moves earlier versions' flat keys into powerbarAppearance, as the current
// theme's own values (so it looks the same), and removes them, the leftovers
// of per-surface settings included. Waits for the theme to be known. Returns
// whether it changed bar.
function migrate(bar, theme) {
  if (!bar || !theme || !legacyPresent(bar)) return false
  var next = isMap(bar.powerbarAppearance) ? bar.powerbarAppearance : fromLegacy(bar, theme)
  legacyKeys(legacyNames).concat(["powerbarForeground", "powerbarMainReadableOverlay", "powerbarExtendedReadableOverlay"])
    .forEach(function(k) { delete bar[k] })
  if (Object.keys(next).length) bar.powerbarAppearance = next
  else delete bar.powerbarAppearance
  return true
}

// The scope a tile follows in `theme`: the theme's own choice, else "all"
// when shared values exist, else "theme".
function scopeOf(appearance, theme, tile) {
  var a = appearance || {}
  var own = theme && isMap(a.themes) ? pick(a.themes[theme], tile) : undefined
  if (isMap(own) && scopes.indexOf(own.use) >= 0) return own.use
  return defaultScope(a, tile)
}
// The scope a theme without a choice of its own follows.
function defaultScope(appearance, tile) {
  return filled(pick((appearance || {}).all, tile)) ? "all" : "theme"
}
// Everything the bar and Preferences need for `theme`:
//   scopes: tile → scope; values: key → value or undefined (Omarchy's);
//   from: key → "this" | "all" | "file" | "" (Omarchy and Hyprland);
//   text: "theme" | "light" | "dark"; look: tile → the theme file sets some of it.
function resolve(appearance, theme, look) {
  var a = appearance || {}, l = look || {}
  var own = theme && isMap(a.themes) && isMap(a.themes[theme]) ? a.themes[theme] : {}
  var out = { scopes: {}, values: {}, from: {}, text: "theme", look: {} }
  Object.keys(scopeTiles).forEach(function(tile) {
    var scope = scopeOf(a, theme, tile)
    out.scopes[tile] = scope
    out.look[tile] = filled(l[tile])
    var chain = scope === "this" ? [["this", own[tile]], ["all", pick(a.all, tile)], ["file", l[tile]]]
      : scope === "all" ? [["all", pick(a.all, tile)], ["file", l[tile]]] : [["file", l[tile]]]
    scopeTiles[tile].forEach(function(key) {
      out.from[key] = ""
      for (var i = 0; i < chain.length; i++) {
        var v = pick(chain[i][1], key)
        if (v !== undefined) { out.values[key] = v; out.from[key] = chain[i][0]; return }
      }
    })
  })
  var text = own.text !== undefined ? own.text : pick(l.surface, "text")
  out.text = text === "light" || text === "dark" ? text : "theme"
  return out
}
// The bar's config with the resolved appearance in the flat keys its
// drawing code reads (effects, roundingFor, borderFor, foreground).
function flatten(bar, theme, look) {
  var b = bar || {}, flat = {}
  for (var k in b) flat[k] = b[k]
  legacyKeys(legacyNames).concat(["powerbarForeground", "powerbarMainReadableOverlay", "powerbarExtendedReadableOverlay"])
    .forEach(function(key) { delete flat[key] })
  var r = resolve(appearanceOf(b, theme), theme, look)
  for (var key in flatKeys) if (r.values[key] !== undefined) flat[flatKeys[key]] = r.values[key]
  if (theme && r.text !== "theme") { flat.powerbarForeground = {}; flat.powerbarForeground[theme] = r.text }
  return flat
}

// Writes, on the bar section (Preferences passes it inside writeConfig).
function ensureAppearance(bar, theme) {
  if (!isMap(bar.powerbarAppearance)) bar.powerbarAppearance = fromLegacy(bar, theme)
  return bar.powerbarAppearance
}
function prune(a) {
  if (isMap(a.all)) {
    for (var t in a.all) if (!filled(a.all[t])) delete a.all[t]
    if (!Object.keys(a.all).length) delete a.all
  }
  if (isMap(a.themes)) {
    for (var name in a.themes) {
      var th = a.themes[name]
      for (var tile in th) if (isMap(th[tile]) && !Object.keys(th[tile]).length) delete th[tile]
      if (!Object.keys(th).length) delete a.themes[name]
    }
    if (!Object.keys(a.themes).length) delete a.themes
  }
}
function themeEntry(a, theme, tile) {
  if (!isMap(a.themes)) a.themes = {}
  if (!isMap(a.themes[theme])) a.themes[theme] = {}
  if (tile && !isMap(a.themes[theme][tile])) a.themes[theme][tile] = {}
  return tile ? a.themes[theme][tile] : a.themes[theme]
}
// Picks a tile's scope in `theme`. Values stored for other scopes stay.
// The first pick of "all" for a tile shares what the tile shows now
// (`look`: the theme's powerbar.toml, for what it shows from there).
function setScope(bar, theme, tile, scope, look) {
  if (!bar || !theme || !scopeTiles[tile] || scopes.indexOf(scope) < 0) return
  var a = ensureAppearance(bar, theme)
  if (scope === "all" && !filled(pick(a.all, tile))) {
    var shown = resolve(a, theme, look).values, seed = {}
    scopeTiles[tile].forEach(function(key) { if (shown[key] !== undefined) seed[key] = shown[key] })
    if (Object.keys(seed).length) {
      if (!isMap(a.all)) a.all = {}
      a.all[tile] = seed
    }
  }
  var entry = themeEntry(a, theme, tile)
  entry.use = scope
  // The default needs no record: "all" while shared values exist, else "theme".
  var fallback = filled(pick(a.all, tile)) ? "all" : "theme"
  if (scope === fallback && !filled(entry)) delete entry.use
  prune(a)
  if (!Object.keys(a).length) delete bar.powerbarAppearance
}
// Changes one value in the scope the tile follows in `theme` (nothing in
// "theme": its controls are off). undefined removes the value.
function setValue(bar, theme, tile, key, value) {
  if (!bar || scopeTiles[tile] === undefined || scopeTiles[tile].indexOf(key) < 0) return
  if (scopeOf(appearanceOf(bar, theme), theme, tile) === "theme") return
  var a = ensureAppearance(bar, theme)
  var scope = scopeOf(a, theme, tile)
  if (scope === "all") {
    // Recorded so the tile stays on "all" once it holds values of its own.
    var own = theme ? themeEntry(a, theme, tile) : null
    if (own && own.use === undefined) own.use = "all"
    if (!isMap(a.all)) a.all = {}
    if (!isMap(a.all[tile])) a.all[tile] = {}
    if (value === undefined) delete a.all[tile][key]
    else a.all[tile][key] = value
    if (own && own.use === "all" && !filled(own)) delete own.use
  } else {
    var entry = themeEntry(a, theme, tile)
    if (value === undefined) delete entry[key]
    else entry[key] = value
  }
  prune(a)
  if (!Object.keys(a).length) delete bar.powerbarAppearance
}
// Text and icons for `theme`: "theme" removes the choice.
function setText(bar, theme, value) {
  if (!bar || !theme) return
  var a = ensureAppearance(bar, theme)
  var entry = themeEntry(a, theme)
  if (value === "light" || value === "dark") entry.text = value
  else delete entry.text
  prune(a)
  if (!Object.keys(a).length) delete bar.powerbarAppearance
}
// Whether something is kept for a theme not in `installed`.
function hasStaleThemes(bar, installed) {
  var a = bar && bar.powerbarAppearance
  if (!isMap(a) || !isMap(a.themes) || !installed || !installed.length) return false
  return Object.keys(a.themes).some(function(name) { return installed.indexOf(name) < 0 })
}
// Drops what is kept for themes no longer installed. Returns whether it did.
function pruneThemes(bar, installed) {
  var a = bar && bar.powerbarAppearance
  if (!isMap(a) || !isMap(a.themes) || !installed || !installed.length) return false
  var changed = false
  for (var name in a.themes) if (installed.indexOf(name) < 0) { delete a.themes[name]; changed = true }
  if (changed) { prune(a); if (!Object.keys(a).length) delete bar.powerbarAppearance }
  return changed
}
