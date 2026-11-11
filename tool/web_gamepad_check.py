"""A game controller in the web app, in a real browser.

    python tool/web_cdp.py --check gamepad --url http://127.0.0.1:8080/ --out build/web_gamepad

A browser reads a controller through its Gamepad API, which a page polls
(`navigator.getGamepads()`). This check gives the page a controller of its
own before the app starts: an object shaped as the API's is, in the browser's
"standard" layout, whose buttons and sticks the check sets as a hand would.
The app cannot tell it from a real one, so everything after the browser's
API is tested as it runs: the app's polling, its reading of the layout, the
controller host's moves, what opens, and what the page's own focus (a screen
reader's) does where the controller moves it.

Each press is judged by what it did, and, in a trace build (WEB_TRACE=1
tool/build_web.sh), by the controller's own account of it in the console
("Gamepad dpadDown -> moveDown"). On Home the controller moves a ring over
the tile grid, which gaze uses too; there the page's focus does not move,
and the screen reader hears the tile as an announcement instead. From a
freshly onboarded profile (as tool/web_smoke.py makes one: build with
WEB_TEST=1 so nothing reaches the cloud) it checks that:

  0. the first A, which is also the press that shows the browser the
     controller, collects the Daily Reward;
  1. on Home, the D-pad and the left stick move the ring (a stick near the
     middle does not), and a held D-pad is one step;
  2. R1 asks to go to the next section and A says yes; L1 and A come back;
     B says no to the question and stays;
  2b. A opens the tile under the ring, and B comes back to Home;
  3. on a screen pushed over Home (Settings), the D-pad moves the page's own
     focus from control to control, as the arrow keys do;
  4. the controller's settings screen sees the controller by name.

A screenshot of each step is saved to --out.
"""
import hashlib
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from web_dpad_check import focused, location  # noqa: E402
from web_smoke import Smoke, WebDriver, capabilities  # noqa: E402
import web_focus_log  # noqa: E402

# Standard layout indices (https://w3c.github.io/gamepad/#remapping).
A, B, X, Y, L1, R1, L2, R2 = 0, 1, 2, 3, 4, 5, 6, 7
UP, DOWN, LEFT, RIGHT = 12, 13, 14, 15

FAKE_PAD = r"""
(() => {
  const pad = {
    id: 'Test Pad (STANDARD GAMEPAD Vendor: 0000 Product: 0000)',
    index: 0, connected: false, mapping: 'standard', timestamp: 0,
    axes: [0, 0, 0, 0],
    buttons: Array.from({length: 17},
        () => ({pressed: false, touched: false, value: 0})),
  };
  const touch = () => {
    pad.timestamp = performance.now();
    if (!pad.connected) {
      // A browser makes a controller known on its first press.
      pad.connected = true;
      window.dispatchEvent(new Event('gamepadconnected'));
    }
  };
  window.__pad = {
    button(i, down) {
      touch();
      pad.buttons[i].pressed = down;
      pad.buttons[i].touched = down;
      pad.buttons[i].value = down ? 1 : 0;
    },
    axis(i, v) { touch(); pad.axes[i] = v; },
    polls: 0,
  };
  Object.defineProperty(Navigator.prototype, 'getGamepads', {
    configurable: true,
    value: function () {
      window.__pad.polls++;
      return pad.connected ? [pad, null, null, null] : [null, null, null, null];
    },
  });
  // What the app says aloud, for the learner without a screen reader.
  window.__said = [];
  if (window.speechSynthesis) {
    const speak = window.speechSynthesis.speak.bind(window.speechSynthesis);
    window.speechSynthesis.speak = (u) => {
      window.__said.push(u.text);
      try { speak(u); } catch (e) {}
    };
  }
})();
"""


