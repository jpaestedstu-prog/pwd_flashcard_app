"""Features in Action (website/features.html) and the regrouped Help & Guides, in headless Chrome.

    python tool/website_features_check.py [--port 8897]

Checks, on the real pages (website/ served locally; nothing is counted):
  * Features in Action: 20 cards in 5 groups; every card has its icon, name, what it does,
    who it helps, a "Helps:" (or "For:") line, a closed "See it in action" and a link to
    its guide that lands on a real guide or guide section;
  * the "Who is it for?" filter: one need, two needs (either), the count in words (EN and
    FIL), the pressed states, groups with nothing left disappear, Show all and All reset,
    ?for= from a link, and a link to one card always shows it;
  * See it in action: nothing loads until opened; a video starts only when Play is pressed,
    is a part (#t=start,end) of the one file, has English and Filipino captions, and stops at
    the end of its part; pictures load when opened and enlarge on a click;
  * without JavaScript: every card shows, the filter is gone, and the video opens as a file;
  * Filipino; a 360 px phone (normal and largest text) never scrolls sideways;
  * Help & Guides: the five groups, every guide and guide section reachable by its address
    (a section link opens its guide there), "Back to all guides" on every guide, and the
    same demo as the card;
  * Home, the Teacher's Guide, the FAQ and the Gaze Control page link to guides and cards
    that exist; the Gaze Control page's steps are the app guide's own.
Fails on any script error.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.request
from html.parser import HTMLParser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (its Chrome client and server)

ap = argparse.ArgumentParser()
ap.add_argument("--port", type=int, default=8897)
args = ap.parse_args()
SITE = f"http://127.0.0.1:{args.port}"
WEB = os.path.join(h.ROOT, "website")
results = []


def check(label, ok, detail=""):
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + label + ("" if ok or not detail else f"  [{detail}]"), flush=True)


class Ids(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.hrefs = set(), []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if tag == "a" and a.get("href"):
            self.hrefs.append(a["href"])


def parse(name):
    x = Ids()
    x.feed(open(os.path.join(WEB, name), encoding="utf-8").read())
    return x


def dead_links(page):
    """Links from `page` to another page's #part (or its own) that do not exist."""
    bad = []
    for href in parse(page).hrefs:
        # app/ is the web app, built into the folder only when the site is published.
        if href.startswith(("http", "mailto:", "tel:", "app/")):
            continue
        path, _, frag = href.partition("#")
        path = path.split("?")[0] or page
        if not os.path.exists(os.path.join(WEB, path)):
            bad.append(href)
        elif frag and path.endswith(".html") and frag not in parse(path).ids:
            bad.append(href)
    return bad


class Ranges(h.Quiet):
    """Answers byte ranges (206), as GitHub Pages does: a video can only seek on a server that
    does. Python's own file server answers the whole file every time."""

    def send_head(self):
        rng = self.headers.get("Range")
        path = self.translate_path(self.path)
        if not rng or not os.path.isfile(path):
            return super().send_head()
        m = re.match(r"bytes=(\d*)-(\d*)$", rng.strip())
        size = os.path.getsize(path)
        if not m:
            return super().send_head()
        a = int(m.group(1)) if m.group(1) else max(0, size - int(m.group(2) or 0))
        b = int(m.group(2)) if m.group(1) and m.group(2) else size - 1
        b = min(b, size - 1)
        f = open(path, "rb")
        f.seek(a)
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {a}-{b}/{size}")
        self.send_header("Content-Length", str(b - a + 1))
        self.end_headers()
        self._left = b - a + 1
        return f

    def copyfile(self, source, outputfile):
        left = getattr(self, "_left", None)
        if left is None:
            return super().copyfile(source, outputfile)
        while left > 0:
            chunk = source.read(min(65536, left))
            if not chunk:
                break
            outputfile.write(chunk)
            left -= len(chunk)
        self._left = None


