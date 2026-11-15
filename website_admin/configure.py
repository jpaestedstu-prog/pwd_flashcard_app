"""Connect the website and its admin dashboard to the website's own Firebase project,
and to the email notifier.

    python website_admin/configure.py --project flashlearn-pwd-site --api-key AIza... --app-id 1:123:web:abc
    python website_admin/configure.py --mail-url https://script.google.com/macros/s/.../exec
    python website_admin/configure.py --mail-url ""      (email notices off again)
    python website_admin/configure.py --check

One set of values (from Firebase console -> Project settings -> Your apps -> Web),
written to every place that needs it:

  website_admin/public/config.js   the dashboard: apiKey, authDomain, projectId, appId
  website_admin/.firebaserc        where `firebase deploy` sends the rules and the dashboard
  website_admin/firebase.json      the dashboard's Content-Security-Policy (the sign-in frame)
  website/assets/site.js           STATS: where the public website sends its counts

--mail-url is the web app address of the email notifier (email_notifier/Code.gs,
deployed in the team's Google account; README "Email notices"). It goes to
config.js (MAIL.url, for the dashboard's Tools page) and site.js (NOTIFY.url, for
the feedback form).

Either way it then re-stamps the website's asset fingerprints
(tools/site_chrome_build.py), so returning visitors get the new site.js.
--check fails when any of these disagree, including the one admin email address:
config.js MAIL.to, ADMIN_EMAIL in email_notifier/Code.gs and the address of the
feedback form's "Open in your email app" (website/faq.html).
These values are public by design; the data is protected by the sign-in and
firestore.rules, and the notifier can only ever email ADMIN_EMAIL. No password,
app password or secret key is needed or stored anywhere.
"""
import argparse, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONFIG_JS = os.path.join(HERE, "public", "config.js")
FIREBASERC = os.path.join(HERE, ".firebaserc")
FIREBASE_JSON = os.path.join(HERE, "firebase.json")
SITE_JS = os.path.join(ROOT, "website", "assets", "site.js")
CODE_GS = os.path.join(HERE, "email_notifier", "Code.gs")
FAQ_HTML = os.path.join(ROOT, "website", "faq.html")

CONFIG_FIELD = r"(\n  {name}: ')([^']*)(',)"
STATS = re.compile(r"(var STATS = \{ host: '[^']*', project: ')([^']*)(', key: ')([^']*)(' \};)")
FRAME = re.compile(r"(frame-src https://)([^ ;]+)")
MAIL = re.compile(r"(export const MAIL = \{\r?\n  to: ')([^']*)(',\r?\n  url: ')([^']*)(',\r?\n\};)")
NOTIFY = re.compile(r"(var NOTIFY = \{ url: ')([^']*)(' \};)")
ADMIN_EMAIL = re.compile(r"const ADMIN_EMAIL = '([^']*)';")
FAQ_ADDR = re.compile(r"var addr = \['([^']+)', '([^']+)'\]\.join\('@'\)")
MAIL_URL = re.compile(r"https://script\.google\.com/macros/s/[A-Za-z0-9_-]{20,}/exec")
# The dashboard's CSP lets it reach the notifier's exact address (not every Apps Script)
# and the host Apps Script answers from; neither while email notices are off.
ANSWER_HOST = "https://script.googleusercontent.com"
CONNECT = re.compile(r"(connect-src )([^;]*)(;)")


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
    fj = read(FIREBASE_JSON)
    m = FRAME.search(fj)
    if not m:
        sys.exit("firebase.json: no `frame-src https://...` in the Content-Security-Policy")
    values["frameHost"] = m.group(2)
    m = CONNECT.search(fj)
    if not m:
        sys.exit("firebase.json: no `connect-src ...;` in the Content-Security-Policy")
    values["connectSrc"] = m.group(2).split()
    m = MAIL.search(cfg)
    if not m:
        sys.exit("config.js: no `export const MAIL = { to: '...', url: '...' };` block")
    values["mailTo"], values["mailUrl"] = m.group(2), m.group(4)
    m = NOTIFY.search(read(SITE_JS))
    if not m:
        sys.exit("site.js: no `var NOTIFY = { url: '...' };` line")
    values["siteMailUrl"] = m.group(2)
    m = ADMIN_EMAIL.search(read(CODE_GS))
    if not m:
        sys.exit("email_notifier/Code.gs: no `const ADMIN_EMAIL = '...';` line")
    values["notifierTo"] = m.group(1)
    m = FAQ_ADDR.search(read(FAQ_HTML))
    if not m:
        sys.exit("faq.html: no `var addr = ['...', '...'].join('@')` line")
    values["formTo"] = m.group(1) + "@" + m.group(2)
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
    # Email: one admin address everywhere, and one notifier address.
    if v["notifierTo"] != v["mailTo"]:
        out.append(f"the notifier (Code.gs) emails {v['notifierTo']}, but the dashboard shows {v['mailTo']}")
    if v["formTo"] != v["mailTo"]:
        out.append(f"the feedback form's email button writes to {v['formTo']}, but the dashboard shows {v['mailTo']}")
    if v["siteMailUrl"] != v["mailUrl"]:
        out.append(f"site.js sends notices to {v['siteMailUrl'] or '(nowhere)'}, the dashboard checks {v['mailUrl'] or '(nothing)'}")
    if v["mailUrl"] and not MAIL_URL.fullmatch(v["mailUrl"]):
        out.append(f"{v['mailUrl']} is not an Apps Script web app address (https://script.google.com/macros/s/.../exec)")
    scripts = [t for t in v["connectSrc"] if t.startswith("https://script.google")]
    want = [v["mailUrl"], ANSWER_HOST] if v["mailUrl"] else []
    if scripts != want:
        out.append("the dashboard's Content-Security-Policy (firebase.json connect-src) should allow "
                   + (" and ".join(want) if want else "no Apps Script address while notices are off")
                   + f", not {scripts or 'none'}: run --mail-url again")
    return out


