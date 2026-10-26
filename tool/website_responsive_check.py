"""Every page of website/ at phone-to-desktop widths, in both languages, with the
largest text and the reading aids, in headless Chrome.

    python tool/website_responsive_check.py

Fails a page when it scrolls sideways, when the header's controls spill past
the screen edge, or when a script error is logged. Serves website/ itself on
127.0.0.1:8899; no emulator needed (a local copy never counts visits).
"""
import json, os, shutil, subprocess, sys, tempfile, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (its Chrome client and server)

# 430 and 600 sit between the header's 420 px phone breakpoint and the width it needs
# with its labels (large phones, a phone set to a small display size, the largest text);
# 900 is a phone turned sideways, just past the 820 px two-column video layout.
WIDTHS = (320, 360, 414, 430, 600, 768, 900, 1280)
MODES = {
    "EN": ({}, []),
    "FIL A++": ({"fil": True, "font": "xl"}, []),
    "A++ dyslexia high-contrast": ({"font": "xl", "dys": True, "hc": True}, []),
    "FIL dark reduced-motion": ({"fil": True}, [{"name": "prefers-color-scheme", "value": "dark"},
                                                {"name": "prefers-reduced-motion", "value": "reduce"}]),
}
PROBE = """(function(){
  var W = document.documentElement.clientWidth, t = document.querySelector('.header-tools');
  var r = t ? t.getBoundingClientRect() : null;
  return { sw: document.documentElement.scrollWidth, W: W,
           header: r && r.width ? Math.round(r.right) : 0,
           stars: [...new Set([...document.querySelectorAll('.stars label')].map(l => Math.round(l.getBoundingClientRect().top)))].length };
})()"""


def main():
    pages = sorted(f for f in os.listdir(os.path.join(h.ROOT, "website")) if f.endswith(".html"))
    h.serve(8899, os.path.join(h.ROOT, "website"), h.Quiet)
    profile = tempfile.mkdtemp(prefix="flsweep-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9338", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "--mute-audio", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    problems, loads = [], 0
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9338/json/list"))
                                      if t["type"] == "page"), None) if h._up(9338) else None, 20)
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        for mode, (prefs, media) in MODES.items():
            p.call("Emulation.setEmulatedMedia", features=media)
            p.goto(f"{h.SITE}/index.html")
            p.js("localStorage.setItem('flp-a11y', %s)" % json.dumps(json.dumps(prefs)))
            for w in WIDTHS:
                p.call("Emulation.setDeviceMetricsOverride", width=w, height=800, deviceScaleFactor=1, mobile=w < 600)
                for page in pages:
                    p.errors.clear()
                    p.goto(f"{h.SITE}/{page}")
                    time.sleep(0.15)
                    m = p.js(PROBE)
                    loads += 1
                    where = f"{page} @ {w}px, {mode}"
                    if m["sw"] > m["W"]:
                        problems.append(f"{where}: scrolls sideways ({m['sw']} > {m['W']})")
                    if m["header"] > m["W"]:
                        problems.append(f"{where}: header controls end at {m['header']} px")
                    if m["stars"] > 1:
                        problems.append(f"{where}: the rating stars wrap onto {m['stars']} lines")
                    problems += [f"{where}: {e}" for e in p.errors]
        print(f"{loads} page loads: {len(pages)} pages x {len(WIDTHS)} widths x {len(MODES)} modes")
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    for x in problems:
        print("FAIL", x)
    print("PASS no sideways scrolling, header overflow or script errors" if not problems else f"{len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
