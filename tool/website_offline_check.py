"""The website's offline copy (website/sw.js), in headless Chrome, with the server really gone.

    python tool/website_offline_check.py [--port 8883]

A first visit installs the service worker, which keeps every page and the shared files
(the precache list in sw.js, kept by tools/site_chrome_build.py). Then the local server
is SHUT DOWN, and the checks run with no network at all:
  * every page opens from the offline copy;
  * a page asked for with a query (features.html?for=visual, as Home's presets link)
    opens that page with the need chosen — not the home page;
  * a link to one guide (guides.html#g-voice) still opens that guide;
  * an unknown address falls back to the home page;
  * a picture already seen still shows; a video says it needs the internet, in words,
    instead of failing silently;
  * the worker's cache is the one sw.js names (an older one would have been deleted).
Fails on any script error.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (its Chrome client and server)

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8883)
args = ap.parse_args()
SITE = f"http://127.0.0.1:{args.port}"
WEB = os.path.join(h.ROOT, "website")
results = []


def check(label, ok, detail=""):
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + label + ("" if ok or not detail else f"  [{detail}]"), flush=True)


def main():
    sw = open(os.path.join(WEB, "sw.js"), encoding="utf-8").read()
    cache_name = re.search(r"const CACHE = '([^']+)'", sw).group(1)
    core = re.findall(r"^\s*'([^']+)',?$", sw.split("const CORE = [")[1].split("];")[0], re.M)
    pages = sorted(f for f in os.listdir(WEB) if f.endswith(".html"))
    srv = h.serve(args.port, WEB, h.Quiet)
    profile = tempfile.mkdtemp(prefix="floff-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9352", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "--mute-audio", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9352/json/list"))
                                      if t["type"] == "page"), None) if h._up(9352) else None, 20)
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)
        # ---- online: install, and see a few things once ----
        p.goto(f"{SITE}/index.html")
        ready = p.wait("navigator.serviceWorker && navigator.serviceWorker.ready.then(r => !!r.active)", 30)
        p.goto(f"{SITE}/index.html?second")
        controlled = p.wait("!!navigator.serviceWorker.controller", 15)
        n = p.wait(f"caches.open({json.dumps(cache_name)}).then(c => c.keys()).then(k => k.length >= {len(core)} ? k.length : 0)", 40)
        check("the worker installs, controls the page and keeps the whole precache list",
              ready and controlled and n, {"ready": ready, "controlled": controlled, "kept": n, "list": len(core)})
        names = p.js("caches.keys()")
        check("only the cache sw.js names is kept (older ones are deleted)", names == [cache_name], names)
        p.goto(f"{SITE}/features.html")
        p.js("var d=document.getElementById('demo-f-display'); d.open=true; d.scrollIntoView({block:'start', behavior:'instant'});")
        seen = p.wait("[...document.querySelectorAll('#demo-f-display img')].every(i => i.complete && i.naturalWidth > 0)", 15)
        check("(online) the before-and-after pictures are seen once", seen)
        time.sleep(1)
        # ---- the server goes away ----
        srv.shutdown()
        srv.server_close()
        gone = True
        try:
            urllib.request.urlopen(f"{SITE}/index.html", timeout=3)
            gone = False
        except Exception:
            pass
        check("the server is really gone", gone)
        bad = []
        for page in pages:
            p.goto(f"{SITE}/{page}")
            time.sleep(0.3)
            r = p.js("({path: location.pathname, h1: (document.querySelector('h1') || {}).textContent || '', css: getComputedStyle(document.body).fontFamily})")
            if not r["h1"].strip() or "Nunito" not in r["css"]:
                bad.append((page, r))
        check(f"offline: all {len(pages)} pages open from the offline copy, styled", not bad, bad[:3])
        p.goto(f"{SITE}/features.html?for=visual#who")
        time.sleep(0.5)
        r = p.js("({h1: document.querySelector('h1 .en').textContent, pressed: document.querySelector('.feat-chip[data-need=visual]').getAttribute('aria-pressed'), status: document.getElementById('featStatus').innerText.trim()})")
        check("offline: features.html?for=visual opens Features in Action with Visual chosen (not the home page)",
              r["h1"] == "Features in Action" and r["pressed"] == "true" and r["status"].startswith("Showing"), r)
        p.goto(f"{SITE}/guides.html#g-voice")
        time.sleep(0.6)
        check("offline: a link to one guide opens it", p.js("document.getElementById('g-voice').open"))
        p.goto(f"{SITE}/no-such-page.html")
        time.sleep(0.3)
        check("offline: an unknown address falls back to the home page", "Learning made" in (p.js("document.querySelector('h1').textContent") or ""))
        p.goto(f"{SITE}/features.html")
        p.js("var d=document.getElementById('demo-f-display'); d.open=true; d.scrollIntoView({block:'start', behavior:'instant'});")
        pics = p.wait("[...document.querySelectorAll('#demo-f-display img')].every(i => i.complete && i.naturalWidth > 0)", 10)
        check("offline: a picture already seen still shows", pics)
        p.js("var d=document.getElementById('demo-f-gaze'); d.open=true; d.scrollIntoView({block:'center', behavior:'instant'});")
        time.sleep(0.4)
        p.js("document.querySelector('#demo-f-gaze .demo-play').click()")
        note = p.wait("(function(){var n=document.querySelector('#demo-f-gaze .demo-note');return n && n.getAttribute('role')==='status' && n.innerText.trim();})()", 15)
        check("offline: a video says, in words, that it needs the internet", note and "internet" in note, note)
        errors = [e for e in p.errors if "Failed to load resource" not in e and "net::ERR" not in e]
        check("no script errors (a missing network is not one)", not errors, errors[:3])
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
