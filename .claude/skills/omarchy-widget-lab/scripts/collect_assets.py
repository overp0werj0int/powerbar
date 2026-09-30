#!/usr/bin/env python3
"""Collect the real-thing assets for an Omarchy widget lab page.

Reads the user's live Omarchy setup (never writes to it) and produces, in --out:

  w/<name>.png   each Powerbar widget capture, faint fringes removed and
                 (by default) recoloured to the current theme foreground
  wall.jpg       the top band of the current wallpaper, as the bar's backdrop
  widgets.js     window.LAB = { widgets, zones, theme, scale } for the page
  widgets.json   the same data, for scripts

Every widget entry carries measurements in bar pixels:
  w, h   the capture's size (the widget's implicit size)
  ink    [left, width, top, height] of what it actually paints
  parts  painted runs along the bar (sub-items of compounds, words of text)

Usage:
  collect_assets.py --out DIR                       # every widget on the bar
  collect_assets.py --out DIR --widgets clock tray   # a subset, by name or id
  collect_assets.py --out DIR --face group-ai="AI"   # draw a text face too
  collect_assets.py --out DIR --glyph agent-orchestr=~/.config/omarchy/plugins/x/assets/icons/agent.svg
                                                    # a clean glyph for a widget that paints over its own
  collect_assets.py --list                           # what is available
"""
import argparse, json, os, re, shutil, subprocess, sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required: sudo pacman -S python-pillow")

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache/powerbar/widgets")
SHELL = os.path.join(HOME, ".config/omarchy/shell.json")
THEME = os.path.join(HOME, ".local/state/omarchy/current/theme/colors.toml")
WALL = os.path.join(HOME, ".local/state/omarchy/current/background")


def load_shell():
    try:
        with open(SHELL) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return {}
    return data.get("bar", data)


def bar_entries(bar):
    """Layout entries in zone order: (zone, entry)."""
    layout = bar.get("layout") or {}
    for zone in ("left", "center", "right"):
        for entry in layout.get(zone) or []:
            if isinstance(entry, dict) and entry.get("id"):
                yield zone, entry


def slug(widget_id):
    return re.sub(r"[^a-z0-9-]+", "-", widget_id.split(".")[-1].lower()).strip("-") or "widget"


def theme():
    colors = {}
    try:
        for line in open(THEME):
            m = re.match(r'\s*([a-z_0-9]+)\s*=\s*"(#[0-9a-fA-F]{6})"', line)
            if m:
                colors[m.group(1)] = m.group(2)
    except OSError:
        pass
    font = ""
    try:
        font = subprocess.run(["fc-match", "-f", "%{family[0]}", "monospace"], capture_output=True, text=True).stdout.strip()
    except OSError:
        pass
    return {"colors": colors, "font": font or "monospace"}


def detect_scale():
    """Powerbar saves captures at 2 x the device pixel ratio (WidgetIcon.savedScale)."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3).stdout
        scales = [m.get("scale", 1) for m in json.loads(out)]
        if scales:
            return 2 * max(1.0, max(scales))
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return 4.0


def hex_rgb(value, fallback=(220, 215, 214)):
    try:
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
    except (TypeError, ValueError, IndexError):
        return fallback


def clean(im, fg, recolor):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 36:
                px[x, y] = (0, 0, 0, 0)
            elif recolor:
                px[x, y] = (fg[0], fg[1], fg[2], a)
    return im


def measure(im, scale):
    alpha = im.split()[3].point(lambda v: 255 if v > 70 else 0)
    box = alpha.getbbox()
    if not box:  # drawn only in faint pixels (thin graphs): count anything visible
        alpha = im.split()[3].point(lambda v: 255 if v > 8 else 0)
        box = alpha.getbbox()
    cols = [any(alpha.getpixel((x, y)) for y in range(im.height)) for x in range(im.width)]
    runs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        if not on and start is not None:
            runs.append([start, x])
            start = None
    merged = []
    for run in runs:  # runs closer than ~3 bar px belong to one glyph or word
        if merged and run[0] - merged[-1][1] < 3.2 * scale:
            merged[-1][1] = run[1]
        else:
            merged.append(run)
    r = lambda v: round(v / scale, 2)
    ink = [r(box[0]), r(box[2] - box[0]), r(box[1]), r(box[3] - box[1])] if box else [0, 0, 0, 0]
    return {"w": r(im.width), "h": r(im.height), "ink": ink, "parts": [[r(a), r(b - a)] for a, b in merged]}


def draw_face(text, scale, fg, font_path, size=12, margin=8.5, bar=38):
    """A text face drawn the way Omarchy's WidgetButton draws labels."""
    font = ImageFont.truetype(font_path, int(size * scale))
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    advance = probe.textlength(text, font=font)
    w, h = int(round(advance + 2 * margin * scale)), int(bar * scale)
    im = Image.new("RGBA", (w, h))
    ascent, descent = font.getmetrics()
    ImageDraw.Draw(im).text(((w - advance) / 2, (h - ascent - descent) / 2), text, font=font, fill=fg + (255,))
    return im


