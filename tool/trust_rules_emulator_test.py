"""Who-is-whose test for firestore.rules, run against the LOCAL Firestore emulator.

    firebase emulators:exec --only firestore --project demo-flashlearn \
        "python tool/trust_rules_emulator_test.py"

Never touches the real project (a `demo-` project on 127.0.0.1:8080, seeded
with the emulator's admin token; each user is an unsigned emulator token,
like an anonymous sign-in).

What it pins (2026-10-12/13). The rules take a class or home-group
membership as proof that someone is a learner's teacher or parent: to rename
the learner, to approve a child's friend request, and (through an educator
link, `note_readers`) to read the notes about them and to set their time
limits, alarms, routines and unlocks. Before, a group's owner could file ANY
learner in their own group, and anyone who owned some profile could set any
child's limits, so a stranger could:
  * make themselves "the parent" of someone else's child and approve a
    friend request with that child, or simply send one already approved;
  * rename someone else's learner through a class of their own;
  * overwrite a child's time limit and lock them out, or send them alarms
    and routines with words of their own;
  * read, and write, the notes about any learner.
Also: a learner's achievements and shop purchases were readable by anyone
who knew the learner's id.

Teachers and parents on apps from before 1.4.0 file no links: the class or
family group on the learner's own profile proves the same (2026-10-13).

Every check is something a released app does (must stay allowed) or an
attack (must be refused).
"""
import base64, json, os, sys, time, urllib.error, urllib.request
from pathlib import Path

PROJECT = "demo-flashlearn"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
BASE = f"http://127.0.0.1:8080/v1/{ROOT}"
TOOL = Path(__file__).resolve().parent
RULES = Path(os.environ.get("FLASHLEARN_RULES_FILE") or TOOL.parent / "firestore.rules")
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


def rules_text():
    return RULES.read_text(encoding="utf-8").replace("\r\n", "\n")


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
    # Educator links, as the app (or the one-off backfill) files them.
    put("note_readers/uT_pS", {"profile_id": "pS", "classroom_id": "c1", "updated_at": "x"})
    put("note_readers/uP_pC", {"profile_id": "pC", "home_group_id": "g1", "updated_at": "x"})
    # What the educators have already set.
    put("child_time_limits/pC", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP",
                                 "daily_minutes": 60})
    put("child_alarms/a1", {"child_profile_id": "pS", "setter_profile_id": "pT", "owner_uid": "uT",
                            "label": "Reading"})
    # A shared classroom tablet: the teacher and a student on one device,
    # with no link filed. And a Player who builds their own routine.
    put("profiles/pT2", {"owner_uid": "uT2", "name": "Tablet teacher", "role": 1})
    put("profiles/pS3", {"owner_uid": "uT2", "name": "Tablet student", "role": 0})
    put("profiles/pPl", {"owner_uid": "uPl", "name": "Player", "role": 4})
    # Joined the teacher's class after the backfill: no link, but their own
    # profile names the class and the membership is real. pS5's profile still
    # names the class after they left it; pS6's names the stranger's class,
    # which they never joined.
    put("profiles/pS4", {"owner_uid": "uS4", "name": "New student", "role": 0, "classroom_id": "c1"})
    put("classroom_members/c1_pS4", {"classroom_id": "c1", "profile_id": "pS4"})
    put("profiles/pS5", {"owner_uid": "uS5", "name": "Left student", "role": 0, "classroom_id": "c1"})
    put("profiles/pS6", {"owner_uid": "uS6", "name": "Other student", "role": 0, "classroom_id": "cX"})
    # The same for the parent: pC3 joined the family group after the
    # backfill on a device of their own (no link); pC4's profile still names
    # the group after they left it; pC5's names the stranger's group, which
    # they never joined.
    put("profiles/pC3", {"owner_uid": "uC3", "name": "New child", "role": 3, "home_group_id": "g1"})
    put("home_group_members/g1_pC3", {"home_group_id": "g1", "profile_id": "pC3"})
    put("profiles/pC4", {"owner_uid": "uC4", "name": "Left child", "role": 3, "home_group_id": "g1"})
    put("profiles/pC5", {"owner_uid": "uC5", "name": "Other child", "role": 3, "home_group_id": "gX"})


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
    allowed("the teacher files a link to their student (the app does it for every roster learner)",
            update("uT", "note_readers/uT_pS", {"profile_id": "pS", "classroom_id": "c1", "updated_at": "y"}))
    allowed("the parent files one to their child",
            update("uP", "note_readers/uP_pC", {"profile_id": "pC", "home_group_id": "g1", "updated_at": "y"}))
    allowed("the teacher checks their own link", get("uT", "note_readers/uT_pS"))
    allowed("... even before it exists", get("uP", "note_readers/uP_pS"))
    denied("a stranger reads someone else's link", get("uX", "note_readers/uT_pS"))
    denied("a stranger links themselves through a class they own but the learner never joined",
           create("uX", "note_readers/uX_pS", {"profile_id": "pS", "classroom_id": "cX"}))
    denied("... through someone else's class",
           create("uX", "note_readers/uX_pS", {"profile_id": "pS", "classroom_id": "c1"}))
    denied("... through someone else's family group",
           create("uX", "note_readers/uX_pC", {"profile_id": "pC", "home_group_id": "g1"}))
    denied("nobody files a link for another device",
           create("uT", "note_readers/uP_pS", {"profile_id": "pS", "classroom_id": "c1"}))
    denied("the link carries nothing else",
           create("uT", "note_readers/uT_pS2", {"profile_id": "pS2", "classroom_id": "c1", "admin": True}))


