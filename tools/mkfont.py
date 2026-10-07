#!/usr/bin/env python3
"""Generate Connect IQ bitmap fonts (BMFont .fnt + .png) for a face from its mockup fonts.

Usage: <venv>/bin/python tools/mkfont.py faces/<Dir>
Needs Pillow + fontTools (see CLAUDE.md for the venv). Reads faces/<Dir>/fonts.json:

  {"fonts": [
    {"id": "Time", "ttf": "Fraunces", "axes": {"wght": 300, "opsz": 96}, "size": 96, "chars": "digits"},
    {"id": "Small", "ttf": "Sora", "axes": {"wght": 400}, "size": 12, "chars": "upper"}
  ]}

- ttf: a file name in tools/fonts/ (without .ttf); download Google Fonts TTFs there.
- size: CSS font-size in 390-px design units. One font per screen size is written:
  390 -> resources/fonts/, others -> resources-round-NxN/fonts/ (scaled N/390).
- ls: optional CSS letter-spacing in design px; baked into each glyph's advance, so draw the
  text with one Gfx.text call (don't use Gfx.spaced with bitmap fonts).
- outline: optional stroke width in design px for hollow (outlined) numerals, like CSS
  `color: transparent; -webkit-text-stroke: 1.5px`. The stroke is centered on the outline.
- gamma: optional edge-alpha curve override (default 1.6 for <= 12 px, 1.3 below 24 px, else 1.0).
- icons: instead of ttf, the name of an SVG icon set in tools/icons/<name>.json -> a font whose
  characters are icons (cell = the set's "cell" design px). Draw centered with
  TEXT_JUSTIFY_CENTER | TEXT_JUSTIFY_VCENTER at the icon center; color via setColor.
  Optional "scale" (e.g. 0.8) makes a smaller copy of the same set.
- chars: a preset (digits | upper | lower | all) and/or literal characters, joined with "+",
  e.g. "upper+°·". Characters missing from the TTF are skipped with a warning.

The .fnt `base` is set to 1.305 x cap height so Gfx.text (which centers capitals at y using
ascent * 0.617) centers these fonts the same way as the system Roboto fonts.
Load in Monkey C with WatchUi.loadResource(Rez.Fonts.<id>).
"""
import json, math, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from fontTools.ttLib import TTFont

SIZES = [360, 390, 416, 454, 466]
PRESETS = {
    "digits": "0123456789:.-% ",
    "upper": "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,:;%°·-+/()'<>_|!?#&",
    "lower": "abcdefghijklmnopqrstuvwxyz",
}
PRESETS["all"] = PRESETS["upper"] + PRESETS["lower"]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def charset(spec):
    out = ""
    for part in spec.split("+"):
        out += PRESETS.get(part, part)
    seen = []
    for c in out:
        if c not in seen:
            seen.append(c)
    return seen


PAD = 1
SS = 4  # supersampling factor: glyphs are drawn at 4x, unhinted, then box-downsampled


def load_font(path, size, axes, opsz=None):
    f = ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.BASIC)
    if axes:
        tt = TTFont(path)
        tags = [a.axisTag for a in tt["fvar"].axes]
        defaults = {a.axisTag: a.defaultValue for a in tt["fvar"].axes}
        vals = [axes.get(t, defaults[t]) for t in tags]
        if "opsz" in tags and "opsz" not in axes:
            lo = next(a for a in tt["fvar"].axes if a.axisTag == "opsz")
            vals[tags.index("opsz")] = max(lo.minValue, min(lo.maxValue, opsz or size))
        f.set_variation_by_axes(vals)
    return f


