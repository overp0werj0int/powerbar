import QtQuick
import QtQuick.Layouts
import qs.Commons

// A caption under the control it explains, a text pair's xxs below it in a
// column m apart (PREFS-133); dim when it says why it is off.
InkText {
    property bool dim: false
    Layout.fillWidth: true
    Layout.topMargin: Gap.xxs - Gap.m
    role: "caption"
    disabled: dim
    wrapMode: Text.WordWrap
}
