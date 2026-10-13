pragma Singleton
import QtQml
// Stands in for Quickshell.Hyprland, which Omarchy's Style listens to for
// config reloads.
QtObject {
  signal rawEvent(var event)
}
