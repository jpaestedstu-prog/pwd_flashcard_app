"""Privacy test for firestore.rules, run against the LOCAL Firestore emulator.

    firebase emulators:exec --only firestore --project demo-flashlearn \
        "python tool/privacy_rules_emulator_test.py"

Never touches the real project (a `demo-` project on 127.0.0.1:8080, seeded
with the emulator's admin token; each user is an unsigned emulator token,
like an anonymous sign-in).

What it pins (13 October 2026). Until then anyone signed in who knew a
learner's id (from a username handle, a roster or a message) could read the
learner's profile (name, disability, support options, class, device id), their
progress, test results, time limits, alarms, routines, routine days, unlocks
and study time, and could message them. Now:
  * a learner's records are read by their own device, their educators, and
    (profile and progress only, for the leaderboard) a device with a profile
    in the same class or family group, through its group link;
  * messages go only between contacts: a learner and the teacher or parent of
    the group their profile names (either way), friends, or two profiles on
    one device.
  * an educator's device keeps a roster of its learners that the rules read
    in one lookup: what lets a 30-learner query through, and the only way
    to check every learner a test names; strangers cannot add to it;
  * the class and family documents (which carry the join code) are read
    only by their teacher or parent and their members' devices.
Every check is something a released app does (must stay allowed) or an
attack (must be refused). Set FLASHLEARN_RULES_FILE to run it against
another rules file (a negative control).
"""
import base64, json, os, sys, time, urllib.error, urllib.request
from pathlib import Path

