"""The website's "See it in action" media: one list, used everywhere.

Every video part and every app picture the website shows next to a feature is listed here
ONCE. tools/features_page_build.py (website/features.html) and tools/guides_page_build.py
(website/guides.html) both draw a demo from this list, so a feature card and its guide
always show the same thing, from the same file. Nothing here is a copy of a video: a clip
is a start and an end inside one of the site's existing videos.

  VIDEOS    the site's silent demo videos (English and Filipino captions beside them)
  CLIPS     a part of one video: (video, start s, end s)
  PICTURES  screenshots of the real app (website/assets/features/*.webp), taken on an
            Android emulator by integration_test/site_pictures_test.dart and converted
            by tools/site_pictures_build.py
  DEMOS     what one "See it in action" shows: a clip and/or pictures, or words only

"What you see" under a clip is the clip's own captions (the .vtt cues inside it), in both
languages, so the description can never disagree with the video.
"""
import html, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "website")

# The videos (all 720 x 1126, silent; recorded on the owner's Android tablet).
VIDEOS = {
    "gaze": {"file": "assets/videos/gaze-demo.mp4", "w": 720, "h": 1126, "length": 53.9, "version": "1.2.6",
             "vtt": {"en": "assets/videos/gaze-demo.en.vtt", "fil": "assets/videos/gaze-demo.fil.vtt"}},
    "tour": {"file": "assets/videos/app-demo.mp4", "w": 720, "h": 1126, "length": 81.5, "version": "1.2.1",
             "vtt": {"en": "assets/videos/app-demo.en.vtt", "fil": "assets/videos/app-demo.fil.vtt"}},
}

# Parts of a video. The times are the caption cue boundaries, so a part starts and ends
# where its captions do.
CLIPS = {
    "gaze-head":   ("gaze", 0.0, 23.9),    # head turns move the highlight; a blink opens
    "gaze-switch": ("gaze", 23.9, 38.3),   # scanning with one switch, camera off
    "gaze-talk":   ("gaze", 38.3, 53.9),   # the Talk Board with one switch
    "tour-cards":  ("tour", 17.3, 26.5),   # decks, a card, the flip
    "tour-fsl":    ("tour", 26.5, 37.9),   # the FSL button plays the sign, with replay and speed
    "tour-auto":   ("tour", 37.9, 46.3),   # Games: "Auto" picks a difficulty from recent accuracy
    "tour-game":   ("tour", 46.3, 60.3),   # choosing categories, then Word Match
    "tour-talk":   ("tour", 66.3, 77.0),   # the Talk Board, then the same board in Filipino
    "tour-all":    ("tour", 0.0, 81.5),    # the whole 81-second app tour
}

# Screenshots of the real app, 600 x 800. alt = (English, Filipino); cap = a short caption.
PICTURES = {}   # filled in below by pic()


def pic(key, file, alt_en, alt_fil, cap_en=None, cap_fil=None):
    PICTURES[key] = {"src": f"assets/features/{file}", "alt": (alt_en, alt_fil),
                     "cap": (cap_en, cap_fil) if cap_en else None}


pic("gaze", "gaze.webp",
    "The Gaze Control settings: a short explanation, the Enable Gaze Control switch (off here, so only touch works), the Try it now button, and how far the hands-free control reaches.",
    "Ang settings ng Gaze Control: maikling paliwanag, ang switch na Enable Gaze Control (nakapatay dito, kaya pindot lang ang gumagana), ang button na Try it now, at kung hanggang saan aabot ang hands-free na kontrol.")
pic("voice", "voice.webp",
    "The Voice part of the Gaze Control settings: Voice commands, with the words to say, Voice only (camera off), and Read the highlight aloud.",
    "Ang bahaging Voice ng settings ng Gaze Control: Voice commands, kasama ang mga salitang sasabihin, Voice only (nakapatay ang camera), at Read the highlight aloud.")
pic("switch-choose", "switch-choose.webp",
    "How to choose, in the Gaze Control settings: a blink, a switch or controller button, or either one.",
    "Paano pumili, sa settings ng Gaze Control: pagkurap, switch o button ng controller, o alinman sa dalawa.",
    "How to choose", "Paano pumili")
pic("switch-scan", "switch-scan.webp",
    "The Scanning mode switch, where buttons light up in turn, and the resting position for a head that rests turned or tilted.",
    "Ang switch na Scanning mode, kung saan sunod-sunod na umiilaw ang mga button, at ang resting position para sa ulong nakatagilid o nakabaling.",
    "Scanning mode", "Scanning mode")
