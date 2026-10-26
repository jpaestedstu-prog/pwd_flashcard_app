"""Accessibility audit of every page of website/ with axe-core (WCAG 2.2 A/AA rules
and axe's best practices), in headless Chrome.

    python tool/website_a11y_check.py

Each page is checked twice: English on a computer screen, and Filipino with the
largest text in dark mode on a 360 px phone. axe-core (pinned) is fetched from
cdnjs once per PC and run in the page through DevTools; nothing is added to
the site. Fails on any violation.
"""
import json, os, shutil, subprocess, sys, tempfile, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402

TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"]
SETUPS = {
    "EN, 1280 px": ({}, 1280, []),
    "FIL A++, dark, 360 px": ({"fil": True, "font": "xl"}, 360, [{"name": "prefers-color-scheme", "value": "dark"}]),
}


def audit(p, source, label):
    """Run axe in the current page; returns one line per violation."""
    if not p.js("typeof axe !== 'undefined'"):
        p.call("Runtime.evaluate", expression=source)
    found = p.js("axe.run(document, {runOnly: {type: 'tag', values: %s}, resultTypes: ['violations']})"
                 ".then(r => r.violations.map(v => v.impact + ' ' + v.id + ': ' + v.help + ' — ' +"
                 " v.nodes.slice(0, 3).map(n => n.target.join(' ')).join(' | ') + (v.nodes.length > 3 ? ' (+' + (v.nodes.length - 3) + ')' : '')))"
                 % json.dumps(TAGS))
    return [f"{label}: {v}" for v in found]


def main():
    source = h.axe_source()
    pages = sorted(f for f in os.listdir(os.path.join(h.ROOT, "website")) if f.endswith(".html"))
    h.serve(8899, os.path.join(h.ROOT, "website"), h.Quiet)
    profile = tempfile.mkdtemp(prefix="fla11y-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9340", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "--mute-audio", "about:blank"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    problems, runs = [], 0
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9340/json/list"))
                                      if t["type"] == "page"), None) if h._up(9340) else None, 20)
        p = h.Page(ws)
        p.call("Page.enable")
        p.call("Runtime.enable")
        for name, (prefs, width, media) in SETUPS.items():
            p.call("Emulation.setEmulatedMedia", features=media)
            p.call("Emulation.setDeviceMetricsOverride", width=width, height=900, deviceScaleFactor=1, mobile=width < 600)
            p.goto(f"{h.SITE}/index.html")
            p.js("localStorage.setItem('flp-a11y', %s)" % json.dumps(json.dumps(prefs)))
            for page in pages:
                p.goto(f"{h.SITE}/{page}")
                problems += audit(p, source, f"{page} ({name})")
                runs += 1
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    for x in problems:
        print("FAIL", x)
    print(f"{runs} audits ({len(pages)} pages x {len(SETUPS)} setups): " + ("PASS no violations" if not problems else f"{len(problems)} violations"))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