def main():
    h.serve(args.port, WEB, Ranges)
    profile = tempfile.mkdtemp(prefix="flfeat-")
    chrome = subprocess.Popen([h.CHROME, "--headless=new", "--remote-debugging-port=9346", f"--user-data-dir={profile}",
                               "--no-first-run", "--hide-scrollbars", "--mute-audio", "--autoplay-policy=no-user-gesture-required",
                               "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = h.wait_for(lambda: next((t["webSocketDebuggerUrl"] for t in json.load(urllib.request.urlopen("http://127.0.0.1:9346/json/list"))
                                      if t["type"] == "page"), None) if h._up(9346) else None, 20)
        p = h.Page(ws)
        for d in ("Page.enable", "Runtime.enable", "Log.enable"):
            p.call(d)
        p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)
        p.goto(f"{SITE}/index.html")
        p.js("localStorage.removeItem('flp-a11y')")
        static_links()
        features(p)
        guides(p)
        other_pages(p)
        check("no script errors", not p.errors, p.errors[:4])
    finally:
        chrome.kill()
        chrome.wait()
        shutil.rmtree(profile, ignore_errors=True)
    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)


def static_links():
    pages = sorted(f for f in os.listdir(WEB) if f.endswith(".html"))
    bad = {page: dead_links(page) for page in pages}
    bad = {k: v[:4] for k, v in bad.items() if v}
    check(f"all {len(pages)} pages: every link to a page, or to a part of one, lands somewhere real", not bad, bad)