PROJECT = "demo-flashlearn"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
BASE = f"http://127.0.0.1:8080/v1/{ROOT}"
TOOL = Path(__file__).resolve().parent
RULES = Path(os.environ.get("FLASHLEARN_RULES_FILE") or TOOL.parent / "firestore.rules")
sys.stdout.reconfigure(encoding="utf-8")
DAY = "2026-10-13"


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
    if isinstance(v, list):
        return {"arrayValue": {"values": [val(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: val(x) for k, x in v.items()}}}
    return {"stringValue": v}


def fields(d):
    return {"fields": {k: val(v) for k, v in d.items()}}


def put(path, data):
    st, body = req("PATCH", f"{BASE}/{path}", fields(data))
    assert st == 200, (path, st, body)


def create(uid, path, data):
    st, _ = req("PATCH", f"{BASE}/{path}?currentDocument.exists=false", fields(data), uid)
    return st


def patch(uid, path, data, mask):
    """An update of only the [mask] fields (dotted paths): a path missing
    from [data] is deleted, as the app's FieldValue.delete() does."""
    q = "&".join(f"updateMask.fieldPaths={m}" for m in mask)
    st, _ = req("PATCH", f"{BASE}/{path}?{q}", fields(data), uid)
    return st


def get(uid, path):
    return req("GET", f"{BASE}/{path}", None, uid)[0]


def query(uid, coll, *filters):
    where = [{"fieldFilter": {"field": {"fieldPath": f}, "op": op,
                              "value": ({"arrayValue": {"values": [
                                  ({"referenceValue": f"{ROOT}/{coll}/{x}"} if f == "__name__" else val(x))
                                  for x in v]}} if op == "IN" else val(v))}}
             for f, op, v in filters]
    sq = {"from": [{"collectionId": coll}]}
    if where:
        sq["where"] = where[0] if len(where) == 1 else {"compositeFilter": {"op": "AND", "filters": where}}
    return req("POST", f"{BASE}:runQuery", {"structuredQuery": sq}, uid)[0]


def batch_create(uid, docs):
    """One batched write (a class broadcast): every document, or none."""
    writes = [{"update": {"name": f"{ROOT}/{path}", **fields(data)},
               "currentDocument": {"exists": False}} for path, data in docs]
    return req("POST", f"{BASE}:commit", {"writes": writes}, uid)[0]


def delete(uid, path):
    return req("DELETE", f"{BASE}/{path}", None, uid)[0]


def wipe():
    st, _ = req("DELETE", f"http://127.0.0.1:8080/emulator/v1/{ROOT}")
    assert st == 200, st


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


def message(frm, to, owner):
    return {"sender_profile_id": frm, "recipient_profile_id": to, "sender_uid": owner,
            "sender_name": "x", "content": "hi", "type": "text", "timestamp": DAY, "is_read": False}


def seed():
    # A teacher (uT) and class c1: students pS1, pS2 (classmates on their own
    # tablets, both with group links) and pS5 (in the class, no group link yet).
    put("profiles/pT", {"owner_uid": "uT", "name": "Teacher", "role": 1})
    put("classrooms/c1", {"teacher_id": "pT", "name": "Class", "code": "ABC123"})
    for n in ("1", "2", "5"):
        put(f"profiles/pS{n}", {"owner_uid": f"uS{n}", "name": f"Student {n}", "role": 0,
                                "classroom_id": "c1", "disability_type": 1})
        put(f"classroom_members/c1_pS{n}", {"classroom_id": "c1", "profile_id": f"pS{n}"})
        put(f"progress/pS{n}", {"owner_uid": f"uS{n}", "total_stars": 10})
    put("group_readers/c1_uS1", {"group_id": "c1", "profile_id": "pS1", "kind": "class"})
    put("group_readers/c1_uS2", {"group_id": "c1", "profile_id": "pS2", "kind": "class"})
    put("note_readers/uT_pS1", {"profile_id": "pS1", "classroom_id": "c1"})
    # A parent (uP), family g1, child pC on their own tablet.
    put("profiles/pP", {"owner_uid": "uP", "name": "Parent", "role": 2})
    put("home_groups/g1", {"owner_profile_id": "pP", "name": "Family", "code": "FAM123"})
    put("profiles/pC", {"owner_uid": "uC", "name": "Child", "role": 3, "home_group_id": "g1"})
    put("home_group_members/g1_pC", {"home_group_id": "g1", "profile_id": "pC"})
    put("progress/pC", {"owner_uid": "uC", "total_stars": 4})
    # A friend of pS1's (pF), and pF's friendship with pS1 (sorted pair id).
    put("profiles/pF", {"owner_uid": "uF", "name": "Friend", "role": 4})
    put("friendships/pF_pS1", {"profile_a": "pF", "profile_b": "pS1"})
    # A shared classroom tablet: teacher pT2 and student pS6 on one device.
    put("profiles/pT2", {"owner_uid": "uT2", "name": "Tablet teacher", "role": 1})
    put("profiles/pS6", {"owner_uid": "uT2", "name": "Tablet student", "role": 0})
    # A stranger with a device of their own: a learner in a class and family
    # of their own, with group links for them.
    put("profiles/pX", {"owner_uid": "uX", "name": "Stranger", "role": 0, "classroom_id": "cX",
                        "home_group_id": "gX"})
    put("profiles/pXT", {"owner_uid": "uX", "name": "Stranger teacher", "role": 1})
    put("profiles/pXP", {"owner_uid": "uX", "name": "Stranger parent", "role": 2})
    put("classrooms/cX", {"teacher_id": "pXT", "name": "x", "code": "XXX222"})
    put("home_groups/gX", {"owner_profile_id": "pXP", "name": "x", "code": "XXX111"})
    put("classroom_members/cX_pX", {"classroom_id": "cX", "profile_id": "pX"})
    put("home_group_members/gX_pX", {"home_group_id": "gX", "profile_id": "pX"})
    put("group_readers/cX_uX", {"group_id": "cX", "profile_id": "pX", "kind": "class"})
    put("group_readers/gX_uX", {"group_id": "gX", "profile_id": "pX", "kind": "family"})
    # The learners' records.
    put("assessment_results/r1", {"profileId": "pS1", "assessmentId": "a1", "score": 8})
    put("assessment_results/r2", {"profileId": "pS2", "assessmentId": "a1", "score": 6})
    put("child_time_limits/pC", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put("child_unlock_overrides/pC", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put("child_alarms/al1", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put("routines/rt1", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put(f"routine_actions/pC_{DAY}", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put(f"routine_logs/pC_{DAY}", {"profile_id": "pC", "owner_uid": "uC"})
    put(f"active_time_logs/pC_{DAY}", {"child_profile_id": "pC", "owner_uid": "uC"})
    # Thirty more students in c1: the teacher's class broadcast (8 to a
    # batch) and the app's 30-learner queries (results, deleted-learner check).
    for i in range(30):
        put(f"profiles/pB{i}", {"owner_uid": f"uB{i}", "name": f"B{i}", "role": 0, "classroom_id": "c1"})
        put(f"classroom_members/c1_pB{i}", {"classroom_id": "c1", "profile_id": f"pB{i}"})
        put(f"assessment_results/rb{i}", {"profileId": f"pB{i}", "assessmentId": "a1", "score": i})
        if i % 2 == 0:  # half of them with the teacher's educator link, half without (older apps)
            put(f"note_readers/uT_pB{i}", {"profile_id": f"pB{i}", "classroom_id": "c1"})
    # Two students who join c1 after the roster was filled: pS7 (the teacher
    # will add them) and pS8 (their own device adds them on joining).
    for n in ("7", "8"):
        put(f"profiles/pS{n}", {"owner_uid": f"uS{n}", "name": f"Student {n}", "role": 0, "classroom_id": "c1"})
        put(f"classroom_members/c1_pS{n}", {"classroom_id": "c1", "profile_id": f"pS{n}"})
        put(f"assessment_results/r{n}", {"profileId": f"pS{n}", "assessmentId": "a1", "score": 5})
    # The rosters as the backfill files them: every member of each device's
    # classes and family groups, and the learners on the device itself.
    members = {f"pS{n}": f"uS{n}" for n in ("1", "2", "5")} | {f"pB{i}": f"uB{i}" for i in range(30)}
    put("educator_rosters/uT", {"learners": members, "via": {k: "c1" for k in members}})
    put("educator_rosters/uP", {"learners": {"pC": "uC"}, "via": {"pC": "g1"}})
    put("educator_rosters/uT2", {"learners": {"pS6": "uT2"}, "via": {"pS6": "device"}})
    put("classrooms/c1", {"teacher_id": "pT", "name": "Class", "code": "ABC123", "teacher_uid": "uT"})


def reads():
    allowed("a learner's own device reads their profile", get("uS1", "profiles/pS1"))
    allowed("... and their progress", get("uS1", "progress/pS1"))
    allowed("their teacher reads them (educator link)", get("uT", "profiles/pS1"))
    allowed("their teacher reads them without a link (the class on the profile)", get("uT", "profiles/pS2"))
    allowed("... and their progress", get("uT", "progress/pS2"))
    allowed("a parent reads their child", get("uP", "profiles/pC"))
    allowed("... and the child's progress", get("uP", "progress/pC"))
    allowed("a classmate reads them for the leaderboard (group link)", get("uS2", "profiles/pS1"))
    allowed("... and their progress", get("uS2", "progress/pS1"))
    denied("a classmate whose device filed no group link", get("uS5", "profiles/pS1"))
    denied("a stranger reads a learner's profile", get("uX", "profiles/pS1"))
    denied("... their progress", get("uX", "progress/pS1"))
    denied("... a child's profile", get("uX", "profiles/pC"))
    denied("a friend is not a reader of the profile", get("uF", "profiles/pS1"))
    denied("a teacher reads a child who is not theirs", get("uT", "profiles/pC"))
    # 404: the read was allowed, and there is nothing there.
    allowed("a missing profile reads as missing (deleted-learner check)",
            200 if get("uX", "profiles/pGone") == 404 else 403)
    allowed("the teacher lists their learners by id (with a deleted one)",
            query("uT", "profiles", ("__name__", "IN", ["pS1", "pS2", "pGone"])))
    denied("a stranger lists a learner by id", query("uX", "profiles", ("__name__", "IN", ["pS1"])))
    denied("the teacher's list may not include someone else's child",
           query("uT", "profiles", ("__name__", "IN", ["pS1", "pC"])))

    allowed("the teacher reads their students' results (several at once)",
            query("uT", "assessment_results", ("profileId", "IN", ["pS1", "pS2"])))
    allowed("... thirty at once, as the app asks",
            query("uT", "assessment_results", ("profileId", "IN", [f"pB{i}" for i in range(30)])))
    # A by-id list counts every name it carries as a document read, and a
    # request may read 20 in all: the app asks for 10 names at a time.
    allowed("the teacher lists ten learners by id (deleted-learner check)",
            query("uT", "profiles", ("__name__", "IN", [f"pB{i}" for i in range(9)] + ["pGone"])))
    allowed("... with a new student not on the roster yet (checked on their own)",
            query("uT", "profiles", ("__name__", "IN", [f"pB{i}" for i in range(8)] + ["pS7", "pGone"])))
    denied("... never more than 20 names (the engine's limit)",
           query("uT", "profiles", ("__name__", "IN", [f"pB{i}" for i in range(21)])))
    allowed("thirty at once with a new student not on the roster yet (checked on their own)",
            query("uT", "assessment_results", ("profileId", "IN", [f"pB{i}" for i in range(29)] + ["pS7"])))
    denied("thirty at once with one learner who is not theirs",
           query("uT", "assessment_results", ("profileId", "IN", [f"pB{i}" for i in range(29)] + ["pC"])))
    allowed("a learner lists their own results", query("uS1", "assessment_results", ("profileId", "EQUAL", "pS1")))
    denied("a classmate reads a learner's results", query("uS2", "assessment_results", ("profileId", "EQUAL", "pS1")))
    denied("a stranger reads one result by id", get("uX", "assessment_results/r1"))
    denied("a stranger lists a learner's results", query("uX", "assessment_results", ("profileId", "EQUAL", "pS1")))

    allowed("the child reads their own time limit", get("uC", "child_time_limits/pC"))
    allowed("the parent reads it", get("uP", "child_time_limits/pC"))
    denied("a stranger reads a child's time limit", get("uX", "child_time_limits/pC"))
    allowed("the parent lists the limits they set", query("uP", "child_time_limits", ("setter_profile_id", "EQUAL", "pP")))
    denied("a stranger lists a parent's limits", query("uX", "child_time_limits", ("setter_profile_id", "EQUAL", "pP")))
    allowed("the child lists their alarms", query("uC", "child_alarms", ("child_profile_id", "EQUAL", "pC")))
    allowed("the parent lists the child's alarms", query("uP", "child_alarms", ("child_profile_id", "EQUAL", "pC")))
    denied("a stranger lists a child's alarms", query("uX", "child_alarms", ("child_profile_id", "EQUAL", "pC")))
    denied("... or reads one by id", get("uX", "child_alarms/al1"))
    allowed("the child lists their routines", query("uC", "routines", ("child_profile_id", "EQUAL", "pC")))
    denied("a stranger lists a child's routines", query("uX", "routines", ("child_profile_id", "EQUAL", "pC")))
    denied("a stranger reads a routine by id", get("uX", "routines/rt1"))
    allowed("the parent reads the child's routine day", get("uP", f"routine_logs/pC_{DAY}"))
    denied("a stranger reads it", get("uX", f"routine_logs/pC_{DAY}"))
    denied("... or lists the routine days", query("uX", "routine_logs", ("profile_id", "EQUAL", "pC")))
    allowed("the child reads the parent's action on their day", get("uC", f"routine_actions/pC_{DAY}"))
    denied("a stranger reads it", get("uX", f"routine_actions/pC_{DAY}"))
    allowed("the child reads their unlock", get("uC", "child_unlock_overrides/pC"))
    denied("a stranger reads it", get("uX", "child_unlock_overrides/pC"))
    allowed("the parent reads the child's study time", get("uP", f"active_time_logs/pC_{DAY}"))
    allowed("... and lists it", query("uP", "active_time_logs", ("child_profile_id", "EQUAL", "pC")))
    denied("a stranger reads a child's study time", get("uX", f"active_time_logs/pC_{DAY}"))
    denied("... or lists it", query("uX", "active_time_logs", ("child_profile_id", "EQUAL", "pC")))
    denied("a classmate cannot read another's study time either", get("uS2", f"active_time_logs/pC_{DAY}"))


def class_docs():
    # The class and family documents carry the join code.
    allowed("the teacher reads their class", get("uT", "classrooms/c1"))
    allowed("a member's device (group link) reads the class", get("uS1", "classrooms/c1"))
    denied("a member whose device filed no group link yet", get("uS5", "classrooms/c1"))
    denied("a stranger who knows a class's id cannot read it (or its code)", get("uX", "classrooms/c1"))
    allowed("anyone with the code finds the class (how a learner joins)",
            req("POST", f"{BASE}:runQuery", {"structuredQuery": {
                "from": [{"collectionId": "classrooms"}], "limit": 1,
                "where": {"fieldFilter": {"field": {"fieldPath": "code"}, "op": "EQUAL",
                                          "value": val("ABC123")}}}}, "uX")[0])
    allowed("the parent reads their family group", get("uP", "home_groups/g1"))
    denied("a stranger reads a family group by id", get("uX", "home_groups/g1"))
    denied("the child's device before its family link", get("uC", "home_groups/g1"))
    allowed("a missing class reads as missing", 200 if get("uX", "classrooms/gone") == 404 else 403)
    # The memberships: who is in a class, and (since 1.4.1) the code they joined with.
    allowed("the teacher lists their class", query("uT", "classroom_members", ("classroom_id", "EQUAL", "c1")))
    allowed("a member's device lists its classmates (leaderboard)",
            query("uS1", "classroom_members", ("classroom_id", "EQUAL", "c1")))
    allowed("a learner lists their own memberships",
            query("uS5", "classroom_members", ("profile_id", "EQUAL", "pS5")))
    allowed("... and reads one", get("uS5", "classroom_members/c1_pS5"))
    denied("a stranger who knows a class's id lists who is in it",
           query("uX", "classroom_members", ("classroom_id", "EQUAL", "c1")))
    denied("... or reads one membership", get("uX", "classroom_members/c1_pS1"))
    allowed("the parent lists their family group", query("uP", "home_group_members", ("home_group_id", "EQUAL", "g1")))
    denied("a stranger lists a family group", query("uX", "home_group_members", ("home_group_id", "EQUAL", "g1")))
    denied("... or reads a child's membership", get("uX", "home_group_members/g1_pC"))


def roster(uid, owner, learner, learners, via, mask=None):
    """One roster write by [uid] to [owner]'s roster about [learner]."""
    return patch(uid, f"educator_rosters/{owner}",
                 {"learners": learners, "via": via, "learner": learner},
                 mask or [f"learners.{learner}", f"via.{learner}", "learner"])


def rosters():
    allowed("the teacher's device adds a new student of theirs",
            roster("uT", "uT", "pS7", {"pS7": "uS7"}, {"pS7": "c1"}))
    denied("... naming the wrong device for them",
           roster("uT", "uT", "pS7", {"pS7": "uX"}, {"pS7": "c1"}))
    denied("the teacher adds a child who is not theirs",
           roster("uT", "uT", "pC", {"pC": "uC"}, {"pC": "c1"}))
    denied("two learners in one write",
           patch("uT", "educator_rosters/uT", {"learners": {"pS7": "uS7", "pC": "uC"}, "learner": "pS7"},
                 ["learners.pS7", "learners.pC", "learner"]))
    allowed("the tablet's teacher adds the student on the same tablet",
            roster("uT2", "uT2", "pS6", {"pS6": "uT2"}, {"pS6": "device"}))
    allowed("a stranger may keep an empty roster of their own",
            create("uX", "educator_rosters/uX", {"learners": {}}))
    denied("a stranger adds a learner to their own roster",
           roster("uX", "uX", "pS1", {"pS1": "uS1"}, {"pS1": "cX"}))
    denied("a stranger adds themselves to the teacher's roster",
           roster("uX", "uT", "pX", {"pX": "uX"}, {"pX": "c1"}))
    allowed("a new student's device adds them to their teacher's roster",
            roster("uS8", "uT", "pS8", {"pS8": "uS8"}, {"pS8": "c1"}))
    denied("... not to a device that is not the teacher's",
           roster("uS8", "uX", "pS8", {"pS8": "uS8"}, {"pS8": "c1"}))
    denied("... not naming another learner",
           roster("uS8", "uT", "pS2", {"pS2": "uS2"}, {"pS2": "c1"}))
    denied("... not for a class they are not in",
           roster("uS8", "uT", "pS8", {"pS8": "uS8"}, {"pS8": "cX"}))
    denied("... not touching anyone else's entry",
           patch("uS8", "educator_rosters/uT",
                 {"learners": {"pS8": "uS8"}, "via": {"pS8": "c1"}, "learner": "pS8"},
                 ["learners.pS8", "learners.pS1", "via.pS8", "learner"]))
    denied("a learner removes someone else", roster("uS1", "uT", "pS2", {}, {}))
    allowed("a learner removes themselves", roster("uS2", "uT", "pS2", {}, {}))
    allowed("the teacher removes a learner", roster("uT", "uT", "pS5", {}, {}))
    allowed("a device reads its own roster", get("uT", "educator_rosters/uT"))
    denied("nobody reads another device's roster", get("uX", "educator_rosters/uT"))
    # What the roster proves, and what it no longer proves once a learner is off it.
    allowed("(student B1 leaves the class)", delete("uB1", "classroom_members/c1_pB1"))
    allowed("until the teacher's app takes them off, the roster still lists their results",
            query("uT", "assessment_results", ("profileId", "IN", ["pB0", "pB1"])))
    allowed("(the teacher's app takes them off)", roster("uT", "uT", "pB1", {}, {}))
    denied("then nothing proves them", query("uT", "assessment_results", ("profileId", "IN", ["pB0", "pB1"])))
    denied("... nor one result by id", get("uT", "assessment_results/rb1"))


def assignments():
    def assignment(by, ids, uids):
        return {"assignedBy": by, "studentIds": ids, "student_uids": uids, "assessmentId": "a1"}
    allowed("the teacher sets a test for their students",
            create("uT", "assessment_assignments/t1", assignment("pT", ["pS1", "pB0"], ["uS1", "uB0"])))
    denied("... naming a child who is not theirs",
           create("uT", "assessment_assignments/t2", assignment("pT", ["pS1", "pC"], ["uS1"])))
    denied("... addressed to a stranger's device",
           create("uT", "assessment_assignments/t3", assignment("pT", ["pS1"], ["uS1", "uX"])))
    denied("a stranger sets a test for a learner",
           create("uX", "assessment_assignments/t4", assignment("pXT", ["pS1"], ["uS1"])))
    denied("... or just for their device",
           create("uX", "assessment_assignments/t5", assignment("pXT", [], ["uS1"])))
    allowed("the parent sets a test for their child",
            create("uP", "assessment_assignments/t6", assignment("pP", ["pC"], ["uC"])))
    allowed("the tablet's teacher sets one for the student on the tablet",
            create("uT2", "assessment_assignments/t7", assignment("pT2", ["pS6"], ["uT2"])))
    put("assessment_assignments/old", assignment("pT", ["pB1", "pS1"], []))  # pB1 left (above)
    allowed("the teacher's app fills in the devices of an older assignment",
            patch("uT", "assessment_assignments/old", {"student_uids": ["uS1"]}, ["student_uids"]))
    allowed("... and edits it while it still names a learner who left",
            patch("uT", "assessment_assignments/old", {"assessmentTitle": "x"}, ["assessmentTitle"]))
    denied("... but cannot add someone who is not theirs",
           patch("uT", "assessment_assignments/old", {"studentIds": ["pB1", "pS1", "pC"]}, ["studentIds"]))
    denied("an assignment cannot move to another setter",
           patch("uT", "assessment_assignments/t1", {"assignedBy": "pXT"}, ["assignedBy"]))
    allowed("a learner finds the tests set for their device",
            query("uS1", "assessment_assignments", ("student_uids", "ARRAY_CONTAINS", "uS1")))


def group_links():
    allowed("a member's device files its group link",
            create("uS5", "group_readers/c1_uS5", {"group_id": "c1", "profile_id": "pS5", "kind": "class"}))
    allowed("now it reads its classmates", get("uS5", "profiles/pS1"))
    allowed("a child's device files its family link",
            create("uC", "group_readers/g1_uC", {"group_id": "g1", "profile_id": "pC", "kind": "family"}))
    denied("a stranger files a link to a class they are not in",
           create("uX", "group_readers/c1_uX", {"group_id": "c1", "profile_id": "pX", "kind": "class"}))
    denied("... naming someone else's profile",
           create("uX", "group_readers/c1_uX", {"group_id": "c1", "profile_id": "pS1", "kind": "class"}))
    denied("nobody files a link for another device",
           create("uS1", "group_readers/c1_uS2", {"group_id": "c1", "profile_id": "pS1", "kind": "class"}))
    denied("a link to a family group the learner never joined",
           create("uS1", "group_readers/g1_uS1", {"group_id": "g1", "profile_id": "pS1", "kind": "family"}))
    denied("the link carries nothing else",
           create("uS2", "group_readers/c1_uS2b", {"group_id": "c1", "profile_id": "pS2", "kind": "class",
                                                   "admin": True}))
    denied("a stranger reads someone's link", get("uX", "group_readers/c1_uS1"))
    allowed("a device reads its own link", get("uS1", "group_readers/c1_uS1"))
    # The member leaves: the link stays, the membership under it is gone.
    allowed("(student 5 leaves the class)", delete("uS5", "classroom_members/c1_pS5"))
    denied("the former classmate no longer reads them", get("uS5", "profiles/pS1"))


def messages():
    allowed("the teacher messages their student", create("uT", "messages/m1", message("pT", "pS1", "uT")))
    allowed("the student messages their teacher", create("uS1", "messages/m2", message("pS1", "pT", "uS1")))
    allowed("the parent messages their child", create("uP", "messages/m3", message("pP", "pC", "uP")))
    allowed("the child messages their parent", create("uC", "messages/m4", message("pC", "pP", "uC")))
    allowed("friends message each other", create("uF", "messages/m5", message("pF", "pS1", "uF")))
    allowed("... either way", create("uS1", "messages/m6", message("pS1", "pF", "uS1")))
    allowed("two profiles on one tablet", create("uT2", "messages/m7", message("pT2", "pS6", "uT2")))
    denied("a stranger messages a student", create("uX", "messages/x1", message("pX", "pS1", "uX")))
    denied("a stranger messages a child", create("uX", "messages/x2", message("pX", "pC", "uX")))
    denied("a stranger posing as a teacher of their own class", create("uX", "messages/x3", message("pXT", "pS1", "uX")))
    denied("a stranger messages a teacher", create("uX", "messages/x4", message("pX", "pT", "uX")))
    denied("a teacher messages a child who is not theirs", create("uT", "messages/x5", message("pT", "pC", "uT")))
    denied("classmates who are not friends", create("uS1", "messages/x6", message("pS1", "pS2", "uS1")))
    put("blocks/pS1_pF", {"blocker_profile_id": "pS1", "blocked_profile_id": "pF"})
    denied("a friend the learner blocked", create("uF", "messages/x7", message("pF", "pS1", "uF")))
    allowed("the teacher's class broadcast: 8 messages in one batch",
            batch_create("uT", [(f"messages/b{i}", message("pT", f"pB{i}", "uT")) for i in range(8)]))
    denied("one stranger's message spoils the whole batch",
           batch_create("uT", [("messages/b8", message("pT", "pB0", "uT")),
                               ("messages/b9", message("pT", "pC", "uT"))]))


def main():
    load_rules(RULES.read_text(encoding="utf-8").replace("\r\n", "\n"))
    wipe()
    seed()
    reads()
    class_docs()
    rosters()
    assignments()
    group_links()
    messages()
    print(f"{passed} passed, {len(failed)} failed")
    for f in failed:
        print("  FAIL", f)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
