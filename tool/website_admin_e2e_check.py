"""End-to-end check of the website's visit counts, feedback form and admin dashboard,
in headless Chrome against the LOCAL Auth + Firestore emulators.

    cd website_admin
    firebase emulators:start --only firestore,auth --project demo-flashlearn-site
    python tool/website_admin_e2e_check.py [screenshot folder]

Serves website/ on 127.0.0.1:8899 and website_admin/public on 127.0.0.1:8898 with
the Hosting headers from website_admin/firebase.json (the CSP gains the two
emulator origins, nothing else). The public pages count only because the test
sets localStorage 'flp-stats-test' (honoured on localhost only); the dashboard
runs with ?emulator. GitHub's API and the live version.json are read for real.
Nothing touches a real Firebase project.
"""
import base64, functools, http.server, json, os, shutil, socket, struct, subprocess, sys, tempfile, threading, time
import urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "demo-flashlearn-site"
FS = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
AUTH = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1"
SITE, ADMIN = "http://127.0.0.1:8899", "http://127.0.0.1:8898"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
sys.stdout.reconfigure(encoding="utf-8")
SHOTS = sys.argv[1] if len(sys.argv) > 1 else tempfile.mkdtemp(prefix="fladm-shots-")
os.makedirs(SHOTS, exist_ok=True)

results = []


def check(label, ok, detail=""):
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + label + ("" if ok or not detail else f"  [{detail}]"), flush=True)


