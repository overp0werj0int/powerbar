# Appearance

Powerbar's appearance covers theme tokens, surface effects (blur, shadow, opacity), islands' looks, tooltips' appearance, the bar's auto-hide visibility, and scope choices (Theme / Everywhere / Just here). Users control these in Preferences > Bar page tiles (Shape, Surface, Shadow, Behavior > Readable over windows, Animations). Everything except text and icons is stored in `bar.powerbarAppearance` in shell.json; earlier versions' flat keys migrate once per theme.

**Sources:** AppearanceModel.js, RenderModel.js, TooltipModel.js, EffectSurface.qml, BarBackdrop.qml, BarFace.qml, TintedImage.qml, WidgetIcon.qml, Bar.qml (grep: autoHide, powerbarAutoHide, powerbarStyle, powerbarLargeBar, powerbarAnimations, theme/appearance/surface/effects/shadow), tests/appearance.test.cjs, tests/render.test.cjs, tests/tooltip-model.test.cjs, README.md "Shadows and backdrop blur" and "Theme or yours" sections, powerbar.toml parsing.

## Surface Effects (Blur, Opacity, Shadow)

- **LOOK-1** Given shell.json has `powerbarBackgroundOpacity` set to a number, when the bar draws, background opacity is clamped to 0–100% (5% steps): 0→0, 50→0.5, 100→1, 140→1, negatives→0 (AppearanceModel.ranges.backgroundOpacity, AppearanceModel.clampTo).

- **LOOK-2** Given shell.json has `powerbarBlur` true or false, when the bar draws with transparent or floating surfaces, blur is on/off (AppearanceModel.effects, used in EffectSurface.qml layer.enabled).

- **LOOK-3** Given shell.json has `powerbarShadow` true/false, when the bar draws, a shadow is painted locally around islands and drawers (EffectSurface.qml RectangularShadow with visible: surface.shadowEnabled).

- **LOOK-4** Given shell.json has `powerbarShadowSize` set to a number, when the bar draws, shadow blur is clamped to 2–24 px (AppearanceModel.ranges.shadowSize): 0→2 px, 16→16 px (default), 30→24 px.

- **LOOK-5** Given shell.json has `powerbarShadowOpacity` set to a number, when the bar draws, shadow strength is clamped to 5–60% (AppearanceModel.ranges.shadowOpacity): 0→0.05, 30→0.3 (default), 70→0.6.

- **LOOK-6** Given shell.json has `powerbarReadableOverlay` unset or false, and drawers or an autohidden bar draws over windows with opacity under 88%, then text remains readable over opaque backgrounds behind it (AppearanceModel.overlayOpacity returns Math.max(opacity, 0.88) when readableOverlay !== false && !blur).

- **LOOK-7** Given shell.json has `powerbarReadableOverlay` false, when a drawer or autohidden bar draws with opacity under 88% and blur is off, readable overlay is disabled: opacity is used as set (AppearanceModel.overlayOpacity, Bar.qml overlaySurfaceColor).

- **LOOK-8** Given blur is on, when a drawer or autohidden bar draws, readable overlay does not raise opacity: the set opacity is used (AppearanceModel.overlayOpacity returns opacity when blur is true).

- **LOOK-9** Given no opacity is set and the theme provides `background.a` (alpha), the bar uses the theme's own background opacity (AppearanceModel.effects with themeOpacity fallback).

## Island Shape (Rounding, Borders)

