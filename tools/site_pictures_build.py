"""Makes the website's app pictures from the emulator screenshots, as WebP.

    python tools/site_pictures_build.py [SHOTS_DIR] [--sets features,kids,tour]

Three sets (all of them unless --sets names some):
  features  the "Features in Action" pictures and the video posters -> assets/features/
  kids      the Child screens for the guides "For children" (guides.html) -> assets/kids/
  tour      the App Tour's eleven pictures (how-to-use.html) and the Home page's phone
            picture (02-home) -> assets/screenshots/
The emulator's screenshots come in the tablet's own upright shape, 5:8 (the 2026-11-16 run;
an earlier run gave 3:4, which is why the Features pictures are 3:4). Each set says its size.

SHOTS_DIR (default build/site_pictures) holds the PNGs that
integration_test/site_pictures_test.dart saved on an Android emulator (sample profiles
"Ana" and "Ms. Cruz", offline, so nothing reached the cloud). The ones the website uses
are listed below by name and written to website/assets/features/ at 600 x 800 (the
screenshots are 3:4), ~40-70 KB each. The posters are one frame of each clip in
tools/site_media.py, taken from the site's own videos.

Needs Pillow and ffmpeg (C:\\ffmpeg\\bin\\ffmpeg.exe on this machine).
"""
import os, shutil, subprocess, sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import site_media as sm   # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "website" / "assets" / "features"
FFMPEG = shutil.which("ffmpeg") or r"C:\ffmpeg\bin\ffmpeg.exe"

# website picture -> the screenshot it comes from (the part of the name after "NN_")
SHOTS = {
    "gaze.webp": "gaze_top",
    "voice.webp": "gaze_voice",
    "switch-choose.webp": "gaze_choose",
    "switch-scan.webp": "gaze_scanning",
    "controller.webp": "controller",
    "look-normal.webp": "look_normal",
    "look-large.webp": "look_large_contrast",
    "look-dark.webp": "look_dark",
    "look-dyslexia.webp": "look_dyslexia",
    "read-card.webp": "flashcard",
    "read-settings.webp": "settings_speech",
    "adaptive.webp": "settings_learning",
    "break-learner.webp": "break_reminder",
    "break-adult.webp": "break_settings_on",
    "my-day.webp": "my_day_start",
    "my-day-adult.webp": "routine_manage",
    "talk-board.webp": "talk_board",
    "teacher-home.webp": "teacher_home",
    "assign.webp": "assign_tasks",
    "time-limits.webp": "time_limits",
    "tv-cast.webp": "tv_cast",
    "decks.webp": "decks",
    "games.webp": "games",
    "stories.webp": "stories",
    "buddy.webp": "learner_home",
}
# Child screens (sample child "Mia") for tools/kids_guides.py.
KIDS = {
    "join.webp": "kids_join",
    "home.webp": "kids_home",
    "card.webp": "kids_card",
    "games.webp": "kids_games",
    "stories.webp": "kids_stories",
    "talk.webp": "kids_talk",
    "my-day.webp": "kids_my_day",
    "feelings.webp": "kids_feelings",
    "buddy.webp": "kids_buddy",
    "rewards.webp": "kids_rewards",
    "stickers.webp": "kids_stickers",
}
# App Tour steps (how-to-use.html), in order; 02-home is also the Home page's phone picture.
TOUR = {
    "01-choose-profile.webp": "choose_profile",
    "02-home.webp": "learner_home",
    "03-cards-decks.webp": "decks",
    "04-flashcard-viewer.webp": "flashcard",
    "05-games.webp": "games",
    "06-stories.webp": "stories",
    "07-progress.webp": "progress",
    "08-settings.webp": "settings_top",
    "09-talk-board.webp": "talk_board",
    "10-my-day.webp": "my_day_plans",
    "11-gaze-control.webp": "gaze_top",
}
SIZE = (600, 800)          # Features pictures, 3:4
KIDS_SIZE = (600, 960)     # 5:8
TOUR_SIZE = (800, 1280)    # 5:8, shown full size when tapped
# Where in each clip its poster frame is taken (seconds after the clip starts).
POSTER_AT = {"gaze-head": 6.0, "gaze-switch": 3.0, "gaze-talk": 8.0, "tour-cards": 4.0, "tour-fsl": 3.0,
             "tour-auto": 3.0, "tour-game": 9.0, "tour-talk": 4.0, "tour-all": 6.0}


def pictures(pngs, src, mapping, out, size=SIZE):
    """Each screenshot in `mapping` (by the part of its name after "NN_") to out/ as WebP."""
    out.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, shot in mapping.items():
        match = next((p for p in pngs if p.stem.split("_", 1)[-1] == shot), None)
        if match is None:
            sys.exit(f"no screenshot named *_{shot}.png in {src}")
        img = Image.open(match).convert("RGB")
        if abs(img.width / img.height - size[0] / size[1]) > 0.01:
            sys.exit(f"{match.name} is {img.width}x{img.height}, not {size[0]}:{size[1]}")
        img = img.resize(size, Image.LANCZOS)
        img.save(out / name, "WEBP", quality=80, method=6)
        total += (out / name).stat().st_size
        print(f"{match.name} -> {out.relative_to(ROOT / 'website').as_posix()}/{name}: {(out / name).stat().st_size // 1024} KB")
    return total


def main():
    args = sys.argv[1:]
    sets = ["features", "kids", "tour"]
    if "--sets" in args:
        i = args.index("--sets")
        sets = args[i + 1].split(",")
        args = args[:i] + args[i + 2:]
    src = Path(args[0]) if args else ROOT / "build" / "site_pictures"
    pngs = sorted(src.glob("*.png"))
    total = 0
    if "kids" in sets:
        total += pictures(pngs, src, KIDS, ROOT / "website" / "assets" / "kids", KIDS_SIZE)
    if "tour" in sets:
        total += pictures(pngs, src, TOUR, ROOT / "website" / "assets" / "screenshots", TOUR_SIZE)
    if "features" not in sets:
        print(f"total {total // 1024} KB")
        return
    total += pictures(pngs, src, SHOTS, OUT)
    used = {d["clip"] for d in sm.DEMOS.values() if "clip" in d}
    for clip, (video, a, b) in sm.CLIPS.items():
        if clip not in used:      # a part no demo shows needs no poster
            continue
        v = sm.VIDEOS[video]
        at = a + POSTER_AT.get(clip, 1.0)
        dst = OUT / f"poster-{clip}.webp"
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-ss", f"{at:.2f}", "-i", str(ROOT / "website" / v["file"]),
                        "-frames:v", "1", "-vf", f"scale={v['w'] // 2}:-2", "-c:v", "libwebp", "-quality", "75",
                        str(dst)], check=True)
        total += dst.stat().st_size
        print(f"poster {clip} at {at:.1f}s -> assets/features/{dst.name}: {dst.stat().st_size // 1024} KB")
    print(f"total {total // 1024} KB")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
