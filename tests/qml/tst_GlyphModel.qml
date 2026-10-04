import QtQuick
import QtTest
import "../../GlyphModel.js" as GlyphModel

// The glyph rules run in Qt's JavaScript engine, not only in node.
TestCase {
  name: "GlyphModelInQml"
  function test_glyphs() {
    compare(GlyphModel.glyphFrom(""), "")
    compare(GlyphModel.glyphFrom("󰕾"), "󰕾")
    compare(GlyphModel.glyphFrom("100% 󰁹"), "󰁹")
    compare(GlyphModel.glyphFrom("EN"), "EN")
    compare(GlyphModel.glyphFrom("17"), "")
    compare(GlyphModel.glyphFrom("Friday 23:46"), "")
  }
  function test_pick() {
    var found = GlyphModel.pick([{ text: "1", font: "F", visible: true }, { text: "󰂯", font: "F", visible: true }])
    compare(found.glyph, "󰂯")
    compare(found.font, "F")
  }
}
