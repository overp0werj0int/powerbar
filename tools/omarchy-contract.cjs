#!/usr/bin/env node
// omarchy-contract.cjs: does the installed Omarchy still provide everything
// Powerbar relies on? Run after every Omarchy update (tools/validate.sh runs it).
//   node tools/omarchy-contract.cjs [OMARCHY_PATH]   (default $OMARCHY_PATH, else /usr/share/omarchy)
// Each failure names the Omarchy file, the exact text that went missing and
// what it breaks in Powerbar, so a fix starts from the right place:
//   contract drift: shell/shell.qml: shell.bar.summonBarWidget(id)
//       breaks: `omarchy-shell shell summon` does nothing
// Three kinds of check:
//   1. CONTRACT: literal lines in Omarchy's files that Powerbar depends on (the
//      host handing the bar its config, the shell facade, the widget kit
//      properties Powerbar reads, commands, state files, bind forms). When one
//      is missing, read what replaced it in that file and adapt Powerbar, then
//      update the line here.
//   2. Theme tokens: every Style.* and Commons.Color.* path Powerbar's own
//      files use, found automatically, must be declared in Omarchy's Commons.
//   3. qs.Commons singletons and qs.Ui types Powerbar uses must be registered.
// Not covered: Quickshell's own API (IpcHandler, FileView, PopupWindow...)
// and Hyprland's (hyprctl repl, hl.is_key_down, hl.define_submap); the QML
// tests, startup probe and tools/smoke.sh exercise those.
"use strict"
const fs = require("fs")
const path = require("path")

