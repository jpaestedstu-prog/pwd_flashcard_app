"""Turns walkthrough screenshots into store-ready screenshot sets.

    python tools/store_screenshots_build.py <walkthrough dir> <set name> [--play]

<walkthrough dir> is what integration_test/app_walkthrough_test.dart saved
(build/walkthrough/<device>/ locally, or a GitHub Actions artifact for the
iPhone/iPad runs). Picks the same eight screens from every device, saves them
as JPEG (no alpha, small) in docs/store/screenshots/<set name>/.

--play: Google Play refuses a screenshot whose long side is more than twice
its short side; a 1080x2400 phone is 2.22:1, so the set is centre-cropped to
2:1 (it loses only status-bar and gesture-bar margins). App Store sizes are
kept exactly as the simulator produced them (1320x2868 iPhone 6.9",
2064x2752 iPad 13").
"""

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
# (screenshot name fragment, output name) — first match wins.
SCREENS = [
    ("home_after_reward", "01-home"),
    ("_flashcards_viewer_0", "02-flashcard"),
    ("_flashcards.png", "03-decks"),
    ("_games_picture-word", "04-game-picture-word"),
    ("_fsl-dictionary", "05-sign-dictionary"),
    ("_communication-board", "06-talk-board"),
    ("_mood-check-in", "07-mood-check-in"),
    ("_progress", "08-progress"),
]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src = pathlib.Path(sys.argv[1])
    out = ROOT / "docs" / "store" / "screenshots" / sys.argv[2]
    play = "--play" in sys.argv
    files = sorted(src.glob("*.png"))
    out.mkdir(parents=True, exist_ok=True)
    for fragment, name in SCREENS:
        match = next((f for f in files if fragment in f.name), None)
        if match is None:
            print(f"  missing {fragment}")
            continue
        img = Image.open(match).convert("RGB")
        w, h = img.size
        if play and max(w, h) > 2 * min(w, h):
            if h > w:
                nh = 2 * w
                top = (h - nh) // 2
                img = img.crop((0, top, w, top + nh))
            else:
                nw = 2 * h
                left = (w - nw) // 2
                img = img.crop((left, 0, left + nw, h))
        target = out / f"{name}.jpg"
        img.save(target, quality=90, optimize=True)
        print(f"  {target.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
