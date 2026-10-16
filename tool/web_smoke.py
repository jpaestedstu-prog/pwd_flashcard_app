"""Browser smoke test of the FlashLearn web app over W3C WebDriver.

Drives Safari (macOS, or Mobile Safari in the iOS Simulator), Chrome or
Firefox through their own drivers (safaridriver, chromedriver, geckodriver)
with nothing but the Python standard library, so it runs the same on a
GitHub Actions runner and on a laptop.

    python tool/web_smoke.py --driver http://127.0.0.1:4444 \
        --browser safari --url http://127.0.0.1:8080/ --out build/web_smoke/safari
    # --browser: safari | safari-ios | chrome | firefox ; --mobile for a
    # phone-sized window (desktop browsers)

It onboards a "Player (with Progress)" profile (build the app with
--dart-define=FLASHLEARN_OFFLINE=true so nothing is created online), opens
every learner screen through the URL, and fails when one shows the app's
"Something went wrong" banner or an error box, when the page throws (the
collector in web/index.html), or when the app never starts. A screenshot of
every stop is saved to --out.

Flutter draws to a canvas; its accessibility layer, switched on here the way
a screen reader would, exposes every control as an element with a label,
which is what the test finds and clicks.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROUTES = [
    "/home", "/flashcards", "/games", "/stories", "/progress",
    "/flashcards/viewer/0", "/flashcards/viewer/5",
    "/games/word-match", "/games/spelling-bee", "/games/memory-match",
    "/games/drag-drop", "/games/flashcard-quiz", "/games/pronunciation",
    "/games/sentence-builder", "/games/tracing", "/games/jigsaw-puzzle",
    "/games/picture-word", "/games/yes-or-no", "/games/odd-one-out",
    "/games/first-letter", "/games/fsl-practice",
    "/games/fsl-practice/sign-to-word", "/games/fsl-practice/word-to-sign",
    "/games/fsl-practice/sign-it", "/settings", "/fsl-dictionary",
    "/communication-board", "/daily-challenge", "/smart-review", "/shop",
    "/learning-world", "/learning-paths", "/ai-tutor", "/object-scan",
    "/word-hunt-collection", "/gaze-settings", "/gamepad-settings",
    "/tv-cast", "/voice-guided", "/notebook", "/goals", "/streak-calendar",
    "/certificates", "/hard-words", "/word-of-day", "/focus-mode",
    "/mood-check-in", "/sticker-album", "/leaderboard", "/routine",
    "/messages", "/peer-collab", "/multiplayer", "/guided-practice",
    "/showcase", "/edit-profile", "/backup",
]

BAD_TEXT = ("Something went wrong",)


class WebDriver:
    def __init__(self, base, capabilities):
        self.base = base.rstrip("/")
        self._wait_ready()
        for attempt in range(3):
            try:
                r = self._call("POST", "/session", {"capabilities": {"alwaysMatch": capabilities}})
                break
            except RuntimeError as e:
                # Mobile Safari's first start on a freshly booted simulator can
                # outlast safaridriver's own wait ("session not created").
                if attempt == 2 or "session not created" not in str(e):
                    raise
                time.sleep(10)
        self.sid = r["sessionId"] if "sessionId" in r else r["value"]["sessionId"]

    def _wait_ready(self, seconds=60):
        # A driver started just before (a CI step) may still be coming up:
        # on GitHub one ChromeDriver was not listening yet 3 s after start.
        end = time.time() + seconds
        while True:
            try:
                self._call("GET", "/status", timeout=5)
                return
            except (OSError, RuntimeError):
                if time.time() > end:
                    raise
                time.sleep(1)

    def _call(self, method, path, body=None, timeout=120):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(self.base + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{method} {path}: {e.code} {e.read()[:300]!r}") from None

    def s(self, method, path, body=None):
        return self._call(method, f"/session/{self.sid}{path}", body)["value"]

    def go(self, url):
        self.s("POST", "/url", {"url": url})

    def js(self, script, *args):
        return self.s("POST", "/execute/sync", {"script": script, "args": list(args)})

    def window(self, w, h):
        try:
            self.s("POST", "/window/rect", {"width": w, "height": h})
        except RuntimeError:
            pass  # Mobile Safari: the simulator decides

    def screenshot(self, path):
        with open(path, "wb") as f:
            f.write(base64.b64decode(self.s("GET", "/screenshot")))

    def quit(self):
        try:
            self._call("DELETE", f"/session/{self.sid}")
        except Exception:
            pass


# Every labelled control the accessibility layer exposes, with its centre.
LABELS_JS = """
const out = [];
for (const n of document.querySelectorAll('flt-semantics, [role], input, textarea')) {
  const label = (n.getAttribute('aria-label') || n.innerText || n.value || '').trim();
  const r = n.getBoundingClientRect();
  if (!label || r.width === 0 || r.height === 0) continue;
  out.push([label.slice(0, 160), n.getAttribute('role') || n.tagName.toLowerCase(),
            r.x + r.width / 2, r.y + r.height / 2]);
}
return out;
"""

# A real click at a point: Flutter listens to pointer events on its view.
CLICK_JS = """
const [x, y] = arguments;
const el = document.elementFromPoint(x, y);
if (!el) return false;
const opts = {bubbles: true, cancelable: true, clientX: x, clientY: y,
              pointerId: 1, pointerType: 'mouse', isPrimary: true, button: 0, buttons: 1};
