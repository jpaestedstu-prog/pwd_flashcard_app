"""Write the shared parts of every website page from one definition.

    python tools/site_chrome_build.py          # rewrite the pages
    python tools/site_chrome_build.py --check  # exit 1 if any page is stale

The website has no build step, and every page used to carry its own copy of
the header, navigation and footer. The copies drifted (three different navs
and three footers at one point, and a template that silently reverted a fix).
Now the shared parts live here and are written between markers:

  <!--gen:site-head-->    stylesheet, icons, the early preference script
  <!--gen:site-header-->  skip link, header, navigation, accessibility panel
  <!--gen:site-crumbs-->  "Home > Group > This page" and the page's 3D badge
  <!--gen:site-footer-->  footer + assets/site.js

The navigation is grouped (2026-11 redesign): Home, three groups that open a
panel (Explore, Teachers & Parents, Help) and two actions (Try It, Download).
Every one of the fourteen pages is reachable from the header on every page, and
the footer repeats the same three groups. Explore SHOWS what the app does (App Tour,
Features in Action, Gaze Control, Games, the FSL Dictionary); Help TEACHES it (Help &
Guides, where all the step-by-step guides live). Teachers & Parents links into the
adults' part of Help & Guides rather than copying it. No group holds more than five
links, and no link opens a second menu.

The generated pages are covered through their templates, so the next
games/dictionary build reproduces exactly what this script wrote.
Guards: every page must carry each marker exactly once (crumbs: none on Home),
and every page must be reachable from the navigation exactly once.

Cache busting: the site's service worker answers scripts and stylesheets from
its cache first, so after a deploy a returning visitor would get the new
pages with the OLD site.js (a dead menu button until they reload). Every
reference to assets/site.css, site.js and try.js therefore carries a
fingerprint of the file (?v=<hash>), and sw.js precaches exactly those URLs
under a cache name that includes them. A changed file means a new URL, which
no old cache can answer.
"""
import hashlib, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "website")

# file -> page key. Every page of the site must be listed (checked below).
PAGES = {
    "index.html": "home",
    "try.html": "try",
    "download.html": "download",
    "how-to-use.html": "how",
    "games.html": "games",
    "fsl-dictionary.html": "dictionary",
    "teachers-guide.html": "guide",
    "faq.html": "faq",
    "awareness.html": "awareness",
    "about.html": "about",
    "privacy.html": "privacy",
    "gaze-control.html": "gaze",
    "guides.html": "guides",
    "features.html": "features",
}
TEMPLATES = {
    os.path.join("tools", "games_page.template.html"): "games",
    os.path.join("tools", "fsl_dict_page.template.html"): "dictionary",
    os.path.join("tools", "guides_page.template.html"): "guides",
    os.path.join("tools", "features_page.template.html"): "features",
}

