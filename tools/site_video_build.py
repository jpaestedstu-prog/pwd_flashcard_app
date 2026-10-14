"""Make the website's videos: the home page film (English and Filipino, wide
and upright-for-phones), its two posters, and the app preview that plays
inside the phone at the top of the home page.

    python tools/site_video_build.py              # everything (about 25 min)
    python tools/site_video_build.py --check      # fast: the page and the files agree
    python tools/site_video_build.py --stills     # one picture per scene per version
    python tools/site_video_build.py --page       # rewrite only the film section
    python tools/site_video_build.py --only film --lang en --shape wide
    python tools/site_video_build.py --only hero | posters

How the film is made. tools/site_video/stage.html links the website's own
stylesheet, so the film is drawn with the site's fonts, colours, tiles and
buttons. Headless Chrome draws it one frame at a time (stage.js is a pure
function of time) and ffmpeg encodes the frames. That keeps it on-brand
when the site changes, and makes it re-renderable instead of hand-edited:

  * the words are in COPY below, which also writes the "Read what the film
    shows" transcript on the page, so the film and the text cannot disagree;
  * the numbers (177 words, 15 games ...) come from the home page's stats
    band — change them there and re-run;
  * the app on screen is real: frames cut from the tablet recording
    website/assets/videos/app-demo.mp4 (FOOTAGE / HERO below).

The section in website/index.html between <!--gen:site-film--> markers is
written here (sizes of the download links included); never edit it by hand.
After a re-render, run tools/site_chrome_build.py if site.css/site.js changed.
Needs: Google Chrome (or Edge) and ffmpeg. Free, local, no network.
"""
import argparse, base64, html, http.server, functools, json, os, re, shutil, socket, struct, subprocess
import sys, tempfile, threading, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "website")
VIDEOS = os.path.join(SITE, "assets", "videos")
INDEX = os.path.join(SITE, "index.html")
STAGE_URL_PATH = "tools/site_video/stage.html"
BUILD = os.path.join(ROOT, "build", "site_video")
DEMO = os.path.join(VIDEOS, "app-demo.mp4")
FPS = 30

# ---------------------------------------------------------------- the footage
# Cut from app-demo.mp4 (the 81-second tablet recording on How to Use).
# ss/len in seconds; mark = seconds into the clip of a moment the film waits
# for (the pill beside the phone appears exactly then).
FOOTAGE = {
    "cards":    {"ss": 21.0, "len": 5.4},              # the Dog card, turned over at 24.3
    "fsl":      {"ss": 27.4, "len": 6.2},              # the card's FSL video: the sign for Dog
    "games":    {"ss": 53.2, "len": 6.2, "mark": 1.8},  # Word Match: "Butterfly" turns green at 55.0
    "talk":     {"ss": 68.4, "len": 5.6, "mark": 3.2},  # Talk Board: "I am thirsty" joins "Hello" at 71.6
    "progress": {"ss": 77.8, "len": 3.7},              # the Progress tab (after its page change)
}
# The app preview in the home page's phone: these pieces in turn, faded into
# one another, and back to the first so it loops without a jump.
HERO = [("home", 5.6, 3.0), ("cards", 21.0, 4.8), ("fsl", 27.6, 4.4), ("games", 53.2, 4.6), ("talk", 68.4, 5.4)]
HERO_FADE = 0.6

