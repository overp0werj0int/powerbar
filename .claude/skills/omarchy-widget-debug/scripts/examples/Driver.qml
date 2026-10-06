import QtQuick

// An example driver for framedebug.sh: copy it, then replace the steps.
// steps(h) returns [{ wait: ms before running, label, run }]. `h` is the
// harness: h.widget (the loaded widget), h.log(...), h.census(label, step),
// h.hitChain(x, y), h.recording, and the PluginBarApi the widget sees as h.widget.bar.
QtObject {
  function steps(h) {
    return [
      { wait: 400, label: "who takes a press, at rest", run: function() { h.census("rest", 6) } },
      // Change something the widget reacts to, then let frames record.
      { wait: 50, label: "bar grows", run: function() { h.widget.bar.barSize = 40 } },
      { wait: 600, label: "bar back", run: function() { h.widget.bar.barSize = 30 } },
      { wait: 600, label: "who takes a press, after", run: function() { h.census("after", 6) } }
    ]
  }
}
