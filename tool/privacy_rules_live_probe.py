"""Probe the DEPLOYED Firestore rules for 1.4.1's privacy rules.

    python tool/privacy_rules_live_probe.py

Checks, against production, that a stranger who knows a learner's or a
class's id can no longer read the learner's profile or progress, the class
document (with its join code) or its roster, join it without the code, file a
group link into it, or put themselves on a teacher's roster; and that the
teacher, the learner's own device and a classmate's device (through its group
link) still can, until the classmate leaves.

Signs in throwaway anonymous users (as the app does) and sets each up the way
the app would; every document is written with its owner's own token.
Everything it writes is deleted on the way out, and so are the throwaway
accounts. Standard library only.
"""
import json
import sys
import urllib.error
import urllib.request

API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"  # the app's public client key
PROJECT = "pwd-flashcard"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
FS = f"https://firestore.googleapis.com/v1/{ROOT}"
sys.stdout.reconfigure(encoding="utf-8")

results = []
created = []  # (path, token), deleted newest first
_accounts = []


def call(method, url, token, payload=None):
    req = urllib.request.Request(url, data=None if payload is None else json.dumps(payload).encode(),
                                 method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def val(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: val(x) for k, x in v.items()}}}
    if isinstance(v, list):
        return {"arrayValue": {"values": [val(x) for x in v]}}
    return {"stringValue": v}


def write(path, data, token, exists=None):
    url = f"{FS}/{path}" + ("" if exists is None else f"?currentDocument.exists={'true' if exists else 'false'}")
    st = call("PATCH", url, token, {"fields": {k: val(v) for k, v in data.items()}})
    if st == 200 and all(p != path for p, _ in created):
        created.append((path, token))
    return st


def read(path, token):
    return call("GET", f"{FS}/{path}", token)


def delete(path, token):
    return call("DELETE", f"{FS}/{path}", token)


def query(token, coll, field, op, value, limit=None):
    v = ({"arrayValue": {"values": [{"referenceValue": f"{ROOT}/{coll}/{x}"} for x in value]}}
         if field == "__name__" else val(value))
    q = {"from": [{"collectionId": coll}],
         "where": {"fieldFilter": {"field": {"fieldPath": field}, "op": op, "value": v}}}
    if limit:
        q["limit"] = limit
    return call("POST", f"{FS}:runQuery", token, {"structuredQuery": q})


def check(name, got, want):
    ok = got == want
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + f"{name} (got {got}, want {want})")


def setup(name, got):
    if got != 200:
        print(f"SETUP FAILED: {name} -> {got}")
        raise SystemExit(2)


def signin():
    req = urllib.request.Request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
        data=json.dumps({"returnSecureToken": True}).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as r:
        body = json.loads(r.read())
    _accounts.append(body["idToken"])
    return body["localId"], body["idToken"]


def cleanup():
    removed = sum(delete(path, token) == 200 for path, token in reversed(created))
    print(f"cleanup: {removed}/{len(created)} documents removed")
    gone = 0
    for token in _accounts:
        req = urllib.request.Request(
            f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={API_KEY}",
            data=json.dumps({"idToken": token}).encode(), method="POST")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                gone += r.status == 200
        except urllib.error.HTTPError:
            pass
    print(f"cleanup: {gone}/{len(_accounts)} throwaway accounts deleted")


