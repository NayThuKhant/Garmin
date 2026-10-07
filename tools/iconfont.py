#!/usr/bin/env python3
"""Render an SVG icon set (tools/icons/<set>.json) to glyph images with headless Chrome.

Used by mkfont.py for fonts.json entries like
  {"id": "Icons", "icons": "meridian"}
which become a bitmap font whose characters are the icons (draw with Gfx/drawText in any color).
Run directly to get a preview sheet:  python3 tools/iconfont.py meridian out.png
"""
import json, math, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def load(name):
    return json.load(open(os.path.join(ROOT, "tools", "icons", name + ".json")))


def svg_markup(icon, px):
    return (f'<svg width="{px}" height="{px}" viewBox="0 0 24 24" fill="#fff" stroke="#fff" stroke-width="0" '
            f'xmlns="http://www.w3.org/2000/svg">{icon["svg"]}</svg>')


def render(name, cell_px, bg="transparent"):
    """Return {char: PIL.Image 'L' (cell_px square)} with icons centered in their cells."""
    from PIL import Image
    data = load(name)
    icons, cell = data["icons"], data["cell"]
    cols = 10
    rows = math.ceil(len(icons) / cols)
    W, H = cols * cell_px, rows * cell_px
    cells = []
    for i, ic in enumerate(icons):
        px = round(ic["size"] / cell * cell_px)
        x, y = (i % cols) * cell_px, (i // cols) * cell_px
        cells.append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:{cell_px}px;height:{cell_px}px;'
                     f'display:flex;align-items:center;justify-content:center">{svg_markup(ic, px)}</div>')
    page = (f'<!doctype html><html><head><style>html,body{{margin:0;background:{bg}}}</style></head>'
            f'<body><div style="position:relative;width:{W}px;height:{H}px">{"".join(cells)}</div></body></html>')
    with tempfile.TemporaryDirectory() as d:
        src, out = os.path.join(d, "i.html"), os.path.join(d, "i.png")
        open(src, "w").write(page)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--default-background-color=00000000", "--force-device-scale-factor=1",
                        f"--window-size={W},{H}", f"--screenshot={out}", "file://" + src],
                       check=True, capture_output=True)
        sheet = Image.open(out).convert("RGBA")
        sheet.load()
    glyphs = {}
    for i, ic in enumerate(icons):
        x, y = (i % cols) * cell_px, (i // cols) * cell_px
        glyphs[ic["char"]] = sheet.crop((x, y, x + cell_px, y + cell_px)).getchannel("A")
    return glyphs


if __name__ == "__main__":
    from PIL import Image, ImageDraw
    name, out = sys.argv[1], sys.argv[2]
    g = render(name, 80)
    icons = load(name)["icons"]
    cols = 10
    rows = math.ceil(len(icons) / cols)
    img = Image.new("RGB", (cols * 90, rows * 100), (20, 20, 20))
    d = ImageDraw.Draw(img)
    for i, ic in enumerate(icons):
        x, y = (i % cols) * 90 + 5, (i // cols) * 100 + 2
        img.paste((255, 255, 255), (x, y), g[ic["char"]])
        d.text((x, y + 82), f'{ic["char"]} {ic["name"]}', fill=(255, 210, 0))
    img.save(out)
    print(out)
