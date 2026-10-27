import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// The Tuning page (docs/behavior/preferences.md PREFS-132), there only with
// `powerbarTuning` on (INTEG-155): the development numbers behind the look as
// faders on a desk (DeskPage) under the same camera, so what they change
// shows as they move. One strip per section of TuningModel.SECTIONS, the
// values in Tuning (the singleton), and a Debugging strip with the frame log
// switch. Adding a number is one line in the model and one binding where it
// is read.
DeskPage {
  id: page
  pageLines: [
    {
      keys: "j k",
      label: "Down the strip, on to the next"
    },
    {
      keys: "h l",
      label: "Less, more on a fader (shift: five steps)"
    },
    {
      keys: "backspace",
      label: "Back to the default"
    },
    {
      keys: "tab",
      label: "Next strip"
    },
    {
      keys: "4",
      label: "Behavior: how the bar comes, goes and answers keys"
    }
  ]

  // A fader for one number: it applies as it moves, so the look follows a
  // drag; the file is written once it rests.
  component TuningFader: Fader {
    required property var modelData
    label: modelData.label
    unit: modelData.unit
    minimum: modelData.min
    maximum: modelData.max
    stepSize: 1
    defaultValue: modelData.value
    value: Tuning.values[modelData.key]
    animate: page.animate
    formatter: function (v) {
      return modelData.key === "octaves" && v === 1 ? "1 octave" : "";
    }
    onDrafted: function (v) {
      if (!isNaN(v))
        Tuning.set(modelData.key, v);
    }
    onEdited: function (v) {
      Tuning.set(modelData.key, v);
    }
  }

  Repeater {
    model: Tuning.sections
    DeskStrip {
      id: strip
      required property var modelData
      title: modelData.title
      caption: modelData.caption
      faders: [
        Repeater {
          model: strip.modelData.params
          TuningFader {}
        }
      ]
    }
  }

  DeskStrip {
    title: "Debugging"
    caption: "For a session with an agent. Nothing of it runs while off."
    footnote: "The numbers are kept in " + Tuning.path + " while this page is on; the defaults are what ships."
    DeskRow {
      label: "Frame log"
      caption: "The bar's event timeline and the frame timing of its motions, in the shell log."
      checked: page.preferences.options.frameLog
      onActivated: page.preferences.setOption("powerbarFrameLog", checked ? undefined : true)
    }
  }
}
