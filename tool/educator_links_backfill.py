"""One-off: file an educator link for every teacher/parent-learner relationship.

    FIREBASE_ACCESS_TOKEN=<owner token> python tool/educator_links_backfill.py           # dry run
    FIREBASE_ACCESS_TOKEN=<owner token> python tool/educator_links_backfill.py --apply

Since 2026-10-13 the security rules let a device read or write the notes about
a learner, and set their time limits, alarms, routines and unlocks, only if it
is the learner's own device or holds an educator link,
`note_readers/{device uid}_{learner}`, naming a class or family group it owns
that the learner is a member of ([educatesLearner] in firestore.rules). The
1.4.0 app files those links itself. Older apps do not, so before the rules
went live this created one for every relationship that already existed: for
each class membership, the device that owns the class's teacher profile; for
each family membership, the device that owns the group's owner profile.

Only creates documents in `note_readers`, and never overwrites one (each write
is conditional on the document not existing). Reads the rest. The token must
belong to a project owner (it bypasses the rules); it is read from the
environment and never printed. Standard library only.
"""
import datetime
import json
import os
import sys
import urllib.error
import urllib.request

PROJECT = "pwd-flashcard"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
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


def plain(fields):
    out = {}
    for k, v in (fields or {}).items():
        (t, x), = v.items()
        out[k] = x
    return out


def doc_id(d):
    return d["name"].rsplit("/", 1)[1]


def main():
    apply = "--apply" in sys.argv
    tok = os.environ.get("FIREBASE_ACCESS_TOKEN")
    if not tok:
        sys.exit("Set FIREBASE_ACCESS_TOKEN to a project owner's access token.")

    profiles = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "profiles")}
    classes = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "classrooms")}
    groups = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "home_groups")}
    existing = {doc_id(d) for d in list_all(tok, "note_readers")}

    def device_of(profile_id):
        return (profiles.get(profile_id) or {}).get("owner_uid") or None

    wanted = {}  # link id -> fields
    skipped = {"owner has no device": 0, "learner deleted": 0}
    for m in list_all(tok, "classroom_members"):
        f = plain(m.get("fields"))
        c, learner = f.get("classroom_id"), f.get("profile_id")
        if learner not in profiles:
            skipped["learner deleted"] += 1
            continue
        uid = device_of((classes.get(c) or {}).get("teacher_id"))
        if not uid:
            skipped["owner has no device"] += 1
            continue
        wanted.setdefault(f"{uid}_{learner}", {"profile_id": learner, "classroom_id": c})
    for m in list_all(tok, "home_group_members"):
        f = plain(m.get("fields"))
        g, learner = f.get("home_group_id"), f.get("profile_id")
        if learner not in profiles:
            skipped["learner deleted"] += 1
            continue
        uid = device_of((groups.get(g) or {}).get("owner_profile_id"))
        if not uid:
            skipped["owner has no device"] += 1
            continue
        wanted.setdefault(f"{uid}_{learner}", {"profile_id": learner, "home_group_id": g})

    to_create = {k: v for k, v in wanted.items() if k not in existing}
    print(f"relationships: {len(wanted)} links wanted, {len(wanted) - len(to_create)} already filed, "
          f"{len(to_create)} to create; skipped: "
          + ", ".join(f"{k} {v}" for k, v in skipped.items()))
    if not apply:
        print("dry run: nothing written (add --apply)")
        return

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    created = failed = 0
    for link_id, f in sorted(to_create.items()):
        fields = {k: {"stringValue": v} for k, v in f.items()}
        fields["updated_at"] = {"timestampValue": now}
        st, res = call("PATCH", f"{FS}/note_readers/{link_id}?currentDocument.exists=false", tok,
                       {"fields": fields})
        if st == 200:
            created += 1
        else:
            failed += 1
            print(f"  not created: {link_id[:10]}... ({st})")
    print(f"created {created}, failed {failed}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