pic("controller", "controller.webp",
    "The Game Controller settings with no controller paired yet: Practise the buttons, Enable controller, Say what is happening, Speech speed and Read each item.",
    "Ang settings ng Game Controller na wala pang naka-pair na controller: Practise the buttons, Enable controller, Say what is happening, Speech speed at Read each item.")
pic("look-normal", "look-normal.webp",
    "A flashcard at the normal look: a dog, the words Dog and Aso, and the English and Filipino sound buttons.",
    "Isang flashcard sa karaniwang itsura: isang aso, ang mga salitang Dog at Aso, at ang mga sound button sa English at Filipino.",
    "Normal", "Karaniwan")
pic("look-large", "look-large.webp",
    "The same flashcard with Extra Large text and High Contrast Mode: white words on black, and bigger words and buttons.",
    "Ang parehong flashcard na may Extra Large na letra at High Contrast Mode: puting salita sa itim, at mas malalaking salita at button.",
    "Bigger text + high contrast", "Mas malaking letra + mataas na contrast")
pic("look-dark", "look-dark.webp",
    "The same flashcard in Dark Mode, on a dark blue background.",
    "Ang parehong flashcard sa Dark Mode, sa madilim na asul na background.",
    "Dark mode", "Dark mode")
pic("look-dyslexia", "look-dyslexia.webp",
    "The same flashcard with Dyslexia-friendly on: a cream background and an easier-to-read font.",
    "Ang parehong flashcard na naka-on ang Dyslexia-friendly: kulay-krema na background at mas madaling basahing font.",
    "Dyslexia-friendly", "Para sa may dyslexia")
pic("read-card", "read-card.webp",
    "A flashcard with its big English and Filipino speaker buttons, which say the word, and the FSL button.",
    "Isang flashcard na may malalaking speaker button sa English at Filipino, na nagsasabi ng salita, at ang FSL button.",
    "Tap a speaker to hear the word", "I-tap ang speaker para marinig ang salita")
pic("read-settings", "read-settings.webp",
    "The Audio settings: Text-to-Speech on, Speech Speed set to slow, the Filipino voice, Sound Effects and Speech-to-Text.",
    "Ang settings ng Audio: naka-on ang Text-to-Speech, mabagal ang Speech Speed, ang boses na Filipino, Sound Effects at Speech-to-Text.",
    "Settings: Text-to-Speech and Speech Speed", "Settings: Text-to-Speech at Speech Speed")
pic("adaptive", "adaptive.webp",
    "The Learning Modes settings: Adaptive Difficulty on (it suggests a difficulty based on progress), Slow-Motion Mode, Learning Assist and Daily Mission Size.",
    "Ang settings ng Learning Modes: naka-on ang Adaptive Difficulty (nagmumungkahi ito ng antas ng hirap batay sa progreso), Slow-Motion Mode, Learning Assist at Daily Mission Size.",
    "Settings: Learning Modes", "Settings: Learning Modes")
pic("break-learner", "break-learner.webp",
    "The break reminder on a learner's tablet: “Time for a short break. You have been learning for 20 minutes. Rest your eyes, stretch, or drink some water. Learning time left today: 25 minutes.” Buttons: Keep learning and Take a break.",
    "Ang paalala na magpahinga sa tablet ng mag-aaral: “Oras na para sa maikling pahinga.” Sinasabi nito kung gaano na katagal ang pag-aaral at ang natitirang oras ngayong araw. Mga button: Magpatuloy sa pag-aaral at Magpahinga.",
    "What the learner sees", "Ang nakikita ng mag-aaral")
pic("break-adult", "break-adult.webp",
    "A learner's Time limits, set by a teacher or parent: Remind them to take a break is on, after every 20 minutes of learning, with the warning before the lock below.",
    "Ang Time limits ng isang mag-aaral, na itinakda ng guro o magulang: naka-on ang Ipaalala na magpahinga, bawat 20 minuto ng pag-aaral, kasama ang babala bago ang lock sa ibaba.",
    "What the teacher or parent sets", "Ang itinatakda ng guro o magulang")
pic("my-day", "my-day.webp",
    "My Day for a learner with no plan yet: “Plan your day. My Day shows your plan for the day, one step at a time, with pictures and times,” and a Build my routine button.",
    "Ang Aking Araw para sa mag-aaral na wala pang plano: “Planuhin ang iyong araw,” isang hakbang bawat pagkakataon, may larawan at oras, at isang button na Build my routine.",
    "The learner’s My Day", "Ang Aking Araw ng mag-aaral")