def notes():
    allowed("the teacher reads their student's notes",
            subquery("uT", "parent_teacher_notes/pS", "notes"))
    allowed("the parent reads their child's notes",
            subquery("uP", "parent_teacher_notes/pC", "notes"))
    allowed("the learner's own device reads its notes",
            subquery("uS", "parent_teacher_notes/pS", "notes"))
    allowed("the teacher writes a note",
            create("uT", "parent_teacher_notes/pS/notes/n4", {"author_uid": "uT", "content": "x"}))
    allowed("the parent writes a note",
            create("uP", "parent_teacher_notes/pC/notes/n5", {"author_uid": "uP", "content": "x"}))
    allowed("the deleted-learner cleanup lists its own notes (author filter)",
            subquery("uT", "parent_teacher_notes/pS", "notes", author="uT"))
    denied("a stranger lists a learner's notes",
           subquery("uX", "parent_teacher_notes/pS", "notes"))
    denied("... or reads one by id", get("uX", "parent_teacher_notes/pS/notes/n1"))
    denied("a stranger writes a note about a learner",
           create("uX", "parent_teacher_notes/pS/notes/spam", {"author_uid": "uX", "content": "x"}))
    denied("an educator with no link to that learner is refused",
           subquery("uP", "parent_teacher_notes/pS", "notes"))
    denied("a stranger edits someone's note",
           update("uX", "parent_teacher_notes/pS/notes/n1", {"author_uid": "uX", "content": "changed"}))