# ---------------------------------------------------------------- the words
# {words} {decks} {games} {signs} come from the home page's stats band.
# **x** = the site's purple-to-pink gradient; <acc>x</acc> = a Filipino word.
COPY = {
    "en": {
        "tag": ["Learning made joyful,", "**for every child.**"],
        "intro": {
            "eyebrow": "Free · English & Filipino · Android",
            "title": "A free learning app for children with disabilities",
            "line": "Flashcards, sign language, games and stories that adapt to each learner.",
        },
        "cards": {"tone": "purple", "icon": "🃏", "label": "Bilingual flashcards",
                  "title": "**{words}** words · **{decks}** decks",
                  "line": "Pictures, real photos and spoken English & Filipino.",
                  "pill": "🐶 Dog · <acc>Aso</acc>"},
        "fsl": {"tone": "teal", "icon": "🤟", "label": "Filipino Sign Language",
                "title": "**{signs}** sign videos",
                "line": "Watch everyday words signed. Slow them down, play them again.",
                "pill": "🐢 Slow · 🔁 Replay"},
        "games": {"tone": "pink", "icon": "🎮", "label": "Learning games",
                  "title": "**{games}** games",
                  "line": "Ten for each accessibility profile, at a level that adapts.",
                  "pill": "<acc>Paru-paro</acc> → Butterfly <ok>✓</ok>"},
        "talk": {"tone": "orange", "icon": "💬", "label": "Talk Board",
                 "title": "Tap pictures, **make a sentence**",
                 "line": "The tablet says it aloud: a voice for learners who don’t speak yet.",
                 "pill": "🔊 “Hello. I am thirsty.”"},
        "learn": {"title": "Made for **every** kind of learner",
                  "line": "Choose a preset and the whole app sets itself up.",
                  "items": [
                      {"tone": "blue", "icon": "👁️", "name": "Visual", "sub": "Large text, voice guide"},
                      {"tone": "teal", "icon": "👂", "name": "Hearing", "sub": "Sign videos, pictures first"},
                      {"tone": "orange", "icon": "🦽", "name": "Motor", "sub": "Gaze, voice, big buttons"},
                      {"tone": "pink", "icon": "🧠", "name": "Cognitive", "sub": "Calm, short, adaptive"},
                      {"tone": "purple", "icon": "🤝", "name": "Multiple", "sub": "Every support together"},
                  ]},
        "teach": {"tone": "blue", "icon": "🧑‍🏫", "label": "For teachers & parents",
                  "title": "Follow **every step**",
                  "line": "Classes, progress reports, pre- and post-tests, and messages home.",
                  "pill": "📊 Progress reports"},
        "end": {"title": "Ready to start learning?",
                "chips": ["🆓 100% free", "🚫 No ads", "🔓 No login", "📴 Works offline"],
                "button": "⬇️ Download free",
                "sub": "For Android 10 and newer",
                "qr": "Scan to open the website",
                "url": "jpaestedstu-prog.github.io/pwd_flashcard_app"},
        # What the transcript says the screen shows, scene by scene.
        "shows": {
            "open": "The FlashLearn PWD logo.",
            "intro": "On a tablet: the app’s Home screen.",
            "cards": "A learner opens the Dog card (Aso in Filipino) and turns it over.",
            "fsl": "The card’s sign video plays: the FSL sign for Dog.",
            "games": "In Word Match, the learner picks Butterfly for “Paru-paro”, and it turns green.",
            "talk": "On the Talk Board, the learner taps “Hello” and “I am thirsty”, and the tablet reads the sentence aloud.",
            "learn": "Five cards, one for each preset.",
            "teach": "The learner’s Progress screen: streak, stars, words learned and level.",
            "end": "A QR code that opens this website.",
        },
    },
    "fil": {
        "tag": ["Masayang pagkatuto,", "**para sa bawat bata.**"],
        "intro": {
            "eyebrow": "Libre · English at Filipino · Android",
            "title": "Libreng app sa pag-aaral para sa mga batang may kapansanan",
            "line": "Flashcards, sign language, mga laro at kuwentong umaangkop sa bawat mag-aaral.",
        },
        "cards": {"tone": "purple", "icon": "🃏", "label": "Bilingual na flashcards",
                  "title": "**{words}** salita · **{decks}** deck",
                  "line": "May larawan, totoong litrato, at binibigkas sa English at Filipino.",
                  "pill": "🐶 Dog · <acc>Aso</acc>"},
        "fsl": {"tone": "teal", "icon": "🤟", "label": "Filipino Sign Language",
                "title": "**{signs}** video ng senyas",
                "line": "Panoorin ang senyas ng mga salita. Pabagalin, ulitin.",
                "pill": "🐢 Mabagal · 🔁 Ulitin"},
        "games": {"tone": "pink", "icon": "🎮", "label": "Mga larong pampag-aaral",
                  "title": "**{games}** laro",
                  "line": "Sampu para sa bawat accessibility profile, sa antas na umaangkop.",
                  "pill": "<acc>Paru-paro</acc> → Butterfly <ok>✓</ok>"},
        "talk": {"tone": "orange", "icon": "💬", "label": "Talk Board",
                 "title": "Mag-tap ng larawan, **bumuo ng pangungusap**",
                 "line": "Binibigkas ito ng tablet: boses para sa mga mag-aaral na hindi pa nagsasalita.",
                 "pill": "🔊 “Hello. I am thirsty.”"},
        "learn": {"title": "Para sa **bawat** uri ng mag-aaral",
                  "line": "Pumili ng preset at kusang mag-aayos ang buong app.",
                  "items": [
                      {"tone": "blue", "icon": "👁️", "name": "Paningin", "sub": "Malaking letra, gabay na boses"},
                      {"tone": "teal", "icon": "👂", "name": "Pandinig", "sub": "Video ng senyas, larawan muna"},
                      {"tone": "orange", "icon": "🦽", "name": "Paggalaw", "sub": "Tingin, boses, malaking button"},
                      {"tone": "pink", "icon": "🧠", "name": "Kognitibo", "sub": "Kalmado, maikli, umaangkop"},
                      {"tone": "purple", "icon": "🤝", "name": "Maramihan", "sub": "Lahat ng suporta nang sabay"},
                  ]},
        "teach": {"tone": "blue", "icon": "🧑‍🏫", "label": "Para sa guro at magulang",
                  "title": "Subaybayan ang **bawat hakbang**",
                  "line": "Mga klase, progress report, pre-test at post-test, at mensahe sa tahanan.",
                  "pill": "📊 Ulat ng progreso"},
        "end": {"title": "Handa nang matuto?",
                "chips": ["🆓 100% libre", "🚫 Walang ads", "🔓 Walang login", "📴 Gumagana offline"],
                "button": "⬇️ I-download nang libre",
                "sub": "Para sa Android 10 pataas",
                "qr": "I-scan para mabuksan ang website",
                "url": "jpaestedstu-prog.github.io/pwd_flashcard_app"},
        "shows": {
            "open": "Ang logo ng FlashLearn PWD.",
            "intro": "Sa isang tablet: ang Home screen ng app.",
            "cards": "Binuksan ng mag-aaral ang kard na Dog (Aso sa Filipino) at binaligtad ito.",
            "fsl": "Lumabas ang video ng senyas ng kard: ang senyas sa FSL para sa Dog.",
            "games": "Sa Word Match, pinili ng mag-aaral ang Butterfly para sa “Paru-paro”, at naging berde ito.",
            "talk": "Sa Talk Board, pinindot ng mag-aaral ang “Hello” at “I am thirsty”, at binasa nang malakas ng tablet ang pangungusap (sa Filipino: “Kamusta. Nauuhaw ako.”).",
            "learn": "Limang kard, isa para sa bawat preset.",
            "teach": "Ang screen na Progress ng mag-aaral: streak, stars, mga natutunang salita at level.",
            "end": "Isang QR code na nagbubukas ng website na ito.",
        },
    },
}
SCENES = ["open", "intro", "cards", "fsl", "games", "talk", "learn", "teach", "end"]
# For search engines (schema.org VideoObject). Change FILM_DATE when the film
# is re-rendered with new content and published again.
SITE_URL = "https://jpaestedstu-prog.github.io/pwd_flashcard_app/"
FILM_DATE = "2026-10-14"

