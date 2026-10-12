"""How close the cloud runs to the free Spark plan's daily limits. READ-ONLY.

    FIREBASE_ACCESS_TOKEN=<owner token> python tool/usage_report.py [days]

Reads the project's own Firestore usage from Google Cloud Monitoring (reading
metrics is free) and prints, per day, document reads, writes and deletes
against the Spark plan's daily quotas, flagging a day above 70 %. The plan
has no billing account, so going over a quota cannot cost money: Firestore
simply refuses further requests until the quota resets (midnight Pacific
time), and the app keeps working offline meanwhile. See docs/costs.md.

The token must belong to a project owner; it is read from the environment
and never printed. Standard library only.
"""
import datetime
import json
import os
import sys
import urllib.parse
import urllib.request

PROJECT = "pwd-flashcard"
QUOTAS = {  # Spark plan, per day
    "firestore.googleapis.com/document/read_count": ("reads", 50_000),
    "firestore.googleapis.com/document/write_count": ("writes", 20_000),
    "firestore.googleapis.com/document/delete_count": ("deletes", 20_000),
}
sys.stdout.reconfigure(encoding="utf-8")


def series(tok, metric, start, end):
    params = urllib.parse.urlencode({
        "filter": f'metric.type="{metric}"',
        "interval.startTime": start.isoformat().replace("+00:00", "Z"),
        "interval.endTime": end.isoformat().replace("+00:00", "Z"),
        "aggregation.alignmentPeriod": "86400s",
        "aggregation.perSeriesAligner": "ALIGN_SUM",
        "aggregation.crossSeriesReducer": "REDUCE_SUM",
    })
    req = urllib.request.Request(
        f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/timeSeries?{params}",
        headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        body = json.loads(r.read())
    out = {}
    for ts in body.get("timeSeries", []):
        for p in ts.get("points", []):
            day = p["interval"]["endTime"][:10]
            out[day] = out.get(day, 0) + int(p["value"].get("int64Value", 0))
    return out


def main():
    tok = os.environ.get("FIREBASE_ACCESS_TOKEN")
    if not tok:
        sys.exit("Set FIREBASE_ACCESS_TOKEN to a project owner's access token.")
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 14
    end = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    start = end - datetime.timedelta(days=days)
    table = {}
    for metric, (name, _) in QUOTAS.items():
        for day, n in series(tok, metric, start, end).items():
            table.setdefault(day, {})[name] = n
    print(f"Firestore use per day (last {days} days) against the Spark plan's daily quotas")
    print(f"{'day':<12}{'reads':>14}{'writes':>14}{'deletes':>14}")
    worst = 0.0
    for day in sorted(table):
        row = table[day]
        cells = []
        for _, (name, quota) in QUOTAS.items():
            n = row.get(name, 0)
            share = n / quota
            worst = max(worst, share)
            cells.append(f"{n:>7} ({share:>4.0%})" + ("!" if share >= 0.7 else " "))
        print(f"{day:<12}" + "".join(f"{c:>14}" for c in cells))
    print(f"busiest share of any quota: {worst:.0%}" + ("  <-- above 70 %" if worst >= 0.7 else ""))


if __name__ == "__main__":
    main()
