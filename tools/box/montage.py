#!/usr/bin/env python3
"""montage.py: burst frames side by side in one labelled PNG, to read at a glance.

    montage.py DIR OUT [--crop X0,Y0,X1,Y1] [--side] [--scale S] FRAME...

Stacks the frames (numbers as in frame-NNN.png) top to bottom, or left to
right with --side (for a vertical bar), each cropped and labelled with its
number. --scale shrinks the result (0.66 keeps a full-height side bar
readable).
"""
import argparse
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument('dir'); ap.add_argument('out')
ap.add_argument('--crop'); ap.add_argument('--side', action='store_true')
ap.add_argument('--scale', type=float, default=1.0)
ap.add_argument('frames', nargs='+', type=int)
a = ap.parse_args()

ims = [Image.open(f"{a.dir}/frame-{n:03d}.png").convert('RGB') for n in a.frames]
if a.crop:
    box = tuple(int(v) for v in a.crop.split(','))
    ims = [im.crop(box) for im in ims]
W, H = ims[0].size
size = ((W + 2) * len(ims), H) if a.side else (W, (H + 2) * len(ims))
M = Image.new('RGB', size, (255, 0, 0))
for i, (n, im) in enumerate(zip(a.frames, ims)):
    at = (i * (W + 2), 0) if a.side else (0, i * (H + 2))
    M.paste(im, at)
    ImageDraw.Draw(M).text((at[0] + 3, at[1] + 2), str(n), fill=(255, 255, 0))
if a.scale != 1.0:
    M = M.resize((int(M.width * a.scale), int(M.height * a.scale)))
M.save(a.out); print(a.out)
