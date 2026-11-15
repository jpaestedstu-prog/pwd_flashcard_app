"""Builds website/features.html — "Features in Action", the companion website's showcase
of what the app can do — and the guide quick starts on other pages.

    python tools/features_page_build.py          write the page (and the quick starts)
    python tools/features_page_build.py --check  fail if anything is out of date

Then run `python tools/site_chrome_build.py` (header, footer, fingerprints).

One source for every kind of text, so nothing is copied by hand:
  * Steps, "what it does", "who it helps" and "you need" lines come from the app's own
    guides (lib/features/help/models/guides.dart, read by guides_page_build.py). A guide
    line that moves or disappears stops this build, and test/help_guides_test.dart checks
    the page against the guides on every test run.
  * The few lines no guide covers (the Talk Board, My Day, the games...) are written here,
    from the app's own code: the per-disability presentation classes
    (lib/features/*/models/*_presentation.dart) and AccessibilityPresets.
  * Videos and pictures come from tools/site_media.py, the list the guides page uses too.
  * Each card links to its guide (guides.html#g-<id>, or a section of it).

Quick starts: a page region
    <!--gen:guide-steps gaze/turn-it-on-->...<!--/gen:guide-steps-->
is filled with that guide section's steps, in both languages (the Gaze Control page's
"Getting started" is one), so a showcase page never carries hand-typed steps.
"""
import os, re, sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import guides_page_build as gp   # noqa: E402
import site_media as sm          # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools" / "features_page.template.html"
OUT = ROOT / "website" / "features.html"
SITE = ROOT / "website"

GUIDES = gp.read_guides()
BY_ID = {g["id"]: g for g in GUIDES}
esc, bi2 = gp.esc, gp.bi2


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def section_id(gid, heading_en):
    """The anchor of a guide section on guides.html (guides_page_build.py uses it too)."""
    return f"g-{gid}-{slug(heading_en)}"


def find_section(gid, heading):
    g = BY_ID.get(gid)
    if not g:
        raise SystemExit(f"features: no guide {gid!r}")
    for si, s in enumerate(g["sections"]):
        if s["heading"]["en"].startswith(heading):
            return si, s
    raise SystemExit(f"features: guide {gid!r} has no section starting {heading!r}")


def G(gid, heading, label=None, idx=None, head=False):
    """One line of a guide, in both languages, with where it came from. head=True shows
    the guide section's heading in front of it (e.g. "Dyslexia-friendly: ...")."""
    si, s = find_section(gid, heading)
    for li, line in enumerate(s["lines"]):
        if (label is not None and line["label"] and line["label"]["en"] == label) or (label is None and li == idx):
            return {"en": line["text"]["en"], "fil": line["text"]["fil"], "ref": f"{gid}.{si}.{li}",
                    "head": s["heading"] if head else None}
    raise SystemExit(f"features: {gid}/{heading!r} has no line {label or idx!r}")


def SUMMARY(gid):
    g = BY_ID[gid]
    return {"en": g["summary"]["en"], "fil": g["summary"]["fil"], "ref": f"{gid}.summary"}


def T(en, fil):
    """Words written for this page (no guide says them); see the module docstring."""
    return {"en": en, "fil": fil, "ref": None}


def STEPS(gid, heading, picks=None):
    si, s = find_section(gid, heading)
    picks = range(len(s["lines"])) if picks is None else picks
    return [{"en": s["lines"][i]["text"]["en"], "fil": s["lines"][i]["text"]["fil"], "ref": f"{gid}.{si}.{i}"} for i in picks]


NEEDS = [   # the app's own disability presets (DisabilityType), as on Home
    ("visual", "👁️", ("Visual", "Paningin")),
    ("hearing", "👂", ("Hearing", "Pandinig")),
    ("motor", "🦽", ("Motor", "Paggalaw")),
    ("cognitive", "🧠", ("Cognitive & learning", "Pag-iisip at pagkatuto")),
]
NEED_LABEL = {k: (ico, names) for k, ico, names in NEEDS}

