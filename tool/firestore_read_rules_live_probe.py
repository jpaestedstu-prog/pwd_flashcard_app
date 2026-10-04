"""Read-only check of the LIVE Firestore read rules (writes nothing to Firestore).

    python tool/firestore_read_rules_live_probe.py

Signs in anonymously like any copy of the app, tries the sweeps that used to
download every learner's data, checks that the app's own query shapes still
work, and deletes its own anonymous account afterwards. Every query asks for
at most one document, so even a wrongly-allowed sweep reads almost nothing.
"""
import json, sys, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pwd-flashcard"
API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"  # the app's public client key
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def call(method, url, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(url, method=method, headers=headers,
                               data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:160]


def eq(field, value):
    return {"fieldFilter": {"field": {"fieldPath": field}, "op": "EQUAL",
                            "value": {"stringValue": value}}}


def query(token, coll, where=None):
    q = {"from": [{"collectionId": coll}], "limit": 1}
    if where:
        q["where"] = where
    st, _ = call("POST", f"{FS}:runQuery", {"structuredQuery": q}, token)
    return st


SWEEPS = ["profiles", "progress", "messages", "shared_media", "classrooms", "classroom_members",
          "home_groups", "home_group_members", "assessment_results", "session_logs",
          "friend_requests", "friendships", "game_rooms", "profile_directory", "child_alarms",
          "routines", "routine_logs", "custom_cards", "app_state", "active_time_logs"]


def main():
    st, auth = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                    {"returnSecureToken": True})
    if st != 200:
        sys.exit(f"anonymous sign-in failed: {st} {auth}")
    token, uid = auth["idToken"], auth["localId"]
    ok = True

    def expect(label, status, allowed):
        nonlocal ok
        good = (status in (200, 404)) if allowed else (status == 403)
        ok &= good
        print(("PASS" if good else "FAIL") + f" {label}: HTTP {status}")

    try:
        for coll in SWEEPS:
            expect(f"sweep {coll} refused", query(token, coll), allowed=False)
        expect("someone else's messages refused",
               query(token, "messages", eq("recipient_profile_id", "not-my-profile")), allowed=False)
        expect("someone else's file list refused",
               query(token, "shared_media", eq("owner_profile_id", "not-my-profile")), allowed=False)
        # The app's own shapes keep working (they return nothing for this new user).
        expect("my profiles (sign-in) allowed", query(token, "profiles", eq("owner_uid", uid)), allowed=True)
        expect("join-by-code lookup allowed", query(token, "classrooms", eq("code", "ZZZZZZ")), allowed=True)
        expect("one class's roster allowed",
               query(token, "classroom_members", eq("classroom_id", "no-such-class")), allowed=True)
        expect("username lookup allowed",
               call("GET", f"{FS}/profile_directory/no-such-user-x9", None, token)[0], allowed=True)
    finally:
        st, _ = call("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={API_KEY}",
                     {"idToken": token})
        print(f"throwaway anonymous account deleted: HTTP {st}")
    print("LIVE READ PROBE", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