def main():
    uT, tT = signin()
    uS1, tS1 = signin()
    uS2, tS2 = signin()
    uX, tX = signin()
    tag = uX[:8]
    pT, pS1, pS2, pX = (f"privacyprobe-{n}-{tag}" for n in ("teacher", "student1", "student2", "stranger"))
    c = f"privacyprobe-class-{tag}"
    code = f"Q{tag[:5]}"

    setup("teacher profile", write(f"profiles/{pT}", {"owner_uid": uT, "name": "Probe teacher", "role": 1}, tT))
    setup("class", write(f"classrooms/{c}", {"teacher_id": pT, "name": "Probe class", "code": code,
                                             "teacher_uid": uT}, tT))
    for p, u, t in ((pS1, uS1, tS1), (pS2, uS2, tS2)):
        setup("student profile", write(f"profiles/{p}", {"owner_uid": u, "name": "Probe student", "role": 0,
                                                         "classroom_id": c}, t))
        setup("student joins with the code", write(f"classroom_members/{c}_{p}", {
            "classroom_id": c, "profile_id": p, "join_code": code}, t, exists=False))
    setup("student 1's progress", write(f"progress/{pS1}", {"owner_uid": uS1, "total_stars": 3}, tS1))
    setup("stranger profile", write(f"profiles/{pX}", {"owner_uid": uX, "name": "Probe stranger", "role": 0}, tX))

    print("-- a learner's records")
    check("a stranger reads a learner's profile by id", read(f"profiles/{pS1}", tX), 403)
    check("... or their progress", read(f"progress/{pS1}", tX), 403)
    check("... or lists them by id", query(tX, "profiles", "__name__", "IN", [pS1]), 403)
    check("the learner's own device reads them", read(f"profiles/{pS1}", tS1), 200)
    check("their teacher reads them", read(f"profiles/{pS1}", tT), 200)
    check("... and their progress", read(f"progress/{pS1}", tT), 200)
    check("... and lists them by id with a deleted one (the deleted-learner check)",
          query(tT, "profiles", "__name__", "IN", [pS1, pS2, f"privacyprobe-gone-{tag}"]), 200)
    check("a missing profile reads as missing", read(f"profiles/privacyprobe-gone-{tag}", tX), 404)
    check("a classmate's device with no group link yet", read(f"profiles/{pS1}", tS2), 403)

    print("-- the class: its document holds the join code")
    check("a stranger reads the class by id", read(f"classrooms/{c}", tX), 403)
    check("... or lists who is in it", query(tX, "classroom_members", "classroom_id", "EQUAL", c), 403)
    check("... or reads one membership", read(f"classroom_members/{c}_{pS1}", tX), 403)
    check("anyone with the code finds the class (how a learner joins)",
          query(tX, "classrooms", "code", "EQUAL", code, limit=1), 200)
    check("a stranger joins with the class's id alone",
          write(f"classroom_members/{c}_{pX}", {"classroom_id": c, "profile_id": pX}, tX, exists=False), 403)
    check("... or a wrong code",
          write(f"classroom_members/{c}_{pX}", {"classroom_id": c, "profile_id": pX, "join_code": "WRONG1"},
                tX, exists=False), 403)
    check("the teacher reads their class", read(f"classrooms/{c}", tT), 200)

    print("-- group links")
    check("a stranger files a link into the class",
          write(f"group_readers/{c}_{uX}", {"group_id": c, "profile_id": pX, "kind": "class"}, tX), 403)
    check("a classmate's device files its link",
          write(f"group_readers/{c}_{uS2}", {"group_id": c, "profile_id": pS2, "kind": "class"}, tS2), 200)
    check("now it reads its classmate (the leaderboard)", read(f"profiles/{pS1}", tS2), 200)
    check("... and their progress", read(f"progress/{pS1}", tS2), 200)
    check("... and the class", read(f"classrooms/{c}", tS2), 200)
    check("... and who is in it", query(tS2, "classroom_members", "classroom_id", "EQUAL", c), 200)

    print("-- the teacher's roster")
    check("a learner's device puts them on their teacher's roster",
          write(f"educator_rosters/{uT}", {"learners": {pS1: uS1}, "via": {pS1: c}, "learner": pS1}, tS1), 200)
    check("a stranger puts themselves on it",
          write(f"educator_rosters/{uT}", {"learners": {pS1: uS1, pX: uX}, "via": {pS1: c, pX: c},
                                           "learner": pX}, tX), 403)
    check("a stranger reads it", read(f"educator_rosters/{uT}", tX), 403)
    check("the teacher reads their own roster", read(f"educator_rosters/{uT}", tT), 200)
    setup("a result of student 1's", write(f"assessment_results/privacyprobe-r-{tag}", {
        "profileId": pS1, "assessmentId": "probe", "owner_uid": uS1, "score": 1}, tS1))
    check("the teacher lists their students' results",
          query(tT, "assessment_results", "profileId", "IN", [pS1]), 200)
    check("a stranger lists them", query(tX, "assessment_results", "profileId", "IN", [pS1]), 403)

    print("-- a learner who leaves takes the access with them")
    check("(the classmate leaves the class)", delete(f"classroom_members/{c}_{pS2}", tS2), 200)
    created[:] = [x for x in created if x[0] != f"classroom_members/{c}_{pS2}"]
    check("the former classmate no longer reads them", read(f"profiles/{pS1}", tS2), 403)
    check("... nor the class", read(f"classrooms/{c}", tS2), 403)

    cleanup()
    print(f"{sum(results)}/{len(results)} checks passed")
    return 0 if all(results) else 1


if __name__ == "__main__":
    code = 2
    try:
        code = main()
    finally:
        if code == 2 and (created or _accounts):
            cleanup()
    sys.exit(code)