# ---- Emulator REST -----------------------------------------------------------------
def rest(method, url, body=None, token="owner"):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    r = urllib.request.Request(url, method=method, headers=headers, data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def fields(path):
    st, d = rest("GET", f"{FS}/{path}")
    if st != 200:
        return None
    out = {}
    for k, v in d.get("fields", {}).items():
        out[k] = int(v["integerValue"]) if "integerValue" in v else v.get("stringValue", v.get("booleanValue", v))
    return out


def listing(collection):
    st, d = rest("GET", f"{FS}/{collection}?pageSize=300")
    return [] if st != 200 or not d else d.get("documents", [])


def manila_day():
    return time.strftime("%Y-%m-%d", time.gmtime(time.time() + 8 * 3600))


def sign_up(email, password):
    st, d = rest("POST", f"{AUTH}/accounts:signUp?key=demo-key",
                 {"email": email, "password": password, "returnSecureToken": True}, token=None)
    assert st == 200, d
    return d["localId"]


# ---- Local servers --------------------------------------------------------------------
def admin_headers():
    with open(os.path.join(ROOT, "website_admin", "firebase.json"), encoding="utf-8") as f:
        hs = json.load(f)["hosting"]["headers"][0]["headers"]
    out = []
    for h in hs:
        v = h["value"]
        if h["key"] == "Content-Security-Policy":
            # The emulators stand in for Google's servers: the Auth emulator also serves the
            # sign-in helper frame, which mobile Chrome loads ahead of time.
            v = v.replace("connect-src 'self'", "connect-src 'self' http://127.0.0.1:8080 http://127.0.0.1:9099")
            v = v.replace("frame-src ", "frame-src http://127.0.0.1:9099 ")
        out.append((h["key"], v))
    return out


class Quiet(http.server.SimpleHTTPRequestHandler):
    extra = []

    def log_message(self, *a):
        pass

    def end_headers(self):
        for k, v in self.extra:
            self.send_header(k, v)
        super().end_headers()


class AdminHandler(Quiet):
    extra = admin_headers()


class Server(http.server.ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        pass   # Chrome closing a connection early is not a failure


def serve(port, directory, handler):
    srv = Server(("127.0.0.1", port), functools.partial(handler, directory=directory))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


# ---- A small Chrome DevTools client (stdlib only) ---------------------------------------
class WS:
    def __init__(self, url):
        hostport, path = url[len("ws://"):].split("/", 1)
        host, port = hostport.split(":")
        self.s = socket.create_connection((host, int(port)), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                        f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            resp += self.s.recv(4096)
        head, self.buf = resp.split(b"\r\n\r\n", 1)
        assert b" 101 " in head.split(b"\r\n")[0], head

    def send(self, text):
        data, mask = text.encode(), os.urandom(4)
        n = len(data)
        hdr = bytearray([0x81])
        if n < 126:
            hdr.append(0x80 | n)
        elif n < 65536:
            hdr.append(0x80 | 126)
            hdr += struct.pack(">H", n)
        else:
            hdr.append(0x80 | 127)
            hdr += struct.pack(">Q", n)
        self.s.sendall(bytes(hdr) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _read(self, n):
        chunks, have = [self.buf], len(self.buf)
        while have < n:
            c = self.s.recv(1 << 20)
            if not c:
                raise ConnectionError("devtools closed")
            chunks.append(c)
            have += len(c)
        data = b"".join(chunks)
        self.buf = data[n:]
        return data[:n]

    def recv(self):
        msg = b""
        while True:
            b1, b2 = self._read(2)
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            data = self._read(n)
            if b1 & 0x0F == 0x9:
                continue
            msg += data
            if b1 & 0x80:
                return msg.decode("utf-8", "replace")


class Page:
    def __init__(self, ws_url):
        self.ws, self.id, self.errors = WS(ws_url), 0, []

    def call(self, method, **params):
        self.id += 1
        mid = self.id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get("id") == mid:
                if "error" in m:
                    raise RuntimeError(f"{method}: {m['error']}")
                return m.get("result", {})
            self.event(m)

    def event(self, m):
        meth, p = m.get("method"), m.get("params", {})
        if meth == "Runtime.exceptionThrown":
            d = p["exceptionDetails"]
            self.errors.append("exception: " + (d.get("exception", {}).get("description") or d.get("text", ""))[:300])
        elif meth == "Runtime.consoleAPICalled" and p.get("type") == "error":
            self.errors.append("console: " + " ".join(str(a.get("value", a.get("description", ""))) for a in p.get("args", []))[:300])
        elif meth == "Log.entryAdded" and p["entry"]["level"] == "error":
            self.errors.append("log: " + p["entry"].get("text", "")[:300] + " " + p["entry"].get("url", ""))

    def js(self, expr):
        r = self.call("Runtime.evaluate", expression=expr, awaitPromise=True, returnByValue=True)
        if "exceptionDetails" in r:
            raise RuntimeError("JS: " + json.dumps(r["exceptionDetails"])[:400])
        return r["result"].get("value")

    def wait(self, expr, timeout=15):
        end = time.time() + timeout
        while time.time() < end:
            try:
                v = self.js(expr)
                if v:
                    return v
            except RuntimeError:
                pass
            time.sleep(0.25)
        return None

    def goto(self, url, referrer=None):
        """Navigate and wait for the NEW document to finish loading."""
        try:
            self.js("window.__old = 1")
        except RuntimeError:
            pass
        params = {"url": url}
        if referrer:
            params["referrer"] = referrer
        self.call("Page.navigate", **params)
        # (Leaving about:blank, Chrome first shows an empty in-between document.)
        origin = "/".join(url.split("/")[:3])
        return self.wait(f"!window.__old && document.readyState === 'complete' && location.href.indexOf({json.dumps(origin)}) === 0", 40)

    def follow(self, selector):
        """Click a link on the page and wait for the page it opens."""
        self.js("window.__old = 1")
        self.js(f"document.querySelector({json.dumps(selector)}).click()")
        return self.wait("!window.__old && document.readyState === 'complete'", 40)

    def shot(self, name, full=False):
        params = {"format": "png"}
        if full:
            m = self.call("Page.getLayoutMetrics")["cssContentSize"]
            params.update(captureBeyondViewport=True, clip={"x": 0, "y": 0, "width": m["width"], "height": m["height"], "scale": 1})
        data = self.call("Page.captureScreenshot", **params)["data"]
        path = os.path.join(SHOTS, name + ".png")
        with open(path, "wb") as f:
            f.write(base64.b64decode(data))
        return path


AXE = None
AXE_URL = "https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.10.2/axe.min.js"


def axe_source():
    """axe-core 4.10.2, downloaded once per PC and kept in its temp folder (550 KB)."""
    cached = os.path.join(tempfile.gettempdir(), "axe-core-4.10.2.min.js")
    if not os.path.exists(cached):
        with urllib.request.urlopen(AXE_URL, timeout=60) as r:
            data = r.read()
        with open(cached, "wb") as f:
            f.write(data)
    with open(cached, encoding="utf-8") as f:
        return f.read()


def axe(p, label):
    """axe-core (WCAG 2.2 A/AA + best practice) on the current page; [] when clean.
    DevTools runs it, so the dashboard's Content-Security-Policy does not get in the way."""
    global AXE
    if AXE is None:
        AXE = axe_source()
    if not p.js("typeof axe !== 'undefined'"):
        p.call("Runtime.evaluate", expression=AXE)
    tags = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"]
    return p.js("axe.run(document, {runOnly: {type: 'tag', values: %s}, resultTypes: ['violations']})"
                ".then(r => r.violations.map(v => v.impact + ' ' + v.id + ' ' + v.nodes.slice(0, 2).map(n => n.target.join(' ')).join(' | ')))"
                % json.dumps(tags))


def wait_for(fn, timeout=12):
    end = time.time() + timeout
    while time.time() < end:
        v = fn()
        if v:
            return v
        time.sleep(0.3)
    return fn()


def main():
    for port in (8080, 9099):
        with socket.socket() as s:
            if s.connect_ex(("127.0.0.1", port)):
                sys.exit(f"Start the emulators first (port {port} is closed): see this file's docstring.")
    rest("DELETE", f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents")
    rest("DELETE", f"http://127.0.0.1:9099/emulator/v1/projects/{PROJECT}/accounts", token=None)
    serve(8899, os.path.join(ROOT, "website"), Quiet)
    serve(8898, os.path.join(ROOT, "website_admin", "public"), AdminHandler)
    bare = tempfile.mkdtemp(prefix="fladm-bare-")
    shutil.copytree(os.path.join(ROOT, "website_admin", "public"), bare, dirs_exist_ok=True)
    cfg = os.path.join(bare, "config.js")
    with open(cfg, encoding="utf-8") as f:
        text = f.read()
    with open(cfg, "w", encoding="utf-8") as f:
        f.write(__import__("re").sub(r"apiKey: '[^']*'", "apiKey: ''", text))
    serve(8897, bare, AdminHandler)

    profile = tempfile.mkdtemp(prefix="fladm-")
    chrome = subprocess.Popen([CHROME, "--headless=new", "--remote-debugging-port=9333", f"--user-data-dir={profile}",
                               "--no-first-run", "--no-default-browser-check", "--hide-scrollbars",
                               "--autoplay-policy=no-user-gesture-required", "--window-size=1280,900", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        page_ws = wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9333/json/list"))
                                         if t["type"] == "page"), None) if _up(9333) else None, 20)
        p = Page(page_ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)
        run(p)
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} checks passed · screenshots in {SHOTS}")
    sys.exit(1 if failed else 0)


def _up(port):
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


SHOWN = "(id => { const e = document.getElementById(id); return !!e && getComputedStyle(e).display !== 'none'; })"


def run(p):
    today = manila_day()
    day = f"daily/{today}"
    tally = lambda: fields(day) or {}

    # ---- The site as published today: no statistics project, nothing sent ----
    p.goto(f"{SITE}/faq.html")
    check("unconfigured site: the form offers email first, no Send button",
          p.js(f"!{SHOWN}('fbSend') && document.getElementById('fbEmail').classList.contains('btn-primary')"
               f" && {SHOWN}('fbNoteMail') && !{SHOWN}('fbNoteSite')"))
    time.sleep(1.2)
    check("unconfigured site: no request leaves for a database",
          p.js("performance.getEntriesByType('resource').every(e => !/firestore|:8080/.test(e.name))"))

    # Point this browser's copy at the emulator (honoured on localhost only).
    p.js("localStorage.setItem('flp-stats-test', JSON.stringify({base: 'http://127.0.0.1:8080/v1', project: '%s'}))" % PROJECT)

    # ---- Counting ----
    # (An https:// referrer would be dropped on the way to this http:// copy.)
    p.goto(f"{SITE}/index.html", referrer="http://www.google.com/search?q=flashlearn")
    t = wait_for(lambda: tally().get("v") == 1 and tally())
    check("a first page view counts the page, language, visitor, new visitor, device and source",
          t and t.get("p_index") == 1 and t.get("l_en") == 1 and t.get("u") == 1 and t.get("n") == 1
          and t.get("d_computer") == 1 and t.get("s_search") == 1, t)
    check("the browser keeps only the day, a counted-before flag and the aids counted, no ID",
          p.js(f"(function(v){{return v.d === '{today}' && v.r === 1 && Object.keys(v).sort().join() === 'a,d,r';}})"
               "(JSON.parse(localStorage.getItem('flp-visit')))"))
    p.follow('a[href="faq.html"]')
    t = wait_for(lambda: tally().get("v") == 2 and tally())
    check("a second page counts a view but not a second visitor or source",
          t and t.get("p_faq") == 1 and t.get("u") == 1 and t.get("s_search") == 1 and not t.get("s_direct"), t)

    # ---- Feedback form ----
    check("configured site: Send to the team is offered first",
          p.js(f"{SHOWN}('fbSend') && document.getElementById('fbEmail').classList.contains('btn-secondary')"
               f" && {SHOWN}('fbNoteSite') && !{SHOWN}('fbNoteMail')"))
    p.js("document.getElementById('fbSend').click()")
    check("sending nothing asks for a rating or a message",
          p.wait("document.getElementById('fbStatus').classList.contains('bad') && /rating/.test(document.getElementById('fbStatus').textContent)"))
    time.sleep(1.6)   # the form refuses sends faster than a person
    p.js("""(function(){
      document.getElementById('fbR4').click();
      document.getElementById('fbRole').value = 'Parent or Guardian';
      document.getElementById('fbType').value = 'Suggestion';
      document.getElementById('fbDevice').value = 'Galaxy Tab A9';
      document.getElementById('fbMsg').value = '=1+2 Please add more Filipino words';
      document.getElementById('fbSend').click();
    })()""")
    check("a rating with a message is sent and thanked",
          p.wait("/reached the FlashLearn PWD team/.test(document.getElementById('fbStatus').textContent)"))
    check("the form clears after sending", p.js("!document.getElementById('fbMsg').value && !document.querySelector('[name=fbRating]:checked')"))
    p.js("document.getElementById('fbR5').click(); document.getElementById('fbSend').click()")
    check("a rating on its own is sent and thanked", p.wait("/Thank you for rating/.test(document.getElementById('fbStatus').textContent)"))
    p.js("document.getElementById('fbHp').value = 'http://spam'; document.getElementById('fbMsg').value = 'buy now';"
         "document.getElementById('fbSend').click()")
    time.sleep(1.5)
    docs = listing("feedback")
    check("exactly two messages arrived (the robot-filled one was not sent)", len(docs) == 2, len(docs))
    got = sorted((fields("feedback/" + d["name"].rsplit("/", 1)[1]) for d in docs), key=lambda f: f.get("type"))
    want0 = {"type": "idea", "role": "parent", "rating": 4, "device": "Galaxy Tab A9", "page": "faq", "lang": "en", "status": "new"}
    check("the message carries what the visitor chose, and nothing else",
          got and all(got[0].get(k) == v for k, v in want0.items()) and got[0].get("message", "").startswith("=1+2")
          and set(got[0]) == set(want0) | {"message", "created"}, got and got[0])
    check("the rating on its own is type 'rating' with no words",
          len(got) > 1 and got[1].get("type") == "rating" and got[1].get("rating") == 5 and got[1].get("message") == "", got[1:] and got[1])

    # ---- A reading aid switched on mid-visit counts once ----
    p.js("document.getElementById('btnHC').click()")
    wait_for(lambda: tally().get("a_hc") == 1)
    p.js("document.getElementById('btnHC').click(); document.getElementById('btnHC').click()")
    time.sleep(1.2)
    check("high contrast switched on counts once, however often it is toggled", tally().get("a_hc") == 1, tally().get("a_hc"))
    p.js("document.getElementById('btnHC').click()")   # off again for the screenshots

    # ---- Downloads and the web app (the clicks are stopped before they leave) ----
    p.follow('.site-nav a[href="download.html"]')
    p.js("window.addEventListener('click', e => { if (e.target.closest('a[href$=\".apk\"], a[href=\"app/\"]')) e.preventDefault(); }, true)")
    p.js("document.querySelector('a[href$=\"-arm64.apk\"]').click(); document.querySelector('a[href$=\"-arm64.apk\"]').click();"
         "document.querySelector('a[href=\"app/\"]').click()")
    # (the page view itself is sent 300 ms after the page has loaded)
    t = wait_for(lambda: tally().get("e_apk_arm64") == 1 and tally().get("e_webapp") == 1 and tally().get("p_download") == 1 and tally())
    check("a Download press and an Open-the-web-app press count once each", t and t.get("p_download") == 1, t)

    # ---- Try It ----
    p.follow('.site-nav a[href="try.html"]')
    p.js("document.getElementById('tryCard').click()")
    p.js("document.querySelector('[role=tab][aria-selected=false]').click()")
    t = wait_for(lambda: tally().get("e_try_card") == 1 and tally().get("e_try_game") == 1 and tally())
    check("Try It: a flipped card and a Word Match game are counted", bool(t), tally())

    # ---- FSL dictionary: one sign ----
    p.follow('.site-nav a[href="fsl-dictionary.html"]')
    name = p.js("document.querySelector('button.sign[data-f]').getAttribute('data-f')")
    p.js("document.querySelector('button.sign[data-f]').click()")
    key = "w_" + name.replace("-", "_")
    s = wait_for(lambda: (fields(f"signs/{today}") or {}).get(key) == 1 and fields(f"signs/{today}"))
    check(f"playing a sign counts that sign ({key})", bool(s), fields(f"signs/{today}"))

    # ---- The Home film ----
    p.follow('.site-nav a[href="index.html"]')
    p.js("document.querySelector('#filmPlayer .film-facade').click()")
    t = wait_for(lambda: tally().get("e_film") == 1 and tally())
    check("playing the Home film counts", bool(t), tally())

    # ---- Leaving out a device, and browsers that ask not to be tracked ----
    # (Each page view is sent 300 ms after its page has loaded: wait for the
    # Home view above to land before measuring.)
    wait_for(lambda: tally().get("p_index") == 2)
    v0 = tally().get("v")
    p.goto(f"{SITE}/index.html?nocount=on")
    check("?nocount=on says so and leaves the address clean",
          p.wait("document.querySelector('.site-notice') && location.search === ''"))
    p.goto(f"{SITE}/about.html")
    time.sleep(1.5)
    check("an excluded browser is not counted", tally().get("v") == v0, (v0, tally().get("v")))
    p.goto(f"{SITE}/index.html?nocount=off")
    check("?nocount=off counts that browser again", wait_for(lambda: tally().get("p_index") == 3 and tally().get("v") == v0 + 1),
          (v0, tally().get("v")))
    sid = p.call("Page.addScriptToEvaluateOnNewDocument",
                 source="Object.defineProperty(navigator, 'globalPrivacyControl', {get: () => true})")["identifier"]
    p.goto(f"{SITE}/privacy.html")
    time.sleep(1.5)
    check("Global Privacy Control: nothing is counted", tally().get("v") == v0 + 1 and not tally().get("p_privacy"), tally().get("v"))
    p.call("Page.removeScriptToEvaluateOnNewDocument", identifier=sid)
    t = tally()
    check("the day's totals add up (7 views, 1 visitor, 1 typed-in arrival)",
          t.get("v") == 7 and t.get("u") == 1 and t.get("s_direct") == 1 and t.get("p_index") == 3, t)
    site_errors = list(p.errors)
    check("no script errors on the public pages", not site_errors, site_errors[:4])

    # ---- Dashboard ----
    p.errors.clear()
    admin_uid = sign_up("admin@example.com", "correct-horse-battery")
    other_uid = sign_up("someone@example.com", "another-long-password")
    rest("PATCH", f"{FS}/admins/{admin_uid}", {"fields": {"name": {"stringValue": "Test admin"}}})
    old = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 400 * 86400))
    root = f"projects/{PROJECT}/databases/(default)/documents"
    writes = [{"update": {"name": f"{root}/feedback/OLD{i:017d}", "fields": {
        "type": {"stringValue": "idea"}, "role": {"stringValue": "teacher"}, "message": {"stringValue": f"old {i}"},
        "page": {"stringValue": "faq"}, "lang": {"stringValue": "en"}, "status": {"stringValue": "new"},
        "created": {"timestampValue": old}}}} for i in range(130)]
    check("130 messages from 13 months ago are in place", rest("POST", f"{FS}:commit", {"writes": writes})[0] == 200
          and len(listing("feedback")) == 132)
    p.call("Page.addScriptToEvaluateOnNewDocument",
           source="window.__csp = []; document.addEventListener('securitypolicyviolation', e => window.__csp.push(e.violatedDirective + ' ' + e.blockedURI));")
    p.goto("http://127.0.0.1:8897/")
    check("without a Firebase project the dashboard says it is not connected", p.wait("!document.getElementById('viewSetup').hidden"))
    p.goto(f"{ADMIN}/?emulator")
    check("signed out, the dashboard shows only the sign-in", p.wait("!document.getElementById('viewSignIn').hidden")
          and p.js("document.getElementById('viewDash').hidden && !document.getElementById('kpis').children.length"
                   " && document.getElementById('side').hidden"))
    found = axe(p, "sign-in")
    check("accessibility: the sign-in page has no axe violations", not found, found)
    p.shot("dashboard-signin-desktop")
    p.js("""(function(){
      document.querySelector('.email-signin').open = true;
      document.getElementById('inEmail').value = 'someone@example.com';
      document.getElementById('inPassword').value = 'another-long-password';
      document.getElementById('formEmail').requestSubmit();
    })()""")
    check("a signed-in stranger is told they are not an administrator, and shown their ID",
          p.wait("!document.getElementById('viewDenied').hidden") and p.js(f"document.getElementById('deniedUid').textContent === '{other_uid}'")
          and p.js("document.getElementById('viewDash').hidden && document.getElementById('side').hidden"))
    found = axe(p, "denied")
    check("accessibility: the not-an-administrator page has no axe violations", not found, found)
    p.js("window.__old = 1; document.getElementById('btnDeniedOut').click()")
    p.wait("!window.__old && document.readyState === 'complete'", 20)
    p.wait("!document.getElementById('viewSignIn').hidden")
    p.js("""(function(){
      document.querySelector('.email-signin').open = true;
      document.getElementById('inEmail').value = 'admin@example.com';
      document.getElementById('inPassword').value = 'correct-horse-battery';
      document.getElementById('formEmail').requestSubmit();
    })()""")
    check("an administrator gets the dashboard", p.wait("!document.getElementById('viewDash').hidden"))
    ok = p.wait("document.querySelectorAll('#kpis .tile').length === 5 && !document.getElementById('dash').classList.contains('loading')", 20)
    tiles = p.js("[...document.querySelectorAll('#kpis .tile')].map(t => t.querySelector('.tile-label').textContent + '=' + t.querySelector('.tile-value').textContent)")
    check("the overview shows 1 visitor, 7 page views, 4.5 stars and 1 message",
          ok and tiles[0] == "Visitors=1" and tiles[1] == "Page views=7" and tiles[3] == "Average rating=4.5 ★" and tiles[4] == "Messages=1", tiles)
    check("GitHub's download total is shown", p.wait("/^\\d[\\d,]*$/.test(document.querySelectorAll('#kpis .tile-value')[2].textContent)", 15),
          p.js("document.querySelectorAll('#kpis .tile-value')[2].textContent"))
    check("the charts and breakdowns are drawn",
          p.js("!!document.querySelector('#chartVisits svg .line.s1') && document.querySelectorAll('#barsPages li').length >= 5"
               " && document.querySelector('#barsSigns li') && document.querySelectorAll('#inbox .msg-item').length === 2"))
    check("messages older than 12 months are deleted when an administrator opens the dashboard (batches of 20)",
          wait_for(lambda: len(listing("feedback")) == 2, 20) and p.wait("/130 ratings and messages older than 12 months/.test(document.getElementById('expiredNote').textContent)"),
          (len(listing("feedback")), p.js("document.getElementById('expiredNote').textContent")))
    check("the inbox never lists an expired message", p.js("![...document.querySelectorAll('#inbox .msg-text')].some(e => /^old /.test(e.textContent))"))
    # Download numbers and the release check against GitHub's API, read independently here.
    gh = json.load(urllib.request.urlopen(urllib.request.Request(
        "https://api.github.com/repos/jpaestedstu-prog/pwd_flashcard_app/releases?per_page=100",
        headers={"Accept": "application/vnd.github+json"}), timeout=30))
    apks = [(r["tag_name"], a["name"], a["download_count"]) for r in gh if not r["draft"] for a in r["assets"] if a["name"].endswith(".apk")]
    total = sum(n for _, _, n in apks)
    newest = gh[0]["tag_name"]
    shown = p.js("[...document.querySelectorAll('#barsReleases li')].map(li => li.querySelector('.bar-name').textContent + '=' + li.querySelector('.bar-val').textContent)")
    check("the dashboard's total matches GitHub's own count of APK downloads",
          p.js("document.querySelectorAll('#kpis .tile-value')[2].textContent.replace(/,/g, '')") == str(total), (total, shown[:2]))
    check("each release's downloads match GitHub (newest release first)",
          shown and shown[0].startswith(newest + " ·") and shown[0].endswith("=" + str(sum(n for t, _, n in apks if t == newest))), (newest, shown[:2]))
    site = json.load(urllib.request.urlopen("https://jpaestedstu-prog.github.io/pwd_flashcard_app/version.json", timeout=30))
    agree = f"/download/{gh[0]['tag_name']}/" in site["latest"]["apks"]["arm64"]["url"]
    check("the download page check gives the right verdict (website vs GitHub's latest release)",
          p.wait("!!document.querySelector('#healthBody .status-line." + ("good" if agree else "warn") + "')", 10),
          p.js("document.getElementById('healthBody').textContent"))
    check("the breakdowns show today's numbers (Home 3 views; high contrast for 1 of 1 visitors)",
          p.js("(function(){var r=[...document.querySelectorAll('#barsPages li')].map(l=>l.textContent);"
               "var a=[...document.querySelectorAll('#barsAids li')].map(l=>l.textContent);"
               "return r[0].startsWith('Home') && /3 · 43%/.test(r[0]) && a.some(t=>/High contrast/.test(t) && /1 · 100%/.test(t));})()"),
          p.js("[...document.querySelectorAll('#barsPages li')].map(l=>l.textContent).slice(0,2)"))
    snap = wait_for(lambda: fields(f"downloads/{today}"), 15)
    gh_total = p.js("document.querySelectorAll('#kpis .tile-value')[2].textContent.replace(/,/g, '')")
    check("today's GitHub total is saved for the trend", snap and str(snap.get("total")) == gh_total, (snap, gh_total))
    check("the message text is shown as text, not as HTML",
          p.js("[...document.querySelectorAll('#inbox .msg-text')].some(e => e.textContent.startsWith('=1+2'))"))

    check("signed in: the sidebar is shown and the dashboard opens on the Overview",
          p.js("!document.getElementById('side').hidden && document.getElementById('pageTitle').textContent === 'Overview'"
               " && document.querySelector('.side-nav a[aria-current=page]').dataset.view === 'overview'"
               " && !document.querySelector('.view[data-view=overview]').hidden && document.querySelector('.view[data-view=audience]').hidden"))
    check("the overview lists the most-read pages (top 5), the latest feedback and the release check",
          p.js("(function(){var r=document.querySelectorAll('#barsTopPages li');"
               "return r.length >= 1 && r.length <= 5 && r[0].textContent.startsWith('Home')"
               " && document.querySelectorAll('#latestFeedback li').length === 2"
               " && !!document.querySelector('#healthSummary .status-line');})()"),
          p.js("document.getElementById('latestFeedback').textContent.slice(0, 120)"))
    check("the sidebar shows how many messages are not yet seen (2)",
          p.js("!document.getElementById('navUnseen').hidden && document.getElementById('navUnseen').textContent.startsWith('2')"))
    p.js("document.querySelector('.side-nav a[data-view=audience]').click()")
    check("the sidebar opens a section: its title, its address, focus on its heading",
          p.wait("document.getElementById('pageTitle').textContent === 'Audience' && location.hash === '#audience'"
                 " && !document.querySelector('.view[data-view=audience]').hidden && document.querySelector('.view[data-view=overview]').hidden"
                 " && document.activeElement === document.getElementById('pageTitle') && document.title.startsWith('Audience')"))
    p.js("history.back()")
    check("Back returns to the previous section", p.wait("document.getElementById('pageTitle').textContent === 'Overview'"))

    # Every section: accessibility and a screenshot.
    found = []
    for view in ("overview", "audience", "downloads", "feedback", "tools"):
        p.js(f"location.hash = '#{view}'")
        p.wait(f"!document.querySelector('.view[data-view={view}]').hidden")
        time.sleep(0.5)
        found += [view + ": " + v for v in axe(p, view)]
        p.shot(f"dashboard-{view}-desktop", full=True)
    check("accessibility: every section of the dashboard has no axe violations (computer, light)", not found, found)
    p.js("location.hash = '#feedback'")
    # Inbox actions
    p.js("""(function(){
      const item = [...document.querySelectorAll('#inbox .msg-item')].find(li => li.querySelector('.msg-text:not(.none)'));
      const sel = item.querySelector('select'); sel.value = 'seen'; sel.dispatchEvent(new Event('change'));
      [...item.querySelectorAll('button')].find(b => /Star/.test(b.textContent)).click();
    })()""")
    msg_id = next(d["name"].rsplit("/", 1)[1] for d in listing("feedback") if fields("feedback/" + d["name"].rsplit("/", 1)[1]).get("message"))
    f = wait_for(lambda: (fields(f"feedback/{msg_id}") or {}).get("starred") is True and fields(f"feedback/{msg_id}"))
    check("marking a message seen and starring it is saved", f and f.get("status") == "seen", f)
    check("the sidebar count follows (1 not yet seen)", p.wait("document.getElementById('navUnseen').textContent.startsWith('1')"))
    p.js("window.confirm = () => true;"
         "[...document.querySelectorAll('#inbox .msg-item')].find(li => li.querySelector('.msg-text.none')).querySelector('.btn-danger').click()")
    check("deleting a rating removes it", wait_for(lambda: len(listing("feedback")) == 1)
          and p.wait("document.querySelectorAll('#inbox .msg-item').length === 1"))
    check("with nothing left unseen, the sidebar count disappears", p.wait("document.getElementById('navUnseen').hidden"))

    # Exports
    dl = tempfile.mkdtemp(prefix="fladm-dl-")
    browser = Page(json.load(urllib.request.urlopen("http://127.0.0.1:9333/json/version"))["webSocketDebuggerUrl"])
    browser.call("Browser.setDownloadBehavior", behavior="allow", downloadPath=dl)
    p.js("document.getElementById('btnCsvMessages').click(); document.getElementById('btnCsvDaily').click()")
    files = wait_for(lambda: (lambda fs: len(fs) == 2 and all(not x.endswith(".crdownload") for x in fs) and fs)(os.listdir(dl)), 10) or []
    texts = {x: open(os.path.join(dl, x), encoding="utf-8-sig").read() for x in files}
    msgs = next((v for k, v in texts.items() if "messages" in k), "")
    daily = next((v for k, v in texts.items() if "daily" in k), "")
    check("the messages export keeps a formula-looking message as text", "'=1+2 Please add more Filipino words" in msgs, msgs[:200])
    check("the daily export has today's 7 page views",
          any(line.startswith(today + ",") and line.split(",")[3] == "7" for line in daily.splitlines()), daily.splitlines()[:2])
    shutil.rmtree(dl, ignore_errors=True)

    # Another period, then the phone layout in dark mode
    p.js("document.querySelector('[data-range=\"7\"]').click()")
    check("switching the period redraws everything", p.wait("document.querySelector('[data-range=\"7\"]').getAttribute('aria-checked') === 'true'"
                                                          " && !document.getElementById('dash').classList.contains('loading')"
                                                          " && document.querySelectorAll('#kpis .tile').length === 5"))
    p.call("Emulation.setDeviceMetricsOverride", width=390, height=844, deviceScaleFactor=1, mobile=True)
    p.call("Emulation.setEmulatedMedia", features=[{"name": "prefers-color-scheme", "value": "dark"}])
    # With an unread count on the Feedback tab: its screen-reader text once escaped the
    # scrolling tab strip and made the whole page 550 px wide on a phone.
    p.js("(function(){ const s = document.querySelector('#inbox .msg-item select'); s.value = 'new'; s.dispatchEvent(new Event('change')); })()")
    check("phone width: marking a message new again brings back the tab's unread count",
          p.wait("!document.getElementById('navUnseen').hidden"))
    wide, found = [], []
    for view in ("overview", "feedback"):
        p.js(f"location.hash = '#{view}'")
        time.sleep(0.8)
        if p.js("document.documentElement.scrollWidth > document.documentElement.clientWidth"):
            wide.append(view)
        p.shot(f"dashboard-{view}-phone-dark", full=True)
        found += [view + ": " + v for v in axe(p, view + " phone")]
    check("phone width: no section scrolls sideways", not wide, wide)
    check("accessibility: the dashboard has no axe violations (phone, dark)", not found, found)
    p.call("Emulation.setEmulatedMedia", features=[])
    p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)

    check("no Content-Security-Policy violations", p.js("window.__csp.length === 0"), p.js("window.__csp"))
    check("no script errors on the dashboard", not p.errors, p.errors[:4])
    p.js("window.__old = 1; document.getElementById('btnSignOut').click()")
    check("signing out reloads the page: sign-in only, no statistics left in it",
          p.wait("!window.__old && document.readyState === 'complete' && !document.getElementById('viewSignIn').hidden", 20)
          and p.js("document.getElementById('viewDash').hidden && !document.getElementById('kpis').children.length"
                   " && !document.querySelectorAll('#inbox li').length"))


if __name__ == "__main__":
    main()