def connect_src(fj, url):
    """firebase.json with connect-src allowing exactly `url` + the answer host (nothing when url is "")."""
    def fix(m):
        keep = [t for t in m.group(2).split() if not t.startswith("https://script.google")]
        return m.group(1) + " ".join(keep + ([url, ANSWER_HOST] if url else [])) + m.group(3)
    return CONNECT.sub(fix, fj, count=1)


def set_mail_url(url):
    """Write the notifier's address (or "" for no notices) to the dashboard and the website."""
    if url and not MAIL_URL.fullmatch(url):
        sys.exit("--mail-url is the notifier's web app address, like https://script.google.com/macros/s/AKfy.../exec "
                 "(Apps Script: Deploy -> Manage deployments -> Web app URL), or \"\" to turn notices off")
    write(CONFIG_JS, MAIL.sub(lambda m: m.group(1) + m.group(2) + m.group(3) + url + m.group(5), read(CONFIG_JS)))
    write(SITE_JS, NOTIFY.sub(lambda m: m.group(1) + url + m.group(3), read(SITE_JS)))
    write(FIREBASE_JSON, connect_src(read(FIREBASE_JSON), url))
    left = problems(current())
    if left:
        sys.exit("still inconsistent: " + "; ".join(left))
    print("email notices " + (f"go through {url}" if url else "are off (the form saves to the dashboard only)"), flush=True)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "site_chrome_build.py")], check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--project")
    ap.add_argument("--api-key")
    ap.add_argument("--app-id")
    ap.add_argument("--auth-domain", help="default: <project>.firebaseapp.com")
    ap.add_argument("--mail-url", help='the email notifier\'s web app address (…/exec), or "" for no email notices')
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        v = current()
        found = problems(v)
        for p in found:
            print("problem:", p)
        if not found:
            print("website and dashboard both use", v["projectId"])
            print("admin email everywhere:", v["mailTo"], "| email notices:",
                  ("on, " + v["mailUrl"]) if v["mailUrl"] else "not set up yet (--mail-url)")
        sys.exit(1 if found else 0)
    if a.mail_url is not None and not (a.project or a.api_key or a.app_id):
        set_mail_url(a.mail_url.strip())
        return
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
    if a.mail_url is not None:
        set_mail_url(a.mail_url.strip())   # also re-stamps the fingerprints
        return
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "site_chrome_build.py")], check=True)


if __name__ == "__main__":
    main()
