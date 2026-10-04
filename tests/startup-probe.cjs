// Extract the real startup bindings/chrome; no native shell or commands run.
// Emit into a temporary directory, then run it with qmltestrunner.
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const repo = path.resolve(__dirname, '..');
const bar = fs.readFileSync(path.join(repo, 'Bar.qml'), 'utf8');
const editor = fs.readFileSync(path.join(repo, 'LayoutEditor.qml'), 'utf8');
function block(source, marker) {
  const start = source.indexOf(marker);
  if (start < 0) throw new Error('Missing source block: ' + marker);
  let end = source.indexOf('{', start), depth = 1;
  while (depth && ++end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(start, end + 1);
}
const badge = block(bar, 'Rectangle {\n      id: cellBadge').replaceAll('Style.', 'fixtureStyle.').replaceAll('Color.', 'fixturePalette.');
const cells = block(editor, 'readonly property var cellEntries:');
const members = block(editor, 'function members(');
const dir = path.resolve(process.argv[2] || '/tmp/powerbar-startup-probe');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, 'tst_Startup.qml'), `import QtQuick
import QtTest
import ${JSON.stringify(pathToFileURL(repo).href)}
import ${JSON.stringify(pathToFileURL(path.join(repo, 'PreferencesModel.js')).href)} as Model
import ${JSON.stringify(pathToFileURL(path.join(repo, 'CellModel.js')).href)} as CellModel
TestCase {
  id: root
  name: "PowerbarStartupBindings"
  when: windowShown
  width: 400; height: 200
  property bool islands: false
  property bool animationsEnabled: false
  property var cellTokens: ({})
  property real highlightRadius: 4
  function cellHighlight() { return {x: 5, y: 5, width: 30, height: 22, radius: 4} }
  QtObject {
    id: fixtureStyle
    property var font: ({family: "Sans Serif", caption: 12})
    function space(n) { return n }
  }
  QtObject { id: fixturePalette; property color urgent: "red"; property color accent: "blue"; property color background: "white" }
  Item {
    id: slot
    width: 30; height: 26
    property bool groupHeader: true
    property var activeItem: ({badge: {count: 5, urgent: false}})
    property var groupConfig: ({badge: true})
    property bool mainVisible: true
    property var preview: ({hidden: false})
    property bool dragSource: false
    property real cellLength: 30
  }
  Item { id: layer; width: 400; height: 200 }
  QtObject { id: barHighlight; property Item hostLayer: layer; property Item island: null }
  Component { id: badgeFactory; ${badge} }
  Component {
    id: editorFactory
    Item {
      id: editor
      // During QML construction consumers can run before the cache binding.
      property var initialItems: members("left", "shown", "")
      property var entries: [{section: "left", mode: "shown", index: 0, instanceKey: "first"}]
      property var preferences: ({})
      property int anchorIndex: -1
      function columnsFor(mode) { return Model.columns(mode, anchorIndex >= 0) }
      ${cells}
      ${members}
    }
  }
  Component {
    id: coldEditorFactory
    Item {
      // Exercise the real consumer before the cache is available, as in the
      // host's startup warning, then publish the cache and check recovery.
      property var cellEntries
      property var initialItems: members("left", "shown", "")
      ${members}
    }
  }
  function test_badgeHasLabelAndResizes() {
    failOnWarning(/ReferenceError|TypeError/)
    var badge = createTemporaryObject(badgeFactory, root)
    verify(badge)
    var label = badge.children.find(function(child) { return child.text !== undefined })
    verify(label, "The group count label must be present")
    compare(label.text, "5")
    verify(badge.width >= label.implicitWidth + 5)
    slot.activeItem = {badge: {count: 120, urgent: true}}
    compare(label.text, "99+")
    compare(badge.color, Qt.color("red"))
  }
  function test_editorCacheDuringConstruction() {
    failOnWarning(/ReferenceError|TypeError/)
    var editor = createTemporaryObject(editorFactory, root)
    verify(editor)
    compare(editor.initialItems.length, 1)
    compare(editor.initialItems[0].instanceKey, "first")
    editor.entries = []
    compare(editor.initialItems.length, 0)
  }
  function test_editorConsumerBeforeCacheArrives() {
    failOnWarning(/ReferenceError|TypeError/)
    var editor = createTemporaryObject(coldEditorFactory, root)
    verify(editor)
    compare(editor.initialItems.length, 0)
    editor.cellEntries = {"left:shown": [{instanceKey: "first"}]}
    compare(editor.initialItems.length, 1)
    compare(editor.initialItems[0].instanceKey, "first")
  }
}
`);
console.log(dir);