# Size budgets for what visitors download (bytes). The film only loads when
# someone presses Play; the preview loads on its own, so it must stay small.
BUDGET = {"film": 5_500_000, "hero": 1_600_000, "poster": 120_000}


def fail(msg):
    sys.exit(f"site_video_build: {msg}")


# ---------------------------------------------------------------- tools
def find_ffmpeg(name="ffmpeg"):
    p = shutil.which(name)
    if p:
        return p
    for c in (rf"C:\ffmpeg\bin\{name}.exe",):
        if os.path.isfile(c):
            return c
    fail(f"{name} not found (install ffmpeg, or put it at C:\\ffmpeg\\bin)")


def find_chrome():
    for c in (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
              shutil.which("google-chrome") or "", shutil.which("chromium") or ""):
        if c and os.path.isfile(c):
            return c
    fail("Google Chrome or Microsoft Edge is needed to draw the film")


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        fail(f"{os.path.basename(cmd[0])} failed:\n{r.stderr[-2000:]}")
    return r.stdout


# ---------------------------------------------------------------- the page's numbers
def site_stats():
    text = open(INDEX, encoding="utf-8").read()
    found = dict((label, int(n)) for n, label in re.findall(
        r'<div class="stat"><b>(\d+)</b><span><span class="en">([^<]+)</span>', text))
    want = {"words": "Words to learn", "decks": "Flashcard decks", "games": "Learning games",
            "signs": "FSL sign videos"}
    out = {}
    for key, label in want.items():
        if label not in found:
            fail(f"index.html stats band has no “{label}” — the film takes its numbers from there")
        out[key] = found[label]
    return out


def copy_for(lang, stats):
    """COPY[lang] with the numbers filled in."""
    def fill(v):
        if isinstance(v, str):
            return v.format(**stats)
        if isinstance(v, list):
            return [fill(x) for x in v]
        if isinstance(v, dict):
            return {k: fill(x) for k, x in v.items()}
        return v
    return fill(COPY[lang])


# ---------------------------------------------------------------- a tiny CDP client
class _WS:
    def __init__(self, url):
        hostport, path = url[5:].split("/", 1)
        host, port = hostport.split(":")
        self.s = socket.create_connection((host, int(port)))
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\nUpgrade: websocket\r\n"
                        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            buf += self.s.recv(4096)
        self.buf = buf.split(b"\r\n\r\n", 1)[1]
        self.partial = b""

    def send(self, text):
        data = text.encode()
        hdr = bytearray([0x81])
        n = len(data)
        if n < 126:
            hdr.append(0x80 | n)
        elif n < 65536:
            hdr.append(0x80 | 126); hdr += struct.pack(">H", n)
        else:
            hdr.append(0x80 | 127); hdr += struct.pack(">Q", n)
        mask = os.urandom(4)
        self.s.sendall(bytes(hdr) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def _frame(self):
        b = self.buf
        if len(b) < 2:
            return None
        n, off = b[1] & 0x7F, 2
        if n == 126:
            if len(b) < 4:
                return None
            n, off = struct.unpack(">H", b[2:4])[0], 4
        elif n == 127:
            if len(b) < 10:
                return None
            n, off = struct.unpack(">Q", b[2:10])[0], 10
        if len(b) < off + n:
            return None
        self.buf = b[off + n:]
        return b[0] & 0x80, b[0] & 0x0F, b[off:off + n]

    def recv(self):
        while True:
            f = self._frame()
            if f is None:
                chunk = self.s.recv(1 << 20)
                if not chunk:
                    raise ConnectionError("Chrome closed the connection")
                self.buf += chunk
                continue
            fin, op, payload = f
            if op == 9:
                continue
            self.partial += payload
            if fin:
                msg, self.partial = self.partial, b""
                return msg.decode("utf-8", "replace")


class Chrome:
    def __init__(self, width, height):
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0)); port = s.getsockname()[1]
        self.profile = tempfile.mkdtemp(prefix="flpv")
        self.proc = subprocess.Popen([
            find_chrome(), "--headless=new", f"--remote-debugging-port={port}", f"--user-data-dir={self.profile}",
            "--hide-scrollbars", "--no-first-run", "--mute-audio", "--force-color-profile=srgb",
            "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
            f"--window-size={width},{height}", "about:blank"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        page = None
        for _ in range(150):
            try:
                tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json"))
                page = [t for t in tabs if t["type"] == "page"][0]
                break
            except Exception:
                time.sleep(0.2)
        if not page:
            fail("Chrome did not start")
        self.ws = _WS(page["webSocketDebuggerUrl"])
        self.id = 0
        self.errors = []
        for m in ("Page.enable", "Runtime.enable", "Log.enable"):
            self.cmd(m)

    def cmd(self, method, **params):
        self.id += 1
        mid = self.id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get("id") == mid:
                if "error" in m:
                    raise RuntimeError(f"{method}: {m['error']}")
                return m.get("result", {})
            meth = m.get("method")
            if meth == "Runtime.exceptionThrown":
                d = m["params"]["exceptionDetails"]
                self.errors.append(str(d.get("exception", {}).get("description", d.get("text"))))
            elif meth == "Log.entryAdded" and m["params"]["entry"]["level"] == "error":
                self.errors.append(m["params"]["entry"].get("text", "") + " " + m["params"]["entry"].get("url", ""))

    def js(self, expr):
        r = self.cmd("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True)
        if "exceptionDetails" in r:
            d = r["exceptionDetails"]
            raise RuntimeError("stage: " + str(d.get("exception", {}).get("description", d.get("text"))))
        return r["result"].get("value")

    def size(self, w, h):
        self.cmd("Emulation.setDeviceMetricsOverride", width=w, height=h, deviceScaleFactor=1, mobile=False)
        self.cmd("Emulation.setEmulatedMedia", features=[
            {"name": "prefers-color-scheme", "value": "light"},
            {"name": "prefers-reduced-motion", "value": "no-preference"}])

    def open(self, url):
        self.cmd("Page.navigate", url=url)
        for _ in range(200):
            if self.js("document.readyState") == "complete":
                return
            time.sleep(0.05)
        fail("the stage page did not load")

    def png(self):
        return base64.b64decode(self.cmd("Page.captureScreenshot", format="png", optimizeForSpeed=True)["data"])

    def close(self):
        try:
            self.cmd("Browser.close")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=10)
        except Exception:
            self.proc.kill()
        shutil.rmtree(self.profile, ignore_errors=True)


class Server:
    """The repository root over http (Chrome will not load fonts from file://)."""
    def __init__(self):
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *a):
                pass
        self.srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=ROOT))
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        self.base = f"http://127.0.0.1:{self.srv.server_address[1]}/"

    def close(self):
        self.srv.shutdown()


