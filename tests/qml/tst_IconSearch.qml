import QtQuick
import QtTest
import "../../IconSearch.js" as IconSearch
import "../../OmarchyIcons.js" as OmarchyIcons

// Material glyphs are surrogate pairs; the search runs in Qt's engine too.
TestCase {
  name: "IconSearchInQml"
  function test_index_and_search() {
    var list = IconSearch.index({ bar: [{ glyph: "󰍬", font: "", name: "Microphone" }],
      logos: OmarchyIcons.logos, glyphs: OmarchyIcons.glyphs, emoji: [{ e: "🤖", k: "robot face" }] })
    verify(list.length > 250)
    compare(list[0].glyph, "󰍬")
    compare(IconSearch.search(list, "microphone")[0].glyph, "󰍬")
    var logo = IconSearch.search(list, "codex")[0]
    compare(logo.font, "omarchy")
    compare(logo.glyph, "")
    compare(IconSearch.search(list, "robot face")[0].glyph, "🤖")
  }
  function test_pasted() {
    compare(IconSearch.pastedGlyph("󰚩"), "󰚩")
    compare(IconSearch.pastedGlyph("👩‍💻"), "👩‍💻")
    compare(IconSearch.pastedGlyph("ab"), "")
  }
  function test_speed() {
    var emoji = []
    for (var i = 0; i < 1870; i++) emoji.push({ e: String.fromCodePoint(0x1F300 + i), k: "grinning face smile happy " + i })
    var list = IconSearch.index({ logos: OmarchyIcons.logos, glyphs: OmarchyIcons.glyphs, emoji: emoji })
    var t = Date.now()
    for (var n = 0; n < 10; n++) IconSearch.search(list, "mic")
    var each = (Date.now() - t) / 10
    console.info("IconSearch: " + list.length + " icons, " + each.toFixed(1) + " ms per search")
    verify(each < 16)
  }
}
