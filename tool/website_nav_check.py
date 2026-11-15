"""The website's grouped navigation, theme choice and arrival animation, in headless Chrome.

    python tool/website_nav_check.py [--port 8899]

Checks, on the real pages (website/ served locally; nothing is counted):
  * every page is reachable from the header of every page, exactly once, and the
    current page is marked (its link aria-current="page", its group's button
    aria-current="true"), with Home > Group > Page breadcrumbs;
  * a group opens with a click, with Down (first link) and Up (last link), moves
    with the arrow keys, closes with Escape (focus back on its button), a click
    outside, or by opening another; it never opens or closes by itself (no hover,
    no timer), so a slow pointer (head-pointer, eye-gaze, switch) never loses it;
  * every group holds at most five links, in the agreed order (Explore shows the app,
    Help teaches it, Teachers & Parents links into the adults' guides);
  * an open panel stays inside the window at 1024, 1280 and 1440 px;
  * on a phone the Menu sheet lists every page and closes with Escape;
  * the theme choice (Auto / Light / Dark) applies, follows to the next page,
    and loses to high contrast;
  * the arrival animation: off for robots and with reduced motion; with a
    normal browser, nothing on screen is hidden and everything below the fold
    is visible once scrolled to.
Fails on any script error.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (its Chrome client and server)

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8899)
args = ap.parse_args()
SITE = f"http://127.0.0.1:{args.port}"
results = []


def check(label, ok, detail=""):
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + label + ("" if ok or not detail else f"  [{detail}]"), flush=True)


def key(p, k, code=None, vk=0):
    for t in ("rawKeyDown", "keyUp"):
        p.call("Input.dispatchKeyEvent", type=t, key=k, code=code or k, windowsVirtualKeyCode=vk, nativeVirtualKeyCode=vk)
    time.sleep(0.08)


ESC, DOWN, UP, END = ("Escape", "Escape", 27), ("ArrowDown", "ArrowDown", 40), ("ArrowUp", "ArrowUp", 38), ("End", "End", 35)


def press(p, k):
    key(p, k[0], k[1], k[2])


def goto(p, page, settle=0.35):
    p.goto(f"{SITE}/{page}")
    time.sleep(settle)


def main():
    pages = sorted(f for f in os.listdir(os.path.join(h.ROOT, "website")) if f.endswith(".html"))
    h.serve(args.port, os.path.join(h.ROOT, "website"), h.Quiet)
    profile = tempfile.mkdtemp(prefix="flnav-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9344", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "--mute-audio", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9344/json/list"))
                                      if t["type"] == "page"), None) if h._up(9344) else None, 20)
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable", "Network.enable"):
            p.call(d)
        p.call("Network.setCacheDisabled", cacheDisabled=True)
        p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)
        goto(p, "index.html")
        p.js("localStorage.removeItem('flp-a11y')")
        run(p, pages)
        check("no script errors", not p.errors, p.errors[:4])
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)


def run(p, pages):
    # ---- Reach and the current page, on every page ----
    bad_reach, bad_current, bad_crumbs = [], [], []
    for page in pages:
        goto(p, page, 0.2)
        r = p.js("""(function(){
          var hrefs = [...document.querySelectorAll('#siteNav a')].map(a => a.getAttribute('href').split('#')[0]);
          var cur = [...document.querySelectorAll('#siteNav a[aria-current="page"]')].map(a => a.getAttribute('href'));
          var grp = [...document.querySelectorAll('#siteNav .nav-group-btn[aria-current="true"]')].map(b => b.closest('.nav-group').dataset.group);
          var inGroup = cur.length ? !!document.querySelector('#siteNav .nav-panel a[aria-current="page"]') : false;
          var crumbs = [...document.querySelectorAll('.crumbs li')].map(li => li.innerText.trim());
          return {hrefs: hrefs, cur: cur, grp: grp, inGroup: inGroup, crumbs: crumbs};
        })()""")
        counts = {f: r["hrefs"].count(f) for f in pages}
        # Linked twice: faq.html (the FAQ and its feedback form, #feedback), about.html
        # (the team and its Future Recommendations, #future) and guides.html (Help & Guides,
        # and its adults' part, #gg-educators, under Teachers & Parents).
        wrong = {f: n for f, n in counts.items() if n != (2 if f in ("faq.html", "about.html", "guides.html") else 1)}
        if wrong:
            bad_reach.append(f"{page}: {wrong}")
        if r["cur"] != [page]:
            bad_current.append(f"{page}: {r['cur']}")
        if r["inGroup"] != bool(r["grp"]) or len(r["grp"]) > 1:
            bad_current.append(f"{page}: group {r['grp']} / link in a group {r['inGroup']}")
        if page != "index.html" and (len(r["crumbs"]) not in (2, 3) or r["crumbs"][0] != "Home" or (len(r["crumbs"]) == 3) != bool(r["grp"])):
            bad_crumbs.append(f"{page}: {r['crumbs']}")
    check(f"every page reaches all {len(pages)} pages from its header, each once", not bad_reach, bad_reach[:3])
    check("each page marks itself (link) and its group (button), and only those", not bad_current, bad_current[:3])
    check("breadcrumbs read Home > (group) > page", not bad_crumbs, bad_crumbs[:3])

    # ---- What each group holds ----
    goto(p, "games.html")
    groups = p.js("""(function(){var o={};document.querySelectorAll('.nav-group').forEach(function(g){
      o[g.dataset.group]=[...g.querySelectorAll('.nav-panel a')].map(a=>a.getAttribute('href'));});return o;})()""")
    check("Explore: App Tour, Features in Action, Gaze Control, Games, FSL Dictionary",
          groups.get("explore") == ["how-to-use.html", "features.html", "gaze-control.html", "games.html", "fsl-dictionary.html"], groups.get("explore"))
    check("Teachers & Parents: Teacher's Guide, Guides for Parents & Teachers, PWD Awareness, Privacy & Data",
          groups.get("educators") == ["teachers-guide.html", "guides.html#gg-educators", "awareness.html", "privacy.html"], groups.get("educators"))
    check("Help: Help & Guides, FAQ, Rate & Feedback, About the Team, Future Recommendations",
          groups.get("help") == ["guides.html", "faq.html", "faq.html#feedback", "about.html", "about.html#future"], groups.get("help"))
    check("no group holds more than five links, and none opens another menu",
          all(len(v) <= 5 for v in groups.values()) and not p.js("!!document.querySelector('.nav-panel .nav-panel, .nav-panel .nav-group-btn')"), groups)
    check("the menu labels: App Tour (the old How to Use) and Features in Action",
          p.js("[...document.querySelectorAll('#nav-explore .nav-main .en')].map(e=>e.textContent).slice(0,2).join('|')") == "App Tour|Features in Action")

    # ---- A group, with the mouse and the keyboard (wide screen) ----
    state = "(function(g){var e=document.querySelector('.nav-group[data-group='+g+']');return {open:e.classList.contains('open'),exp:e.querySelector('.nav-group-btn').getAttribute('aria-expanded'),shown:getComputedStyle(e.querySelector('.nav-panel')).display!=='none',focus:document.activeElement.textContent.trim().slice(0,30)};})"
    p.js("document.querySelector('.nav-group[data-group=help] .nav-group-btn').click()")
    s = p.js(state + "('help')")
    check("a click opens a group: expanded, panel shown", s["open"] and s["exp"] == "true" and s["shown"], s)
    p.js("document.querySelector('.nav-group[data-group=explore] .nav-group-btn').click()")
    s1, s2 = p.js(state + "('help')"), p.js(state + "('explore')")
    check("opening another group closes the first", not s1["open"] and s2["open"] and s1["exp"] == "false", (s1, s2))
    p.js("document.querySelector('h1').click()")
    time.sleep(0.1)
    check("a click outside closes it", not p.js(state + "('explore')")["open"])
    p.js("document.querySelector('.nav-group[data-group=educators] .nav-group-btn').focus()")
    press(p, DOWN)
    s = p.js(state + "('educators')")
    check("Down on a group's button opens it at its first link", s["open"] and s["focus"].startswith("🧑‍🏫Teacher’s Guide"), s)
    press(p, DOWN)
    check("Down moves to the next link", p.js("document.activeElement.getAttribute('href')") == "guides.html#gg-educators")
    press(p, END)
    check("End moves to the last link", p.js("document.activeElement.getAttribute('href')") == "privacy.html")
    press(p, DOWN)
    check("Down past the last link wraps to the first", p.js("document.activeElement.getAttribute('href')") == "teachers-guide.html")
    press(p, ESC)
    s = p.js(state + "('educators')")
    check("Escape closes it and returns to its button", not s["open"] and p.js("document.activeElement.classList.contains('nav-group-btn')"), s)
    press(p, UP)
    check("Up opens it at its last link", p.js("document.activeElement.getAttribute('href')") == "privacy.html")
    press(p, ESC)
    # Mouse
    box = p.js("(function(){var r=document.querySelector('.nav-group[data-group=help] .nav-group-btn').getBoundingClientRect();return [r.left+r.width/2,r.top+r.height/2];})()")
    p.call("Input.dispatchMouseEvent", type="mouseMoved", x=box[0], y=box[1])
    time.sleep(0.6)
    check("hovering a group does not open it (it opens only when chosen)", not p.js(state + "('help')")["open"])
    p.js("document.querySelector('.nav-group[data-group=help] .nav-group-btn').click()")
    p.call("Input.dispatchMouseEvent", type="mouseMoved", x=box[0], y=600)
    time.sleep(1.2)
    check("an open group stays open when the pointer wanders off (no timer closes it)", p.js(state + "('help')")["open"])
    press(p, ESC)
    check("…and Escape closes it", not p.js(state + "('help')")["open"])
    # On screen at several widths
    off = []
    for w in (1024, 1280, 1440):
        p.call("Emulation.setDeviceMetricsOverride", width=w, height=900, deviceScaleFactor=1, mobile=False)
        goto(p, "index.html", 0.3)
        if p.js("getComputedStyle(document.getElementById('btnMenu')).display !== 'none'"):
            off.append(f"{w}: compact (Menu) instead of the bar")
            continue
        for g in ("explore", "educators", "help"):
            p.js(f"document.querySelector('.nav-group[data-group={g}] .nav-group-btn').click()")
            time.sleep(0.3)
            r = p.js(f"(function(){{var r=document.getElementById('nav-{g}').getBoundingClientRect();return [r.left,r.right,document.documentElement.clientWidth,document.documentElement.scrollWidth];}})()")
            if r[0] < 0 or r[1] > r[2] or r[3] > r[2]:
                off.append(f"{w} {g}: {r}")
            p.js("document.body.click()")
    check("open panels stay inside the window (1024, 1280, 1440 px), the bar fits", not off, off)

    # ---- Phone: the Menu sheet ----
    p.call("Emulation.setDeviceMetricsOverride", width=390, height=844, deviceScaleFactor=1, mobile=True)
    goto(p, "faq.html")
    p.js("document.getElementById('btnMenu').click()")
    time.sleep(0.3)
    r = p.js("""(function(){var n=document.getElementById('siteNav');
      var vis=[...n.querySelectorAll('a')].filter(a=>a.getClientRects().length && getComputedStyle(a).visibility!=='hidden').map(a=>a.getAttribute('href'));
      return {open:n.classList.contains('open'), n:new Set(vis.map(h=>h.split('#')[0])).size, focus:document.activeElement.getAttribute('href'),
              sw:document.documentElement.scrollWidth, cw:document.documentElement.clientWidth};})()""")
    check("phone: Menu opens a sheet listing every page, focus on the current one",
          r["open"] and r["n"] == len(pages) and r["focus"] == "faq.html" and r["sw"] <= r["cw"], r)
    press(p, ESC)
    check("phone: Escape closes the sheet, focus back on Menu",
          p.js("!document.getElementById('siteNav').classList.contains('open') && document.activeElement.id === 'btnMenu'"))

    # ---- Theme ----
    p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)
    goto(p, "index.html")
    p.js("document.getElementById('btnA11y').click(); document.querySelector('[data-theme-pick=dark]').click()")
    dark_bg = p.js("getComputedStyle(document.body).backgroundColor")
    check("Dark theme applies at once", p.js("document.documentElement.classList.contains('theme-dark')") and dark_bg == "rgb(17, 14, 34)", dark_bg)
    goto(p, "about.html")
    check("the theme follows to the next page before it is drawn",
          p.js("document.documentElement.classList.contains('theme-dark') && document.querySelector('[data-theme-pick=dark]').getAttribute('aria-pressed') === 'true'"))
    p.js("document.getElementById('btnHC').click()")
    check("high contrast wins over the dark theme", p.js("getComputedStyle(document.body).backgroundColor") == "rgb(255, 255, 255)")
    p.js("document.getElementById('btnA11yReset').click()")
    check("Reset returns to Auto (the device's setting)",
          p.js("!document.documentElement.classList.contains('theme-dark') && !document.documentElement.classList.contains('hc')"
               " && document.querySelector('[data-theme-pick=\"\"]').getAttribute('aria-pressed') === 'true'"))

    # ---- Arrival animation ----
    goto(p, "index.html")
    check("robots (this headless browser) never get the arrival animation",
          p.js("!document.documentElement.classList.contains('reveal-on') && !document.querySelector('.reveal')"))
    ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
    p.call("Emulation.setUserAgentOverride", userAgent=ua)
    p.call("Page.addScriptToEvaluateOnNewDocument", source="Object.defineProperty(navigator, 'webdriver', {get: () => false})")
    goto(p, "index.html", 0.6)
    r = p.js("""(function(){var vh=innerHeight,held=[...document.querySelectorAll('.reveal')];
      var onScreenHidden=held.filter(e=>{var b=e.getBoundingClientRect();return b.top<vh*0.9&&b.bottom>0&&!e.classList.contains('is-in');}).length;
      return {on:document.documentElement.classList.contains('reveal-on'), held:held.length, onScreenHidden:onScreenHidden};})()""")
    check("a visitor's browser: sections below the fold wait, nothing on screen is hidden",
          r["on"] and r["held"] > 5 and r["onScreenHidden"] == 0, r)
    for y in range(0, 12000, 500):
        p.js(f"window.scrollTo({{top:{y}, behavior:'instant'}})")
        time.sleep(0.12)
    time.sleep(0.9)
    r = p.js("[...document.querySelectorAll('.reveal')].filter(e=>!e.classList.contains('is-in') || getComputedStyle(e).opacity !== '1').length")
    check("…and once scrolled to, every one of them is fully visible", r == 0, r)
    p.call("Emulation.setEmulatedMedia", features=[{"name": "prefers-reduced-motion", "value": "reduce"}])
    goto(p, "index.html", 0.4)
    check("reduced motion: no arrival animation at all", p.js("!document.documentElement.classList.contains('reveal-on') && !document.querySelector('.reveal')"))
    p.call("Emulation.setEmulatedMedia", features=[])


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
