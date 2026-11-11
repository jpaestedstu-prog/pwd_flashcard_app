"""What a browser's screen reader is told in the web app: words, no emoji.

    python tool/web_cdp.py --check speech --url http://127.0.0.1:8080/ --out build/web_speech

A screen reader reads an emoji by its name: TalkBack said "Welcome Back!
waving hand" (29 Oct). The app drops the pictures from every label, hint and
tooltip it hands a screen reader (lib/core/accessibility/spoken_words*.dart),
on the phone and in a browser. From a freshly onboarded profile (build with
WEB_TEST=1, as tool/web_smoke.py needs) this reads the page's accessibility
layer on each hub and checks that no label with words in it still carries a
picture. The ⭐ is the exception the app makes on purpose (it counts in stars,
"You earned 3 ⭐"), and a label that is only a picture keeps it, so that the
reader still names it.
"""
import argparse
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from web_smoke import Smoke, WebDriver, capabilities  # noqa: E402

# The app's SpokenWords.isPicture, the star aside.
PICTURE = re.compile(
    "[\U0001F000-\U0001FAFF☀-➿⬀-⭏⭑-⯿"
    "←-⇿⌀-⏿‍︀-️⃣]")
WORD = re.compile(r"[^\W_]", re.UNICODE)
ROUTES = ["/home", "/flashcards", "/games", "/stories", "/progress", "/settings"]


def problems_in(labels):
    """Labels that say words and still carry a picture."""
    out = []
    for label, role, _x, _y in labels:
        if PICTURE.search(label) and WORD.search(PICTURE.sub("", label)):
            out.append(f"{role}: {label!r}")
    return out


def main():
    # The labels carry emoji, which a Windows console cannot print otherwise.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--browser", default="chrome")
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    wd = WebDriver(args.driver, capabilities(args.browser))
    smoke = Smoke(wd, args.url, args.out)
    found, seen = [], 0
    try:
        wd.window(1280, 900)
        if not smoke.onboard():
            print("FAIL could not onboard a profile")
            sys.exit(1)
        for route in ROUTES:
            wd.js("location.hash = arguments[0];", route)
            time.sleep(5)
            labels = smoke.labels()
            seen += len(labels)
            bad = problems_in(labels)
            smoke.shot(route.strip("/") or "home")
            print(("OK      " if not bad else "PROBLEM ") + f"{route} ({len(labels)} labels)")
            for b in bad:
                print(f"    {b}")
                found.append(f"{route}: {b}")
    finally:
        wd.quit()
    print(f"WEB SPEECH {args.browser}: {len(ROUTES)} screens, {seen} labels, "
          f"{len(found)} with an emoji read by name")
    sys.exit(1 if found or seen == 0 else 0)


if __name__ == "__main__":
    main()
