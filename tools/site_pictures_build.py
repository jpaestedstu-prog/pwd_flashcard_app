"""Makes the "Features in Action" pictures: app screenshots and video posters as WebP.

    python tools/site_pictures_build.py [SHOTS_DIR]

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
SIZE = (600, 800)
# Where in each clip its poster frame is taken (seconds after the clip starts).
POSTER_AT = {"gaze-head": 6.0, "gaze-switch": 3.0, "gaze-talk": 8.0, "tour-cards": 4.0, "tour-fsl": 3.0,
             "tour-auto": 3.0, "tour-game": 9.0, "tour-talk": 4.0, "tour-all": 6.0}


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "site_pictures"
    OUT.mkdir(parents=True, exist_ok=True)
    pngs = sorted(src.glob("*.png"))
    total = 0
    for name, shot in SHOTS.items():
        match = next((p for p in pngs if p.stem.split("_", 1)[-1] == shot), None)
        if match is None:
            sys.exit(f"no screenshot named *_{shot}.png in {src}")
        img = Image.open(match).convert("RGB")
        if abs(img.width / img.height - SIZE[0] / SIZE[1]) > 0.01:
            sys.exit(f"{match.name} is {img.width}x{img.height}, not 3:4")
        img = img.resize(SIZE, Image.LANCZOS)
        img.save(OUT / name, "WEBP", quality=80, method=6)
        total += (OUT / name).stat().st_size
        print(f"{match.name} -> assets/features/{name}: {(OUT / name).stat().st_size // 1024} KB")
    for clip, (video, a, b) in sm.CLIPS.items():
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
