"""One-off before the 1.4.1 rules: file what they need for everyone already
in a class or family group.

    FIREBASE_ACCESS_TOKEN=<owner token> python tool/privacy_backfill.py           # dry run
    FIREBASE_ACCESS_TOKEN=<owner token> python tool/privacy_backfill.py --apply

From 1.4.1 a device reads a learner's profile and progress only as the
learner's own device, one of their educators, or a device with a profile in
the same class or family group, and reads a class or family document (which
holds its join code) and its roster only as its teacher or parent or as a
member's device. An educator's 30-learner queries and the tests it sets are
checked against its roster. The 1.4.1 app files all of this itself, on
joining and at start; older apps do not, so this files it for every
membership that already exists:

  * a group link `group_readers/{group}_{device}` for each device with a
    profile in a class or family group (naming one such profile);
  * a roster `educator_rosters/{device}` for each teacher's and parent's
    device: every member of their classes and family groups, and the
    learners on the device itself;
  * `teacher_uid` / `owner_uid` on each class and family group: the device
    whose roster a 1.4.1 learner joining later joins.

Creates group links and rosters that do not exist (never overwrites one) and
adds a missing or out-of-date device field to a group; touches nothing else.
Then reports, without writing, what the new rules will refuse that exists
today: assignments naming learners off their setter's roster. Safe to run
again. The token must belong to a project owner (it bypasses the rules); it
is read from the environment and never printed, and nor are ids. Standard
library only.
"""
import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "pwd-flashcard"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
# Tested against the local emulator first: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
# with FIREBASE_ACCESS_TOKEN=owner (the emulator's admin token) and a demo project.
if os.environ.get("FIRESTORE_EMULATOR_HOST"):
    PROJECT = os.environ.get("FLASHLEARN_PROJECT", "demo-flashlearn")
    FS = (f"http://{os.environ['FIRESTORE_EMULATOR_HOST']}/v1/projects/{PROJECT}"
          "/databases/(default)/documents")
LEARNER_ROLES = {0, 3}  # student, child
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


def value(v):
    (t, x), = v.items()
    if t == "integerValue":
        return int(x)
    if t == "mapValue":
        return {k: value(y) for k, y in (x.get("fields") or {}).items()}
    if t == "arrayValue":
        return [value(y) for y in x.get("values", [])]
    return x


def plain(fields):
    return {k: value(v) for k, v in (fields or {}).items()}


def doc_id(d):
    return d["name"].rsplit("/", 1)[1]


def strings(d):
    return {"mapValue": {"fields": {k: {"stringValue": v} for k, v in d.items()}}}


def field_path(*parts):
    """A Firestore field path, each part back-quoted (ids carry hyphens)."""
    return ".".join("`" + p.replace("\\", "\\\\").replace("`", "\\`") + "`" for p in parts)


