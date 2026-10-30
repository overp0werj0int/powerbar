.import "AppearanceModel.js" as AppearanceModel
.import "BarModel.js" as BarModel
.import "GroupsModel.js" as GroupsModel
.import "ManagedModel.js" as ManagedModel
.import "SectionsModel.js" as SectionsModel

// What Powerbar writes back into a bar config the host hands it, decided once
// as a plan of plain values (heal) and saved as one queued edit (apply). The
// config store runs a queued edit again on every config the host delivers
// until it is written, so the plan holds everything the heal invents (new
// instance ids), and apply changes only what is still as the plan found it:
// run twice, or on a newer config, it gives the same result and undoes no
// other writer's change. A healed config delivered back heals to null.
//
// A plan:
//   entries: [{ zone, index, id, was, keys }]: the entry at layout[zone][index]
//     of widget `id` takes `keys` (powerbar* keys); `was` holds what it had in
//     those keys, its instance among them, when the heal was decided. Keys
//     another writer dropped come back (INTEG-148), a legacy config's widgets
//     not from Omarchy stay On demand (INTEG-113), and every entry has a
//     unique instance (INTEG-114).
//   marker: bar.powerbarVisibilityDefault "shown" (INTEG-113).
//   offer: bar.powerbarShortcutOffer on a config Powerbar never ran on (KEYS-84).
//   appearance: the theme earlier versions' flat keys move into (LOOK-48), or "".
//   themes: the themes whose values stay (LOOK-55), from a fresh listing, or null.
//   members: group members whose widget is gone (INTEG-40).
//   zoneLayouts: the zone modes' arrangements leave, their copy saved (ZONE-92).

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}
function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }
function copy(value) { return value === undefined ? undefined : JSON.parse(JSON.stringify(value)) }

// ctx: previous: the layout the bar showed before (where lost keys come back
// from); theme: the current theme's name; thirdParty(entry): not from Omarchy;
// newInstance(): a new instance key; installedThemes: the installed themes,
// only from a listing just read; zoneModesSaved: the zone modes' copy is saved.
// → a plan, or null when there is nothing to write.
function heal(bar, ctx) {
  if (!isPlainObject(bar)) return null
  var c = ctx || {}
  var healed = copy(bar)
  var plan = { entries: [], marker: false, offer: false, appearance: "", themes: null, members: [], zoneLayouts: !!c.zoneModesSaved }
  if (isPlainObject(healed.layout)) {
    BarModel.applyLostKeys(healed, BarModel.lostKeys(c.previous, healed.layout))
    // Before the marker and the ids, which would make a fresh config look
    // like one Powerbar ran on.
    plan.offer = !ManagedModel.powerbarHasRun(healed)
    plan.marker = ManagedModel.healVisibility(healed, c.thirdParty)
    assignInstances(healed.layout, c.newInstance)
    plan.entries = entrySteps(bar.layout, healed.layout)
  }
  if (c.theme && AppearanceModel.migrate(healed, c.theme)) plan.appearance = c.theme
  if (Array.isArray(c.installedThemes) && c.installedThemes.length) {
    var keep = c.installedThemes.concat(c.theme ? [c.theme] : [])
    if (AppearanceModel.hasStaleThemes(healed, keep)) plan.themes = keep
  }
  plan.members = GroupsModel.danglingMembers(healed)
  var empty = !plan.entries.length && !plan.marker && !plan.offer && !plan.appearance && !plan.themes
    && !plan.members.length && !plan.zoneLayouts
  return empty ? null : plan
}

// Every entry an instance of its own, the tray section's too; a bare id
// becomes an entry.
function assignInstances(layout, newInstance) {
  var used = {}
  SectionsModel.sections.forEach(function(zone) {
    var entries = layout[zone]
    if (!Array.isArray(entries)) return
    for (var i = 0; i < entries.length; i++) {
      var entry = typeof entries[i] === "string" ? { id: entries[i] } : entries[i]
      if (!isPlainObject(entry)) continue
      if (!entry.powerbarInstance || used[entry.powerbarInstance]) entry.powerbarInstance = newInstance()
      used[entry.powerbarInstance] = true
      entries[i] = entry
    }
  })
}

// The powerbar* keys each entry gained or changed from `before` to `healed`,
// which hold the same entries in the same places.
function entrySteps(before, healed) {
  var steps = []
  SectionsModel.sections.forEach(function(zone) {
    var was = Array.isArray(before[zone]) ? before[zone] : [], now = Array.isArray(healed[zone]) ? healed[zone] : []
    for (var i = 0; i < now.length; i++) {
      if (!isPlainObject(now[i])) continue
      var old = isPlainObject(was[i]) ? was[i] : {}, step = { zone: zone, index: i, id: BarModel.entryId(was[i]), was: {}, keys: {} }
      var changed = false
      for (var key in now[i]) {
        if (key.indexOf("powerbar") !== 0 || same(now[i][key], old[key])) continue
        step.keys[key] = copy(now[i][key])
        if (key in old) step.was[key] = copy(old[key])
        changed = true
      }
      if (!changed) continue
      if ("powerbarInstance" in old) step.was.powerbarInstance = copy(old.powerbarInstance)
      steps.push(step)
    }
  })
  return steps
}

// The plan on a bar config, in place.
function apply(bar, plan) {
  if (!isPlainObject(bar) || !plan) return
  if (isPlainObject(bar.layout)) plan.entries.forEach(function(step) { applyEntry(bar.layout, step) })
  if (plan.offer) bar.powerbarShortcutOffer = true
  if (plan.marker) bar.powerbarVisibilityDefault = "shown"
  if (plan.appearance) AppearanceModel.migrate(bar, plan.appearance)
  if (plan.themes) AppearanceModel.pruneThemes(bar, plan.themes)
  if (plan.members.length) GroupsModel.pruneMembers(bar, plan.members)
  if (plan.zoneLayouts) delete bar.powerbarZoneLayouts
}

// Only an entry still of that widget with the instance it had; each key only
// while it still holds what it had (a value another writer set since stays).
function applyEntry(layout, step) {
  var entries = layout[step.zone]
  if (!Array.isArray(entries) || !(step.index >= 0 && step.index < entries.length)) return
  var entry = entries[step.index]
  if (BarModel.entryId(entry) !== step.id) return
  var current = isPlainObject(entry) ? entry : { id: entry }
  if (!same(current.powerbarInstance, step.was.powerbarInstance)) return
  for (var key in step.keys) if (same(current[key], step.was[key])) current[key] = copy(step.keys[key])
  entries[step.index] = current
}
