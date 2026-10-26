"""The website and the admin dashboard in the REAL Chrome of an Android phone, tablet or
emulator, against the LOCAL Firebase emulators (nothing real is touched).

    cd website_admin
    firebase emulators:start --only firestore,auth --project demo-flashlearn-site
    python tool/website_device_check.py [serial] [screenshot folder] [--sideways]

Tunnels (removed afterwards): adb reverse 8899 (website), 8898 (dashboard), 8080 and
9099 (Firestore and Auth emulators); adb forward 9230 to Chrome's DevTools. Checks that
every page fits the screen with no script errors, that a visit is counted with the
device's real kind (phone or tablet), that the feedback form sends, and that the
dashboard signs in, opens every section, fits and passes axe. --sideways turns the
screen once Chrome is open (auto-rotate off, user rotation 1) and puts both settings back.
"""
import json, os, subprocess, sys, tempfile, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
SIDEWAYS_RUN = "--sideways" in sys.argv[1:]
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SERIAL = next((a for a in ARGS if not any(c in a for c in r"/\:")), None)   # a serial has no path characters
SHOTS = next((a for a in ARGS if a != SERIAL), None) or tempfile.mkdtemp(prefix="fldev-")
os.makedirs(SHOTS, exist_ok=True)
sys.argv = ["x", SHOTS]
import website_admin_e2e_check as h  # noqa: E402

ADB = r"C:\Android\Sdk\platform-tools\adb.exe"
PORTS = (8899, 8898, 8080, 9099)
PAGES = ("index.html", "try.html", "download.html", "how-to-use.html", "games.html", "fsl-dictionary.html",
         "teachers-guide.html", "faq.html", "awareness.html", "about.html", "privacy.html", "gaze-control.html")
check = h.check


def adb(*args, check_ok=True):
    cmd = [ADB] + (["-s", SERIAL] if SERIAL else []) + list(args)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if check_ok and r.returncode:
        raise RuntimeError(" ".join(args) + ": " + (r.stderr or r.stdout).strip())
    return r.stdout.strip()


def device_page():
    """Chrome's tab on the device, over DevTools."""
    def find():
        try:
            tabs = json.load(urllib.request.urlopen("http://127.0.0.1:9230/json", timeout=5))
        except Exception:
            return None
        return next((t["webSocketDebuggerUrl"] for t in tabs if t.get("type") == "page"
                     and t.get("url", "").startswith("http://127.0.0.1:8899")), None)
    return h.wait_for(find, 40)


def turn_sideways(p):
    """Turns the screen sideways with Chrome in front. Turning it before Chrome restarts does
    not hold: the launcher shows in between, and an upright-only launcher (the Villaon's)
    turns the screen back for good. Returns the settings to put back."""
    get = lambda name: adb("shell", "settings", "get", "system", name)
    before = {name: get(name) for name in ("accelerometer_rotation", "user_rotation")}
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    if before["user_rotation"] == "1":   # already 1: only a change turns the screen
        adb("shell", "settings", "put", "system", "user_rotation", "0")
    adb("shell", "settings", "put", "system", "user_rotation", "1")
    check("the screen turned sideways", h.wait_for(lambda: p.js("innerWidth > innerHeight"), 15),
          p.js("innerWidth + ' x ' + innerHeight"))
    return before


def put_back(settings):
    for name, value in settings.items():
        if value in ("", "null"):
            adb("shell", "settings", "delete", "system", name, check_ok=False)
        else:
            adb("shell", "settings", "put", "system", name, value, check_ok=False)


