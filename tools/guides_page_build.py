"""Builds website/guides.html — the companion website's Help & Guides — from the app's own
guides (lib/features/help/models/guides.dart), so the website and the app can never say
different things.

    python tools/guides_page_build.py          write website/guides.html
    python tools/guides_page_build.py --check  fail if it is out of date (writes nothing)

Then run `python tools/site_chrome_build.py` (header, footer, fingerprints).

The guides file is Dart constant data; this reads it with a small parser for the subset it
uses (constructor calls, named arguments, lists, string literals, dotted names), then
renders each guide in both languages, numbered where the app numbers it, with the same
"Read aloud" text the app speaks (Guide.spokenText).
"""
import html, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUIDES = ROOT / "lib" / "features" / "help" / "models" / "guides.dart"
TEMPLATE = ROOT / "tools" / "guides_page.template.html"
OUT = ROOT / "website" / "guides.html"

# Website look per guide: emoji and tile tone (site.css .tone-*). Every guide in the app
# must have one; a new guide without one stops the build.
LOOK = {
    "students": ("🎒", "purple"),
    "teachers": ("🧑‍🏫", "indigo"),
    "parents": ("👪", "teal"),
    "accessibility": ("♿", "pink"),
    "gaze": ("👁️", "blue"),
    "voice": ("🎙️", "magenta"),
    "controller": ("🎮", "orange"),
    "screenReader": ("🔊", "green"),
    "keyboard": ("⌨️", "indigo"),
    "timeBreaks": ("⏰", "gold"),
    "tvCast": ("📺", "teal"),
    "feedback": ("⭐", "gold"),
}
# Who each guide is for, on the "Find your guide" panel.
GROUPS = [
    ("learners", "🎒", ("For students", "Para sa mag-aaral"), ["students"]),
    ("educators", "🧑‍🏫", ("For teachers and parents", "Para sa guro at magulang"),
     ["teachers", "parents", "timeBreaks", "tvCast"]),
    ("access", "♿", ("Accessibility: ways to use the app", "Accessibility: mga paraan ng paggamit ng app"),
     ["accessibility", "gaze", "voice", "controller", "screenReader", "keyboard"]),
    ("feedback", "💬", ("Questions and feedback", "Mga tanong at feedback"), ["feedback"]),
]
# More on this website, after a guide.
MORE = {
    "students": ("how-to-use.html", ("How to Use, with pictures and a short video", "Paano Gamitin, may larawan at maikling video")),
    "teachers": ("teachers-guide.html", ("The printable Teacher’s Guide", "Ang napi-print na Gabay ng Guro")),
    "parents": ("teachers-guide.html", ("The printable Teacher’s Guide (for parents too)", "Ang napi-print na Gabay ng Guro (para rin sa magulang)")),
    "gaze": ("gaze-control.html", ("Gaze Control, with a video", "Gaze Control, may video")),
    "accessibility": ("awareness.html", ("PWD Awareness", "Kamalayang PWD")),
}


# ── A small reader for the guides file ─────────────────────────────────────────────────
TOKEN = re.compile(r"""
    (?P<ws>\s+|//[^\n]*|/\*.*?\*/)
  | (?P<str>'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")
  | (?P<num>0x[0-9A-Fa-f]+|\d+)
  | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<p>[()\[\]{},:;=.<>?])
""", re.S | re.X)