const CONTRACT = [
  ["shell/shell.qml", "if (\"shell\" in target) target.shell = shell.pluginShellFor(manifest)", "no shell facade: config writes and inline widget updates stop"],
  ["shell/shell.qml", "if (\"manifest\" in target) target.manifest = shell.publicPluginManifest(manifest)", "`status`/`build` lose the id and version"],
  ["shell/shell.qml", "if (\"barWidgetRegistry\" in target) target.barWidgetRegistry = shell.pluginBarWidgetRegistryFor(manifest)", "no widget resolves"],
  ["shell/shell.qml", "if (\"barConfig\" in target) target.barConfig = shell.barConfigFor(manifest)", "bar config never delivered"],
  ["shell/shell.qml", "if (\"omarchyPath\" in target) target.omarchyPath = shell.omarchyPath", "omarchyPath only from the environment"],
  ["shell/shell.qml", "bar.barConfig = shell.barConfigFor(shell.activeBarManifest)", "shell.json edits stop reaching the bar live"],
  ["shell/shell.qml", "var configured = Util.canonicalWidgetId(String(config.id || \"\"))", "bar.id stops selecting Powerbar; config writes refused"],
  ["shell/shell.qml", "&& manifest.kinds.indexOf(\"bar\") !== -1", "Powerbar no longer offered as a bar"],
  ["shell/services/PluginRegistry.qml", "if (manifest.schemaVersion !== 1) {", "manifest.json rejected"],
  ["shell/services/PluginShellApi.qml", "function mutateShellConfig(mutator) {", "every config write fails (\"Could not save\")"],
  ["shell/shell.qml", "var scoped = { bar: JSON.parse(JSON.stringify(config.bar || {})) }", "ConfigStore mutators expect config.bar only"],
  ["shell/shell.qml", "return hasCurrentBarCapabilities() ? shell.mutatePluginBarConfig(mutator) : false", "writes need the bar kind; else reported failed"],
  ["shell/services/PluginShellApi.qml", "function pluginShellForBarEntry(ownerId, moduleName) {", "third-party widgets lose summon/toggle/updateEntryInline"],
  ["shell/shell.qml", "? shell.pluginShellForBarEntry(cacheKey + \":\" + ownerId, moduleName) : null", "third-party widget shell facade (Bar.qml pluginShellFor)"],
  ["shell/services/PluginShellApi.qml", "function updateEntryInline(id, settings) {", "clock/power/tailscale inline state stops saving"],
  ["shell/shell.qml", "return shell.updateEntryInline(requestedId, settings)", "inline widget settings stop saving"],
  ["shell/services/PluginBarWidgetRegistryApi.qml", "property var widgets: ({})", "slots get no component; WidgetRepair never fires"],
  ["shell/services/PluginBarWidgetRegistryApi.qml", "property int revision: 0", "Preferences stops refreshing on rescan"],
  ["shell/services/PluginBarWidgetRegistryApi.qml", "function metadataFor(id) {", "first-party detection and widget names"],
  ["shell/shell.qml", "widgets: shell.publicBarWidgetSnapshot(),", "the stale copy WidgetRepair works around"],
  ["shell/shell.qml", "widgetApi.widgets = shell.publicBarWidgetSnapshot()", "WidgetRepair's refresh trigger"],
  ["shell/shell.qml", "metadata: JSON.parse(JSON.stringify(entry.metadata || {}))", "stale detection needs the {component, metadata} shape"],
  ["shell/shell.qml", "sourceDir: manifest.__sourceDir || \"\",", "WidgetRepair can't find a plugin's folder"],
  ["shell/shell.qml", "firstParty: !!manifest.__isFirstParty", "first-party widgets get the facade instead of the bar"],
  ["shell/shell.qml", "displayName: meta.displayName || manifest.name,", "widget names fall back to ids"],
  ["shell/services/PluginRegistry.qml", "var ep = manifest.entryPoints ? manifest.entryPoints[kind] : null", "WidgetRepair can't resolve entry QML (BarModel.js)"],
  ["shell/services/PluginRegistry.qml", "if (value.indexOf(\"..\") !== -1) return false", "BarModel.js isSafeEntryPoint copy drifts"],
  ["shell/services/PluginRegistry.qml", "-name manifest.json -o -name '*.manifest.json'", "WidgetRepair misses sibling manifests"],
  ["shell/shell.qml", "api.barHidden = Qt.binding(function() { return shell.bar ? shell.bar.barHidden === true : false })", "bar-state facade reads Powerbar's barHidden"],
  ["shell/shell.qml", "api.barSize = Qt.binding(function() { return shell.bar ? Math.max(0, shell.bar.barSize || 0) : 0 })", "bar-state facade reads Powerbar's barSize"],
  ["shell/shell.qml", "api.fontFamily = Qt.binding(function() { return shell.bar ? String(shell.bar.fontFamily || \"\") : \"\" })", "bar-state facade reads Powerbar's fontFamily"],
  ["shell/shell.qml", "api.position = Qt.binding(function() { return shell.bar ? String(shell.bar.position || \"top\") : \"top\" })", "bar-state facade reads Powerbar's position"],
  ["shell/plugins/notifications/Service.qml", "shell.bar && !shell.bar.barHidden ? Math.max(0, shell.bar.barSize)", "notifications offset from the bar"],
  ["shell/shell.qml", "shell.bar.summonBarWidget(id)", "`omarchy-shell shell summon` does nothing"],
  ["shell/shell.qml", "shell.bar.hideBarWidget(id)", "hide/toggle can't close a widget panel"],
  ["shell/shell.qml", "shell.bar.isBarWidgetOpen(id)", "toggle always opens"],
  ["shell/shell.qml", "if (m.kinds.indexOf(\"bar-widget\") === -1) return false", "summon routing through the bar"],
  ["shell/shell.qml", "shell.bar.toggleTransparency()", "toggleBarTransparency answers no-bar"],
  ["shell/shell.qml", "shell.bar.debugBarGeometry()", "debug geometry IPC answers []"],
  ["shell/shell.qml", "shell.bar.panelWidgetIdAt(section, index)", "Super+Ctrl+1..9 panel keys stop"],
  ["shell/shell.qml", "function togglePanelAt(section: string, index: string): string {", "Super+Ctrl+1..9 panel keys stop"],
  ["shell/plugins/bar/Bar.qml", "if (\"bar\" in target) target.bar =", "the widget injection protocol Powerbar mirrors"],
  ["shell/Ui/qmldir", "PluginBarApi 1.0 PluginBarApi.qml", "third-party widgets get no bar"],
  ["shell/Ui/PluginBarApi.qml", "required property string moduleName", "facade createObject fails on a new required property"],
  ["shell/Ui/PluginBarApi.qml", "property var _switchPanelFrom: null", "facade callbacks Powerbar fills"],
  ["shell/Ui/PluginBarApi.qml", "property var _moduleWidgets: null", "facade callbacks Powerbar fills"],
  ["shell/Ui/PluginBarApi.qml", "property var _targetBelongsToWindow: null", "facade callbacks Powerbar fills"],
  ["shell/Ui/PluginBarApi.qml", "property var _setCenterHoverRevealSuppressed: null", "facade callbacks Powerbar fills"],
  ["shell/Ui/PluginBarApi.qml", "property bool _centerHoverRevealSuppressed: false", "facade binding target"],
  ["shell/Ui/PluginBarApi.qml", "readonly property var foreignPopoutMarker: ({ foreign: true })", "foreign popouts not signalled (PluginApiSync)"],
  ["shell/Ui/PluginBarApi.qml", "property var clickTargets: []", "click targets not synced (PluginApiSync)"],
  ["shell/Ui/PluginBarApi.qml", "property var layoutConfig: ({})", "layout not synced (PluginApiSync)"],
  ["shell/Ui/WidgetButton.qml", "registeredBar.registerClickTarget(root)", "buttons stop registering click targets"],
  ["shell/Ui/WidgetButton.qml", "property color foreground: bar ? bar.barForeground : Color.foreground", "widget colours (barForeground)"],
  ["shell/Ui/BarWidget.qml", "? bar.moduleWidgets(moduleName) : [root]", "multi-monitor widget sync"],
  ["shell/Ui/Panel.qml", "return bar.switchPanelFrom(root, direction)", "left/right panel switching"],
  ["shell/plugins/panels/clock/Panel.qml", "root.bar.setCenterHoverRevealSuppressed(value)", "centre reveal fights an open clock panel"],
  ["shell/plugins/panels/clock/Panel.qml", "root.bar.shell.updateEntryInline(root.moduleName, entry)", "clock inline state stops saving"],
  ["shell/Ui/KeyboardPanel.qml", "root.bar.targetBelongsToWindow(target, root.anchorWindow)", "outside-click detection"],
  ["shell/Ui/KeyboardPanel.qml", "bar.requestPopout(coordinatorKey)", "one popout at a time"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property var coordinatorKey: owner || root", "slot panelOpen (highlight, reveal, keyboard mode)"],
  ["shell/Ui/PopupCard.qml", "if (open) bar.requestPopout(coordinatorKey)", "one popout at a time"],
  ["shell/Ui/Panel.qml", "function closeForPopoutSwitch() {", "panel switches animate as full closes"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property point cardOrigin: {", "popup gap compensation; panels at the wrong distance"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property real barH: anchorWindow ? anchorWindow.height : 0", "popup gap compensation"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null", "popup gap compensation"],
  ["shell/Ui/KeyboardPanel.qml", "property int gap: Style.gapsOut", "panel offset (Powerbar binds gap)"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property string barPos: bar ? bar.position : \"top\"", "popupStatus"],
  ["shell/Ui/KeyboardPanel.qml", "readonly property real screenW: screen ? screen.width : 0", "popupStatus"],
  ["shell/Ui/KeyboardPanel.qml", "property int contentWidth: Style.space(280)", "popupStatus"],
  ["shell/Ui/KeyboardPanel.qml", "property bool open: false", "popupStatus, panel state"],
  ["shell/plugins/panels/clock/BarWidget.qml", "readonly property bool opened:", "summon/hide/isOpen find no widget (findPanelWidget)"],
  ["shell/Ui/WidgetButton.qml", "readonly property real labelWidth:", "glyph capture, highlight sizing"],
  ["shell/Ui/WidgetButton.qml", "property real textRotation: 0", "glyph capture, highlight sizing"],
  ["shell/Ui/WidgetButton.qml", "readonly property real scaledVerticalPadding:", "vertical highlight sizing"],
  ["shell/Ui/BarIconButton.qml", "readonly property real glyphPaintedWidth:", "icon buttons not seen as kit buttons"],
  ["shell/Ui/BarIconButton.qml", "readonly property int glyphFontSize:", "glyph size lost"],
  ["shell/Ui/BarIconButton.qml", "property real opticalSize:", "circle highlight size"],
  ["shell/Ui/WidgetButton.qml", "signal pressed(int button)", "group and custom buttons go dead"],
  ["shell/Ui/WidgetButton.qml", "property bool keepSpace: false", "custom command modules fail to load"],
  ["shell/Ui/BorderSurface.qml", "property var borderSpec: Border.none()", "islands and overlays fail to load"],
  ["shell/Ui/ScreenMoveRemap.qml", "required property var window", "bar window fails to build"],
  ["shell/Ui/ScreenMoveRemap.qml", "property bool remapping: false", "monitor-move remap"],
  ["shell/Ui/ButtonGroup.qml", "signal changed(string value)", "Preferences choices go dead"],
  ["shell/Ui/Dropdown.qml", "property bool showLabel: true", "Preferences dropdowns fail to load"],
  ["shell/Ui/TextField.qml", "property real verticalPadding: Style.spacing.inputPaddingY", "group text fields fail to load"],
  ["shell/Ui/Toggle.qml", "property real titleSize: Style.font.subtitle", "Preferences toggles fail to load"],
  ["shell/Ui/ToggleSwitch.qml", "property bool cursorRing: interactive", "tile switches fail to load"],
  ["shell/Ui/ToggleSwitch.qml", "signal toggled()", "tile switches go dead"],
  ["shell/Commons/Util.qml", "function canonicalWidgetId(id) {", "widget id matching"],
  ["shell/Commons/Util.qml", "function normalizeLayout(layout) {", "layout not parsed"],
  ["shell/Commons/Util.qml", "function isPlainObject(value) {", "config guards"],
  ["shell/Commons/Util.qml", "function parseModuleJson(raw) {", "custom command modules show nothing"],
  ["shell/Commons/Util.qml", "function fileUrl(path) {", "custom QML modules fail to load"],
  ["shell/Commons/Util.qml", "function clamp(value, min, max) {", "bar-move maths"],
  ["shell/Commons/Util.qml", "Quickshell.execDetached([\"bash\", \"-lc\", command])", "bar.run: toggles, custom onClick"],
  ["shell/Commons/Border.qml", "function surfaceSpec(section, token, fallbackColor, fallbackWidth, alphaKey) {", "island and tooltip borders"],
  ["shell/Commons/Border.qml", "function controlSpec(state, foreground, accent, urgent) {", "focus rings"],
  ["shell/Commons/Border.qml", "function flat(color, width) {", "outlines"],
  ["shell/Commons/Border.qml", "function none() {", "flat style"],
  ["shell/Commons/Border.qml", "function top(spec) { return spec && spec.widths ? spec.widths.top : 0 }", "`settings` border width"],
  ["bin/omarchy-shell", "qs ipc -n -p \"$OMARCHY_PATH/shell\" call -- \"$@\"", "the whole `omarchy-shell powerbar` CLI"],
  ["bin/omarchy-shell", "if [[ $1 == \"shell\" && ( $2 == \"summon\" || $2 == \"toggle\" ) ]] && (( $# == 3 )); then", "widget shortcuts would need the {} argument"],
  ["shell/shell.qml", "function toggle(id: string, payloadJson: string): void {", "widget shortcuts do nothing"],
  ["bin/omarchy-toggle-bar", "omarchy-toggle bar-off \"${1:-toggle}\"", "CLI show/hide"],
  ["bin/omarchy-toggle-bar", "omarchy-shell -q omarchy.bar syncHidden", "the bar can stay off-screen"],
  ["bin/omarchy-toggle", "FLAG=\"$HOME/.local/state/omarchy/toggles/$FLAG_NAME\"", "barOffFlag never changes"],
  ["bin/omarchy-bar-text-color", "background_color=${4:-}", "transparent-bar text colour"],
  ["bin/omarchy-bar", "commit \"$NORMALIZE | .bar.transparent = (.bar.transparent != true)\"", "the bar.transparent key moved"],
  ["bin/omarchy-bar", "commit \"$NORMALIZE | .bar.position = \\$position\" --arg position \"$position\"", "the bar.position key moved"],
  ["bin/omarchy-bar", "commit \"$NORMALIZE | .bar.id = \\$plugin\" --arg plugin \"$plugin\"", "how Powerbar becomes the active bar"],
  ["bin/omarchy-theme-set", "echo \"$THEME_NAME\" >\"$HOME/.local/state/omarchy/current/theme.name\"", "per-theme appearance scopes"],
  ["bin/omarchy-theme-set", "CURRENT_THEME_PATH=\"$HOME/.local/state/omarchy/current/theme\"", "theme powerbar.toml not read"],
  ["bin/omarchy-theme-set", "CURRENT_BACKGROUND_LINK=\"$HOME/.local/state/omarchy/current/background\"", "Preferences wallpaper blank"],
  ["bin/omarchy-theme-set", "OMARCHY_THEMES_PATH=\"$OMARCHY_PATH/themes\"", "theme pruning skipped"],
  ["bin/omarchy-theme-set", "USER_THEMES_PATH=\"$HOME/.config/omarchy/themes\"", "theme pruning skipped"],
  ["shell/plugins/emojis/emojis.json", "[{\"e\":\"", "icon picker emoji tab empty"],
  ["shell/plugins/menu/BarWidget.qml", "fontFamily: \"omarchy\"", "Omarchy logo glyphs (OmarchyIcons.js)"],
  ["default/hypr/bindings/utilities.lua", "o.bind_toggle(\"SUPER + SHIFT + SPACE\", \"Toggle top bar\", \"bar\")", "held-key reveal falls back to any modifier"],
  ["default/hypr/helpers.lua", "o.bind(keys, description, \"omarchy-toggle-\" .. toggle, options)", "held-key reveal falls back to any modifier"],
  ["default/hypr/helpers.lua", "function o.bind(keys, description, dispatcher, options)", "the shortcut block fails to load and rolls back"],
  ["config/hypr/hyprland.lua", "require(\"hypr.bindings\")", "the shortcut block in bindings.lua never loads"],
  ["default/hypr/bindings/utilities.lua", "o.bind(\"SUPER + CTRL + A\", \"Audio\", \"omarchy-shell shell toggle omarchy.audio\")", "Omarchy's widget shortcuts not read"],
  ["default/hypr/bindings/utilities.lua", "for panel = 1, 9 do", "positional panel shortcuts not read"],
  ["default/hypr/bindings/utilities.lua", "\"SUPER + CTRL + code:\" .. tostring(panel + 9),", "positional panel shortcuts not read"],
  ["default/hypr/bindings/utilities.lua", "\"omarchy-shell -q shell togglePanelAt right \" .. panel", "positional panel shortcuts not read"],
  ["default/hypr/bindings/utilities.lua", "hl.dsp.exec_cmd(", "binds written with exec_cmd not parsed"],
  ["config/omarchy/shell.json", "\"centerAnchor\": \"omarchy.clock\",", "default anchor and its key"],
  ["shell/plugins/bar/BarModel.js", "if (settings.exec) return \"command\"", "custom module schema (BarModel.js)"],
  ["shell/plugins/panels/clock/manifest.json", "\"id\": \"omarchy.clock\",", "clock quiet-activity exemption"],
  ["shell/plugins/bar/widgets/Tray.manifest.json", "\"id\": \"omarchy.tray\",", "tray special case"],
  ["shell/plugins/bar/widgets/Indicators.manifest.json", "\"id\": \"omarchy.indicators\",", "centre-reveal special case"],
  ["shell/plugins/bar/Bar.qml", "WlrLayershell.namespace: \"omarchy-bar-drag-ghost\"", "drag ghost namespace Powerbar reuses"],
  ["shell/plugins/bar/Bar.qml", "WlrLayershell.namespace: \"omarchy-bar-move-ghost\"", "move ghost namespace Powerbar reuses"],
  ["shell/plugins/background/Background.qml", "WlrLayershell.namespace: \"omarchy-background\"", "keyboard mode's passive layers (BarKeys)"],
  ["shell/plugins/notifications/Service.qml", "WlrLayershell.namespace: \"omarchy-notifications\"", "keyboard mode's passive layers (BarKeys)"],
  ["shell/plugins/osd/Osd.qml", "WlrLayershell.namespace: \"omarchy-osd\"", "keyboard mode's passive layers (BarKeys)"],
  ["shell/Ui/KeyboardPanel.qml", "WlrLayershell.namespace: \"omarchy-keyboard-panel-dismiss\"", "keyboard mode's passive layers (BarKeys)"],
  ["shell/plugins/lock/Service.qml", "WlrLayershell.namespace: \"omarchy-lock-preview\"", "keyboard mode's passive layers (BarKeys)"],
]

// qs.Ui types Powerbar instantiates, and qs.Commons singletons it imports.
const UI_TYPES = ["BorderSurface", "ButtonGroup", "Dropdown", "PanelSectionHeader", "PluginBarApi",
  "ScreenMoveRemap", "TextField", "Toggle", "ToggleSwitch", "WidgetButton"]
const COMMONS = ["Border", "Color", "Style", "Util"]

const ROOT = path.resolve(__dirname, "..")
const OMARCHY = path.resolve(process.argv[2] || process.env.OMARCHY_PATH || "/usr/share/omarchy")
const failures = []
const files = new Map()
function read(rel) {
  if (!files.has(rel)) {
    try { files.set(rel, fs.readFileSync(path.join(OMARCHY, rel), "utf8")) } catch (e) { files.set(rel, null) }
  }
  return files.get(rel)
}
function drift(rel, what, breaks) { failures.push(`contract drift: ${rel}: ${what}\n    breaks: ${breaks}`) }

// 1. Literal lines.
for (const [rel, literal, breaks] of CONTRACT) {
  const text = read(rel)
  if (text === null) drift(rel, "the file is gone", breaks)
  else if (!text.includes(literal)) drift(rel, literal, breaks)
}

// 2. Theme tokens used by Powerbar's own (loaded) files.
const own = fs.readdirSync(ROOT).filter((f) => /\.(qml|js)$/.test(f)).map((f) => [f, fs.readFileSync(path.join(ROOT, f), "utf8")])
function tokens(pattern) {
  const found = new Map()
  for (const [file, text] of own) for (const m of text.matchAll(pattern)) if (!found.has(m[1])) found.set(m[1], file)
  return found
}
// A segment is declared as a property, a function or a key of an object value.
function declared(text, name) {
  return new RegExp(`(property\\s+[\\w.<>]+\\s+${name}\\b|function\\s+${name}\\s*\\(|\\b${name}\\s*:)`).test(text)
}
function checkTokens(prefix, rel, found) {
  const text = read(rel)
  if (text === null) { drift(rel, "the file is gone", `every ${prefix}* token`); return 0 }
  for (const [token, file] of found) {
    // Colour channels (.r .g .b .a) belong to the colour value, not Omarchy.
    const segments = token.split(".").filter((s) => !/^[rgba]$/.test(s))
    const missing = segments.find((s) => !declared(text, s))
    if (missing) drift(rel, `${prefix}${token} (no "${missing}")`, `used in ${file}`)
  }
  return found.size
}
const styleCount = checkTokens("Style.", "shell/Commons/Style.qml", tokens(/(?<![\w.])Style\.([A-Za-z_][\w.]*\w)/g))
const colorCount = checkTokens("Commons.Color.", "shell/Commons/Color.qml", tokens(/Commons\.Color\.([A-Za-z_][\w.]*\w)/g))

// 3. Registered types.
const commonsDir = read("shell/Commons/qmldir") || ""
for (const name of COMMONS) if (!new RegExp(`^singleton ${name} `, "m").test(commonsDir)) drift("shell/Commons/qmldir", `singleton ${name}`, `import qs.Commons (${name})`)
const uiDir = read("shell/Ui/qmldir") || ""
for (const name of UI_TYPES) if (!new RegExp(`^${name} `, "m").test(uiDir)) drift("shell/Ui/qmldir", `${name} 1.0 ${name}.qml`, `qs.Ui ${name} in Powerbar`)

let version = ""
try { version = fs.readFileSync(path.join(OMARCHY, "version"), "utf8").trim() } catch (e) {}
const total = CONTRACT.length + styleCount + colorCount + COMMONS.length + UI_TYPES.length
if (failures.length) {
  console.log(failures.join("\n"))
  console.log(`omarchy contract: ${failures.length} of ${total} checks drifted (Omarchy ${version || "?"} at ${OMARCHY})`)
  process.exit(1)
}
console.log(`omarchy contract: all ${total} checks hold (Omarchy ${version || "?"} at ${OMARCHY}; ${CONTRACT.length} lines, ${styleCount} Style and ${colorCount} Color tokens)`)
