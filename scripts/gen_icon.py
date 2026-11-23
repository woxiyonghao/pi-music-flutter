"""Generate the PhonoraMusic app icon (neon blue background, white vinyl + tonearm)."""
import math, sys
from PIL import Image, ImageDraw

S = 4096  # supersample
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/icon/app_icon_1024.png"
FG_ONLY = len(sys.argv) > 2 and sys.argv[2] == "fg"  # transparent foreground for adaptive icon

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
if not FG_ONLY:
    top, bot = (0, 214, 255), (0, 110, 255)  # fluorescent blue gradient
    px = img.load()
    bg = Image.new("RGB", (S, S))
    d0 = ImageDraw.Draw(bg)
    for y in range(S):
        d0.line([(0, y), (S, y)], fill=lerp(top, bot, y / S))
    img = bg.convert("RGBA")

d = ImageDraw.Draw(img)
c = S / 2
cx, cy = c - S * 0.03, c + S * 0.02
R = S * 0.27
W = (255, 255, 255, 255)
BLUE = (0, 150, 255, 255)

def ring(r, w, col=W):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=int(w))

d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=W)       # record body
for r, w in [(0.86, 0.010), (0.72, 0.010), (0.58, 0.010)]:  # grooves
    ring(R * r, S * w, (150, 205, 255, 255))
lab = R * 0.40
d.ellipse([cx - lab, cy - lab, cx + lab, cy + lab], fill=BLUE)  # label
hole = R * 0.07
d.ellipse([cx - hole, cy - hole, cx + hole, cy + hole], fill=W)

# tonearm: pivot top-right, needle onto record
px_, py_ = c + S * 0.27, c - S * 0.28
nx, ny = cx + R * 0.62, cy - R * 0.40
mx, my = px_ - S * 0.02, py_ + (ny - py_) * 0.55
lw = int(S * 0.028)
d.line([(px_, py_), (mx, my), (nx, ny)], fill=W, width=lw, joint="curve")
for p in [(px_, py_), (nx, ny)]:
    d.ellipse([p[0] - lw * .9, p[1] - lw * .9, p[0] + lw * .9, p[1] + lw * .9], fill=W)
d.ellipse([px_ - lw * .4, py_ - lw * .4, px_ + lw * .4, py_ + lw * .4], fill=BLUE)

img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("saved", OUT)
