#!/usr/bin/env python3
"""cards.py: find light blobs (cards, tooltips, strip previews) in burst frames.

    cards.py DIR [--axis h|v] [--band A B] [--light L] [--summary]

For each frame-*.png in DIR, looks in the band A..B (rows A..B for a
horizontal bar, columns A..B with --axis v) for runs of light pixels
(grey > L, default 150: a light theme's cards on a dark desktop) and prints
them as (start, length, cross-start) along the bar. --summary prints one
line per frame, "NNN:count[!]" with ! where the count is not 1, then the
frames that were flagged.

A card and a strip preview that touch merge into one wide blob; a montage
(montage.py) tells them apart. Count a frame with no card as a cue, not a
failure: the dots and a group's icon carry no card by design.
"""
import argparse, glob, os
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('dir')
ap.add_argument('--axis', choices='hv', default='h')
ap.add_argument('--band', nargs=2, type=int, default=[46, 100])
ap.add_argument('--light', type=int, default=150)
ap.add_argument('--summary', action='store_true')
a = ap.parse_args()

def blobs(path):
    im = Image.open(path).convert('L'); W, H = im.size; px = im.load()
    lo, hi = a.band
    if a.axis == 'h':
        along, cross = W, range(lo, min(hi, H))
        lit = lambda i, j: px[i, j] > a.light
    else:
        along, cross = H, range(lo, min(hi, W))
        lit = lambda i, j: px[j, i] > a.light
    on = [any(lit(i, j) for j in cross) for i in range(along)]
    runs, i = [], 0
    while i < along:
        if on[i]:
            s = i
            while i < along and on[i]: i += 1
            if i - s > 6:
                js = [j for j in cross if any(lit(ii, j) for ii in range(s, i))]
                runs.append((s, i - s, min(js)))
        i += 1
    return runs

frames = sorted(glob.glob(os.path.join(a.dir, 'frame-*.png')))
flagged = []
line = []
for f in frames:
    n = os.path.basename(f)[6:9]; r = blobs(f)
    if len(r) != 1: flagged.append(n)
    if a.summary: line.append(f"{n}:{len(r)}{'' if len(r) == 1 else '!'}")
    else: print(n, len(r), r)
if a.summary:
    print(' '.join(line))
    print('not one card:', ' '.join(flagged) if flagged else 'none')
