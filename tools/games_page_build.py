#!/usr/bin/env python3
"""Generate website/games.html from the app's real game data.

    python tools/games_page_build.py

Everything on the page - the game names, blurbs, accent colours, and the ten
games each accessibility type receives - is read from `enums.dart`,
`game_catalog.dart` and the ARB files by `games_page_data.py`. Re-run whenever
those change. The build fails loudly rather than publishing a page that
disagrees with the app (see the assertions in games_page_data.collect).

Cards and rosters are baked into the HTML rather than rendered by JavaScript so
the game names are crawlable and the page is readable with JS off; JavaScript
only switches which roster is shown.
"""
import html
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from games_page_data import collect  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "website"
TEMPLATE = ROOT / "tools" / "games_page.template.html"
OUT = SITE / "games.html"
SEED = ROOT / "lib" / "data" / "local" / "seed_data.dart"

E = lambda s: html.escape(s, quote=True)  # noqa: E731


def word_count():
    """How many flashcard words the app seeds - the page quotes this number."""
    if not SEED.exists():
        sys.exit(f"missing {SEED}")
    src = SEED.read_text(encoding="utf-8")
    n = len(re.findall(r"\bFlashcard\s*\(", src))
    if n < 50:
        sys.exit(f"only found {n} seeded flashcards - check the seed_data parser")
    return n


def bilingual(en, fil):
    return f'<span class="en">{E(en)}</span><span class="fil">{E(fil)}</span>'


def build_game_cards(d):
    out = []
    for gid in d["order"]:
        g = d["games"][gid]
        in_hub = gid not in d["hub_excluded"]
        tag = (
            bilingual("In the Games tab", "Nasa Games tab")
            if in_hub
            else bilingual("Opens from Stories", "Bubukas mula sa Stories")
        )
        out.append(
            f'<article class="game" style="--g:{g["color"]}">'
            f'<span class="g-emoji" aria-hidden="true">{g["emoji"]}</span>'
            f'<h3>{bilingual(g["name_en"], g["name_fil"])}</h3>'
            # The other language's name, shown only when it differs (four games
            # are called the same thing in both). The .en/.fil classes are
            # deliberately swapped here: in English the Filipino name shows.
            + (f'<span class="g-alt"><span class="fil">{E(g["name_en"])}</span>'
               f'<span class="en">{E(g["name_fil"])}</span></span>'
               if g["name_en"] != g["name_fil"] else "")
            + 
            f"<p>{bilingual(g['blurb_en'], g['blurb_fil'])}</p>"
            f'<span class="g-tag">{tag}</span>'
            "</article>"
        )
    return out


def build_chips(d):
    out = []
    for i, (key, (en, fil)) in enumerate(d["categories"].items()):
        pressed = "true" if i == 0 else "false"
        out.append(
            f'<button class="chip" type="button" data-cat="{key}" aria-pressed="{pressed}">'
            f"{bilingual(en, fil)}"
            f'<span class="chip-n">{len(d["rosters"][key]["games"])}</span>'
            "</button>"
        )
    return out


CATEGORY_EMOJI = {
    "visual": "👁️", "hearing": "👂", "motor": "🖐️",
    "cognitive": "🧠", "multiple": "♿", "none": "✅",
}


def build_rosters(d):
    out = []
    for i, (key, (en, fil)) in enumerate(d["categories"].items()):
        r = d["rosters"][key]
        rat = r["rationale"]
        hidden = "" if i == 0 else " hidden"
        picks = "".join(
            f'<div class="r-game" style="--g:{d["games"][g]["color"]}">'
            f'<span class="r-dot" aria-hidden="true"></span>'
            f'<span>{bilingual(d["games"][g]["name_en"], d["games"][g]["name_fil"])}</span>'
            "</div>"
            for g in r["games"]
        )
        outs = "".join(
            f'<li>{bilingual(d["games"][g]["name_en"], d["games"][g]["name_fil"])}</li>'
            for g in r["excludes"]
        )
        out.append(
            f'<div class="roster" data-cat="{key}"{hidden}>'
            f'<div class="roster-head">'
            f'<span class="r-emoji" aria-hidden="true">{CATEGORY_EMOJI[key]}</span>'
            f"<h3>{bilingual(en, fil)}</h3>"
            f'<span class="r-count">{bilingual(f"{len(r['games'])} games", f"{len(r['games'])} laro")}</span>'
            f"</div>"
            f'<p class="r-why">{bilingual(rat["en"], rat["fil"])}</p>'
            f'<div class="roster-list">{picks}</div>'
            f'<div class="r-out">'
            f'<h4>{bilingual("Deliberately left out", "Sinadyang hindi isinama")}</h4>'
            f'<p>{bilingual(rat["why_en"], rat["why_fil"])}</p>'
            f"<ul>{outs}</ul>"
            f"</div></div>"
        )
    return out


