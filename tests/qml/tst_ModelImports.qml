import QtQuick
import QtTest
import "../../BarModel.js" as BarModel
import "../../CliModel.js" as CliModel
import "../../GroupsModel.js" as GroupsModel
import "../../ManagedModel.js" as ManagedModel
import "../../PreferencesModel.js" as PreferencesModel
import "../../RenderModel.js" as RenderModel
import "../../TrayItemsModel.js" as TrayItemsModel

// Every model that imports another, loaded by Qt's engine: each answer here
// comes through the import. tests/model-imports.test.cjs keeps the list whole.
TestCase {
  name: "ModelImportsInQml"
  function layout() {
    return { left: [], centerBegin: [], center: [], centerEnd: [{ id: "a", powerbarInstance: "pa" }], right: [],
      tray: [{ id: "t", powerbarInstance: "pt" }] }
  }
  function test_zoneLists() {
    compare(CliModel.widgetPatch({ zone: "x" }, {}).error, "zone is one of left, centerBegin, center, centerEnd, right")
    compare(GroupsModel.groups({ layout: layout(), powerbarGroups: [{ id: "g", section: "centerBegin", items: [] }] })[0].section, "centerBegin")
    var config = { bar: { layout: layout() } }
    verify(BarModel.moveInstanceInConfig(config, "tray", "pt", "centerEnd", "pa"))
    compare(config.bar.layout.centerEnd[0].id, "t")
    compare(Object.keys(RenderModel.split([])).join(), "left,centerBegin,center,centerEnd,right")
    compare(PreferencesModel.zonesOnly().length, 5)
    compare(ManagedModel.layoutEntries({ layout: layout() }).length, 2)
    compare(TrayItemsModel.entries({ centerEnd: [{ type: "trayItem", item: "x" }] }).length, 1)
  }
  function test_visibilityModes() {
    compare(CliModel.widgetPatch({ visibility: "x" }, {}).error, "visibility is one of shown, managed, hidden")
    compare(PreferencesModel.rows.join(), "shown,managed,hidden,tray")
    compare(PreferencesModel.mode({ id: "a" }, null, true), "managed")
    compare(GroupsModel.groups({ layout: layout(), powerbarGroups: [{ id: "g", visibility: "managed", items: [] }] })[0].visibility, "managed")
    verify(!BarModel.moveInstanceInConfig({ bar: { layout: layout() } }, "tray", "pt", "left", "", "x"))
    compare(TrayItemsModel.moveOut({ bar: { layout: layout() } }, { id: "app" }, "left", "x", "", "k"), null)
  }
}
