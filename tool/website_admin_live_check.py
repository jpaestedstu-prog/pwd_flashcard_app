"""Checks the DEPLOYED website statistics project (flashlearn-pwd-site): the dashboard's
hosting and headers, its sign-in page in Chrome, and the security rules, probed exactly
as the public website talks to them (no sign-in).

    python tool/website_admin_live_check.py          # after deploying rules + dashboard
    python tool/website_admin_live_check.py --site   # also the published website (after gh-pages)

What it writes is undone. A test count is taken back with an increment of -1 (so a real
visitor counted at the same moment is not erased) and a test message is deleted, using
the Firebase CLI's owner access: its token is held in memory, never printed or saved.
"""
import base64, datetime, json, os, shutil, subprocess, sys, tempfile, time, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (Chrome client, axe, check())

PROJECT = "flashlearn-pwd-site"
DASH = f"https://{PROJECT}.web.app"
SITE = "https://jpaestedstu-prog.github.io/pwd_flashcard_app"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
check = h.check
TOKEN = None


def owner_token():
    """The Firebase CLI's access token (owner of the project), kept in memory only."""
    global TOKEN
    if TOKEN is None:
        npm_root = subprocess.run("npm root -g", shell=True, capture_output=True, text=True).stdout.strip()
        lib = os.path.join(npm_root, "firebase-tools", "lib").replace("\\", "/") + "/"
        js = ("const lib=%s;const {requireAuth}=require(lib+'requireAuth.js');"
              "const {getGlobalDefaultAccount}=require(lib+'auth.js');const {getAccessToken}=require(lib+'apiv2.js');"
              "(async()=>{const a=getGlobalDefaultAccount();await requireAuth({user:a.user,tokens:a.tokens});"
              "process.stdout.write(await getAccessToken());})().catch(e=>{process.stderr.write(e.message);process.exit(1);});") % json.dumps(lib)
        r = subprocess.run(["node", "-e", js], capture_output=True, text=True)
        if r.returncode or not r.stdout:
            sys.exit("Could not use the Firebase CLI's sign-in (run `firebase login`): " + r.stderr[:200])
        TOKEN = r.stdout.strip()
    return TOKEN


def rest(method, url, body=None, owner=False, quota=True):
    headers = {"Content-Type": "application/json"}
    if owner:
        headers["Authorization"] = "Bearer " + owner_token()
        if quota:   # bill the request's quota to this project (free; needed by Firestore)
            headers["X-Goog-User-Project"] = PROJECT
    r = urllib.request.Request(url, method=method, headers=headers, data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def counts(path):
    st, d = rest("GET", f"{FS}/{path}", owner=True)
    return {} if st != 200 else {k: int(v["integerValue"]) for k, v in d.get("fields", {}).items() if "integerValue" in v}


def bump(path, keys, by=1, owner=False, extra=None):
    extra = extra or {}
    return rest("POST", f"{FS}:commit", {"writes": [{
        "update": {"name": f"{ROOT}/{path}", "fields": {k: {"stringValue": v} for k, v in extra.items()}},
        "updateMask": {"fieldPaths": list(extra)},
        "updateTransforms": [{"fieldPath": k, "increment": {"integerValue": str(by)}} for k in keys]}]}, owner=owner)[0]


def send(doc_id, fields, server_time=True):
    w = {"update": {"name": f"{ROOT}/feedback/{doc_id}", "fields": {
        k: ({"integerValue": str(v)} if isinstance(v, int) else {"stringValue": v}) for k, v in fields.items()}},
         "currentDocument": {"exists": False}}
    if server_time:
        w["updateTransforms"] = [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]
    return rest("POST", f"{FS}:commit", {"writes": [w]})[0]


def manila_day(offset=0):
    t = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=8, days=offset)
    return t.strftime("%Y-%m-%d")


def free_plan():
    """The project must stay on the no-cost Spark plan: no billing account linked."""
    st, d = rest("GET", f"https://cloudbilling.googleapis.com/v1/projects/{PROJECT}/billingInfo", owner=True, quota=False)
    check("billing is NOT enabled on the project (free Spark plan)", st == 200 and d.get("billingEnabled") is False, (st, d))