GROUPS = [
    ("control", "🎛️", "blue", ("Control the app your way", "Kontrolin ang app sa paraan mo"),
     ("Use the app without touching the screen: with head movements, your voice, a game controller, a keyboard or one switch.",
      "Gamitin ang app nang hindi hinahawakan ang screen: sa galaw ng ulo, sa boses, sa game controller, sa keyboard o sa isang switch.")),
    ("seehear", "👀", "teal", ("See, hear and read your way", "Makita, marinig at mabasa sa paraan mo"),
     ("Bigger words and stronger colours, words read aloud, Android’s screen reader, and Filipino Sign Language videos.",
      "Mas malalaking salita at mas matitingkad na kulay, binabasang mga salita, ang screen reader ng Android, at mga video sa Filipino Sign Language.")),
    ("pace", "🌱", "green", ("Learn at your own pace", "Matuto ayon sa sariling bilis"),
     ("Games that get easier or harder, rests when they are needed, a picture schedule for the day, and a voice for learners who do not speak yet.",
      "Mga larong lumalaki o lumiliit ang hirap, pahinga kapag kailangan, iskedyul ng araw na may larawan, at boses para sa mga mag-aaral na hindi pa nagsasalita.")),
    ("adults", "🧑‍🏫", "indigo", ("For teachers and parents", "Para sa guro at magulang"),
     ("Classes, progress, tests, time limits and the TV: the tools for the adults beside a learner.",
      "Mga klase, progreso, pagsusulit, limitasyon sa oras at ang TV: ang mga gamit ng mga katuwang ng mag-aaral.")),
    ("learn", "🎒", "purple", ("Learn and play", "Matuto at maglaro"),
     ("The learning itself: flashcards, games, stories and a friendly buddy, each set up for the learner who uses it.",
      "Ang mismong pag-aaral: mga flashcard, laro, kuwento at isang mabait na kasama, bawat isa inihanda para sa mag-aaral na gumagamit nito.")),
]

ALL4 = ["visual", "hearing", "motor", "cognitive"]

