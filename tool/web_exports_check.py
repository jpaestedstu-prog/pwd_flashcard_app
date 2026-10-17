"""The browser version's file exports and imports, in a real Chrome.

Serves the offline test build (tool/build_web.sh with WEB_TEST=1, in
build/web-test) the way GitHub Pages will, then, as a new teacher:

  * makes a card, exports the cards (a .json download) and imports two more;
  * imports a student's profile file, then exports it again;
  * exports research data (one .zip of every file);
  * exports the teacher's progress as CSV and a worksheet as PDF.

Each download is checked on disk: its name, and what is inside. A file the
app is asked to import is handed over the way a person picking it in the
browser's file dialog does (only the operating system's dialog is skipped:
the app's own reading of the file runs as it is).

  python tool/web_exports_check.py --driver <chromedriver.exe> --out <dir>

Uses tool/web_smoke.py's driver and helpers. Exits 1 on any problem.
"""
import argparse
import base64
import datetime
import functools
import glob
import http.server
import importlib.util
import json
import os
import socketserver
import subprocess
import sys
import threading
import time
import zipfile

# Screen text holds emoji; a Windows console's default code page has none.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
spec = importlib.util.spec_from_file_location("web_smoke", os.path.join(HERE, "web_smoke.py"))
ws = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ws)

BASE = "/pwd_flashcard_app/app/"

# Answers the next file dialog with one file, as a person choosing it would:
# the app's own input element receives the file and its change event.
PICK_JS = """
const [name, b64, mime] = arguments;
const bytes = Uint8Array.from(atob(b64), c => c.charCodeAt(0));
const original = HTMLInputElement.prototype.click;
HTMLInputElement.prototype.click = function () {
  if (this.type !== 'file') return original.call(this);
  HTMLInputElement.prototype.click = original;
  const dt = new DataTransfer();
  dt.items.add(new File([bytes], name, {type: mime}));
  this.files = dt.files;
  setTimeout(() => this.dispatchEvent(new Event('change', {bubbles: true})), 50);
};
return true;
"""


class Handler(http.server.SimpleHTTPRequestHandler):
    """Serves build/web-test at BASE, like the project site serves app/."""

    root = ""

    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        if path.startswith(BASE):
            path = path[len(BASE):]
        else:
            path = path.lstrip("/")
        full = os.path.normpath(os.path.join(self.root, *path.split("/")))
        return full

    def log_message(self, *args):
        pass


def serve(root, port):
    Handler.root = root
    httpd = socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler)
    httpd.daemon_threads = True
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


class Check:
    def __init__(self, wd, smoke, downloads):
        self.wd, self.smoke, self.downloads = wd, smoke, downloads
        self.results = []

    def record(self, name, ok, detail=""):
        self.results.append((name, ok, detail))
        print(("PASS  " if ok else "FAIL  ") + name + (f": {detail}" if detail else ""))
        if not ok:
            self.smoke.shot("fail_" + name.replace(" ", "_")[:40])

    def go(self, route, wait_for=None, secs=25):
        self.wd.js("location.hash = arguments[0];", route)
        time.sleep(4)
        if wait_for and not self.smoke.wait(wait_for, secs):
            return False
        return True

    def type_into(self, index, text):
        """Types into the index-th text field on screen."""
        pos = self.wd.js(
            "const f = [...document.querySelectorAll('input, textarea')]"
            ".filter(e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; });"
            "const t = f[arguments[0]]; if (!t) return null;"
            "const r = t.getBoundingClientRect(); return [r.x + r.width/2, r.y + r.height/2];", index)
        if not pos:
            fields = [l for l in self.smoke.labels() if l[1] in ("textbox", "input", "textarea")]
            if index >= len(fields):
                return False
            pos = fields[index][2:4]
        self.wd.js(ws.CLICK_JS, pos[0], pos[1])
        time.sleep(1)
        try:
            active = self.wd.s("GET", "/element/active")
            eid = list(active.values())[0]
            self.wd.s("POST", f"/element/{eid}/value", {"text": text})
        except RuntimeError:
            return False
        time.sleep(0.8)
        return True

    def wait_download(self, pattern, secs=30, since=0.0):
        end = time.time() + secs
        while time.time() < end:
            hits = [p for p in glob.glob(os.path.join(self.downloads, pattern))
                    if not p.endswith(".crdownload") and os.path.getmtime(p) >= since]
            if hits:
                time.sleep(0.5)
                return max(hits, key=os.path.getmtime)
            time.sleep(0.5)
        return None

    def click_scrolling(self, label, tries=12):
        """Clicks [label], wheeling the page down until the accessibility
        layer has built it: one far down a long page is not there yet."""
        for _ in range(tries):
            if self.smoke.find(label):
                return self.smoke.click(label)
            self.wd.js(ws.WHEEL_JS, 400)
            time.sleep(1.2)
        return self.smoke.click(label)

    def pick(self, name, data, mime):
        self.wd.js(PICK_JS, name, base64.b64encode(data).decode(), mime)


