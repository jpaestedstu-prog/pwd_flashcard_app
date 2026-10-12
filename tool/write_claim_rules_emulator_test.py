"""Create-rule test for firestore.rules, run against the LOCAL Firestore emulator.

    firebase emulators:exec --only firestore --project demo-flashlearn \
        "python tool/write_claim_rules_emulator_test.py"

Never touches the real project (a `demo-` project on 127.0.0.1:8080, seeded
with the emulator's admin token; each user is an unsigned emulator token,
like an anonymous sign-in).

What it pins (2026-10-11): a document that belongs to one learner can only be
*started* by the device that owns the learner, or while the learner is not in
the cloud yet. Before, whoever wrote first owned it: a stranger who had seen a
learner's id on a roster could create that learner's progress, streak or
equipped items and lock the learner's own device out of them for good, or file
made-up study logs under the learner's name. Recovery onto a new device still
creates progress with a valid code.
"""
import base64, json, sys, time, urllib.error, urllib.parse, urllib.request
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
    """A write to a document that already exists."""
    st, _ = req("PATCH", f"{BASE}/{path}?currentDocument.exists=true", fields(data), uid)
    return st


def wipe():
    st, _ = req("DELETE", f"http://127.0.0.1:8080/emulator/v1/{ROOT}")
    assert st == 200, st


def load_rules():
    text = RULES.read_text(encoding="utf-8").replace("\r\n", "\n")
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
    put("profiles/pS1", {"owner_uid": "uS1", "name": "Student One", "role": 0})
    put("profiles/pS2", {"owner_uid": "uS2", "name": "Student Two", "role": 0})
    put("profiles/pX", {"owner_uid": "uX", "name": "Stranger", "role": 0})
    # Existing learners in the cloud today: a profile from before owner_uid
    # (not yet claimed by OwnerUidMigration), one with owner_uid null, and an
    # imported profile whose id contains underscores.
    put("profiles/pLegacy", {"name": "Old Tablet Learner", "role": 0})
    put("profiles/pNull", {"owner_uid": None, "name": "Unclaimed", "role": 0})
    put("profiles/p_imported_1", {"owner_uid": "uS1", "name": "Imported", "role": 0})
    # A learner already syncing: profile, progress and a study log on file.
    put("profiles/pS3", {"owner_uid": "uS3", "name": "Student Three", "role": 0})
    put("progress/pS3", {"owner_uid": "uS3", "stars": 40})
    put("session_logs/old3", {"owner_uid": "uS3", "profile_id": "pS3"})
    put("app_state/daily_streak_pS3", {"owner_uid": "uS3", "value": "4"})
    # A code the old tablet (uS2) issued for pS2, not yet redeemed.
    put("recovery_codes/MNGO-BERY-7K", {
        "profile_id": "pS2", "profile_owner_uid": "uS2", "used_at": None})


