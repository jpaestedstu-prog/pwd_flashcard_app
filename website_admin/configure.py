"""Connect the website and its admin dashboard to the website's own Firebase project.

    python website_admin/configure.py --project flashlearn-pwd-site --api-key AIza... --app-id 1:123:web:abc
    python website_admin/configure.py --check

One set of values (from Firebase console -> Project settings -> Your apps -> Web),
written to every place that needs it:

  website_admin/public/config.js   the dashboard: apiKey, authDomain, projectId, appId
  website_admin/.firebaserc        where `firebase deploy` sends the rules and the dashboard
  website_admin/firebase.json      the dashboard's Content-Security-Policy (the sign-in frame)
  website/assets/site.js           STATS: where the public website sends its counts

then re-stamps the website's asset fingerprints (tools/site_chrome_build.py), so
returning visitors get the new site.js. --check fails when the four disagree.
These values are public by design; the data is protected by the sign-in and
firestore.rules, not by keeping them secret.
"""
import argparse, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONFIG_JS = os.path.join(HERE, "public", "config.js")
FIREBASERC = os.path.join(HERE, ".firebaserc")
FIREBASE_JSON = os.path.join(HERE, "firebase.json")
SITE_JS = os.path.join(ROOT, "website", "assets", "site.js")

CONFIG_FIELD = r"(\n  {name}: ')([^']*)(',)"
STATS = re.compile(r"(var STATS = \{ host: '[^']*', project: ')([^']*)(', key: ')([^']*)(' \};)")
FRAME = re.compile(r"(frame-src https://)([^ ;]+)")


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def current():
    cfg = read(CONFIG_JS)
    values = {}
    for name in ("apiKey", "authDomain", "projectId", "appId"):
        m = re.search(CONFIG_FIELD.format(name=name), cfg)
        if not m:
            sys.exit(f"config.js: no `{name}: '...'` line")
        values[name] = m.group(2)
    m = STATS.search(read(SITE_JS))
    if not m:
        sys.exit("site.js: no `var STATS = { host: '...', project: '...', key: '...' };` line")
    values["siteProject"], values["siteKey"] = m.group(2), m.group(4)
    values["deployProject"] = json.loads(read(FIREBASERC))["projects"]["default"]
    m = FRAME.search(read(FIREBASE_JSON))
    if not m:
        sys.exit("firebase.json: no `frame-src https://...` in the Content-Security-Policy")
    values["frameHost"] = m.group(2)
    return values


def problems(v):
    out = []
    if not v["apiKey"]:
        out.append("not set up yet: config.js has no apiKey (run with --project/--api-key/--app-id)")
    if v["siteProject"] != v["projectId"] or v["siteKey"] != v["apiKey"]:
        out.append(f"site.js sends counts to {v['siteProject'] or '(nowhere)'}, the dashboard reads {v['projectId']}")
    if v["deployProject"] != v["projectId"]:
        out.append(f".firebaserc deploys to {v['deployProject']}, the dashboard reads {v['projectId']}")
    if v["frameHost"] != v["authDomain"]:
        out.append(f"the CSP allows the sign-in frame from {v['frameHost']}, but authDomain is {v['authDomain']}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--project")
    ap.add_argument("--api-key")
    ap.add_argument("--app-id")
    ap.add_argument("--auth-domain", help="default: <project>.firebaseapp.com")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        found = problems(current())
        for p in found:
            print("problem:", p)
        if not found:
            print("website and dashboard both use", current()["projectId"])
        sys.exit(1 if found else 0)
    if not (a.project and a.api_key and a.app_id):
        ap.error("--project, --api-key and --app-id are needed (or --check)")
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", a.project):
        ap.error("--project is a Firebase project ID such as flashlearn-pwd-site")
    if not re.fullmatch(r"AIza[0-9A-Za-z_-]{35}", a.api_key):
        ap.error("--api-key looks like AIza followed by 35 letters, digits, - or _")
    if not re.fullmatch(r"1:\d+:web:[0-9a-f]+", a.app_id):
        ap.error("--app-id looks like 1:123456789:web:abc123")
    domain = a.auth_domain or a.project + ".firebaseapp.com"

    cfg = read(CONFIG_JS)
    for name, value in (("apiKey", a.api_key), ("authDomain", domain), ("projectId", a.project), ("appId", a.app_id)):
        cfg = re.sub(CONFIG_FIELD.format(name=name), lambda m: m.group(1) + value + m.group(3), cfg)
    write(CONFIG_JS, cfg)
    write(SITE_JS, STATS.sub(lambda m: m.group(1) + a.project + m.group(3) + a.api_key + m.group(5), read(SITE_JS)))
    rc = json.loads(read(FIREBASERC))
    rc["projects"]["default"] = a.project
    write(FIREBASERC, json.dumps(rc, indent=2) + "\n")
    write(FIREBASE_JSON, FRAME.sub(lambda m: m.group(1) + domain, read(FIREBASE_JSON)))
    left = problems(current())
    if left:
        sys.exit("still inconsistent: " + "; ".join(left))
    print(f"website and dashboard now use {a.project}", flush=True)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "site_chrome_build.py")], check=True)


if __name__ == "__main__":
    main()
