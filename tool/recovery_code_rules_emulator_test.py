"""Security-rules test for recovery_codes, run against the LOCAL Firestore emulator.

    firebase emulators:start --only firestore --project demo-flashlearn
    python tool/recovery_code_rules_emulator_test.py

Never touches the real project: the target is a `demo-` project on
127.0.0.1:8080, seeded with an admin ("owner") token that only the emulator
accepts. Each user is an unsigned emulator token, like an anonymous sign-in.

What it pins (the takeover closed on 2026-09-29): nobody may *list* codes
that are not their own — the doc id IS the code — while redeeming a code you
were given keeps working, and a code can only be spent by actually claiming
the profile with it.
"""
import base64, json, sys, time, urllib.error, urllib.request

PROJECT = "demo-flashlearn"
BASE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
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
        return e.code, e.read().decode()[:200]


def val(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    return {"stringValue": v}


def put(path, fields, uid=None):
    return req("PATCH", f"{BASE}/{path}", {"fields": {k: val(v) for k, v in fields.items()}}, uid)


def query(uid, filters, limit=None):
    parts = []
    for field, op, v in filters:
        if op == "IS_NULL":
            parts.append({"unaryFilter": {"field": {"fieldPath": field}, "op": "IS_NULL"}})
        else:
            parts.append({"fieldFilter": {"field": {"fieldPath": field}, "op": op, "value": val(v)}})
    q = {"from": [{"collectionId": "recovery_codes"}]}
    if parts:
        q["where"] = parts[0] if len(parts) == 1 else {"compositeFilter": {"op": "AND", "filters": parts}}
    if limit:
        q["limit"] = limit
    st, body = req("POST", f"{BASE}:runQuery", {"structuredQuery": q}, uid)
    docs = [x for x in body if "document" in x] if st == 200 else None
    return st, docs


def claim(uid, code, profile_id, redeemed_by=None):
    """The app's claim batch: profile to the new owner + code marked used."""
    name = f"projects/{PROJECT}/databases/(default)/documents"
    writes = [
        {"update": {"name": f"{name}/profiles/{profile_id}",
                    "fields": {"owner_uid": val(uid), "_recovery_code": val(code)}},
         "updateMask": {"fieldPaths": ["owner_uid", "_recovery_code"]}},
        {"update": {"name": f"{name}/recovery_codes/{code}",
                    "fields": {"redeemed_by_uid": val(redeemed_by or uid)}},
         "updateMask": {"fieldPaths": ["redeemed_by_uid", "used_at"]},
         "updateTransforms": [{"fieldPath": "used_at", "setToServerValue": "REQUEST_TIME"}]},
    ]
    return req("POST", f"{BASE}:commit", {"writes": writes}, uid)[0]


def burn_only(uid, code):
    """Mark a code used without claiming anything."""
    name = f"projects/{PROJECT}/databases/(default)/documents"
    return req("POST", f"{BASE}:commit", {"writes": [
        {"update": {"name": f"{name}/recovery_codes/{code}", "fields": {"redeemed_by_uid": val(uid)}},
         "updateMask": {"fieldPaths": ["redeemed_by_uid", "used_at"]},
         "updateTransforms": [{"fieldPath": "used_at", "setToServerValue": "REQUEST_TIME"}]}]}, uid)[0]


results = []


def check(label, ok):
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + label)


def main():
    # Fresh state: wipe the emulator's data for this project.
    req("DELETE", f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents")
    put("profiles/P1", {"owner_uid": "alice", "role": 0, "name": "Learner"})
    put("profiles/P2", {"owner_uid": "alice", "role": 0, "name": "Learner 2"})
    put("recovery_codes/AAAA-BBBB-CC", {"profile_id": "P1", "profile_owner_uid": "alice",
                                        "code_hash": "h", "code_salt": "s", "used_at": None})
    put("recovery_codes/DDDD-EEEE-FF", {"profile_id": "P2", "profile_owner_uid": "alice",
                                        "code_hash": "h", "code_salt": "s", "used_at": None})

    st, _ = query("mallory", [])
    check("a stranger cannot list all recovery codes", st == 403)
    st, _ = query("mallory", [("profile_id", "EQUAL", "P1")])
    check("a stranger cannot list a profile's codes by profile id", st == 403)
    st, _ = query("mallory", [("profile_owner_uid", "EQUAL", "alice")])
    check("a stranger cannot list codes by naming the owner", st == 403)

    st, docs = query("alice", [("profile_owner_uid", "EQUAL", "alice"), ("profile_id", "EQUAL", "P1"),
                               ("used_at", "IS_NULL", None)], limit=1)
    check("the owner's own 'show my code' query works", st == 200 and len(docs) == 1)
    st, docs = query("alice", [("profile_owner_uid", "EQUAL", "alice"), ("profile_id", "EQUAL", "P1")])
    check("the owner's delete-cascade query works", st == 200 and len(docs) == 1)
    st, _ = query("alice", [("profile_id", "EQUAL", "P1")])
    check("even the owner's query must carry the owner filter", st == 403)

    st, _ = req("GET", f"{BASE}/recovery_codes/AAAA-BBBB-CC", uid="bob")
    check("whoever holds the code can still look it up", st == 200)

    check("a stranger cannot spend a code without claiming", burn_only("mallory", "AAAA-BBBB-CC") == 403)
    check("nobody can mark a code redeemed in someone else's name",
          claim("bob", "AAAA-BBBB-CC", "P1", redeemed_by="alice") == 403)
    check("recovering with the code works (new tablet claims the profile)",
          claim("bob", "AAAA-BBBB-CC", "P1") == 200)
    st, prof = req("GET", f"{BASE}/profiles/P1", uid="bob")
    check("the profile now belongs to the recovering tablet",
          st == 200 and prof["fields"]["owner_uid"]["stringValue"] == "bob")
    check("a spent code cannot be used again", claim("mallory", "AAAA-BBBB-CC", "P1") == 403)

    st, _ = req("DELETE", f"{BASE}/recovery_codes/DDDD-EEEE-FF", uid="mallory")
    check("a stranger cannot delete someone's code", st == 403)
    st, _ = req("DELETE", f"{BASE}/recovery_codes/DDDD-EEEE-FF", uid="alice")
    check("the owner can revoke their code", st == 200)

    print(f"\n{sum(results)}/{len(results)} passed")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