def main():
    apply = "--apply" in sys.argv
    tok = os.environ.get("FIREBASE_ACCESS_TOKEN")
    if not tok:
        sys.exit("Set FIREBASE_ACCESS_TOKEN to a project owner's access token.")

    profiles = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "profiles")}
    classes = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "classrooms")}
    groups = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "home_groups")}
    links = {doc_id(d) for d in list_all(tok, "group_readers")}
    rosters = {doc_id(d): plain(d.get("fields")) for d in list_all(tok, "educator_rosters")}

    def device_of(profile_id):
        return (profiles.get(profile_id) or {}).get("owner_uid") or None

    want_links = {}    # link id -> fields
    want_roster = {}   # educator device -> {learner: (learner device, group)}
    want_names = []    # (collection, group id, field, device)
    skipped = {"learner deleted or on no device": 0, "group or its owner gone": 0}

    def membership(kind, group_id, learner, owner_profile):
        learner_uid = device_of(learner)
        if not learner_uid:
            skipped["learner deleted or on no device"] += 1
            return
        educator_uid = device_of(owner_profile)
        if not educator_uid:
            skipped["group or its owner gone"] += 1
            return
        want_links.setdefault(f"{group_id}_{learner_uid}", {
            "group_id": group_id, "profile_id": learner, "kind": kind})
        want_roster.setdefault(educator_uid, {}).setdefault(learner, (learner_uid, group_id))

    for m in list_all(tok, "classroom_members"):
        f = plain(m.get("fields"))
        c = f.get("classroom_id")
        membership("class", c, f.get("profile_id"), (classes.get(c) or {}).get("teacher_id"))
    for m in list_all(tok, "home_group_members"):
        f = plain(m.get("fields"))
        g = f.get("home_group_id")
        membership("family", g, f.get("profile_id"), (groups.get(g) or {}).get("owner_profile_id"))

    # The learners on each educator's own device (a shared classroom tablet).
    educator_devices = set(want_roster) | {
        device_of(c.get("teacher_id")) for c in classes.values()} | {
        device_of(g.get("owner_profile_id")) for g in groups.values()}
    educator_devices.discard(None)
    for pid, p in profiles.items():
        uid = p.get("owner_uid")
        if uid in educator_devices and p.get("role") in LEARNER_ROLES \
                and not p.get("is_guest_player"):
            want_roster.setdefault(uid, {}).setdefault(pid, (uid, "device"))

    for coll, items, owner_field, field in (
            ("classrooms", classes, "teacher_id", "teacher_uid"),
            ("home_groups", groups, "owner_profile_id", "owner_uid")):
        for gid, g in items.items():
            uid = device_of(g.get(owner_field))
            if uid and g.get(field) != uid:
                want_names.append((coll, gid, field, uid))

    new_links = {k: v for k, v in want_links.items() if k not in links}
    roster_adds = {
        uid: {pid: e for pid, e in learners.items()
              if (rosters.get(uid) or {}).get("learners", {}).get(pid) != e[0]}
        for uid, learners in want_roster.items()}
    roster_adds = {uid: adds for uid, adds in roster_adds.items() if adds}
    print(f"group links: {len(want_links)} wanted, {len(want_links) - len(new_links)} already filed, "
          f"{len(new_links)} to create")
    print(f"rosters: {len(want_roster)} educator devices, {sum(map(len, want_roster.values()))} entries; "
          f"{sum(map(len, roster_adds.values()))} entries to add on {len(roster_adds)} devices "
          f"({sum(1 for u in roster_adds if u in rosters)} of them existing rosters)")
    print(f"device named on classes and family groups: {len(want_names)} to set")
    print("skipped memberships: " + ", ".join(f"{k} {v}" for k, v in skipped.items()))

    # What the new rules refuse that exists today (reported, not changed).
    uncovered = 0
    assignments = list_all(tok, "assessment_assignments")
    for d in assignments:
        a = plain(d.get("fields"))
        roster = {pid for pid in want_roster.get(device_of(a.get("assignedBy")), {})}
        if set(a.get("studentIds") or []) - roster:
            uncovered += 1
    print(f"assignments: {len(assignments)}; {uncovered} name a learner off their setter's roster "
          "(they stay; only adding learners to them is checked)")

    if not apply:
        print("dry run: nothing written (add --apply)")
        return

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    ok = failed = 0

    def report(st, what):
        nonlocal ok, failed
        if st == 200:
            ok += 1
        else:
            failed += 1
            print(f"  not written: {what} ({st})")

    for link_id, f in sorted(new_links.items()):
        fields = {k: {"stringValue": v} for k, v in f.items()}
        fields["updated_at"] = {"timestampValue": now}
        st, _ = call("PATCH", f"{FS}/group_readers/{link_id}?currentDocument.exists=false", tok,
                     {"fields": fields})
        report(st, f"group link {link_id[:6]}...")

    for uid, adds in sorted(roster_adds.items()):
        learners = {pid: e[0] for pid, e in adds.items()}
        via = {pid: e[1] for pid, e in adds.items()}
        if uid not in rosters:
            st, _ = call("PATCH", f"{FS}/educator_rosters/{uid}?currentDocument.exists=false", tok, {
                "fields": {"learners": strings(learners), "via": strings(via),
                           "learner": {"stringValue": ""}, "updated_at": {"timestampValue": now}}})
        else:
            mask = [field_path("learners", pid) for pid in adds] + [
                field_path("via", pid) for pid in adds] + ["updated_at"]
            q = "&".join("updateMask.fieldPaths=" + urllib.parse.quote(m) for m in mask)
            st, _ = call("PATCH", f"{FS}/educator_rosters/{uid}?currentDocument.exists=true&{q}", tok, {
                "fields": {"learners": strings(learners), "via": strings(via),
                           "updated_at": {"timestampValue": now}}})
        report(st, f"roster {uid[:6]}... ({len(adds)})")

    for coll, gid, field, uid in want_names:
        st, _ = call("PATCH", f"{FS}/{coll}/{gid}?currentDocument.exists=true"
                              f"&updateMask.fieldPaths={field}", tok,
                     {"fields": {field: {"stringValue": uid}}})
        report(st, f"{coll} {gid[:6]}...")

    print(f"written {ok}, failed {failed}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