def features(p):
    p.goto(f"{SITE}/features.html")
    time.sleep(0.6)
    r = p.js("""(function(){
      var cards = [...document.querySelectorAll('article.feat')];
      var bad = cards.filter(c => !(c.querySelector('.feat-ico') && c.querySelector('h3') && c.querySelector('.feat-what')
          && c.querySelector('.feat-facts dt') && c.querySelector('.feat-tags li') && c.querySelector('details.demo:not([open]) > summary')
          && c.querySelector('a.feat-guide'))).map(c => c.id);
      var names = cards.map(c => c.querySelector('a.feat-guide').textContent.trim());
      return {n: cards.length, groups: [...document.querySelectorAll('section.feat-group')].map(g => g.id + ':' + g.querySelectorAll('article.feat').length),
              bad: bad, unique: new Set(names).size, h1: document.querySelector('h1 .en').textContent,
              crumbs: [...document.querySelectorAll('.crumbs li')].map(l => l.innerText.trim()),
              cur: document.querySelector('#siteNav a[aria-current=page]')?.getAttribute('href'),
              status: document.getElementById('featStatus').innerText.trim(),
              videos: document.querySelectorAll('video').length,
              loaded: [...document.querySelectorAll('.demo img')].filter(i => i.complete && i.naturalWidth > 0).length};
    })()""")
    check("20 cards in 5 groups (4 each), all closed at first", r["n"] == 20 and r["groups"] == [
        "grp-control:4", "grp-seehear:4", "grp-pace:4", "grp-adults:4", "grp-learn:4"], r["groups"])
    check("every card: icon, name, what it does, who it helps, Helps/For, See it in action, guide link", not r["bad"], r["bad"])
    check("every guide link has its own accessible name (no twenty identical links)", r["unique"] == 20, r["unique"])
    check("the page: Features in Action, under Explore, marked as the current page",
          r["h1"] == "Features in Action" and r["crumbs"][:3] == ["Home", "Explore", "Features in Action"] and r["cur"] == "features.html", r)
    check("nothing loads before it is asked for: no video, no demo picture", r["videos"] == 0 and r["loaded"] == 0, r)
    check("the count starts at all 20", r["status"] == "Showing all 20 features.", r["status"])

    # ---- the filter ----
    want = "(function(n){return [...document.querySelectorAll('article.feat')].filter(c=>c.dataset.needs.split(' ').indexOf(n)!==-1).length;})"
    p.js("document.querySelector('.feat-chip[data-need=hearing]').click()")
    s = p.js("""({shown:[...document.querySelectorAll('article.feat')].filter(c=>!c.hidden).length,
                 status:document.getElementById('featStatus').innerText.trim(),
                 pressed:[...document.querySelectorAll('.feat-chip')].filter(b=>b.getAttribute('aria-pressed')==='true').map(b=>b.dataset.need),
                 hiddenGroups:[...document.querySelectorAll('section.feat-group')].filter(g=>g.hidden).map(g=>g.id),
                 reset:!document.getElementById('featReset').hidden, url:location.search,
                 live:document.getElementById('featStatus').getAttribute('role')})""")
    nh = p.js(want + "('hearing')")
    check("Hearing: only the cards that help hearing stay; the count says so in words",
          s["shown"] == nh and s["status"] == f"Showing {nh} of 20 features: the ones that help Hearing.", s)
    check("Hearing is pressed and All is not; a group with nothing left disappears; Show all appears",
          s["pressed"] == ["hearing"] and "grp-control" in s["hiddenGroups"] and s["reset"], s)
    check("the count is a polite status message (screen readers hear it)", s["live"] == "status")
    check("the choice is kept in the address (?for=hearing)", s["url"] == "?for=hearing", s["url"])
    p.js("document.querySelector('.feat-chip[data-need=motor]').click()")
    both = p.js("[...document.querySelectorAll('article.feat')].filter(c=>c.dataset.needs.split(' ').some(n=>n==='hearing'||n==='motor')).length")
    s = p.js("({shown:[...document.querySelectorAll('article.feat')].filter(c=>!c.hidden).length, status:document.getElementById('featStatus').innerText.trim()})")
    check("two needs: the cards that help either one (union)",
          s["shown"] == both and s["status"] == f"Showing {both} of 20 features: the ones that help Hearing or Motor.", s)
    p.js("document.getElementById('btnLangFil').click()")
    time.sleep(0.2)
    p.js("document.querySelector('.feat-chip[data-need=motor]').click(); document.querySelector('.feat-chip[data-need=motor]').click()")
    s = p.js("document.getElementById('featStatus').innerText.trim()")
    check("in Filipino, the count is in Filipino", s == f"Ipinapakita ang {both} sa 20 feature: ang mga nakakatulong sa Pandinig o Paggalaw.", s)
    p.js("document.getElementById('btnLangEn').click()")
    p.js("document.getElementById('featReset').click()")
    s = p.js("({shown:[...document.querySelectorAll('article.feat')].filter(c=>!c.hidden).length, all:document.querySelector('.feat-chip[data-need=\"\"]').getAttribute('aria-pressed'), focus:document.activeElement.dataset.need, url:location.search})")
    check("Show all features: every card back, All pressed, focus on All, address cleared",
          s["shown"] == 20 and s["all"] == "true" and s["focus"] == "" and s["url"] == "", s)
    p.js("document.querySelector('.feat-chip[data-need=visual]').click(); document.querySelector('.feat-chip[data-need=\"\"]').click()")
    check("All clears every need", p.js("[...document.querySelectorAll('article.feat')].every(c=>!c.hidden)"))
    p.goto(f"{SITE}/features.html?for=cognitive")
    time.sleep(0.4)
    s = p.js("({shown:[...document.querySelectorAll('article.feat')].filter(c=>!c.hidden).length, pressed:document.querySelector('.feat-chip[data-need=cognitive]').getAttribute('aria-pressed')})")
    check("a link with ?for=cognitive (from Home's presets) opens with that need chosen",
          s["shown"] == p.js(want + "('cognitive')") and s["pressed"] == "true", s)
    p.goto(f"{SITE}/features.html?for=hearing&x=1#f-gaze")
    time.sleep(0.5)
    s = p.js("({hidden:document.getElementById('f-gaze').hidden, top:Math.round(document.getElementById('f-gaze').getBoundingClientRect().top)})")
    check("a link to one card always shows it, even when the chosen need would hide it", not s["hidden"] and 0 <= s["top"] < 300, s)

    # ---- See it in action ----
    p.goto(f"{SITE}/features.html?r=demo")
    time.sleep(0.4)
    p.js("var d=document.getElementById('demo-f-gaze'); d.open=true; d.scrollIntoView({block:'center', behavior:'instant'});")
    time.sleep(1.5)
    s = p.js("""(function(){var d=document.getElementById('demo-f-gaze');return {video:!!d.querySelector('video'),
              poster:[...d.querySelectorAll('.demo-play img')].every(i=>i.complete&&i.naturalWidth>0),
              summary:d.querySelector('summary').innerText.replace(/\\s+/g,' ').trim()};})()""")
    check("opening a demo shows the poster and words, and starts nothing", not s["video"] and s["poster"], s)
    p.js("document.querySelector('#demo-f-gaze .demo-play').click()")
    time.sleep(2.5)
    s = p.js("""(function(){var v=document.querySelector('#demo-f-gaze video');if(!v)return null;
      return {src:v.getAttribute('src'), t:v.currentTime, paused:v.paused, tracks:[...v.querySelectorAll('track')].map(t=>t.srclang),
              label:v.getAttribute('aria-label'), focus:document.activeElement===v, err:v.error&&v.error.code};})()""")
    check("Play makes the video: a part (#t=0,23.9) of the one gaze video file, playing, focused",
          s and s["src"] == "assets/videos/gaze-demo.mp4#t=0,23.9" and not s["err"] and s["t"] > 0 and s["focus"], s)
    check("…with English and Filipino captions, and a name for screen readers",
          s and s["tracks"] == ["en", "fil"] and s["label"] == "Video: Gaze Control", s)
    p.js("var v=document.querySelector('#demo-f-gaze video'); v.currentTime=23.4; v.play();")
    time.sleep(1.6)
    s = p.js("(function(){var v=document.querySelector('#demo-f-gaze video');return {t:v.currentTime, paused:v.paused};})()")
    check("it stops at the end of its part (23.9 s), not at the end of the video", s["paused"] and 23.0 < s["t"] < 25.0, s)
    p.js("document.getElementById('demo-f-gaze').open=false")
    time.sleep(0.2)
    check("closing the demo pauses the video", p.js("document.querySelector('#demo-f-gaze video').paused"))
    p.js("var d=document.getElementById('demo-f-display'); d.open=true; d.scrollIntoView({block:'start', behavior:'instant'});")
    time.sleep(1.5)
    s = p.js("""(function(){var imgs=[...document.querySelectorAll('#demo-f-display img')];
      return {n:imgs.length, ok:imgs.filter(i=>i.complete&&i.naturalWidth>0).length, alts:imgs.every(i=>i.alt.length>30&&i.dataset.labelFil.length>30),
              caps:[...document.querySelectorAll('#demo-f-display figcaption .en')].map(c=>c.textContent)};})()""")
    check("the before-and-after pictures load when opened, each with a description in both languages",
          s["n"] == 4 and s["ok"] == 4 and s["alts"], s)
    check("…and say which look each one is", s["caps"] == ["Normal", "Bigger text + high contrast", "Dark mode", "Dyslexia-friendly"], s["caps"])
    p.js("document.querySelector('#demo-f-display img').click()")
    time.sleep(0.4)
    s = p.js("(function(){var d=document.querySelector('dialog.lightbox');return d&&{open:d.open, src:d.querySelector('img').getAttribute('src'), alt:d.querySelector('img').alt};})()")
    check("a picture enlarges in a dialog, keeping its description", s and s["open"] and s["src"].endswith("look-normal.webp") and len(s["alt"]) > 30, s)
    p.js("document.querySelector('dialog.lightbox').close()")
    s = p.js("(function(){var d=document.getElementById('demo-f-screenreader');return {kind:d.querySelector('.demo-kind .en').textContent, words:d.querySelector('.demo-what .en').textContent.slice(0,60)};})()")
    check("TalkBack is described in words, not shown", s["kind"] == "Described in words" and s["words"].startswith("TalkBack is heard, not seen"), s)

    # ---- Filipino ----
    p.js("document.getElementById('btnLangFil').click()")
    time.sleep(0.3)
    s = p.js("({h1:document.querySelector('h1').innerText.trim(), title:document.title, lang:document.documentElement.lang, chip:document.querySelector('.feat-chip[data-need=visual]').innerText.replace(/\\s+/g,' ').trim(), guide:document.querySelector('#f-voice a.feat-guide').innerText.replace(/\\s+/g,' ').trim()})")
    check("Filipino: the page, the filter and the cards switch", s["h1"] == "Tingnan ang mga Feature" and s["lang"] == "fil"
          and s["title"].startswith("Tingnan ang mga Feature") and s["chip"].startswith("👁️ Paningin") and "Gabay" in s["guide"], s)
    p.js("document.getElementById('btnLangEn').click()")

    # ---- Phone, normal and largest text ----
    p.call("Emulation.setDeviceMetricsOverride", width=360, height=780, deviceScaleFactor=1, mobile=True)
    wide = []
    for font in ("", "xl"):
        p.goto(f"{SITE}/features.html?r=phone{font}")
        p.js(f"localStorage.setItem('flp-a11y', JSON.stringify({{font:'{font}'}}))")
        p.goto(f"{SITE}/features.html?r=phone{font}b")
        time.sleep(0.5)
        p.js("document.querySelectorAll('details.demo').forEach(d=>d.open=true)")
        time.sleep(0.4)
        r = p.js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
        if r[0] > r[1]:
            wide.append((font or "normal", r))
    p.js("localStorage.removeItem('flp-a11y')")
    check("a 360 px phone, normal and largest text, every demo open: no sideways scrolling", not wide, wide)
    p.call("Emulation.setDeviceMetricsOverride", width=1280, height=900, deviceScaleFactor=1, mobile=False)

    # ---- Without JavaScript ----
    p.call("Emulation.setScriptExecutionDisabled", value=True)
    p.goto(f"{SITE}/features.html?r=nojs")
    time.sleep(0.5)
    s = p.js("""(function(){var vis=e=>!!e&&getComputedStyle(e).display!=='none';
      return {cards:[...document.querySelectorAll('article.feat')].filter(vis).length, chips:vis(document.querySelector('.feat-chips')),
              note:vis(document.querySelector('.feat-filter .nojs-only')), file:vis(document.querySelector('#demo-f-gaze .demo-file')),
              play:vis(document.querySelector('#demo-f-gaze .demo-play'))};})()""")
    p.call("Emulation.setScriptExecutionDisabled", value=False)
    check("without JavaScript: all 20 cards, no filter buttons (a note instead), the video opens as a file",
          s["cards"] == 20 and not s["chips"] and s["note"] and s["file"] and not s["play"], s)