def console_lines(events):
    out = []
    for e in events:
        if e.get("method") == "Runtime.consoleAPICalled":
            out.append(" ".join(str(a.get("value", "")) for a in e["params"].get("args", [])))
    return out


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
        sys.exit("the gamepad check needs the DevTools driver (tool/web_cdp.py)")
    wd.cdp.call("Page.addScriptToEvaluateOnNewDocument", {"source": FAKE_PAD})
    web_focus_log.install(wd)
    smoke = Smoke(wd, args.url, args.out)
    problems, log = [], []
    seen_events = [0]

    def check(ok, what):
        log.append(("PASS " if ok else "FAIL ") + what)
        if not ok:
            problems.append(what)

    def console():
        """The app's console lines since the last call."""
        wd.js("return 1;")  # console events arrive with any DevTools answer
        lines = console_lines(wd.cdp.events[seen_events[0]:])
        seen_events[0] = len(wd.cdp.events)
        return lines

    def traced(lines, word):
        return [l for l in lines if l.startswith("Gamepad ") and word in l]

    def shot_hash():
        data = wd.cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
        return hashlib.sha1(data.encode()).hexdigest()

    def button(i, hold=0.12, pause=0.7):
        wd.js("window.__pad.button(arguments[0], true);", i)
        time.sleep(hold)
        wd.js("window.__pad.button(arguments[0], false);", i)
        time.sleep(pause)

    def axis(i, v, hold=0.15, pause=0.7):
        wd.js("window.__pad.axis(arguments[0], arguments[1]);", i, v)
        time.sleep(hold)
        wd.js("window.__pad.axis(arguments[0], 0);", i)
        time.sleep(pause)

    def run():
        wd.window(1280, 900)
        reward = {}

        def collect_by_controller():
            time.sleep(1.5)
            reward["focused"] = focused(wd)
            console()
            button(A, pause=2)
            reward["lines"] = console()
            reward["closed"] = not smoke.find("Collect")
            if not reward["closed"]:
                button(A, pause=2)
                reward["second"] = not smoke.find("Collect")
                reward["lines2"] = console()
                if not reward["second"]:
                    smoke.click("Collect")

        smoke.on_reward = collect_by_controller
        if not smoke.onboard():
            problems.append("could not onboard a profile")
            return
        everything = console_lines(wd.cdp.events)
        tracing = any(l.startswith("Gamepad") for l in everything)
        log.append(f"NOTE trace build: {tracing}")
        if reward:
            check(reward["closed"], "the first A (which also shows the browser the "
                  f"controller) collects the Daily Reward (focus: {reward['focused']}; "
                  f"second A: {reward.get('second')}; trace: "
                  f"{[l for l in reward.get('lines', []) if 'Gamepad' in l][:6]} / "
                  f"{[l for l in reward.get('lines2', []) if 'Gamepad' in l][:6]})")
        else:
            log.append("NOTE the Daily Reward did not show")
        polls = wd.js("return window.__pad.polls;")
        check(bool(polls and polls > 10), f"the app reads the controller ({polls} reads)")
        home = location(wd)
        console()

        # 1. Home: the ring moves.
        before = shot_hash()
        button(DOWN)
        moved = shot_hash()
        lines = console()
        smoke.shot("gamepad_home_down")
        check(moved != before, "D-pad down moves the ring on Home (the screen changed)")
        if tracing:
            check(bool(traced(lines, "dpadDown -> ")),
                  f"the controller took D-pad down ({traced(lines, 'dpadDown')[:3]})")
        check(location(wd) == home, f"the D-pad moves, it does not open ({location(wd)})")

        axis(1, 0.3)
        lines = console()
        check(not traced(lines, "leftStick"), "a stick near the middle sends nothing "
              f"({traced(lines, 'leftStick')[:2]})")
        before = shot_hash()
        axis(1, 0.95)
        lines = console()
        check(shot_hash() != before, "the left stick pushed down moves the ring")
        if tracing:
            check(bool(traced(lines, "leftStickDown -> ")),
                  f"the controller took the stick ({traced(lines, 'leftStick')[:3]})")
        axis(1, -0.95)

        console()
        button(DOWN, hold=1.3, pause=0.8)
        lines = console()
        if tracing:
            taken = traced(lines, "dpadDown -> ")
            check(len(taken) == 1, f"a held D-pad is one step ({len(taken)} steps: {taken[:4]})")

        # 2. R1 asks (a learner is not moved by a stray press); A is yes, B no.
        button(R1, pause=1.0)
        lines = console()
        smoke.shot("gamepad_r1_asks")
        if tracing:
            check(bool(traced(lines, "r1 -> ")), f"the controller took R1 ({traced(lines, 'r1')[:3]})")
        check(location(wd) == home, f"R1 alone stays put, and asks ({location(wd)})")
        button(B, pause=1.0)
        lines = console()
        if tracing:
            check(bool(traced(lines, "b -> answerNo")), f"B says no ({traced(lines, ' -> ')[:3]})")
        check(location(wd) == home, f"after no, still on Home ({location(wd)})")
        button(R1, pause=1.0)
        button(A, pause=2.5)
        lines = console()
        smoke.shot("gamepad_r1_yes")
        next_section = location(wd)
        check(next_section != home, f"R1 then A goes to the next section ({next_section}; "
              f"trace: {traced(lines, ' -> ')[:3]})")
        # B declined and offered the section after: that one may be several
        # away, so back a section at a time.
        for _ in range(6):
            if location(wd) == home:
                break
            button(L1, pause=1.0)
            button(A, pause=2.5)
        check(location(wd) == home, f"L1 then A, section by section, comes back to Home ({location(wd)})")

        # 2b. A opens the tile under the ring; B comes back.
        button(DOWN)
        button(DOWN)
        said_before = wd.js("return window.__said.length;") or 0
        console()
        button(A, pause=3)
        lines = console()
        smoke.shot("gamepad_a_opened")
        opened = location(wd) != home or bool(smoke.find("Back"))
        check(opened, f"A opens the tile under the ring (at {location(wd)}; "
              f"trace: {traced(lines, ' -> ')[:3]})")
        said = wd.js("return window.__said.slice(arguments[0]);", said_before) or []
        log.append(f"NOTE said aloud: {said[:4]}")
        button(B, pause=3)
        smoke.shot("gamepad_b_back")
        check(location(wd) == home, f"B comes back to Home (at {location(wd)})")

        # 3. A screen pushed over Home, by its button: the page's own focus
        # moves. (Changing the address would leave nothing under it to go back
        # to.)
        smoke.click("Open settings")
        time.sleep(3)
        # Pushed over Home: the address stays, the page says where it is.
        check("Settings" in smoke.text(), f"Settings opened ({smoke.text()[:50]})")
        console()
        seen = []
        for _ in range(5):
            button(DOWN, pause=0.8)
            seen.append(focused(wd))
        lines = console()
        smoke.shot("gamepad_settings_steps")
        distinct = [s for s in dict.fromkeys(seen) if s and s != "(unnamed)"]
        check(len(distinct) >= 4, f"on Settings the D-pad moves the page's focus: {seen}")
        if tracing:
            check(not [l for l in lines if "no one took the arrow" in l],
                  "every arrow was taken by the app, none fell through")
        button(B, pause=3)
        check(location(wd) == home, f"B leaves Settings for Home (at {location(wd)})")

        # 4. Its settings screen knows it.
        wd.js("location.hash = arguments[0];", "/gamepad-settings")
        time.sleep(4)
        smoke.shot("gamepad_settings_screen")
        text = smoke.text()
        check("Test Pad" in text, f"the controller's settings see it by name ({text[:160]})")
        check("Android app" not in text,
              "the settings no longer send a browser to the Android app")

        errors = smoke.page_errors()
        check(not errors, f"no page errors ({errors[:2]})")
        focus = web_focus_log.read(wd)
        with open(os.path.join(args.out, "focus_log.json"), "w", encoding="utf-8") as f:
            json.dump(focus, f, indent=1, ensure_ascii=False)
        bad = web_focus_log.unnamed_focus(focus)
        check(not bad, f"every focus has a name a screen reader can say "
              f"({len(focus)} focuses; {bad[:3]})")

    try:
        run()
    finally:
        try:
            with open(os.path.join(args.out, "console.txt"), "w", encoding="utf-8") as f:
                f.write("\n".join(console_lines(wd.cdp.events)))
        except Exception:
            pass
        wd.quit()
        with open(os.path.join(args.out, "result.json"), "w", encoding="utf-8") as f:
            json.dump({"log": log, "problems": problems}, f, indent=1)
        sys.stdout.reconfigure(errors="replace")
        print(f"WEB GAMEPAD {args.browser}: {len(log) - len(problems)} passed, "
              f"{len(problems)} failed")
        for line in log:
            print("  " + line)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
