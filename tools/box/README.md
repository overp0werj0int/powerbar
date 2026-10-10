# Box tools: see Powerbar move, frame by frame

Helpers for checking behaviour and visuals in an omabox box (a private,
invisible Omarchy desktop; never the user's). They are what earlier sessions
kept rebuilding from scratch: use them before writing new ones. Needs omabox,
rsync, node and python3 with Pillow.

| Tool | What it does |
|---|---|
| `box.sh up NAME` | Box at 1512x945 with this checkout and the user's bar config (read from `~/.config/omarchy/shell.json`, autohide off). |
| `box.sh sync NAME` | After an edit: copy the plugin in, restart the box's shell, wait until Powerbar answers. |
| `box.sh conf NAME KEY=VALUE…` | Change bar keys live: `position=left`, `powerbarOnDemand=inline`, `powerbarStyle=islands`. |
| `drive.sh` | `source` it with `B=NAME`: `ks` (keyboard state in one line), `k KEY`, `st`, `glide` (pointer glide), `reset`, `to NAME`. |
| `burst.sh BOX` | A fast keyboard walk recorded at 40 ms a frame, with the card count per frame. |
| `cards.py DIR` | Light blobs (cards, tooltips, strip previews) per frame, along the bar. |
| `montage.py DIR OUT FRAMES…` | Chosen frames stacked and labelled in one PNG. |
| `edges.sh BOX OUT.png` | The card on the first and last widget, in one PNG. |
| `benchdiff.sh BASE CHANGED` | Offscreen bench geometry and errors, master against a worktree. |

## Recipes

```bash
B=pb; tools/box/box.sh up $B                      # once
tools/box/box.sh sync $B ../powerbar-wt-x         # after each edit in a worktree
source tools/box/drive.sh
reset; ks                                         # cur=Clock ... card="Clock"

# Fast walk on a top bar: every frame should show exactly one card.
tools/box/box.sh conf $B powerbarOnDemand=inline position=top
tools/box/burst.sh $B
# Bottom bar: shoot above the bar. Side bars: --vertical and a tall area.
tools/box/burst.sh $B -g "0,795 1512x150" --band 0 100
tools/box/burst.sh $B -g "0,0 400x945" --vertical --band 50 400     # left
tools/box/burst.sh $B -g "1112,0 400x945" --vertical --band 0 350   # right

# Look at the frames around anything flagged.
tools/box/montage.py /tmp/omabox-…-burst-… m.png --crop 0,0,900,100 19 20 21 22
tools/box/montage.py DIR m.png --side --scale 0.66 19 20 21 22      # side bar

# The ends of the bar, on every edge.
tools/box/edges.sh $B top.png
tools/box/box.sh conf $B position=left; tools/box/edges.sh $B left.png -g "0,0 300x945" --vertical

# Pointer: glide, then rest past the 400 ms tooltip delay.
omabox pointer -b $B move 700 600 sleep 300; glide 1300 60 1330 22 6
omabox pointer -b $B move 1331 22 sleep 900; omabox shot -b $B -g "700,0 812x200"

tools/box/benchdiff.sh . ../powerbar-wt-x         # before merging
omabox down $B
```

## What earlier sessions learned

- **Keys cards are the easy probe.** Every widget has a keyboard card (its
  name); pointer tooltips show only for widgets that bring text (drawer
  members, keyboard layout, tray, the dots), and most stock widgets bring
  none, so "no tooltip" on hover is usually right.
- **Glide the pointer.** A single `omabox pointer move` onto a widget often
  registers no hover in a box; `glide` in a few steps does. A diagonal glide out
  of a zone closes its drawer: go straight down into a strip, then along it.
- **One-frame skews are normal.** The card lives in its own popup surface and
  can lead or trail the cursor ring (bar window) by one 40 ms frame. Two
  cards at once, a card in another zone, or a card cut at a zone's start are
  bugs (appearance.md LOOK-136, 138).
- **Frames with no card** while the cursor passes the dots or a group's icon
  are by design (they carry none).
- **Colour detectors lie.** An "accent pixel" ring finder picked up other
  orange; read positions from `ks`, `cards.py` and montages instead.
- **Box config edits apply live**; `sync` only after code changes.
- In drawer mode a zone strip previews as the cursor reaches the zone, so a
  card and the preview can merge into one wide blob in `cards.py`: check the
  montage.
- `omabox shot --after -- keys …` takes `keys`, not `omabox keys`.

See also `tools/smoke.sh` (IPC basics in a throwaway box),
`tools/frame-probe.md` (frame gaps on the live bar) and
`docs/performance/bench` (the offscreen bench `benchdiff.sh` runs).