- **LOOK-10** Given shell.json has `powerbarIslandRounding` set to a number, when islands draw, rounding is not clamped to a maximum: any stored value is used (AppearanceModel.ranges.rounding has no max field, roundingMax computes the slider's top as bar thickness / 2 / spacing scale, min 1, but stored values may exceed it).

- **LOOK-11** Given a bar of thickness 38 px and spacing scale 1, when Preferences' rounding slider is shown, its maximum is 19 (half the bar thickness; roundingMax(38, 1) → 19).

- **LOOK-12** Given a bar of thickness 27 px (odd) and spacing scale 1, when the slider's top is computed, it rounds up so a full pill is reachable (roundingMax(27, 1) → 14; rounded 27 / 2 = 13.5 → 14).

- **LOOK-13** Given a bar of thickness 42 px and spacing scale 1.25, when the slider's top is computed, it divides by the spacing scale (roundingMax(42, 1.25) → 17; 42 / 2 / 1.25 = 16.8 → 17).

- **LOOK-14** Given shell.json has `powerbarIslandBorders` true, when islands draw, borders are shown with the border width set (AppearanceModel effects and flatKeys).

- **LOOK-15** Given shell.json has `powerbarIslandBorders` false or unset, when islands draw, borders are hidden (AppearanceModel).

- **LOOK-16** Given shell.json has `powerbarIslandBorderWidth` set to a number, when borders draw, thickness is clamped to 0.5–3 px (AppearanceModel.ranges.borderWidth): 0→0.5 px, 1→1 px (default), 4→3 px.

- **LOOK-17** Given a side bar with vertical islands, when islands draw, rounding and border width apply as on a horizontal bar: vertical islands use the same shape (AppearanceModel, used in Bar.qml roundingFor/borderFor).

## Text and Icons Colour

- **LOOK-18** Given shell.json has no `powerbarForeground` set, when the bar draws text and icons, the theme's own colours are used (AppearanceModel.foreground returns "theme" as default).

- **LOOK-19** Given shell.json has `powerbarForeground` as a bare string (legacy), when a theme is active, the choice is ignored: text and icons use the theme's colours (AppearanceModel.foreground checks `isMap(v)` and returns "theme" for non-object values).

- **LOOK-20** Given shell.json has `powerbarForeground: { "osaka-jade": "dark" }` and "osaka-jade" is the active theme, when the bar draws, text and icons use the theme's dark colour (AppearanceModel.foreground returns the per-theme choice).

- **LOOK-21** Given shell.json has `powerbarForeground: { "osaka-jade": "light" }` and the bar draws, when text and icons are drawn, they use the theme's light colour (AppearanceModel.foreground returns "light" or "dark" from the per-theme map).

- **LOOK-22** Given shell.json has `powerbarForeground: { "osaka-jade": "invalid" }`, when "osaka-jade" is active, text and icons use the theme's colours (AppearanceModel.foreground checks value === "light" || value === "dark" and defaults to "theme").

- **LOOK-23** Given a theme with light text and dark background, when AppearanceModel.textPair computes the light/dark pair from two colours, luminance is calculated via sRGB conversion and coefficients (0.2126·R + 0.7152·G + 0.0722·B): the brighter colour becomes "light", the darker becomes "dark".

- **LOOK-24** Given text and icons are set to "light" or "dark" in Preferences, when the bar switches themes, the same colour is used in each theme: the choice belongs to the theme it was made in and follows the per-theme map (AppearanceModel, shell.json `powerbarForeground` is per-theme).

- **LOOK-25** Given the bar's text color is changed in Preferences, when the bar redraws, text and icons colour animates over 420 ms with InOutCubic easing (Bar.qml Behavior on barForeground).

- **LOOK-26** Given a theme holds no `powerbarForeground` entry for itself and Preferences' Surface > Text and icons shows the theme's default, when the user picks "dark", the choice is stored per theme (AppearanceModel.setText).

## Appearance Scopes (Theme / Everywhere / Just here)

- **LOOK-27** Given no user appearance values are set and Preferences' Shape, Surface or Shadow tile is open, when the tile header is shown, "Theme" is selected and controls show the theme's values (AppearanceModel.scopeOf returns "theme" as default when no all and no own values exist).

- **LOOK-28** Given the user has set values in Preferences' Surface > Everywhere (shared), when another theme is switched to that has not been customised, Surface follows the shared values (AppearanceModel.scopeOf: if all is filled, scope is "all"; AppearanceModel.resolve checks "all" values in the lookup chain).

- **LOOK-29** Given Preferences' Shape > Everywhere is picked the first time with rounding unset on the bar, when the first pick shares the currently shown values, the shown rounding is recorded in the shared set (AppearanceModel.setScope seeds the "all" set with resolve().values).

- **LOOK-30** Given the user has set rounding to 10 in Preferences' Shape > Everywhere and switches to another theme, when the new theme draws, its islands use rounding 10 (AppearanceModel: every theme's scope defaults to "all" when shared values exist).