def main():
    load_rules()
    wipe()
    seed()

    # ── progress/{profileId} ──
    denied("a stranger starts a learner's progress",
           create("uX", "progress/pS1", {"owner_uid": "uX", "stars": 999}))
    allowed("the learner's device starts its own progress",
            create("uS1", "progress/pS1", {"owner_uid": "uS1", "stars": 1}))
    allowed("progress for a learner not in the cloud yet (offline first)",
            create("uN", "progress/pNew", {"owner_uid": "uN"}))
    allowed("recovery onto a new device creates progress with a valid code",
            create("uR", "progress/pS2",
                   {"owner_uid": "uR", "_recovery_code": "MNGO-BERY-7K"}))
    denied("a code for a different learner proves nothing",
           create("uR", "progress/pX",
                  {"owner_uid": "uR", "_recovery_code": "MNGO-BERY-7K"}))
    denied("progress stamped with someone else's uid",
           create("uX", "progress/pNew2", {"owner_uid": "uS1"}))

    # ── session_logs ──
    denied("a stranger files study time under a learner",
           create("uX", "session_logs/fake1",
                  {"owner_uid": "uX", "profile_id": "pS1", "duration_seconds": 99999}))
    allowed("the learner's device files its own study time",
            create("uS1", "session_logs/real1",
                   {"owner_uid": "uS1", "profile_id": "pS1", "duration_seconds": 60}))
    allowed("study time for a learner not in the cloud yet",
            create("uN", "session_logs/new1", {"owner_uid": "uN", "profile_id": "pNew"}))
    denied("a study log naming no learner",
           create("uX", "session_logs/none1", {"owner_uid": "uX"}))

    # ── shop_equipped ──
    denied("a stranger equips a learner's avatar first",
           create("uX", "shop_equipped/pS1_frame",
                  {"owner_uid": "uX", "profile_id": "pS1", "item_id": "x"}))
    allowed("the learner's device equips its own item",
            create("uS1", "shop_equipped/pS1_frame",
                   {"owner_uid": "uS1", "profile_id": "pS1", "item_id": "gold"}))

    # ── app_state ──
    denied("a stranger claims a learner's streak",
           create("uX", "app_state/daily_streak_pS1", {"owner_uid": "uX", "value": "0"}))
    allowed("the learner's device starts its own streak",
            create("uS1", "app_state/daily_streak_pS1", {"owner_uid": "uS1", "value": "1"}))
    denied("a stranger claims a learner's tutorial flag",
           create("uX", "app_state/tutorial_seen_pS1", {"owner_uid": "uX", "value": "true"}))
    denied("a stranger claims a learner's daily challenge",
           create("uX", "app_state/daily_challenge_pS1", {"owner_uid": "uX", "value": "x"}))
    allowed("a learner not in the cloud yet",
            create("uN", "app_state/tutorial_seen_pNew", {"owner_uid": "uN", "value": "true"}))
    denied("another device's active-profile pointer",
           create("uX", "app_state/active_profile_uS1", {"owner_uid": "uX", "value": "pX"}))
    allowed("a device's own active-profile pointer",
            create("uX", "app_state/active_profile_uX", {"owner_uid": "uX", "value": "pX"}))
    allowed("any other key is as before",
            create("uX", "app_state/something_else", {"owner_uid": "uX", "value": "1"}))

    # ── existing learners keep working (2026-10-12, before deploying) ──
    allowed("a learner already syncing updates its progress",
            update("uS3", "progress/pS3", {"owner_uid": "uS3", "stars": 41}))
    allowed("... files a new study log",
            create("uS3", "session_logs/new3", {"owner_uid": "uS3", "profile_id": "pS3"}))
    allowed("... updates its streak",
            update("uS3", "app_state/daily_streak_pS3", {"owner_uid": "uS3", "value": "5"}))
    denied("a stranger still cannot overwrite that progress",
           update("uX", "progress/pS3", {"owner_uid": "uX", "stars": 999}))
    allowed("a legacy profile (no owner_uid yet) still files study logs",
            create("uL", "session_logs/legacy1", {"owner_uid": "uL", "profile_id": "pLegacy"}))
    allowed("... and starts its progress",
            create("uL", "progress/pLegacy", {"owner_uid": "uL", "stars": 1}))
    allowed("... and its tutorial flag",
            create("uL", "app_state/tutorial_seen_pLegacy", {"owner_uid": "uL", "value": "true"}))
    allowed("a profile with owner_uid null is treated the same",
            create("uL", "session_logs/null1", {"owner_uid": "uL", "profile_id": "pNull"}))
    allowed("an imported id with underscores: its own device",
            create("uS1", "app_state/tutorial_seen_p_imported_1", {"owner_uid": "uS1", "value": "true"}))
    allowed("... its streak",
            create("uS1", "app_state/daily_streak_p_imported_1", {"owner_uid": "uS1", "value": "1"}))
    denied("... but not a stranger",
           create("uX", "app_state/daily_challenge_p_imported_1", {"owner_uid": "uX", "value": "x"}))
    denied("... nor a stranger's study log",
           create("uX", "session_logs/imp1", {"owner_uid": "uX", "profile_id": "p_imported_1"}))

    print(f"{passed} passed, {len(failed)} failed")
    for f in failed:
        print("  FAIL", f)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
