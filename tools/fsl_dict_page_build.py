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


def main():
    cats, entries = parse_dict_js(DICT_JS.read_text(encoding="utf-8"))

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


if __name__ == "__main__":
    main()