- **LOOK-31** Given Preferences' Shape > Just here is picked in theme A with custom rounding, when theme B is switched to, theme B's Shape still shows "Theme" and draws the theme's rounding (AppearanceModel.scopeOf, resolve: per-theme "this" is independent of other themes).

- **LOOK-32** Given Preferences' Surface > Just here sets opacity to 70 and "Everywhere" is then chosen, when "Everywhere" is chosen the first time, opacity 70 is recorded in the shared set (AppearanceModel.setScope seeds from resolve().values, the currently shown).

- **LOOK-33** Given the user has switched Shape from "Everywhere" to "Theme", when the tile is switched back to "Everywhere", the earlier shared values are still there and shown (AppearanceModel.setValue/setScope keep stored values; switching scope does not erase them; unmatched scopes stay stored).

- **LOOK-34** Given Preferences' Surface > Just here holds opacity 40 and "Everywhere" holds 70, when "Just here" is shown on a theme, opacity 40 is shown; switching to another theme shows 70 ("Everywhere"); switching back shows 40 again (AppearanceModel.resolve: lookup chain is ["this", own], ["all", shared], ["file", theme]; setScope keeps every value).

- **LOOK-35** Given a tile follows "Everywhere", when its controls are changed in Preferences, the shared set is updated; every theme not customised to "Just here" shows the new value (AppearanceModel.setValue updates a.all[tile][key]).

- **LOOK-36** Given a tile has no user values and "Theme" is shown, when a control is adjusted in Preferences, the write goes nowhere: nothing is stored and the bar is not redrawn (AppearanceModel.setValue checks scope and returns early if scope is "theme").

## A Theme's powerbar.toml

- **LOOK-37** Given a theme ships `powerbar.toml` in its install folder (`/usr/share/omarchy/themes/<name>/powerbar.toml`), when Powerbar loads that theme, the file is read and its values apply to tiles set to "Theme" (Bar.qml themeLookFile reads from `stateHome/omarchy/current/theme/powerbar.toml`; AppearanceModel.resolve includes l[tile] in the lookup chain).

- **LOOK-38** Given a user overlay folder exists (`~/.config/omarchy/themes/<name>/powerbar.toml`), when that theme is active, Powerbar reads the overlay file instead of the theme's shipped one (FileView path uses the overlay first via `current/theme/` symlink).

- **LOOK-39** Given a template (`~/.config/omarchy/themed/powerbar.toml`) exists, when a new theme is switched to with no shipped or overlay file, the template is not read; only shipped and overlay files apply (AppearanceModel, documented in README but only shipped and overlay paths are used).

- **LOOK-40** Given a powerbar.toml file holds `[shape] rounding = 12 borders = true border-width = 1.5`, when parsed, rounding is 12, borders is true, border-width is 1.5; unknown values are ignored (AppearanceModel.parseLook, lookKeys object).

- **LOOK-41** Given a file holds `[surface] opacity = 85 blur = true text = "dark"`, when parsed, opacity 85, blur true, text "dark" are extracted (AppearanceModel.parseLook matches boolean and number values).

- **LOOK-42** Given a file holds `[shadow] enabled = false softness = 10 strength = 30`, when parsed, enabled false, softness 10, strength 30 are set (AppearanceModel.parseLook, shadow section maps enabled/softness/strength).

- **LOOK-43** Given a file holds `[surface] text = "theme"`, when parsed, text is set to "theme" (AppearanceModel.parseLook: text !== "light" && text !== "dark" && text !== "theme" is checked; "theme" is valid).

- **LOOK-44** Given a file holds `[surface] text = "purple"` or `blur = maybe`, when parsed, those lines are skipped: only known string values are accepted (AppearanceModel.parseLook tests value against "light" | "dark" | "theme" for text, "true" | "false" for booleans).

- **LOOK-45** Given a file holds lines with `# comment` or `## comment`, when parsed, comments are stripped and the line is processed (AppearanceModel.parseLook: `.replace(/\s+#.*$/, "")` removes inline comments, `/^#/` removes full-line comments).

