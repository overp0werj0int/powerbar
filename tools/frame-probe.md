# Frame probe: is a motion getting its frames?

Use it when something "looks jerky" on the live bar (a slide, a drawer, an
expansion). It tells a main-thread stall (one long gap between frames) from a
slow animation (frames arrive, but move too little each). Offscreen benches
(docs/performance/bench) can't show this: the stall usually comes from mapping
Wayland surfaces, which only happens on a real compositor (or in omabox).

## How

1. Add a temporary `FrameAnimation` to the window that moves (in Bar.qml, the
   `barWindow`), logging the time since the action and the animated value:

   ```qml
   property real perfT0: 0
   property var perfFrames: []
   FrameAnimation {
     running: barWindow.perfT0 > 0
     onTriggered: {
       var now = Date.now()
       barWindow.perfFrames.push(Math.round(now - barWindow.perfT0) + ":" + Math.round(barWindow.autoHideOffset))
       if (now - barWindow.perfT0 > 700) {
         console.info("PBPERF frames", barWindow.perfFrames.join(" "))
         barWindow.perfT0 = 0; barWindow.perfFrames = []
       }
     }
   }
   ```

2. Start the clock where the action starts (`w.perfT0 = Date.now()`), and time
   the steps of the action with `console.info("PBPERF step", Date.now() - t0)`.
3. Trigger the action by IPC, not keys, where you can (`omarchy-shell powerbar
   keys` enters and leaves the keyboard mode). Restart with
   `.claude/skills/omarchy-widget-debug/scripts/live.sh restart powerbar` or
   `omarchy-restart-shell` (never while the session is locked).
4. Read the shell's log: `grep PBPERF "$(live.sh log)"`.
5. Remove every PBPERF line before committing.

## Reading it

`14:58 30:39 46:24 62:14 78:8` is healthy: a frame every ~16 ms (60 Hz), the
value easing towards its end. `80:58 146:3` is a stall: the first frame came at
80 ms and the next 66 ms later, so a 180 ms slide showed two frames.

## Known causes

- Mapping a surface (a `PanelWindow` or `PopupWindow` becoming visible) stalls
  the GUI thread for ~50–70 ms. Don't map surfaces while something the user
  is watching moves: Powerbar gates its keyboard-mode layers and the tooltip
  on `barWindow.sliding` (October 2026: Super+B on an autohidden bar went from
  2–3 frames to a frame every 16 ms).
- A Repeater whose model holds QObjects costs ~2 ms per object
  (docs/performance/implementation.md).
