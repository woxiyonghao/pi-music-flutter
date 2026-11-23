"""Resize assets/icon/app_icon_1024.png over every existing platform icon file (same pixel size)."""
import glob
from PIL import Image
src = Image.open("assets/icon/app_icon_1024.png").convert("RGB")
pats = ["android/app/src/main/res/mipmap-*/ic_launcher.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png",
        "macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png"]
n = 0
for p in pats:
    for f in glob.glob(p):
        w, h = Image.open(f).size
        src.resize((w, h), Image.LANCZOS).save(f)
        n += 1
print("updated", n)
