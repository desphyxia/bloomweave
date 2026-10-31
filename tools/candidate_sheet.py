"""Draw a contact sheet of generated valley candidates (needs Pillow).

Usage: python3 tools/candidate_sheet.py candidates.json out.png [count]
Each tile shows the plots (landmark in orange), the hills around them and
the candidate's number and scores.
"""
import json
import math
import sys

from PIL import Image, ImageDraw

S3 = math.sqrt(3)


def hex_xy(q, r):
    return 1.5 * q, S3 * (r + q / 2)


def tile(draw, cand, ox, oy, w, h, label):
    plots = [tuple(p) for p in cand["plots"]]
    hexes = [(b[0] + dq, b[1] + dr) for b in plots for dq, dr in ((0, 0), (1, 0), (0, 1))]
    xs = [hex_xy(*hx)[0] for hx in hexes]
    zs = [hex_xy(*hx)[1] for hx in hexes]
    cx, cz = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
    span = max(max(xs) - min(xs), max(zs) - min(zs)) + 10
    s = min(w, h - 40) / span
    def to_px(x, z):
        return ox + w / 2 + (x - cx) * s, oy + 30 + (h - 40) / 2 + (z - cz) * s
    for hill in cand.get("hills", []):
        px, pz = to_px(hill[0], hill[1])
        r = hill[2] * s
        shade = int(200 - min(hill[3], 5) * 18)
        draw.ellipse([px - r, pz - r, px + r, pz + r], fill=(shade - 40, shade, shade - 60), outline=(90, 110, 80))
    land = tuple(cand["landmark"])
    for b in plots:
        for dq, dr in ((0, 0), (1, 0), (0, 1)):
            x, z = hex_xy(b[0] + dq, b[1] + dr)
            pts = [to_px(x + math.cos(math.radians(60 * k)), z + math.sin(math.radians(60 * k))) for k in range(6)]
            draw.polygon(pts, fill=(245, 170, 70) if b == land else (238, 226, 190), outline=(120, 100, 80))
    draw.text((ox + 8, oy + 6), label, fill=(30, 30, 30))


def main():
    cands = json.load(open(sys.argv[1]))
    count = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    cands = cands[:count]
    cols = 3
    w, h = 360, 340
    rows = (len(cands) + cols - 1) // cols
    img = Image.new("RGB", (cols * w, rows * h), (250, 248, 240))
    d = ImageDraw.Draw(img)
    for i, c in enumerate(cands):
        m = c["metrics"]
        settle = ", ".join(f"{k} {v}%" for k, v in m["settle"].items())
        label = f"{chr(65 + i)}  ({m['plots']} plots, {m['bloom_spots']} bloom spots)\n{settle}; visitor {m['visitor_chance']}% luck / {m['visitor_sought']}% sought"
        tile(d, c, (i % cols) * w, (i // cols) * h, w, h, label)
    img.save(sys.argv[2])


if __name__ == "__main__":
    main()