- **LOOK-46** Given a file holds `[unknown] key = 1` or `[shape] unknown = 2`, when parsed, unknown sections and keys are skipped (AppearanceModel.parseLook checks lookKeys[section] and key mapping).

- **LOOK-47** Given a file is empty or holds only whitespace and comments, when parsed, an empty object is returned (AppearanceModel.parseLook returns `{}`).

## Legacy Migration

- **LOOK-48** Given shell.json holds older flat keys (`powerbarIslandRounding`, `powerbarBackgroundOpacity`, `powerbarShadow`, etc.) and no `powerbarAppearance`, when the theme name is known and Preferences opens, migration runs once per theme (Bar.qml healAppearance, AppearanceModel.migrate).

- **LOOK-49** Given shell.json holds `powerbarMainBlur: true` and `powerbarMainBackgroundOpacity: 13`, when the bar draws and no unified `powerbarBackgroundOpacity` is set, background opacity is 0.13 (AppearanceModel.effects: main surface's blur setting implies 80% opacity in legacy; unified key overrides).

- **LOOK-50** Given shell.json holds `powerbarExtendedShadow: false` and no unified `powerbarShadow`, when the bar draws, shadow is off (AppearanceModel.effects: unified key is checked first, then main, then legacy defaults).

- **LOOK-51** Given earlier versions' flat keys exist and are migrated, the keys are moved into `bar.powerbarAppearance.themes[<current-theme>]` with `"use": "this"`, and the flat keys are deleted from the bar section (AppearanceModel.migrate, legacyKeys).

- **LOOK-52** Given a theme's appearance has been migrated and other themes have no custom settings, when they are switched to, they start on "Theme" scope (AppearanceModel.migrate creates entries only for the current theme; others default to "theme" scope).

- **LOOK-53** Given earlier versions' per-surface keys like `powerbarMainShadow` and `powerbarExtendedShadow` coexist, when the bar draws, the unified `powerbarShadow` is checked first, then the per-surface ones are ignored (AppearanceModel.effects value function).

- **LOOK-54** Given shell.json has `powerbarForeground` as a bare string (not a per-theme map), when migrated, the entry is removed and no foreground value is stored (AppearanceModel.migrate: non-map values are dropped; fromLegacy skips bare strings).

- **LOOK-55** Given themes are uninstalled from the system, when Powerbar next starts, appearance values kept for missing themes are dropped (AppearanceModel.pruneThemes, called from installedThemesProc.onStreamFinished in Bar.qml).

## Bar Auto-Hide Visibility

- **LOOK-56** Given shell.json has `powerbarAutoHide: true`, when the bar is running, the bar reserves no window space and parks off-screen past its edge (Bar.qml autoHide property, barWindow.exclusiveZone = 0).

- **LOOK-57** Given the bar is autohidden and the pointer moves to the screen edge where the bar is parked, when the pointer enters the activation zone, the bar slides out over windows in 180 ms and stays visible while the pointer is over the bar (Bar.qml autoHideRevealed, autoHideOffset animation, autoHideDelay timer 400 ms).

- **LOOK-58** Given the bar is autohidden and visible while hovered, when the pointer leaves the bar and drawer, after 400 ms with no activity the bar slides away in 130 ms (Bar.qml autoHideDelay timer 400 ms, autoHideMotionMs 130).

- **LOOK-59** Given a drawer is open while the bar is autohidden, when the drawer is open or the pointer hovers it, the bar stays visible (Bar.qml barWindow.autoHideRevealed, autoHideHeld).

- **LOOK-60** Given a widget panel is open from a bar icon while autohidden, the bar stays visible while the panel is open (Bar.qml autoHideHeld includes activePopout check).

- **LOOK-61** Given Preferences is open, when the bar is autohidden, the bar stays visible (Bar.qml barWindow.autoHideHeld includes preferencesOpen).

- **LOOK-62** Given the bar is autohidden and a drag is happening on the bar, when the drag is active, the bar stays visible (Bar.qml autoHideHeld check).

- **LOOK-63** Given the bar is autohidden and `powerbarAutoHideActivity: true` (on by default), when a visible widget changes icon, value or other signal on the watched list, the bar's island for that widget slides out for 2.5 seconds (ManagedModel.activityPeek, autoHidePeekMs).

- **LOOK-64** Given the bar is autohidden, activity peeks the bar, and the widget's activity is cleared within 2.5 seconds, the bar slides back in at the same time the peek ends (Bar.qml autoHidePeek, peekEnd timer).

- **LOOK-65** Given `powerbarAutoHideActivity: false`, when a widget's activity fires, the bar does not peek out: only pointer entry reveals it (Bar.qml autoHideActivity guard in autoHidePeek).

- **LOOK-66** Given a widget has `powerbarActivityPeek: false` set in its layout entry, when that widget's value changes and the bar is autohidden, the bar does not peek for activity (ManagedModel.peeksOnActivity checks entry.powerbarActivityPeek).

- **LOOK-67** Given the bar is autohidden and hovered or dragged, when the on-screen 2 px strip at the bar's edge is clicked, the bar slides out (Bar.qml edgeHover, barWindow.autoHideRevealed).

- **LOOK-68** Given the bar is autohidden and `powerbarAutoHide: true` in shell.json, when a file `$HOME/.local/state/omarchy/toggles/bar-off` exists, the bar is hidden and parked (Bar.qml barOffFlag check).

- **LOOK-69** Given the `bar-off` flag exists and Omarchy's toggle `omarchy toggle bar` is used (Super+Shift+Space), when the toggle key is held, the bar slides out and stays out while the key is held (Bar.qml revealFromToggle on key down, autoHideDelay 400 ms on key up).

- **LOOK-70** Given the bar is toggled out with Super+Shift+Space, when the key is released after 400 ms with no pointer activity, the bar slides back in (Bar.qml autoHideDelay timer fires after 400 ms with autoHideHeld false).

- **LOOK-71** Given Omarchy's toggle for `bar` is used and the bar is autohidden, when the toggle key is no longer down, the flag is not changed: the bar's hide state is independent (Bar.qml revealFromToggle does not write bar-off).

## Widget Capture for Preferences Display

- **LOOK-72** Given a widget is loaded on the bar and Preferences' Layout page shows that widget, when the preview renders, it is a live capture of the widget in the bar's current style (Bar.qml captureWidgetImages, CaptureQueue).

- **LOOK-73** Given a widget is hidden or unloaded while Powerbar is running, when Preferences shows it, the last rendered image Powerbar captured is shown from cache (`~/.cache/powerbar/widgets/<key>.png`) (Bar.qml widgetImageFile, WidgetIcon cachedUrl).

- **LOOK-74** Given a widget has no cached image and is not loaded, when Preferences shows it, the widget's own glyph is shown (WidgetIcon fallback to glyph).

- **LOOK-75** Given a widget has no glyph, when Preferences shows it, a stock fallback icon is shown (WidgetIcon fallback tree).

- **LOOK-76** Given a large bar is active (`powerbarLargeBar: true`), when widget icons are captured in Preferences, they are grabbed at twice their displayed size and trimmed to remove the lip above and below (WidgetIcon savedScale, trimY calculation).

- **LOOK-77** Given a widget was captured on a vertical bar before Powerbar added vertical capture, when Preferences shows its cached image on a horizontal bar now, the image is not shown and the glyph is used instead (WidgetIcon cacheUsable check for image height ≤ 1 px of horizontal bar size).

## Widget Glyphs (Icons)

- **LOOK-78** Given a widget draws a font glyph on the bar, when Preferences opens, the glyph is read from the bar's rendering and cached in `~/.cache/powerbar/glyphs.json` per widget (Bar.qml glyphButtons, takeWidgetGlyphs).

- **LOOK-79** Given a cached glyph is available and a widget is hidden or unloaded, when Preferences shows that widget, the cached glyph is displayed (Bar.qml recordFace, faceOf).

## Tooltip Placement and Appearance

- **LOOK-80** Given a widget is hovered on the bar and a tooltip is shown, when the bar is at the top edge, the tooltip is placed below the icon, centered horizontally on the icon (TooltipModel.place: position="top", tooltip is placed away from the bar, centred).

- **LOOK-81** Given a bottom bar and hovered icon, when the tooltip is shown, it is placed above the icon (TooltipModel away function: position="bottom", tooltip.y = icon.y - tooltip.height - gap).

- **LOOK-82** Given a left bar and hovered icon, when the tooltip is shown, it is placed to the right of the icon, centered vertically (TooltipModel away: position="left", x = icon.x + icon.width + gap).

- **LOOK-83** Given a right bar, when the tooltip is shown, it is placed to the left of the icon, centered vertically on the target (TooltipModel away: position="right", x = icon.x - tooltip.width - gap).

- **LOOK-84** Given a drawer's icon is hovered while an open managed drawer sits beside the bar, when the tooltip is shown, it is placed outside the drawer, not over the drawer's body (TooltipModel overlaps check, place: inDrawer=true, drawer=open).

- **LOOK-85** Given a top bar with a vertical menu open and a menu row item is hovered, when the tooltip is shown, it is placed beside the menu (right of it if there is room, else left), level with the hovered row (TooltipModel: drawer.vertical=true, barVertical=false, places tooltip beside menu).

- **LOOK-86** Given a top bar with a vertical menu and no room on the right of the menu within the screen width, when the tooltip is placed, it is placed on the left of the menu, never slid back over it (TooltipModel overlaps check with bounds).

- **LOOK-87** Given a right bar with a horizontal drawer strip opening to the left, when a strip item is hovered, the tooltip is placed outside the strip (left of it), level with the item (TooltipModel: barVertical=true, drawer.vertical=false).

- **LOOK-88** Given the bar is vertical and a top bar widget has an open drawer beside the bar, when a bar icon not in the drawer is hovered, if the tooltip would overlap the drawer, it is moved past the drawer (TooltipModel place: overlaps check and away past drawer).

- **LOOK-89** Given a tooltip is to be shown, when the gap between tooltip and its anchor (icon or drawer) is set, the default is 6 px (TooltipModel place gap parameter default in Bar.qml).

- **LOOK-90** Tooltip position is calculated in bar window coordinates; overlays such as tooltips apply their border and shadow in screen pixels (Bar.qml overlayShadowPad, overlayBorder scale).

- **LOOK-91** Given Preferences' Appearance > Surface tile follows "Theme", when a theme ships powerbar.toml with shape/surface/shadow settings, tooltips and the key legend draw with those shapes and effects (Bar.qml overlayStyled tracks appearance scopes and look; TooltipModel place is called with styled overlay geometry).

- **LOOK-92** Given Preferences' Surface > Just here or Everywhere is chosen, when tooltips are shown, they draw with the user's shape, surface and shadow settings; the hint says "Your values" (Bar.qml overlayStyled.surface, appearance scopes, Preferences).

- **LOOK-93** Given a tooltip is hovered briefly, when it is first shown after another tooltip faded, there is no delay: the second tooltip appears at once (Bar.qml tooltips share a single entry point; once one has shown, the delay is skipped; README "Once one bar tooltip has shown…").

## Large Bar

- **LOOK-94** Given shell.json has `powerbarLargeBar: true`, when the bar is drawn, it is 12 px thicker than the standard size: 6 px lip above and below each widget (Bar.qml largeBarLip = Style.space(6); barSizeFor adds lip*2).

- **LOOK-95** Given a large bar is active, when Preferences' Layout page shows the bar's On the bar shelf, the shelf's bar preview is drawn at the large bar's thickness with the lip (Preferences barFace uses bar.largeBar).

- **LOOK-96** Given a large bar is active and drawers open, when drawers are drawn, they use the same thickness as the main bar including the lip (Bar.qml barSizeFor used for drawer height).

- **LOOK-97** Given a large bar is active, when widget icons are shown, they keep their normal size; the extra space around them is white space (Bar.qml: "Widgets keep their own size and gain room around them").

- **LOOK-98** Given a large bar is active and widget images are captured in Preferences, they are grabbed with the lip trimmed out so the widget shows alone at either bar size (WidgetIcon: captured at twice size with lip trimmed).

## Animations

- **LOOK-99** Given shell.json has `powerbarAnimations: true` (on by default) or is unset, when the bar redraws after a change, visual transitions use animations: islands ease to new sizes, drawers grow/shrink, spacing animates (Bar.qml animationsEnabled, many Behavior statements).

- **LOOK-100** Given `powerbarAnimations: false`, when the bar makes visual changes, all transitions are instant (Bar.qml: enabled: root.animationsEnabled on Behavior elements).

- **LOOK-101** Given a drawer opens and animationsEnabled is true, the drawer grows out of its edge over 160 ms (README, Bar.qml: drawer animation 160 ms strong ease-out).

- **LOOK-102** Given a drawer closes with animations on, it closes over 110 ms (README: "drawers…close over 110 ms…strong ease-out without overshoot").

- **LOOK-103** Given widget spacing or island size changes with animations on, they resize over 120 ms with ease-out (README: "120 ms ease-out resize").

- **LOOK-104** Given an autohidden bar is revealed by pointer entry with animations on, it slides out over 180 ms (Bar.qml autoHideMotionMs: 180 when autoHideShown).

- **LOOK-105** Given an autohidden bar is dismissed after pointer leaves with animations on, it slides away over 130 ms (Bar.qml autoHideMotionMs: 130 when not autoHideShown).

- **LOOK-106** Given the foreground colour changes (text and icons) with animations on, the colour animates over 420 ms with InOutCubic easing (Bar.qml Behavior on barForeground).

- **LOOK-107** Given the bar's background or urgent colour changes and animations are on, it animates over 420 ms with InOutCubic easing (Bar.qml Behavior on background/urgent).

- **LOOK-108** Given a backdrop wallpaper fade is set in the Preferences background preview with animations on, it fades in over 160 ms (BarBackdrop.qml Behavior on opacity).

## Capture Invalidation

- **LOOK-109** Given a widget's captured presentation is being redisplayed and shell.json changes only `powerbarBackgroundOpacity`, when the capture delta is calculated, it returns empty list [] (does not re-render): only surface alpha should not invalidate (RenderModel.captureDelta: backgroundOpacity is deleted from both oldChrome and newChrome before comparison).

- **LOOK-110** Given a widget's presentation is captured and the bar theme changes or chrome settings change (e.g., bar style), when the capture delta is calculated, it returns null (re-render all): a theme change invalidates captures (RenderModel.captureDelta: theme !== theme returns null, not []).

- **LOOK-111** Given a widget's position or order on the bar changes, when the capture delta is calculated, the changed widget's key is returned as an array element so it is re-rendered at its new position (RenderModel.captureDelta: layout positions are indexed; changed keys are collected).

## Text on Images (BarFace, TintedImage)

- **LOOK-112** Given a widget's face is an image saved in another theme's text colour, when the bar draws that face in a different theme, the image is redrawn: its shape is filled with the bar's current text colour (BarFace TintedImage with tint: face.recolour true, color: root.ink).

- **LOOK-113** Given an image is tinted, when it is drawn, the image's alpha channel masks the fill colour: soft edges are preserved (TintedImage MultiEffect with maskSource, maskThresholdMin 0.5, maskSpreadAtMin 1).

- **LOOK-114** Given a widget's face is text or a glyph in the bar's font, when drawn, the text uses the bar's current text colour (BarFace Text color: root.ink).

## Render Model Reconciliation

- **LOOK-115** Given a bar's layout model is replaced with new widget records while a visual holds snapshots (retained images, etc.), when lists are reconciled, widgets are moved, inserted or removed in place to match the new model without destroying visual state (RenderModel.reconcileLists keeps visual identity).

- **LOOK-116** Given a widget is no longer in the new layout, when lists are reconciled, that widget is removed from its model and its item is parked to coordinate (0, 0) for cleanup (RenderModel.reconcileLists: item.parent = parking, item.x/y = 0).

- **LOOK-117** Given the same widget is present in both old and new layouts at the same index, when lists are reconciled, nothing happens: the widget is not moved (RenderModel.reconcileLists: if model.get(at) === wanted[at] continue).

- **LOOK-118** Given a widget is at a different index in the new layout, when lists are reconciled, it is moved to its new position; other widgets shift as needed (RenderModel.reconcileLists: model.move(from, at, 1) reorders in place).

## Bar Backdrop (Wallpaper Cropping)

- **LOOK-119** Given Preferences' bar appearance shows a preview with a wallpaper behind it, when the preview is drawn, the BarBackdrop crops the wallpaper to the edge the bar sits on (BarBackdrop: verticalAlignment and horizontalAlignment position the image for each bar position).

- **LOOK-120** Given the bar is on the top edge and the wallpaper is landscape, when BarBackdrop aligns it, the image is top-aligned and horizontally centered (BarBackdrop: position="top" → AlignTop, AlignHCenter).

- **LOOK-121** Given the bar is on a side edge, when the wallpaper is cropped in BarBackdrop, its vertical alignment flips: bottom edge on the bar side (BarBackdrop: position="bottom" || position="right" → AlignBottom).

- **LOOK-122** Given the wallpaper image is loading asynchronously in BarBackdrop, when it finishes loading, it fades in with a 160 ms animation if motionEnabled is true (BarBackdrop Image Behavior on opacity).

## Icon Recolouring (WidgetIcon)

- **LOOK-123** Given a group shows its icon and the icon is a custom image (not a glyph), when drawn, the image uses the theme's accent colour if it is a glyph-like icon or the colour it was saved in (WidgetIcon: custom images are not tinted; glyphs are recoloured).

- **LOOK-124** Given a group icon is drawn with faceMode "glyph", when shown, it uses the bar's accent colour (WidgetIcon groupFace color: Color.accent).

## Bar Window Layer Rules

- **LOOK-125** Given Hyprland is configured with powerbar layer rules for blur (namespace = "^powerbar$" with blur = true), when the bar or its tooltips are drawn, backdrop blur from windows behind them is applied (Bar.qml uses namespace "powerbar" for blurred surfaces, documented in README Hyprland config).

- **LOOK-126** Given a powerbar-clear namespace layer rule exists (blur = false), when a non-blurred surface is drawn, it clears the blur (README: dual namespace approach for Hyprland blur control).

- **LOOK-127** Given blur is enabled and the bar switches from blurred to non-blurred, when the switch happens, the namespace is briefly remapped so Hyprland applies the new blur state immediately (Bar.qml surfaceNamespace, "Powerbar briefly remaps…").

- **LOOK-128** Given the alpha threshold for blur is 0.01 (ignore_alpha), when the bar draws fully transparent pixels, Hyprland does not apply blur in those areas (Hyprland layer_rule: ignore_alpha = 0.01).

---

## Doc drift

- README states "Bar → Behavior offers **Animations** (enabled by default)" and lists animations durations. Code: appearanceModel has no animation durations; timing is in Bar.qml hardcoded (160 ms drawer open, 110 ms close, 120 ms resize, 180 ms reveal, 130 ms hide, 420 ms colour, 160 ms backdrop fade). The README is accurate; timing is not in the appearance model.
- README "Large bar (`powerbarLargeBar`) makes the bar 12 px thicker…and doubles the islands' end padding" — testing confirms the 12 px thickness but end padding doubling is not found in the code.
- README "Turn Animations off to make these changes immediate" and lists specific durations for each animation, but code has all hardcoded; there is no way to tune individual durations.

## Open questions

- Does the colour transition on foreground change (420 ms InOutCubic, Bar.qml Behavior on barForeground) apply simultaneously to all text and icon elements, or is there per-element transition delay?
- When a tooltip is shown for the second time in quick succession (< 400 ms), the README says "its neighbours show without the usual delay"—does this apply per-tooltip or is it a global state? Code shows single tooltipShown flag.
- In WidgetIcon, is the `saved scale` (2 × device pixel ratio) applied to both live and cached images, or only cached?
- Does `powerbarAnimations: false` affect tooltips' fade timing, or only bar surface transitions and drawer animations?
