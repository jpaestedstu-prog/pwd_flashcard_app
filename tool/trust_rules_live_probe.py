"""Probe the DEPLOYED Firestore rules for who-is-whose (2026-10-13).

    python tool/trust_rules_live_probe.py

Checks, against production, that a stranger with a learner's ids cannot:
  * pose as a child's parent or a learner's teacher (file them in a group of
    their own), approve or write a friendship with a child, or rename them;
  * read a learner's achievements or the notes about them, or write a note;
  * set a child's time limit, alarms, routine or unlock, or overwrite what
    their parent set;
and that the real teacher, parent and learner still can (the teacher of a
student who joined without a link too, through the class on the student's
profile).

Signs in throwaway anonymous users (as the app does) and gives each its own
profiles, class or family group, exactly the way the app would; every
document is written with its owner's own token. Everything it writes is
deleted on the way out, and so are the throwaway accounts. Standard library
only.
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


def s(v):
    return {"stringValue": v}


def i(v):
    return {"integerValue": str(v)}


def b(v):
    return {"booleanValue": v}


def fields(d):
    out = {}
    for k, v in d.items():
        out[k] = b(v) if isinstance(v, bool) else i(v) if isinstance(v, int) else s(v)
    return out


def write(path, data, token, exists=None, mask=None):
    url = f"{FS}/{path}"
    q = []
    if exists is not None:
        q.append(f"currentDocument.exists={'true' if exists else 'false'}")
    for m in mask or []:
        q.append(f"updateMask.fieldPaths={m}")
    if q:
        url += "?" + "&".join(q)
    st = call("PATCH", url, token, {"fields": fields(data)})
    if st == 200 and all(p != path for p, _ in created):
        created.append((path, token))
    return st


def read(path, token):
    return call("GET", f"{FS}/{path}", token)


def delete(path, token):
    return call("DELETE", f"{FS}/{path}", token)


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
    removed = 0
    for path, token in reversed(created):
        if delete(path, token) == 200:
            removed += 1
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
    uP, tP = signin()
    uS, tS = signin()
    uS2, tS2 = signin()
    uC, tC = signin()
    uX, tX = signin()
    tag = uX[:8]
    pT, pP, pS, pS2, pC = (f"trustprobe-{n}-{tag}" for n in ("teacher", "parent", "student", "student2", "child"))
    pX, pXP, pXT = (f"trustprobe-{n}-{tag}" for n in ("stranger", "strangerparent", "strangerteacher"))
    cT, gP, cX, gX = (f"trustprobe-{n}-{tag}" for n in ("class", "family", "fakeclass", "fakefamily"))

    # The real people, set up as the app does.
    setup("teacher profile", write(f"profiles/{pT}", {"owner_uid": uT, "name": "Probe teacher", "role": 1}, tT))
    setup("parent profile", write(f"profiles/{pP}", {"owner_uid": uP, "name": "Probe parent", "role": 2}, tP))
    setup("class", write(f"classrooms/{cT}", {"teacher_id": pT, "name": "Probe class", "code": f"T{tag[:5]}"}, tT))
    setup("family group", write(f"home_groups/{gP}", {"owner_profile_id": pP, "name": "Probe family",
                                                      "code": f"F{tag[:5]}"}, tP))
    setup("student profile", write(f"profiles/{pS}", {"owner_uid": uS, "name": "Probe student", "role": 0,
                                                      "classroom_id": cT}, tS))
    setup("student joins the class", write(f"classroom_members/{cT}_{pS}", {"classroom_id": cT, "profile_id": pS},
                                           tS, exists=False))
    setup("second student", write(f"profiles/{pS2}", {"owner_uid": uS2, "name": "Probe student 2", "role": 0,
                                                       "classroom_id": cT}, tS2))
    setup("second student joins", write(f"classroom_members/{cT}_{pS2}", {"classroom_id": cT, "profile_id": pS2},
                                        tS2, exists=False))
    setup("child profile", write(f"profiles/{pC}", {"owner_uid": uC, "name": "Probe child", "role": 3}, tC))
    setup("child joins the family", write(f"home_group_members/{gP}_{pC}", {"home_group_id": gP, "profile_id": pC},
                                          tC, exists=False))
    setup("teacher's link", write(f"note_readers/{uT}_{pS}", {"profile_id": pS, "classroom_id": cT}, tT, exists=False))
    setup("parent's link", write(f"note_readers/{uP}_{pC}", {"profile_id": pC, "home_group_id": gP}, tP, exists=False))
    setup("student's achievement", write(f"achievements/{pS}/items/first", {"owner_uid": uS, "profile_id": pS,
                                                                          "achievement_id": "first"}, tS))
    setup("teacher's note", write(f"parent_teacher_notes/{pS}/notes/n1", {"author_uid": uT, "content": "probe"}, tT))
    setup("parent's time limit", write(f"child_time_limits/{pC}", {"child_profile_id": pC, "setter_profile_id": pP,
                                                                  "owner_uid": uP, "daily_minutes": 60}, tP))
    # The stranger's own device: a learner, a "parent" and a "teacher".
    setup("stranger", write(f"profiles/{pX}", {"owner_uid": uX, "name": "Probe stranger", "role": 0}, tX))
    setup("stranger parent", write(f"profiles/{pXP}", {"owner_uid": uX, "name": "Probe stranger", "role": 2}, tX))
    setup("stranger teacher", write(f"profiles/{pXT}", {"owner_uid": uX, "name": "Probe stranger", "role": 1}, tX))
    setup("stranger's family group", write(f"home_groups/{gX}", {"owner_profile_id": pXP, "name": "x",
                                                                 "code": f"X{tag[:5]}"}, tX))
    setup("stranger's class", write(f"classrooms/{cX}", {"teacher_id": pXT, "name": "x", "code": f"Y{tag[:5]}"}, tX))

    print("-- posing as a parent or teacher")
    check("stranger files someone else's child in their family group",
          write(f"home_group_members/{gX}_{pC}", {"home_group_id": gX, "profile_id": pC}, tX, exists=False), 403)
    check("stranger files someone else's student in their class",
          write(f"classroom_members/{cX}_{pS}", {"classroom_id": cX, "profile_id": pS}, tX, exists=False), 403)
    check("stranger links themselves to a student through someone else's class",
          write(f"note_readers/{uX}_{pS}", {"profile_id": pS, "classroom_id": cT}, tX, exists=False), 403)

    print("-- friendships")
    pair = "_".join(sorted([pC, pX]))
    check("stranger's request arriving already approved for the child",
          write(f"friend_requests/{pX}_{pC}", {"id": f"{pX}_{pC}", "from_profile_id": pX, "to_profile_id": pC,
                                              "from_owner_uid": uX, "from_display_name": "x", "status": "pending",
                                              "to_approved": True, "to_home_group_id": gP}, tX, exists=False), 403)
    check("stranger sends a plain request (allowed: children may get requests)",
          write(f"friend_requests/{pX}_{pC}", {"id": f"{pX}_{pC}", "from_profile_id": pX, "to_profile_id": pC,
                                              "from_owner_uid": uX, "from_display_name": "x", "status": "pending"},
                tX, exists=False), 200)
    check("stranger approves the child's side",
          write(f"friend_requests/{pX}_{pC}", {"to_approved": True}, tX, mask=["to_approved"]), 403)
    check("stranger writes the friendship with the child",
          write(f"friendships/{pair}", {"profile_a": sorted([pC, pX])[0], "profile_b": sorted([pC, pX])[1],
                                        "request_id": f"{pX}_{pC}"}, tX, exists=False), 403)

    print("-- other learners' information")
    check("stranger renames a student through a class of their own",
          write(f"profiles/{pS}", {"name": "Rude name", "_rename_actor_classroom_id": cX}, tX,
                mask=["name", "_rename_actor_classroom_id"]), 403)
    check("stranger edits a student's profile outright",
          write(f"profiles/{pS}", {"name": "Rude name"}, tX, mask=["name"]), 403)

    print("-- private data")
    check("stranger lists a student's achievements", read(f"achievements/{pS}/items", tX), 403)
    check("stranger lists the notes about a student", read(f"parent_teacher_notes/{pS}/notes", tX), 403)
    check("stranger reads one note by id", read(f"parent_teacher_notes/{pS}/notes/n1", tX), 403)
    check("stranger writes a note about a student",
          write(f"parent_teacher_notes/{pS}/notes/spam", {"author_uid": uX, "content": "x"}, tX), 403)

    print("-- what an adult sets for a child")
    check("stranger overwrites the parent's time limit",
          write(f"child_time_limits/{pC}", {"child_profile_id": pC, "setter_profile_id": pXP, "owner_uid": uX,
                                           "daily_minutes": 1}, tX), 403)
    check("stranger sends the child an alarm",
          write(f"child_alarms/trustprobe-x-{tag}", {"child_profile_id": pC, "setter_profile_id": pXP,
                                                     "owner_uid": uX, "label": "come outside"}, tX), 403)
    check("stranger sends the child a routine",
          write(f"routines/trustprobe-x-{tag}", {"child_profile_id": pC, "setter_profile_id": pXP,
                                                 "owner_uid": uX}, tX), 403)
    check("stranger unlocks the child",
          write(f"child_unlock_overrides/{pC}", {"child_profile_id": pC, "setter_profile_id": pXP,
                                                "owner_uid": uX}, tX), 403)
    check("stranger acts on the student's routine day",
          write(f"routine_actions/{pS}_2026-10-13", {"child_profile_id": pS, "setter_profile_id": pXT,
                                                    "owner_uid": uX}, tX), 403)

    print("-- the real educators and learners")
    check("the teacher reads the notes about their student", read(f"parent_teacher_notes/{pS}/notes", tT), 200)
    check("the student's own device reads them", read(f"parent_teacher_notes/{pS}/notes", tS), 200)
    check("the parent writes a note about their child",
          write(f"parent_teacher_notes/{pC}/notes/n2", {"author_uid": uP, "content": "probe"}, tP), 200)
    check("the parent reads the notes about their child", read(f"parent_teacher_notes/{pC}/notes", tP), 200)
    check("the parent changes their child's time limit",
          write(f"child_time_limits/{pC}", {"child_profile_id": pC, "setter_profile_id": pP, "owner_uid": uP,
                                           "daily_minutes": 45}, tP), 200)
    check("the parent sets an alarm for their child",
          write(f"child_alarms/trustprobe-p-{tag}", {"child_profile_id": pC, "setter_profile_id": pP,
                                                     "owner_uid": uP, "label": "Bath time"}, tP), 200)
    check("the teacher sets a routine for their student",
          write(f"routines/trustprobe-t-{tag}", {"child_profile_id": pS, "setter_profile_id": pT,
                                                 "owner_uid": uT}, tT), 200)
    check("the teacher guides a student who joined without a link (class on their profile)",
          write(f"child_time_limits/{pS2}", {"child_profile_id": pS2, "setter_profile_id": pT, "owner_uid": uT,
                                            "daily_minutes": 30}, tT), 200)
    check("the student reads their own achievements", read(f"achievements/{pS}/items", tS), 200)

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
