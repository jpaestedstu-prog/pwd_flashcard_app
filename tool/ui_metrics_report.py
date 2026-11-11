#!/usr/bin/env python3
"""Prints what test/surveys/ui_metrics_survey_test.dart measured.

    python tool/ui_metrics_report.py [phone360|honorP|honorL|desktop]
"""
import collections
import glob
import json
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
only = sys.argv[1] if len(sys.argv) > 1 else None

data = {}
for path in glob.glob("build/ui_metrics_*.json"):
    data.update(json.load(open(path, encoding="utf-8")))

print(f"{len(data)} screen-and-size combinations")
worst = {}
hist = collections.Counter()
for key, v in data.items():
    combo = key.split(" | ")[1]
    if only and not combo.startswith(only):
        continue
    for where, r in v["labels"].items():
        hist[f"{combo.split()[0]} lines={r['lines']}"] += 1
        old = worst.get(where)
        if old is None or (r["lines"], -r["side"]) > (old[0]["lines"], -old[0]["side"]):
            worst[where] = (r, key)

print("\n== labels on three or more lines")
rows = [x for x in worst.items() if x[1][0]["lines"] >= 3]
for where, (r, key) in sorted(rows, key=lambda x: -x[1][0]["lines"]):
    print(f"{r['lines']} lines, {r['w']}x{r['h']}, side {r['side']}, {r['font']}px  {where}  '{r['text']}'  [{key.split(' | ')[1]}]")

print("\n== labels on two lines in a button under 200 wide (top 60 by width)")
rows = [x for x in worst.items() if x[1][0]["lines"] == 2 and x[1][0]["w"] < 200]
for where, (r, key) in sorted(rows, key=lambda x: x[1][0]["w"])[:60]:
    print(f"{r['w']}x{r['h']}, side {r['side']}, {r['font']}px  {where}  '{r['text']}'  [{key.split(' | ')[1]}]")

print("\n== off centre by 3 px or more")
for where, (r, key) in worst.items():
    if float(r["off"]) >= 3:
        print(f"off {r['off']}  {r['w']}x{r['h']}  {where}  '{r['text']}'  [{key.split(' | ')[1]}]")

print("\n== side-by-side buttons at different heights")
c = collections.Counter()
for key, v in data.items():
    if only and not key.split(" | ")[1].startswith(only):
        continue
    for x in v["rows"]:
        c[x] += 1
for x, n in c.most_common(40):
    print(f"{n:4d}  {x}")

print("\n== stretched")
c = collections.Counter()
ex = {}
for key, v in data.items():
    combo = key.split(" | ")[1]
    if only and not combo.startswith(only):
        continue
    for x in v["stretched"]:
        kind, measure, where = x.split(" ", 2)
        c[(kind, where)] += 1
        m = ex.get((kind, where))
        val = int(measure.rstrip("em"))
        if m is None or val > m:
            ex[(kind, where)] = val
for (kind, where), n in c.most_common(120):
    print(f"{n:4d}  {kind:10s} up to {ex[(kind, where)]:5d}  {where}")

def tally(field, title, limit=60):
    print(f"\n== {title}")
    c = collections.Counter()
    best = {}
    for key, v in data.items():
        combo = key.split(" | ")[1]
        if only and not combo.startswith(only):
            continue
        for x in v.get(field, []):
            if field == "tiny":
                size, rest = x.split(" ", 1)
                k = rest.split(' "')[0]
                val = float(size)
                if k not in best or val < best[k]:
                    best[k] = val
            else:
                k = x
            c[k] += 1
    for k, n in c.most_common(limit):
        print(f"{n:4d}  {best.get(k, '')}  {k}")


tally("tiny", "text drawn under 11 px")
tally("clipped", "text cut off by a fixed box")
tally("panels", "light panels on a dark page")
print("\n== how many lines, by size")
for k, n in sorted(hist.items()):
    print(f"{k}: {n}")