def student_file():
    now = datetime.datetime.now().replace(microsecond=0).isoformat()
    return json.dumps({
        "formatVersion": 1,
        "exportDate": now,
        "profile": {
            "id": "web-exports-student-1",
            "name": "Web Student",
            "role": 0,  # student
            "avatarIndex": 3,
            "createdAt": now,
            "disabilityType": 1,  # hearing
            "tags": [],
        },
        "progress": {
            "wordsLearned": 2,
            "learnedWordIds": ["animals_1", "animals_2"],
            "streakDays": 1,
            "lastActivityDate": now,
            "totalStars": 12,
            "recentScores": [
                {"gameType": 0, "score": 4, "total": 5, "starsEarned": 2,
                 "date": now, "durationSeconds": 60},
            ],
        },
        "achievements": [],
        "purchases": [],
        "equipped": {},
    }).encode()


def cards_file():
    now = datetime.datetime.now().replace(microsecond=0).isoformat()
    cards = []
    for i, (en, fil) in enumerate([("Pineapple", "Pinya"), ("Papaya", "Papaya")]):
        cards.append({
            "id": f"web-import-card-{i}",
            "wordEnglish": en,
            "wordFilipino": fil,
            "category": 0,
            "isCustom": True,
            "createdAt": now,
        })
    return json.dumps(cards).encode()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--build", default=os.path.join(REPO, "build", "web-test"))
    ap.add_argument("--port", type=int, default=8771)
    args = ap.parse_args()

    downloads = os.path.abspath(os.path.join(args.out, "downloads"))
    os.makedirs(downloads, exist_ok=True)
    for old in glob.glob(os.path.join(downloads, "*")):
        os.remove(old)

    httpd = serve(os.path.abspath(args.build), args.port)
    drv = subprocess.Popen([args.driver, "--port=9518"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    url = f"http://127.0.0.1:{args.port}{BASE}"
    caps = ws.capabilities("chrome")
    # No component downloads of Chrome's own (a 27 MB one landed in the
    # downloads folder; the test PC may be on a metered connection).
    caps["goog:chromeOptions"]["args"] += ["--disable-component-update"]
    caps["goog:chromeOptions"]["prefs"] = {
        "download.default_directory": downloads,
        "download.prompt_for_download": False,
        "profile.default_content_setting_values.automatic_downloads": 1,
    }
    caps["goog:loggingPrefs"] = {"browser": "ALL"}
    wd = ws.WebDriver("http://127.0.0.1:9518", caps)
    smoke = ws.Smoke(wd, url, args.out)
    c = Check(wd, smoke, downloads)
    try:
        wd.window(1280, 900)
        wd._call("POST", f"/session/{wd.sid}/goog/cdp/execute", {
            "cmd": "Browser.setDownloadBehavior",
            "params": {"behavior": "allow", "downloadPath": downloads}})

        # ── A new teacher ────────────────────────────────────────────
        wd.go(url)
        end = time.time() + 180
        while time.time() < end and not wd.js(
                "return !!document.querySelector('flt-semantics-placeholder, flutter-view');"):
            time.sleep(1)
        time.sleep(4)
        smoke._enable_semantics()
        if smoke.wait("Skip", 60):
            smoke.click("Skip")
        ok = smoke.click("Teacher Profile", 30)
        ok = ok and c.type_into(0, "Web Teacher")
        wd.js("document.activeElement && document.activeElement.blur && document.activeElement.blur();")
        ok = ok and smoke.click("Let's Go!")
        time.sleep(4)
        for _ in range(4):
            if smoke.find("Skip"):
                smoke.click("Skip")
                time.sleep(2)
        c.record("teacher onboarding", ok and bool(smoke.wait("Cards", 30)),
                 smoke.text()[:200])

        # ── Cards: make one, export, import two ──────────────────────
        c.go("/create-flashcard-enhanced", "Create Flashcard")
        typed = c.type_into(0, "Mango") and c.type_into(1, "Mangga")
        wd.js("document.activeElement && document.activeElement.blur && document.activeElement.blur();")
        # The button shares its words with the screen's title: the button
        # is the one at the bottom.
        c.click_scrolling("Create Flashcard")
        made = smoke.wait("Flashcard created", 6) or not smoke.find("Word (Filipino)")
        c.record("create a card", typed and bool(made), smoke.text()[:160])

        c.go("/flashcards", "Export")
        t0 = time.time()
        smoke.click("Export")
        got = c.wait_download("flashlearn_cards_*.json", since=t0 - 1)
        detail = ""
        ok = False
        if got:
            data = json.load(open(got, encoding="utf-8"))
            words = [x.get("wordEnglish") for x in data]
            ok = "Mango" in words
            detail = f"{os.path.basename(got)}: {words}"
        c.record("export cards (.json download)", ok, detail or "no download")
        c.record("export says how many", bool(smoke.wait("1 card exported", 8)))

        c.pick("more_cards.json", cards_file(), "application/json")
        smoke.click("Import")
        c.record("import cards (file chosen in the browser)",
                 bool(smoke.wait("Imported 2 flashcard", 12)), smoke.text()[:160])

        # ── A student's profile: import, then export ─────────────────
        c.go("/profile-import-export", "Choose File")
        c.pick("student_web_student.json", student_file(), "application/json")
        smoke.click("Choose File")
        c.record("import a student profile",
                 bool(smoke.wait("Successfully imported", 15)), smoke.text()[:160])
        time.sleep(2)
        t0 = time.time()
        clicked = smoke.click("Export", 15)
        got = c.wait_download("student_web_student_*.json", since=t0 - 1)
        ok = False
        detail = "no download"
        if got:
            data = json.load(open(got, encoding="utf-8"))
            ok = data.get("profile", {}).get("name") == "Web Student"
            detail = f"{os.path.basename(got)}: {data.get('profile', {}).get('name')}"
        c.record("export a student profile (.json download)", clicked and ok, detail)

        # ── Research data: every file in one zip ─────────────────────
        c.go("/research-export", "Tick all")
        smoke.click("Tick all")
        time.sleep(1)
        t0 = time.time()
        c.click_scrolling("Export Research Data")
        got = c.wait_download("FlashLearn_Research_*.zip", secs=45, since=t0 - 1)
        ok = False
        detail = "no download"
        if got:
            names = zipfile.ZipFile(got).namelist()
            ok = len(names) >= 3 and any(n.endswith(".csv") for n in names)
            detail = f"{os.path.basename(got)}: {names}"
        c.record("research export (.zip download)", ok, detail)

        # ── Progress as CSV ──────────────────────────────────────────
        c.go("/dashboard")
        time.sleep(2)
        t0 = time.time()
        smoke.click("Export data as CSV spreadsheet")
        got = c.wait_download("FlashLearn_Data_*.csv", since=t0 - 1)
        ok = False
        detail = "no download"
        if got:
            text = open(got, encoding="utf-8").read()
            ok = "PROGRESS SUMMARY" in text
            detail = f"{os.path.basename(got)}: {text.splitlines()[0] if text else ''}"
        c.record("progress CSV (.csv download)", ok, detail)

        # ── A worksheet as PDF ───────────────────────────────────────
        c.go("/worksheets", "Share PDF")
        t0 = time.time()
        smoke.click("Share PDF")
        got = c.wait_download("FlashLearn_*.pdf", secs=45, since=t0 - 1)
        ok = bool(got) and open(got, "rb").read(5) == b"%PDF-"
        c.record("worksheet PDF (.pdf download)", ok,
                 os.path.basename(got) if got else "no download")

        # ── Nothing went wrong on the way ────────────────────────────
        errs = smoke.page_errors()
        bad = [b for b in ws.BAD_TEXT if b in smoke.text()]
        logs = wd._call("POST", f"/session/{wd.sid}/se/log", {"type": "browser"}).get("value", [])
        # Chrome's own "intervention" notices (navigator.vibrate before a
        # real tap: a driver's clicks are not one) are not the app's errors.
        severe = [l.get("message", "")[:200] for l in logs
                  if l.get("level") == "SEVERE"
                  and "navigator.vibrate" not in l.get("message", "")]
        c.record("no app errors", not errs and not bad, "; ".join(map(str, errs))[:300])
        c.record("no console errors", not severe, "; ".join(severe)[:400])
    finally:
        wd.quit()
        drv.kill()
        httpd.shutdown()

    failed = [r for r in c.results if not r[1]]
    print(f"WEB EXPORTS: {len(c.results) - len(failed)} of {len(c.results)} passed")
    with open(os.path.join(args.out, "exports_result.json"), "w", encoding="utf-8") as f:
        json.dump(c.results, f, indent=1)
    print("downloads:", ", ".join(sorted(os.listdir(downloads))))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