def tokens(src):
    pos, out = 0, []
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            raise SystemExit(f"guides.dart: cannot read at {src[pos:pos + 40]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        val = m.group(kind)
        if kind == "str":
            body = val[1:-1]
            val = re.sub(r"\\(.)", lambda e: {"n": "\n", "t": "\t"}.get(e.group(1), e.group(1)), body)
        out.append((kind, val))
    return out


class Reader:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def take(self, want=None):
        tok = self.peek()
        if want is not None and tok[1] != want:
            raise SystemExit(f"guides.dart: expected {want!r}, found {tok[1]!r}")
        self.i += 1
        return tok

    def expr(self):
        kind, val = self.peek()
        if kind == "str":
            parts = []
            while self.peek()[0] == "str":     # 'a' 'b' joins, as in Dart
                parts.append(self.take()[1])
            return "".join(parts)
        if kind == "num":
            self.take()
            return int(val, 0)
        if val == "[":
            self.take("[")
            items = []
            while self.peek()[1] != "]":
                items.append(self.expr())
                if self.peek()[1] == ",":
                    self.take(",")
            self.take("]")
            return items
        if kind == "id":
            if val == "const":
                self.take()
                return self.expr()
            name = self.take()[1]
            while self.peek()[1] == ".":
                self.take(".")
                name += "." + self.take()[1]
            if self.peek()[1] == "(":
                return self.call(name)
            return {"ref": name}
        raise SystemExit(f"guides.dart: unexpected {val!r}")

    def call(self, name):
        self.take("(")
        args, kw = [], {}
        while self.peek()[1] != ")":
            if self.peek()[0] == "id" and self.peek(1)[1] == ":":
                key = self.take()[1]
                self.take(":")
                kw[key] = self.expr()
            else:
                args.append(self.expr())
            if self.peek()[1] == ",":
                self.take(",")
        self.take(")")
        return {"call": name, "args": args, "kw": kw}


def call_text(src, start):
    """src[start:] begins `Name(`: the text up to its matching `)`, strings skipped."""
    i = src.index("(", start)
    depth = 0
    while i < len(src):
        c = src[i]
        if c in "'\"":
            q = c
            i += 1
            while src[i] != q:
                i += 2 if src[i] == "\\" else 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
        i += 1
    raise SystemExit("guides.dart: unbalanced parentheses")


def read_guides():
    src = GUIDES.read_text(encoding="utf-8")
    consts = {}
    for m in re.finditer(r"^const (_\w+) = (GuideText|Guide)\(", src, re.M):
        r = Reader(tokens(call_text(src, m.start(2))))
        consts[m.group(1)] = r.expr()
    order_m = re.search(r"^const List<Guide> allGuides = \[(.*?)\];", src, re.M | re.S)
    if not order_m:
        raise SystemExit("guides.dart: no `const List<Guide> allGuides = [...]`")
    order = re.findall(r"_\w+", order_m.group(1))

    def text(node):
        if isinstance(node, dict) and "ref" in node:
            node = consts[node["ref"]]
        if not (isinstance(node, dict) and node.get("call") == "GuideText" and len(node["args"]) == 2):
            raise SystemExit(f"guides.dart: expected GuideText(en, fil), found {node!r}"[:200])
        en, fil = node["args"]
        if not en.strip() or not fil.strip():
            raise SystemExit(f"guides.dart: an empty text: {node!r}"[:200])
        return {"en": en, "fil": fil}

    guides = []
    for name in order:
        g = consts[name]
        kw = g["kw"]
        sections = []
        for s in kw["sections"]:
            heading, lines = s["args"]
            sections.append({
                "heading": text(heading),
                "numbered": bool(s["kw"].get("numbered", {}).get("ref") == "true"),
                "lines": [{"text": text(l["args"][0]),
                           "label": text(l["kw"]["label"]) if "label" in l["kw"] else None} for l in lines],
            })
        guides.append({
            "id": kw["id"],
            "title": text(kw["title"]),
            "summary": text(kw["summary"]),
            "audience": kw["audience"]["ref"].split(".")[-1],
            "sections": sections,
        })
    return guides


def spoken(g, lang):
    """The app's Guide.spokenText, word for word."""
    fil = lang == "fil"
    parts = [g["title"][lang], g["summary"][lang]]
    for s in g["sections"]:
        parts.append(s["heading"][lang])
        for n, line in enumerate(s["lines"], 1):
            step = (f"Hakbang {n}. " if fil else f"Step {n}. ") if s["numbered"] else ""
            label = f"{line['label'][lang]}: " if line["label"] else ""
            parts.append(step + label + line["text"][lang])
    return " ".join(p if re.search(r"[.!?:]$", p.strip()) else p + "." for p in parts)


# ── HTML ───────────────────────────────────────────────────────────────────────────────
def esc(s):
    return html.escape(s, quote=True)


def bi(t):
    return f'<span class="en">{esc(t["en"])}</span><span class="fil">{esc(t["fil"])}</span>'


def bi2(en, fil):
    return f'<span class="en">{esc(en)}</span><span class="fil">{esc(fil)}</span>'


def render_index(guides):
    by_id = {g["id"]: g for g in guides}
    grouped = [i for _, _, _, ids in GROUPS for i in ids]
    missing = sorted(set(by_id) - set(grouped))
    unknown = sorted(set(grouped) - set(by_id))
    if missing or unknown:
        raise SystemExit(f"GROUPS out of date — not grouped: {missing}, no such guide: {unknown}")
    out = ['    <div class="guide-groups">']
    for key, ico, (en, fil), ids in GROUPS:
        out.append(f'      <section class="guide-group" aria-labelledby="gg-{key}">')
        out.append(f'        <h3 id="gg-{key}"><span aria-hidden="true">{ico}</span> {bi2(en, fil)}</h3>')
        out.append('        <ul class="guide-cards">')
        for gid in ids:
            g = by_id[gid]
            emoji, tone = LOOK[gid]
            out.append(f'          <li><a class="guide-card" href="#g-{gid}" data-guide="{gid}">'
                       f'<span class="guide-ico tone-{tone}" aria-hidden="true">{emoji}</span>'
                       f'<span class="guide-card-text"><strong>{bi(g["title"])}</strong>'
                       f'<span class="guide-card-sum">{bi(g["summary"])}</span></span></a></li>')
        out.append('        </ul>')
        out.append('      </section>')
    out.append('    </div>')
    return "\n".join(out)


def render_guide(g):
    gid = g["id"]
    emoji, tone = LOOK[gid]
    out = [f'    <details class="disclosure guide" id="g-{gid}">',
           f'      <summary><span class="guide-sum"><span class="guide-ico tone-{tone}" aria-hidden="true">{emoji}</span>'
           f'<span class="guide-sum-text"><span class="guide-name">{bi(g["title"])}</span>'
           f'<span class="guide-sub">{bi(g["summary"])}</span></span></span></summary>',
           '      <div class="d-body guide-body">',
           f'        <p class="guide-actions"><button type="button" class="btn btn-secondary btn-sm guide-say" hidden'
           f' data-say-en="{esc(spoken(g, "en"))}" data-say-fil="{esc(spoken(g, "fil"))}" aria-pressed="false">'
           f'<span aria-hidden="true">🔊</span> <span class="say-start">{bi2("Read aloud", "Basahin nang malakas")}</span>'
           f'<span class="say-stop" hidden>{bi2("Stop reading", "Itigil ang pagbasa")}</span></button>'
           f'<a class="guide-top" href="#find">{bi2("All guides", "Lahat ng gabay")}</a></p>',
           '        <p class="guide-voice-note" role="status" hidden>'
           + bi2("This device has no Filipino voice, so another voice reads the Filipino words.",
                 "Walang boses na Filipino sa device na ito, kaya ibang boses ang babasa sa mga salitang Filipino.")
           + '</p>']
    for s in g["sections"]:
        tag = "ol" if s["numbered"] else "ul"
        out.append('        <section class="guide-sec">')
        out.append(f'          <h3>{bi(s["heading"])}</h3>')
        out.append(f'          <{tag} class="guide-{"steps" if s["numbered"] else "list"}">')
        for line in s["lines"]:
            if line["label"]:
                label = line["label"]
                body = (f'<span class="en"><strong>{esc(label["en"])}:</strong> {esc(line["text"]["en"])}</span>'
                        f'<span class="fil"><strong>{esc(label["fil"])}:</strong> {esc(line["text"]["fil"])}</span>')
            else:
                body = bi(line["text"])
            out.append(f'            <li>{body}</li>')
        out.append(f'          </{tag}>')
        out.append('        </section>')
    if gid == "feedback":
        out.append('        <p><a class="btn btn-primary" href="faq.html#feedback"><span aria-hidden="true">💌</span> '
                   + bi2("Open the feedback form", "Buksan ang feedback form") + '</a></p>')
    if gid in MORE:
        href, (en, fil) = MORE[gid]
        out.append(f'        <p class="guide-more"><span class="en">More on this website:</span>'
                   f'<span class="fil">Higit pa sa website na ito:</span> <a href="{href}">{bi2(en, fil)}</a></p>')
    out.append('      </div>')
    out.append('    </details>')
    return "\n".join(out)


PAGE_JS = r"""(function(){
  // Help & Guides: a link to one guide (#g-voice) opens it; Open all / Close all; printing
  // shows every guide; and "Read aloud" with the browser's own voices (the app reads the
  // same words with its own voice).
  var guides = [].slice.call(document.querySelectorAll('details.guide'));
  function openFromHash(){
    var id = decodeURIComponent((location.hash || '').slice(1));
    var el = id && document.getElementById(id);
    if (el && el.tagName === 'DETAILS') {
      el.open = true;
      requestAnimationFrame(function(){ el.scrollIntoView({ block: 'start' }); el.querySelector('summary').focus({ preventScroll: true }); });
    }
  }
  addEventListener('hashchange', openFromHash);
  openFromHash();
  var tools = document.querySelector('.guides-tools');
  if (tools) tools.hidden = false;
  var openAll = document.getElementById('guidesOpenAll'), closeAll = document.getElementById('guidesCloseAll');
  if (openAll) openAll.addEventListener('click', function(){ guides.forEach(function(d){ d.open = true; }); });
  if (closeAll) closeAll.addEventListener('click', function(){ stop(); guides.forEach(function(d){ d.open = false; }); });
  var printed = [];
  addEventListener('beforeprint', function(){ printed = guides.filter(function(d){ return !d.open; }); printed.forEach(function(d){ d.open = true; }); });
  addEventListener('afterprint', function(){ printed.forEach(function(d){ d.open = false; }); printed = []; });

  var synth = window.speechSynthesis;
  var buttons = [].slice.call(document.querySelectorAll('.guide-say'));
  if (!synth || !window.SpeechSynthesisUtterance) return;   // no speech: the buttons stay hidden
  buttons.forEach(function(b){ b.hidden = false; });
  if (synth.onvoiceschanged !== undefined) synth.onvoiceschanged = function(){};
  synth.getVoices();
  function voiceFor(prefixes){
    var vs = synth.getVoices();
    for (var i = 0; i < prefixes.length; i++)
      for (var j = 0; j < vs.length; j++)
        if ((vs[j].lang || '').toLowerCase().replace('_', '-').indexOf(prefixes[i]) === 0) return vs[j];
    return null;
  }
  // Long text in sentence-sized pieces: some browsers stop a long single utterance.
  function pieces(text){
    var out = [], cur = '';
    (text.match(/[^.!?]+[.!?]*\s*/g) || [text]).forEach(function(s){
      if ((cur + s).length > 220 && cur) { out.push(cur); cur = ''; }
      cur += s;
    });
    if (cur.trim()) out.push(cur);
    return out;
  }
  var speaking = null, run = 0;
  function show(b, on){
    b.setAttribute('aria-pressed', on ? 'true' : 'false');
    b.querySelector('.say-start').hidden = on;
    b.querySelector('.say-stop').hidden = !on;
  }
  function stop(){
    run++;
    if (speaking) show(speaking, false);
    speaking = null;
    synth.cancel();
  }
  buttons.forEach(function(b){
    b.addEventListener('click', function(){
      if (speaking === b) { stop(); return; }
      stop();
      var fil = document.documentElement.classList.contains('fil');
      var voice = fil ? voiceFor(['fil', 'tl']) : voiceFor(['en']);
      var note = b.closest('.guide-body').querySelector('.guide-voice-note');
      if (note) note.hidden = !(fil && !voice);
      var parts = pieces(b.getAttribute(fil ? 'data-say-fil' : 'data-say-en') || ''), mine = ++run;
      speaking = b;
      show(b, true);
      parts.forEach(function(text, i){
        var u = new SpeechSynthesisUtterance(text);
        u.lang = fil ? 'fil-PH' : 'en-US';
        u.rate = 0.95;
        if (voice) u.voice = voice;
        if (i === parts.length - 1) u.onend = function(){ if (run === mine) { show(b, false); speaking = null; } };
        u.onerror = function(){ if (run === mine) { show(b, false); speaking = null; } };
        synth.speak(u);
      });
    });
  });
  // A closed guide, another page, or a language switch stops the reading.
  guides.forEach(function(d){ d.addEventListener('toggle', function(){ if (!d.open && speaking && d.contains(speaking)) stop(); }); });
  addEventListener('pagehide', stop);
  var lang = document.getElementById('btnLangEn'), langFil = document.getElementById('btnLangFil');
  [lang, langFil].forEach(function(x){ if (x) x.addEventListener('click', stop); });
})();"""


def main():
    check = "--check" in sys.argv
    guides = read_guides()
    missing = [g["id"] for g in guides if g["id"] not in LOOK]
    if missing:
        raise SystemExit(f"LOOK has no emoji/tone for: {missing}")
    page = TEMPLATE.read_text(encoding="utf-8")
    repl = {
        "<!--INDEX-->": render_index(guides),
        "<!--GUIDES-->": "\n".join(render_guide(g) for g in guides),
        "<!--PAGEJS-->": PAGE_JS,
        "__COUNT__": str(len(guides)),
    }
    for needle, value in repl.items():
        if needle not in page:
            raise SystemExit(f"template is missing placeholder {needle}")
        page = page.replace(needle, value)
    if check:
        current = OUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUT.exists() else ""
        if current != page.replace("\r\n", "\n"):
            print(f"stale: {OUT.relative_to(ROOT)} (run python tools/guides_page_build.py)")
            sys.exit(1)
        print(f"{OUT.relative_to(ROOT)} is up to date: {len(guides)} guides")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    lines = sum(len(s["lines"]) for g in guides for s in g["sections"])
    print(f"wrote {OUT.relative_to(ROOT)}: {len(guides)} guides, {lines} lines, in English and Filipino")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
