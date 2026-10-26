"""The website and the admin dashboard in the REAL Chrome of an Android phone, tablet or
emulator, against the LOCAL Firebase emulators (nothing real is touched).

    cd website_admin
    firebase emulators:start --only firestore,auth --project demo-flashlearn-site
    python tool/website_device_check.py [serial] [screenshot folder]

Tunnels (removed afterwards): adb reverse 8899 (website), 8898 (dashboard), 8080 and
9099 (Firestore and Auth emulators); adb forward 9230 to Chrome's DevTools. Checks that
every page fits the screen with no script errors, that a visit is counted with the
device's real kind (phone or tablet), that the feedback form sends, and that the
dashboard signs in, opens every section, fits and passes axe.
"""
import json, os, subprocess, sys, tempfile, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ARGS = sys.argv[1:]
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
    try:
        ws = device_page()
        if not ws:
            sys.exit("Chrome on the device did not open the page (first-run screen still showing?)")
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        for origin in ("http://127.0.0.1:8899", "http://127.0.0.1:8898"):
            p.call("Storage.clearDataForOrigin", origin=origin, storageTypes="all")
        run(p, kind)
    finally:
        adb("forward", "--remove", "tcp:9230", check_ok=False)
        for port in PORTS:
            adb("reverse", "--remove", f"tcp:{port}", check_ok=False)
        adb("shell", "rm", "-f", "/data/local/tmp/chrome-command-line", check_ok=False)
        adb("shell", "am", "clear-debug-app", check_ok=False)
    failed = h.results.count(False)
    print(f"\n{len(h.results) - failed}/{len(h.results)} device checks passed on {model} · screenshots in {SHOTS}")
    sys.exit(1 if failed else 0)


FITS = """(function(){
  var W = document.documentElement.clientWidth, t = document.querySelector('.header-tools');
  return document.documentElement.scrollWidth <= W && (!t || t.getBoundingClientRect().right <= W + 0.5);
})()"""


def run(p, kind):
    day = f"daily/{h.manila_day()}"
    p.goto(f"{h.SITE}/index.html")
    p.js("localStorage.setItem('flp-stats-test', JSON.stringify({base: 'http://127.0.0.1:8080/v1', project: '%s'}))" % h.PROJECT)
    p.goto(f"{h.SITE}/index.html")
    t = h.wait_for(lambda: (h.fields(day) or {}).get("v") == 1 and h.fields(day), 20)
    check(f"a visit on this {kind} is counted as a {kind} (real touch screen and size)",
          t and t.get(f"d_{kind}") == 1 and t.get("u") == 1, t)

    wide, errors = [], []
    for page in PAGES:
        p.errors.clear()
        p.goto(f"{h.SITE}/{page}")
        time.sleep(0.4)
        if not p.js(FITS):
            wide.append(page)
        errors += [f"{page}: {e}" for e in p.errors]
    check(f"every page fits the {kind}'s screen (no sideways scrolling, header inside)", not wide, wide)
    check("no script errors on any page", not errors, errors[:3])
    p.shot(f"device-{kind}-home")

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
        if p.js("document.documentElement.scrollWidth > document.documentElement.clientWidth"):
            wide.append(view)
        found += [view + ": " + v for v in h.axe(p, view)]
        if view in ("overview", "feedback"):
            p.shot(f"device-{kind}-dashboard-{view}")
    layout = p.js("getComputedStyle(document.getElementById('app')).display")
    check(f"the dashboard layout suits a {kind} ({'sidebar' if layout == 'grid' else 'top bar with tabs'})",
          (layout == "block") if kind == "phone" else True, layout)
    check("no dashboard section scrolls sideways on the device", not wide, wide)
    check("accessibility: no axe violations in any section on the device", not found, found[:4])
    check("no script errors on the dashboard", not p.errors, p.errors[:3])


if __name__ == "__main__":
    main()
