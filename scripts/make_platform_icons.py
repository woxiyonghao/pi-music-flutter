"""Derive extra icon assets from assets/icon/app_icon_1024.png and gen_icon.py (fg mode).

Outputs:
  assets/icon/play_store_512.png                 Google Play listing icon
  assets/icon/app_icon_foreground_1024.png       transparent glyph for Android adaptive icon
  android/.../drawable-nodpi/ic_launcher_foreground.png (432px, glyph in safe zone)
  windows/runner/resources/app_icon.ico          multi-size .ico
  linux/runner/app_icon.png                      256px window icon
"""
import os, subprocess, sys
from PIL import Image

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
src = Image.open("assets/icon/app_icon_1024.png").convert("RGB")
src.resize((512, 512), Image.LANCZOS).save("assets/icon/play_store_512.png")

fg_path = "assets/icon/app_icon_foreground_1024.png"
subprocess.check_call([sys.executable, "scripts/gen_icon.py", fg_path, "fg"])
fg = Image.open(fg_path).convert("RGBA")
# adaptive icon safe zone is the centre 66/108; shrink glyph so it never gets clipped
canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
k = 0.80
small = fg.resize((int(1024 * k), int(1024 * k)), Image.LANCZOS)
canvas.paste(small, ((1024 - small.width) // 2, (1024 - small.height) // 2), small)
res = "android/app/src/main/res"
if os.path.isdir(res):
    os.makedirs(f"{res}/drawable-nodpi", exist_ok=True)
    canvas.resize((432, 432), Image.LANCZOS).save(f"{res}/drawable-nodpi/ic_launcher_foreground.png")

if os.path.isdir("windows/runner/resources"):
    src.save("windows/runner/resources/app_icon.ico",
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
if os.path.isdir("linux/runner"):
    src.resize((256, 256), Image.LANCZOS).save("linux/runner/app_icon.png")
print("done")