el.dispatchEvent(new PointerEvent('pointerdown', opts));
el.dispatchEvent(new PointerEvent('pointerup', Object.assign({}, opts, {buttons: 0})));
el.dispatchEvent(new MouseEvent('click', opts));
return true;
"""


INTERACTIVE = ("button", "link", "textbox", "checkbox", "switch", "tab",
               "menuitem", "radio", "slider", "combobox", "option",
               "input", "textarea")

WHEEL_JS = """
const v = document.querySelector('flutter-view, flt-glass-pane') || document.body;
v.dispatchEvent(new WheelEvent('wheel', {deltaY: arguments[0], bubbles: true, cancelable: true,
  clientX: window.innerWidth / 2, clientY: window.innerHeight / 2}));
"""


class Smoke:
    def __init__(self, wd, url, out):
        self.wd, self.url, self.out = wd, url, out
        self.n = 0
        self.failures = []
        self.visited = []
        os.makedirs(out, exist_ok=True)

    def shot(self, name):
        self.n += 1
        try:
            self.wd.screenshot(os.path.join(self.out, f"{self.n:03d}_{name}.png"))
        except Exception as e:
            print(f"  screenshot {name} failed: {e}")

    def labels(self):
        try:
            return self.wd.js(LABELS_JS) or []
        except RuntimeError:
            return []

    def find(self, label):
        """A control by its label: exact label on a node with a role first
        (Flutter's containers repeat their children's text), then any exact
        label, then a control whose label starts with or contains it."""
        ls = self.labels()
        # Interactive controls only: a dialog's container has a role too, and
        # repeats all of its text.
        controls = [l for l in ls if l[1] in INTERACTIVE]
        for pool in (controls, ls):
            for l in pool:
                if l[0] == label:
                    return l
        for l in controls:
            if l[0].split("\n")[0] == label:
                return l
        for pool in (controls, ls):
            for l in pool:
                if label.lower() in l[0].lower():
                    return l
        return None

    def wait(self, label, secs):
        end = time.time() + secs
        while time.time() < end:
            hit = self.find(label)
            if hit:
                return hit
            time.sleep(0.7)
        return None

    def click(self, label, secs=15):
        hit = self.wait(label, secs)
        if not hit:
            self.failures.append(f"could not find {label!r}")
            return False
        # Below (or above) the window: wheel the page until it shows. Flutter
        # scrolls on wheel events; a synthetic one works in every browser.
        height = self.wd.js("return window.innerHeight;") or 800
        for _ in range(8):
            if 20 < hit[3] < height - 20:
                break
            self.wd.js(WHEEL_JS, hit[3] - height * 0.5)
            time.sleep(1.2)
            hit = self.find(label) or hit
        self.wd.js(CLICK_JS, hit[2], hit[3])
        time.sleep(1.5)
        return True

    def page_errors(self):
        try:
            return self.wd.js("const e = window.__flErrors || []; window.__flErrors = []; return e;") or []
        except RuntimeError:
            return []

    def text(self):
        return " | ".join(l[0].replace("\n", " ") for l in self.labels())

    def _enable_semantics(self):
        """Turns on Flutter's semantics tree, which every lookup reads.

        A desktop browser turns it on with any click on the placeholder. A
        phone browser (Mobile Safari) only with one landing within a pixel of
        the placeholder's centre, as VoiceOver's tap does; the placeholder
        covers the view there. So: a plain click, then one at the centre
        (the engine reads the click's offset within the placeholder), then a
        real tap at the centre through the driver.
        """
        wd = self.wd
        on = "return document.querySelectorAll('flt-semantics').length > 0;"
        wd.js("const p = document.querySelector('flt-semantics-placeholder');"
              "if (p) p.click();")
        time.sleep(1)
        if wd.js(on):
            return
        centre = wd.js(
            "const p = document.querySelector('flt-semantics-placeholder');"
            "if (!p) return null; const r = p.getBoundingClientRect();"
            "p.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true,"
            "  clientX: 2 * r.left + r.width / 2, clientY: 2 * r.top + r.height / 2}));"
            "return [r.left + r.width / 2, r.top + r.height / 2];")
        time.sleep(1)
        if centre is None or wd.js(on):
            return
        try:
            self._tap(centre[0], centre[1])
        except RuntimeError:
            pass  # a driver without touch actions: the lookups will say so
        time.sleep(1)

    def _tap(self, x, y):
        """A real tap through the driver (a touch, on a phone) at viewport
        point (x, y): what a page script's click cannot stand in for."""
        self.wd.s("POST", "/actions", {"actions": [{
            "type": "pointer", "id": "finger",
            "parameters": {"pointerType": "touch"},
            "actions": [
                {"type": "pointerMove", "duration": 0, "origin": "viewport",
                 "x": round(x), "y": round(y)},
                {"type": "pointerDown", "button": 0},
                {"type": "pause", "duration": 80},
                {"type": "pointerUp", "button": 0},
            ]}]})
        try:
            self.wd.s("DELETE", "/actions")
        except RuntimeError:
            pass

    def onboard(self):
        wd = self.wd
        wd.go(self.url)
        # The app downloads, compiles and draws its first frame.
        end = time.time() + 180
        while time.time() < end:
            if wd.js("return !!document.querySelector('flt-semantics-placeholder, flt-glass-pane, flutter-view');"):
                break
            time.sleep(1)
        time.sleep(4)
        self._enable_semantics()
        time.sleep(2)
        # A browser that kept this site's data from an earlier walk starts
        # further on: at "Who are you?", or at the list with our profile.
        end = time.time() + 60
        start = None
        while time.time() < end and start is None:
            if self.find("Web Tester"):
                start = "mine"
            elif self.find("Player (with Progress)"):
                start = "choose"
            elif self.find("Skip"):
                start = "welcome"
            else:
                time.sleep(1)
        if start is None:
            self.shot("no_welcome")
            self.failures.append("the app never showed its first screen")
            return False
        self.shot("first_screen")
        if start == "mine":
            self.click("Web Tester")
            return self._reach_home()
        if start == "welcome":
            self.click("Skip")
        if not self.click("Player (with Progress)", 30):
            self.shot("no_choice")
            return False
        time.sleep(2)
        self.shot("form")
        field = wd.js("const t = document.querySelector('input, textarea'); if (!t) return null;"
                      "const r = t.getBoundingClientRect(); return [r.x + r.width/2, r.y + r.height/2];")
        if not field:
            name = self.find("name")
            field = name[2:4] if name else None
        typing = ("const a = document.activeElement;"
                  "return !!a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA');")
        if field:
            wd.js(CLICK_JS, field[0], field[1])
            time.sleep(1)
            if not wd.js(typing):
                # iOS gives a text field focus (and its keyboard) only for a
                # real tap, never for a page script's click.
                try:
                    self._tap(field[0], field[1])
                except RuntimeError:
                    pass
                time.sleep(1.5)
        try:
            active = wd.s("GET", "/element/active")
            eid = list(active.values())[0]
            wd.s("POST", f"/element/{eid}/value", {"text": "Web Tester"})
        except RuntimeError as e:
            self.failures.append(f"could not type the name: {e}")
        time.sleep(1)
        # A driver whose keys did not reach the field: put the name in the
        # way a keyboard does, through the input event the app listens to.
        wd.js("const a = document.activeElement;"
              "if (a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA') && !a.value) {"
              "  a.value = 'Web Tester';"
              "  a.dispatchEvent(new Event('input', {bubbles: true}));"
              "}")
        time.sleep(1)
        wd.js("document.activeElement && document.activeElement.blur && document.activeElement.blur();")
        self.click("Tap to select birth date")
        time.sleep(1.5)
        self.shot("date_picker")
        self.click("OK")
        self.click("Let's Go!")
        time.sleep(3)
        return self._reach_home()

    def _reach_home(self):
        """Through whatever comes between the form and Home (setup, the
        tour, the first Daily Reward) to the tab bar."""
        for i in range(6):
            if self.find("Games") and self.find("Cards"):
                break
            if self.find("Collect"):
                # The first visit's Daily Reward sits over Home and hides the
                # tab bar from the accessibility tree.
                self.shot("daily_reward")
                self.click("Collect")
            elif self.find("Skip"):
                self.shot(f"setup_{i}")
                self.click("Skip")
                time.sleep(2)
            else:
                time.sleep(2)
        if not self.wait("Games", 30):
            self.shot("no_home")
            self.failures.append("never reached Home; on screen: " + self.text()[:300])
            return False
        time.sleep(2)
        if self.find("Collect"):
            self.shot("daily_reward")
            self.click("Collect")
        self.shot("home")
        errs = self.page_errors()
        for e in errs:
            self.failures.append(f"start and onboarding: {str(e)[:200]}")
        return True

    def visit(self, route):
        self.wd.js("location.hash = arguments[0];", route)
        time.sleep(5)
        text = self.text()
        bad = [b for b in BAD_TEXT if b in text]
        errs = self.page_errors()
        self.shot(route.strip("/").replace("/", "_") or "home")
        ok = not bad and not errs
        self.visited.append(("OK" if ok else "PROBLEM", route))
        print(("OK      " if ok else "PROBLEM ") + route)
        for b in bad:
            self.failures.append(f"{route}: {b!r} on screen")
        if bad:
            # The app's error banner stays until OK is pressed: dismiss it so
            # the next screen is judged on its own.
            ok = self.find("OK")
            if ok:
                self.wd.js(CLICK_JS, ok[2], ok[3])
                time.sleep(1)
        for e in errs:
            self.failures.append(f"{route}: {str(e)[:200]}")


def capabilities(browser, mobile=False):
    if browser == "safari":
        return {"browserName": "safari"}
    if browser == "safari-ios":
        return {"browserName": "safari", "platformName": "iOS", "safari:useSimulator": True}
    if browser == "chrome":
        options = {"args": ["--headless=new", "--no-sandbox"]}
        if mobile:
            # A phone as Chrome on Android presents itself (user agent, touch,
            # pixel ratio), so the app takes its phone-browser paths too; a
            # narrow desktop window alone does not.
            options["mobileEmulation"] = {"deviceName": "Pixel 7"}
        return {"browserName": "chrome", "goog:chromeOptions": options}
    if browser == "firefox":
        return {"browserName": "firefox", "moz:firefoxOptions": {"args": ["-headless"]}}
    raise SystemExit(f"unknown browser {browser}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--browser", required=True)
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mobile", action="store_true")
    args = ap.parse_args()

    wd = WebDriver(args.driver, capabilities(args.browser, mobile=args.mobile))
    smoke = Smoke(wd, args.url, args.out)
    try:
        if args.mobile:
            wd.window(412, 915)
        elif args.browser != "safari-ios":
            wd.window(1280, 900)
        if smoke.onboard():
            for r in ROUTES:
                smoke.visit(r)
    finally:
        wd.quit()
    print(f"WEB SMOKE {args.browser}: {len(smoke.visited)} screens, "
          f"{len(smoke.failures)} problem(s)")
    for f in smoke.failures:
        print("  FAIL", f)
    with open(os.path.join(args.out, "result.json"), "w", encoding="utf-8") as f:
        json.dump({"visited": smoke.visited, "failures": smoke.failures}, f, indent=1)
    sys.exit(1 if smoke.failures or not smoke.visited else 0)


if __name__ == "__main__":
    main()