# ---------------------------------------------------------------- footage
def extract_footage():
    """Frames of each FOOTAGE clip as JPEGs, for the stage to show one by one."""
    ff = find_ffmpeg()
    out = {}
    for name, f in FOOTAGE.items():
        d = os.path.join(BUILD, "footage", name)
        stamp = os.path.join(d, "clip.json")
        want = {"ss": f["ss"], "len": f["len"], "src": os.path.getsize(DEMO)}
        if not (os.path.isfile(stamp) and json.load(open(stamp)) == want):
            shutil.rmtree(d, ignore_errors=True)
            os.makedirs(d)
            run([ff, "-v", "error", "-ss", str(f["ss"]), "-t", str(f["len"]), "-i", DEMO,
                 "-vf", f"fps={FPS}", "-q:v", "2", os.path.join(d, "%04d.jpg")])
            json.dump(want, open(stamp, "w"))
        count = len([x for x in os.listdir(d) if x.endswith(".jpg")])
        if count < f["len"] * FPS - 2:
            fail(f"footage {name}: only {count} frames")
        out[name] = {"dir": f"../../build/site_video/footage/{name}", "count": count, "mark": f.get("mark", 0)}
    return out


# ---------------------------------------------------------------- rendering
def stage_config(lang, shape, stats, footage, poster=False):
    return {
        "lang": lang, "shape": shape, "fps": FPS, "poster": poster,
        "copy": copy_for(lang, stats), "footage": footage,
        "assets": {"logo": "../../website/assets/icon-512.png",
                   "home": "../../website/assets/screenshots/02-home.webp",
                   "qr": "../../website/assets/qr-site.png"},
    }


def dims(shape):
    return (1920, 1080) if shape == "wide" else (1080, 1920)


def open_stage(server, shape):
    w, h = dims(shape)
    c = Chrome(w, h)
    c.size(w, h)
    c.open(server.base + STAGE_URL_PATH)
    return c


def setup(c, cfg):
    info = c.js(f"FLP.setup({json.dumps(cfg, ensure_ascii=False)})")
    if c.errors:
        fail("the stage reported errors:\n  " + "\n  ".join(c.errors))
    return info


def check_layout(c, info, label):
    problems = []
    for name, t in info["holds"]:
        c.js(f"FLP.frame({t})")
        for p in c.js("FLP.check()"):
            problems.append(f"{label} {name} @{t}s: {p}")
    return problems


ENC_COLOR = ["-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv"]
# The colour tags must be set on the frames too: this ffmpeg takes them from
# the frames, not from -color_primaries (which alone left them untagged, or
# PAL for the cut from the BT.601 tablet recording). Browsers guess colours of
# untagged video; washed-out clips have bitten this project before.
TAGS = "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv"
TO_709 = "scale=out_color_matrix=bt709:out_range=tv:flags=lanczos,format=yuv420p," + TAGS


