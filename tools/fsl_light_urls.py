"""Gives each FSL sign in the app's manifest its light copy from the website.

The app's own clips are 1920x1080 at 60 frames a second (about 8 MB each).
Budget phones froze on them or never started them, and on mobile data the
wait for one sign was long. The website already serves every sign at
854x480, 30 frames a second, silent (about 0.3 MB): the same recordings,
re-encoded with the recipe in tools/README.md. This script writes each
entry's `light_url` to that copy, so phones can play it instead
(FslAssetsService / FslClipQuality decide when).

A light copy is attached ONLY when it is provably the same recording as the
app's own clip: their durations must agree within 0.15 s (the light copy is
a 30 fps re-encode, so they differ by a frame at most). A sign whose website
clip is a different take, or a different word, gets no light_url and keeps
playing the app's own sources.

    python tools/fsl_light_urls.py            # check every entry, write the manifest
    python tools/fsl_light_urls.py --check    # check only; exit 1 if the manifest is stale

Needs ffprobe (C:/ffmpeg/bin or PATH) and the network: each app clip's
duration is read from its download_url (only the first few KB are fetched;
the clips are "faststart").
"""
import concurrent.futures as cf
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "data", "fsl_video_manifest.json")
DICT_JS = os.path.join(ROOT, "website", "assets", "fsl-dict.js")
CLIPS = os.path.join(ROOT, "website", "assets", "videos", "fsl")
SITE = "https://jpaestedstu-prog.github.io/pwd_flashcard_app/assets/videos/fsl/"
TOLERANCE_S = 0.15


def ffprobe():
    for c in (r"C:\ffmpeg\bin\ffprobe.exe", shutil.which("ffprobe")):
        if c and os.path.exists(c):
            return c
    sys.exit("ffprobe not found")


def duration(probe, src):
    for _ in range(3):
        r = subprocess.run([probe, "-v", "error", "-show_entries", "format=duration",
                            "-of", "default=nw=1:nk=1", src], capture_output=True, text=True)
        try:
            return float(r.stdout.strip())
        except ValueError:
            continue
    return None


def website_clips():
    """(category, english lowercased) -> clip file stem, from the dictionary page."""
    s = open(DICT_JS, encoding="utf-8").read()
    cats = json.loads(re.search(r"window.FSL_CATS = (\[.*?\]);", s, re.S).group(1))
    return {(cats[int(c)]["en"], en.lower()): f
            for c, f, en in re.findall(r'\{c:(\d+),f:"([^"]+)",en:"([^"]+)"', s)}


def main():
    check_only = "--check" in sys.argv
    probe = ffprobe()
    manifest = json.load(open(MANIFEST, encoding="utf-8"))
    entries = manifest["entries"]
    clips = website_clips()

    def verdict(e):
        stem = clips.get((e["category"], e["word_english"].lower()))
        local = os.path.join(CLIPS, f"{stem}.mp4") if stem else None
        if not local or not os.path.exists(local):
            return e, None, "no website clip"
        theirs = duration(probe, e["download_url"])
        ours = duration(probe, local)
        if theirs is None or ours is None:
            return e, None, f"could not read durations ({theirs}, {ours})"
        if abs(theirs - ours) > TOLERANCE_S:
            return e, None, f"different recording ({theirs:.2f} s vs {ours:.2f} s)"
        return e, SITE + stem + ".mp4", None

    stale, attached = [], 0
    with cf.ThreadPoolExecutor(6) as pool:
        for e, url, why in pool.map(verdict, entries):
            label = f"{e['category']} / {e['word_english']}"
            if url:
                attached += 1
            else:
                print(f"no light copy: {label}: {why}")
            if e.get("light_url") != url:
                stale.append(label)
                if url:
                    e["light_url"] = url
                else:
                    e.pop("light_url", None)
    print(f"{attached} of {len(entries)} signs have a light copy")
    if check_only:
        if stale:
            print("STALE: " + ", ".join(stale))
            sys.exit(1)
        print("manifest up to date")
        return
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {MANIFEST} ({len(stale)} entries changed)")


if __name__ == "__main__":
    main()
