#!/usr/bin/env python3
"""Draw a 54x54 launcher icon (round, black) from simple shapes, no dependencies.

Usage: python3 tools/icon.py OUT.png SPEC.json [SIZE]   (SIZE: output px, default 54; spec stays in 54-px units)
SPEC is a JSON list of shapes in 54-px units, drawn in order on a black disc:
  {"t":"rect","x":12,"y":12,"w":13,"h":14,"c":"#ffffff"}
  {"t":"circle","x":27,"y":27,"r":8,"c":"#C6F432"}            filled
  {"t":"ring","x":27,"y":27,"r":22,"w":3,"c":"#C6F432","a0":0,"a1":270}
      a0/a1 optional, clock degrees (0 = 12 o'clock, clockwise)
  {"t":"line","x1":10,"y1":27,"x2":44,"y2":27,"w":2,"c":"#888888"}
"""
import json, math, struct, sys, zlib

W, SS = 54, 4  # supersampling; W can be overridden by the SIZE argument

def hexc(s):
    s = s.lstrip('#'); return [int(s[i:i+2], 16) for i in (0, 2, 4)]

def inside(sh, x, y):
    t = sh['t']
    if t == 'rect':
        return sh['x'] <= x < sh['x'] + sh['w'] and sh['y'] <= y < sh['y'] + sh['h']
    if t == 'circle':
        return math.hypot(x - sh['x'], y - sh['y']) <= sh['r']
    if t == 'ring':
        d = math.hypot(x - sh['x'], y - sh['y'])
        if abs(d - sh['r']) > sh['w'] / 2: return False
        a = math.degrees(math.atan2(x - sh['x'], -(y - sh['y']))) % 360
        a0, a1 = sh.get('a0', 0), sh.get('a1', 360)
        return a0 <= a <= a1
    if t == 'line':
        x1, y1, x2, y2 = sh['x1'], sh['y1'], sh['x2'], sh['y2']
        dx, dy = x2 - x1, y2 - y1
        L = dx * dx + dy * dy or 1e-9
        u = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / L))
        return math.hypot(x - x1 - u * dx, y - y1 - u * dy) <= sh['w'] / 2
    return False

def main(out, spec, size=None):
    global W
    k = 1.0
    if size:
        k = int(size) / 54.0
        W = int(size)
    shapes = json.load(open(spec))
    for s in shapes:
        for key in ("x", "y", "w", "h", "r", "x1", "y1", "x2", "y2"):
            if key in s: s[key] = s[key] * k
    for s in shapes: s['rgb'] = hexc(s['c'])
    rows = []
    for py in range(W):
        row = bytearray([0])
        for px in range(W):
            acc = [0, 0, 0]; alpha = 0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + .5) / SS; y = py + (sy + .5) / SS
                    if math.hypot(x - W / 2, y - W / 2) > W / 2: continue
                    c = [0, 0, 0]
                    for s in shapes:
                        if inside(s, x, y): c = s['rgb']
                    acc = [a + b for a, b in zip(acc, c)]; alpha += 1
            n = SS * SS
            row += bytes([int(v / alpha) if alpha else 0 for v in acc] + [int(255 * alpha / n)])
        rows.append(bytes(row))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(out, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, W, 8, 6, 0, 0, 0))
                          + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b''))

if __name__ == '__main__':
    main(*sys.argv[1:4])