def build_icons(spec, res, outdir):
    import iconfont
    data = iconfont.load(spec["icons"])
    cell = max(4, round(data["cell"] * spec.get("scale", 1.0) * res / 390))
    glyphs = iconfont.render(spec["icons"], cell)
    items = list(glyphs.items())
    per_row = max(1, 512 // (cell + 2 * PAD + 2))
    W = 512
    H = ((len(items) + per_row - 1) // per_row) * (cell + 2 * PAD + 2)
    sheet = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    lines = []
    for i, (c, a) in enumerate(items):
        x = (i % per_row) * (cell + 2 * PAD + 2)
        y = (i // per_row) * (cell + 2 * PAD + 2)
        white = Image.new("RGBA", a.size, (255, 255, 255, 255))
        white.putalpha(a)
        sheet.paste(white, (x + PAD, y + PAD))
        lines.append(f"char id={ord(c)} x={x} y={y} width={cell + 2 * PAD} height={cell + 2 * PAD} "
                     f"xoffset={-PAD} yoffset={-PAD} xadvance={cell} page=0 chnl=15")
    name = spec["id"].lower()
    os.makedirs(outdir, exist_ok=True)
    sheet.save(os.path.join(outdir, name + ".png"))
    head = [f'info face="{spec["icons"]}" size={cell} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
            f"common lineHeight={cell} base={cell} scaleW={W} scaleH={H} pages=1 packed=0",
            f'page id=0 file="{name}.png"', f"chars count={len(items)}"]
    open(os.path.join(outdir, name + ".fnt"), "w").write("\n".join(head + lines + ["kernings count=0"]) + "\n")
    return name


def build(spec, res, outdir, cmap):
    size = round(spec["size"] * res / 390)
    path = os.path.join(ROOT, "tools", "fonts", spec["ttf"] + ".ttf")
    # Tiny text (<= 12 px) is drawn hinted at native size so strokes snap to whole pixels
    # (the watch keeps only a few antialias levels, which erodes soft 9-10 px strokes).
    ss = 1 if size <= 12 else SS
    big = load_font(path, size * ss, spec.get("axes"), opsz=size)
    ls = spec.get("ls", 0) * res / 390  # CSS letter-spacing, baked into xadvance
    outline = spec.get("outline", 0)  # CSS -webkit-text-stroke width; > 0 = hollow glyphs
    chars = [c for c in charset(spec.get("chars", "upper")) if ord(c) in cmap or c == " "]
    cap = -big.getbbox("H", anchor="ls")[1] / ss
    base = round(cap * 1.305)
    # The watch renders font edges heavier than the source alpha (9 px Sora came out ~2x bold,
    # "S" read as "9"), so thin out edge pixels on small text; large text is left as drawn.
    gamma = spec.get("gamma", 1.6 if size <= 12 else 1.3 if size < 24 else 1.0)
    lut = [round(255 * (a / 255) ** gamma) for a in range(256)]
    glyphs = []
    for c in chars:
        x0, y0, x1, y1 = big.getbbox(c, anchor="ls")
        if outline:  # room for the stroke
            m = math.ceil(outline * res / 390 * ss)
            x0, y0, x1, y1 = x0 - m, y0 - m, x1 + m, y1 + m
        X0, Y0 = math.floor(x0 / ss) * ss, math.floor(y0 / ss) * ss
        X1, Y1 = math.ceil(x1 / ss) * ss, math.ceil(y1 / ss) * ss
        hi = Image.new("L", (max(ss, X1 - X0), max(ss, Y1 - Y0)), 0)
        if c != " " and outline:
            # hollow glyph: a stroke centered on the outline (CSS text-stroke), interior empty
            sw = max(1, round(outline * res / 390 * ss / 2))
            ImageDraw.Draw(hi).text((-X0, -Y0), c, font=big, anchor="ls", fill=255,
                                    stroke_width=sw, stroke_fill=255)
            inner = Image.new("L", hi.size, 0)
            ImageDraw.Draw(inner).text((-X0, -Y0), c, font=big, anchor="ls", fill=255)
            inner = inner.filter(ImageFilter.MinFilter(2 * sw + 1))
            hi = ImageChops.subtract(hi, inner)
        elif c != " ":
            ImageDraw.Draw(hi).text((-X0, -Y0), c, font=big, anchor="ls", fill=255)
        img = (hi.reduce(ss) if ss > 1 else hi).point(lut)
        # 1px transparent border: the CIQ font compiler drops a glyph's edge column.
        padded = Image.new("L", (img.width + 2 * PAD, img.height + 2 * PAD), 0)
        padded.paste(img, (PAD, PAD))
        adv = round(big.getlength(c) / ss + ls)
        glyphs.append((c, padded, X0 // ss - PAD, base + Y0 // ss - PAD, adv))
    # pack in rows
    maxw = 512
    x = y = rowh = 0
    pos = []
    for c, img, *_ in glyphs:
        if x + img.width + 2 > maxw:
            x, y, rowh = 0, y + rowh + 2, 0
        pos.append((x, y))
        x += img.width + 2
        rowh = max(rowh, img.height)
    W, H = maxw, y + rowh + 2
    sheet = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    for (c, img, *_), (px, py) in zip(glyphs, pos):
        white = Image.new("RGBA", img.size, (255, 255, 255, 255))
        white.putalpha(img)
        sheet.paste(white, (px, py))
    name = spec["id"].lower()
    os.makedirs(outdir, exist_ok=True)
    sheet.save(os.path.join(outdir, name + ".png"))
    desc = round(size * 0.3)
    lines = [
        f'info face="{spec["ttf"]}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={base + desc} base={base} scaleW={W} scaleH={H} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs)}",
    ]
    for (c, img, xo, yo, adv), (px, py) in zip(glyphs, pos):
        lines.append(f"char id={ord(c)} x={px} y={py} width={img.width} height={img.height} "
                     f"xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15")
    lines.append("kernings count=0")
    open(os.path.join(outdir, name + ".fnt"), "w").write("\n".join(lines) + "\n")
    return name


def main(face):
    face = face.rstrip("/")
    if not face.startswith("faces/") and not os.path.isabs(face):
        face = os.path.join("faces", face)
    face = os.path.join(ROOT, face) if not os.path.isabs(face) else face
    specs = json.load(open(os.path.join(face, "fonts.json")))["fonts"]
    for res in SIZES:
        rdir = "resources" if res == 390 else f"resources-round-{res}x{res}"
        outdir = os.path.join(face, rdir, "fonts")
        xml = ["<fonts>"]
        for spec in specs:
            if "icons" in spec:
                name = build_icons(spec, res, outdir)
                xml.append(f'    <font id="{spec["id"]}" filename="{name}.fnt" antialias="true"/>')
                continue
            path = os.path.join(ROOT, "tools", "fonts", spec["ttf"] + ".ttf")
            cmap = TTFont(path).getBestCmap()
            missing = [c for c in charset(spec.get("chars", "upper")) if c != " " and ord(c) not in cmap]
            if missing and res == 390:
                print(f"  warning: {spec['id']}: {spec['ttf']} lacks {''.join(missing)}")
            name = build(spec, res, outdir, cmap)
            xml.append(f'    <font id="{spec["id"]}" filename="{name}.fnt" antialias="true"/>')
        xml.append("</fonts>")
        open(os.path.join(outdir, "fonts.xml"), "w").write("\n".join(xml) + "\n")
    print(f"fonts written for {os.path.basename(face)}: {', '.join(s['id'] for s in specs)}")


if __name__ == "__main__":
    for f in sys.argv[1:]:
        main(f)
