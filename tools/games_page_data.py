#!/usr/bin/env python3
"""Read the real game roster straight out of the app's Dart source + ARB files.

Nothing here is hand-maintained: the website's Games page is built from what
`GameType`, `GameCatalog` and the localisations actually say, so the page cannot
claim a game the app does not ship, or a roster the app does not use.

Exposes `collect()` -> (games, rosters, categories).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENUMS = ROOT / "lib" / "data" / "models" / "enums.dart"
CATALOG = ROOT / "lib" / "core" / "accessibility" / "game_catalog.dart"
ARB = ROOT / "lib" / "l10n"

# GameType -> the ARB keys holding its name and blurb, as wired in GameTypeX.
# Mirrors labelOf()/descriptionOf(); a game missing here is a hard error.
L10N_KEYS = {
    "wordMatch": ("wordMatch", "gameDescWordMatch"),
    "spellingBee": ("spellingBee", "gameDescSpellingBee"),
    "memoryMatch": ("memoryMatch", "gameDescMemoryMatch"),
    "dragAndDrop": ("dragAndDrop", "gameDescDragAndDrop"),
    "flashcardQuiz": ("flashcardQuiz", "gameDescFlashcardQuiz"),
    "pronunciation": ("pronunciationPractice", "gameDescPronunciation"),
    "sentenceBuilder": ("sentenceBuilder", "gameDescSentenceBuilder"),
    "storyQuiz": ("storyQuiz", "gameDescStoryQuiz"),
    "tracing": ("tracing", "gameDescTracing"),
    "fslPractice": ("fslPractice", "gameDescFslPractice"),
    "jigsawPuzzle": ("jigsawPuzzle", "gameDescJigsawPuzzle"),
    "pictureWord": ("pictureWord", "gameDescPictureWord"),
    "yesOrNo": ("yesOrNo", "gameDescYesOrNo"),
    "oddOneOut": ("oddOneOut", "gameDescOddOneOut"),
    "firstLetter": ("firstLetter", "gameDescFirstLetter"),
}

# Emoji are a website-side presentation choice: the app draws Material icons,
# which would mean shipping an icon font and breaking the offline PWA. Each one
# is picked to match the game's actual mechanic, and the app's real accent
# colour (parsed below) is what carries the visual identity.
EMOJI = {
    "wordMatch": "🎯", "spellingBee": "🔤", "memoryMatch": "🃏",
    "dragAndDrop": "🫳", "flashcardQuiz": "↔️", "pronunciation": "🔊",
    "sentenceBuilder": "📝", "storyQuiz": "📖", "tracing": "✏️",
    "fslPractice": "🤟", "jigsawPuzzle": "🧩", "pictureWord": "🖼️",
    "yesOrNo": "👍", "oddOneOut": "🔍", "firstLetter": "🔡",
}

# Bilingual category names, matching the wording already used in the site's
# PWD Awareness grid so the two sections agree.
CATEGORY_NAMES = {
    "visual": ("Visual impairment", "Kapansanan sa paningin"),
    "hearing": ("Hearing impairment", "Kapansanan sa pandinig"),
    "motor": ("Motor impairment", "Kapansanan sa paggalaw"),
    "cognitive": ("Cognitive & learning", "Kognitibo at pagkatuto"),
    "multiple": ("Multiple disabilities", "Maramihang kapansanan"),
    "none": ("No accessibility needs", "Walang kailangang akomodasyon"),
}

# Reader-facing version of the rationale each roster carries as a code comment.
# `excludes` is the load-bearing part: the build asserts it equals the games the
# roster actually leaves out, so this prose cannot quietly go stale when a
# roster is edited. Change a roster in Dart and the page build fails until the
# explanation here is updated too.
RATIONALE = {
    "visual": {
        "en": "Audio and text-to-speech carry the prompt, so nothing depends on seeing a picture.",
        "fil": "Ang audio at text-to-speech ang naghahatid ng tanong, kaya walang umaasa sa pagkakita ng larawan.",
        "excludes": ["dragAndDrop", "fslPractice", "jigsawPuzzle", "pictureWord"],
        "why_en": "Sign language is visual, precise placement needs sight, and Picture-Word's prompt is an image with no text to read aloud.",
        "why_fil": "Biswal ang sign language, kailangan ng paningin sa tumpak na paglalagay, at larawan ang tanong ng Larawan-Salita na walang tekstong mababasa nang malakas.",
    },
    "hearing": {
        "en": "Filipino Sign Language leads, and nothing in the set depends on hearing.",
        "fil": "Nangunguna ang Filipino Sign Language, at walang umaasa sa pandinig.",
        "excludes": ["pronunciation", "yesOrNo", "oddOneOut", "firstLetter"],
        "why_en": "Pronunciation Practice is audio-only. The three low-barrier games are left out on purpose — they lower an input barrier these learners do not have.",
        "why_fil": "Puro audio ang Pagsasanay sa Pagbigkas. Sinadyang hindi isama ang tatlong low-barrier na laro — inaalis nila ang hadlang sa pag-input na wala naman sa mga mag-aaral na ito.",
    },
    "motor": {
        "en": "Single taps on large targets only — no dragging, no sustained gestures.",
        "fil": "Iisang pindot lamang sa malalaking target — walang paghila o matagalang galaw.",
        "excludes": ["dragAndDrop", "flashcardQuiz", "tracing", "jigsawPuzzle"],
        "why_en": "Drag & Drop, Tracing and Jigsaw need sustained drag or fine stroke control. Flashcard Quiz is designed around swiping; its buttons are a fallback, not the design.",
        "why_fil": "Kailangan ng matagalang paghila o pinong kontrol sa I-drag at I-drop, Pagsu-sulat at Jigsaw. Nakabatay sa pag-swipe ang Flashcard Quiz; ang mga button ay pamalit lamang, hindi ang disenyo.",
    },
    "cognitive": {
        "en": "Concrete and pictorial, with low reading and low metacognitive load.",
        "fil": "Konkreto at may larawan, mababa ang pagbabasa at mababa ang metacognitive na pasanin.",
        "excludes": ["spellingBee", "flashcardQuiz", "sentenceBuilder", "fslPractice"],
        "why_en": "Spelling Bee and Sentence Builder carry the heaviest literacy load. Flashcard Quiz asks “do I know this?”, the hardest judgement to make here. FSL Practice is left out because unrelated signing can confuse.",
        "why_fil": "Pinakamabigat sa literasiya ang Spelling Bee at Sentence Builder. Nagtatanong ang Flashcard Quiz ng “alam ko ba ito?”, ang pinakamahirap na paghatol dito. Hindi kasama ang FSL dahil nakalilito ang di-kaugnay na pagsenyas.",
    },
    "multiple": {
        "en": "The motor input limits, with every alternative modality — both FSL and audio — kept available.",
        "fil": "Ang mga limitasyon sa motor input, habang nananatiling available ang lahat ng alternatibong modalidad — FSL at audio.",
        "excludes": ["dragAndDrop", "spellingBee", "tracing", "jigsawPuzzle"],
        "why_en": "The same motor exclusions, plus Spelling Bee for its literacy load. Led by the lowest-barrier games.",
        "why_fil": "Parehong motor na eksklusyon, dagdag ang Spelling Bee dahil sa bigat nito sa literasiya. Pinangungunahan ng pinakamababang-hadlang na laro.",
    },
    "none": {
        "en": "The full classic roster.",
        "fil": "Ang kumpletong klasikong roster.",
        "excludes": ["pictureWord", "yesOrNo", "oddOneOut", "firstLetter"],
        "why_en": "Picture-Word is Word Match with prompt and answer swapped when there is no perception constraint. The three low-barrier games are aimed at the categories that need them.",
        "why_fil": "Ang Larawan-Salita ay Pagtutugma ng Salita na binaligtad ang tanong at sagot kapag walang limitasyon sa pang-unawa. Nakatuon ang tatlong low-barrier na laro sa mga kategoryang nangangailangan nito.",
    },
}


def die(msg):
    sys.exit(f"games_page_data: {msg}")


def _block(text, start_pat, end="};"):
    m = re.search(start_pat, text)
    if not m:
        die(f"could not find {start_pat!r}")
    tail = text[m.end():]
    stop = tail.find(end)
    if stop < 0:
        die(f"unterminated block after {start_pat!r}")
    return tail[:stop]


def parse_enums():
    src = ENUMS.read_text(encoding="utf-8")

    # Enum order: the display order the app itself uses for the combined list.
    body = _block(src, r"enum GameType\s*\{", "}")
    order = [
        line.strip().rstrip(",")
        for line in body.splitlines()
        if line.strip() and not line.strip().startswith("//")
    ]
    order = [o for o in order if re.fullmatch(r"[a-zA-Z]+", o)]
    if not order:
        die("parsed no GameType values")

    # Scope every lookup to the GameTypeX extension. `String get label =>
    # switch (this)` appears in half a dozen extensions in this file, and a
    # bare search silently reads DisabilityTypeX's labels instead.
    ext = re.search(r"extension GameTypeX on GameType \{", src)
    if not ext:
        die("no `extension GameTypeX on GameType`")
    rest = src[ext.end():]
    nxt = re.search(r"\nextension \w+", rest)
    gx = rest[: nxt.start()] if nxt else rest

    def switch_map(pat, cast=str):
        blk = _block(gx, pat)
        out = {}
        for g, v in re.findall(r"GameType\.(\w+)\s*=>\s*(?:const Color\()?([^,\n]+?)\)?,", blk):
            out[g] = cast(v.strip().strip("'"))
        return out

    labels = switch_map(r"String get label => switch \(this\) \{")
    descs = switch_map(r"String get description => switch \(this\) \{")
    icons = switch_map(r"IconData get icon => switch \(this\) \{")
    colors = switch_map(r"Color get color => switch \(this\) \{")

    for name, m in (("label", labels), ("description", descs), ("color", colors)):
        missing = [g for g in order if g not in m]
        if missing:
            die(f"GameType {missing} have no {name}")

    games = {}
    for g in order:
        col = colors[g]
        m = re.fullmatch(r"0x[fF]{2}([0-9a-fA-F]{6})", col)
        if not m:
            die(f"{g}: unparsed colour {col!r}")
        games[g] = {
            "id": g,
            "label_en": labels[g],
            "desc_en": descs[g],
            "icon": icons.get(g, ""),
            "color": "#" + m.group(1).upper(),
            "emoji": EMOJI.get(g) or die(f"{g} has no emoji mapping"),
        }
    return order, games


def parse_catalog(order):
    src = CATALOG.read_text(encoding="utf-8")

    per = int(re.search(r"gamesPerCategory\s*=\s*(\d+)", src).group(1))

    rosters = {}
    for key in CATEGORY_NAMES:
        blk = re.search(
            rf"_{key}\s*=\s*\[(.*?)\];", src, re.S
        )
        if not blk:
            die(f"no roster list for _{key}")
        picks = re.findall(r"GameType\.(\w+)", blk.group(1))
        if len(picks) != per:
            die(f"_{key} has {len(picks)} games, expected {per}")
        if len(set(picks)) != len(picks):
            die(f"_{key} has duplicates")
        unknown = [p for p in picks if p not in order]
        if unknown:
            die(f"_{key} references unknown games {unknown}")
        rosters[key] = picks

    # The rationale comment above each roster — the *why* behind the exclusions.
    for key in CATEGORY_NAMES:
        m = re.search(
            rf"((?:^\s*//.*\n)+)\s*static const List<GameType> _{key}\s*=",
            src, re.M,
        )
        note = ""
        if m:
            lines = [
                re.sub(r"^\s*//\s?", "", ln).strip()
                for ln in m.group(1).splitlines()
            ]
            # Drop the ─── Section Name ─── divider comment above each roster.
            lines = [ln for ln in lines if ln and "─" not in ln]
            note = " ".join(lines).strip()
        rosters[key] = {"games": rosters[key], "note": note}

    excluded = re.findall(r"_hubExcluded\s*=\s*\{([^}]*)\}", src)
    hub_excluded = re.findall(r"GameType\.(\w+)", excluded[0]) if excluded else []
    return rosters, hub_excluded, per


def load_arb(games):
    for loc in ("en", "fil"):
        data = json.loads((ARB / f"app_{loc}.arb").read_text(encoding="utf-8"))
        for gid, g in games.items():
            kn, kd = L10N_KEYS.get(gid, (None, None))
            if not kn:
                die(f"{gid} has no L10N_KEYS entry")
            if kn not in data:
                die(f"{loc}: missing name key {kn}")
            if kd not in data:
                die(f"{loc}: missing description key {kd}")
            g[f"name_{loc}"] = data[kn]
            g[f"blurb_{loc}"] = data[kd]
    return games


def collect():
    order, games = parse_enums()
    games = load_arb(games)
    rosters, hub_excluded, per = parse_catalog(order)
    combined = [g for g in order if g not in hub_excluded]

    # The page's explanation of *why* each roster looks the way it does is
    # checked against the roster itself. Edit a roster in Dart without updating
    # RATIONALE and this build fails rather than publishing a stale reason.
    for key in CATEGORY_NAMES:
        actual = sorted(set(combined) - set(rosters[key]["games"]))
        claimed = sorted(RATIONALE[key]["excludes"])
        if actual != claimed:
            die(
                f"_{key}: the page says it leaves out {claimed}, but the roster "
                f"actually leaves out {actual}. Update RATIONALE['{key}']"
                f"['excludes'] (and its prose) to match game_catalog.dart."
            )
        rosters[key]["excludes"] = actual
        rosters[key]["rationale"] = RATIONALE[key]

    return {
        "order": order,
        "games": games,
        "rosters": rosters,
        "combined": combined,
        "hub_excluded": hub_excluded,
        "per_category": per,
        "categories": CATEGORY_NAMES,
    }


if __name__ == "__main__":
    # The Windows console defaults to cp1252, which cannot encode the emoji.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    d = collect()
    print(f"{len(d['order'])} GameType values, {len(d['combined'])} in the hub")
    print(f"hub-excluded: {d['hub_excluded']}")
    for gid in d["order"]:
        g = d["games"][gid]
        print(f"  {g['emoji']} {g['color']} {g['name_en']:<24} | {g['name_fil']}")
    print()
    for key, (en, fil) in d["categories"].items():
        r = d["rosters"][key]
        print(f"  {en:<24} {len(r['games'])} games")
        print(f"      {r['note'][:120]}")
