#!/usr/bin/env python3
"""Generate website/fsl-dictionary.html from website/assets/fsl-dict.js.

The 143 sign cards are baked into the HTML rather than rendered by JavaScript so
that (a) the words are real crawlable text, and (b) a visitor with JS disabled or
still loading can read and browse the whole dictionary. JavaScript then layers on
search, category filtering, and the video dialog.

    python tools/fsl_dict_page_build.py

Re-run whenever assets/fsl-dict.js changes. Every clip referenced must exist in
assets/videos/fsl/ — the script fails loudly if one is missing, so a broken card
can't reach the site.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "website"
DICT_JS = SITE / "assets" / "fsl-dict.js"
CLIPS = SITE / "assets" / "videos" / "fsl"
TEMPLATE = ROOT / "tools" / "fsl_dict_page.template.html"
OUT = SITE / "fsl-dictionary.html"


def parse_dict_js(text):
    """Pull FSL_CATS and FSL_DICT out of the generated JS."""
    cats_m = re.search(r"window\.FSL_CATS\s*=\s*(\[.*?\]);", text, re.S)
    if not cats_m:
        sys.exit("could not find window.FSL_CATS")
    cats = json.loads(cats_m.group(1))

    dict_m = re.search(r"window\.FSL_DICT\s*=\s*\[(.*?)\n\];", text, re.S)
    if not dict_m:
        sys.exit("could not find window.FSL_DICT")

    entries = []
    for line in dict_m.group(1).splitlines():
        line = line.strip().rstrip(",")
        if not line.startswith("{"):
            continue
        # Quote the bare keys so this becomes valid JSON — which then decodes the
        # \uXXXX escapes (including surrogate pairs) correctly for us.
        as_json = re.sub(r"([{,])\s*(c|f|en|fil|e|s)\s*:", r'\1"\2":', line)
        try:
            entries.append(json.loads(as_json))
        except json.JSONDecodeError as exc:
            sys.exit(f"could not parse dict line:\n  {line}\n  {exc}")
    return cats, entries


SEED = ROOT / "lib" / "data" / "local" / "seed_data.dart"

# The app's categories in `FlashcardCategory` order. The first twelve are the
# dictionary's FSL_CATS in the same order; Actions has no signs yet, so it only
# appears among the words still being recorded.
SEED_CATEGORY_ORDER = [
    "animals", "colorsAndShapes", "numbers", "bodyParts", "foodAndDrinks",
    "familyAndGreetings", "clothing", "weather", "classroom", "transportation",
    "emotions", "daysAndTime", "actions",
]
ACTIONS = {"en": "Actions", "fil": "Mga Kilos", "e": "🏃"}


def parse_seed_words(text):
    """(category, English, Filipino) for every flashcard the app ships."""
    words = re.findall(
        r"wordEnglish: '((?:[^'\\]|\\.)*)', wordFilipino: '((?:[^'\\]|\\.)*)'"
        r".*?category: FlashcardCategory\.(\w+)",
        text,
    )
    if len(words) < 150:
        sys.exit(f"read only {len(words)} words from seed_data.dart — has its format changed?")
    return [(c, en.replace("\\'", "'"), fil.replace("\\'", "'")) for en, fil, c in words]


def coming_soon(cats, entries):
    """App words with no sign on the site yet, grouped by category.

    A word signed under another category counts as covered — the app plays the
    same clip for it (e.g. Walk under Actions uses the Transportation sign).
    No placeholder clips: these are listed as words, nothing more.
    """
    signed = {e["en"].lower() for e in entries}
    groups = {}
    for cat, en, fil in parse_seed_words(SEED.read_text(encoding="utf-8")):
        if cat not in SEED_CATEGORY_ORDER:
            sys.exit(f"seed_data.dart uses an unknown category: {cat}")
        if en.lower() not in signed:
            groups.setdefault(cat, []).append((en, fil))
    out = []
    for cat in SEED_CATEGORY_ORDER:
        if cat not in groups:
            continue
        idx = SEED_CATEGORY_ORDER.index(cat)
        label = cats[idx] if idx < len(cats) else ACTIONS
        # idx is also the chip's data-cat, so a chip filters this group too.
        out.append((idx, label, groups[cat]))
    return out


def render_coming_soon(groups):
    total = sum(len(words) for _, _, words in groups)
    if not total:
        return ""
    blocks = []
    for idx, label, words in groups:
        # data-en / data-fil let the search box filter these words exactly as
        # it filters the sign cards (lower-case, same attribute names).
        items = "".join(
            f'<li data-en="{html.escape(en.lower())}" data-fil="{html.escape(fil.lower())}">'
            f'<span class="soon-en">{html.escape(en)}</span>'
            f'<span class="soon-fil">{html.escape(fil)}</span></li>'
            for en, fil in words
        )
        blocks.append(
            f'<div class="soon-group" data-cat="{idx}">'
            f'<h3><span aria-hidden="true">{label["e"]}</span> '
            f'<span class="en">{html.escape(label["en"])}</span>'
            f'<span class="fil">{html.escape(label["fil"])}</span>'
            f' <span class="soon-n">{len(words)}</span></h3>'
            f'<ul>{items}</ul></div>'
        )
    return (
        '<section class="coming-soon" id="comingSoon" aria-labelledby="soonTitle">\n'
        '      <h2 id="soonTitle"><span class="en">Signs coming soon</span>'
        '<span class="fil">Mga senyas na paparating</span></h2>\n'
        f'      <p class="soon-lead"><span class="en">The app teaches {total} more words that do not '
        'have a recorded sign yet. We would rather show nothing than a guessed sign, so '
        'these are listed here until a Deaf signer records them.</span>'
        f'<span class="fil">May {total} pang salita sa app na wala pang naka-record na senyas. '
        'Mas mabuting walang ipakita kaysa sa hulang senyas, kaya nakalista muna ang mga ito '
        'dito hanggang ma-record ng isang Deaf signer.</span></p>\n'
        '      <div class="soon-grid">\n        ' + "\n        ".join(blocks) + "\n      </div>\n"
        '      <p class="soon-help"><span aria-hidden="true">🤟</span> <span class="en">Do you sign FSL, or teach Deaf learners? '
        '<a href="faq.html#feedback">Send us a message</a> — help recording these signs is very welcome. Until then, '
        'the app teaches each of these words with its picture, both written words and spoken English and Filipino.</span>'
        '<span class="fil">Marunong ba kayo ng FSL, o nagtuturo sa mga Deaf na mag-aaral? '
        '<a href="faq.html#feedback">Magpadala ng mensahe</a> — malaking tulong ang pag-record ng mga senyas na ito. '
        'Hanggang doon, itinuturo ng app ang bawat salitang ito gamit ang larawan, ang nakasulat na salita, at binibigkas na English at Filipino.</span></p>\n'
        "    </section>"
    )


def main():
    cats, entries = parse_dict_js(DICT_JS.read_text(encoding="utf-8"))
    soon = coming_soon(cats, entries)

    missing = [e["f"] for e in entries if not (CLIPS / f'{e["f"]}.mp4').exists()]
    if missing:
        sys.exit(f"{len(missing)} entries have no clip in assets/videos/fsl/: {missing}")

    # Cards, grouped so each category's words stay together in source order.
    cards = []
    for i, e in enumerate(entries):
        cat = cats[e["c"]]
        cards.append(
            '<button class="sign" type="button"'
            f' data-f="{html.escape(e["f"], quote=True)}"'
            f' data-cat="{e["c"]}"'
            f' data-en="{html.escape(e["en"].lower(), quote=True)}"'
            f' data-fil="{html.escape(e["fil"].lower(), quote=True)}"'
            f' data-sentence="{html.escape(e["s"], quote=True)}"'
            f' aria-label="{html.escape(e["en"], quote=True)} / {html.escape(e["fil"], quote=True)}'
            ' — watch the Filipino Sign Language clip">'
            f'<span class="sign-emoji" aria-hidden="true">{e["e"]}</span>'
            f'<span class="sign-en">{html.escape(e["en"])}</span>'
            f'<span class="sign-fil">{html.escape(e["fil"])}</span>'
            f'<span class="sign-cat"><span class="en">{html.escape(cat["en"])}</span>'
            f'<span class="fil">{html.escape(cat["fil"])}</span></span>'
            "</button>"
        )

    # Category filter chips, each labelled with how many signs it holds.
    counts = {}
    for e in entries:
        counts[e["c"]] = counts.get(e["c"], 0) + 1
    chips = [
        '<button class="chip" type="button" data-cat="all" aria-pressed="true">'
        f'<span class="en">All signs</span><span class="fil">Lahat</span>'
        f'<span class="chip-n">{len(entries)}</span></button>'
    ]
    for i, c in enumerate(cats):
        if not counts.get(i):
            continue
        chips.append(
            f'<button class="chip" type="button" data-cat="{i}" aria-pressed="false">'
            f'<span aria-hidden="true">{c["e"]}</span> '
            f'<span class="en">{html.escape(c["en"])}</span>'
            f'<span class="fil">{html.escape(c["fil"])}</span>'
            f'<span class="chip-n">{counts[i]}</span></button>'
        )

    # Structured data: the dictionary as a term set, with every word present.
    jsonld = {
        "@context": "https://schema.org",
        "@type": "DefinedTermSet",
        "name": "FlashLearn PWD — Filipino Sign Language Dictionary",
        "description": (
            f"{len(entries)} everyday Filipino words with their Filipino Sign Language "
            "(FSL) signs on video, in English and Filipino."
        ),
        "inLanguage": ["en", "fil"],
        "hasDefinedTerm": [
            {
                "@type": "DefinedTerm",
                "name": e["en"],
                "alternateName": e["fil"],
                "description": e["s"],
                "inDefinedTermSet": "FlashLearn PWD FSL Dictionary",
            }
            for e in entries
        ],
    }

    page = TEMPLATE.read_text(encoding="utf-8")
    replacements = {
        "<!--CARDS-->": "\n  ".join(cards),
        "<!--CHIPS-->": "\n    ".join(chips),
        "<!--JSONLD-->": json.dumps(jsonld, ensure_ascii=False, indent=1),
        "<!--COMING-->": render_coming_soon(soon),
        "__COUNT__": str(len(entries)),
        "__CATCOUNT__": str(len([c for i, c in enumerate(cats) if counts.get(i)])),
    }
    for needle, value in replacements.items():
        if needle not in page:
            sys.exit(f"template is missing placeholder {needle}")
        page = page.replace(needle, value)

    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"  {len(entries)} signs across {replacements['__CATCOUNT__']} categories")
    print(f"  every referenced clip exists in {CLIPS.relative_to(ROOT)}")
    print(f"  {sum(len(w) for _, _, w in soon)} app words listed as coming soon "
          f"({', '.join(f'{l['en']} {len(w)}' for _, l, w in soon)})")


if __name__ == "__main__":
    main()
