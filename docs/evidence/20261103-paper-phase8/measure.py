#!/usr/bin/env python3
"""Measure element boxes (pt) in a 1170px-wide content image (3 px/pt), same method for mock and device.

region: flood fill from a seed point with a colour tolerance -> bounding box.
ink:    bounding box of pixels darker/lighter than a threshold inside a search box -> text/icon box.
"""
import json, subprocess, sys
from collections import deque

S = 3.0

def load(path):
    w, h = map(int, subprocess.run(['magick', 'identify', '-format', '%w %h', path], capture_output=True, text=True, check=True).stdout.split())
    raw = subprocess.run(['magick', path, '-alpha', 'off', '-depth', '8', 'rgb:-'], capture_output=True, check=True).stdout
    return w, h, raw

def px(img, x, y):
    w, _, raw = img
    i = (y * w + x) * 3
    return raw[i], raw[i + 1], raw[i + 2]

def region(img, sx, sy, tol=10, limit=(None, None, None, None)):
    w, h, _ = img
    x0 = int(sx * S); y0 = int(sy * S)
    seed = px(img, x0, y0)
    lx, ly, ux, uy = [int(v * S) if v is not None else d for v, d in zip(limit, (0, 0, w - 1, h - 1))]
    seen = bytearray(w * h); q = deque([(x0, y0)]); seen[y0 * w + x0] = 1
    minx = maxx = x0; miny = maxy = y0
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if lx <= nx <= ux and ly <= ny <= uy and not seen[ny * w + nx]:
                seen[ny * w + nx] = 1
                c = px(img, nx, ny)
                if max(abs(c[0] - seed[0]), abs(c[1] - seed[1]), abs(c[2] - seed[2])) <= tol:
                    q.append((nx, ny)); minx = min(minx, nx); maxx = max(maxx, nx); miny = min(miny, ny); maxy = max(maxy, ny)
    return [round(minx / S, 1), round(miny / S, 1), round((maxx - minx + 1) / S, 1), round((maxy - miny + 1) / S, 1)]

def ink(img, box, dark=True, thr=110):
    x, y, bw, bh = [int(v * S) for v in box]
    xs, ys = [], []
    for yy in range(y, y + bh):
        for xx in range(x, x + bw):
            r, g, b = px(img, xx, yy); lum = (r + g + b) / 3
            if (lum < thr) if dark else (lum > thr):
                xs.append(xx); ys.append(yy)
    if not xs:
        return None
    return [round(min(xs) / S, 1), round(min(ys) / S, 1), round((max(xs) - min(xs) + 1) / S, 1), round((max(ys) - min(ys) + 1) / S, 1)]

if __name__ == '__main__':
    spec = json.load(open(sys.argv[1]))
    out = {}
    for name, path in (('mock', sys.argv[2]), ('device', sys.argv[3])):
        img = load(path); res = {}
        for key, m in spec.items():
            q = m.get(name, m)
            res[key] = region(img, *q['seed'], tol=q.get('tol', 10), limit=tuple(q.get('limit', (None,) * 4))) if q['kind'] == 'region' \
                else ink(img, q['box'], dark=q.get('dark', True), thr=q.get('thr', 110))
        out[name] = res
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
