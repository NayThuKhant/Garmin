#!/usr/bin/env python3
"""Numerically check Meridian's symmetry: every arc, fill, circle and gap must be identical
(mirrored) in all four corners. Reads the constants straight from MeridianView.mc."""
import math, re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "faces/MeridianFace/source/MeridianView.mc")).read()
def const(name):
    m = re.search(rf"const {name} = (\[[^\]]*\]|[\d.]+)", src)
    v = m.group(1)
    return [float(x) for x in v.strip("[]").split(",")] if v.startswith("[") else float(v)
CX, CY = 195, 195
R, W, TW, CR = const("ARC_R"), const("ARC_W"), const("TRACK_W"), const("CIRCLE_R")
A, B, BASE, END = const("ARC_A"), const("ARC_B"), const("ARC_BASE"), const("ARC_END")
TXT, TXTR = const("ARC_TEXT"), const("ARC_TEXT_R")
SX, SY = const("SLOT_X"), const("SLOT_Y")
names = ["TL", "TR", "BL", "BR"]
circles = {"top": (SX[0], SY[0]), "left": (SX[1], SY[1]), "right": (SX[2], SY[2]), "bottom": (SX[3], SY[3])}
def pt(r, a): return CX + r * math.sin(math.radians(a)), CY - r * math.cos(math.radians(a))
def gap(a, cap, circle):
    # clearance between the arc end (round cap of radius `cap`) and the circle outline (2.5 px)
    x, y = pt(R, a); cx, cy = circles[circle]
    return math.hypot(x - cx, y - cy) - CR - 1.25 - cap
def nearest(a):
    return min(circles, key=lambda c: math.hypot(pt(R, a)[0] - circles[c][0], pt(R, a)[1] - circles[c][1]))
print("circles (distance from center, radius):",
      {k: (round(math.hypot(x - CX, y - CY), 2), CR) for k, (x, y) in circles.items()})
cap = math.degrees((W / 2) / R)
rows = []
for i, n in enumerate(names):
    lo, hi = A[i], B[i]
    side = nearest(BASE[i]); other = nearest(END[i])
    rows.append((n, f"{lo:g}-{hi:g}", f"span {hi-lo:g}",
                 f"fill from {side}", f"gap@{side} {gap(BASE[i], max(TW/2, W/2 if False else TW/2), side):.2f}px",
                 f"gap@{other} {gap(END[i], TW/2, other):.2f}px",
                 f"fill cap inside track: {abs(BASE[i]-A[i] if BASE[i]==A[i] else BASE[i]-B[i])==0}",
                 f"text {TXT[i]:g}deg r{TXTR[i]:g}"))
for r in rows: print("  ".join(r))
spans = {B[i] - A[i] for i in range(4)}
mid = [((A[i] + B[i]) / 2) % 360 for i in range(4)]
print("all spans equal:", len(spans) == 1, "| arc centers on diagonals:", mid,
      "| fill cap inset (deg):", round(cap, 2))
