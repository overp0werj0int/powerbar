import QtQuick

// The live items a page looks up by what they draw (a plate by its layer, a
// tile by its zone): each adds itself on completion and removes itself on
// destruction, so `items` is always the live ones, in creation order. Only
// add and remove write it.
QtObject {
    property var items: []
    function add(item) {
        items = items.concat([item]);
    }
    function remove(item) {
        items = items.filter(function (x) {
            return x !== item;
        });
    }
    // The first item `test` accepts, or null.
    function find(test) {
        return items.find(test) || null;
    }
}
