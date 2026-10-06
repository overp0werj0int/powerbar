import QtQuick
Item {
  property var bar: null
  property bool opened: false
  property int page: 0
  function show(screen) {}
  function close() {}
  function setPage(p) { page = p }
  function showGroup(screen, id) {}
}
