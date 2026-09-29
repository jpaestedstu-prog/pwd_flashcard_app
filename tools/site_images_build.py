"""Convert website screenshots from PNG to WebP.

    python tools/site_images_build.py [SOURCE_DIR]

SOURCE_DIR defaults to website/assets/screenshots. Every NN-name.png there
becomes website/assets/screenshots/NN-name.webp (same 1200x1920 size, so the
lightbox stays sharp), and the PNG is removed from the site folder. A tablet
screenshot is ~600 KB as PNG and ~100 KB as WebP — on a slow connection the
home page's eight screenshots took about 40 seconds as PNG.

Needs ffmpeg with libwebp (C:\\ffmpeg\\bin\\ffmpeg.exe on this machine).
"""
import os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "website" / "assets" / "screenshots"
FFMPEG = shutil.which("ffmpeg") or r"C:\ffmpeg\bin\ffmpeg.exe"
QUALITY = "80"


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    pngs = sorted(src.glob("*.png"))
    if not pngs:
        sys.exit(f"no PNG screenshots in {src}")
    total_in = total_out = 0
    for png in pngs:
        webp = OUT / (png.stem + ".webp")
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(png),
                        "-c:v", "libwebp", "-quality", QUALITY, "-compression_level", "6",
                        str(webp)], check=True)
        a, b = png.stat().st_size, webp.stat().st_size
        total_in += a
        total_out += b
        print(f"{png.name}: {a // 1024} KB -> {webp.name}: {b // 1024} KB")
        if png.parent == OUT:
            png.unlink()
    print(f"total {total_in // 1024} KB -> {total_out // 1024} KB")


if __name__ == "__main__":
    main()
