#!/usr/bin/env python3
"""Render docs/preview.png (the README image): every face's active design in one compact grid.

Usage: python3 tools/render_preview.py   (needs Google Chrome; run after tools/build_gallery.py)
"""
import os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
COLS, CARD = 6, 230          # grid columns, card width (px)

STYLE = f"""<style>
header p, .toolbar, .board.aod, .swatches, .settings, .face-foot, .board > div:last-child {{ display: none !important; }}
header {{ padding: 24px 24px 4px; }}
main {{ grid-template-columns: repeat({COLS}, {CARD}px) !important; gap: 14px !important; max-width: none !important; padding: 12px 24px 24px !important; }}
.face {{ padding: 12px !important; }}
.face h2 {{ font-size: 13px !important; margin-bottom: 8px !important; }}
</style>"""


def main():
    from PIL import Image
    html = open(os.path.join(ROOT, "faces.html")).read().replace("</head>", STYLE + "</head>")
    width = 48 + COLS * CARD + (COLS - 1) * 14
    with tempfile.TemporaryDirectory() as d:
        src, shot = os.path.join(d, "p.html"), os.path.join(d, "p.png")
        open(src, "w").write(html)
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        f"--window-size={width},3200", "--virtual-time-budget=9000", f"--screenshot={shot}",
                        "file://" + src], check=True, capture_output=True)
        im = Image.open(shot).convert("RGB")
        # crop the empty page background below the last row
        bg = im.getpixel((2, im.height - 2))
        px = im.load()
        bottom = im.height
        while bottom > 1 and all(px[x, bottom - 1] == bg for x in range(0, im.width, 7)):
            bottom -= 1
        out = os.path.join(ROOT, "docs", "preview.png")
        im.crop((0, 0, im.width, min(im.height, bottom + 24))).save(out, optimize=True)
        print(f"wrote {out} {im.width}x{bottom + 24}")


if __name__ == "__main__":
    sys.exit(main())
