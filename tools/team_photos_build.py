"""Makes the team's photos for about.html ("Meet the team") from the originals in PICTURES/.

    python tools/team_photos_build.py            write website/assets/team/*.webp
    python tools/team_photos_build.py --check    fail if a photo is missing or the wrong size

PICTURES/ holds one square photo per team member, named by role (the team's own pictures;
the folder stays out of Git). Each one is cut to the same head-and-shoulders frame (4:5),
made 560 x 700 and saved as WebP. Nothing else from the original goes with it: no camera
details, no date, no location (Pillow writes only the pixels).

The crop boxes are fractions of each square photo (left, top, right, bottom), chosen by
looking at the pictures so that every face sits at about the same place in its card.
"""
import os, sys
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "PICTURES"
OUT = ROOT / "website" / "assets" / "team"
SIZE = (560, 700)

# website file -> (original in PICTURES/, crop box)
PHOTOS = {
    "leader-programmer.webp": ("LEADER & PROGRAMMER.png", (0.06, 0.00, 0.86, 1.00)),
    "designer.webp": ("DESIGNER.png", (0.10, 0.00, 0.90, 1.00)),
    "researcher.webp": ("RESEARCHER.png", (0.11, 0.035, 0.53, 0.56)),
    "supporter.webp": ("SUPPORTER.png", (0.315, 0.30, 0.635, 0.70)),
}


def check():
    bad = []
    for name in PHOTOS:
        p = OUT / name
        if not p.exists():
            bad.append(f"missing {p.relative_to(ROOT)}")
            continue
        with Image.open(p) as im:
            if im.size != SIZE or im.format != "WEBP":
                bad.append(f"{name} is {im.format} {im.size}, not WEBP {SIZE}")
            if im.info.get("exif") or im.info.get("xmp"):
                bad.append(f"{name} carries metadata")
    if bad:
        sys.exit("team photos: " + "; ".join(bad))
    print(f"team photos OK ({len(PHOTOS)})")


def main():
    if "--check" in sys.argv:
        return check()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (src, (l, t, r, b)) in PHOTOS.items():
        with Image.open(SRC / src) as original:
            img = ImageOps.exif_transpose(original).convert("RGB")
        w, h = img.size
        img = img.crop((round(l * w), round(t * h), round(r * w), round(b * h)))
        if abs(img.width / img.height - SIZE[0] / SIZE[1]) > 0.01:
            sys.exit(f"{src}: the crop is {img.width}x{img.height}, not 4:5")
        img = img.resize(SIZE, Image.LANCZOS)
        img.save(OUT / name, "WEBP", quality=80, method=6)
        print(f"{src} -> assets/team/{name}: {(OUT / name).stat().st_size // 1024} KB")
    check()


if __name__ == "__main__":
    main()