# One card per feature. what/who/need: guide lines (G, SUMMARY) or T(...) words;
# start: steps from a guide; guide: (guide id, section heading or None) or an (href, (en, fil)) link.
FEATURES = [
    # ── A. Control the app your way ──
    dict(id="gaze", group="control", ico="👁️", tone="blue", name=("Gaze Control", "Gaze Control"),
         what=[G("gaze", "About Gaze Control", "What it does")],
         who=[G("gaze", "About Gaze Control", "Who it helps")],
         need=[G("gaze", "About Gaze Control", "You need")],
         start=STEPS("gaze", "Turn it on", [0, 1]), needs=["motor"], demo="gaze",
         guide=("gaze", None),
         more=("gaze-control.html", ("The Gaze Control page, with the whole video", "Ang pahina ng Gaze Control, kasama ang buong video"))),
    dict(id="voice", group="control", ico="🎙️", tone="magenta", name=("Voice commands", "Mga voice command"),
         what=[G("voice", "About voice commands", "What it does")],
         who=[G("voice", "About voice commands", "Who it helps")],
         need=[G("voice", "About voice commands", "You need")],
         start=STEPS("voice", "Turn it on", [1, 2]), needs=["motor"], demo="voice",
         guide=("voice", None)),
    dict(id="controller", group="control", ico="🕹️", tone="orange", name=("Game controller", "Game controller"),
         what=[SUMMARY("controller")],
         who=[G("controller", "About the controller", "Who it helps")],
         need=[G("controller", "About the controller", "You need")],
         start=STEPS("controller", "Turn it on", [1, 2]), needs=["visual", "motor"], demo="controller",
         guide=("controller", None)),
    dict(id="keyboard", group="control", ico="⌨️", tone="indigo", name=("Keyboard and switches", "Keyboard at mga switch"),
         what=[SUMMARY("keyboard"), G("keyboard", "One switch", "How to use it", head=True)],
         who=[G("keyboard", "Keyboard", "Who it helps"), G("keyboard", "One switch", "Who it helps")],
         need=[G("keyboard", "One switch", "You need")],
         start=[G("keyboard", "One switch", "Turn it on")], needs=["motor"], demo="switch",
         guide=("keyboard", None)),
    # ── B. See, hear and read your way ──
    dict(id="display", group="seehear", ico="🔠", tone="pink", name=("Text size and contrast", "Laki ng letra at contrast"),
         what=[G("accessibility", "Font Size", "What it does", head=True),
               G("accessibility", "High Contrast Mode and Dark Mode", "What it does", head=True),
               G("accessibility", "Dyslexia-friendly", "What it does", head=True)],
         who=[G("accessibility", "Font Size", "Who it helps"), G("accessibility", "Dyslexia-friendly", "Who it helps")],
         start=[G("accessibility", "Font Size", "Turn it on")], needs=["visual", "cognitive"], demo="looks",
         guide=("accessibility", "Font Size")),
    dict(id="readaloud", group="seehear", ico="🗣️", tone="teal", name=("Read aloud (Text-to-Speech)", "Basahin nang malakas (Text-to-Speech)"),
         what=[G("accessibility", "Hear the words", "What it does")],
         who=[G("accessibility", "Hear the words", "Who it helps")],
         need=[G("accessibility", "Hear the words", "You need")],
         start=[G("accessibility", "Hear the words", "Turn it on")], needs=["visual", "cognitive"], demo="read",
         guide=("accessibility", "Hear the words")),
    dict(id="screenreader", group="seehear", ico="🔊", tone="green", name=("Screen reader (TalkBack)", "Screen reader (TalkBack)"),
         what=[SUMMARY("screenReader")],
         who=[G("screenReader", "About TalkBack", "Who it helps")],
         need=[G("screenReader", "About TalkBack", "You need")],
         start=STEPS("screenReader", "Turn it on", [0, 1]), needs=["visual"], demo="screen-reader",
         say=STEPS("screenReader", "Use it"),
         guide=("screenReader", None)),
    dict(id="fsl", group="seehear", ico="🤟", tone="cyan", name=("Filipino Sign Language (FSL)", "Filipino Sign Language (FSL)"),
         what=[G("accessibility", "See, not only hear", "What it does")],
         who=[G("accessibility", "See, not only hear", "Who it helps")],
         need=[G("accessibility", "See, not only hear", "You need")],
         start=[G("accessibility", "See, not only hear", "How to use it")], needs=["hearing"], demo="fsl",
         guide=("accessibility", "See, not only hear"),
         more=("fsl-dictionary.html", ("Watch everyday words signed: the FSL Dictionary", "Panoorin ang senyas ng mga salita: ang Diksyunaryo ng FSL"))),
    # ── C. Learn at your own pace ──
    dict(id="adaptive", group="pace", ico="🎚️", tone="purple", name=("Adaptive Difficulty", "Adaptive Difficulty"),
         what=[G("accessibility", "Learn at your own pace", idx=0)],
         who=[T("Every learner: practice stays not too easy and not too hard. Every disability preset in the app turns it on.",
                "Bawat mag-aaral: hindi masyadong madali at hindi masyadong mahirap ang pagsasanay. Binubuksan ito ng bawat preset para sa kapansanan sa app.")],
         needs=ALL4, demo="adaptive", guide=("accessibility", "Learn at your own pace")),
    dict(id="breaks", group="pace", ico="🧘", tone="green", name=("Break reminders", "Paalala na magpahinga"),
         what=[G("timeBreaks", "Break reminders", idx=2), G("students", "When you need help or a rest", idx=0)],
         who=[T("Learners who need regular rests to stay focused. A teacher or parent chooses how often: every 10 to 60 minutes of learning.",
                "Mga mag-aaral na kailangan ng regular na pahinga para manatiling nakatuon. Pinipili ng guro o magulang kung gaano kadalas: bawat 10 hanggang 60 minuto ng pag-aaral.")],
         start=STEPS("timeBreaks", "Break reminders", [0, 1]), needs=["cognitive"], demo="breaks",
         guide=("timeBreaks", "Break reminders")),
    dict(id="myday", group="pace", ico="🗓️", tone="orange", name=("My Day", "Ang Aking Araw"),
         what=[G("accessibility", "Learn at your own pace", idx=2)],
         who=[T("Learners who need to know what comes next. It changes for each learner: each step read aloud for learners who cannot see it, an FSL sign on every step for Deaf learners, big buttons and no dragging for motor needs, and one step at a time where that helps.",
                "Mga mag-aaral na kailangang malaman kung ano ang susunod. Nagbabago ito para sa bawat mag-aaral: binabasa nang malakas ang bawat hakbang para sa hindi nakakakita, may senyas ng FSL ang bawat hakbang para sa mga Bingi, malalaking button at walang paghila para sa may kapansanan sa paggalaw, at isang hakbang lang bawat pagkakataon kung makakatulong ito.")],
         start=[G("timeBreaks", "Alarms and routines", idx=1)], needs=ALL4, demo="my-day",
         guide=("timeBreaks", "Alarms and routines")),
    dict(id="talkboard", group="pace", ico="💬", tone="pink", name=("Talk Board", "Talk Board"),
         what=[T("Tap picture tiles to build a sentence, and the tablet says it aloud, in English or Filipino. Favourite phrases are kept for next time.",
                 "I-tap ang mga larawang tile para bumuo ng pangungusap, at bibigkasin ito ng tablet, sa English o Filipino. Naitatabi ang mga paboritong parirala para sa susunod.")],
         who=[T("Learners who do not speak yet, or find speaking hard. It changes for each learner: every tile is spoken for learners who cannot see it, a big sentence banner to show others, two big columns for motor needs, and fewer, simpler tiles where that helps.",
                "Mga mag-aaral na hindi pa nagsasalita, o nahihirapang magsalita. Nagbabago ito para sa bawat mag-aaral: binibigkas ang bawat tile para sa hindi nakakakita, may malaking banner ng pangungusap para ipakita sa iba, dalawang malalaking hanay para sa may kapansanan sa paggalaw, at mas kaunti at mas simpleng tile kung makakatulong ito.")],
         needs=ALL4, demo="talk-board",
         guide=("how-to-use.html#step-9", ("How to use it: the App Tour, step 9", "Paano ito gamitin: ang Tour ng App, hakbang 9"))),
    # ── D. For teachers and parents ──
    dict(id="classes", group="adults", ico="📊", tone="indigo", name=("Classes and progress", "Mga klase at progreso"),
         what=[G("teachers", "Assign work and see progress", idx=2), G("teachers", "Support each learner", idx=0)],
         who=[T("Teachers (Manage Classes) and parents (Manage Groups), for every learner they support.",
                "Mga guro (Pamahalaan ang mga Klase) at magulang (Pamahalaan ang mga Grupo), para sa bawat mag-aaral na sinusuportahan nila.")],
         start=STEPS("teachers", "Set up your class", [0, 1, 2]), needs=ALL4, demo="classes",
         guide=("teachers", None)),
    dict(id="assignments", group="adults", ico="📝", tone="gold", name=("Assignments and tests", "Mga gawain at pagsusulit"),
         what=[G("teachers", "Assign work and see progress", idx=0), G("teachers", "Assign work and see progress", idx=1)],
         who=[T("Teachers, for a whole class or for some learners.", "Mga guro, para sa buong klase o sa ilang mag-aaral.")],
         needs=[], demo="assign", guide=("teachers", "Assign work and see progress")),
    dict(id="timelimits", group="adults", ico="⏰", tone="gold", name=("Time limits and breaks", "Mga limitasyon sa oras at pahinga"),
         what=STEPS("timeBreaks", "Time limits", [0, 1, 2]),
         who=[G("timeBreaks", "Time limits", idx=4)],
         start=STEPS("timeBreaks", "Open a learner", [0, 1, 2]), needs=["visual", "hearing"], demo="time-limits",
         guide=("timeBreaks", None)),
    dict(id="tvcast", group="adults", ico="📺", tone="teal", name=("TV Cast", "TV Cast"),
         what=[SUMMARY("tvCast")],
         who=[T("Teachers and parents with a group of learners: the whole class or family sees the same lesson.",
                "Mga guro at magulang na may grupo ng mag-aaral: iisang aralin ang nakikita ng buong klase o pamilya.")],
         need=STEPS("tvCast", "What you need"),
         start=STEPS("tvCast", "Start casting", [0, 1]), needs=[], demo="tv-cast",
         guide=("tvCast", None)),
    # ── E. Learn and play ──
    dict(id="cards", group="learn", ico="🃏", tone="purple", name=("Flashcards", "Mga flashcard"),
         what=STEPS("students", "Learn words with cards", [2, 3]),
         who=[T("Every learner. Each card has a picture, the word in English and Filipino, a speaker button and a sign language video.",
                "Bawat mag-aaral. May larawan ang bawat card, ang salita sa English at Filipino, speaker button at video sa sign language.")],
         start=STEPS("students", "Learn words with cards", [0, 1]), needs=["visual", "hearing"], demo="cards",
         guide=("students", "Learn words with cards")),
    dict(id="games", group="learn", ico="🎮", tone="pink", name=("Learning games and Play Together", "Mga larong pampagkatuto at Play Together"),
         what=[G("students", "Play and read", idx=0),
               T("On the Games tab, Play Together lets two learners play the same round, each on their own tablet.",
                 "Sa tab na Games, hinahayaan ng Play Together na maglaro ang dalawang mag-aaral ng iisang round, bawat isa sa sariling tablet.")],
         who=[T("Every learner: each disability preset gets its own set of games it can really play, and Play Together keeps each player’s own pace and spoken help.",
                "Bawat mag-aaral: may sariling hanay ng laro ang bawat preset para sa kapansanan na talagang malalaro nito, at sa Play Together, may sariling bilis at sinasabing tulong ang bawat manlalaro.")],
         needs=ALL4, demo="games", guide=("students", "Play and read"),
         more=("games.html", ("Every game in the app", "Lahat ng laro sa app"))),
    dict(id="stories", group="learn", ico="📚", tone="magenta", name=("Stories", "Mga kuwento"),
         what=[G("students", "Play and read", idx=1)],
         who=[T("Learners practising reading. The stories use the words they have learned, and can be heard as well as read.",
                "Mga mag-aaral na nagsasanay magbasa. Ginagamit ng mga kuwento ang mga salitang natutuhan nila, at maaaring pakinggan at basahin.")],
         needs=["visual", "cognitive"], demo="stories", guide=("students", "Play and read")),
    dict(id="buddy", group="learn", ico="🤖", tone="blue", name=("AI Buddy", "AI Buddy"),
         what=[G("students", "When you need help or a rest", idx=3)],
         who=[T("Every learner. It changes for each one: calm and still for learners who need less movement or sound, and lively on the screen for Deaf learners.",
                "Bawat mag-aaral. Nagbabago ito para sa bawat isa: kalmado at tahimik para sa mga kailangan ng mas kaunting galaw o tunog, at masigla sa screen para sa mga Bingi.")],
         needs=ALL4, demo="buddy", guide=("students", "When you need help or a rest")),
]


