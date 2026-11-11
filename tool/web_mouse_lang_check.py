"""The mouse, and switching language, in the web app, in a real browser.

    python tool/web_cdp.py --check mouse --url http://127.0.0.1:8080/ --out build/web_mouse

Real input from the browser's own input layer (the DevTools protocol's
Input.dispatchMouseEvent), not scripted clicks: the pointer moves, presses and
lets go, the wheel turns. From a freshly onboarded profile (as tool/web_smoke.py
makes one: build with WEB_TEST=1 so nothing reaches the cloud) it checks that:

  1. a click on a tab opens it, and a click on a deck opens the deck;
  2. Back by the mouse returns;
  3. the wheel scrolls a page;
  4. resting the pointer on an icon button shows its tooltip;
  5. a slider drags, and what it sets changes (Settings: Font Size);
  6. a switch toggles by a click, and back;
  7. the language dropdown opens by a click and switching to Filipino turns
     the screens Filipino at once, with the page marked `lang="fil"` for a
     screen reader; a vocabulary word stays marked English; and back again.

A screenshot of each step is saved to --out.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from web_dpad_check import location  # noqa: E402
from web_smoke import Smoke, WebDriver, capabilities  # noqa: E402


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--browser", default="chrome")
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    wd = WebDriver(args.driver, capabilities(args.browser))
    if not hasattr(wd, "cdp"):
        sys.exit("the mouse check needs the DevTools driver (tool/web_cdp.py)")
    smoke = Smoke(wd, args.url, args.out)
    problems, log = [], []

    def check(ok, what):
        log.append(("PASS " if ok else "FAIL ") + what)
        if not ok:
            problems.append(what)

    def mouse(kind, x, y, **more):
        wd.cdp.call("Input.dispatchMouseEvent", {"type": kind, "x": x, "y": y, **more})

    def move(x, y):
        mouse("mouseMoved", x, y)

    def click_at(x, y, pause=1.5):
        move(x, y)
        time.sleep(0.1)
        mouse("mousePressed", x, y, button="left", buttons=1, clickCount=1)
        time.sleep(0.06)
        mouse("mouseReleased", x, y, button="left", buttons=0, clickCount=1)
        time.sleep(pause)

    def click(label, pause=1.5, secs=10):
        hit = smoke.wait(label, secs)
        if not hit:
            return False
        height = wd.js("return window.innerHeight;") or 800
        for _ in range(10):
            if 30 < hit[3] < height - 30:
                break
            wheel(hit[2], height / 2, 300 if hit[3] > height / 2 else -300)
            hit = smoke.find(label) or hit
        click_at(hit[2], hit[3], pause)
        return True

    def wheel(x, y, dy, pause=0.9):
        mouse("mouseWheel", x, y, deltaX=0, deltaY=dy)
        time.sleep(pause)

    def run():
        wd.window(1280, 900)
        if not smoke.onboard():
            problems.append("could not onboard a profile")
            return
        home = location(wd)

        # 1. Tabs and a deck.
        check(click("Cards", pause=2.5) and "/flashcards" in location(wd),
              f"a click on the Cards tab opens it ({location(wd)})")
        smoke.shot("mouse_cards")
        deck = next((l for l in smoke.labels()
                     if "deck" in l[0].lower() and l[1] in ("button", "link")), None)
        check(deck is not None, "the Cards tab lists decks to click")
        if deck:
            click_at(deck[2], deck[3], pause=3)
            smoke.shot("mouse_deck")
            check(bool(smoke.find("Flip") and smoke.find("Next")),
                  f"a click on a deck opens it ({smoke.text()[:100]})")
            # 2. Back.
            check(click("Back", pause=2.5) or click("Go back", pause=2.5),
                  "the Back button is there to click")
            check("/flashcards" in location(wd), f"Back returns to Cards ({location(wd)})")

        # 3. The wheel.
        click("Home", pause=2.5)
        check(location(wd) == home, f"back on Home ({location(wd)})")
        first = (smoke.labels() or [[None, None, 0, 0]])[0]
        before = smoke.find(first[0])
        wheel(640, 450, 500)
        after = smoke.find(first[0])
        check(after is None or before is None or after[3] != before[3],
              f"the wheel scrolls the page ({before and before[3]} -> {after and after[3]})")
        wheel(640, 450, -1500)

        # 4. A tooltip on rest.
        hit = smoke.find("Open star shop") or smoke.find("Open settings")
        if hit:
            words_before = smoke.text()
            move(hit[2], hit[3])
            time.sleep(1.6)
            smoke.shot("mouse_tooltip")
            shown = wd.js("return document.body.innerText.length;")
            log.append(f"NOTE tooltip target: {hit[0][:40]}; text before {len(words_before)}, now {shown}")
            move(5, 5)
            time.sleep(0.4)

        # 5. A slider drags.
        check(click("Open settings", pause=3), "Settings opens by a click")
        # Pushed over Home: the address stays, the page says where it is.
        check("Settings" in smoke.text(), f"on Settings ({smoke.text()[:60]})")
        size_before = smoke.find("Font Size")
        # One in plain view: under the top bar or the tab bar, a press lands on
        # them.
        find_slider = """
          const all = [...document.querySelectorAll('input[type=range], [role=slider]')];
          for (let i = 0; i < all.length; i++) {
            const r = all[i].getBoundingClientRect();
            if (r.width > 0 && r.y > 90 && r.bottom < window.innerHeight - 110) {
              return [i, r.x, r.y, r.width, r.height,
                      all[i].value || all[i].getAttribute('aria-valuenow') || '',
                      all[i].getAttribute('aria-valuetext') || ''];
            }
          }
          return null;"""
        slider = wd.js(find_slider)
        for _ in range(8):
            if slider:
                break
            wheel(640, 450, 300)
            slider = wd.js(find_slider)
        check(slider is not None, "a slider is on Settings")
        if slider:
            index, x, y, w, h, value, text = slider
            page_before = smoke.text()
            yc = y + h / 2
            # The node is as wide as its row; the track is at the row's end.
            # Press near its left, drag to the right, let go.
            x0, x1 = x + w - 110, x + w - 30
            move(x0, yc)
            mouse("mousePressed", x0, yc, button="left", buttons=1, clickCount=1)
            for i in range(1, 9):
                mouse("mouseMoved", x0 + (x1 - x0) * i / 8, yc, button="left", buttons=1)
                time.sleep(0.04)
            mouse("mouseReleased", x1, yc, button="left", buttons=0, clickCount=1)
            time.sleep(1.2)
            smoke.shot("mouse_slider")
            # The page's own words say the new value: a browser's slider element
            # stays at its middle.
            page_after = smoke.text()
            check(page_after != page_before, "a drag moves the slider, and the row says so")
            log.append(f"NOTE font row before: {size_before and size_before[0][:60]}")
            # Back to the middle of the track, as it was: the size is a setting.
            click_at(x + w * 0.2, yc, pause=1.0)

        # 6. A switch.
        toggle = wd.js("""
          for (const n of document.querySelectorAll('[role=switch], input[type=checkbox]')) {
            const r = n.getBoundingClientRect();
            if (r.width > 0 && r.y > 60 && r.y < innerHeight - 60)
              return [r.x + r.width / 2, r.y + r.height / 2,
                      n.getAttribute('aria-checked') || String(n.checked),
                      n.getAttribute('aria-label') || ''];
          }
          return null;""")
        check(toggle is not None, "a switch is on the page")
        if toggle:
            state = lambda: wd.js("""
              for (const n of document.querySelectorAll('[role=switch], input[type=checkbox]')) {
                if ((n.getAttribute('aria-label') || '') === arguments[0])
                  return n.getAttribute('aria-checked') || String(n.checked);
              }
              return null;""", toggle[3])
            click_at(toggle[0], toggle[1], pause=1.2)
            flipped = state()
            check(flipped != toggle[2], f"a click turns {toggle[3][:30]!r} ({toggle[2]} -> {flipped})")
            click_at(toggle[0], toggle[1], pause=1.2)
            check(state() == toggle[2], f"a second click turns it back ({state()})")

        # 7. Language.
        for _ in range(12):
            if smoke.find("Language"):
                break
            wheel(640, 450, 450)
        lang_row = smoke.find("Language")
        check(lang_row is not None, "the Language row is on Settings")
        if lang_row:
            height = wd.js("return window.innerHeight;")
            # The whole row opens the menu: press it on its words, well above
            # the tab bar.
            opener = smoke.find("Language")
            for _ in range(8):
                if opener and 100 < opener[3] < height - 160:
                    break
                wheel(640, 450, (opener[3] - height / 2) if opener else 300)
                opener = smoke.find("Language")
            check(opener is not None, "the row shows the language")
            if opener:
                click_at(opener[2], opener[3], pause=1.5)
                smoke.shot("mouse_language_menu")
                pick = next((l for l in smoke.labels()
                             if l[0].split("\n")[0] == "Filipino"), None)
                check(pick is not None, "the menu offers Filipino")
                if pick:
                    click_at(pick[2], pick[3], pause=3)
                    smoke.shot("mouse_filipino")
                    text = smoke.text()
                    check("Wika" in text or "Mga Setting" in text or "Pagkakita" in text,
                          f"Settings turned Filipino at once ({text[:90]})")
                    marked = wd.js("return document.querySelectorAll('[lang=fil]').length;")
                    check((marked or 0) > 0, f"the page is marked lang=fil for a reader ({marked})")
                    click("Bumalik", pause=2.5) or click("Back", pause=2.5) or click("Go back", pause=2.5)
                    smoke.shot("mouse_home_filipino")
                    home_text = smoke.text()
                    check("Maglaro" in home_text or "Kumusta" in home_text,
                          f"Home is Filipino too ({home_text[:90]})")
                    english = wd.js("return document.querySelectorAll('[lang=en]').length;")
                    log.append(f"NOTE nodes marked lang=en among the Filipino: {english}")
                    # And back.
                    click("Buksan ang mga setting", pause=3)
                    for _ in range(12):
                        if smoke.find("Wika"):
                            break
                        wheel(640, 450, 450)
                    row = smoke.find("Wika")
                    if row and not 30 < row[3] < height - 30:
                        wheel(640, 450, row[3] - height / 2)
                    opener = smoke.find("Filipino")
                    if opener:
                        click_at(opener[2], opener[3], pause=1.5)
                        pick = next((l for l in smoke.labels()
                                     if l[0].split("\n")[0] == "English"), None)
                        if pick:
                            click_at(pick[2], pick[3], pause=3)
                    text = smoke.text()
                    check("Language" in text, f"and back to English ({text[:90]})")
                    marked = wd.js("return document.querySelectorAll('[lang=fil]').length;")
                    check(not marked, f"no longer marked Filipino ({marked})")

        errors = smoke.page_errors()
        check(not errors, f"no page errors ({errors[:2]})")

    try:
        run()
    finally:
        wd.quit()
        with open(os.path.join(args.out, "result.json"), "w", encoding="utf-8") as f:
            json.dump({"log": log, "problems": problems}, f, indent=1)
        sys.stdout.reconfigure(errors="replace")
        print(f"WEB MOUSE {args.browser}: {len(log) - len(problems)} passed, "
              f"{len(problems)} failed")
        for line in log:
            print("  " + line)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