def guides(p):
    p.goto(f"{SITE}/guides.html?r=g")
    time.sleep(0.5)
    r = p.js("""({index:[...document.querySelectorAll('.guide-group')].map(g=>g.querySelector('h3').id+':'+[...g.querySelectorAll('.guide-card')].map(a=>a.dataset.guide).join(',')),
                list:[...document.querySelectorAll('h3.guide-list-title')].map(x=>x.id),
                back:[...document.querySelectorAll('details.guide .guide-back a[href="#find"]')].length,
                guides:document.querySelectorAll('details.guide').length})""")
    check("Help & Guides: the five groups, with the right guides", r["index"] == [
        "gg-learners:students", "gg-educators:teachers,parents,timeBreaks,tvCast", "gg-control:gaze,voice,controller,keyboard",
        "gg-seehear:accessibility,screenReader", "gg-feedback:feedback"], r["index"])
    check("all 12 guides are there, listed under the same five group headings", r["guides"] == 12 and r["list"] == [
        "gl-learners", "gl-educators", "gl-control", "gl-seehear", "gl-feedback"], r)
    check("every guide ends with Back to all guides", r["back"] == 12, r["back"])
    p.goto(f"{SITE}/guides.html?r=s#g-accessibility-hear-the-words")
    time.sleep(0.8)
    s = p.js("({open:document.getElementById('g-accessibility').open, others:[...document.querySelectorAll('details.guide')].filter(d=>d.open).length, focus:document.activeElement.id, top:Math.round(document.getElementById('g-accessibility-hear-the-words').getBoundingClientRect().top)})")
    check("a link to a guide section opens that guide there, and focuses the section",
          s["open"] and s["others"] == 1 and s["focus"] == "g-accessibility-hear-the-words-h" and 40 <= s["top"] <= 160, s)
    p.js("document.querySelector('#g-accessibility .guide-back a').click()")
    time.sleep(0.6)
    check("Back to all guides goes back to the list", p.js("location.hash") == "#find" and p.js("Math.round(document.getElementById('find').getBoundingClientRect().top)") < 160)
    p.goto(f"{SITE}/guides.html?r=e#gg-educators")
    time.sleep(0.6)
    s = p.js("({top:Math.round(document.getElementById('gg-educators').getBoundingClientRect().top), cards:[...document.getElementById('gg-educators').closest('.guide-group').querySelectorAll('.guide-card')].length})")
    check("Guides for Parents & Teachers (#gg-educators) lands on the adults' four guides", 40 <= s["top"] <= 200 and s["cards"] == 4, s)
    s = p.js("({g:document.querySelector('#demo-g-gaze .demo-clip').dataset.src, start:document.querySelector('#demo-g-gaze .demo-clip').dataset.start, end:document.querySelector('#demo-g-gaze .demo-clip').dataset.end})")
    check("a guide shows the same demo as its card (same file, same part)", s == {"g": "assets/videos/gaze-demo.mp4", "start": "0", "end": "23.9"}, s)


