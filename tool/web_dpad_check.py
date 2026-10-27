"""The arrow keys as a D-pad in the web app, in a real browser.

    python tool/web_dpad_check.py --driver http://127.0.0.1:9515 \
        --browser chrome --url http://127.0.0.1:8080/ --out build/web_dpad

A browser's default turns the arrow keys into scrolling, so a keyboard, a
switch box sending arrows or a TV-style remote could not reach a single tab
or tile there. From a freshly onboarded profile (as tool/web_smoke.py makes
one: build with WEB_TEST=1 so nothing reaches the cloud) this checks that:

  1. down-arrow steps from control to control on Home;
  2. it carries on down to the tab bar, and right-arrow walks the tabs;
  3. Enter on a tab opens it, and the arrows and Enter open a deck there.

Flutter mirrors its keyboard focus into the page's accessibility layer, which
the smoke test switches on, so the focused control is read from
document.activeElement. A screenshot of each step is saved to --out.
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from web_smoke import Smoke, WebDriver, capabilities  # noqa: E402

KEYS = {
    "down": "", "up": "", "left": "", "right": "",
    "enter": "",
}
TABS = ("Home", "Cards", "Games", "Stories", "Progress")


def press(wd, key, pause=0.5):
    wd.s("POST", "/actions", {"actions": [{
        "type": "key", "id": "keyboard",
        "actions": [{"type": "keyDown", "value": KEYS[key]},
                    {"type": "keyUp", "value": KEYS[key]}],
    }]})
    try:
        wd.s("DELETE", "/actions")
    except RuntimeError:
        pass
    time.sleep(pause)


def focused(wd):
    return wd.js(
        "const e = document.activeElement;"
        "if (!e || e === document.body) return null;"
        "const l = e.getAttribute('aria-label') || e.textContent || e.innerText || '';"
        "return l.trim().split('\\n')[0].slice(0, 80) || '(unnamed)';")


def tab_of(label):
    """The tab a focused label names. A tab's label can repeat its name
    ("Progress Progress": the item's own label and its caption)."""
    word = (label or "").split(" ")[0]
    return word if word in TABS else None


def location(wd):
    return wd.js("return location.pathname + location.hash;")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--browser", default="chrome")
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    wd = WebDriver(args.driver, capabilities(args.browser))
    smoke = Smoke(wd, args.url, args.out)
    problems, log = [], []

    def check(ok, what):
        log.append(("PASS " if ok else "FAIL ") + what)
        if not ok:
            problems.append(what)

    def run():
        wd.window(1280, 900)
        if not smoke.onboard():
            problems.append("could not onboard a profile")
            return
        start = location(wd)

        # 1. Down steps through Home's controls (and only moves focus: the
        #    page is still Home).
        seen = []
        for _ in range(6):
            press(wd, "down")
            seen.append(focused(wd))
        smoke.shot("dpad_home_steps")
        # Read from the page's own focus, which follows only the controls
        # whose accessibility node takes focus: the cards that set their own
        # label (My Day, Mood Check-In) are stepped through too — the ring is
        # on them in the screenshot — but leave the page's focus where it was.
        distinct = [s for s in dict.fromkeys(seen) if s and s != "(unnamed)"]
        check(len(distinct) >= 3, f"down-arrow steps through Home: {seen}")
        check(location(wd) == start, f"arrows move focus, not the page ({location(wd)})")

        # 2. On down to the tab bar, then along it to Cards from whichever
        #    tab down arrived at, and on and back.
        tab = None
        for _ in range(120):
            press(wd, "down", pause=0.35)
            tab = tab_of(focused(wd))
            if tab:
                break
        check(tab is not None, f"down-arrow reaches the tab bar (last: {focused(wd)})")
        if tab is None:
            return
        toward = "left" if TABS.index(tab) > TABS.index("Cards") else "right"
        walked = [tab]
        for _ in range(6):
            if walked[-1] == "Cards":
                break
            press(wd, toward)
            walked.append(tab_of(focused(wd)))
        smoke.shot("dpad_tab_bar")
        check(walked[-1] == "Cards" and None not in walked,
              f"{toward}-arrow walks the tabs to Cards: {walked}")
        press(wd, "right")
        check(tab_of(focused(wd)) == "Games", f"right-arrow goes on to Games ({focused(wd)})")
        press(wd, "left")
        check(tab_of(focused(wd)) == "Cards", f"left-arrow comes back to Cards ({focused(wd)})")

        # 3. Enter opens a tab; arrows and Enter open a deck on it.
        press(wd, "enter", pause=2.5)
        check("/flashcards" in location(wd), f"Enter opens Cards ({location(wd)})")
        deck = None
        for _ in range(4):
            press(wd, "down")
            label = focused(wd) or ""
            if "deck" in label.lower():
                deck = label
                break
        check(deck is not None, f"down-arrow reaches a deck ({focused(wd)})")
        press(wd, "enter", pause=3)
        smoke.shot("dpad_deck_opened")
        # The viewer is pushed over Cards, and a pushed page does not change
        # the address, so it is known by its own buttons.
        check(bool(smoke.find("Flip") and smoke.find("Next")),
              f"Enter opens the deck (on screen: {smoke.text()[:120]})")
        errors = smoke.page_errors()
        check(not errors, f"no page errors ({errors[:2]})")

    try:
        run()
    finally:
        wd.quit()
        print(f"WEB DPAD {args.browser}: {len(log) - len(problems)} passed, "
              f"{len(problems)} failed")
        for line in log:
            print("  " + line)
        with open(os.path.join(args.out, "result.json"), "w", encoding="utf-8") as f:
            json.dump({"log": log, "problems": problems}, f, indent=1)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