# One destination: key, href, EN, FIL, icon, hint EN, hint FIL, tone.
# The tone is one of the tile tones in site.css (.tone-*): it colours the
# destination's icon in the menus and its page's 3D badge.
HOME = ("home", "index.html", "Home", "Home", "🏠", "Start here", "Dito magsimula", "purple")
GROUPS = [
    ("explore", "Explore", "Tuklasin", "The app, up close", "Ang app, malapitan", [
        ("how", "how-to-use.html", "App Tour", "Tour ng App", "📖", "An 81-second video and a picture tour", "81 segundong video at tour na may larawan", "orange"),
        ("features", "features.html", "Features in Action", "Tingnan ang mga Feature", "✨", "See each feature work, and who it helps", "Tingnan ang bawat feature at kung sino ang natutulungan", "magenta"),
        ("gaze", "gaze-control.html", "Gaze Control", "Gaze Control", "👁️", "Use the app hands-free", "Gamitin ang app nang walang kamay", "blue"),
        ("games", "games.html", "Games", "Mga Laro", "🎮", "Every learning game in the app", "Bawat larong pampagkatuto sa app", "pink"),
        ("dictionary", "fsl-dictionary.html", "FSL Dictionary", "Diksyunaryo ng FSL", "🤟", "Watch everyday words signed", "Panoorin ang senyas ng mga salita", "teal"),
    ]),
    ("educators", "Teachers &amp; Parents", "Guro at Magulang", "For the adults beside a learner", "Para sa mga katuwang ng mag-aaral", [
        ("guide", "teachers-guide.html", "Teacher’s Guide", "Gabay ng Guro", "🧑‍🏫", "Set up a class, printable", "Pag-set up ng klase, napi-print", "indigo"),
        ("guidesadults", "guides.html#gg-educators", "Guides for Teachers &amp; Parents", "Mga Gabay para sa Guro at Magulang", "📘", "Set up and support learners, step by step", "Pag-set up at pagsuporta, hakbang-hakbang", "green"),
        ("awareness", "awareness.html", "PWD Awareness", "Kamalayang PWD", "💜", "Rights and everyday inclusion", "Mga karapatan at araw-araw na inklusyon", "green"),
        ("privacy", "privacy.html", "Privacy &amp; Data", "Privacy at Datos", "🔒", "What the app keeps, and who sees it", "Ano ang itinatago ng app, at sino ang nakakakita", "cyan"),
    ]),
    ("help", "Help", "Tulong", "Guides, questions, feedback and the team", "Mga gabay, tanong, feedback at ang pangkat", [
        ("guides", "guides.html", "Help &amp; Guides", "Tulong at mga Gabay", "📘", "Step-by-step guides for the app", "Mga gabay sa app, hakbang-hakbang", "green"),
        ("faq", "faq.html", "FAQ", "Mga Tanong", "❓", "Answers to common questions", "Mga sagot sa karaniwang tanong", "magenta"),
        ("feedback", "faq.html#feedback", "Rate &amp; Feedback", "Rating at Feedback", "⭐", "Tell the team what you think", "Sabihin sa pangkat ang iyong opinyon", "gold"),
        ("about", "about.html", "About the Team", "Tungkol sa Pangkat", "🎓", "The students behind the app", "Ang mga mag-aaral sa likod ng app", "red"),
        ("future", "about.html#future", "Future Recommendations", "Mga Rekomendasyon", "🔭", "Plans for later, like 3D signs", "Mga plano, gaya ng 3D na senyas", "teal"),
    ]),
]
# The two actions at the end of the bar (the class picks their look).
ACTIONS = [
    ("try", "try.html", "Try It", "Subukan", "🎴", "Flashcards and a game in your browser", "Flashcard at laro sa browser", "gold", "nav-btn-try"),
    ("download", "download.html", "Download", "I-download", "⬇️", "Free for Android 10 and newer", "Libre para sa Android 10 pataas", "purple", "nav-btn-dl"),
]
# Links that are not pages of their own (never marked as the current page).
NOT_PAGES = {"feedback", "future", "guidesadults"}

FOOTER_COLS = [
    ("Explore", "Tuklasin", "Explore the app", "🧭", [
        ("how-to-use.html", "App tour (video and pictures)", "Tour ng app (video at larawan)"),
        ("features.html", "Features in action", "Tingnan ang mga feature"),
        ("gaze-control.html", "Gaze Control (hands-free)", "Gaze Control (walang kamay)"),
        ("games.html", "Learning games", "Mga larong pampagkatuto"),
        ("fsl-dictionary.html", "FSL Sign Dictionary", "Diksyunaryo ng FSL"),
        ("try.html", "Try it in your browser", "Subukan sa browser"),
    ]),
    ("Teachers &amp; Parents", "Guro at Magulang", "For teachers and parents", "🏫", [
        ("teachers-guide.html", "Teacher’s Guide", "Gabay ng Guro"),
        ("guides.html#gg-educators", "Guides for teachers &amp; parents", "Mga gabay para sa guro at magulang"),
        ("awareness.html", "PWD Awareness", "Kamalayang PWD"),
        ("privacy.html", "Privacy &amp; data", "Privacy at datos"),
        ("download.html", "Download the app", "I-download ang app"),
    ]),
    ("Help", "Tulong", "Help and the project", "💬", [
        ("guides.html", "Help &amp; Guides (step by step)", "Tulong at mga Gabay (hakbang-hakbang)"),
        ("faq.html", "Questions (FAQ)", "Mga Tanong (FAQ)"),
        ("faq.html#feedback", "Rate the app or send feedback", "I-rate ang app o magpadala ng feedback"),
        ("about.html", "About the team", "Tungkol sa pangkat"),
        ("about.html#future", "Future recommendations", "Mga rekomendasyon sa hinaharap"),
    ]),
]