pic("my-day-adult", "my-day-adult.webp",
    "A teacher's Routines page for the learner Ana: build a daily routine, starting from a ready-made template, with a Create a routine button.",
    "Ang pahina ng Routines ng guro para sa mag-aaral na si Ana: bumuo ng araw-araw na routine, simula sa isang handang template, may button na Create a routine.",
    "What the teacher or parent sets up", "Ang inihahanda ng guro o magulang")
pic("talk-board", "talk-board.webp",
    "The Talk Board: the sentence Hello, Good morning built from picture tiles at the top, category tabs such as Greetings, Needs, Feelings and Actions, and greeting tiles.",
    "Ang Talk Board: ang pangungusap na Hello, Good morning na binuo mula sa mga larawang tile sa itaas, mga tab ng kategorya gaya ng Greetings, Needs, Feelings at Actions, at mga tile ng pagbati.")
pic("teacher-home", "teacher-home.webp",
    "A teacher's Home: the number of students, those active today and their average words, the Teacher Dashboard, and quick actions such as All Students (roster and progress) and Analytics.",
    "Ang Home ng guro: bilang ng mga estudyante, ang mga aktibo ngayon at ang karaniwang bilang ng salita, ang Teacher Dashboard, at mga mabilisang gawain gaya ng All Students (roster at progreso) at Analytics.")
pic("assign", "assign.webp",
    "Assign Assessment before any learner has joined: it asks the teacher to share the class code first, then assign the work.",
    "Ang Assign Assessment bago sumali ang sinumang mag-aaral: hinihiling nito sa guro na ibahagi muna ang class code, saka ibigay ang gawain.")
pic("time-limits", "time-limits.webp",
    "A learner's Time limits: what the learner gets at lock time (a warning banner, an alarm chime, a spoken message, a picture of who to hand the tablet to), the recommended 60 minutes a day, the daily limit and the allowed schedule.",
    "Ang Time limits ng isang mag-aaral: ang matatanggap niya sa oras ng lock (babalang banner, tunog ng alarma, sinasabing mensahe, larawan ng pagbibigyan ng tablet), ang inirerekomendang 60 minuto bawat araw, ang araw-araw na limitasyon at ang pinapayagang iskedyul.")
pic("tv-cast", "tv-cast.webp",
    "The TV Cast screen: Cast to any TV with a web browser, a Start Casting button, and the class or group to cast for.",
    "Ang screen ng TV Cast: Cast to any TV na may web browser, isang button na Start Casting, at ang klase o grupong paglalaanan ng cast.")
pic("decks", "decks.webp",
    "The flashcard decks: big colourful cards for Animals, Colors and Shapes, Numbers, Body Parts, Food and Drinks, and Family and Greetings.",
    "Ang mga flashcard deck: malalaki at makukulay na card para sa Animals, Colors and Shapes, Numbers, Body Parts, Food and Drinks, at Family and Greetings.")
pic("games", "games.webp",
    "The Games tab: a Play Together banner and colourful cards for Word Match, Spelling Bee, Memory Match, Drag and Drop and more.",
    "Ang tab na Games: isang banner ng Play Together at makukulay na card para sa Word Match, Spelling Bee, Memory Match, Drag and Drop at iba pa.")
pic("stories", "stories.webp",
    "The Stories tab: story cards grouped by topic, such as A Day at the Farm and The Rainbow Garden, each with a difficulty tag and the reading time.",
    "Ang tab na Stories: mga card ng kuwento na nakapangkat ayon sa paksa, gaya ng A Day at the Farm at The Rainbow Garden, bawat isa may antas ng hirap at tagal ng pagbasa.")
pic("buddy", "buddy.webp",
    "A learner's Home, “Hi, Ana!”, with the round AI Buddy button floating at the bottom right of the screen.",
    "Ang Home ng mag-aaral, “Hi, Ana!”, na may bilog na AI Buddy button na nakalutang sa kanang ibaba ng screen.")