PAGE_JS = """<script>
(function(){
  // Roster switcher. Every roster is in the HTML already, so with JS off the
  // page simply shows all six - readable, just longer.
  var chips = [].slice.call(document.querySelectorAll('.chips .chip[data-cat]'));
  var panels = [].slice.call(document.querySelectorAll('.roster[data-cat]'));
  if (!chips.length || !panels.length) return;
  function show(cat){
    chips.forEach(function(c){ c.setAttribute('aria-pressed', String(c.dataset.cat === cat)); });
    panels.forEach(function(p){ p.hidden = (p.dataset.cat !== cat); });
  }
  chips.forEach(function(c){
    c.addEventListener('click', function(){ show(c.dataset.cat); });
  });
  // Deep link: #visual, #hearing, ... opens that roster. Handled on load AND
  // on hashchange - a same-document hash change (a link to #motor from this
  // page, or the back button after following one) never re-runs this script,
  // so without the listener those silently do nothing.
  function fromHash(){
    var want = location.hash.replace('#','');
    if (want && panels.some(function(p){ return p.dataset.cat === want; })) show(want);
  }
  addEventListener('hashchange', fromHash);
  fromHash();
})();
</script>"""


def main():
    d = collect()
    words = word_count()
    games = d["games"]
    story = [g for g in d["hub_excluded"]]

    story_en = story_fil = ""
    if story:
        names_en = ", ".join(games[g]["name_en"] for g in story)
        names_fil = ", ".join(games[g]["name_fil"] for g in story)
        story_en = (f"{names_en} is not in the Games tab — it opens from the "
                    f"Stories tab, where it has its own story picker.")
        story_fil = (f"Ang {names_fil} ay wala sa Games tab — bumubukas ito mula sa "
                     f"Stories tab, kung saan may sarili itong pampili ng kuwento.")

    jsonld = {
        "@context": "https://schema.org",
        "@type": "ItemList",
        "name": "FlashLearn PWD — learning games",
        "description": (
            f"The {len(d['order'])} learning games in FlashLearn PWD, and the "
            f"{d['per_category']} each accessibility type is given."
        ),
        "numberOfItems": len(d["order"]),
        "itemListElement": [
            {
                "@type": "ListItem",
                "position": i + 1,
                "name": games[g]["name_en"],
                "description": games[g]["blurb_en"],
            }
            for i, g in enumerate(d["order"])
        ],
    }

    page = TEMPLATE.read_text(encoding="utf-8")
    repl = {
        "<!--GAMES-->": "\n      ".join(build_game_cards(d)),
        "<!--CATCHIPS-->": "\n      ".join(build_chips(d)),
        "<!--ROSTERS-->": "\n    ".join(build_rosters(d)),
        "<!--JSONLD-->": json.dumps(jsonld, ensure_ascii=False, indent=1),
        "<!--PAGEJS-->": PAGE_JS,
        "__COUNT__": str(len(d["order"])),
        "__PER__": str(d["per_category"]),
        "__CATS__": str(len(d["categories"])),
        "__WORDS__": str(words),
        "__STORYNOTE_FIL__": story_fil,
        "__STORYNOTE__": story_en,
    }
    for needle, value in repl.items():
        if needle not in page:
            sys.exit(f"template is missing placeholder {needle}")
        page = page.replace(needle, value)

    leftover = re.findall(r"__[A-Z_]+__|<!--(?:GAMES|CATCHIPS|ROSTERS|JSONLD|PAGEJS)-->", page)
    if leftover:
        sys.exit(f"unfilled placeholders remain: {sorted(set(leftover))}")

    OUT.write_text(page, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"  {len(d['order'])} games ({len(d['combined'])} in the hub, "
          f"{len(d['hub_excluded'])} elsewhere)")
    print(f"  {len(d['categories'])} rosters of {d['per_category']}, "
          f"each cross-checked against game_catalog.dart")
    print(f"  quoting {words} seeded words")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main()