# ── HTML ───────────────────────────────────────────────────────────────────────────────
def text_html(t):
    attr = f' data-guide-line="{t["ref"]}"' if t["ref"] else ""
    head = t.get("head")
    if head:
        return (f'<span class="t"{attr}><span class="en"><strong>{esc(head["en"])}:</strong> {esc(t["en"])}</span>'
                f'<span class="fil"><strong>{esc(head["fil"])}:</strong> {esc(t["fil"])}</span></span>')
    return f'<span class="t"{attr}>{bi2(t["en"], t["fil"])}</span>'


def lines_html(items):
    return " ".join(text_html(t) for t in items)


def guide_link(f):
    target, label = f["guide"][0], f["guide"][1]
    name_en, name_fil = f["name"]
    if target.endswith(".html") or "#" in target:
        en, fil = label
        return (f'<a class="feat-guide" href="{target}"><span aria-hidden="true">📘</span> '
                f'{bi2(en, fil)}<span class="sr-only"> — {bi2(name_en, name_fil)}</span></a>')
    gid, heading = target, label
    href = f"guides.html#g-{gid}"
    if heading:
        si, s = find_section(gid, heading)
        href = "guides.html#" + section_id(gid, s["heading"]["en"])
    return (f'<a class="feat-guide" href="{href}"><span aria-hidden="true">📘</span> '
            f'{bi2("Step-by-step guide", "Gabay, hakbang-hakbang")}<span class="sr-only">: {bi2(name_en, name_fil)}</span></a>')


