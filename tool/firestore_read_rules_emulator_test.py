"""Read-rule test for firestore.rules, run against the LOCAL Firestore emulator.

    firebase emulators:start --only firestore --project demo-flashlearn
    python tool/firestore_read_rules_emulator_test.py

Never touches the real project: it loads firestore.rules into a `demo-`
project on 127.0.0.1:8080 and seeds it with the emulator's admin token. Each
user is an unsigned emulator token, like an anonymous sign-in.

What it pins (reads narrowed 2026-10-04): every query the app makes still
works — rosters, a parent's dashboard, join codes, messages, recovery — while
a copy of the app can no longer sweep a collection or read a stranger's
messages, friend requests, game rooms or file lists. Assignments followed
the same day: learners find theirs by their own uid (`student_uids`) and
the old `studentIds` lookup is closed.
"""
import base64, json, sys, time, urllib.error, urllib.request
from pathlib import Path

PROJECT = "demo-flashlearn"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
BASE = f"http://127.0.0.1:8080/v1/{ROOT}"
RULES = Path(__file__).resolve().parent.parent / "firestore.rules"
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
    if isinstance(v, list):
        return {"arrayValue": {"values": [val(x) for x in v]}}
    return {"stringValue": v}


def put(path, fields):
    st, body = req("PATCH", f"{BASE}/{path}", {"fields": {k: val(v) for k, v in fields.items()}})
    assert st == 200, (path, st, body)


def load_rules():
    text = RULES.read_text(encoding="utf-8").replace("\r\n", "\n")
    r = urllib.request.Request(
        f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}:securityRules", method="PUT",
        data=json.dumps({"rules": {"files": [{"name": "firestore.rules", "content": text}]}}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=20) as resp:
        assert resp.status == 200


def query(uid, coll, *filters, limit=None):
    """filters: (field, op, value) with op EQUAL / IN / ARRAY_CONTAINS; field '__name__' takes doc ids."""
    parts = []
    for field, op, v in filters:
        if field == "__name__":
            value = {"arrayValue": {"values": [{"referenceValue": f"{ROOT}/{coll}/{i}"} for i in v]}}
        else:
            value = val(v)
        parts.append({"fieldFilter": {"field": {"fieldPath": field}, "op": op, "value": value}})
    sq = {"from": [{"collectionId": coll}]}
    if parts:
        sq["where"] = parts[0] if len(parts) == 1 else {"compositeFilter": {"op": "AND", "filters": parts}}
    if limit:
        sq["limit"] = limit
    st, _ = req("POST", f"{BASE}:runQuery", {"structuredQuery": sq}, uid)
    return st


def subquery(uid, parent, coll):
    """Every doc of a subcollection under [parent] (a doc path)."""
    st, _ = req("POST", f"{BASE}/{parent}:runQuery",
                {"structuredQuery": {"from": [{"collectionId": coll}]}}, uid)
    return st


def get(uid, path):
    st, _ = req("GET", f"{BASE}/{path}", None, uid)
    return st



passed, failed = 0, []


