import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "IconSearch.js" as IconSearch
import "OmarchyIcons.js" as OmarchyIcons
import "GroupsModel.js" as GroupsModel

// The group icon picker (docs/behavior/preferences.md): a popover over the Groups
// page, under the icon well. Its icons are the glyphs your widgets draw,
// Omarchy's own font and the Nerd Font glyphs Omarchy uses, and Omarchy's
// emoji, about 2,170 in all; or your own SVG or PNG, dropped or pasted.
//
// Focus stays in the search field, as in Omarchy's emoji picker: typing
// searches, the arrows walk the grid across sections, Enter chooses, Tab
// changes the source, Esc clears the search and then closes.
Item {
  id: picker
  required property var preferences
  readonly property var bar: preferences.bar
  // The group the picker edits, and the item it opens under.
  property var group: null
  property Item anchorItem: null
  property bool opened: false
  // { icon, iconFont } or { iconImage, iconTint }
  signal chosen(var patch)
  signal closed()

  property string query: ""
  property string source: "all"
  property int cursor: 0
  readonly property var sources: [
    { value: "all", label: "All" }, { value: "bar", label: "On your bar" }, { value: "omarchy", label: "Omarchy" },
    { value: "emoji", label: "Emoji" }, { value: "own", label: "Your own" }
  ]
  readonly property real cellSize: Style.space(38)
  readonly property int columns: Math.max(1, Math.floor((grid.width + Style.space(2)) / (cellSize + Style.space(2))))
  readonly property var hints: source === "own"
    ? [{ keys: "h l", label: "Colour" }, { keys: "enter", label: "Use it" }, { keys: "tab", label: "Source" }, { keys: "esc", label: "Close" }]
    : [{ keys: "↑ ↓ ← →", label: "Move" }, { keys: "enter", label: "Choose" }, { keys: "tab", label: "Source" },
      { keys: "ctrl+v", label: "Paste" }, { keys: "esc", label: query ? "Clear search" : "Close" }]

  function open(group, anchorItem) {
    picker.group = group
    picker.anchorItem = anchorItem
    query = ""
    field.text = ""
    source = "all"
    own = null
    ownError = ""
    tint = "text"
    emojiFile.path = emojiPath
    // Images imported before and never used (or no longer used) go now, while
    // nothing is pending and the saved groups are settled.
    iconSweep.running = true
    rebuildIndex()
    cursor = Math.max(0, results.findIndex(function(i) { return isCurrent(i) }))
    opened = true
    Qt.callLater(function() { field.forceActiveFocus(); revealCursor() })
  }
  function close() {
    if (!opened) return
    opened = false
    closed()
  }

  // ------------------------------------------------------------- the icons
  readonly property string emojiPath: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/shell/plugins/emojis/emojis.json"
  property var emoji: []
  FileView {
    id: emojiFile
    onLoaded: {
      try { picker.emoji = JSON.parse(text()) } catch (e) { picker.emoji = [] }
      if (picker.opened) picker.rebuildIndex()
    }
  }
  // The glyph each widget on the bar draws, named by the widget.
  function barGlyphs() {
    var read = bar && bar.widgetGlyphs ? bar.widgetGlyphs : {}
    return preferences.entries.filter(function(e) { return read[e.instanceKey] && (read[e.instanceKey].parts || 1) === 1 }).map(function(e) {
      var g = read[e.instanceKey]
      return { glyph: g.glyph, font: g.font === "omarchy" ? "omarchy" : "", name: preferences.title(e) }
    })
  }
  property var index: []
  function rebuildIndex() {
    index = IconSearch.index({ bar: barGlyphs(), logos: OmarchyIcons.logos, glyphs: OmarchyIcons.glyphs, emoji: emoji })
  }
  function sourceOf(item) { return item.source === IconSearch.BAR ? "bar" : item.source === IconSearch.OMARCHY ? "omarchy" : "emoji" }
  readonly property var results: {
    if (source === "own") return []
    var list = query.trim() ? IconSearch.search(index, query) : index
    var src = source
    return src === "all" ? list : list.filter(function(i) { return picker.sourceOf(i) === src })
  }
  // A single glyph or emoji in the search is offered as itself, first.
  readonly property string pasted: IconSearch.pastedGlyph(query)
  readonly property var offered: pasted && !results.some(function(i) { return i.glyph === pasted })
    ? [{ glyph: pasted, font: "", name: "Pasted", source: -1, logo: false, words: [] }].concat(results) : results
  readonly property var rowList: IconSearch.rows(offered, columns, !query.trim() && source === "all")
  readonly property var current: offered[cursor] || null
  function isCurrent(item) {
    return !!group && !group.iconImage && item.glyph === group.icon && (item.font || "") === (group.iconFont || "")
  }
  onQueryChanged: { cursor = 0; Qt.callLater(revealCursor) }
  onSourceChanged: { cursor = 0; Qt.callLater(revealCursor) }

  function move(to) {
    if (!offered.length) return
    cursor = Math.max(0, Math.min(offered.length - 1, to))
    revealCursor()
  }
  function revealCursor() {
    for (var r = 0; r < rowList.length; r++) {
      var items = rowList[r].items
      if (items.length && items[0].at <= cursor && cursor <= items[items.length - 1].at) { grid.positionViewAtIndex(r, ListView.Contain); return }
    }
  }
  function choose() {
    if (source === "own") {
      if (own) chosen({ iconImage: own.path, iconTint: tint })
      return
    }
    var item = current
    if (item) chosen({ icon: item.glyph, iconFont: item.font || "" })
  }

  // ------------------------------------------------------- your own icon
  // { path, name }: your file, copied to Powerbar's icon folder.
  property var own: null
  property string ownError: ""
  property string tint: "text"
  readonly property string iconDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/powerbar/icons"
  Process {
    id: iconSweep
    command: ["sh", "-c", 'ls -1A -- "$1" 2>/dev/null', "sh", picker.iconDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var stale = GroupsModel.unreferencedIcons(text.split("\n"), picker.bar ? picker.bar.barConfig : null, picker.iconDir)
        if (stale.length) Quickshell.execDetached(["rm", "-f", "--"].concat(stale))
      }
    }
  }
  function extensionOf(path) {
    var m = String(path).toLowerCase().match(/\.(svg|png)$/)
    return m ? m[1] : ""
  }
  function destinationFor(name, ext) { return iconDir + "/" + Qt.md5(name + Date.now()).slice(0, 12) + "." + ext }
  // A file you dropped, pasted or typed: checked, then copied.
  function takeFile(path) {
    var ext = extensionOf(path)
    source = "own"
    if (!ext) { ownError = "Only SVG or PNG files. " + path.split("/").pop() + " is neither."; return }
    var dest = destinationFor(path, ext)
    copier.name = path.split("/").pop()
    copier.dest = dest
    copier.command = ["sh", "-c", 'f=$1; d=$2; [ -f "$f" ] || exit 3; [ "$(stat -c %s -- "$f")" -le 524288 ] || exit 4; mkdir -p -- "${d%/*}" && cp -- "$f" "$d"',
      "sh", path, dest]
    copier.running = true
  }
  Process {
    id: copier
    property string name: ""
    property string dest: ""
    onExited: function(code) {
      if (code === 0) { picker.own = { path: dest, name: name }; picker.ownError = "" }
      else picker.ownError = code === 3 ? "Could not read " + name + "."
        : code === 4 ? name + " is over 512 KB. Icons are drawn 16 px tall; a smaller file is plenty."
        : "Could not copy " + name + " to " + picker.iconDir + "."
    }
  }
  // Ctrl+V: an image or a copied file becomes your own icon; anything else
  // pastes as text into the search, where a glyph or emoji is offered.
  function paste() {
    clipTypes.found = []
    clipTypes.running = true
  }
  Process {
    id: clipTypes
    property var found: []
    command: ["wl-paste", "--list-types"]
    stdout: SplitParser { onRead: function(line) { clipTypes.found.push(String(line).trim()) } }
    onExited: function(code) {
      var types = found
      var image = ["image/svg+xml", "image/png"].find(function(t) { return types.indexOf(t) >= 0 })
      if (code === 0 && image) {
        var dest = picker.destinationFor(image, image === "image/png" ? "png" : "svg")
        clipImage.dest = dest
        clipImage.command = ["sh", "-c", 'mkdir -p -- "${2%/*}" && timeout 2s wl-paste --type "$1" > "$2" && [ "$(stat -c %s -- "$2")" -le 524288 ] || { rm -f -- "$2"; exit 4; }',
          "sh", image, dest]
        clipImage.running = true
      } else if (code === 0 && types.indexOf("text/uri-list") >= 0) {
        clipUri.running = true
      } else field.paste()
    }
  }
  Process {
    id: clipImage
    property string dest: ""
    onExited: function(code) {
      picker.source = "own"
      if (code === 0) { picker.own = { path: dest, name: "Pasted image" }; picker.ownError = "" }
      else picker.ownError = code === 4 ? "The pasted image is over 512 KB." : "Could not read the pasted image."
    }
  }
  Process {
    id: clipUri
    command: ["wl-paste", "--type", "text/uri-list"]
    stdout: StdioCollector {
      onStreamFinished: {
        var first = String(text).split(/\r?\n/).find(function(l) { return l.indexOf("file://") === 0 })
        if (first) picker.takeFile(decodeURIComponent(first.slice(7)))
        else field.paste()
      }
    }
  }

  // ----------------------------------------------------------------- view
  visible: opened
  // A click outside the card closes it.
  MouseArea {
    anchors.fill: parent
    enabled: picker.opened
    onClicked: picker.close()
  }
  // A file dropped anywhere on the page while the picker is open.
  DropArea {
    anchors.fill: parent
    enabled: picker.opened
    onEntered: function(drag) { if (drag.hasUrls) picker.source = "own" }
    onDropped: function(drop) {
      if (!drop.hasUrls || !drop.urls.length) return
      picker.takeFile(decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, "")))
      drop.accept()
    }
  }

  BorderSurface {
    id: card
    readonly property point at: picker.anchorItem && picker.opened ? picker.anchorItem.mapToItem(picker, 0, picker.anchorItem.height + Style.space(6)) : Qt.point(0, 0)
    x: Math.max(Style.space(8), Math.min(picker.width - width - Style.space(8), at.x))
    y: Math.max(Style.space(8), Math.min(picker.height - height - Style.space(8), at.y))
    width: Math.min(picker.width - Style.space(16), Style.space(488))
    height: Math.min(picker.height - Style.space(16), Style.space(520))
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(1)))
    // Opens from the icon well: a short fade and scale, none with animations off.
    opacity: picker.opened ? 1 : 0
    scale: picker.opened ? 1 : 0.97
    transformOrigin: Item.TopLeft
    Behavior on opacity { enabled: picker.bar.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: picker.bar.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(6)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)
        TextField {
          id: field
          Layout.fillWidth: true
          foreground: Commons.Color.popups.text
          placeholderText: "Search " + picker.index.length.toLocaleString(Qt.locale("en_US"), "f", 0) + " icons, or paste one"
          Accessible.name: "Search icons"
          onTextChanged: picker.query = text
          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            var key = event.key, ctrl = event.modifiers & Qt.ControlModifier
            if (ctrl && key === Qt.Key_V) { picker.paste(); event.accepted = true; return }
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
            if (key === Qt.Key_Escape) {
              if (text !== "") text = ""
              else picker.close()
            } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
              // A typed path to an SVG or PNG is taken as your own icon.
              if (text.trim().indexOf("/") === 0 && picker.extensionOf(text.trim())) picker.takeFile(text.trim())
              else picker.choose()
            } else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
              var i = picker.sources.findIndex(function(s) { return s.value === picker.source })
              var step = key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1
              picker.source = picker.sources[(i + step + picker.sources.length) % picker.sources.length].value
            } else if (picker.source === "own") {
              if (key === Qt.Key_Left || key === Qt.Key_Right) picker.tint = picker.tint === "text" ? "own" : "text"
              else return
            } else if (key === Qt.Key_Right) picker.move(picker.cursor + 1)
            else if (key === Qt.Key_Left) picker.move(picker.cursor - 1)
            else if (key === Qt.Key_Down) picker.move(IconSearch.vertical(picker.rowList, picker.cursor, 1))
            else if (key === Qt.Key_Up) picker.move(IconSearch.vertical(picker.rowList, picker.cursor, -1))
            else if (key === Qt.Key_PageDown || key === Qt.Key_PageUp) {
              var to = picker.cursor, rows = Math.max(1, Math.floor(grid.height / picker.cellSize))
              for (var n = 0; n < rows; n++) to = IconSearch.vertical(picker.rowList, to, key === Qt.Key_PageDown ? 1 : -1)
              picker.move(to)
            } else return
            event.accepted = true
          }
        }
        Text {
          text: picker.source === "own" ? "" : picker.query.trim()
            ? picker.results.length + " found" : picker.offered.length.toLocaleString(Qt.locale("en_US"), "f", 0) + " icons"
          textFormat: Text.PlainText
          color: Qt.alpha(Commons.Color.popups.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      ButtonGroup {
        options: picker.sources
        value: picker.source
        focusable: false
        foreground: Commons.Color.popups.text
        background: "transparent"
        fontSize: Style.font.bodySmall
        Accessible.name: "Icon source"
        onChanged: function(value) { picker.source = value; field.forceActiveFocus() }
      }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Commons.Color.popups.text, 0.1) }

      // The grid: rows of icons under a header per source. Only the rows in
      // view exist.
      ListView {
        id: grid
        visible: picker.source !== "own"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: picker.rowList
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
          id: rowItem
          required property var modelData
          width: grid.width
          height: modelData.header ? Style.space(26) : picker.cellSize + Style.space(2)
          Text {
            visible: !!rowItem.modelData.header
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(4)
            x: Style.space(2)
            text: rowItem.modelData.header.toUpperCase()
            textFormat: Text.PlainText
            color: Qt.darker(Commons.Color.popups.text, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.6
          }
          Row {
            spacing: Style.space(2)
            Repeater {
              model: rowItem.modelData.items
              BorderSurface {
                id: cell
                required property var modelData
                readonly property var icon: modelData.item
                readonly property bool isCursor: modelData.at === picker.cursor
                readonly property bool pasted: icon.source === -1
                width: pasted ? Math.max(picker.cellSize, useLabel.implicitWidth + Style.space(44)) : picker.cellSize
                height: picker.cellSize
                radius: Math.max(0, Style.cornerRadius - Style.space(2))
                color: isCursor ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
                  : cellHover.hovered ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
                borderSpec: isCursor ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
                  : picker.isCurrent(icon) ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.5), 1) : Border.none()
                HoverHandler { id: cellHover; onHoveredChanged: if (hovered) picker.cursor = cell.modelData.at }
                Text {
                  x: cell.pasted ? Style.space(10) : (parent.width - width) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: cell.icon.glyph
                  textFormat: Text.PlainText
                  color: Commons.Color.popups.text
                  font.family: cell.icon.font || (picker.bar ? picker.bar.fontFamily : Style.font.family)
                  font.pixelSize: Style.font.iconLarge
                }
                Text {
                  id: useLabel
                  visible: cell.pasted
                  x: Style.space(36)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Use this"
                  textFormat: Text.PlainText
                  color: Commons.Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { picker.cursor = cell.modelData.at; picker.choose() }
                }
              }
            }
          }
        }
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.space(40)
          visible: picker.offered.length === 0
          text: picker.query.trim() ? "No icons match “" + picker.query.trim() + "”. Try a simpler word, or paste a glyph or emoji." : "No icons here."
          textFormat: Text.PlainText
          color: Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }

      // Your own: a drop area, and the file once it is in.
      ColumnLayout {
        visible: picker.source === "own"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.space(10)
        BorderSurface {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(170)
          radius: Math.max(0, Style.cornerRadius - Style.space(2))
          color: ownDrop.containsDrag ? Qt.alpha(Commons.Color.accent, 0.1) : "transparent"
          borderSpec: Border.flat(ownDrop.containsDrag ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.3), 1)
          DropArea { id: ownDrop; anchors.fill: parent }
          ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Style.space(40)
            spacing: Style.space(4)
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "󰉍"
              color: Qt.alpha(Commons.Color.popups.text, 0.7)
              font.family: Style.font.family
              font.pixelSize: Style.font.iconLarge * 1.4
            }
            Text {
              Layout.fillWidth: true
              text: "Drop an SVG or PNG here"
              textFormat: Text.PlainText
              color: Commons.Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }
            Text {
              Layout.fillWidth: true
              text: "or paste one with Ctrl+V, or type its path and press Enter. Up to 512 KB; Powerbar keeps its own copy."
              textFormat: Text.PlainText
              color: Qt.alpha(Commons.Color.popups.text, 0.65)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
            Text {
              Layout.fillWidth: true
              visible: picker.ownError !== ""
              text: picker.ownError
              textFormat: Text.PlainText
              color: Commons.Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }
        }
        RowLayout {
          visible: !!picker.own
          Layout.fillWidth: true
          spacing: Style.space(12)
          Island {
            group: picker.group && picker.own ? Object.assign({}, picker.group, { iconImage: picker.own.path, iconTint: picker.tint === "own" ? "own" : undefined }) : null
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Text {
              text: picker.own ? picker.own.name : ""
              textFormat: Text.PlainText
              color: Commons.Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideMiddle
              Layout.fillWidth: true
            }
            ButtonGroup {
              options: [{ value: "text", label: "Text colour" }, { value: "own", label: "Its own colours" }]
              value: picker.tint
              focusable: false
              foreground: Commons.Color.popups.text
              background: "transparent"
              fontSize: Style.font.bodySmall
              Accessible.name: "Icon colour"
              onChanged: function(value) { picker.tint = value; field.forceActiveFocus() }
            }
            Text {
              text: picker.tint === "text" ? "Drawn in the bar's text colour, like your other icons. A multicolour image shows as its outline."
                : "Keeps its colours; they won't follow Light or Dark."
              textFormat: Text.PlainText
              color: Qt.alpha(Commons.Color.popups.text, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
        Item { Layout.fillHeight: true }
      }

      // The icon under the cursor, drawn as the group's face on the bar.
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Commons.Color.popups.text, 0.1) }
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: picker.bar ? picker.bar.barSizeFor(false) + Style.space(4) : Style.space(40)
        spacing: Style.space(12)
        visible: picker.source !== "own"
        Island {
          group: picker.group && picker.current ? Object.assign({}, picker.group, { icon: picker.current.glyph,
            iconFont: picker.current.font || undefined, iconImage: undefined }) : null
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(1)
          Text {
            text: picker.current ? picker.current.name : "Nothing under the cursor"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: !picker.current ? "" : picker.current.source === -1 ? "Pasted, drawn in the bar's font"
              : picker.current.source === IconSearch.BAR ? "Drawn by a widget on your bar"
              : picker.current.logo ? "Omarchy's font" : picker.current.source === IconSearch.OMARCHY ? "Used by Omarchy"
              : "Emoji, keeps its own colours on the bar"
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
        KeyCap { text: "enter" }
        Text {
          text: "Choose"
          color: Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  // The face on an island of the bar's surface, at the bar's size: what the
  // bar will draw (icon only for an icon face, else the group's own face).
  component Island: BorderSurface {
    id: island
    property var group: null
    readonly property string mode: group && group.face === "text" ? "glyph" : ""
    implicitWidth: face.implicitWidth + Style.space(20)
    implicitHeight: picker.bar ? picker.bar.barSizeFor(false) : Style.space(36)
    color: picker.bar ? Qt.rgba(picker.bar.mainSurfaceColor.r, picker.bar.mainSurfaceColor.g, picker.bar.mainSurfaceColor.b, 1) : Commons.Color.popups.background
    radius: picker.bar ? Math.min(picker.bar.islandRounding, implicitHeight / 2) : 0
    borderSpec: picker.bar && picker.bar.islands ? picker.bar.islandBorder : Border.none()
    GroupFace {
      id: face
      anchors.centerIn: parent
      group: island.group
      faceMode: island.mode
      color: picker.bar ? picker.bar.barForeground : Commons.Color.popups.text
      fontFamily: picker.bar ? picker.bar.fontFamily : Style.font.family
      fontSize: Style.font.body
    }
  }
}