def render_card(f):
    fid, (en, fil) = f["id"], f["name"]
    I = "        "
    needs = f["needs"]
    if needs:
        chips = "".join(f'<li data-need="{n}"><span aria-hidden="true">{NEED_LABEL[n][0]}</span> {bi2(*NEED_LABEL[n][1])}</li>' for n in needs)
        tags = (f'{I}  <div class="feat-helps"><p class="feat-helps-label">{bi2("Helps:", "Nakakatulong sa:")}</p>'
                f'<ul class="feat-tags">{chips}</ul></div>')
    else:
        tags = (f'{I}  <div class="feat-helps"><p class="feat-helps-label">{bi2("For:", "Para sa:")}</p>'
                f'<ul class="feat-tags"><li data-need="adults"><span aria-hidden="true">🧑‍🏫</span> {bi2("Teachers and parents", "Guro at magulang")}</li></ul></div>')
    facts = [f'{I}  <dl class="feat-facts">',
             f'{I}    <div><dt>{bi2("Who it helps", "Sino ang natutulungan")}</dt><dd>{lines_html(f["who"])}</dd></div>']
    if f.get("need"):
        facts.append(f'{I}    <div><dt>{bi2("You need", "Kailangan mo")}</dt><dd>{lines_html(f["need"])}</dd></div>')
    if f.get("start"):
        steps = "".join(f"<li>{text_html(t)}</li>" for t in f["start"])
        facts.append(f'{I}    <div><dt>{bi2("First steps", "Mga unang hakbang")}</dt><dd><ol class="feat-steps">{steps}</ol></dd></div>')
    facts.append(f'{I}  </dl>')
    say = None
    if f.get("say"):
        say = (" ".join(t["en"] for t in f["say"]),
               " ".join(t["fil"] for t in f["say"]))
        say = ("TalkBack is heard, not seen, so it is described here instead of shown. " + say[0],
               "Naririnig, hindi nakikita, ang TalkBack, kaya inilalarawan ito rito sa halip na ipakita. " + say[1])
    demo = sm.render_demo(f["demo"], en, fil, f"f-{fid}", say=say, indent=I + "  ")
    links = [guide_link(f)]
    if f.get("more"):
        href, (men, mfil) = f["more"]
        links.append(f'<a class="feat-more" href="{href}">{bi2(men, mfil)}</a>')
    return "\n".join([
        f'{I}<article class="feat tone-{f["tone"]}" id="f-{fid}" data-needs="{" ".join(needs)}" aria-labelledby="f-{fid}-h">',
        f'{I}  <div class="feat-head"><span class="feat-ico" aria-hidden="true">{f["ico"]}</span>'
        f'<h3 id="f-{fid}-h">{bi2(en, fil)}</h3></div>',
        f'{I}  <p class="feat-what">{lines_html(f["what"])}</p>',
        tags,
        *facts,
        demo,
        f'{I}  <p class="feat-links">{" ".join(links)}</p>',
        f'{I}</article>',
    ])


