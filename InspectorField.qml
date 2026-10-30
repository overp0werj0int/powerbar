import QtQuick
import qs.Ui

// A text field in an inspector that writes to what it was opened for
// (a37aa7f): a press on the boards selects the next group or widget before
// this field loses focus and finishes, so `subject` is taken when focus
// comes, not when typing ends. While it is not being edited it shows `saved`,
// the saved value of whatever the inspector shows now (typing breaks a plain
// binding).
TextField {
    id: field
    // What the typing is for now (null: nothing).
    required property var subject
    required property string saved
    // The subject focus came for.
    property var editing: null
    // Typing finished for `subject` as it was when focus came, never null.
    signal committed(var subject, string text)
    Binding on text {
        value: field.saved
        when: !field.activeFocus
        restoreMode: Binding.RestoreNone
    }
    onActiveFocusChanged: if (activeFocus)
        editing = subject
    onEditingFinished: if (editing)
        committed(editing, text)
}
