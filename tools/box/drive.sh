# drive.sh: shell helpers for driving Powerbar in a box. Source it, set B:
#   source tools/box/drive.sh; B=NAME
#
#   ks             one line of keyboard-mode state: cursor, drawer, inline, card
#   k KEY...       send keys, wait until the screen is still
#   st             wait until the screen is still
#   glide X1 Y1 X2 Y2 [STEPS]   glide the pointer, 10 ms a step (a single jump
#                  often registers no hover in a box: glide onto a target)
#   reset          keyboard mode off, pointer parked at 700,600, mode on again
#                  (the cursor starts on the bar's anchor widget)
#   to NAME        press Right until the cursor is on NAME (as ks names it)
ks() { omabox run -b "$B" -- omarchy-shell powerbar keysStatus | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);const d=o.drawer;console.log((o.active?"":"OFF ")+(o.suspended?"SUSP ":"")+"cur="+o.cursor+" mode="+o.mode+" drawer="+(d?(d.group||d.zone)+(d.previewing?"/preview":"/entered")+(d.aside?"/aside":"")+" member="+d.member:"-")+" inline="+o.inline+" card="+(o.card&&o.card.shown?JSON.stringify(o.card.text):"-"))})'; }
st() { omabox wait -b "$B" still >/dev/null 2>&1; }
k() { omabox keys -b "$B" "$@" >/dev/null; st; }
glide() { local n=${5:-8} a="" i; for i in $(seq 1 "$n"); do a="$a move $(( $1 + ($3-$1)*i/n )) $(( $2 + ($4-$2)*i/n )) sleep 10"; done; omabox pointer -b "$B" $a >/dev/null; }
reset() { omabox run -b "$B" -- omarchy-shell powerbar keysOff >/dev/null; omabox pointer -b "$B" move 700 600 >/dev/null; st; omabox run -b "$B" -- omarchy-shell powerbar keysOn >/dev/null; st; }
to() { local i; for i in $(seq 1 30); do ks | grep -q "cur=$1 " && return 0; k Right; done; echo "never reached $1"; return 1; }
