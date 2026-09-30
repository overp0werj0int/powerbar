pragma Singleton
import QtQml
QtObject {
  function isPlainObject(value) { return value !== null && typeof value === "object" && !Array.isArray(value) }
  function parseModuleJson(raw) { try { return JSON.parse(raw) } catch (_) { return {} } }
}