# What each "See it in action" shows. "say" = words only (no picture can show it).
DEMOS = {
    "gaze":        {"clip": "gaze-head", "pics": ["gaze"]},
    "voice":       {"pics": ["voice"]},
    "controller":  {"pics": ["controller"]},
    "switch":      {"clip": "gaze-switch", "pics": ["switch-choose", "switch-scan"]},
    "looks":       {"pics": ["look-normal", "look-large", "look-dark", "look-dyslexia"], "compare": True},
    "read":        {"pics": ["read-card", "read-settings"]},
    "screen-reader": {"say": True},
    "fsl":         {"clip": "tour-fsl"},
    "adaptive":    {"clip": "tour-auto", "pics": ["adaptive"]},
    "breaks":      {"pics": ["break-learner", "break-adult"]},
    "my-day":      {"pics": ["my-day", "my-day-adult"]},
    "talk-board":  {"clip": "tour-talk", "pics": ["talk-board"]},
    "classes":     {"pics": ["teacher-home"]},
    "assign":      {"pics": ["assign"]},
    "time-limits": {"pics": ["time-limits", "break-adult"]},
    "tv-cast":     {"pics": ["tv-cast"]},
    "cards":       {"clip": "tour-cards", "pics": ["decks"]},
    "games":       {"clip": "tour-game", "pics": ["games"]},
    "stories":     {"pics": ["stories"]},
    "buddy":       {"pics": ["buddy"]},
    "tour":        {"clip": "tour-all"},
}


# ── helpers ────────────────────────────────────────────────────────────────────────────
def esc(s):
    return html.escape(s, quote=True)


def bi(en, fil):
    return f'<span class="en">{esc(en)}</span><span class="fil">{esc(fil)}</span>'


def mmss(seconds):
    s = int(round(seconds))
    return f"{s // 60}:{s % 60:02d}"


def size_mb(path):
    return f"{os.path.getsize(os.path.join(SITE, path)) / 1e6:.1f} MB"


def image_size(path):
    """Width and height of a WebP or PNG (read from the file header)."""
    with open(os.path.join(SITE, path), "rb") as f:
        head = f.read(64)
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        chunk = head[12:16]
        if chunk == b"VP8X":
            w = 1 + int.from_bytes(head[24:27], "little")
            h = 1 + int.from_bytes(head[27:30], "little")
            return w, h
        if chunk == b"VP8 ":
            w = int.from_bytes(head[26:28], "little") & 0x3FFF
            h = int.from_bytes(head[28:30], "little") & 0x3FFF
            return w, h
        if chunk == b"VP8L":
            b = int.from_bytes(head[21:25], "little")
            return (b & 0x3FFF) + 1, ((b >> 14) & 0x3FFF) + 1
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")
    raise SystemExit(f"site_media: cannot read the size of {path}")


_CUES = {}


def cues(video, lang):
    """[(start, end, text)] of a video's captions in one language."""
    key = (video, lang)
    if key not in _CUES:
        text = open(os.path.join(SITE, VIDEOS[video]["vtt"][lang]), encoding="utf-8").read()
        out = []
        for m in re.finditer(r"(\d+):(\d+\.\d+)\s+-->\s+(\d+):(\d+\.\d+)[^\n]*\n(.+?)(?:\n\n|\Z)", text, re.S):
            a = int(m.group(1)) * 60 + float(m.group(2))
            b = int(m.group(3)) * 60 + float(m.group(4))
            out.append((a, b, " ".join(m.group(5).split())))
        _CUES[key] = out
    return _CUES[key]


def clip_words(clip, lang):
    video, a, b = CLIPS[clip]
    return " ".join(t for s, e, t in cues(video, lang) if s >= a - 0.05 and e <= b + 0.05)


def check():
    """Every file a demo uses exists, and every clip has captions in both languages."""
    problems = []
    for v in VIDEOS.values():
        for p in [v["file"], *v["vtt"].values()]:
            if not os.path.exists(os.path.join(SITE, p)):
                problems.append(f"missing {p}")
    for key, d in DEMOS.items():
        for k in d.get("pics", []):
            if k not in PICTURES:
                problems.append(f"demo {key}: no picture {k!r}")
            elif not os.path.exists(os.path.join(SITE, PICTURES[k]["src"])):
                problems.append(f"demo {key}: missing {PICTURES[k]['src']}")
        if "clip" in d:
            c = d["clip"]
            if c not in CLIPS:
                problems.append(f"demo {key}: no clip {c!r}")
                continue
            poster = f"assets/features/poster-{c}.webp"
            if not os.path.exists(os.path.join(SITE, poster)):
                problems.append(f"demo {key}: missing {poster}")
            for lang in ("en", "fil"):
                if not clip_words(c, lang):
                    problems.append(f"clip {c}: no {lang} captions inside it")
    if problems:
        raise SystemExit("site_media: " + "; ".join(problems))