def allowed(label, status):
    global passed
    # 404 = the read was allowed and the doc simply does not exist.
    if status in (200, 404):
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
    put("profiles/pT", {"owner_uid": "uT", "name": "Teacher", "role": 1})
    put("profiles/pS1", {"owner_uid": "uS1", "name": "Student One", "role": 0, "disability_type": 1})
    put("profiles/pS2", {"owner_uid": "uS2", "name": "Student Two", "role": 0})
    put("profiles/pP", {"owner_uid": "uP", "name": "Parent", "role": 2})
    put("profiles/pC", {"owner_uid": "uC", "name": "Child", "role": 3})
    put("profiles/pX", {"owner_uid": "uX", "name": "Stranger", "role": 0})
    put("progress/pS1", {"owner_uid": "uS1", "stars": 5})
    put("app_state/tutorial_seen_pS1", {"owner_uid": "uS1", "value": True})
    put("custom_cards/cc1", {"owner_uid": "uT", "id": "cc1", "word_english": "Lola"})
    put("session_logs/sl1", {"owner_uid": "uS1", "profile_id": "pS1", "date": "2026-10-04"})
    put("shop_equipped/pS1_avatar", {"owner_uid": "uS1", "profile_id": "pS1", "item_id": "hat"})
    put("classrooms/c1", {"teacher_id": "pT", "code": "ABC123", "name": "Class"})
    put("classroom_members/c1_pS1", {"classroom_id": "c1", "profile_id": "pS1"})
    put("home_groups/g1", {"owner_profile_id": "pP", "code": "HG1234"})
    put("home_group_members/g1_pC", {"home_group_id": "g1", "profile_id": "pC"})
    put("messages/m1", {"sender_profile_id": "pS1", "recipient_profile_id": "pT", "content": "hi"})
    put("messages/m2", {"sender_profile_id": "pP", "recipient_profile_id": "pC", "content": "hello"})
    put("assessments/a1", {"created_by_profile_id": "pT", "title": "Pre-test"})
    put("assessment_assignments/as1",
        {"assignedBy": "pT", "studentIds": ["pS1"], "student_uids": ["uS1"], "assessmentId": "a1"})
    put("assessment_results/r1", {"profileId": "pS1", "assessmentId": "a1", "score": 8})
    put("live_sessions/c1", {"owner_uid": "uT", "active": True})
    put("child_time_limits/pC", {"setter_profile_id": "pP", "owner_uid": "uP", "minutes": 60})
    put("child_unlock_overrides/pC", {"setter_profile_id": "pP", "owner_uid": "uP"})
    put("child_alarms/al1", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP"})
    put("routines/rt1", {"child_profile_id": "pC", "setter_profile_id": "pP", "owner_uid": "uP",
                         "media_refs": ["m-1"]})
    put("routine_logs/pC_2026-10-04", {"profile_id": "pC", "owner_uid": "uC"})
    put("routine_actions/pC_2026-10-04", {"child_profile_id": "pC", "setter_profile_id": "pP"})
    put("active_time_logs/pC_2026-10-04", {"child_profile_id": "pC", "owner_uid": "uC"})
    put("leaderboard_config_classroom/c1", {"owner_uid": "uT", "visible": True})
    put("profile_directory/student1", {"profile_id": "pS1", "owner_uid": "uS1"})
    put("friend_requests/pS1_pS2", {"from_profile_id": "pS1", "to_profile_id": "pS2", "status": "pending"})
    put("friend_requests/pC_pS2", {"from_profile_id": "pC", "to_profile_id": "pS2", "status": "awaiting_parent",
                                   "from_home_group_id": "g1"})
    put("friendships/pS1_pS2", {"profile_a": "pS1", "profile_b": "pS2"})
    put("game_rooms/gr1", {"host_profile_id": "pS1", "invited_profile_id": "pS2", "guest_profile_id": None,
                           "status": "waiting"})
    put("shared_media/sm1", {"owner_profile_id": "pS1", "owner_uid": "uS1", "size": 10, "chunk_count": 1})
    put("shared_media/sm1/chunks/0", {"n": 0})
    put("parent_teacher_notes/pS1/notes/n1", {"author_uid": "uT", "text": "Doing well"})


def main():
    load_rules()
    seed()
    day = "pC_2026-10-04"

    # ── what the app does: must keep working ──
    allowed("my profiles (sign-in)", query("uT", "profiles", ("owner_uid", "EQUAL", "uT")))
    allowed("profiles by id (deleted-learner check)", query("uT", "profiles", ("__name__", "IN", ["pS1", "pS2"])))
    # The check exists to find profiles that are GONE: a missing id among the
    # names must not refuse the whole query (production evaluates each name).
    allowed("deleted-learner check with a deleted learner",
            query("uT", "profiles", ("__name__", "IN", ["pS1", "pGone"])))
    allowed("roster reads a student's profile", get("uT", "profiles/pS1"))
    allowed("recovery reads the profile it claims", get("uNew", "profiles/pS1"))
    allowed("teacher reads a student's progress", get("uT", "progress/pS1"))
    allowed("my app state", get("uS1", "app_state/tutorial_seen_pS1"))
    allowed("my custom cards (restore)", query("uT", "custom_cards", ("owner_uid", "EQUAL", "uT")))
    allowed("recovery lists the old tablet's cards", query("uNew", "custom_cards", ("owner_uid", "EQUAL", "uT")))
    allowed("my session logs (delete cascade)", query("uS1", "session_logs", ("profile_id", "EQUAL", "pS1")))
    allowed("equipped item by id", get("uX", "shop_equipped/pS1_avatar"))
    allowed("equipped items of a profile (cascade / recovery)",
            query("uNew", "shop_equipped", ("profile_id", "EQUAL", "pS1")))
    allowed("join a class by code", query("uS2", "classrooms", ("code", "EQUAL", "ABC123"), limit=1))
    allowed("teacher's own classes", query("uT", "classrooms", ("teacher_id", "EQUAL", "pT")))
    allowed("member reads the class", get("uS1", "classrooms/c1"))
    allowed("teacher's roster", query("uT", "classroom_members", ("classroom_id", "EQUAL", "c1")))
    allowed("student sees classmates", query("uS1", "classroom_members", ("classroom_id", "EQUAL", "c1")))
    allowed("my memberships", query("uS1", "classroom_members", ("profile_id", "EQUAL", "pS1")))
    allowed("join a home group by code", query("uC", "home_groups", ("code", "EQUAL", "HG1234"), limit=1))
    allowed("parent's own groups", query("uP", "home_groups", ("owner_profile_id", "EQUAL", "pP")))
    allowed("parent's group members", query("uP", "home_group_members", ("home_group_id", "EQUAL", "g1")))
    allowed("child's own group memberships", query("uC", "home_group_members", ("profile_id", "EQUAL", "pC")))
    allowed("educator's templates", query("uT", "assessments", ("created_by_profile_id", "EQUAL", "pT")))
    allowed("learner fetches assigned templates by id", query("uS1", "assessments", ("__name__", "IN", ["a1"])))
    allowed("an assigned template that was deleted",
            query("uS1", "assessments", ("__name__", "IN", ["a1", "aGone"])))
    allowed("learner finds their work by uid",
            query("uS1", "assessment_assignments", ("student_uids", "ARRAY_CONTAINS", "uS1")))
    allowed("learner reads their assignment", get("uS1", "assessment_assignments/as1"))
    allowed("educator's assignments", query("uT", "assessment_assignments", ("assignedBy", "EQUAL", "pT")))
    allowed("educator reads assignees' results", query("uT", "assessment_results", ("profileId", "IN", ["pS1", "pS2"])))
    allowed("learner's results (cascade)", query("uS1", "assessment_results", ("profileId", "EQUAL", "pS1")))
    allowed("learner joins the live session", get("uS1", "live_sessions/c1"))
    allowed("child's alarms on the child's tablet", query("uC", "child_alarms", ("child_profile_id", "EQUAL", "pC")))
    allowed("parent's alarms for the child", query("uP", "child_alarms", ("child_profile_id", "EQUAL", "pC"),
                                                   ("setter_profile_id", "EQUAL", "pP")))
    allowed("everything a parent set (cleanup)", query("uP", "child_alarms", ("setter_profile_id", "EQUAL", "pP")))
    allowed("child's routines", query("uC", "routines", ("child_profile_id", "EQUAL", "pC")))
    allowed("parent's routines", query("uP", "routines", ("setter_profile_id", "EQUAL", "pP")))
    allowed("routine day by key", get("uP", f"routine_logs/{day}"))
    allowed("routine logs (cascade)", query("uC", "routine_logs", ("profile_id", "EQUAL", "pC")))
    allowed("routine actions (cleanup)", query("uP", "routine_actions", ("child_profile_id", "EQUAL", "pC"),
                                               ("setter_profile_id", "EQUAL", "pP")))
    allowed("child's time limit", get("uC", "child_time_limits/pC"))
    allowed("limits a parent set (cleanup)", query("uP", "child_time_limits", ("setter_profile_id", "EQUAL", "pP")))
    allowed("child's unlock override", get("uC", "child_unlock_overrides/pC"))
    allowed("overrides a parent set (cleanup)",
            query("uP", "child_unlock_overrides", ("setter_profile_id", "EQUAL", "pP")))
    allowed("active time by key", get("uP", f"active_time_logs/{day}"))
    allowed("active time (cascade)", query("uC", "active_time_logs", ("child_profile_id", "EQUAL", "pC")))
    allowed("leaderboard config", get("uS1", "leaderboard_config_classroom/c1"))
    allowed("my sent messages", query("uS1", "messages", ("sender_profile_id", "EQUAL", "pS1")))
    allowed("my received messages", query("uT", "messages", ("recipient_profile_id", "EQUAL", "pT")))
    allowed("recipient reads a message", get("uT", "messages/m1"))
    allowed("username lookup", get("uX", "profile_directory/student1"))
    allowed("my username", query("uS1", "profile_directory", ("profile_id", "EQUAL", "pS1"), limit=1))
    allowed("incoming friend requests", query("uS2", "friend_requests", ("to_profile_id", "EQUAL", "pS2")))
    allowed("outgoing friend requests", query("uS1", "friend_requests", ("from_profile_id", "EQUAL", "pS1")))
    allowed("parent's approvals queue", query("uP", "friend_requests", ("from_home_group_id", "IN", ["g1"])))
    allowed("request pre-check (not there yet)", get("uS1", "friend_requests/pS2_pS1"))
    allowed("recipient reads the request", get("uS2", "friend_requests/pS1_pS2"))
    allowed("parent reads the child's request", get("uP", "friend_requests/pC_pS2"))
    allowed("my friendships (a)", query("uS1", "friendships", ("profile_a", "EQUAL", "pS1")))
    allowed("my friendships (b)", query("uS2", "friendships", ("profile_b", "EQUAL", "pS2")))
    allowed("friendship by id", get("uS2", "friendships/pS1_pS2"))
    allowed("friendship pre-check (not there yet)", get("uS1", "friendships/pS1_pX"))
    allowed("my invitations", query("uS2", "game_rooms", ("invited_profile_id", "EQUAL", "pS2")))
    allowed("rooms I host", query("uS1", "game_rooms", ("host_profile_id", "EQUAL", "pS1")))
    allowed("invited friend watches the room", get("uS2", "game_rooms/gr1"))
    allowed("teacher opens a video answer", get("uT", "shared_media/sm1"))
    allowed("teacher reads its pieces", get("uT", "shared_media/sm1/chunks/0"))
    allowed("my files (sweep / cascade)", query("uS1", "shared_media", ("owner_profile_id", "EQUAL", "pS1")))
    allowed("notes about a student", subquery("uT", "parent_teacher_notes/pS1", "notes"))

    # ── what a copy of the app must no longer do ──
    for coll in ["profiles", "progress", "custom_cards", "session_logs", "shop_equipped", "app_state",
                 "classrooms", "classroom_members", "home_groups", "home_group_members", "assessments",
                 "assessment_results", "live_sessions", "child_time_limits", "child_unlock_overrides",
                 "child_alarms", "routines", "routine_logs", "routine_actions", "active_time_logs",
                 "messages", "profile_directory", "friend_requests", "friendships", "game_rooms",
                 "shared_media", "leaderboard_config_classroom", "assessment_assignments"]:
        denied(f"sweep {coll}", query("uX", coll))
    denied("someone else's profiles", query("uX", "profiles", ("owner_uid", "EQUAL", "uT")))
    denied("class codes without a code", query("uX", "classrooms", ("teacher_id", "EQUAL", "pT")))
    denied("class codes, many at once", query("uX", "classrooms", ("code", "EQUAL", "ABC123"), limit=50))
    denied("someone else's session logs", query("uX", "session_logs", ("profile_id", "EQUAL", "pS1")))
    denied("a session log by id", get("uX", "session_logs/sl1"))
    denied("a stranger's messages", query("uX", "messages", ("recipient_profile_id", "EQUAL", "pT")))
    denied("a stranger reads a message", get("uX", "messages/m1"))
    denied("a stranger reads a parent's message", get("uT", "messages/m2"))
    denied("someone else's friend requests", query("uX", "friend_requests", ("to_profile_id", "EQUAL", "pS2")))
    denied("a stranger reads a friend request", get("uX", "friend_requests/pS1_pS2"))
    denied("someone else's approvals queue", query("uX", "friend_requests", ("from_home_group_id", "IN", ["g1"])))
    denied("someone else's friendships", query("uX", "friendships", ("profile_a", "EQUAL", "pS1")))
    denied("a stranger reads a friendship", get("uX", "friendships/pS1_pS2"))
    denied("someone else's invitations", query("uX", "game_rooms", ("invited_profile_id", "EQUAL", "pS2")))
    denied("a stranger watches a room", get("uX", "game_rooms/gr1"))
    denied("someone else's file list", query("uX", "shared_media", ("owner_profile_id", "EQUAL", "pS1")))
    denied("someone else's templates", query("uX", "assessments", ("created_by_profile_id", "EQUAL", "pT")))
    denied("someone else's live sessions", query("uX", "live_sessions", ("owner_uid", "EQUAL", "uT")))
    denied("a stranger's progress audit", get("uX", "progress_audit/pS1/events/e1"))

    # Assignments (closed 2026-10-04): by learner uid only.
    denied("the old studentIds lookup is closed",
           query("uS1", "assessment_assignments", ("studentIds", "ARRAY_CONTAINS", "pS1")))
    denied("someone else's uid",
           query("uX", "assessment_assignments", ("student_uids", "ARRAY_CONTAINS", "uS1")))
    denied("a stranger reads an assignment", get("uX", "assessment_assignments/as1"))

    print(f"{passed} passed, {len(failed)} failed")
    for f in failed:
        print("  " + f)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
