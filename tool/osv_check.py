"""Known vulnerabilities in the app's Dart packages, from the free OSV database.

    python tool/osv_check.py

Reads pubspec.lock and asks https://api.osv.dev (Google's open vulnerability
database) about every hosted package at its locked version. Sends only
package names and versions. Prints each advisory; exits 1 if there is one.
"""
import json, re, sys, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
lock = open("pubspec.lock", encoding="utf-8").read()
packages = []
for m in re.finditer(r'\n  ([a-z0-9_]+):\n((?:    .*\n)+)', lock):
    name, body = m.group(1), m.group(2)
    if 'source: hosted' not in body:
        continue
    v = re.search(r'version: "([^"]+)"', body)
    if v:
        packages.append((name, v.group(1)))

queries = [{"package": {"name": n, "ecosystem": "Pub"}, "version": v} for n, v in packages]
found = []
for i in range(0, len(queries), 500):
    req = urllib.request.Request(
        "https://api.osv.dev/v1/querybatch",
        data=json.dumps({"queries": queries[i:i + 500]}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        results = json.loads(r.read())["results"]
    for (n, v), res in zip(packages[i:i + 500], results):
        for vuln in res.get("vulns", []):
            found.append((n, v, vuln["id"]))

print(f"{len(packages)} hosted Dart packages checked against OSV")
for n, v, vid in found:
    print(f"  {n} {v}: {vid}")
print("OSV: no known vulnerabilities" if not found else f"OSV: {len(found)} advisories")
sys.exit(1 if found else 0)