def bi(en, fil):
    return f'<span class="en">{en}</span><span class="fil">{fil}</span>'


VERSIONED = ("site.css", "site.js", "try.js")


def fingerprint(name):
    with open(os.path.join(SITE, "assets", name), "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:10]


V = {name: fingerprint(name) for name in VERSIONED}


def asset(name):
    return f"assets/{name}?v={V[name]}"


# Runs before the page is painted: marks JavaScript as available and applies
# the visitor's saved text size / dyslexia / contrast / motion / theme /
# language choices, so a Filipino reader never sees the English page flash
# first and a "Reduce motion" visitor never sees anything start moving. The
# larger text sizes (and Filipino on a narrower window) start with the compact
# header; site.js measures and corrects it.
EARLY_JS = (
    "<script>(function(h){h.classList.add('js');try{var p=JSON.parse(localStorage.getItem('flp-a11y')||'{}');"
    "if(p.font==='lg'||p.font==='xl')h.classList.add('fs-'+p.font);if(p.dys)h.classList.add('dys');"
    "if(p.hc)h.classList.add('hc');if(p.still)h.classList.add('still');"
    "if(p.theme==='dark'||p.theme==='light')h.classList.add('theme-'+p.theme);"
    "if(p.fil){h.classList.add('fil');h.setAttribute('lang','fil');}"
    "if(p.font==='lg'||p.font==='xl'||(p.fil&&window.innerWidth<1200))h.classList.add('nav-compact');}catch(e){}})"
    "(document.documentElement);</script>"
)


def render_head(key):
    return "\n".join([
        "",
        '<meta name="theme-color" content="#7E57C2">',
        '<link rel="manifest" href="manifest.webmanifest">',
        '<link rel="icon" type="image/png" sizes="192x192" href="assets/icon-192.png">',
        '<link rel="apple-touch-icon" href="assets/icon-192.png">',
        f'<link rel="stylesheet" href="{asset("site.css")}">',
        EARLY_JS,
        "",
    ])


MENU_SVG = (
    '<svg class="ico-open" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 7h16M4 12h16M4 17h16" '
    'stroke="currentColor" stroke-width="2.4" stroke-linecap="round" fill="none"/></svg>'
    '<svg class="ico-close" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M6 6l12 12M18 6L6 18" '
    'stroke="currentColor" stroke-width="2.4" stroke-linecap="round" fill="none"/></svg>'
)
CHEVRON = ('<svg class="chev" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M6 9l6 6 6-6" '
           'stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>')


def nav_txt(en, fil, sub_en, sub_fil):
    return (f'<span class="nav-txt"><span class="nav-main">{bi(en, fil)}</span>'
            f'<span class="nav-sub">{bi(sub_en, sub_fil)}</span></span>')


def current(k, key):
    return ' aria-current="page"' if k == key and k not in NOT_PAGES else ""


def render_header(key):
    I = "        "
    items = []
    k, href, en, fil, ico, sub_en, sub_fil, tone = HOME
    items.append(f'{I}<li class="nav-item"><a class="nav-link" href="{href}"{current(k, key)}>'
                 f'<span class="nav-ico tone-{tone}" aria-hidden="true">{ico}</span>{nav_txt(en, fil, sub_en, sub_fil)}</a></li>')
    for gk, gen, gfil, gsub_en, gsub_fil, links in GROUPS:
        here = any(lk == key and lk not in NOT_PAGES for lk, *_ in links)
        here_attr = ' aria-current="true"' if here else ""
        pid = "nav-" + gk
        subs = []
        for lk, lhref, len_, lfil, lico, lsub_en, lsub_fil, ltone in links:
            subs.append(f'{I}      <li><a href="{lhref}"{current(lk, key)}><span class="nav-ico tone-{ltone}" aria-hidden="true">{lico}</span>'
                        f'{nav_txt(len_, lfil, lsub_en, lsub_fil)}</a></li>')
        items.append(
            f'{I}<li class="nav-item nav-group" data-group="{gk}">\n'
            f'{I}  <button type="button" class="nav-link nav-group-btn" aria-expanded="false" aria-controls="{pid}"'
            f'{here_attr}><span class="nav-main">{bi(gen, gfil)}</span>{CHEVRON}</button>\n'
            f'{I}  <div class="nav-panel" id="{pid}">\n'
            f'{I}    <p class="nav-panel-title">{bi(gen, gfil)}<span class="sr-only"> — {bi(gsub_en, gsub_fil)}</span></p>\n'
            f'{I}    <ul class="nav-sublist">\n' + "\n".join(subs) + f'\n{I}    </ul>\n'
            f'{I}  </div>\n'
            f'{I}</li>')
    for n, (ak, ahref, en, fil, ico, sub_en, sub_fil, tone, cls) in enumerate(ACTIONS):
        first = " nav-cta-first" if n == 0 else ""
        items.append(f'{I}<li class="nav-item nav-cta{first}"><a class="nav-btn {cls}" href="{ahref}"{current(ak, key)}>'
                     f'<span aria-hidden="true">{ico}</span><span class="nav-main">{bi(en, fil)}</span></a></li>')
    sizes = [
        ("", "A", "Normal text size", "Karaniwang laki ng letra"),
        ("lg", "A+", "Large text", "Malaking letra"),
        ("xl", "A++", "Largest text", "Pinakamalaking letra"),
    ]
    seg = "\n".join(
        f'          <button type="button" data-font="{v}" aria-pressed="{"true" if not v else "false"}" '
        f'aria-label="{en}" data-label-en="{en}" data-label-fil="{fil}">{t}</button>'
        for v, t, en, fil in sizes)
    themes = [
        ("", "Auto", "Awto", "Follow this device", "Sundin ang device"),
        ("light", "Light", "Maliwanag", "Light theme", "Maliwanag na tema"),
        ("dark", "Dark", "Madilim", "Dark theme", "Madilim na tema"),
    ]
    tseg = "\n".join(
        f'          <button type="button" data-theme-pick="{v}" aria-pressed="{"true" if not v else "false"}">'
        f'{bi(en, fil)}<span class="sr-only"> — {bi(en_long, fil_long)}</span></button>'
        for v, en, fil, en_long, fil_long in themes)
    return f"""
<a class="skip" href="#main">{bi("Skip to main content", "Laktawan papunta sa nilalaman")}</a>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="index.html"><img class="brand-logo" src="assets/logo.webp" width="40" height="40" alt=""><span class="brand-name">FlashLearn <b>PWD</b></span></a>
    <nav class="site-nav" id="siteNav" aria-label="Main" data-label-en="Main" data-label-fil="Pangunahin">
      <ul class="nav-list">
{chr(10).join(items)}
      </ul>
    </nav>
    <div class="header-tools">
      <div class="lang-switch needs-js" role="group" aria-label="Language / Wika">
        <button type="button" id="btnLangEn" lang="en" aria-pressed="true" aria-label="English">EN</button>
        <button type="button" id="btnLangFil" lang="fil" aria-pressed="false" aria-label="Filipino">FIL</button>
      </div>
      <button type="button" class="tool-btn needs-js" id="btnA11y" aria-expanded="false" aria-controls="a11yPanel" aria-label="Accessibility settings" data-label-en="Accessibility settings" data-label-fil="Mga setting sa aksesibilidad" title="Accessibility / Aksesibilidad"><span class="aa" aria-hidden="true">Aa</span></button>
      <button type="button" class="tool-btn menu-btn needs-js" id="btnMenu" aria-expanded="false" aria-controls="siteNav">{MENU_SVG}<span class="tool-label">{bi("Menu", "Menu")}</span></button>
    </div>
  </div>
  <div class="a11y-panel" id="a11yPanel" role="group" aria-labelledby="a11yTitle" hidden>
    <p class="panel-title" id="a11yTitle">{bi("Accessibility", "Aksesibilidad")}</p>
    <div class="panel-row">
      <span class="row-label" id="a11ySizeLabel">{bi("Text size", "Laki ng letra")}</span>
      <div class="seg" role="group" aria-labelledby="a11ySizeLabel">
{seg}
      </div>
    </div>
    <div class="panel-row">
      <span class="row-label" id="a11yThemeLabel">{bi("Theme", "Tema")}</span>
      <div class="seg" role="group" aria-labelledby="a11yThemeLabel">
{tseg}
      </div>
    </div>
    <button type="button" class="switch" id="btnDys" role="switch" aria-checked="false"><span>{bi("Dyslexia-friendly font", "Font para sa may dyslexia")}</span><span class="track" aria-hidden="true"></span></button>
    <button type="button" class="switch" id="btnHC" role="switch" aria-checked="false"><span>{bi("High contrast", "Mataas na contrast")}</span><span class="track" aria-hidden="true"></span></button>
    <button type="button" class="switch" id="btnStill" role="switch" aria-checked="false"><span>{bi("Reduce motion", "Bawasan ang galaw")}</span><span class="track" aria-hidden="true"></span></button>
    <div class="panel-foot">
      <p class="panel-note">{bi("Saved on this device for every page.", "Naka-save sa device na ito para sa bawat pahina.")}</p>
      <button type="button" class="link-btn" id="btnA11yReset">{bi("Reset", "I-reset")}</button>
    </div>
  </div>
</header>
"""


def find(key):
    """(group or None, destination) for a page key."""
    if key == HOME[0]:
        return None, HOME
    for g in GROUPS:
        for d in g[5]:
            if d[0] == key:
                return g, d
    for a in ACTIONS:
        if a[0] == key:
            return None, a
    fail(f"page key {key!r} is in no navigation entry")


def render_crumbs(key):
    group, dest = find(key)
    en, fil, ico, tone = dest[2], dest[3], dest[4], dest[7]
    mid = f'<li>{bi(group[1], group[2])}</li>' if group else ""
    return (f'<nav class="crumbs" aria-label="Breadcrumb" data-label-en="Breadcrumb" data-label-fil="Kinaroroonan">'
            f'<ol><li><a href="index.html">{bi("Home", "Home")}</a></li>{mid}'
            f'<li aria-current="page">{bi(en, fil)}</li></ol></nav>'
            f'<span class="hero-badge tone-{tone}" aria-hidden="true">{ico}</span>')


def render_footer(key):
    cols = []
    for title_en, title_fil, aria, ico, links in FOOTER_COLS:
        lis = []
        for href, en, fil in links:
            ext = ' rel="noopener"' if href.startswith("http") else ""
            text = en if en == fil else bi(en, fil)
            lis.append(f'          <li><a href="{href}"{ext}>{text}</a></li>')
        cols.append(
            f'      <nav aria-label="{aria}">\n'
            f'        <h2 class="footer-title"><span aria-hidden="true">{ico}</span>{bi(title_en, title_fil)}</h2>\n'
            f'        <ul>\n' + "\n".join(lis) + "\n        </ul>\n      </nav>")
    return f"""
<footer class="site-footer">
  <div class="container">
    <div class="footer-grid">
      <div class="footer-brand">
        <a class="brand" href="index.html"><img class="brand-logo" src="assets/logo.webp" width="40" height="40" alt=""><span>FlashLearn <b>PWD</b></span></a>
        <p>{bi("A free, bilingual flashcard app for learners with disabilities — a college thesis / capstone project (2023–2027), built with Filipino learners first.", "Libreng bilingual na flashcard app para sa mga mag-aaral na may kapansanan — isang college thesis / capstone project (2023–2027), ginawa para sa mga mag-aaral na Pilipino.")}</p>
        <div class="actions">
          <a class="btn btn-primary btn-sm" href="download.html">{bi("Download free", "I-download nang libre")}</a>
          <a class="btn btn-secondary btn-sm" href="try.html">{bi("Try it first", "Subukan muna")}</a>
        </div>
      </div>
{chr(10).join(cols)}
    </div>
    <div class="footer-bottom">
      <p>{bi("Made with 💜 for inclusive education in the Philippines.", "Ginawa nang may 💜 para sa inklusibong edukasyon sa Pilipinas.")}</p>
      <p>© 2026 FlashLearn PWD. {bi("Screenshots and the app in our videos come from the real app on an Android tablet.", "Galing sa totoong app sa isang Android tablet ang mga screenshot at ang app sa aming mga video.")}</p>
    </div>
  </div>
</footer>
<script src="{asset("site.js")}"></script>
"""


REGIONS = {
    "site-head": render_head,
    "site-header": render_header,
    "site-crumbs": render_crumbs,
    "site-footer": render_footer,
}


def fail(msg):
    sys.exit(f"site_chrome_build: {msg}")


def check_reach():
    """Every page is one navigation entry (Home, a group link or an action), once."""
    keys = [HOME[0]] + [d[0] for g in GROUPS for d in g[5] if d[0] not in NOT_PAGES] + [a[0] for a in ACTIONS]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    missing = sorted(set(PAGES.values()) - set(keys))
    extra = sorted(set(keys) - set(PAGES.values()))
    if dupes or missing or extra:
        fail(f"navigation out of date — twice: {dupes}, no entry: {missing}, no page: {extra}")


def apply(text, key, path):
    nl = "\r\n" if "\r\n" in text else "\n"
    for name, render in REGIONS.items():
        pattern = re.compile(rf"(<!--gen:{name}-->)(.*?)(<!--/gen:{name}-->)", re.S)
        found = len(pattern.findall(text))
        want = 0 if (name == "site-crumbs" and key == "home") else 1
        if found != want:
            fail(f"{path}: expected {want} <!--gen:{name}--> region(s), found {found}")
        if want:
            body = render(key).replace("\r\n", "\n").replace("\n", nl)
            text = pattern.sub(lambda m: m.group(1) + body + m.group(3), text)
    # Page-specific scripts outside the regions (try.html's try.js).
    text = re.sub(r'assets/try\.js(\?v=[0-9a-f]+)?"', asset("try.js") + '"', text)
    return text


def assets_digest():
    """Every file under website/assets the service worker may keep, by content. (Videos
    are left out: a <video> asks for byte ranges, and the worker never stores a partial
    206 answer.) A changed picture, caption or font changes the cache name, so no
    visitor is answered from an old copy."""
    h = hashlib.sha256()
    base = os.path.join(SITE, "assets")
    for dirpath, dirs, files in os.walk(base):
        dirs.sort()
        for f in sorted(files):
            if f.endswith(".mp4"):
                continue
            path = os.path.join(dirpath, f)
            h.update(os.path.relpath(path, base).replace(os.sep, "/").encode())
            with open(path, "rb") as fh:
                h.update(fh.read())
    return h.hexdigest()


def apply_sw(text):
    """Precache the fingerprinted URLs, under a cache name that changes with them and
    with every other asset."""
    for name in VERSIONED:
        text, n = re.subn(r"'assets/" + re.escape(name) + r"(\?v=[0-9a-f]+)?'", "'" + asset(name) + "'", text)
        if n != 1:
            fail(f"sw.js: expected one precache entry for assets/{name}, found {n}")
    tag = hashlib.sha256(("".join(V[n] for n in VERSIONED) + assets_digest()).encode()).hexdigest()[:8]
    text, n = re.subn(r"const CACHE = 'flp-site-v(\d+)(-[0-9a-f]+)?';",
                      lambda m: f"const CACHE = 'flp-site-v{m.group(1)}-{tag}';", text)
    if n != 1:
        fail("sw.js: no `const CACHE = 'flp-site-vN';` line")
    return text


def main():
    check = "--check" in sys.argv
    check_reach()
    on_disk = sorted(f for f in os.listdir(SITE) if f.endswith(".html"))
    unknown = [f for f in on_disk if f not in PAGES]
    missing = [f for f in PAGES if f not in on_disk]
    if unknown or missing:
        fail(f"page list out of date — not listed: {unknown}, listed but missing: {missing}")
    targets = [(os.path.join(SITE, f), k) for f, k in PAGES.items()]
    targets += [(os.path.join(ROOT, f), k) for f, k in TEMPLATES.items()]
    stale = []
    sw = os.path.join(SITE, "sw.js")
    with open(sw, encoding="utf-8", newline="") as f:
        old = f.read()
    new = apply_sw(old)
    if new != old:
        stale.append(sw)
        if not check:
            with open(sw, "w", encoding="utf-8", newline="") as f:
                f.write(new)
    for path, key in targets:
        with open(path, encoding="utf-8", newline="") as f:
            old = f.read()
        new = apply(old, key, os.path.relpath(path, ROOT))
        if new != old:
            stale.append(path)
            if not check:
                with open(path, "w", encoding="utf-8", newline="") as f:
                    f.write(new)
    for p in stale:
        print(("stale: " if check else "wrote ") + os.path.relpath(p, ROOT))
    if check:
        sys.exit(1 if stale else 0)
    print(f"{len(targets)} files checked, {len(stale)} rewritten")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()
