import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "BarModel.js" as BarModel
import "AppearanceModel.js" as AppearanceModel
import "GroupsModel.js" as Groups

// Powerbar preferences. Everything is reachable from the keyboard: 1-4 switch
// pages, Tab and j/k walk controls, h/l adjust them, Esc closes. The footer
// always lists the keys that apply to whatever has focus.
Item {
  id: prefs
  property var bar: null
  property bool opened: false
  property var targetScreen: null
  property int page: 0
  property string status: "Changes apply as you make them"
  property var snapshots: ({})
  property int openSerial: 0
  readonly property string wallpaper: bar ? "file://" + bar.stateHome + "/omarchy/current/background?v=" + openSerial : ""
  readonly property var config: bar ? bar.barConfig : ({})
  readonly property var entries: Model.records(config.layout, function(id) { return bar.barWidgetRegistry.metadataFor(id) })
  readonly property var layoutEntries: {
    var result = entries.filter(function(e) { return !bar.groupFor(e.instanceKey) })
    bar.groups.forEach(function(g) {
      var list = result.filter(function(e) { return e.section === g.section })
      var anchor = list.find(function(e) { return e.instanceKey === g.before })
      result.push({ id: "powerbar.group." + g.id, groupId: g.id, instanceKey: "group:" + g.id,
        label: g.label, icon: g.icon, mode: g.visibility, section: g.section,
        index: anchor ? anchor.index : (config.layout[g.section] || []).length,
        fingerprint: JSON.stringify(g) })
    })
    return result.sort(function(a, b) { return a.index - b.index || (a.groupId ? -1 : b.groupId ? 1 : 0) })
  }
  readonly property var pages: [
    { title: "Layout", icon: "󰕰" }, { title: "Groups", icon: "󰉋" },
    { title: "General", icon: "󰒓" }, { title: "Appearance", icon: "󰏘" }
  ]
  readonly property var pageItems: [layoutPage, groupsPage, generalPage, appearancePage]
  readonly property var hints: pageItems[page] ? pageItems[page].hints : []

  function open(payloadJson) {
    bar.closeManagedDrawer()
    bar.clearTooltip()
    bar.requestPopout(prefs)
    snapshots = ({})
    openSerial++
    cacheListing.running = true
    opened = true
    refreshSnapshots()
    Qt.callLater(focusPage)
  }
  function close() {
    opened = false
    if (bar) bar.releasePopout(prefs)
  }
  function show(screen) { targetScreen = screen; open("{}") }
  function showGroup(screen, id) { if (id) groupsPage.selectedId = id; page = 1; show(screen) }
  function openGroup(id) { groupsPage.selectedId = id; setPage(1) }
  function setPage(index) {
    if (index < 0 || index >= pages.length) return
    page = index
    Qt.callLater(focusPage)
  }
  function focusPage() { if (pageItems[page]) pageItems[page].focusFirst() }
  function refreshSnapshots() {
    if (!opened || !bar || !targetScreen) return
    bar.captureWidgetImages(targetScreen, function(key, image) {
      var next = Object.assign({}, prefs.snapshots)
      next[key] = image
      prefs.snapshots = next
    })
  }
  function title(record) {
    if (record.groupId) return record.label
    if (record.label) return record.label
    var metadata = bar.barWidgetRegistry.metadataFor(record.id)
    return metadata && (metadata.displayName || metadata.name) || String(record.id).split('.').pop()
  }
  // Saved widget images on disk, listed once per opening.
  property var cachedImages: ({})
  function cachedImageUrl(key) {
    if (!bar) return ""
    var file = bar.widgetImageFile(key)
    return cachedImages[file.slice(file.lastIndexOf("/") + 1)] ? "file://" + file + "?v=" + openSerial : ""
  }
  Process {
    id: cacheListing
    command: ["ls", "-1", prefs.bar ? prefs.bar.widgetImageDir : "/nonexistent"]
    property var found: ({})
    stdout: SplitParser { onRead: function(line) { cacheListing.found[String(line).trim()] = true } }
    onStarted: found = ({})
    onExited: prefs.cachedImages = found
  }
  function iconFont(record) { return Groups.iconFont(icon(record)) || Style.font.family }
  function icon(record) { return record.groupId ? record.icon : Model.icon(String(record.id || "")) }
  function setOption(key, value) {
    if (!bar || !bar.shell) return
    var result = bar.shell.mutateShellConfig(function(config) {
      if (!config.bar) config.bar = {}
      config.bar[key] = value
    })
    status = result === false ? "Could not save. Check that shell.json is writable." : "Changes apply as you make them"
  }
  function setBarStyle(value) {
    if (!bar || !bar.shell) return
    var result = bar.shell.mutateShellConfig(function(config) { BarModel.setBarStyle(config, value) })
    status = result === false ? "Could not save. Check that shell.json is writable." : "Changes apply as you make them"
  }
  function resetOptions(operation) {
    if (bar && bar.shell) bar.shell.mutateShellConfig(function(config) { if (config.bar) operation(config.bar) })
  }
  function move(record, section, mode, before) {
    if (!record || !bar || !bar.shell) return
    var changed = false
    var accepted = bar.shell.mutateShellConfig(function(config) {
      if (record.groupId) {
        var anchor = (config.bar.layout[section] || [])[Math.ceil(before)]
        changed = Groups.edit(config, record.groupId, { section: section, visibility: mode,
          before: anchor && anchor.powerbarInstance || "" })
      } else changed = Model.move(config, record, section, mode, Math.ceil(before))
    })
    status = accepted === false ? "Could not save the layout. Check that shell.json is writable."
      : changed ? "Changes apply as you make them" : "The layout changed elsewhere. Try again."
  }

  // Widget images go stale whenever the bar re-renders.
  Timer { id: snapshotDelay; interval: 260; onTriggered: prefs.refreshSnapshots() }
  Connections {
    target: prefs.bar
    function onBarConfigChanged() { if (prefs.opened) snapshotDelay.restart() }
  }

  PanelWindow {
    id: window
    screen: prefs.targetScreen
    visible: prefs.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "powerbar-preferences"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: prefs.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      MouseArea { anchors.fill: parent; onClicked: prefs.close() }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(48), Style.space(1180))
      height: Math.min(parent.height - Style.space(64), Style.space(790))
      color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
      radius: Style.cornerRadius
      focus: true
      opacity: prefs.opened ? 1 : 0
      scale: prefs.opened ? 1 : 0.98
      Behavior on opacity { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      // Keys nothing inside wanted: page switching and closing.
      Keys.onPressed: function(event) {
        var ctrl = event.modifiers & Qt.ControlModifier
        var digit = event.key - Qt.Key_1
        if (event.key === Qt.Key_Escape) { prefs.close(); event.accepted = true }
        else if (digit >= 0 && digit < prefs.pages.length && !(event.modifiers & Qt.AltModifier)) { prefs.setPage(digit); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_Tab) { prefs.setPage((prefs.page + 1) % prefs.pages.length); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_Backtab) { prefs.setPage((prefs.page + prefs.pages.length - 1) % prefs.pages.length); event.accepted = true }
      }
      // Ctrl+digit works even while typing in a field.
      Shortcut { sequences: ["Ctrl+1"]; onActivated: prefs.setPage(0) }
      Shortcut { sequences: ["Ctrl+2"]; onActivated: prefs.setPage(1) }
      Shortcut { sequences: ["Ctrl+3"]; onActivated: prefs.setPage(2) }
      Shortcut { sequences: ["Ctrl+4"]; onActivated: prefs.setPage(3) }
      MouseArea { anchors.fill: parent } // Keep clicks inside the card.

      // One accent ring follows keyboard focus from control to control, so the
      // current place is obvious whatever the theme's own focus styling.
      // Lists and grids that draw their own cursor opt out with ownsFocusRing.
      BorderSurface {
        id: focusRing
        readonly property Item focused: card.Window.activeFocusItem
        readonly property Item target: prefs.opened && focused && focused !== card && !focused.ownsFocusRing
          && focused.width > 0 && focused.height > 0 ? focused : null
        readonly property real pad: Style.space(3)
        property bool gliding: false
        z: 1000
        visible: !!target && target.visible
        color: "transparent"
        radius: Style.cornerRadius + pad
        borderSpec: Border.flat(Color.accent, Math.max(1, Style.space(2)))
        onTargetChanged: { gliding = true; glideEnd.restart(); follow() }
        function follow() {
          if (!target) return
          var p = target.mapToItem(card, 0, 0)
          x = p.x - pad
          y = p.y - pad
          width = target.width + pad * 2
          height = target.height + pad * 2
        }
        Timer { id: glideEnd; interval: 170; onTriggered: focusRing.gliding = false }
        FrameAnimation { running: focusRing.visible; onTriggered: focusRing.follow() }
        Behavior on x { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(28)
        anchors.rightMargin: Style.space(28)
        anchors.topMargin: Style.space(20)
        anchors.bottomMargin: Style.space(14)
        spacing: 0

        // ---------------------------------------------------------- header
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(28)
          Text {
            text: "Powerbar"
            textFormat: Text.PlainText
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Row {
            spacing: Style.space(4)
            Repeater {
              model: prefs.pages
              Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: prefs.page === index
                width: tabRow.implicitWidth + Style.space(20)
                height: tabRow.implicitHeight + Style.space(18)
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.title
                Accessible.selected: current
                Row {
                  id: tabRow
                  anchors.centerIn: parent
                  spacing: Style.space(8)
                  KeyCap {
                    text: tab.index + 1
                    foreground: tab.current ? Color.accent : Color.popups.text
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: tab.modelData.title
                    textFormat: Text.PlainText
                    color: tab.current ? Color.popups.text : Qt.alpha(Color.popups.text, tabMouse.containsMouse ? 0.85 : 0.55)
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
                  color: Color.accent
                  Behavior on width { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: prefs.setPage(tab.index)
                }
              }
            }
          }
          Item { Layout.fillWidth: true }
          Item {
            implicitWidth: closeRow.implicitWidth
            implicitHeight: closeRow.implicitHeight
            opacity: closeMouse.containsMouse ? 1 : 0.65
            Accessible.role: Accessible.Button
            Accessible.name: "Close"
            Row {
            id: closeRow
            spacing: Style.space(8)
            KeyCap { text: "esc"; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: "Close"
              textFormat: Text.PlainText
              color: Color.popups.text
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
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.popups.text, 0.1) }

        // ----------------------------------------------------------- pages
        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.topMargin: Style.space(20)
          Layout.bottomMargin: Style.space(14)
          currentIndex: prefs.page

          LayoutEditor { id: layoutPage; preferences: prefs }
          GroupsPreferences { id: groupsPage; preferences: prefs }

          PrefsForm {
            id: generalPage
            PrefsSection {
              title: "Placement"
              PrefsChoice {
                label: "Screen edge"
                options: [{ value: "top", label: "Top" }, { value: "bottom", label: "Bottom" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
                value: prefs.bar ? prefs.bar.position : ""
                onChosen: function(value) { prefs.setOption("position", value) }
              }
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(16)
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)
                  Text { text: "Center"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                  Text {
                    text: "Center the middle zone as a whole, or pin one widget to the exact screen center"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Color.popups.text, 0.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                  }
                }
                Dropdown {
                  showLabel: false
                  Layout.preferredWidth: Style.space(260)
                  options: [{ label: "The whole zone", value: "" }].concat(prefs.layoutEntries.filter(function(e) {
                    return e.section === "center" && e.mode === "shown" && !e.groupId
                  }).map(function(e) { return { label: prefs.title(e), value: e.id } }))
                  value: prefs.bar ? prefs.bar.centerAnchor : ""
                  onChanged: function(value) { prefs.setOption("centerAnchor", value) }
                }
              }
            }
            PrefsSection {
              title: "Behavior"
              PrefsToggle {
                label: "Autohide"
                description: "The bar stays off screen and slides over your windows when the pointer reaches its edge"
                checked: prefs.config.powerbarAutoHide === true
                onToggled: function(checked) { prefs.setOption("powerbarAutoHide", checked) }
              }
              PrefsToggle {
                label: "Animations"
                description: "Widgets and drawers ease into place as they change"
                checked: prefs.bar ? prefs.bar.animationsEnabled : true
                onToggled: function(checked) { prefs.setOption("powerbarAnimations", checked) }
              }
            }
            PrefsSection {
              title: "Style"
              BarStylePicker {
                Layout.fillWidth: true
                bar: prefs.bar
                wallpaper: prefs.wallpaper
                onChosen: function(value) { prefs.setBarStyle(value) }
              }
              PrefsSlider {
                label: "Space between widgets"
                minimum: 0; maximum: 24
                value: Number(prefs.config.powerbarSpacing || 0)
                onEdited: function(value) { prefs.setOption("powerbarSpacing", value) }
              }
            }
            PrefsSection {
              title: "Drawer widgets"
              description: "Widgets set to the drawer appear on the bar briefly when they change, and all of them open in a drawer when you hover their zone."
              PrefsSlider {
                label: "Stay on the bar after a change"
                unit: "s"; minimum: 1; maximum: 60
                value: prefs.bar ? prefs.bar.managedRevealSeconds : 10
                onEdited: function(value) { prefs.setOption("powerbarManagedRevealSeconds", value) }
              }
              PrefsSlider {
                label: "Time to reach the drawer"
                unit: "s"; minimum: 1; maximum: 15
                value: prefs.bar ? prefs.bar.managedEntrySeconds : 5
                onEdited: function(value) { prefs.setOption("powerbarManagedEntryGraceSeconds", value) }
              }
              PrefsSlider {
                label: "Drawer stays open after you leave"
                unit: "s"; minimum: 1; maximum: 15
                value: prefs.bar ? prefs.bar.managedExitSeconds : 3
                onEdited: function(value) { prefs.setOption("powerbarManagedExitGraceSeconds", value) }
              }
              Button {
                text: "Restore default timing"
                iconText: "󰑓"
                focusable: true
                bordered: true
                foreground: Color.popups.text
                onClicked: prefs.resetOptions(function(bar) {
                  delete bar.powerbarManagedRevealSeconds
                  delete bar.powerbarManagedEntryGraceSeconds
                  delete bar.powerbarManagedExitGraceSeconds
                })
              }
            }
          }

          PrefsForm {
            id: appearancePage
            BarPreview { Layout.fillWidth: true }
            PrefsSection {
              title: "Size"
              PrefsToggle {
                label: "Large bar"
                description: "A taller bar with more room around each widget. Text and icons keep their size."
                checked: prefs.bar ? prefs.bar.largeBar : false
                onToggled: function(checked) { prefs.setOption("powerbarLargeBar", checked) }
              }
            }
            PrefsSection {
              title: "Borders and rounding"
              description: "For floating bars, islands and drawers. Border color follows your theme."
              PrefsToggle {
                label: "Borders"
                checked: prefs.config.powerbarIslandBorders !== false
                onToggled: function(checked) { prefs.setOption("powerbarIslandBorders", checked) }
              }
              PrefsSlider {
                label: "Border thickness"
                minimum: 0; maximum: 4; stepSize: 0.5
                enabled: prefs.config.powerbarIslandBorders !== false
                value: typeof prefs.config.powerbarIslandBorderWidth === "number"
                  ? prefs.config.powerbarIslandBorderWidth : prefs.bar ? Border.top(prefs.bar.themeIslandBorder) / Style.space(1) : 1
                onEdited: function(value) { prefs.setOption("powerbarIslandBorderWidth", value) }
              }
              PrefsSlider {
                label: "Corner rounding"
                minimum: 0; maximum: 32
                value: prefs.bar ? prefs.bar.islandRounding / Style.space(1) : 0
                onEdited: function(value) { prefs.setOption("powerbarIslandRounding", value) }
              }
              Button {
                text: "Use the theme's borders and rounding"
                iconText: "󰑓"
                focusable: true
                bordered: true
                foreground: Color.popups.text
                onClicked: prefs.resetOptions(function(bar) {
                  delete bar.powerbarIslandBorders
                  delete bar.powerbarIslandBorderWidth
                  delete bar.powerbarIslandRounding
                })
              }
            }
            PrefsSection {
              title: "Surface"
              description: "Blur uses your desktop's blur strength. Shadows follow each surface's shape."
              PrefsToggle {
                label: "Background blur"
                checked: prefs.bar ? prefs.bar.surfaceEffects.blur : false
                onToggled: function(checked) { prefs.setOption("powerbarBlur", checked) }
              }
              PrefsSlider {
                label: "Background opacity"
                unit: "%"; minimum: 0; maximum: 100
                value: prefs.bar ? prefs.bar.surfaceEffects.backgroundOpacity * 100 : 100
                onEdited: function(value) { prefs.setOption("powerbarBackgroundOpacity", value) }
              }
              PrefsToggle {
                label: "Shadow"
                checked: prefs.bar ? prefs.bar.surfaceEffects.shadow : false
                onToggled: function(checked) { prefs.setOption("powerbarShadow", checked) }
              }
              PrefsSlider {
                label: "Shadow softness"
                minimum: 0; maximum: 32
                enabled: prefs.bar && prefs.bar.surfaceEffects.shadow
                value: prefs.bar ? prefs.bar.surfaceEffects.shadowSize : 16
                onEdited: function(value) { prefs.setOption("powerbarShadowSize", value) }
              }
              PrefsSlider {
                label: "Shadow strength"
                unit: "%"; minimum: 0; maximum: 45
                enabled: prefs.bar && prefs.bar.surfaceEffects.shadow
                value: prefs.bar ? prefs.bar.surfaceEffects.shadowOpacity * 100 : 30
                onEdited: function(value) { prefs.setOption("powerbarShadowOpacity", value) }
              }
              Button {
                text: "Reset surface"
                iconText: "󰑓"
                focusable: true
                bordered: true
                foreground: Color.popups.text
                onClicked: prefs.resetOptions(function(bar) { AppearanceModel.reset(bar) })
              }
            }
          }
        }

        // ---------------------------------------------------------- footer
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Color.popups.text, 0.1) }
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(12)
          spacing: Style.space(18)
          Repeater {
            model: prefs.hints
            Row {
              required property var modelData
              spacing: Style.space(6)
              Repeater {
                model: String(parent.modelData.keys).split(" ")
                KeyCap { required property string modelData; text: modelData; anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
              }
              Text {
                text: parent.modelData.label
                textFormat: Text.PlainText
                color: Qt.alpha(Color.popups.text, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
          Item { Layout.fillWidth: true }
          Text {
            text: prefs.status
            textFormat: Text.PlainText
            color: Qt.alpha(Color.popups.text, 0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
            Layout.maximumWidth: Style.space(320)
          }
        }
      }
    }
  }

  // A miniature of the bar with its current surface, drawn over a neutral
  // backdrop so transparency, borders and shadows read at a glance.
  component BarPreview: BarBackdrop {
    id: preview
    readonly property var effects: prefs.bar ? prefs.bar.surfaceEffects : ({})
    // The preview is the strip of screen along the bar's edge: a flat bar
    // touches the edges, floating bars and islands keep the bar's edge gap.
    readonly property real gap: prefs.bar && !prefs.bar.flat ? prefs.bar.edgeGap : 0
    readonly property real barY: prefs.bar && (prefs.bar.position === "bottom" || prefs.bar.position === "right")
      ? height - prefs.bar.barSize - gap : gap
    implicitHeight: prefs.bar ? prefs.bar.barSize + Style.space(72) : Style.space(100)
    source: prefs.wallpaper
    position: prefs.bar ? prefs.bar.position : "top"

    EffectSurface {
      visible: prefs.bar && !prefs.bar.islands
      x: preview.gap; y: preview.barY
      width: parent.width - preview.gap * 2
      height: prefs.bar ? prefs.bar.barSize : 0
      color: prefs.bar ? prefs.bar.mainSurfaceColor : "transparent"
      radius: prefs.bar && prefs.bar.floating ? prefs.bar.islandRounding : 0
      borderSpec: prefs.bar && prefs.bar.floating ? prefs.bar.islandBorder : Border.none()
      shadowEnabled: !!preview.effects.shadow
      shadowSize: preview.effects.shadowSize || 0
      shadowOpacity: preview.effects.shadowOpacity || 0
    }
    Repeater {
      model: ["left", "center", "right"]
      Item {
        required property string modelData
        readonly property var shown: prefs.layoutEntries.filter(function(e) {
          return e.section === modelData && e.mode === "shown"
            && (prefs.snapshots[e.instanceKey] || prefs.cachedImageUrl(e.instanceKey) !== "")
        }).slice(0, 4)
        readonly property real contentWidth: zoneRow.implicitWidth + (prefs.bar ? prefs.bar.islandPadding * 2 : 0)
        width: contentWidth
        height: prefs.bar ? prefs.bar.barSize : 0
        y: preview.barY
        x: modelData === "left" ? preview.gap
          : modelData === "right" ? preview.width - preview.gap - width
          : (preview.width - width) / 2
        visible: shown.length > 0
        EffectSurface {
          anchors.fill: parent
          visible: prefs.bar && prefs.bar.islands
          color: prefs.bar ? prefs.bar.mainSurfaceColor : "transparent"
          radius: prefs.bar ? prefs.bar.islandRounding : 0
          borderSpec: prefs.bar ? prefs.bar.islandBorder : Border.none()
          shadowEnabled: !!preview.effects.shadow
          shadowSize: preview.effects.shadowSize || 0
          shadowOpacity: preview.effects.shadowOpacity || 0
        }
        Row {
          id: zoneRow
          anchors.centerIn: parent
          spacing: prefs.bar ? Math.max(Style.space(2), prefs.bar.widgetSpacing) : 0
          Repeater {
            model: parent.parent.shown
            // Live on a horizontal bar, otherwise the saved horizontal look:
            // the preview is always a horizontal bar.
            WidgetIcon {
              required property var modelData
              preferences: prefs
              record: modelData
              size: prefs.bar ? prefs.bar.themeBarSize : Style.font.iconLarge
              maxAspect: 40
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
