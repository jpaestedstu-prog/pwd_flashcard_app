"""One-off: remove the private fields the join flows used to copy to the cloud.

    FIREBASE_ACCESS_TOKEN=<owner token> python tool/profile_private_fields_cleanup.py                 # dry run
    FIREBASE_ACCESS_TOKEN=<owner token> python tool/profile_private_fields_cleanup.py --apply BACKUP.json

Until 1.4.1, joining a class or family group wrote the learner's PIN hash,
PIN salt, PIN algorithm, birth date and grade level into `profiles/{id}`,
which any signed-in user who knows the id can read. No version of the app has
ever read them back from the cloud (the device keeps its own copy), so they
were only an exposure: a 4-digit PIN falls to a brute force of its salted
hash in moments. This removes those five fields and nothing else (an update
mask names only them); every other field is left as it is.

With --apply, the birth dates and grade levels it removes are first written
to BACKUP.json, a local file the owner keeps or deletes (the PIN fields are
not kept: they are credentials, and the device has the PIN). The token must
belong to a project owner (it bypasses the rules); it is read from the
environment and never printed. Standard library only.
"""
import json
import os
import sys
import urllib.error
import urllib.request

PROJECT = "pwd-flashcard"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
FIELDS = ["pin_hash", "pin_salt", "pin_hash_algorithm", "birth_date", "grade_level"]
KEPT_IN_BACKUP = ["birth_date", "grade_level"]
sys.stdout.reconfigure(encoding="utf-8")


def call(method, url, tok, body=None):
    req = urllib.request.Request(
        url, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]


def list_all(tok, coll):
    docs, page = [], None
    while True:
        url = f"{FS}/{coll}?pageSize=300" + (f"&pageToken={page}" if page else "")
        st, res = call("GET", url, tok)
        if st != 200:
            sys.exit(f"list {coll} failed: {st} {res}")
        docs += res.get("documents", [])
        page = res.get("nextPageToken")
        if not page:
            return docs


def doc_id(d):
    return d["name"].rsplit("/", 1)[1]


def main():
    apply = "--apply" in sys.argv
    tok = os.environ.get("FIREBASE_ACCESS_TOKEN")
    if not tok:
        sys.exit("Set FIREBASE_ACCESS_TOKEN to a project owner's access token.")
    backup_path = None
    if apply:
        rest = [a for a in sys.argv[1:] if a != "--apply"]
        if len(rest) != 1:
            sys.exit("--apply needs the path of the local backup file for the removed birth dates.")
        backup_path = rest[0]
        if os.path.exists(backup_path):
            sys.exit(f"{backup_path} already exists; choose a new file.")

    targets = {}  # profile id -> {field: Firestore value} for the fields present
    for d in list_all(tok, "profiles"):
        present = {k: v for k, v in d.get("fields", {}).items() if k in FIELDS}
        if present:
            targets[doc_id(d)] = present

    def counted(field, real):
        return sum(1 for p in targets.values()
                   if field in p and ("nullValue" not in p[field]) == real)

    print(f"profiles holding any of the fields: {len(targets)}")
    for f in FIELDS:
        print(f"  {f}: {counted(f, True)} with a value, {counted(f, False)} empty")
    if not apply:
        print("dry run: nothing changed (add --apply BACKUP.json)")
        return

    backup = {pid: {k: next(iter(v.values())) for k, v in p.items()
                    if k in KEPT_IN_BACKUP and "nullValue" not in v}
              for pid, p in targets.items()}
    backup = {pid: v for pid, v in backup.items() if v}
    with open(backup_path, "x", encoding="utf-8") as fh:
        json.dump(backup, fh, indent=1, sort_keys=True)
    print(f"backup: {len(backup)} profiles' birth dates / grade levels written to the local file")

    mask = "&".join(f"updateMask.fieldPaths={f}" for f in FIELDS)
    cleaned = failed = 0
    for pid in sorted(targets):
        st, res = call("PATCH", f"{FS}/profiles/{pid}?{mask}&currentDocument.exists=true", tok, {"fields": {}})
        if st == 200:
            cleaned += 1
        else:
            failed += 1
            print(f"  not cleaned: {pid[:8]}... ({st})")
    print(f"cleaned {cleaned}, failed {failed}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