def child_controls():
    allowed("the teacher sets a time limit for their student",
            create("uT", "child_time_limits/pS", {"child_profile_id": "pS", "setter_profile_id": "pT",
                                                  "owner_uid": "uT", "daily_minutes": 30}))
    allowed("the parent changes their child's time limit",
            update("uP", "child_time_limits/pC", {"child_profile_id": "pC", "setter_profile_id": "pP",
                                                  "owner_uid": "uP", "daily_minutes": 45}))
    denied("a stranger overwrites a child's time limit (to lock them out)",
           update("uX", "child_time_limits/pC", {"child_profile_id": "pC", "setter_profile_id": "pXP",
                                                 "owner_uid": "uX", "daily_minutes": 1}))
    denied("a stranger sets a limit for a child who has none",
           create("uX", "child_time_limits/pS2", {"child_profile_id": "pS2", "setter_profile_id": "pXT",
                                                  "owner_uid": "uX", "daily_minutes": 1}))
    denied("an educator sets a limit for a learner who is not theirs",
           create("uT", "child_time_limits/pC2", {"child_profile_id": "pC2", "setter_profile_id": "pT",
                                                  "owner_uid": "uT", "daily_minutes": 10}))
    allowed("a shared tablet: the teacher sets a limit for a student on the same device, no link",
            create("uT2", "child_time_limits/pS3", {"child_profile_id": "pS3", "setter_profile_id": "pT2",
                                                    "owner_uid": "uT2", "daily_minutes": 20}))
    allowed("the parent sets an alarm for their child",
            create("uP", "child_alarms/p1", {"child_profile_id": "pC", "setter_profile_id": "pP",
                                             "owner_uid": "uP", "label": "Bath time"}))
    denied("a stranger sends a child an alarm with words of their own",
           create("uX", "child_alarms/x1", {"child_profile_id": "pC", "setter_profile_id": "pXP",
                                            "owner_uid": "uX", "label": "come outside"}))
    allowed("the teacher edits their alarm",
            update("uT", "child_alarms/a1", {"child_profile_id": "pS", "setter_profile_id": "pT",
                                             "owner_uid": "uT", "label": "Reading time"}))
    denied("... but cannot move it onto another child",
           update("uT", "child_alarms/a1", {"child_profile_id": "pC", "setter_profile_id": "pT",
                                            "owner_uid": "uT", "label": "Reading time"}))
    denied("a stranger takes over the teacher's alarm",
           update("uX", "child_alarms/a1", {"child_profile_id": "pS", "setter_profile_id": "pXT",
                                            "owner_uid": "uX", "label": "x"}))
    denied("a stranger deletes the teacher's alarm", req("DELETE", f"{BASE}/child_alarms/a1", None, "uX")[0])
    denied("a stranger sends a child a routine",
           create("uX", "routines/r1", {"child_profile_id": "pC", "setter_profile_id": "pXP", "owner_uid": "uX"}))
    allowed("the parent sets their child's routine",
            create("uP", "routines/r3", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"}))
    allowed("a Player builds their own routine",
            create("uPl", "routines/r2", {"child_profile_id": "pPl", "setter_profile_id": "pPl",
                                          "owner_uid": "uPl"}))
    allowed("the teacher marks a step done on their student's day",
            create("uT", "routine_actions/pS_2026-10-13", {"child_profile_id": "pS", "setter_profile_id": "pT",
                                                           "owner_uid": "uT"}))
    denied("a stranger acts on a child's routine day",
           create("uX", "routine_actions/pS_2026-10-14", {"child_profile_id": "pS", "setter_profile_id": "pXT",
                                                          "owner_uid": "uX"}))
    allowed("the parent unlocks their child for a while",
            create("uP", "child_unlock_overrides/pC", {"child_profile_id": "pC", "setter_profile_id": "pP",
                                                       "owner_uid": "uP"}))
    denied("a stranger unlocks (or re-locks) someone else's child",
           update("uX", "child_unlock_overrides/pC", {"child_profile_id": "pC", "setter_profile_id": "pXP",
                                                      "owner_uid": "uX"}))
    allowed("the setter still deletes their own alarm", req("DELETE", f"{BASE}/child_alarms/p1", None, "uP")[0])
    allowed("a teacher on an older app guides a student who joined later (their profile names the class)",
            create("uT", "child_time_limits/pS4", {"child_profile_id": "pS4", "setter_profile_id": "pT",
                                                   "owner_uid": "uT", "daily_minutes": 30}))
    allowed("... and reads the notes about them",
            subquery("uT", "parent_teacher_notes/pS4", "notes"))
    denied("... but not a student whose profile still names the class after they left it",
           create("uT", "child_time_limits/pS5", {"child_profile_id": "pS5", "setter_profile_id": "pT",
                                                  "owner_uid": "uT", "daily_minutes": 30}))
    denied("a stranger whose class a profile names, without a membership",
           create("uX", "child_time_limits/pS6", {"child_profile_id": "pS6", "setter_profile_id": "pXT",
                                                  "owner_uid": "uX", "daily_minutes": 1}))
    denied("... nor the notes", subquery("uX", "parent_teacher_notes/pS6", "notes"))


def parents_on_older_apps():
    # A parent's app from before 1.4.0 files no links. The child's own
    # profile names the family group (every release's join writes it).
    allowed("a parent on an older app sets a time limit for a child who joined later",
            create("uP", "child_time_limits/pC3", {"child_profile_id": "pC3", "setter_profile_id": "pP",
                                                   "owner_uid": "uP", "daily_minutes": 30}))
    allowed("... reads the notes about them", subquery("uP", "parent_teacher_notes/pC3", "notes"))
    allowed("... writes a note", create("uP", "parent_teacher_notes/pC3/notes/n6",
                                        {"author_uid": "uP", "content": "x"}))
    allowed("... sets an alarm", create("uP", "child_alarms/p3", {"child_profile_id": "pC3", "setter_profile_id": "pP",
                                                                  "owner_uid": "uP", "label": "Bath time"}))
    allowed("... sets a routine", create("uP", "routines/r4", {"child_profile_id": "pC3", "setter_profile_id": "pP",
                                                               "owner_uid": "uP"}))
    allowed("... and unlocks them for a while",
            create("uP", "child_unlock_overrides/pC3", {"child_profile_id": "pC3", "setter_profile_id": "pP",
                                                        "owner_uid": "uP"}))
    denied("but not a child whose profile still names the group after they left it",
           create("uP", "child_time_limits/pC4", {"child_profile_id": "pC4", "setter_profile_id": "pP",
                                                  "owner_uid": "uP", "daily_minutes": 30}))
    denied("... nor their notes", subquery("uP", "parent_teacher_notes/pC4", "notes"))
    denied("a stranger whose family group a profile names, without a membership",
           create("uX", "child_time_limits/pC5", {"child_profile_id": "pC5", "setter_profile_id": "pXP",
                                                  "owner_uid": "uX", "daily_minutes": 1}))
    denied("... nor the notes", subquery("uX", "parent_teacher_notes/pC5", "notes"))
    denied("a stranger cannot use the real parent's path to the child",
           create("uX", "child_alarms/x3", {"child_profile_id": "pC3", "setter_profile_id": "pXP",
                                            "owner_uid": "uX", "label": "come outside"}))
    denied("... nor read the child's notes", subquery("uX", "parent_teacher_notes/pC3", "notes"))
    denied("a teacher is not the child's parent",
           create("uT", "child_time_limits/pC3", {"child_profile_id": "pC3", "setter_profile_id": "pT",
                                                  "owner_uid": "uT", "daily_minutes": 30}))
    # The child leaves: the access goes with the membership.
    allowed("(the child leaves the family group)",
            req("DELETE", f"{BASE}/home_group_members/g1_pC3", None, "uC3")[0])
    denied("the parent no longer changes the time limit",
           update("uP", "child_time_limits/pC3", {"child_profile_id": "pC3", "setter_profile_id": "pP",
                                                  "owner_uid": "uP", "daily_minutes": 5}))
    denied("... nor reads the notes", subquery("uP", "parent_teacher_notes/pC3", "notes"))


def after_leaving():
    # The student leaves the class: the teacher's link stays, but the
    # membership under it is gone, so the access goes with it.
    allowed("(the student leaves the class)",
            req("DELETE", f"{BASE}/classroom_members/c1_pS", None, "uS")[0])
    denied("the former teacher no longer reads the notes",
           subquery("uT", "parent_teacher_notes/pS", "notes"))
    allowed("... but still lists the notes they wrote (author filter)",
            subquery("uT", "parent_teacher_notes/pS", "notes", author="uT"))
    denied("... and no longer sets the student's time limit",
           update("uT", "child_time_limits/pS", {"child_profile_id": "pS", "setter_profile_id": "pT",
                                                 "owner_uid": "uT", "daily_minutes": 5}))
    allowed("... and can still remove what they set", req("DELETE", f"{BASE}/child_alarms/a1", None, "uT")[0])


def main():
    load_rules(rules_text())
    wipe()
    seed()
    memberships()
    friend_requests()
    renames()
    own_records()
    note_readers()
    notes()
    child_controls()
    parents_on_older_apps()
    after_leaving()
    print(f"{passed} passed, {len(failed)} failed")
    for f in failed:
        print("  FAIL", f)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