def render_film(server, lang, shape, stats, footage):
    """Draw every frame and encode a near-lossless 1080p master, then the
    web copy (720p wide / 720×1280 upright)."""
    ff = find_ffmpeg()
    os.makedirs(BUILD, exist_ok=True)
    master, _web = film_paths(lang, shape)
    c = open_stage(server, shape)
    try:
        info = setup(c, stage_config(lang, shape, stats, footage))
        problems = check_layout(c, info, f"{lang}/{shape}")
        if problems:
            fail("layout problems — fix stage.css or COPY:\n  " + "\n  ".join(problems))
        n = round(info["duration"] * FPS)
        enc = subprocess.Popen([ff, "-y", "-v", "error", "-f", "image2pipe", "-framerate", str(FPS), "-c:v", "png",
                                "-i", "-", "-vf", TO_709, "-c:v", "libx264", "-preset", "medium", "-crf", "12",
                                *ENC_COLOR, "-movflags", "+faststart", master], stdin=subprocess.PIPE)
        t0 = time.time()
        for i in range(n):
            c.js(f"FLP.frame({i / FPS:.6f})")
            enc.stdin.write(c.png())
            if i % 150 == 0:
                el = time.time() - t0
                print(f"  {lang}/{shape}: frame {i}/{n}  ({el:.0f}s, ~{el / max(i, 1) * (n - i):.0f}s left)", flush=True)
        enc.stdin.close()
        if enc.wait():
            fail("ffmpeg could not encode the master")
        if c.errors:
            fail("the stage reported errors while rendering:\n  " + "\n  ".join(c.errors))
    finally:
        c.close()
    encode_web(lang, shape)


def film_paths(lang, shape):
    return (os.path.join(BUILD, f"film-{lang}-{shape}-master.mp4"),
            os.path.join(VIDEOS, f"film-{lang}{'' if shape == 'wide' else '-tall'}.mp4"))


def encode_web(lang, shape):
    """The copy the site serves, from the 1080p master (also: --reencode)."""
    master, web = film_paths(lang, shape)
    if not os.path.isfile(master):
        fail(f"no master for {lang}/{shape} — render it first (--only film --lang {lang} --shape {shape})")
    size = "1280:720" if shape == "wide" else "720:1280"
    run([find_ffmpeg(), "-y", "-v", "error", "-i", master, "-vf", f"scale={size}:flags=lanczos,{TAGS}",
         "-c:v", "libx264", "-profile:v", "high", "-level:v", "4.0", "-preset", "veryslow", "-crf", "24",
         "-maxrate", "1500k", "-bufsize", "3000k", "-g", "90", "-x264-params", "aq-mode=3",
         "-pix_fmt", "yuv420p", *ENC_COLOR, "-an", "-movflags", "+faststart", web])
    print(f"  wrote {os.path.relpath(web, ROOT)} ({os.path.getsize(web) / 1e6:.2f} MB)")


def render_posters(server, stats, footage):
    ff = find_ffmpeg()
    for shape, name, size in (("wide", "film-poster.webp", "1280:720"), ("tall", "film-tall-poster.webp", "720:1280")):
        c = open_stage(server, shape)
        try:
            info = setup(c, stage_config("en", shape, stats, footage, poster=True))
            c.js(f"FLP.frame({info['posterAt']})")
            png = os.path.join(BUILD, f"poster-{shape}.png")
            open(png, "wb").write(c.png())
        finally:
            c.close()
        out = os.path.join(VIDEOS, name)
        run([ff, "-y", "-v", "error", "-i", png, "-vf", f"scale={size}:flags=lanczos", "-c:v", "libwebp",
             "-quality", "84", "-compression_level", "6", out])
        print(f"  wrote {os.path.relpath(out, ROOT)} ({os.path.getsize(out) / 1e3:.0f} KB)")


def render_hero():
    """The app preview for the home page's phone: real footage, 600×960 (the
    phone frame's 1200×1920 shape), looping without a visible seam."""
    ff = find_ffmpeg()
    parts = HERO + [HERO[0]]          # end on the first piece again ...
    d = HERO_FADE
    chains, offs, acc = [], [], 0.0
    for i, (_name, ss, ln) in enumerate(parts):
        chains.append(f"[0:v]trim=start={ss}:duration={ln},setpts=PTS-STARTPTS,fps={FPS},"
                      f"crop=704:1126:8:0,scale=600:960:flags=lanczos:in_color_matrix=bt601:out_color_matrix=bt709,"
                      f"format=yuv420p,setsar=1,{TAGS}[p{i}]")
    graph, last = chains[:], "p0"
    for i in range(1, len(parts)):
        acc += parts[i - 1][2] - d
        offs.append(acc)
        graph.append(f"[{last}][p{i}]xfade=transition=fade:duration={d}:offset={acc:.3f}[x{i}]")
        last = f"x{i}"
    # ... and keep exactly one lap: from just after the first fade-in point to
    # the same point in the repeated first piece. Both ends show the same frame.
    period = offs[-1]
    graph.append(f"[{last}]trim=start={d}:duration={period:.3f},setpts=PTS-STARTPTS,{TAGS}[out]")
    out = os.path.join(VIDEOS, "hero-loop.mp4")
    run([ff, "-y", "-v", "error", "-i", DEMO, "-filter_complex", ";".join(graph), "-map", "[out]",
         "-c:v", "libx264", "-profile:v", "main", "-level:v", "3.1", "-preset", "veryslow", "-crf", "27",
         "-maxrate", "900k", "-bufsize", "1800k", "-g", "60", "-pix_fmt", "yuv420p", *ENC_COLOR,
         "-an", "-movflags", "+faststart", out])
    print(f"  wrote {os.path.relpath(out, ROOT)} ({os.path.getsize(out) / 1e3:.0f} KB, {period:.1f}s loop)")