# ── one "See it in action" ─────────────────────────────────────────────────────────────
def render_demo(key, name_en, name_fil, uid, say=None, indent="        "):
    """A closed <details>: nothing inside loads until it is opened (pictures are lazy; a
    video is made only when its Play button is pressed). Works without JavaScript: the
    pictures show, and the video opens as a file. `say` = (en, fil) words for a demo that
    is described rather than shown."""
    d = DEMOS[key]
    I = indent
    kinds_en, kinds_fil = [], []
    body = []
    if "clip" in d:
        video, a, b = CLIPS[d["clip"]]
        v = VIDEOS[video]
        length = mmss(b - a)
        kinds_en.append(f"Video {length}")
        kinds_fil.append(f"Video {length}")
        src = v["file"]
        frag = f"#t={a:g},{b:g}"
        poster = f"assets/features/poster-{d['clip']}.webp"
        pw, ph = image_size(poster)
        mb = size_mb(src)
        body.append(
            f'{I}  <div class="demo-clip" data-src="{src}" data-start="{a:g}" data-end="{b:g}" '
            f'data-vtt-en="{v["vtt"]["en"]}" data-vtt-fil="{v["vtt"]["fil"]}" '
            f'data-name-en="{esc("Video: " + name_en)}" data-name-fil="{esc("Video: " + name_fil)}" '
            f'style="--ar:{v["w"]}/{v["h"]}">')
        body.append(
            f'{I}    <button type="button" class="demo-play needs-js">'
            f'<img src="{poster}" width="{pw}" height="{ph}" alt="" loading="lazy" decoding="async">'
            f'<span class="demo-play-btn"><span class="demo-play-ico" aria-hidden="true">▶</span> '
            f'{bi("Play the video", "I-play ang video")} <span class="demo-len">{length}</span>'
            f'<span class="sr-only"> — {bi(name_en, name_fil)}</span></span></button>')
        body.append(
            f'{I}    <a class="demo-file nojs-only" href="{src}{frag}">{bi("Open the video", "Buksan ang video")} ({length})</a>')
        body.append(f'{I}  </div>')
        body.append(
            f'{I}  <p class="demo-facts">{bi(f"{length} · no sound · captions in English and Filipino · uses up to {mb} of data · filmed on app version {v['version']}", f"{length} · walang tunog · may caption sa English at Filipino · gagamit ng hanggang {mb} na data · kinunan sa app version {v['version']}")}</p>')
        body.append(
            f'{I}  <div class="demo-what"><p><strong>{bi("What you see:", "Ang makikita mo:")}</strong> '
            f'{bi(clip_words(d["clip"], "en"), clip_words(d["clip"], "fil"))}</p></div>')
    pics = d.get("pics", [])
    if pics:
        kinds_en.append("Picture" if len(pics) == 1 else f"{len(pics)} pictures")
        kinds_fil.append("Larawan" if len(pics) == 1 else f"{len(pics)} larawan")
        cls = "demo-pics compare" if d.get("compare") else "demo-pics"
        body.append(f'{I}  <div class="{cls}" data-count="{len(pics)}">')
        for k in pics:
            p = PICTURES[k]
            w, h = image_size(p["src"])
            en, fil = p["alt"]
            cap = (f'<figcaption>{bi(*p["cap"])}</figcaption>') if p["cap"] else ""
            body.append(
                f'{I}    <figure class="demo-pic"><img class="zoomable" src="{p["src"]}" width="{w}" height="{h}" '
                f'loading="lazy" decoding="async" alt="{esc(en)}" data-label-en="{esc(en)}" data-label-fil="{esc(fil)}">{cap}</figure>')
        body.append(f'{I}  </div>')
        if "clip" not in d:
            body.append(f'{I}  <p class="demo-facts">{bi("Pictures of the real app (version 1.4.6). Select a picture to make it bigger.", "Mga larawan ng totoong app (version 1.4.6). Piliin ang larawan para lumaki ito.")}</p>')
    if d.get("say"):
        if not say:
            raise SystemExit(f"site_media: demo {key} is described in words, and no words were given")
        kinds_en.append("Described in words")
        kinds_fil.append("Inilalarawan sa salita")
        body.append(f'{I}  <div class="demo-what"><p>{bi(*say)}</p></div>')
    sum_kind = bi(" · ".join(kinds_en), " · ".join(kinds_fil))
    return "\n".join([
        f'{I}<details class="demo" id="demo-{uid}">',
        f'{I}  <summary class="demo-sum"><span class="demo-sum-ico" aria-hidden="true">▶</span>'
        f'<span class="demo-sum-text">{bi("See it in action", "Tingnan kung paano ito gumagana")}'
        f'<span class="sr-only">: {bi(name_en, name_fil)}</span></span>'
        f'<span class="demo-kind">{sum_kind}</span></summary>',
        f'{I}  <div class="demo-body">',
        *body,
        f'{I}  </div>',
        f'{I}</details>',
    ])