def hosting():
    with open(os.path.join(h.ROOT, "website_admin", "firebase.json"), encoding="utf-8") as f:
        want = {x["key"].lower(): x["value"] for x in json.load(f)["hosting"]["headers"][0]["headers"]}
    with urllib.request.urlopen(DASH + "/", timeout=30) as r:
        got = {k.lower(): v for k, v in r.headers.items()}
        page = r.read().decode("utf-8")
    check("the dashboard is served at " + DASH, "FlashLearn PWD Admin" in page)
    bad = [k for k, v in want.items() if got.get(k) != v]
    check("every security header is sent exactly as configured (CSP, no framing, no referrer, noindex...)", not bad, bad)
    with urllib.request.urlopen(DASH + "/robots.txt", timeout=30) as r:
        check("robots.txt asks search engines to stay out", "Disallow: /" in r.read().decode())
    with urllib.request.urlopen(f"https://{PROJECT}.firebaseapp.com/__/auth/handler", timeout=30) as r:
        check("the Google sign-in handler answers on the auth domain", r.status == 200)


def dashboard_in_chrome():
    profile = tempfile.mkdtemp(prefix="fllive-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9341", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9341/json/list"))
                                      if t["type"] == "page"), None) if h._up(9341) else None, 20)
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        p.call("Page.addScriptToEvaluateOnNewDocument",
               source="window.__csp = []; document.addEventListener('securitypolicyviolation', e => window.__csp.push(e.violatedDirective + ' ' + e.blockedURI));")
        p.goto(DASH + "/")
        check("live dashboard: signed out, it shows only the sign-in", p.wait("!document.getElementById('viewSignIn').hidden", 20)
              and p.js("document.getElementById('viewDash').hidden"))
        found = h.axe(p, "live sign-in")
        check("live dashboard: no accessibility violations on the sign-in page", not found, found)
        check("live dashboard: no Content-Security-Policy violations", p.js("window.__csp.length === 0"), p.js("window.__csp"))
        check("live dashboard: no script errors", not p.errors, p.errors[:3])
        return p, chrome, profile
    except Exception:
        chrome.kill()
        shutil.rmtree(profile, ignore_errors=True)
        raise


def exists(path):
    return rest("GET", f"{FS}/{path}", owner=True)[0] == 200


def take_back(path, deltas, existed):
    """Undo test increments with -n per key. A document the test itself created, still
    holding nothing but the test's own counts, is deleted instead."""
    if not existed:
        after = counts(path)
        if set(after) <= set(deltas) and all(after[k] <= deltas[k] for k in after):
            return rest("DELETE", f"{FS}/{path}", owner=True)[0] == 200
    return all(bump(path, [k], by=-n, owner=True) == 200 for k, n in deltas.items() if n > 0)


def rules():
    today, day = manila_day(), f"daily/{manila_day()}"
    for path in (day, f"signs/{today}", "feedback/x", f"downloads/{today}", "admins/x"):
        check(f"public read of {path.split('/')[0]} is refused", rest("GET", f"{FS}/{path}")[0] == 403)
    st = rest("POST", f"{FS}:runQuery", {"structuredQuery": {"from": [{"collectionId": "feedback"}]}})[0]
    check("public listing of messages is refused", st == 403)
    check("a jump of two is refused", bump(day, ["p_other"], by=2) == 403)
    check("an unknown tally is refused", bump(day, ["x_live_check"]) == 403)
    check("a back-dated day is refused", bump(f"daily/{manila_day(-3)}", ["p_other"]) == 403)
    check("a sign tally not named in `last` is refused", bump(f"signs/{today}", ["w_live_check"], extra={"last": "w_other"}) == 403)
    good = {"type": "rating", "role": "other", "message": "", "page": "faq", "lang": "en", "status": "new", "rating": 5}
    check("a message with an extra field is refused", send("LIVECHECKX" + "0" * 10, {**good, "email": "a@b.c"}) == 403)
    check("a message arriving as done is refused", send("LIVECHECKY" + "0" * 10, {**good, "status": "done"}) == 403)
    check("six stars are refused", send("LIVECHECKZ" + "0" * 10, {**good, "rating": 6}) == 403)
    check("nobody can add an administrator from outside the console",
          rest("PATCH", f"{FS}/admins/live-check", {"fields": {"name": {"stringValue": "x"}}})[0] == 403)
    # Allowed writes, each undone straight away.
    had = exists(day)
    before = counts(day).get("p_other", 0)
    ok = bump(day, ["p_other"]) == 200 and counts(day).get("p_other", 0) == before + 1
    check("a page-view tally is accepted (and taken back)", ok and take_back(day, {"p_other": 1}, had))
    sday = f"signs/{today}"
    had = exists(sday)
    ok = bump(sday, ["w_live_check"], extra={"last": "w_live_check"}) == 200 and counts(sday).get("w_live_check") == 1
    if had:   # keep the day's other signs; drop only the test counter
        gone = rest("PATCH", f"{FS}/{sday}?updateMask.fieldPaths=w_live_check", {"fields": {}}, owner=True)[0] == 200
    else:
        gone = rest("DELETE", f"{FS}/{sday}", owner=True)[0] == 200
    check("a sign tally is accepted (and removed)", ok and gone)
    doc_id = "LIVECHECK" + base64.b32encode(os.urandom(10)).decode()[:11]
    ok = send(doc_id, good) == 200
    check("the public cannot delete a message", rest("DELETE", f"{FS}/feedback/{doc_id}")[0] == 403)
    check("a rating is accepted (and deleted)", ok and rest("DELETE", f"{FS}/feedback/{doc_id}", owner=True)[0] == 200)


