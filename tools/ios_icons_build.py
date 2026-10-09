"""Builds the iOS app icons and launch image from the one master artwork.

The Android launcher icon is cut from `assets/images/icon app/newicon1.png`
(3200x3200, full-bleed). iOS draws its own rounded mask, so every size in
`AppIcon.appiconset` is that same square, scaled down, with NO alpha channel
(App Store Connect rejects a 1024 marketing icon that has one).

The launch screen shows the icon at 120 pt with its corners already rounded,
centred on the system background colour - the iOS twin of Android 12's
splash, which also shows the icon over the theme background.

Run from the repo root:  python tools/ios_icons_build.py
"""

import json
import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "images" / "icon app" / "newicon1.png"
ICONSET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
LAUNCH = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

# Launch image size in points; iOS picks @1x/@2x/@3x by screen scale.
LAUNCH_POINTS = 120
# Apple's app-icon corner radius is ~22.37% of the side.
CORNER = 0.2237


def main() -> int:
    master = Image.open(SOURCE).convert("RGB")
    if master.width != master.height:
        print(f"{SOURCE} is not square", file=sys.stderr)
        return 1

    contents = json.loads((ICONSET / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(points * scale)
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(ICONSET / entry["filename"], optimize=True)
        print(f"{entry['filename']}: {px}x{px}")

    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        px = LAUNCH_POINTS * scale
        # Draw the mask 4x larger and scale it down so the curve is smooth.
        big = px * 4
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=round(big * CORNER), fill=255
        )
        mask = mask.resize((px, px), Image.LANCZOS)
        art = master.resize((px, px), Image.LANCZOS).convert("RGBA")
        art.putalpha(mask)
        art.save(LAUNCH / name, optimize=True)
        print(f"{name}: {px}x{px}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
