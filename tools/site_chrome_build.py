"""Write the shared parts of every website page from one definition.

    python tools/site_chrome_build.py          # rewrite the pages
    python tools/site_chrome_build.py --check  # exit 1 if any page is stale

The website has no build step, and every page used to carry its own copy of
the header, navigation and footer. The copies drifted (three different navs
and three footers at one point, and a template that silently reverted a fix).
Now the shared parts live here and are written between markers:

  <!--gen:site-head-->    stylesheet, icons, the early preference script
  <!--gen:site-header-->  skip link, header, navigation, accessibility panel
  <!--gen:site-crumbs-->  "Home > This page" (every page except Home)
  <!--gen:site-footer-->  footer + assets/site.js

The two generated pages are covered through their templates, so the next
games/dictionary build reproduces exactly what this script wrote.
Guards: every page must carry each marker exactly once (crumbs: none on Home).

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
}
TEMPLATES = {
    os.path.join("tools", "games_page.template.html"): "games",
    os.path.join("tools", "fsl_dict_page.template.html"): "dictionary",
}

# Main navigation: key, href, EN, FIL, icon, menu hint EN, menu hint FIL.
NAV = [
    ("home", "index.html", "Home", "Home", "🏠", "Start here", "Dito magsimula"),
    ("try", "try.html", "Try It", "Subukan", "🎴", "Flashcards and a game, right in your browser", "Flashcard at laro, mismo sa browser"),
    ("download", "download.html", "Download", "I-download", "⬇️", "Free for Android 10 and newer", "Libre para sa Android 10 pataas"),
    ("how", "how-to-use.html", "How to Use", "Paano Gamitin", "📖", "A short video and a picture tour", "Maikling video at tour na may larawan"),
    ("games", "games.html", "Games", "Mga Laro", "🎮", "Every learning game in the app", "Bawat larong pampagkatuto sa app"),
    ("dictionary", "fsl-dictionary.html", "FSL Dictionary", "Diksyunaryo ng FSL", "🤟", "Watch everyday words signed", "Panoorin ang senyas ng mga salita"),
    ("guide", "teachers-guide.html", "Teacher’s Guide", "Gabay ng Guro", "🧑‍🏫", "Set up a class, printable", "Pag-set up ng klase, napi-print"),
    ("faq", "faq.html", "FAQ", "Mga Tanong", "❓", "Answers, and how to reach us", "Mga sagot, at paano kami makakausap"),
]
# Pages that are not in the main navigation still need a breadcrumb label.
EXTRA_LABELS = {
    "awareness": ("PWD Awareness", "Kamalayang PWD"),
    "about": ("About", "Tungkol sa Amin"),
    "privacy": ("Privacy &amp; Data", "Privacy at Datos"),
    "gaze": ("Gaze Control", "Gaze Control"),
}

FOOTER_COLS = [
    ("Get started", "Magsimula", "Get started", [
        ("download.html", "Download the app", "I-download ang app"),
        ("try.html", "Try it in your browser", "Subukan sa browser"),
        ("how-to-use.html", "How to use the app", "Paano gamitin ang app"),
        ("games.html", "Learning games", "Mga larong pampagkatuto"),
    ]),
    ("Learn more", "Matuto pa", "Learn more", [
        ("fsl-dictionary.html", "FSL Sign Dictionary", "Diksyunaryo ng FSL"),
        ("teachers-guide.html", "Teacher’s Guide", "Gabay ng Guro"),
        ("gaze-control.html", "Gaze Control (hands-free)", "Gaze Control (walang kamay)"),
        ("awareness.html", "PWD Awareness", "Kamalayang PWD"),
        ("faq.html", "Questions (FAQ)", "Mga Tanong (FAQ)"),
    ]),
    ("The project", "Ang proyekto", "About the project", [
        ("about.html", "About the team", "Tungkol sa pangkat"),
        ("faq.html#feedback", "Send feedback", "Magpadala ng feedback"),
        ("privacy.html", "Privacy &amp; data", "Privacy at datos"),
        ("https://github.com/jpaestedstu-prog/pwd_flashcard_app", "GitHub", "GitHub"),
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
# the visitor's saved text size / dyslexia / contrast / language choices, so a
# Filipino reader never sees the English page flash first.
EARLY_JS = (
    "<script>(function(h){h.classList.add('js');try{var p=JSON.parse(localStorage.getItem('flp-a11y')||'{}');"
    "if(p.font==='lg'||p.font==='xl')h.classList.add('fs-'+p.font);if(p.dys)h.classList.add('dys');"
    "if(p.hc)h.classList.add('hc');if(p.fil){h.classList.add('fil');h.setAttribute('lang','fil');}"
    "if(p.fil||p.font==='lg'||p.font==='xl')h.classList.add('nav-compact');}catch(e){}})"
    "(document.documentElement);</script>"
)


def render_head(key):
    return "\n".join([
        "",
        '<meta name="theme-color" content="#6C5CE7">',
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


def render_header(key):
    items = []
    for k, href, en, fil, ico, sub_en, sub_fil in NAV:
        cur = ' aria-current="page"' if k == key else ""
        items.append(
            f'        <li><a href="{href}"{cur}><span class="nav-ico" aria-hidden="true">{ico}</span>'
            f'<span class="nav-txt"><span class="nav-main">{bi(en, fil)}</span>'
            f'<span class="nav-sub">{bi(sub_en, sub_fil)}</span></span></a></li>')
    sizes = [
        ("", "A", "Normal text size", "Karaniwang laki ng letra"),
        ("lg", "A+", "Large text", "Malaking letra"),
        ("xl", "A++", "Largest text", "Pinakamalaking letra"),
    ]
    seg = "\n".join(
        f'          <button type="button" data-font="{v}" aria-pressed="{"true" if not v else "false"}" '
        f'aria-label="{en}" data-label-en="{en}" data-label-fil="{fil}">{t}</button>'
        for v, t, en, fil in sizes)
    return f"""