def render_index():
    out = ['    <nav class="feat-index" aria-labelledby="featIndexTitle">',
           f'      <h2 id="featIndexTitle" class="sr-only">{bi2("Feature groups on this page", "Mga grupo ng feature sa pahinang ito")}</h2>',
           '      <ul>']
    for key, ico, tone, (en, fil), _ in GROUPS:
        n = sum(1 for f in FEATURES if f["group"] == key)
        out.append(f'        <li data-group="{key}"><a href="#grp-{key}"><span class="feat-index-ico tone-{tone}" aria-hidden="true">{ico}</span>'
                   f'<span class="feat-index-name">{bi2(en, fil)}</span><span class="feat-index-n" aria-hidden="true">{n}</span></a></li>')
    out += ['      </ul>', '    </nav>']
    return "\n".join(out)


def render_filter():
    chips = [f'          <button type="button" class="feat-chip" data-need="" aria-pressed="true">{bi2("All", "Lahat")}</button>']
    for key, ico, (en, fil) in NEEDS:
        chips.append(f'          <button type="button" class="feat-chip" data-need="{key}" aria-pressed="false">'
                     f'<span class="chip-ico" aria-hidden="true">{ico}</span> {bi2(en, fil)}<span class="chip-check" aria-hidden="true">✓</span></button>')
    return "\n".join(chips)


def render_groups():
    out = []
    for n, (key, ico, tone, (en, fil), (len_, lfil)) in enumerate(GROUPS):
        cards = [render_card(f) for f in FEATURES if f["group"] == key]
        tint = " tint" if n % 2 == 0 else ""
        out += [
            f'<section class="section feat-group{tint}" id="grp-{key}" data-group="{key}" aria-labelledby="grp-{key}-h">',
            '  <div class="container">',
            f'    <div class="feat-group-head"><span class="feat-group-ico tone-{tone}" aria-hidden="true">{ico}</span>',
            f'      <div><h2 id="grp-{key}-h">{bi2(en, fil)}</h2><p class="lead">{bi2(len_, lfil)}</p></div></div>',
            '    <div class="feat-grid">',
            *cards,
            '    </div>',
            '  </div>',
            '</section>',
            '',
        ]
    return "\n".join(out)


