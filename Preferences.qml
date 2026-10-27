import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "BarModel.js" as BarModel
import "AppearanceModel.js" as AppearanceModel
import "GroupsModel.js" as Groups
import "RenderModel.js" as RenderModel
import "TrayItemsModel.js" as TrayItemsModel

// Powerbar preferences. Everything is reachable from the keyboard: 1-4 switch
// pages, each page walks its own controls, Esc closes. Every page shows the
// keys that apply to whatever has focus as a legend at its bottom left.
Item {
    id: prefs
    property var bar: null
    property bool opened: false
    property var targetScreen: null
    // The page's sheet: the pages measure the camera's top from its edge.
    readonly property Item sheet: card
    property int page: 0
    // Changes save as they are made, so the footer stays quiet unless one fails.
    property string status: ""
    property var snapshots: ({})
    property int openSerial: 0
    property int captureEpoch: 0
    property var snapshotBatch: ({})
    property var pendingCaptureKeys: []
    property var previousCaptureConfig: ({})
    readonly property var config: bar ? bar.barConfig : ({})
    // The bar's options as the bar reads them, defaults included.
    readonly property var options: BarModel.options(config)
    // Widget metadata, refreshed once after the registry changes. Omarchy
    // re-registers every bar widget, one at a time, on each config write; read
    // directly, every registration rebuilt every page's models.
    property var registryMetadata: ({})
    function refreshRegistryMetadata() {
        var registry = bar ? bar.barWidgetRegistry : null;
        var widgets = registry && registry.widgets || {};
        var next = {};
        for (var id in widgets)
            next[id] = registry.metadataFor(id);
        if (!RenderModel.equal(next, registryMetadata))
            registryMetadata = next;
    }
    function metadataFor(id) {
        return registryMetadata[String(id)] || null;
    }
    onBarChanged: refreshRegistryMetadata()
    Component.onCompleted: refreshRegistryMetadata()
    readonly property var entries: Model.records(config.layout, function (id) {
        return prefs.metadataFor(id);
    }, bar ? bar.legacyVisibility : false)
    readonly property var layoutEntries: {
        var result = entries.filter(function (e) {
            return !bar.groupFor(e.instanceKey);
        });
        bar.groups.forEach(function (g) {
            var list = result.filter(function (e) {
                return e.section === g.section;
            });
            var anchor = list.find(function (e) {
                return e.instanceKey === g.before;
            });
            result.push({
                id: "powerbar.group." + g.id,
                groupId: g.id,
                instanceKey: Groups.groupKey(g.id),
                label: g.label,
                icon: g.icon,
                iconFont: g.iconFont,
                iconImage: g.iconImage,
                iconTint: g.iconTint,
                mode: g.visibility,
                section: g.section,
                index: anchor ? anchor.index : (config.layout && config.layout[g.section] || []).length,
                endAnchored: !anchor,
                fingerprint: JSON.stringify(g)
            });
        });
        return result.sort(function (a, b) {
            return a.index - b.index || (a.groupId ? -1 : b.groupId ? 1 : 0);
        });
    }
    // A page's tab in the header (PREFS-6): its number as a keycap and its
    // name, bold with an accent underline while it is the page shown.
    component PageTab: Item {
        id: tab
        required property var modelData
        required property int index
        readonly property bool current: prefs.page === index
        implicitWidth: tabRow.implicitWidth + Style.space(20)
        implicitHeight: tabRow.implicitHeight + Style.space(18)
        Accessible.role: Accessible.PageTab
        Accessible.name: modelData.title
        Accessible.selected: current
        Row {
            id: tabRow
            anchors.centerIn: parent
            spacing: Style.space(8)
            KeyCap {
                text: tab.index + 1
                foreground: tab.current ? Commons.Color.accent : Commons.Color.popups.text
                anchors.verticalCenter: parent.verticalCenter
            }
            GrayText {
                text: tab.modelData.title
                textFormat: Text.PlainText
                color: tab.current ? Commons.Color.popups.text : Qt.alpha(Commons.Color.popups.text, tabMouse.containsMouse ? 0.85 : 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: tab.current
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: tab.current ? parent.width - Style.space(12) : 0
            height: Math.max(2, Style.space(2))
            radius: height / 2
            color: Commons.Color.accent
            Behavior on width {
                enabled: prefs.bar && prefs.bar.animationsEnabled
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: prefs.setPage(tab.index)
        }
    }

    readonly property var pagesAlways: [
        {
            title: "Layout",
            icon: "󰕰"
        },
        {
            title: "Groups",
            icon: "󰉋"
        },
        {
            title: "Look",
            icon: "󰏘"
        },
        {
            title: "Behavior",
            icon: "󰒓"
        }
    ]
    // With `powerbarTuning` on (INTEG-155) a fifth page, Tuning, its tab at
    // the header's right (PREFS-132).
    readonly property var pages: options.tuning === true ? pagesAlways.concat([
            {
                title: "Tuning",
                icon: "󰢻",
                aside: true
            }
        ]) : pagesAlways
    onPagesChanged: if (page >= pages.length)
        setPage(pages.length - 1)
    readonly property var pageItems: [layoutPage.item, groupsPage.item, lookPage.item, behaviorPage.item, tuningPage.item]
    // Built on the first open (the page Loaders), then kept.
    property bool pagesLoaded: false
    // A group asked for before its page exists, selected as it loads.
    property string pendingGroupId: ""
    function selectGroup(id) {
        if (groupsPage.item)
            groupsPage.item.selectedId = id;
        else
            pendingGroupId = id;
    }
    readonly property var hints: pageItems[page] ? pageItems[page].hints : []

    function open(payloadJson) {
        // Preferences takes the keyboard: a keyboard mode left on would hold it too.
        if (bar.barKeys && bar.barKeys.active)
            bar.barKeys.leave();
        bar.closeManagedDrawer();
        bar.clearTooltip();
        bar.requestPopout(prefs);
        captureEpoch++;
        snapshotBatch = ({});
        snapshots = ({});
        previousCaptureConfig = JSON.parse(JSON.stringify(config));
        pendingCaptureKeys = [];
        openSerial++;
        cacheListing.running = true;
        opened = true;
        bar.readWidgetGlyphs();
        refreshSnapshots();
        Qt.callLater(focusPage);
    }
    // Widget and group shortcuts: read from Hyprland each time Preferences opens.
    ShortcutStore {
        id: shortcutStore
        bar: prefs.bar
        preferences: prefs
    }
    readonly property var shortcuts: shortcutStore
    onOpenedChanged: {
        if (!opened)
            return;
        pagesLoaded = true;
        if (bar)
            shortcutStore.refresh();
    }
    function close() {
        shortcutStore.stopRecording();
        opened = false;
        captureEpoch++;
        snapshotBatch = ({});
        snapshotDelay.stop();
        if (bar)
            bar.releasePopout(prefs);
    }
    function closeToKeys() {
        close();
        if (bar && bar.barKeys)
            Qt.callLater(bar.barKeys.backFromPreferences);
    }
    function show(screen) {
        targetScreen = screen;
        open("{}");
    }
    // Behavior → Keyboard, the cursor on the keyboard mode's shortcut row.
    property bool pendingKeyboard: false
    function showKeyboard(screen) {
        pendingKeyboard = true;
        if (opened)
            setPage(3);
        else {
            page = 3;
            show(screen);
        }
    }
    function showGroup(screen, id) {
        if (id)
            selectGroup(id);
        page = 1;
        show(screen);
    }
    function openGroup(id) {
        selectGroup(id);
        setPage(1);
    }
    function setPage(index) {
        if (index < 0 || index >= pages.length)
            return;
        page = index;
        Qt.callLater(focusPage);
    }
    function focusPage() {
        var item = pageItems[page];
        if (!item)
            return;
        if (pendingKeyboard && item.keyboardRow) {
            pendingKeyboard = false;
            item.keyboardRow.deskFocus(0, Qt.OtherFocusReason);
        } else
            item.focusFirst();
    }
    function publishSnapshots() {
        if (!opened || !Object.keys(snapshotBatch).length)
            return;
        snapshots = Object.assign({}, snapshots, snapshotBatch);
        snapshotBatch = ({});
    }
    function refreshSnapshots(keys) {
        if (!opened || !bar || !targetScreen)
            return;
        var epoch = captureEpoch, screen = targetScreen;
        bar.captureWidgetImages(screen, function (key, image) {
            if (!prefs.opened || epoch !== prefs.captureEpoch || screen !== prefs.targetScreen)
                return;
            prefs.snapshotBatch[key] = image;
            Qt.callLater(prefs.publishSnapshots);
        }, keys, function () {
            return prefs.opened && epoch === prefs.captureEpoch && screen === prefs.targetScreen;
        });
    }
    onTargetScreenChanged: if (opened) {
        captureEpoch++;
        snapshotBatch = ({});
        refreshSnapshots();
    }
    function title(record) {
        if (record.groupId)
            return record.label;
        if (record.trayTitle)
            return record.trayTitle;
        if (record.label)
            return record.label;
        var metadata = metadataFor(record.id);
        return BarModel.widgetName(metadata, record.id);
    }
    // Saved widget images on disk, listed once per opening.
    property var cachedImages: ({})
    function cachedImageUrl(key) {
        if (!bar)
            return "";
        var file = bar.widgetImageFile(key);
        return cachedImages[file.slice(file.lastIndexOf("/") + 1)] ? "file://" + file + "?v=" + openSerial : "";
    }
    Process {
        id: cacheListing
        command: ["ls", "-1", prefs.bar ? prefs.bar.widgetImageDir : "/nonexistent"]
        property var found: ({})
        stdout: SplitParser {
            onRead: function (line) {
                cacheListing.found[String(line).trim()] = true;
            }
        }
        onStarted: found = ({})
        onExited: prefs.cachedImages = found
    }
    // Where Preferences has no image of a widget: the glyph the widget itself
    // draws (read by the bar at any orientation), then Powerbar's stock one.
    function readGlyph(record) {
        return !record.groupId && bar && bar.widgetGlyphs ? bar.widgetGlyphs[record.instanceKey] || null : null;
    }
    function iconFont(record) {
        var read = readGlyph(record);
        if (record.groupId)
            return Groups.groupIconFont(record) || Style.font.family;
        return read && read.font || Groups.iconFont(icon(record)) || Style.font.family;
    }
    function icon(record) {
        if (record.groupId)
            return record.icon;
        var read = readGlyph(record);
        return read ? read.glyph : Model.icon(String(record.id || ""));
    }
    // Edits show on the bar at once and are written once it settles
    // (Bar.writeConfig); a write that fails later is reported here.
    function setOption(key, value) {
        if (!bar || !bar.shell)
            return;
        var glassyOmarchy = bar.omarchyGlassy === true;
        var result = bar.writeConfig(function (config) {
            if (!config.bar)
                config.bar = {};
            // Undefined returns the setting to its default.
            if (value === undefined)
                delete config.bar[key];
            else
                config.bar[key] = value;
            // Omarchy's bar background has two forms (AppearanceModel.barBackground):
            // the one written replaces the other, and an Omarchy with glassy keeps
            // only `background`, as `omarchy bar transparent` does there.
            if (key === "background")
                delete config.bar.transparent;
            if (key === "transparent") {
                delete config.bar.background;
                if (value !== undefined && glassyOmarchy) {
                    config.bar.background = value === true ? "none" : "opaque";
                    delete config.bar.transparent;
                }
            }
        });
        status = result === false ? "Could not save. Check that shell.json is writable." : "";
    }
    // Returns several settings to their defaults in one write.
    function clearOptions(keys) {
        if (!bar || !bar.shell)
            return;
        var result = bar.writeConfig(function (config) {
            if (!config.bar)
                return;
            keys.forEach(function (key) {
                delete config.bar[key];
            });
        });
        status = result === false ? "Could not save. Check that shell.json is writable." : "";
    }
    readonly property string themeName: bar ? bar.themeName : ""
    // Appearance scopes (AppearanceModel): what each tile follows in the current
    // theme, the resolved values, and writes to the scope the tile follows.
    readonly property var look: bar ? bar.appearance : null
    function scopeOf(tile) {
        return look ? look.scopes[tile] : "theme";
    }
    function lookValue(key) {
        return look ? look.values[key] : undefined;
    }
    function writeLook(mutator) {
        if (!bar || !bar.shell)
            return;
        var theme = themeName;
        var result = bar.writeConfig(function (config) {
            if (!config.bar)
                config.bar = {};
            mutator(config.bar, theme);
        });
        status = result === false ? "Could not save. Check that shell.json is writable." : "";
    }
    function setScope(tile, scope) {
        var look = bar ? bar.themeLook : ({});
        writeLook(function (b, theme) {
            AppearanceModel.setScope(b, theme, tile, scope, look);
        });
    }
    // Choosing an opacity ends Omarchy's clear or glassy bar (`omarchy bar
    // background`, or `transparent` before it).
    function setLook(tile, key, value) {
        writeLook(function (b, theme) {
            AppearanceModel.setValue(b, theme, tile, key, value);
            if (tile === "surface" && key === "opacity") {
                delete b.transparent;
                delete b.background;
            }
        });
    }
    function setText(value) {
        writeLook(function (b, theme) {
            AppearanceModel.setText(b, theme, value);
        });
    }
    // The line under a tile's header: where its values come from, or what a
    // change there reaches.
    function scopeHint(tile) {
        if (!look)
            return "";
        var theme = themeName || "this theme", own = !!look.look[tile];
        var scope = look.scopes[tile];
        // One line in a tile a third of the card wide: the page must not scroll.
        if (scope === "theme")
            return own ? "Using " + theme + "'s Powerbar look." : "Using " + theme + "'s look.";
        if (scope === "all")
            return own ? "Yours everywhere; " + theme + " has its own look." : "Yours, in every theme that has no own choice.";
        return "Yours, only while " + theme + " is on.";
    }
    function setBarStyle(value) {
        if (!bar || !bar.shell)
            return;
        var result = bar.writeConfig(function (config) {
            BarModel.setBarStyle(config, value);
        });
        status = result === false ? "Could not save. Check that shell.json is writable." : "";
    }
    readonly property var ranges: AppearanceModel.ranges
    // The Notch style: black ears around the camera, at the top of a notched
    // screen, no drawers; other screens and edges draw it as islands. Settings
    // that only the islands use hide when every screen has the notch look.
    readonly property bool notchMode: !!bar && bar.notchMode
    readonly property bool motion: !bar || bar.animationsEnabled

    Connections {
        target: prefs.bar
        ignoreUnknownSignals: true
        function onConfigWriteFailed() {
            prefs.status = "Could not save. Check that shell.json is writable.";
        }
    }
    // `before` is an index into the layout shown now; the edit names the widget
    // and its new neighbour by instance key, so replayed on a layout that
    // changed meanwhile (a queued edit is re-run on each delivery) it lands
    // beside the same neighbour, or reports that the neighbour is gone.
    function move(record, section, mode, before, passGroups) {
        if (!record || !bar || !bar.shell)
            return;
        var beforeKey = Model.anchorKey(config.layout, section, before, record.groupId ? "" : record.instanceKey);
        var changed = false, inPlace = false;
        var accepted = bar.writeConfig(function (config) {
            changed = false;
            inPlace = false;
            if (record.groupId) {
                changed = Groups.edit(config, record.groupId, {
                    section: section,
                    visibility: mode,
                    before: beforeKey
                });
                return;
            }
            var layout = config.bar.layout;
            if (!record.instanceKey) {
                changed = Model.move(config, record, section, mode, Math.ceil(before));
                return;
            }
            var from = Model.sections.find(function (zone) {
                return (layout[zone] || []).some(function (entry) {
                    return entry && entry.powerbarInstance === record.instanceKey;
                });
            });
            var to = layout[section] || [];
            if (!from || (beforeKey && !to.some(function (entry) {
                    return entry && entry.powerbarInstance === beforeKey;
                })))
                return;
            // A group anchored on the moving widget stays where it is.
            var next = Groups.nextAnchor(config, from, record.instanceKey);
            if (!Array.isArray(layout[section]))
                layout[section] = [];
            changed = BarModel.moveInstanceInConfig(config, from, record.instanceKey, section, beforeKey, mode);
            if (changed)
                Groups.reanchor(config, from, record.instanceKey, next);
            // Past groups drawn at the zone's end: they re-anchor on the widget.
            if (!beforeKey && Groups.anchorOn(config, section, record.instanceKey, passGroups || []))
                changed = true;
            if (!changed)
                inPlace = true;
        });
        status = accepted === false ? "Could not save the layout. Check that shell.json is writable." : changed || inPlace ? "" : "The layout changed elsewhere. Try again.";
    }

    // Omarchy's tray icons (TrayItemsModel.js): the ones still in the tray, as
    // the Layout page's last row, and each icon's live image.
    readonly property var trayEntries: TrayItemsModel.trayRows(SystemTray.items.values, config.layout, Status.Passive)
    function trayIcon(record) {
        if (!record || !record.trayItem)
            return "";
        var item = TrayItemsModel.find(SystemTray.items.values, {
            item: record.trayItem,
            title: record.trayTitle
        });
        return item ? String(item.icon || "") : "";
    }
    // Moves a tray icon out onto the bar, before layout index `before` of
    // `section`; returns the new entry's instance key ("" when it did not move).
    function takeFromTray(record, section, mode, before) {
        if (!record || !bar || !bar.shell)
            return "";
        var item = TrayItemsModel.find(SystemTray.items.values, {
            item: record.trayItem,
            title: record.trayTitle
        });
        if (!item) {
            status = "That app has left the tray.";
            return "";
        }
        var beforeKey = Model.anchorKey(config.layout, section, before, "");
        var key = "pw-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2);
        var moved = false;
        var accepted = bar.writeConfig(function (config) {
            moved = !!TrayItemsModel.moveOut(config, item, section, mode, beforeKey, key);
        });
        status = accepted === false ? "Could not save the layout. Check that shell.json is writable." : "";
        return accepted !== false && moved ? key : "";
    }
    // Puts a moved icon back in the tray. A group anchored on it moves on to
    // the widget after it.
    function returnToTray(record) {
        if (!record || !record.instanceKey || !bar || !bar.shell)
            return;
        var accepted = bar.writeConfig(function (config) {
            var next = Groups.nextAnchor(config, record.section, record.instanceKey);
            if (TrayItemsModel.moveBack(config, record.instanceKey))
                Groups.reanchor(config, record.section, record.instanceKey, next);
        });
        status = accepted === false ? "Could not save the layout. Check that shell.json is writable." : "";
    }

    Timer {
        id: snapshotDelay
        interval: 260
        onTriggered: {
            var keys = prefs.pendingCaptureKeys;
            prefs.pendingCaptureKeys = [];
            prefs.refreshSnapshots(keys);
        }
    }
    Connections {
        target: prefs.bar
        function onBarConfigChanged() {
            // Opening takes its own baseline, so a closed window has nothing to track.
            if (!prefs.opened)
                return;
            var next = JSON.parse(JSON.stringify(prefs.config));
            var keys = RenderModel.captureDelta(prefs.previousCaptureConfig, next);
            prefs.previousCaptureConfig = next;
            if (keys && !keys.length)
                return;
            if (keys === null || prefs.pendingCaptureKeys === null)
                prefs.pendingCaptureKeys = null;
            else
                prefs.pendingCaptureKeys = Array.from(new Set(prefs.pendingCaptureKeys.concat(keys)));
            snapshotDelay.restart();
        }
        function onFontFamilyChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onBarSizeChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onBarWidgetRegistryChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onBarForegroundChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onBackgroundChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onUrgentChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
        function onForegroundChanged() {
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
    }

    Connections {
        target: prefs.bar
        ignoreUnknownSignals: true
        function onBarWidgetRegistryChanged() {
            Qt.callLater(prefs.refreshRegistryMetadata);
        }
    }
    Connections {
        target: prefs.bar ? prefs.bar.barWidgetRegistry : null
        ignoreUnknownSignals: true
        function onWidgetsChanged() {
            Qt.callLater(prefs.refreshRegistryMetadata);
        }
        function onRevisionChanged() {
            Qt.callLater(prefs.refreshRegistryMetadata);
            if (prefs.opened) {
                prefs.pendingCaptureKeys = null;
                snapshotDelay.restart();
            }
        }
    }

    PanelWindow {
        id: window
        screen: prefs.targetScreen
        visible: prefs.opened
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // The window covers the screen but the bar: on the bar's edge it starts
        // where a floating bar's border would end (its gap off the screen and
        // its thickness, whatever the style now, which is never thicker), so
        // the bar stays in view and changes show on it, and the page's top
        // never moves with the style. The page is a sheet one gap inside the
        // window on every side; a click on that margin lands on this window
        // and does nothing, never on a window under it (PREFS-102).
        readonly property real gap: prefs.bar ? prefs.bar.edgeGap : 0
        // A bar thicker than the floating one (the Notch style on a screen
        // without a camera) pushes the page down by what it takes more.
        readonly property real barInset: {
            if (!prefs.bar)
                return 0;
            var screen = prefs.targetScreen;
            var now = screen ? prefs.bar.screenExtents[screen.name] || 0 : 0;
            return Math.max(prefs.bar.floatingThicknessFor(screen) + gap, now - gap);
        }
        margins {
            top: prefs.bar && prefs.bar.position === "top" ? barInset : 0
            bottom: prefs.bar && prefs.bar.position === "bottom" ? barInset : 0
            left: prefs.bar && prefs.bar.position === "left" ? barInset : 0
            right: prefs.bar && prefs.bar.position === "right" ? barInset : 0
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "powerbar-preferences"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: prefs.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Omarchy's controls on the pages (buttons, fields, a dropdown's rows)
        // draw Text of their own in Qt's default rendering, LCD-antialiased:
        // gray it as Preferences open, change page or move focus (a dropdown
        // opening moves it into its rows), from the window's root, popups
        // included. Powerbar's own text is GrayText already.
        readonly property var quickWindow: card.Window.window
        function grayControls() {
            var w = quickWindow;
            if (prefs.opened && w && w.contentItem)
                RenderModel.grayText(w.contentItem.parent || w.contentItem, Text.QtRendering, Text.CurveRendering);
        }
        Timer {
            id: grayLater
            interval: 0
            onTriggered: window.grayControls()
        }
        Connections {
            target: window.quickWindow
            function onActiveFocusItemChanged() {
                grayLater.restart();
            }
        }
        Connections {
            target: prefs
            function onOpenedChanged() {
                grayLater.restart();
            }
            function onPageChanged() {
                grayLater.restart();
            }
        }

        // The margin round the page: clicks there do nothing.
        MouseArea {
            anchors.fill: parent
        }
        // The page: a sheet one gap inside the window, the popups background
        // with the floating bar's rounding and border, no shadow. The header and
        // footer keep the sheet's margin, so the Layout page's layers line up
        // with them (PREFS-99).
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: window.gap
            radius: Style.cornerRadius
            border.width: 1
            border.color: Commons.Color.popups.border
            readonly property real inset: Math.round(Math.min(Style.space(66), width / 23))
            color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
            focus: true
            opacity: prefs.opened ? 1 : 0
            Behavior on opacity {
                enabled: prefs.bar && prefs.bar.animationsEnabled
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            // Keys nothing inside wanted: page switching and closing.
            Keys.onPressed: function (event) {
                var ctrl = event.modifiers & Qt.ControlModifier;
                var digit = event.key - Qt.Key_1;
                if (event.key === Qt.Key_Escape) {
                    prefs.close();
                    event.accepted = true;
                } else
                // , (the keyboard mode's key for Preferences) closes it, back to the
                // mode when it came from there (KEYS-81).
                if (event.text === "," && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    prefs.closeToKeys();
                    event.accepted = true;
                } else if (digit >= 0 && digit < prefs.pages.length && !(event.modifiers & Qt.AltModifier)) {
                    prefs.setPage(digit);
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_Tab) {
                    prefs.setPage((prefs.page + 1) % prefs.pages.length);
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_Backtab) {
                    prefs.setPage((prefs.page + prefs.pages.length - 1) % prefs.pages.length);
                    event.accepted = true;
                }
            }
            // Ctrl+digit works even while typing in a field.
            Shortcut {
                sequences: ["Ctrl+1"]
                onActivated: prefs.setPage(0)
            }
            Shortcut {
                sequences: ["Ctrl+2"]
                onActivated: prefs.setPage(1)
            }
            Shortcut {
                sequences: ["Ctrl+3"]
                onActivated: prefs.setPage(2)
            }
            Shortcut {
                sequences: ["Ctrl+4"]
                onActivated: prefs.setPage(3)
            }
            Shortcut {
                sequences: ["Ctrl+5"]
                enabled: prefs.pages.length > 4
                onActivated: prefs.setPage(4)
            }
            MouseArea {
                anchors.fill: parent
            } // Keep clicks inside the card.

            // One accent ring follows keyboard focus from control to control, so the
            // current place is obvious whatever the theme's own focus styling.
            // Lists and grids that draw their own cursor opt out with ownsFocusRing.
            // The ring is clipped to the scrolling area its control sits in, so a
            // control scrolled out of view never drags the ring over the header or
            // footer. Only controls on the pages get it: popups and dropdown lists
            // sit above the card and keep their own highlight.
            Item {
                id: ringClip
                z: 1000
                clip: true
                visible: focusRing.shown

                BorderSurface {
                    id: focusRing
                    readonly property Item focused: card.Window.activeFocusItem
                    readonly property Item target: prefs.opened && focused && focused !== card && !focused.ownsFocusRing && focused.width > 0 && focused.height > 0 && focusRing.onPages(focused) ? focused : null
                    readonly property real pad: Style.space(5)
                    property bool gliding: false
                    // Visibility lives on the clipping parent; a child's own `visible`
                    // reads false while its parent is hidden, so it cannot drive it.
                    readonly property bool shown: !!target && target.visible
                    color: "transparent"
                    // A hairline in the theme's own shape: square on a square theme.
                    radius: Style.cornerRadius > 0 ? Style.cornerRadius + pad : 0
                    borderSpec: Border.flat(Commons.Color.accent, 1)
                    onTargetChanged: {
                        gliding = true;
                        glideEnd.restart();
                        follow();
                    }
                    // A page that draws its own cursor (the desks) keeps the ring away.
                    function onPages(item) {
                        for (var p = item; p; p = p.parent) {
                            if (p.ownsFocusRings === true)
                                return false;
                            if (p === pages)
                                return true;
                        }
                        return false;
                    }
                    function viewportOf(item) {
                        for (var p = item.parent; p && p !== pages; p = p.parent)
                            if (p.contentY !== undefined && p.flicking !== undefined)
                                return p;
                        return pages;
                    }
                    function follow() {
                        if (!target)
                            return;
                        var view = viewportOf(target);
                        var v = view.mapToItem(card, 0, 0);
                        ringClip.x = v.x - pad;
                        ringClip.y = v.y - pad;
                        ringClip.width = view.width + pad * 2;
                        ringClip.height = view.height + pad * 2;
                        var p = target.mapToItem(ringClip, 0, 0);
                        x = p.x - pad;
                        y = p.y - pad;
                        width = target.width + pad * 2;
                        height = target.height + pad * 2;
                    }
                    Timer {
                        id: glideEnd
                        interval: 170
                        onTriggered: focusRing.gliding = false
                    }
                    GeometryObserver {
                        target: focusRing.shown ? focusRing.target : null
                        host: card
                        onChanged: focusRing.follow()
                    }
                    Behavior on x {
                        enabled: focusRing.gliding && prefs.bar.animationsEnabled
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: focusRing.gliding && prefs.bar.animationsEnabled
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        enabled: focusRing.gliding && prefs.bar.animationsEnabled
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        enabled: focusRing.gliding && prefs.bar.animationsEnabled
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: card.inset
                anchors.rightMargin: card.inset
                anchors.topMargin: Style.space(14)
                anchors.bottomMargin: Style.space(14)
                spacing: 0

                // ---------------------------------------------------------- header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(28)
                    GrayText {
                        text: "Powerbar"
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                    }
                    Row {
                        spacing: Style.space(4)
                        Repeater {
                            model: prefs.pages.filter(function (p) {
                                return !p.aside;
                            })
                            PageTab {}
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    // The Tuning page's tab, at the right beside Close (PREFS-132).
                    PageTab {
                        visible: prefs.pages.length > 4
                        index: 4
                        modelData: prefs.pages[4] || ({
                                title: ""
                            })
                    }
                    Item {
                        implicitWidth: closeRow.implicitWidth
                        implicitHeight: closeRow.implicitHeight
                        opacity: closeMouse.containsMouse ? 1 : 0.65
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close"
                        Row {
                            id: closeRow
                            spacing: Style.space(8)
                            KeyCap {
                                text: "esc"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            GrayText {
                                text: "Close"
                                textFormat: Text.PlainText
                                color: Commons.Color.popups.text
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -Style.space(6)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: prefs.close()
                        }
                    }
                }
                // ----------------------------------------------------------- pages
                StackLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Style.space(4)
                    Layout.bottomMargin: Style.space(10)
                    currentIndex: prefs.page

                    // The pages are built the first time Preferences opens, not at the
                    // shell's start, and then kept: nothing in them shows while closed.
                    Loader {
                        id: layoutPage
                        active: prefs.pagesLoaded
                        sourceComponent: Component {
                            LayoutEditor {
                                preferences: prefs
                            }
                        }
                    }
                    // The other pages take the Layout page's geometry and camera, but
                    // the stack sizes only the page in view: keep it at the pages' size
                    // while another one shows.
                    Binding {
                        target: layoutPage.item
                        when: !!layoutPage.item
                        property: "width"
                        value: pages.width
                        restoreMode: Binding.RestoreNone
                    }
                    Binding {
                        target: layoutPage.item
                        when: !!layoutPage.item
                        property: "height"
                        value: pages.height
                        restoreMode: Binding.RestoreNone
                    }
                    Loader {
                        id: groupsPage
                        active: prefs.pagesLoaded && !!layoutPage.item
                        sourceComponent: Component {
                            GroupsEditor {
                                preferences: prefs
                                layout: layoutPage.item
                            }
                        }
                        onLoaded: if (prefs.pendingGroupId) {
                            item.selectedId = prefs.pendingGroupId;
                            prefs.pendingGroupId = "";
                        }
                    }

                    // The Look and Behavior desks (PREFS-124). Changes show on the
                    // bar itself, so neither draws a preview of its own.
                    Loader {
                        id: lookPage
                        active: prefs.pagesLoaded && !!layoutPage.item
                        sourceComponent: Component {
                            LookEditor {
                                preferences: prefs
                                layout: layoutPage.item
                            }
                        }
                    }
                    Loader {
                        id: behaviorPage
                        active: prefs.pagesLoaded && !!layoutPage.item
                        sourceComponent: Component {
                            BehaviorEditor {
                                preferences: prefs
                                layout: layoutPage.item
                            }
                        }
                    }
                    // The Tuning page, only with `powerbarTuning` on (PREFS-132).
                    Loader {
                        id: tuningPage
                        active: prefs.pagesLoaded && !!layoutPage.item && prefs.options.tuning === true
                        sourceComponent: Component {
                            TuningEditor {
                                preferences: prefs
                                layout: layoutPage.item
                            }
                        }
                    }
                }

                // ---------------------------------------------------------- footer
                // A page that draws its own key legend (Layout) has no footer
                // unless a save failed.
                RowLayout {
                    visible: prefs.hints.length > 0 || prefs.status !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: Style.space(8)
                    spacing: Style.space(18)
                    Repeater {
                        model: prefs.hints
                        Row {
                            required property var modelData
                            spacing: Style.space(6)
                            Repeater {
                                model: String(parent.modelData.keys).split(" ")
                                KeyCap {
                                    required property string modelData
                                    text: modelData
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                }
                            }
                            GrayText {
                                text: parent.modelData.label
                                textFormat: Text.PlainText
                                color: Qt.alpha(Commons.Color.popups.text, 0.6)
                                font.family: Style.font.family
                                font.pixelSize: Style.font.caption
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    GrayText {
                        text: prefs.status
                        textFormat: Text.PlainText
                        color: Commons.Color.urgent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideLeft
                        Layout.maximumWidth: Style.space(320)
                    }
                }
            }
        }
    }
}
