#!/usr/bin/env python3
"""Reads what tool/run_surveys.sh wrote to build/ and prints it by finding.

    python tool/survey_report.py [crawl|matrix|language]
"""
import collections
import glob
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
what = sys.argv[1] if len(sys.argv) > 1 else "all"


def load(pattern):
    data = {}
    for path in glob.glob(pattern):
        data.update(json.load(open(path, encoding="utf-8")))
    return data


def crawl(pattern, title):
    data = load(pattern)
    if not data:
        return
    total = sum(len(v["presses"]) for v in data.values())
    print(f"== {title}: {len(data)} screens, {total} presses")
    problems = collections.defaultdict(list)
    cut = collections.defaultdict(set)
    routes = set()
    dead = []
    for screen, v in data.items():
        for p in v["presses"]:
            if p.get("result") == "not found again":
                continue
            where = f"{screen} > {p['name'][:40]}"
            for x in p.get("problems", []):
                problems[x].append(where)
            for c in p.get("cut", []):
                cut[c].add(where)
            routes.update(p.get("routes", []))
            if not any(p.get(k) for k in ("changed", "routes", "platform", "problems")):
                dead.append(where)
    print(f"-- problems: {len(problems)}")
    for k, v in sorted(problems.items(), key=lambda kv: -len(kv[1])):
        print(f"{len(v):4d} {k[:170]}\n       e.g. {v[0]}")
    print(f"-- cut after a press: {len(cut)}")
    for k, v in sorted(cut.items()):
        print(f"{len(v):4d} {k[:130]}  e.g. {sorted(v)[0][:60]}")
    print(f"-- no visible effect: {len(dead)}")
    for d in dead:
        print("    ", d)
    print(f"-- routes asked for: {len(routes)}")
    reader = collections.defaultdict(set)
    small = collections.defaultdict(set)
    covered = collections.defaultdict(set)
    for screen, v in data.items():
        for x in v.get("covered", []):
            covered[x].add(screen)
        for x in v.get("reader", []):
            reader[x].add(screen)
        for x in v.get("small", []):
            small[x].add(screen)
    print(f"-- screen reader findings in the states reached: {len(reader)}")
    for k, v in sorted(reader.items()):
        print(f"{len(v):4d} {k[:170]}  e.g. {sorted(v)[0][:40]}")
    print(f"-- a reader can press, a finger cannot reach: {len(covered)}")
    for k, v in sorted(covered.items()):
        print(f"{len(v):4d} {k[:170]}  e.g. {sorted(v)[0][:40]}")
    print(f"-- targets under 48 dp: {len(small)}")
    for k, v in sorted(small.items()):
        print(f"{len(v):4d} {k[:120]}  e.g. {sorted(v)[0][:40]}")


def matrix():
    data = load("build/matrix_*.json")
    print(f"== layout matrix: {len(data)} combinations with a finding")
    cuts = collections.defaultdict(set)
    errs = collections.defaultdict(set)
    over = collections.defaultdict(set)
    for key, r in data.items():
        for c in r.get("cut", []):
            where, _, text = c.partition(" | ")
            cuts[where].add((key, text))
        for e in r.get("errors", []):
            errs[e].add(key)
        for o in r.get("overlaps", []):
            over[o].add(key)
    print(f"-- errors and overflows: {len(errs)}")
    for e, keys in sorted(errs.items(), key=lambda kv: -len(kv[1])):
        print(f"{len(keys):4d} {e[:150]}\n       e.g. {sorted(keys)[0][:90]}")
    print(f"-- cut: {len(cuts)}")
    for w, items in sorted(cuts.items(), key=lambda kv: -len(kv[1])):
        texts = sorted({t for _, t in items})
        print(f'{len(items):4d} {w}  "{texts[0][:46]}"  e.g. {sorted(k for k, _ in items)[0][:60]}')
    print(f"-- text over text: {len(over)}")
    for o, keys in sorted(over.items(), key=lambda kv: -len(kv[1])):
        print(f"{len(keys):4d} {o[:170]}\n       e.g. {sorted(keys)[0][:90]}")


def language():
    for pattern, title in (
        ("build/english_*.json", "English seen on Filipino screens"),
        ("build/filipino_*.json", "Filipino seen on English screens"),
    ):
        merged = collections.defaultdict(set)
        for path in glob.glob(pattern):
            for k, v in json.load(open(path, encoding="utf-8")).items():
                merged[k].update(v)
        if not merged:
            continue
        print(f"== {title}: {sum(len(v) for v in merged.values())} strings")
        for where, texts in sorted(merged.items()):
            for t in sorted(texts):
                print(f"{where} | {re.sub(chr(10), ' / ', t)[:140]}")



def vocabulary():
    """What was read on the Filipino screens, weighed against the two
    translation files: mostly words only the English file uses."""
    words = re.compile(r"[A-Za-z][A-Za-z'’-]+")

    def vocab(path):
        data = json.load(open(path, encoding="utf-8"))
        out = set()
        for k, v in data.items():
            if k.startswith("@") or not isinstance(v, str):
                continue
            out.update(w.lower() for w in words.findall(v))
        return out

    en = vocab("lib/l10n/app_en.arb")
    fil = vocab("lib/l10n/app_fil.arb")
    only_en = en - fil
    seen = collections.defaultdict(set)
    for path in glob.glob("build/seen_fil_*.json"):
        for k, v in json.load(open(path, encoding="utf-8")).items():
            seen[k].update(v)
    rows = []
    for where, texts in seen.items():
        for t in texts:
            tokens = [w.lower() for w in words.findall(t)]
            hits = [w for w in tokens if w in only_en]
            if len(tokens) >= 2 and len(hits) >= 2 and len(hits) >= len(tokens) * 0.5:
                rows.append((where, t))
    print(f"== mostly English words on Filipino screens: {len(rows)} strings")
    for where, t in sorted(rows):
        print(f"{where} | {re.sub(chr(10), ' / ', t)[:140]}")


if what in ("all", "crawl"):
    crawl("build/crawl_normal*.json", "pressed, tablet size, English")
    crawl("build/crawl_small*.json", "pressed, small phone, largest text, Filipino")
if what in ("all", "matrix"):
    matrix()
if what in ("all", "language"):
    language()
    vocabulary()