<a class="skip" href="#main">{bi("Skip to main content", "Laktawan papunta sa nilalaman")}</a>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="index.html"><img class="brand-logo" src="assets/logo.webp" width="40" height="40" alt=""><span class="brand-name">FlashLearn <b>PWD</b></span></a>
    <nav class="site-nav" id="siteNav" aria-label="Main" data-label-en="Main" data-label-fil="Pangunahin">
      <ul>
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
    <button type="button" class="switch" id="btnDys" role="switch" aria-checked="false"><span>{bi("Dyslexia-friendly font", "Font para sa may dyslexia")}</span><span class="track" aria-hidden="true"></span></button>
    <button type="button" class="switch" id="btnHC" role="switch" aria-checked="false"><span>{bi("High contrast", "Mataas na contrast")}</span><span class="track" aria-hidden="true"></span></button>
    <div class="panel-foot">
      <p class="panel-note">{bi("Saved on this device for every page.", "Naka-save sa device na ito para sa bawat pahina.")}</p>
      <button type="button" class="link-btn" id="btnA11yReset">{bi("Reset", "I-reset")}</button>
    </div>
  </div>
</header>
"""


def label_for(key):
    for k, _href, en, fil, *_ in NAV:
        if k == key:
            return en, fil
    return EXTRA_LABELS[key]


def render_crumbs(key):
    en, fil = label_for(key)
    return (f'<nav class="crumbs" aria-label="Breadcrumb" data-label-en="Breadcrumb" data-label-fil="Kinaroroonan">'
            f'<ol><li><a href="index.html">{bi("Home", "Home")}</a></li>'
            f'<li aria-current="page">{bi(en, fil)}</li></ol></nav>')


def render_footer(key):
    cols = []
    for title_en, title_fil, aria, links in FOOTER_COLS:
        lis = []
        for href, en, fil in links:
            ext = ' rel="noopener"' if href.startswith("http") else ""
            text = en if en == fil else bi(en, fil)
            lis.append(f'          <li><a href="{href}"{ext}>{text}</a></li>')
        cols.append(
            f'      <nav aria-label="{aria}">\n'
            f'        <h2 class="footer-title">{bi(title_en, title_fil)}</h2>\n'
            f'        <ul>\n' + "\n".join(lis) + "\n        </ul>\n      </nav>")
    return f"""
<footer class="site-footer">
  <div class="container">
    <div class="footer-grid">
      <div class="footer-brand">
        <a class="brand" href="index.html"><img class="brand-logo" src="assets/logo.webp" width="40" height="40" alt=""><span>FlashLearn <b>PWD</b></span></a>
        <p>{bi("A free, bilingual flashcard app for learners with disabilities — a college thesis / capstone project (2023–2027), built with Filipino learners first.", "Libreng bilingual na flashcard app para sa mga mag-aaral na may kapansanan — isang college thesis / capstone project (2023–2027), ginawa para sa mga mag-aaral na Pilipino.")}</p>
        <a class="btn btn-primary btn-sm" href="download.html">{bi("Download free", "I-download nang libre")}</a>
      </div>
{chr(10).join(cols)}
    </div>
    <div class="footer-bottom">
      <p>{bi("Made with 💜 for inclusive education in the Philippines.", "Ginawa nang may 💜 para sa inklusibong edukasyon sa Pilipinas.")}</p>
      <p>© 2026 FlashLearn PWD. {bi("Screenshots and the demo video come from the real app on an Android tablet.", "Galing sa totoong app sa isang Android tablet ang mga screenshot at demo video.")}</p>
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


def apply_sw(text):
    """Precache the fingerprinted URLs, under a cache name that changes with them."""
    for name in VERSIONED:
        text, n = re.subn(r"'assets/" + re.escape(name) + r"(\?v=[0-9a-f]+)?'", "'" + asset(name) + "'", text)
        if n != 1:
            fail(f"sw.js: expected one precache entry for assets/{name}, found {n}")
    tag = hashlib.sha256("".join(V[n] for n in VERSIONED).encode()).hexdigest()[:8]
    text, n = re.subn(r"const CACHE = 'flp-site-v(\d+)(-[0-9a-f]+)?';",
                      lambda m: f"const CACHE = 'flp-site-v{m.group(1)}-{tag}';", text)
    if n != 1:
        fail("sw.js: no `const CACHE = 'flp-site-vN';` line")
    return text


def main():
    check = "--check" in sys.argv
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
