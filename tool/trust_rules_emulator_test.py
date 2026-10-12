"""Who-is-whose test for firestore.rules, run against the LOCAL Firestore emulator.

    firebase emulators:exec --only firestore --project demo-flashlearn \
        "python tool/trust_rules_emulator_test.py"

Never touches the real project (a `demo-` project on 127.0.0.1:8080, seeded
with the emulator's admin token; each user is an unsigned emulator token,
like an anonymous sign-in).

What it pins (2026-10-12). The rules take a class or home-group membership
as proof that someone is a learner's teacher or parent: to rename the
learner, to approve a child's friend request, and (phase 2) to read the
notes about them. Before, a group's owner could file ANY learner in their
own group, so a stranger could:
  * make themselves "the parent" of someone else's child and approve a
    friend request with that child, or simply send one already approved;
  * rename someone else's learner through a class of their own.
Also: a learner's achievements and shop purchases were readable by anyone
who knew the learner's id. And the notes about a learner are prepared for
phase 2 (tool/notes_rules_phase2.rules), tested here before anyone deploys it.

Every check is something a released app does (must stay allowed) or an
attack (must be refused).
"""
import base64, json, os, re, sys, time, urllib.error, urllib.request
from pathlib import Path

PROJECT = "demo-flashlearn"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
BASE = f"http://127.0.0.1:8080/v1/{ROOT}"
TOOL = Path(__file__).resolve().parent
RULES = Path(os.environ.get("FLASHLEARN_RULES_FILE") or TOOL.parent / "firestore.rules")
PHASE2 = TOOL / "notes_rules_phase2.rules"
sys.stdout.reconfigure(encoding="utf-8")


def token(uid):
    enc = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
    now = int(time.time())
    return enc({"alg": "none", "typ": "JWT"}) + "." + enc({
        "sub": uid, "user_id": uid, "iat": now, "exp": now + 3600, "auth_time": now,
        "iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT,
        "firebase": {"sign_in_provider": "anonymous", "identities": {}}}) + "."