PAGE_JS = r"""(function(){
  // Features in Action: "Who is it for?" — choose one or more needs; only the cards that
  // help one of them stay. The choice is kept in the address (?for=visual,hearing), so a
  // link from Home (or the Back button) comes back to the same view. Without JavaScript
  // every card simply shows.
  var cards = [].slice.call(document.querySelectorAll('.feat[data-needs]'));
  var groups = [].slice.call(document.querySelectorAll('.feat-group'));
  var chips = [].slice.call(document.querySelectorAll('.feat-chip'));
  var status = document.getElementById('featStatus'), reset = document.getElementById('featReset');
  var index = [].slice.call(document.querySelectorAll('.feat-index li[data-group]'));
  var known = chips.map(function(b){ return b.getAttribute('data-need'); }).filter(Boolean);
  var chosen = [];
  function label(need, lang){
    var b = chips.filter(function(c){ return c.getAttribute('data-need') === need; })[0];
    var s = b && b.querySelector('.' + lang);
    return s ? s.textContent.trim() : need;
  }
  function list(names, word){
    if (names.length < 2) return names.join('');
    return names.slice(0, -1).join(', ') + ' ' + word + ' ' + names[names.length - 1];
  }
  function apply(fromUser){
    var shown = 0;
    cards.forEach(function(c){
      var needs = (c.getAttribute('data-needs') || '').split(' ');
      var ok = !chosen.length || chosen.some(function(n){ return needs.indexOf(n) !== -1; });
      c.hidden = !ok;
      if (ok) shown++;
    });
    groups.forEach(function(g){ g.hidden = !g.querySelector('.feat:not([hidden])'); });
    index.forEach(function(li){
      var g = document.getElementById('grp-' + li.getAttribute('data-group'));
      li.hidden = !!(g && g.hidden);
    });
    chips.forEach(function(b){
      var n = b.getAttribute('data-need');
      b.setAttribute('aria-pressed', String(n ? chosen.indexOf(n) !== -1 : !chosen.length));
    });
    if (reset) reset.hidden = !chosen.length;
    var total = cards.length;
    var en = chosen.length
      ? 'Showing ' + shown + ' of ' + total + ' features: the ones that help ' + list(chosen.map(function(n){ return label(n, 'en'); }), 'or') + '.'
      : 'Showing all ' + total + ' features.';
    var fil = chosen.length
      ? 'Ipinapakita ang ' + shown + ' sa ' + total + ' feature: ang mga nakakatulong sa ' + list(chosen.map(function(n){ return label(n, 'fil'); }), 'o') + '.'
      : 'Ipinapakita ang lahat ng ' + total + ' feature.';
    if (status) status.innerHTML = '<span class="en"></span><span class="fil"></span>';
    if (status) { status.querySelector('.en').textContent = en; status.querySelector('.fil').textContent = fil; }
    if (fromUser && window.history && history.replaceState) {
      var u = new URL(location.href);
      if (chosen.length) u.searchParams.set('for', chosen.join(',')); else u.searchParams.delete('for');
      history.replaceState(history.state, '', u.pathname + u.search + u.hash);
    }
  }
  chips.forEach(function(b){
    b.addEventListener('click', function(){
      var n = b.getAttribute('data-need');
      if (!n) chosen = [];
      else if (chosen.indexOf(n) === -1) chosen.push(n);
      else chosen.splice(chosen.indexOf(n), 1);
      apply(true);
    });
  });
  if (reset) reset.addEventListener('click', function(){
    chosen = []; apply(true);
    var all = chips.filter(function(c){ return !c.getAttribute('data-need'); })[0];
    if (all) all.focus();
  });
  // ?for=hearing (from Home's presets) picks those needs.
  try {
    var want = (new URL(location.href).searchParams.get('for') || '').split(',');
    chosen = want.filter(function(n){ return known.indexOf(n) !== -1; });
  } catch(e){ chosen = []; }
  // A link to one card (#f-fsl) always shows it, whatever was chosen.
  var target = location.hash && document.getElementById(decodeURIComponent(location.hash.slice(1)));
  if (target && target.classList.contains('feat')) {
    var needs = (target.getAttribute('data-needs') || '').split(' ');
    if (chosen.length && !chosen.some(function(n){ return needs.indexOf(n) !== -1; })) chosen = [];
  }
  apply(false);
  if (target) requestAnimationFrame(function(){ target.scrollIntoView({ block: 'start' }); });
  addEventListener('hashchange', function(){
    var t = document.getElementById(decodeURIComponent(location.hash.slice(1)));
    if (t && t.hidden) { chosen = []; apply(true); t.scrollIntoView({ block: 'start' }); }
  });
})();"""