def font_file(family):
    try:
        path = subprocess.run(["fc-match", "-f", "%{file}", family], capture_output=True, text=True).stdout.strip()
        return path or None
    except OSError:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", help="output directory for the lab page's assets")
    ap.add_argument("--widgets", nargs="*", help="names (slug), widget ids or powerbar instances; default: all on the bar")
    ap.add_argument("--face", action="append", default=[], help='NAME="text" to draw a text face (group faces, mock values)')
    ap.add_argument("--glyph", action="append", default=[], help="NAME=icon.svg: replace NAME's capture with its icon rendered clean into a 27 px slot (for widgets that paint a count over their glyph)")
    ap.add_argument("--scale", type=float, help="capture scale (default: 2 x monitor scale, else 4)")
    ap.add_argument("--no-recolor", action="store_true", help="keep capture colours instead of the theme foreground")
    ap.add_argument("--band", type=float, default=0.12, help="wallpaper band height as a fraction of its width")
    ap.add_argument("--no-wallpaper", action="store_true")
    ap.add_argument("--list", action="store_true", help="list widgets on the bar and whether a capture exists")
    args = ap.parse_args()

    bar = load_shell()
    entries = list(bar_entries(bar))
    if args.list:
        for zone, e in entries:
            inst = e.get("powerbarInstance", "")
            has = os.path.exists(os.path.join(CACHE, inst + ".png"))
            print(f"{zone:7s} {slug(e['id']):22s} {e['id']:40s} {e.get('powerbarVisibility', 'shown'):8s} {'capture' if has else 'no capture'}")
        return
    if not args.out:
        ap.error("--out is required")

    scale = args.scale or detect_scale()
    th = theme()
    fg = hex_rgb(th["colors"].get("foreground"))
    os.makedirs(os.path.join(args.out, "w"), exist_ok=True)

    wanted = set(args.widgets or [])
    widgets, zones, used = {}, {"left": [], "center": [], "right": []}, set()
    for zone, e in entries:
        inst = e.get("powerbarInstance", "")
        name = slug(e["id"])
        if wanted and not ({name, e["id"], inst} & wanted):
            continue
        src = os.path.join(CACHE, inst + ".png")
        if not os.path.exists(src):
            print(f"skip {e['id']}: no capture yet (it has never been shown on this bar)", file=sys.stderr)
            continue
        if name in used:
            name = f"{name}-{inst[-4:]}"
        used.add(name)
        im = clean(Image.open(src), fg, not args.no_recolor)
        im.save(os.path.join(args.out, "w", name + ".png"), optimize=True)
        widgets[name] = dict(measure(im, scale), id=e["id"], instance=inst, zone=zone,
                             visibility=e.get("powerbarVisibility", "shown"))
        zones[zone].append(name)

    for spec in args.glyph:
        name, _, svg = spec.partition("=")
        svg = os.path.expanduser(svg)
        size = int(16 * scale)  # Style.bar.iconCanvas, centred in the 27 px slot as BarIconButton does
        png = os.path.join(args.out, "w", name + ".svg.png")
        try:
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), svg, "-o", png], check=True)
        except (OSError, subprocess.CalledProcessError):
            print(f"skip glyph {name}: rsvg-convert could not render {svg}", file=sys.stderr)
            continue
        slot = int(27 * scale)
        im = Image.new("RGBA", (slot, slot))
        g = Image.open(png).convert("RGBA")
        off = int(round((slot - size) / 2))
        im.paste(g, (off, off), g)
        os.remove(png)
        im.save(os.path.join(args.out, "w", name + ".png"), optimize=True)
        prev = widgets.get(name, {})
        widgets[name] = dict(measure(im, scale), id=prev.get("id", name), instance=prev.get("instance", ""),
                             zone=prev.get("zone", ""), visibility=prev.get("visibility", "glyph"), source=svg)

    ffile = font_file(th["font"]) or font_file("monospace")
    for spec in args.face:
        name, _, text = spec.partition("=")
        if not ffile:
            print("skip faces: no font file found", file=sys.stderr)
            break
        bar_px = 38 if bar.get("powerbarLargeBar") else 26
        im = draw_face(text.strip('"'), scale, fg, ffile, bar=bar_px)
        im.save(os.path.join(args.out, "w", name + ".png"), optimize=True)
        widgets[name] = dict(measure(im, scale), id=name, instance="", zone="", visibility="face", text=text)

    if not args.no_wallpaper and os.path.exists(WALL):
        wall = Image.open(WALL).convert("RGB")
        band = wall.crop((0, 0, wall.width, int(wall.width * args.band)))
        band.resize((1600, int(1600 * args.band)), Image.LANCZOS).save(os.path.join(args.out, "wall.jpg"), quality=78)

    data = {"widgets": widgets, "zones": zones, "theme": th, "scale": scale,
            "bar": {"large": bool(bar.get("powerbarLargeBar")), "style": bar.get("powerbarStyle", "islands"),
                    "position": bar.get("position", "top"), "rounding": bar.get("powerbarIslandRounding"),
                    "spacing": bar.get("powerbarSpacing", 0)}}
    with open(os.path.join(args.out, "widgets.json"), "w") as f:
        json.dump(data, f, indent=1)
    with open(os.path.join(args.out, "widgets.js"), "w") as f:
        f.write("// Generated by omarchy-widget-lab/scripts/collect_assets.py\nwindow.LAB = " + json.dumps(data, separators=(",", ":")) + ";\n")
    print(f"{len(widgets)} widgets, scale {scale:g}, theme fg {th['colors'].get('foreground', '?')} -> {args.out}")
    wall_src = os.path.realpath(WALL)
    if not args.no_wallpaper and os.path.exists(WALL):
        print(f"wallpaper: {wall_src} (check its licence before committing wall.jpg to a public repo)")


if __name__ == "__main__":
    main()
