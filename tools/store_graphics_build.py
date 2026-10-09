"""Builds the Google Play listing graphics from the app's own art and fonts.

    python tools/store_graphics_build.py

Writes docs/store/graphics/:
  play-icon-512.png             512x512 store icon (Play adds its own mask)
  play-feature-graphic.png      1024x500 banner at the top of the listing

The art is the launcher icon's master (assets/images/icon app/newicon1.png);
the gradient is the adaptive icon's background (#C3F6F7 -> #41C5F0); the type
is the app's Fredoka and Nunito.
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets" / "images" / "icon app" / "newicon1.png"
FONTS = ROOT / "google_fonts"
OUT = ROOT / "docs" / "store" / "graphics"

TOP = (0xC3, 0xF6, 0xF7)
BOTTOM = (0x41, 0xC5, 0xF0)
INK = (0x0B, 0x2E, 0x4F)  # 9.4:1 to 7.0:1 against the gradient behind the text


def gradient(size):
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for x in range(w):
        t = x / (w - 1)
        color = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        draw.line([(x, 0), (x, h)], fill=color)
    return img


def rounded(img, radius):
    mask = Image.new("L", (img.width * 4, img.height * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask.width - 1, mask.height - 1), radius=radius * 4, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask.resize(img.size, Image.LANCZOS))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = Image.open(MASTER).convert("RGB")

    master.resize((512, 512), Image.LANCZOS).save(OUT / "play-icon-512.png", optimize=True)

    banner = gradient((1024, 500))
    icon = rounded(master.resize((300, 300), Image.LANCZOS), 66)
    banner.paste(icon, (70, 100), icon)
    draw = ImageDraw.Draw(banner)
    title = ImageFont.truetype(str(FONTS / "Fredoka-Bold.ttf"), 76)
    line = ImageFont.truetype(str(FONTS / "Nunito-Bold.ttf"), 32)
    draw.text((420, 128), "FlashLearn PWD", font=title, fill=INK)
    draw.text((424, 236), "Words, games and Filipino", font=line, fill=INK)
    draw.text((424, 280), "Sign Language for every learner", font=line, fill=INK)
    draw.text((424, 336), "English  •  Filipino  •  FSL", font=line, fill=INK)
    banner.save(OUT / "play-feature-graphic.png", optimize=True)
    for f in sorted(OUT.iterdir()):
        print(f.name, Image.open(f).size)


if __name__ == "__main__":
    main()