def build_page():
    page = TEMPLATE.read_text(encoding="utf-8")
    repl = {
        "<!--INDEX-->": render_index(),
        "<!--CHIPS-->": render_filter(),
        "<!--GROUPS-->": render_groups(),
        "<!--PAGEJS-->": PAGE_JS,
        "__COUNT__": str(len(FEATURES)),
    }
    for needle, value in repl.items():
        if needle not in page:
            raise SystemExit(f"features template is missing {needle}")
        page = page.replace(needle, value)
    return page


# ── Quick starts on other pages ────────────────────────────────────────────────────────
QS = re.compile(r"(<!--gen:guide-steps ([A-Za-z]+)/([a-z0-9-]+)-->)(.*?)(<!--/gen:guide-steps-->)", re.S)


def quick_start(gid, sec_slug):
    g = BY_ID.get(gid)
    if not g:
        raise SystemExit(f"quick start: no guide {gid!r}")
    for s in g["sections"]:
        if slug(s["heading"]["en"]) == sec_slug:
            items = "\n".join(f'      <li>{bi2(l["text"]["en"], l["text"]["fil"])}</li>' for l in s["lines"])
            href = "guides.html#" + section_id(gid, s["heading"]["en"])
            return ("\n    <ol class=\"steps\">\n" + items + "\n    </ol>\n"
                    f'    <p class="mt-1"><a class="arrow-link" href="{href}">{bi2("The whole guide, step by step", "Ang buong gabay, hakbang-hakbang")}</a></p>\n    ')
    raise SystemExit(f"quick start: guide {gid!r} has no section {sec_slug!r}")


def apply_quick_starts(check):
    stale = []
    for path in sorted(SITE.glob("*.html")):
        if path.name == OUT.name:
            continue
        raw = path.read_bytes().decode("utf-8")
        if "<!--gen:guide-steps" not in raw:
            continue
        nl = "\r\n" if "\r\n" in raw else "\n"
        new = QS.sub(lambda m: m.group(1) + quick_start(m.group(2), m.group(3)).replace("\n", nl) + m.group(5), raw)
        if new != raw:
            stale.append(path)
            if not check:
                with open(path, "w", encoding="utf-8", newline="") as f:
                    f.write(new)
    return stale


def main():
    check = "--check" in sys.argv
    sm.check()
    ids = [f["id"] for f in FEATURES]
    if len(set(ids)) != len(ids):
        raise SystemExit("features: two cards share an id")
    for f in FEATURES:
        if f["demo"] not in sm.DEMOS:
            raise SystemExit(f"features: card {f['id']} has no demo {f['demo']!r}")
    page = build_page()
    stale = apply_quick_starts(check)
    if check:
        current = OUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUT.exists() else ""
        if current != page.replace("\r\n", "\n"):
            stale.append(OUT)
        for p in stale:
            print(f"stale: {p.relative_to(ROOT)} (run python tools/features_page_build.py)")
        if stale:
            sys.exit(1)
        print(f"{OUT.relative_to(ROOT)} is up to date: {len(FEATURES)} features")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    for p in stale:
        print(f"wrote {p.relative_to(ROOT)} (quick start)")
    from_guides = sum(1 for f in FEATURES for k in ("what", "who", "need", "start") for t in f.get(k, []) if t["ref"])
    print(f"wrote {OUT.relative_to(ROOT)}: {len(FEATURES)} features in {len(GROUPS)} groups, {from_guides} lines from the app's guides")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