def site(p):
    """The published website counts and its form sends; both undone afterwards."""
    # The site leaves robots uncounted, and a headless browser calls itself "HeadlessChrome".
    ua = p.call("Browser.getVersion")["userAgent"].replace("HeadlessChrome", "Chrome")
    p.call("Emulation.setUserAgentOverride", userAgent=ua)
    day = f"daily/{manila_day()}"
    had, before = exists(day), counts(day)
    # Two page views from a fresh browser: Home typed in, then the FAQ through the menu.
    expected = {"v": 2, "p_index": 1, "p_faq": 1, "l_en": 2, "u": 1, "n": 1, "d_computer": 1, "s_direct": 1}
    p.goto(SITE + "/index.html")
    first = h.wait_for(lambda: (lambda c: c if c.get("u", 0) > before.get("u", 0) else None)(counts(day)), 20)
    check("the live website counts a visit (page, language, visitor, new visitor, device, arrival)",
          first and all(first.get(k, 0) > before.get(k, 0) for k in ("v", "p_index", "l_en", "n", "d_computer", "s_direct")),
          first and {k: first.get(k, 0) - before.get(k, 0) for k in expected})
    p.follow('.site-nav a[href="faq.html"]')
    check("the live feedback form offers Send to the team", p.wait("!document.getElementById('fbSend').hidden", 10))
    time.sleep(1.6)
    p.js("document.getElementById('fbR5').click(); document.getElementById('fbMsg').value = '[live check] please ignore';"
         "document.getElementById('fbSend').click()")
    check("a live rating with a message is sent and thanked",
          p.wait("/reached the FlashLearn PWD team/.test(document.getElementById('fbStatus').textContent)", 15))
    st, docs = rest("POST", f"{FS}:runQuery", {"structuredQuery": {"from": [{"collectionId": "feedback"}],
                    "where": {"fieldFilter": {"field": {"fieldPath": "message"}, "op": "EQUAL",
                                              "value": {"stringValue": "[live check] please ignore"}}}}}, owner=True)
    names = [d["document"]["name"] for d in (docs or []) if "document" in d] if st == 200 else []
    deleted = all(rest("DELETE", "https://firestore.googleapis.com/v1/" + n, owner=True)[0] == 200 for n in names)
    check("it arrived in the database (and was deleted)", len(names) == 1 and deleted, (st, len(names)))
    after = h.wait_for(lambda: (lambda c: c if c.get("p_faq", 0) > before.get("p_faq", 0) else None)(counts(day)), 15) or counts(day)
    deltas = {k: min(n, after.get(k, 0) - before.get(k, 0)) for k, n in expected.items()}
    check("the test visits are taken back out of today's totals", take_back(day, deltas, had), deltas)


def main():
    free_plan()
    hosting()
    rules()
    p, chrome, profile = dashboard_in_chrome()
    try:
        if "--site" in sys.argv:
            site(p)
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    failed = h.results.count(False)
    print(f"\n{len(h.results) - failed}/{len(h.results)} live checks passed")
    sys.exit(1 if failed else 0)



if __name__ == "__main__":
    main()