def req(method, url, body=None, uid=None):
    headers = {"Content-Type": "application/json",
               "Authorization": "Bearer " + ("owner" if uid is None else token(uid))}
    r = urllib.request.Request(url, method=method, headers=headers,
                               data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def val(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    return {"stringValue": v}


def fields(d):
    return {"fields": {k: val(v) for k, v in d.items()}}


def put(path, data):
    st, body = req("PATCH", f"{BASE}/{path}", fields(data))
    assert st == 200, (path, st, body)


def create(uid, path, data):
    """A create: refused by Firestore itself if the document exists."""
    st, _ = req("PATCH", f"{BASE}/{path}?currentDocument.exists=false", fields(data), uid)
    return st


def update(uid, path, data):
    """Replaces an existing document with [data] (what a set() over it does)."""
    st, _ = req("PATCH", f"{BASE}/{path}?currentDocument.exists=true", fields(data), uid)
    return st


def get(uid, path):
    """200 when read; a missing doc the rules let you look for counts as 200."""
    st, _ = req("GET", f"{BASE}/{path}", None, uid)
    return 200 if st == 404 else st


def subquery(uid, parent, coll, author=None):
    """Every doc of a subcollection under [parent], optionally author_uid == [author]."""
    sq = {"from": [{"collectionId": coll}]}
    if author:
        sq["where"] = {"fieldFilter": {"field": {"fieldPath": "author_uid"}, "op": "EQUAL",
                                       "value": val(author)}}
    st, _ = req("POST", f"{BASE}/{parent}:runQuery", {"structuredQuery": sq}, uid)
    return st


def wipe():
    st, _ = req("DELETE", f"http://127.0.0.1:8080/emulator/v1/{ROOT}")
    assert st == 200, st


def rules_text(phase2=False):
    text = RULES.read_text(encoding="utf-8").replace("\r\n", "\n")
    if not phase2:
        return text
    block = re.compile(r"    match /parent_teacher_notes/\{studentId\}/notes/\{noteId\} \{\n.*?\n    \}\n",
                       re.S)
    assert len(block.findall(text)) == 1, "notes block not found exactly once"
    snippet = PHASE2.read_text(encoding="utf-8").replace("\r\n", "\n")
    snippet = "\n".join(l for l in snippet.split("\n") if not l.lstrip().startswith("//")).strip("\n") + "\n"
    return block.sub(lambda _: snippet, text)


def load_rules(text):
    r = urllib.request.Request(
        f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}:securityRules", method="PUT",
        data=json.dumps({"rules": {"files": [{"name": "firestore.rules", "content": text}]}}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=20) as resp:
        assert resp.status == 200


passed, failed = 0, []


def allowed(label, status):
    global passed
    if status == 200:
        passed += 1
    else:
        failed.append(f"should be ALLOWED: {label} -> {status}")


def denied(label, status):
    global passed
    if status == 403:
        passed += 1
    else:
        failed.append(f"should be DENIED: {label} -> {status}")


def seed():
    # The real people: a teacher (uT), a parent (uP), a student in the
    # teacher's class (uS), a child in the parent's family group (uC), and
    # two more learners who have joined nothing yet (uS2, uC2).
    put("profiles/pT", {"owner_uid": "uT", "name": "Teacher", "role": 1})
    put("profiles/pP", {"owner_uid": "uP", "name": "Parent", "role": 2})
    put("profiles/pS", {"owner_uid": "uS", "name": "Student", "role": 0})
    put("profiles/pC", {"owner_uid": "uC", "name": "Child", "role": 3})
    put("profiles/pS2", {"owner_uid": "uS2", "name": "Student Two", "role": 0})
    put("profiles/pC2", {"owner_uid": "uC2", "name": "Child Two", "role": 3})
    put("classrooms/c1", {"teacher_id": "pT", "name": "Class", "code": "ABC123"})
    put("home_groups/g1", {"owner_profile_id": "pP", "name": "Family", "code": "FAM123"})
    put("classroom_members/c1_pS", {"classroom_id": "c1", "profile_id": "pS", "display_name": "Student"})
    put("home_group_members/g1_pC", {"home_group_id": "g1", "profile_id": "pC", "display_name": "Child"})
    # A stranger with a device of their own: a learner, a "parent" and a
    # "teacher" profile, a home group and a class.
    put("profiles/pX", {"owner_uid": "uX", "name": "Stranger", "role": 0})
    put("profiles/pXP", {"owner_uid": "uX", "name": "Stranger parent", "role": 2})
    put("profiles/pXT", {"owner_uid": "uX", "name": "Stranger teacher", "role": 1})
    put("home_groups/gX", {"owner_profile_id": "pXP", "name": "Fake family", "code": "XXX111"})
    put("classrooms/cX", {"teacher_id": "pXT", "name": "Fake class", "code": "XXX222"})
    # The learner's own records.
    put("achievements/pS/items/first_game", {"owner_uid": "uS", "profile_id": "pS", "achievement_id": "first_game"})
    put("shop_purchases/pS/items/hat", {"owner_uid": "uS", "profile_id": "pS", "item_id": "hat"})
    put("parent_teacher_notes/pS/notes/n1", {"author_uid": "uT", "content": "Doing well", "student_profile_id": "pS"})
    put("parent_teacher_notes/pC/notes/n2", {"author_uid": "uP", "content": "Tired today", "student_profile_id": "pC"})


def request_doc(frm, to, owner, **extra):
    d = {"id": f"{frm}_{to}", "from_profile_id": frm, "to_profile_id": to, "from_owner_uid": owner,
         "from_display_name": "x", "status": "pending", "created_at": "2026-10-12T00:00:00"}
    d.update(extra)
    return d


def memberships():
    allowed("a student's own device joins a class (the join-code flow)",
            create("uS2", "classroom_members/c1_pS2", {"classroom_id": "c1", "profile_id": "pS2", "display_name": "S2"}))
    allowed("a child's own device joins a family group",
            create("uC2", "home_group_members/g1_pC2", {"home_group_id": "g1", "profile_id": "pC2", "display_name": "C2"}))
    allowed("a learner re-joining writes over its membership (same ids)",
            update("uS", "classroom_members/c1_pS", {"classroom_id": "c1", "profile_id": "pS", "display_name": "Student"}))
    allowed("the teacher renames a member on the roster",
            update("uT", "classroom_members/c1_pS", {"classroom_id": "c1", "profile_id": "pS", "display_name": "Sam"}))
    allowed("the parent renames a member of the family group",
            update("uP", "home_group_members/g1_pC", {"home_group_id": "g1", "profile_id": "pC", "display_name": "Kit"}))
    denied("a stranger files someone else's child in a family group of their own",
           create("uX", "home_group_members/gX_pC", {"home_group_id": "gX", "profile_id": "pC"}))
    denied("a stranger files someone else's student in a class of their own",
           create("uX", "classroom_members/cX_pS", {"classroom_id": "cX", "profile_id": "pS"}))
    denied("even the real teacher cannot enrol a learner who never joined",
           create("uT", "classroom_members/c1_pX", {"classroom_id": "c1", "profile_id": "pX"}))
    denied("a learner cannot file a membership under another learner's name",
           create("uX", "home_group_members/gX_pC2", {"home_group_id": "gX", "profile_id": "pX"}))
    denied("... nor under another group's name",
           create("uX", "classroom_members/c1_pX", {"classroom_id": "cX", "profile_id": "pX"}))
    denied("a teacher cannot turn a membership into someone else's",
           update("uT", "classroom_members/c1_pS", {"classroom_id": "c1", "profile_id": "pX"}))
    denied("a learner cannot move their membership to another class",
           update("uS", "classroom_members/c1_pS", {"classroom_id": "cX", "profile_id": "pS"}))
    allowed("the teacher still removes a student",
            req("DELETE", f"{BASE}/classroom_members/c1_pS2", None, "uT")[0])
    allowed("a child still leaves a family group",
            req("DELETE", f"{BASE}/home_group_members/g1_pC2", None, "uC2")[0])


def friend_requests():
    # What the app sends: a plain request, and a child's own one tagged with
    # their family group.
    allowed("a plain friend request (what every release sends)",
            create("uS", "friend_requests/pS_pC", request_doc("pS", "pC", "uS")))
    allowed("a child's request, tagged with their own family group",
            create("uC", "friend_requests/pC_pS2", request_doc("pC", "pS2", "uC", from_home_group_id="g1")))
    # The bypasses.
    denied("a stranger's request arriving already approved for the child",
           create("uX", "friend_requests/pX_pC", request_doc("pX", "pC", "uX", to_approved=True, to_home_group_id="gX")))
    denied("... approved, without naming a group",
           create("uX", "friend_requests/pX_pC", request_doc("pX", "pC", "uX", to_approved=True)))
    denied("... naming the child's group for them",
           create("uX", "friend_requests/pX_pC", request_doc("pX", "pC", "uX", to_home_group_id="g1")))
    denied("a child pre-approving their own side",
           create("uC", "friend_requests/pC_pX", request_doc("pC", "pX", "uC", from_home_group_id="g1", from_approved=True)))

    # The whole stranger route, step by step: a plain request, the child
    # says yes (awaiting their parent), the stranger tries to be the parent.
    allowed("the stranger sends a plain request to the child",
            create("uX", "friend_requests/pX_pC", request_doc("pX", "pC", "uX")))
    waiting = request_doc("pX", "pC", "uX", status="awaiting_parent", to_home_group_id="g1")
    allowed("the child says yes: it waits for the child's parent",
            update("uC", "friend_requests/pX_pC", waiting))
    denied("the stranger approves the child's side",
           update("uX", "friend_requests/pX_pC", dict(waiting, to_approved=True)))
    moved = dict(waiting, to_home_group_id="gX")
    allowed("(a participant may still re-stamp the group field)",
            update("uX", "friend_requests/pX_pC", moved))
    denied("... but approving through the stranger's own group fails: the child never joined it",
           update("uX", "friend_requests/pX_pC", dict(moved, to_approved=True)))
    denied("so the stranger cannot write the friendship",
           create("uX", "friendships/pC_pX", {"profile_a": "pC", "profile_b": "pX", "request_id": "pX_pC",
                                               "created_at": "2026-10-12"}))
    # The real parent still can.
    allowed("(the group field back on the child's real family)",
            update("uC", "friend_requests/pX_pC", waiting))
    allowed("the child's real parent approves",
            update("uP", "friend_requests/pX_pC", dict(waiting, to_approved=True)))
    allowed("then the friendship is written by the child's device",
            create("uC", "friendships/pC_pX", {"profile_a": "pC", "profile_b": "pX", "request_id": "pX_pC",
                                               "created_at": "2026-10-12"}))


def renames():
    allowed("the real teacher renames a learner in their class",
            update("uT", "profiles/pS", {"owner_uid": "uS", "name": "Sammy", "role": 0,
                                         "_rename_actor_classroom_id": "c1"}))
    denied("a stranger renames a learner through a class of their own",
           update("uX", "profiles/pS", {"owner_uid": "uS", "name": "Rude name", "role": 0,
                                        "_rename_actor_classroom_id": "cX"}))
    denied("... or through a family group of their own",
           update("uX", "profiles/pC", {"owner_uid": "uC", "name": "Rude name", "role": 3,
                                        "_rename_actor_home_group_id": "gX"}))


def own_records():
    allowed("a learner's restore lists its achievements",
            subquery("uS", "achievements/pS", "items"))
    allowed("... and its shop purchases",
            subquery("uS", "shop_purchases/pS", "items"))
    allowed("... and reads one by id", get("uS", "achievements/pS/items/first_game"))
    denied("a stranger lists a learner's achievements", subquery("uX", "achievements/pS", "items"))
    denied("... or their purchases", subquery("uX", "shop_purchases/pS", "items"))
    denied("... or reads one by id", get("uX", "shop_purchases/pS/items/hat"))
    allowed("the learner still saves an achievement",
            create("uS", "achievements/pS/items/streak", {"owner_uid": "uS", "profile_id": "pS",
                                                         "achievement_id": "streak"}))
    denied("a stranger cannot add one", create("uX", "achievements/pS/items/fake", {"owner_uid": "uX"}))


def note_readers():
    allowed("the teacher files themselves as a reader of their student's notes",
            create("uT", "note_readers/uT_pS", {"profile_id": "pS", "classroom_id": "c1", "updated_at": "x"}))
    allowed("... and again later (the same doc, written over)",
            update("uT", "note_readers/uT_pS", {"profile_id": "pS", "classroom_id": "c1", "updated_at": "y"}))
    allowed("the parent files themselves for their child",
            create("uP", "note_readers/uP_pC", {"profile_id": "pC", "home_group_id": "g1", "updated_at": "x"}))
    allowed("the teacher checks their own reader doc", get("uT", "note_readers/uT_pS"))
    allowed("... even before it exists", get("uP", "note_readers/uP_pS"))
    denied("a stranger reads someone else's reader doc", get("uX", "note_readers/uT_pS"))
    denied("a stranger files themselves through a class they own but the learner never joined",
           create("uX", "note_readers/uX_pS", {"profile_id": "pS", "classroom_id": "cX"}))
    denied("... through someone else's class",
           create("uX", "note_readers/uX_pS", {"profile_id": "pS", "classroom_id": "c1"}))
    denied("... through someone else's family group",
           create("uX", "note_readers/uX_pC", {"profile_id": "pC", "home_group_id": "g1"}))
    denied("nobody files a reader doc for another device",
           create("uT", "note_readers/uP_pS", {"profile_id": "pS", "classroom_id": "c1"}))
    denied("the doc carries nothing else",
           create("uT", "note_readers/uT_pS2", {"profile_id": "pS2", "classroom_id": "c1", "admin": True}))
    # Today's notes rule (phase 1) is unchanged: every released app keeps
    # reading and writing notes.
    allowed("phase 1: a teacher on an older app still reads the notes",
            subquery("uT", "parent_teacher_notes/pS", "notes"))
    allowed("phase 1: ... and writes one",
            create("uT", "parent_teacher_notes/pS/notes/n3", {"author_uid": "uT", "content": "x"}))


def notes_phase2():
    load_rules(rules_text(phase2=True))
    allowed("phase 2: the registered teacher reads their student's notes",
            subquery("uT", "parent_teacher_notes/pS", "notes"))
    allowed("phase 2: the registered parent reads their child's notes",
            subquery("uP", "parent_teacher_notes/pC", "notes"))
    allowed("phase 2: the learner's own device reads its notes",
            subquery("uS", "parent_teacher_notes/pS", "notes"))
    allowed("phase 2: the teacher writes a note",
            create("uT", "parent_teacher_notes/pS/notes/n4", {"author_uid": "uT", "content": "x"}))
    allowed("phase 2: the parent writes a note",
            create("uP", "parent_teacher_notes/pC/notes/n5", {"author_uid": "uP", "content": "x"}))
    allowed("phase 2: the deleted-learner cleanup lists its own notes (author filter)",
            subquery("uT", "parent_teacher_notes/pS", "notes", author="uT"))
    denied("phase 2: a stranger lists a learner's notes",
           subquery("uX", "parent_teacher_notes/pS", "notes"))
    denied("phase 2: ... or reads one by id", get("uX", "parent_teacher_notes/pS/notes/n1"))
    denied("phase 2: a stranger writes a note about a learner",
           create("uX", "parent_teacher_notes/pS/notes/spam", {"author_uid": "uX", "content": "x"}))
    denied("phase 2: an educator with no reader doc (an older app, or no link at all) is refused",
           subquery("uP", "parent_teacher_notes/pS", "notes"))
    # The learner leaves the class: the teacher's reader doc stays, but the
    # membership under it is gone, so the access goes with it.
    allowed("(the student leaves the class)",
            req("DELETE", f"{BASE}/classroom_members/c1_pS", None, "uS")[0])
    denied("phase 2: the former teacher no longer reads the notes",
           subquery("uT", "parent_teacher_notes/pS", "notes"))
    allowed("phase 2: the author still sees their own notes (author filter)",
            subquery("uT", "parent_teacher_notes/pS", "notes", author="uT"))


def main():
    load_rules(rules_text())
    wipe()
    seed()
    memberships()
    friend_requests()
    renames()
    own_records()
    note_readers()
    notes_phase2()
    print(f"{passed} passed, {len(failed)} failed")
    for f in failed:
        print("  FAIL", f)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