def stills(server, stats, footage, langs, shapes):
    """One PNG per scene per version, plus a contact sheet — for reviewing
    words and layout without rendering whole films."""
    ff = find_ffmpeg()
    problems = []
    for shape in shapes:
        for lang in langs:
            d = os.path.join(BUILD, "stills", f"{lang}-{shape}")
            shutil.rmtree(d, ignore_errors=True)
            os.makedirs(d)
            c = open_stage(server, shape)
            try:
                info = setup(c, stage_config(lang, shape, stats, footage))
                problems += check_layout(c, info, f"{lang}/{shape}")
                for i, (name, t) in enumerate(info["holds"]):
                    c.js(f"FLP.frame({t})")
                    open(os.path.join(d, f"{i:02d}-{name}.png"), "wb").write(c.png())
            finally:
                c.close()
            sheet = os.path.join(BUILD, "stills", f"sheet-{lang}-{shape}.png")
            scale = "640:-1" if shape == "wide" else "360:-1"
            run([ff, "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", _concat_list(d), "-vf",
                 f"scale={scale},tile=3x3:padding=6:color=white", "-frames:v", "1", sheet])
            print(f"  {os.path.relpath(sheet, ROOT)}")
    for p in problems:
        print("  LAYOUT:", p)
    return problems


def frames_at(server, stats, footage, lang, shape, times):
    """Chosen moments of one version as a strip — for checking transitions."""
    ff = find_ffmpeg()
    d = os.path.join(BUILD, "frames", f"{lang}-{shape}")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    c = open_stage(server, shape)
    try:
        setup(c, stage_config(lang, shape, stats, footage))
        for i, t in enumerate(times):
            c.js(f"FLP.frame({t})")
            open(os.path.join(d, f"{i:02d}-{t:06.2f}.png"), "wb").write(c.png())
    finally:
        c.close()
    cols = 4 if shape == "wide" else 6
    rows = -(-len(times) // cols)
    sheet = os.path.join(BUILD, "frames", f"strip-{lang}-{shape}.png")
    run([ff, "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", _concat_list(d), "-vf",
         f"scale={'480:-1' if shape == 'wide' else '270:-1'},tile={cols}x{rows}:padding=4:color=white",
         "-frames:v", "1", sheet])
    print(f"  {os.path.relpath(sheet, ROOT)}")


def _concat_list(d):
    lst = os.path.join(d, "list.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for name in sorted(x for x in os.listdir(d) if x.endswith(".png")):
            f.write(f"file '{os.path.join(d, name).replace(os.sep, '/')}'\nduration 1\n")
    return lst


# ---------------------------------------------------------------- checks on the files
def probe(path):
    out = run([find_ffmpeg("ffprobe"), "-v", "error", "-show_entries",
               "stream=codec_type,codec_name,profile,width,height,pix_fmt,r_frame_rate,color_primaries,color_transfer,color_space"
               ":format=duration,size", "-of", "json", path])
    return json.loads(out)


def moov_first(path):
    """faststart: the index must come before the media, or browsers wait for the whole file."""
    with open(path, "rb") as f:
        head = f.read(1 << 16)
    return 0 <= head.find(b"moov") < (head.find(b"mdat") if b"mdat" in head else 1 << 30)


def flash_check(path):
    """No flashing: the brightest-to-darkest swing between neighbouring frames
    stays far below the WCAG general flash threshold (a 10% change).
    (The per-frame lines are logged at info level: no -v error here, or the
    check reads nothing and passes silently.)"""
    out = subprocess.run([find_ffmpeg(), "-hide_banner", "-nostats", "-i", path, "-vf",
                          "signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    ys = [float(v) for v in re.findall(r"YAVG=([\d.]+)", out)]
    if len(ys) < 10:
        fail(f"flash check read {len(ys)} frames of {os.path.basename(path)} — the measurement is broken")
    return max(abs(a - b) for a, b in zip(ys, ys[1:])) / 219.0   # limited range: 16..235


def check_files(full=True):
    problems = []
    films = [("film-en.mp4", 1280, 720), ("film-fil.mp4", 1280, 720), ("film-en-tall.mp4", 720, 1280),
             ("film-fil-tall.mp4", 720, 1280), ("hero-loop.mp4", 600, 960)]
    durs = {}
    for name, w, h in films:
        p = os.path.join(VIDEOS, name)
        if not os.path.isfile(p):
            problems.append(f"missing {name}")
            continue
        info = probe(p)
        vs = [s for s in info["streams"] if s["codec_type"] == "video"]
        if [s for s in info["streams"] if s["codec_type"] == "audio"]:
            problems.append(f"{name}: has a sound track (the films are silent)")
        v = vs[0]
        if (v["codec_name"], v["pix_fmt"]) != ("h264", "yuv420p"):
            problems.append(f"{name}: {v['codec_name']}/{v['pix_fmt']} — must be 8-bit H.264 (phones refuse High 10)")
        if (v["width"], v["height"]) != (w, h):
            problems.append(f"{name}: {v['width']}x{v['height']}, expected {w}x{h}")
        tags = (v.get("color_primaries"), v.get("color_transfer"), v.get("color_space"))
        if tags != ("bt709", "bt709", "bt709"):
            problems.append(f"{name}: colour tags {tags}, expected bt709 for all three")
        if not moov_first(p):
            problems.append(f"{name}: not faststart")
        size = int(info["format"]["size"])
        budget = BUDGET["hero" if name.startswith("hero") else "film"]
        if size > budget:
            problems.append(f"{name}: {size / 1e6:.2f} MB is over the {budget / 1e6:.1f} MB budget")
        durs[name] = float(info["format"]["duration"])
        if full:
            jump = flash_check(p)
            if jump > 0.10:
                problems.append(f"{name}: a {jump:.0%} brightness jump between two frames (flash risk)")
            print(f"  {name}: {v['width']}x{v['height']} {durs[name]:.2f}s {size / 1e6:.2f} MB, largest frame-to-frame brightness change {jump:.1%}")
    films_d = [durs[n] for n in ("film-en.mp4", "film-fil.mp4", "film-en-tall.mp4", "film-fil-tall.mp4") if n in durs]
    if films_d and max(films_d) - min(films_d) > 0.05:
        problems.append(f"the four film versions differ in length {films_d} — the page swaps between them mid-play")
    for name in ("film-poster.webp", "film-tall-poster.webp"):
        p = os.path.join(VIDEOS, name)
        if not os.path.isfile(p):
            problems.append(f"missing {name}")
        elif os.path.getsize(p) > BUDGET["poster"]:
            problems.append(f"{name}: {os.path.getsize(p) / 1e3:.0f} KB is over the poster budget")
    return problems, durs


# ---------------------------------------------------------------- the page section
def bi(en, fil):
    return f'<span class="en">{en}</span><span class="fil">{fil}</span>'


def plain(s):
    """Film words as page text: drop the **gradient** and <acc> marks."""
    return html.escape(re.sub(r"</?(acc|ok)>", "", s.replace("**", "")), quote=False)


def mb(path):
    return f"{os.path.getsize(path) / 1e6:.1f} MB" if os.path.isfile(path) else "? MB"


def script_items(lang, stats):
    """One item per scene: the words on screen, then what the picture shows."""
    c = copy_for(lang, stats)

    def sentences(*parts):
        out = []
        for p in parts:
            s = plain(p).strip()
            out.append(s if s[-1:] in ".?!" else s + ".")
        return " ".join(out)
    no_icon = lambda s: s.split(" ", 1)[1]   # "🆓 100% free" -> "100% free"
    said = {
        "open": sentences(" ".join(c["tag"])),
        "intro": sentences(c["intro"]["eyebrow"], c["intro"]["title"], c["intro"]["line"]),
        "learn": sentences(c["learn"]["title"], c["learn"]["line"],
                           "; ".join(f"{i['name']}: {i['sub']}" for i in c["learn"]["items"])),
        "end": sentences(c["end"]["title"], " · ".join(no_icon(x) for x in c["end"]["chips"]),
                         no_icon(c["end"]["button"]), c["end"]["sub"], c["end"]["qr"]) + " " + plain(c["end"]["url"]),
    }
    for k in ("cards", "fsl", "games", "talk", "teach"):
        said[k] = sentences(c[k]["label"], c[k]["title"], c[k]["line"])
    on, see = ("On screen:", "We see:") if lang == "en" else ("Nakasulat:", "Makikita:")
    return [f"<b>{on}</b> {said[k]} <b>{see}</b> {plain(c['shows'][k])}" for k in SCENES]


def render_section(stats, duration):
    secs = int(round(duration))
    clock = f"{secs // 60}:{secs % 60:02d}"
    v = "assets/videos/"
    src = {"en": {"wide": v + "film-en.mp4", "tall": v + "film-en-tall.mp4"},
           "fil": {"wide": v + "film-fil.mp4", "tall": v + "film-fil-tall.mp4"}}
    en_items, fil_items = script_items("en", stats), script_items("fil", stats)
    items = "\n".join(f"          <li>{bi(e, f)}</li>" for e, f in zip(en_items, fil_items))
    links = []
    for lang, lname in (("en", "English"), ("fil", "Filipino")):
        for shape, en_l, fil_l in (("wide", "landscape", "pahiga"), ("tall", "upright, for phones", "patayo, para sa phone")):
            path = os.path.join(SITE, src[lang][shape])
            dl = f"FlashLearn-PWD-film-{lang.upper()}{'' if shape == 'wide' else '-phone'}.mp4"
            links.append(f'<a href="{src[lang][shape]}" download="{dl}">{lname} — {bi(en_l, fil_l)} ({mb(path)})</a>')
    share = "\n        <li>" + "</li>\n        <li>".join(links) + "</li>"
    data = html.escape(json.dumps(src, separators=(",", ":")), quote=True)
    ld = []
    for lang, name, desc in (
            ("en", "FlashLearn PWD in 50 seconds", "A short silent film about FlashLearn PWD, a free bilingual flashcard app for children with disabilities: flashcards, Filipino Sign Language videos, learning games, the Talk Board, and presets for every kind of learner."),
            ("fil", "Ang FlashLearn PWD sa loob ng 50 segundo", "Isang maikling pelikulang walang tunog tungkol sa FlashLearn PWD, libreng bilingual na flashcard app para sa mga batang may kapansanan: flashcards, video ng senyas sa FSL, mga larong pampag-aaral, ang Talk Board, at mga preset para sa bawat uri ng mag-aaral.")):
        ld.append({"@context": "https://schema.org", "@type": "VideoObject", "name": name.replace("50", str(secs)),
                   "description": desc, "inLanguage": lang, "uploadDate": FILM_DATE, "duration": f"PT{secs}S",
                   "thumbnailUrl": SITE_URL + v + "film-poster.webp", "contentUrl": SITE_URL + src[lang]["wide"],
                   "embedUrl": SITE_URL + "#film"})
    jsonld = json.dumps(ld, ensure_ascii=False, indent=1).replace("</", "<\\/")
    return f"""
<section class="section tint film-section" id="film" aria-labelledby="filmTitle">
  <div class="container">
    <div class="section-head center">
      <p class="eyebrow"><span aria-hidden="true">🎬</span> {bi("Watch", "Panoorin")}</p>
      <h2 id="filmTitle">{bi(f"FlashLearn PWD in {secs} seconds", f"Ang FlashLearn PWD sa loob ng {secs} segundo")}</h2>
      <p class="lead">{bi("A short film with no sound: every word is on the screen, in the language you choose at the top of the page.", "Isang maikling pelikula na walang tunog: nasa screen ang bawat salita, sa wikang pipiliin mo sa itaas ng pahina.")}</p>
    </div>
    <div class="film" id="filmPlayer" data-film="{data}" data-film-en="FlashLearn PWD film, {secs} seconds, no sound" data-film-fil="Pelikula ng FlashLearn PWD, {secs} segundo, walang tunog">
      <a class="film-facade" href="{src['en']['wide']}">
        <picture>
          <source media="(max-width: 640px) and (orientation: portrait)" srcset="{v}film-tall-poster.webp" width="720" height="1280">
          <img src="{v}film-poster.webp" width="1280" height="720" alt="" loading="lazy" decoding="async">
        </picture>
        <span class="film-play"><span class="film-play-ico" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M8 5.5v13l11-6.5z" fill="currentColor"/></svg></span><span class="film-play-txt">{bi("Play the film", "I-play ang pelikula")}</span><span class="film-len"><span class="sr-only">{bi(f"({secs} seconds)", f"({secs} segundo)")}</span><span aria-hidden="true">{clock}</span></span></span>
      </a>
      <p class="film-msg" role="status" hidden>{bi("The film needs the internet. Check the connection, then press Play again.", "Kailangan ng internet ang pelikula. Tingnan ang koneksyon, saka pindutin muli ang Play.")}</p>
    </div>
    <details class="disclosure film-words">
      <summary>{bi("Read what the film shows", "Basahin ang ipinapakita ng pelikula")}</summary>
      <div class="d-body">
        <ol class="film-script">
{items}
        </ol>
      </div>
    </details>
    <div class="film-share">
      <p>{bi("Show it in class or share it: download the film.", "Ipalabas sa klase o ibahagi: i-download ang pelikula.")}</p>
      <ul>{share}
      </ul>
    </div>
  </div>
  <script type="application/ld+json">
{jsonld}
  </script>
</section>
"""


def write_section(stats, duration, check=False):
    text = open(INDEX, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    pattern = re.compile(r"(<!--gen:site-film-->)(.*?)(<!--/gen:site-film-->)", re.S)
    if len(pattern.findall(text)) != 1:
        fail("index.html needs exactly one <!--gen:site-film--> … <!--/gen:site-film--> region")
    body = render_section(stats, duration).replace("\n", nl)
    new = pattern.sub(lambda m: m.group(1) + body + m.group(3), text)
    if new == text:
        return False
    if not check:
        open(INDEX, "w", encoding="utf-8", newline="").write(new)
    return True


def film_duration():
    p = os.path.join(VIDEOS, "film-en.mp4")
    if os.path.isfile(p):
        return float(probe(p)["format"]["duration"])
    return 50.0


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--page", action="store_true")
    ap.add_argument("--frames", help="comma-separated seconds: draw just those moments (with --lang/--shape)")
    ap.add_argument("--reencode", action="store_true", help="only re-encode the site's copies from the 1080p masters")
    ap.add_argument("--only", choices=["film", "hero", "posters"])
    ap.add_argument("--lang", choices=["en", "fil"])
    ap.add_argument("--shape", choices=["wide", "tall"])
    a = ap.parse_args()
    stats = site_stats()
    langs = [a.lang] if a.lang else ["en", "fil"]
    shapes = [a.shape] if a.shape else ["wide", "tall"]

    if a.check:
        problems, durs = check_files(full=False)
        if write_section(stats, film_duration(), check=True):
            problems.append("index.html film section is stale — run: python tools/site_video_build.py --page")
        for p in problems:
            print("  " + p)
        sys.exit(1 if problems else 0)
    if a.page:
        print("wrote index.html film section" if write_section(stats, film_duration()) else "film section already current")
        return
    if a.reencode:
        for shape in shapes:
            for lang in langs:
                encode_web(lang, shape)
        write_section(stats, film_duration())
        problems, _ = check_files(full=True)
        for p in problems:
            print("  PROBLEM: " + p)
        sys.exit(1 if problems else 0)

    server = Server()
    try:
        footage = extract_footage()
        if a.stills:
            sys.exit(1 if stills(server, stats, footage, langs, shapes) else 0)
        if a.frames:
            times = [float(x) for x in a.frames.split(",")]
            for shape in shapes:
                for lang in langs:
                    frames_at(server, stats, footage, lang, shape, times)
            return
        if a.only in (None, "hero"):
            render_hero()
        if a.only in (None, "posters"):
            render_posters(server, stats, footage)
        if a.only in (None, "film"):
            for shape in shapes:
                for lang in langs:
                    render_film(server, lang, shape, stats, footage)
    finally:
        server.close()
    if a.only is None or a.only == "film":
        write_section(stats, film_duration())
    problems, _ = check_files(full=True)
    for p in problems:
        print("  PROBLEM: " + p)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()
