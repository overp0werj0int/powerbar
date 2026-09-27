import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "AppearanceModel.js" as AppearanceModel
import "GroupsModel.js" as Groups

Item {
  id: prefs
  property var bar: null
  property bool opened: false
  property var targetScreen: null
  property int page: 0
  property string status: "Changes save automatically"
  readonly property var config: bar ? bar.barConfig : ({})
  readonly property var entries: Model.records(config.layout, function(id) { var widgets = bar.barWidgetRegistry.widgets; return bar.barWidgetRegistry.metadataFor(id) })
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
  readonly property var sections: ["left", "center", "right"]
  readonly property var modes: ["shown", "managed", "hidden"]

  function revealGeneralControl(item) {
    var view = (prefs.page === 3 ? appearanceScroll : generalScroll).contentItem
    if (!view || !view.contentItem) return
    var point = item.mapToItem(view.contentItem, 0, 0)
    if (point.y < view.contentY) view.contentY = point.y
    else if (point.y + item.height > view.contentY + view.height)
      view.contentY = point.y + item.height - view.height
  }
  function open(payloadJson) {
    bar.closeManagedDrawer()
    bar.clearTooltip()
    bar.requestPopout(prefs)
    opened = true
    Qt.callLater(function() { [generalTab, layoutTab, groupsTab, appearanceTab][prefs.page].forceActiveFocus() })
  }
  function close() {
    opened = false
    if (bar) bar.releasePopout(prefs)
  }
  function show(screen) { targetScreen = screen; open("{}") }
  function showGroup(screen, id) { groupsEditor.selectedId = id; page = 2; show(screen) }
  function title(record) {
    if (record.groupId) return record.label
    var metadata = bar.barWidgetRegistry.metadataFor(record.id)
    return metadata && (metadata.displayName || metadata.name) || record.id.split('.').pop()
  }
  function iconFont(record) { return Groups.iconFont(icon(record)) || Style.font.family }
  function icon(record) { return record.groupId ? record.icon : Model.icon(record.id) }
  function setOption(key, value) {
    if (!bar || !bar.shell) return
    var result = bar.shell.mutateShellConfig(function(config) {
      if (!config.bar) config.bar = {}
      config.bar[key] = value
    })
    status = result === false ? "Could not save preferences" : "Changes save automatically"
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
    status = accepted === false ? "Could not save layout" : changed ? "Layout updated" : "Layout changed elsewhere. Select the widget again."
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
      color: Qt.rgba(0, 0, 0, 0.38)
      MouseArea { anchors.fill: parent; onClicked: prefs.close() }
    }

    BorderSurface {
      id: surface
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(40), Style.space(1240))
      height: Math.min(parent.height - Style.space(56), Style.space(800))
      color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
      radius: Style.cornerRadius
      focus: true
      Keys.onEscapePressed: prefs.close()
      // Ctrl+1/2 switches pages without walking the entire grid.
      Keys.onPressed: function(event) {
        if (event.modifiers & Qt.ControlModifier) {
          if (event.key === Qt.Key_1) { prefs.page = 0; generalTab.forceActiveFocus(); event.accepted = true }
          if (event.key === Qt.Key_2) { prefs.page = 1; layoutTab.forceActiveFocus(); event.accepted = true }
          if (event.key === Qt.Key_4) { prefs.page = 3; appearanceTab.forceActiveFocus(); event.accepted = true }
          if (event.key === Qt.Key_3) { prefs.page = 2; groupsTab.forceActiveFocus(); event.accepted = true }
        }
      }
      MouseArea { anchors.fill: parent } // Contain clicks inside the card.

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.space(22)
        spacing: Style.space(24)
        ColumnLayout {
          Layout.preferredWidth: Style.space(156)
          Layout.minimumWidth: Style.space(156)
          Layout.maximumWidth: Style.space(156)
          Layout.fillHeight: true
          spacing: Style.space(10)
          Label { text: "POWERBAR"; font.pixelSize: Style.font.body; font.bold: true; color: Color.accent; Layout.topMargin: Style.space(8) }
          Label { text: "Preferences"; color: Qt.alpha(Color.popups.text, 0.65); Layout.bottomMargin: Style.space(26) }
          Button {
            id: generalTab
            text: "General"; iconText: "󰒓"; selected: prefs.page === 0
            focusable: true; leftAlign: true; Layout.fillWidth: true
            onClicked: prefs.page = 0
            Keys.onDownPressed: { prefs.page = 1; layoutTab.forceActiveFocus() }
          }
          Button {
            id: layoutTab
            text: "Layout"; iconText: "󰙀"; selected: prefs.page === 1
            focusable: true; leftAlign: true; Layout.fillWidth: true
            onClicked: prefs.page = 1
            Keys.onUpPressed: { prefs.page = 0; generalTab.forceActiveFocus() }
            Keys.onDownPressed: { prefs.page = 2; groupsTab.forceActiveFocus() }
          }
          Button {
            id: groupsTab
            text: "Groups"; iconText: "󰉋"; selected: prefs.page === 2
            focusable: true; leftAlign: true; Layout.fillWidth: true
            onClicked: prefs.page = 2
            Keys.onUpPressed: { prefs.page = 1; layoutTab.forceActiveFocus() }
            Keys.onDownPressed: { prefs.page = 3; appearanceTab.forceActiveFocus() }
          }
          Button {
            id: appearanceTab
            text: "Appearance"; iconText: "󰏘"; selected: prefs.page === 3
            focusable: true; leftAlign: true; Layout.fillWidth: true
            onClicked: prefs.page = 3
            Keys.onUpPressed: { prefs.page = 2; groupsTab.forceActiveFocus() }
          }
          Item { Layout.fillHeight: true }
          Label { text: "Ctrl+1 / 2 / 3 / 4\nSwitch pages"; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall }
        }
        Rectangle { Layout.fillHeight: true; width: 1; color: Color.popups.border; opacity: 0.25 }
        ColumnLayout {
          Layout.fillWidth: true; Layout.fillHeight: true
          spacing: Style.space(16)
          RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
              Layout.fillWidth: true
              Label { text: prefs.page === 3 ? "One consistent appearance" : prefs.page === 0 ? "Make it your bar" : prefs.page === 2 ? "A place for everything" : "Everything in its place"; font.pixelSize: Style.space(25); font.bold: true }
              Label { text: prefs.page === 3 ? "Shared by the full bar, main islands, and every extended island." : prefs.page === 0 ? "Placement and behavior, across all your screens." : prefs.page === 2 ? "Named drawers for related widgets. Hover to open, click to pin." : "Drag widgets between zones. Drop onto a widget to place before it."; color: Qt.alpha(Color.popups.text, 0.65); Layout.fillWidth: true; wrapMode: Text.WordWrap }
            }
            Button { text: "✕"; tooltipText: "Close · Esc"; focusable: true; onClicked: prefs.close() }
          }

          Controls.ScrollView {
            id: generalScroll
            visible: prefs.page === 0
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
              width: parent.width
              spacing: Style.space(22)
              SettingGroup {
                title: "POSITION"
                description: "Choose the screen edge for your bar."
                RowLayout {
                  Repeater {
                    model: ["top", "bottom", "left", "right"]
                    Button {
                      required property string modelData
                      text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                      selected: prefs.bar.position === modelData; bordered: true; focusable: true
                      onClicked: prefs.setOption("position", modelData)
                    }
                  }
                }
              }
              SettingGroup {
                title: "BAR STYLE"
                description: "Choose a continuous bar or separate zone islands, and whether the bar hides."
                Controls.CheckBox {
                  text: "Animations"
                  checked: prefs.bar.animationsEnabled
                  onToggled: prefs.setOption("powerbarAnimations", checked)
                  onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
                  font.family: Style.font.family
                  palette.windowText: Color.popups.text
                  palette.highlight: Color.accent
                  Accessible.description: "Subtle spring movement for main and extended islands"
                }
                Controls.CheckBox {
                  text: "Islands"
                  checked: prefs.config.powerbarIslands === true
                  onToggled: prefs.setOption("powerbarIslands", checked)
                  font.family: Style.font.family
                  palette.windowText: Color.popups.text
                  palette.button: Color.popups.background
                  palette.buttonText: Color.popups.text
                  palette.highlight: Color.accent
                  Accessible.description: "Separate bar zones with themed borders and rounding on a transparent background"
                }
                Label {
                  text: "Separate zones into themed islands on a transparent background."
                  color: Qt.alpha(Color.popups.text, 0.65)
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                }
                Controls.CheckBox {
                  text: "Autohide"
                  checked: prefs.config.powerbarAutoHide === true
                  onToggled: prefs.setOption("powerbarAutoHide", checked)
                  font.family: Style.font.family
                  palette.windowText: Color.popups.text
                  palette.button: Color.popups.background
                  palette.buttonText: Color.popups.text
                  palette.highlight: Color.accent
                  Accessible.description: "Hide the bar past the screen edge and slide it over windows when the pointer reaches the edge"
                }
                Label {
                  text: "Slide the bar over windows only when the pointer reaches the screen edge."
                  color: Qt.alpha(Color.popups.text, 0.65)
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                }

              }
              SettingGroup {
                title: "CENTER ANCHOR"
                description: "Keep one widget at the exact screen center, or center the whole group."
                Controls.ComboBox {
                  id: anchorCombo
                  Layout.preferredWidth: Style.space(320)
                  model: [{ label: "Center as a group", value: "" }].concat(prefs.layoutEntries.filter(function(e) { return e.section === "center" && e.mode !== "hidden" }).map(function(e) { return { label: prefs.title(e), value: e.id } }))
                  textRole: "label"; valueRole: "value"
                  currentIndex: { for (var i = 0; i < model.length; i++) if (model[i].value === prefs.bar.centerAnchor) return i; return 0 }
                  onActivated: prefs.setOption("centerAnchor", currentValue)
                  palette.button: Color.popups.background; palette.buttonText: Color.popups.text
                  palette.base: Color.popups.background; palette.text: Color.popups.text; palette.highlight: Color.accent
                  font.family: Style.font.family
                }
              }
              SettingGroup {
                title: "MANAGED WIDGETS"
                description: "Reveal on events, icon or value changes. Hover a zone to access its managed widgets."
                NumberSlider {
                  label: "Activity reveal"; unit: "s"; minimum: 1; maximum: 60
                  value: prefs.bar.managedRevealSeconds
                  onEdited: function(value) { prefs.setOption("powerbarManagedRevealSeconds", value) }
                }
                NumberSlider {
                  label: "Time to enter drawer"; unit: "s"; minimum: 1; maximum: 15
                  value: prefs.bar.managedEntrySeconds
                  onEdited: function(value) { prefs.setOption("powerbarManagedEntryGraceSeconds", value) }
                }
                NumberSlider {
                  label: "Delay after leaving drawer"; unit: "s"; minimum: 1; maximum: 15
                  value: prefs.bar.managedExitSeconds
                  onEdited: function(value) { prefs.setOption("powerbarManagedExitGraceSeconds", value) }
                }
                Button {
                  text: "Reset managed timing"; focusable: true
                  onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
                  onClicked: prefs.bar.shell.mutateShellConfig(function(config) {
                    delete config.bar.powerbarManagedRevealSeconds
                    delete config.bar.powerbarManagedEntryGraceSeconds
                    delete config.bar.powerbarManagedExitGraceSeconds
                  })
                }
              }
              SettingGroup {
                title: "SPACING"
                description: "Space between widgets on the bar."
                NumberSlider {
                  label: "Widget spacing"
                  minimum: 0; maximum: 24
                  value: Number(prefs.config.powerbarSpacing || 0)
                  onEdited: function(value) { prefs.setOption("powerbarSpacing", value) }
                }
              }
            }
          }

          Controls.ScrollView {
            id: appearanceScroll
            visible: prefs.page === 3
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: availableWidth; clip: true
            ColumnLayout {
              width: parent.width; spacing: Style.space(20)
              SectionHeading { title: "APPEARANCE"; Layout.fillWidth: true }
              RowLayout {
                Layout.fillWidth: true; spacing: Style.space(32)
              SettingGroup {
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                title: "BORDERS AND ROUNDING"
                description: "Border color follows your theme. Thickness and rounding can be customized."
                Controls.CheckBox {
                  text: "Show borders"
                  checked: prefs.config.powerbarIslandBorders !== false
                  onToggled: prefs.setOption("powerbarIslandBorders", checked)
                  font.family: Style.font.family
                  palette.windowText: Color.popups.text
                  palette.highlight: Color.accent
                }
                NumberSlider {
                  label: "Border thickness"
                  minimum: 0; maximum: 4; stepSize: 0.5
                  value: typeof prefs.config.powerbarIslandBorderWidth === "number"
                    ? prefs.config.powerbarIslandBorderWidth : Border.top(prefs.bar.themeIslandBorder) / Style.space(1)
                  enabled: prefs.config.powerbarIslandBorders !== false
                  onEdited: function(value) { prefs.setOption("powerbarIslandBorderWidth", value) }
                }
                NumberSlider {
                  label: "Corner rounding"
                  minimum: 0; maximum: 32
                  value: prefs.bar.islandRounding / Style.space(1)
                  onEdited: function(value) { prefs.setOption("powerbarIslandRounding", value) }
                }
                Button {
                  text: "Use theme borders and rounding"; focusable: true
                  onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
                  onClicked: {
                    prefs.bar.shell.mutateShellConfig(function(config) {
                      delete config.bar.powerbarIslandBorders
                      delete config.bar.powerbarIslandBorderWidth
                      delete config.bar.powerbarIslandRounding
                    })
                  }
                }
              }
              EffectsGroup { Layout.preferredWidth: 1; Layout.alignment: Qt.AlignTop }
              }
            }
          }

          OrganizationGrid {
            preferences: prefs; visible: prefs.page === 1
            entries: prefs.layoutEntries
            onMove: function(record, section, mode, before) { prefs.move(record, section, mode, before) }
          }
          GroupsPreferences { id: groupsEditor; preferences: prefs; visible: prefs.page === 2; Layout.fillWidth: true; Layout.fillHeight: true }
          Label { text: prefs.status; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall }
        }
      }

    }
  }
  component Label: Text {
    textFormat: Text.PlainText
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
  component EffectsGroup: SettingGroup {
    id: effectsGroup
    readonly property string prefix: "powerbar"
    readonly property var effects: prefs.bar.surfaceEffects
    title: "SURFACE AND SHADOW"
    description: "Blur uses your desktop's blur strength. Shadows follow the surface's shape."
    Controls.CheckBox {
      text: "Background blur"
      checked: effectsGroup.effects.blur
      onToggled: prefs.setOption(effectsGroup.prefix + "Blur", checked)
      onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
      font.family: Style.font.family
      palette.windowText: Color.popups.text; palette.highlight: Color.accent
    }
    NumberSlider {
      label: "Background opacity"; unit: "%"; minimum: 0; maximum: 100
      value: effectsGroup.effects.backgroundOpacity * 100
      onEdited: function(value) { prefs.setOption(effectsGroup.prefix + "BackgroundOpacity", value) }
    }
    Controls.CheckBox {
      text: "Show shadow"
      checked: effectsGroup.effects.shadow
      onToggled: prefs.setOption(effectsGroup.prefix + "Shadow", checked)
      onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
      font.family: Style.font.family
      palette.windowText: Color.popups.text; palette.highlight: Color.accent
    }
    NumberSlider {
      label: "Shadow softness"; minimum: 0; maximum: 32
      value: effectsGroup.effects.shadowSize
      enabled: effectsGroup.effects.shadow
      onEdited: function(value) { prefs.setOption(effectsGroup.prefix + "ShadowSize", value) }
    }
    NumberSlider {
      label: "Shadow opacity"; unit: "%"; minimum: 0; maximum: 45
      value: effectsGroup.effects.shadowOpacity * 100
      enabled: effectsGroup.effects.shadow
      onEdited: function(value) { prefs.setOption(effectsGroup.prefix + "ShadowOpacity", value) }
    }
    Button {
      text: "Reset appearance"; focusable: true
      onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(this)
      onClicked: prefs.bar.shell.mutateShellConfig(function(config) {
        AppearanceModel.reset(config.bar)
      })
    }
  }

  component NumberSlider: ColumnLayout {
    id: control
    property string label: ""
    property string unit: "px"
    property real minimum: 0
    property real maximum: 100
    property real stepSize: 1
    property real value: 0
    signal edited(real value)
    Layout.fillWidth: true
    Layout.maximumWidth: Style.space(520)
    spacing: Style.space(4)
    RowLayout {
      Layout.fillWidth: true
      Label { text: control.label; Layout.fillWidth: true }
      Label {
        text: (control.stepSize < 1 ? slider.snappedValue.toFixed(1) : Math.round(slider.snappedValue)) + " " + control.unit
        color: Color.accent
      }
    }
    Controls.Slider {
      id: slider
      Layout.fillWidth: true
      from: control.minimum; to: control.maximum
      stepSize: control.stepSize
      snapMode: Controls.Slider.SnapAlways
      value: control.value
      // Qt's own drag-time snapping (stepSize + SnapAlways) doesn't reliably
      // hold the handle to sub-1 steps, so the visuals below snap explicitly
      // instead of trusting slider.visualPosition/value during a drag.
      readonly property real snappedValue: Math.round(value / control.stepSize) * control.stepSize
      readonly property real snappedVisualPosition: (snappedValue - from) / (to - from)
      onMoved: control.edited(snappedValue)
      onActiveFocusChanged: if (activeFocus) prefs.revealGeneralControl(control)
      Accessible.name: control.label
      background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth; height: Style.space(4)
        radius: height / 2
        color: Qt.alpha(Color.popups.text, 0.18)
        Rectangle {
          width: slider.snappedVisualPosition * parent.width; height: parent.height
          radius: parent.radius; color: Color.accent
        }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.snappedVisualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        implicitWidth: Style.space(18); implicitHeight: implicitWidth
        radius: width / 2
        color: slider.pressed ? Color.popups.text : Color.accent
        border.width: slider.activeFocus ? Style.space(2) : 0
        border.color: Color.popups.text
      }
    }
  }
  component SettingGroup: ColumnLayout {
    property string title: ""
    property string description: ""
    Layout.fillWidth: true
    spacing: Style.space(10)
    Label { text: parent.title; font.bold: true; color: Color.accent; font.pixelSize: Style.font.bodySmall }
    Label { text: parent.description; color: Qt.alpha(Color.popups.text, 0.65); Layout.fillWidth: true; wrapMode: Text.WordWrap }
  }
}