def other_pages(p):
    p.goto(f"{SITE}/index.html?r=h")
    time.sleep(0.4)
    s = p.js("""({cards:[...document.querySelectorAll('a[href^="features.html#f-"]')].length,
                presets:[...document.querySelectorAll('a[href^="features.html?for="]')].map(a=>a.getAttribute('href')),
                tile:!!document.querySelector('#start a[href="features.html"]'),
                tour:[...document.querySelectorAll('#start .go .en')].map(e=>e.textContent).includes('App Tour')})""")
    check("Home: its features and presets link into Features in Action", s["cards"] >= 10 and s["presets"] == [
        "features.html?for=visual#who", "features.html?for=hearing#who", "features.html?for=motor#who", "features.html?for=cognitive#who"], s)
    check("Home: a Features in Action tile, and the tour is called App Tour", s["tile"] and s["tour"], s)
    p.goto(f"{SITE}/gaze-control.html?r=gz")
    time.sleep(0.4)
    s = p.js("({steps:[...document.querySelectorAll('ol.steps li .en')].map(l=>l.textContent), lead:[...document.querySelectorAll('.lead .en')].map(l=>l.textContent).join(' ')})")
    check("Gaze Control: its steps are the app guide's own (Turn it on)", s["steps"][:2] == [
        "Open Settings → Accessibility → Gaze Control (Preview).", "Turn on Enable Gaze Control. Allow the camera when asked."], s["steps"])
    check("Gaze Control: says Voice only works with the camera off", "Voice only" in s["lead"], s["lead"][:200])
    p.goto(f"{SITE}/how-to-use.html?r=t")
    time.sleep(0.3)
    s = p.js("({h1:document.querySelector('h1 .en').textContent, crumb:document.querySelector('.crumbs li[aria-current]').innerText.trim()})")
    check("the tour page is the App Tour (same address, how-to-use.html)", s["crumb"] == "App Tour" and "tour" in s["h1"].lower(), s)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