def main():
    model = adb("shell", "getprop", "ro.product.model")
    h.wait_for(lambda: adb("shell", "getprop", "sys.boot_completed") == "1", 180)
    size = adb("shell", "wm", "size").split()[-1]
    density = int(adb("shell", "wm", "density").split()[-1])
    w, hgt = (int(x) for x in size.split("x"))
    smallest_dp = min(w, hgt) * 160 / density
    kind = "phone" if smallest_dp < 600 else "tablet"
    print(f"device: {model}, {size} at {density} dpi -> smallest width {smallest_dp:.0f} dp: a {kind}", flush=True)

    h.rest("DELETE", f"http://127.0.0.1:8080/emulator/v1/projects/{h.PROJECT}/databases/(default)/documents")
    h.rest("DELETE", f"http://127.0.0.1:9099/emulator/v1/projects/{h.PROJECT}/accounts", token=None)
    h.serve(8899, os.path.join(h.ROOT, "website"), h.Quiet)
    h.serve(8898, os.path.join(h.ROOT, "website_admin", "public"), h.AdminHandler)
    for port in PORTS:
        adb("reverse", f"tcp:{port}", f"tcp:{port}")
    # Chrome without its first-run screens (read on its next start).
    adb("shell", "am", "set-debug-app", "--persistent", "com.android.chrome")
    adb("shell", "sh", "-c", "'echo \"_ --disable-fre --no-default-browser-check --no-first-run\" > /data/local/tmp/chrome-command-line'")
    adb("shell", "am", "force-stop", "com.android.chrome")
    adb("shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "http://127.0.0.1:8899/index.html", "com.android.chrome")
    adb("forward", "tcp:9230", "localabstract:chrome_devtools_remote")
    rotation = None
    try:
        ws = device_page()
        if not ws:
            sys.exit("Chrome on the device did not open the page (first-run screen still showing?)")
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        for origin in ("http://127.0.0.1:8899", "http://127.0.0.1:8898"):
            p.call("Storage.clearDataForOrigin", origin=origin, storageTypes="all")
        if SIDEWAYS_RUN:
            rotation = turn_sideways(p)
        run(p, kind)
    finally:
        if rotation:
            put_back(rotation)
        adb("forward", "--remove", "tcp:9230", check_ok=False)
        for port in PORTS:
            adb("reverse", "--remove", f"tcp:{port}", check_ok=False)
        adb("shell", "rm", "-f", "/data/local/tmp/chrome-command-line", check_ok=False)
        adb("shell", "am", "clear-debug-app", check_ok=False)
    failed = h.results.count(False)
    print(f"\n{len(h.results) - failed}/{len(h.results)} device checks passed on {model} · screenshots in {SHOTS}")
    sys.exit(1 if failed else 0)


# Why a page does not fit the screen, or '' when it does: it really scrolls sideways, its
# content is wider than the screen (hidden by body{overflow-x:hidden}, which cuts it off
# instead), or the header's controls end past the edge. The screen width is the exact one:
# clientWidth rounds a 423.53 px screen down to 423, and scrollWidth (a whole number) can
# then read 424 on a page that fits.
SIDEWAYS = """(function(){
  var x = scrollX, y = scrollY;
  scrollTo({left: 100000, top: y, behavior: 'instant'});
  var moved = scrollX;
  scrollTo({left: x, top: y, behavior: 'instant'});
  var W = document.documentElement.getBoundingClientRect().width, sw = document.documentElement.scrollWidth;
  var t = document.querySelector('.header-tools'), right = t ? t.getBoundingClientRect().right : 0;
  if (moved > 0) return 'scrolls ' + moved + ' px sideways';
  if (sw > Math.ceil(W)) return 'content ' + sw + ' px wide on a ' + W.toFixed(1) + ' px screen';
  if (right > W + 0.5) return 'header controls end at ' + right.toFixed(1) + ' px on a ' + W.toFixed(1) + ' px screen';
  return '';
})()"""


def run(p, kind):
    day = f"daily/{h.manila_day()}"
    p.goto(f"{h.SITE}/index.html")
    # A fresh visitor: Chrome on Android keeps an open page's storage through
    # Storage.clearDataForOrigin, so the test copy's own notes are cleared here.
    p.js("localStorage.clear(); sessionStorage.clear()")
    p.js("localStorage.setItem('flp-stats-test', JSON.stringify({base: 'http://127.0.0.1:8080/v1', project: '%s'}))" % h.PROJECT)
    # The page just opened may still send a count left switched on by an earlier run:
    # let it land, then start from an empty database.
    time.sleep(1.5)
    h.rest("DELETE", f"http://127.0.0.1:8080/emulator/v1/projects/{h.PROJECT}/databases/(default)/documents")
    p.goto(f"{h.SITE}/index.html")
    t = h.wait_for(lambda: (h.fields(day) or {}).get("v") == 1 and h.fields(day), 20)
    check(f"a visit on this {kind} is counted as a {kind} (real touch screen and size)",
          t and t.get(f"d_{kind}") == 1 and t.get("u") == 1, t)
    p.shot(f"device-{kind}-home")

    wide, errors = [], []
    for page in PAGES:
        p.errors.clear()
        p.goto(f"{h.SITE}/{page}")
        time.sleep(0.4)
        why = p.js(SIDEWAYS)
        if why:
            wide.append(f"{page}: {why}")
        errors += [f"{page}: {e}" for e in p.errors]
    check(f"every page fits the {kind}'s screen (no sideways scrolling, header inside)", not wide, wide)
    check("no script errors on any page", not errors, errors[:3])

    p.goto(f"{h.SITE}/faq.html")
    shown = "(id => getComputedStyle(document.getElementById(id)).display !== 'none')"
    check("the feedback form offers Send to the team", p.js(f"{shown}('fbSend') && !{shown}('fbNoteMail')"))
    time.sleep(1.6)
    p.js("document.getElementById('fbR5').click(); document.getElementById('fbMsg').value = 'Sent from a " + kind + "';"
         "document.getElementById('fbSend').click()")
    check("a rating sent from the device arrives",
          p.wait("/reached the FlashLearn PWD team/.test(document.getElementById('fbStatus').textContent)", 15)
          and len(h.listing("feedback")) == 1)

    # The dashboard
    uid = h.sign_up("device@example.com", "a-long-device-password")
    h.rest("PATCH", f"{h.FS}/admins/{uid}", {"fields": {"name": {"stringValue": "device test"}}})
    p.goto(f"{h.ADMIN}/?emulator")
    p.wait("!document.getElementById('viewSignIn').hidden", 20)
    p.js("document.querySelector('.email-signin').open = true;"
         "document.getElementById('inEmail').value = 'device@example.com';"
         "document.getElementById('inPassword').value = 'a-long-device-password';"
         "document.getElementById('formEmail').requestSubmit()")
    check("the dashboard signs in on the device", p.wait("!document.getElementById('viewDash').hidden"
                                                         " && document.querySelectorAll('#kpis .tile').length === 5", 30))
    wide, found = [], []
    for view in ("overview", "audience", "downloads", "feedback", "tools"):
        p.js(f"location.hash = '#{view}'")
        p.wait(f"!document.querySelector('.view[data-view={view}]').hidden")
        time.sleep(0.6)
        why = p.js(SIDEWAYS)
        if why:
            wide.append(f"{view}: {why}")
        found += [view + ": " + v for v in h.axe(p, view)]
        if view in ("overview", "feedback"):
            p.shot(f"device-{kind}-dashboard-{view}")
    # Up to 900 px wide the sidebar becomes a top bar with tabs (an upright phone); a
    # phone turned sideways is wider than that and keeps the sidebar, which suits its
    # short screen better than a bar taking a quarter of the height.
    layout = p.js("getComputedStyle(document.getElementById('app')).display")
    width = p.js("document.documentElement.clientWidth")
    check(f"the dashboard layout suits a {kind} {width} px wide ({'sidebar' if layout == 'grid' else 'top bar with tabs'})",
          layout == ("grid" if width > 900 else "block"), layout)
    if layout == "grid":
        fill = p.js("(function(){var s=document.getElementById('side').getBoundingClientRect(), y=innerHeight-4;"
                    "var e=document.elementFromPoint(20, y);"
                    "return {sideBottom: Math.round(s.bottom), viewport: innerHeight, atBottom: e ? (e.closest('#side') ? 'sidebar' : e.tagName) : null};})()")
        check("the sidebar reaches the bottom of the screen", fill["sideBottom"] >= fill["viewport"] - 1 and fill["atBottom"] == "sidebar", fill)
        # A phone's address bar takes part of the screen: scrolled to its end, the
        # sidebar's last control must still be on the screen, not under its edge.
        reach = p.js("(function(){var s=document.getElementById('side'), b=document.getElementById('btnSignOut');"
                     "s.scrollTop = s.scrollHeight; var r = b.getBoundingClientRect();"
                     "var out = {signOutBottom: Math.round(r.bottom), screen: innerHeight, sideHeight: s.clientHeight, scrolls: s.scrollHeight > s.clientHeight};"
                     "s.scrollTop = 0; return out;})()")
        check("every sidebar control can be scrolled onto the screen (Sign out last)", reach["signOutBottom"] <= reach["screen"], reach)
    check("no dashboard section scrolls sideways on the device", not wide, wide)
    check("accessibility: no axe violations in any section on the device", not found, found[:4])
    check("no script errors on the dashboard", not p.errors, p.errors[:3])


if __name__ == "__main__":
    main()
