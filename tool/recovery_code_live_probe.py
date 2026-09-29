"""Read-only check of the LIVE recovery_codes rules (writes nothing to Firestore).

    python tool/recovery_code_live_probe.py

Signs in anonymously like any tablet, tries the listing that used to expose
every unused recovery code, and deletes its own anonymous account afterwards.
Expected: every listing without the caller's own owner filter is refused.
"""
import json, sys, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pwd-flashcard"
API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"  # the app's public client key
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def post(url, body, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:160]


def main():
    st, auth = post(f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                    {"returnSecureToken": True})
    if st != 200:
        sys.exit(f"anonymous sign-in failed: {st} {auth}")
    token, uid = auth["idToken"], auth["localId"]
    ok = True
    try:
        for label, where in [
            ("list every recovery code", None),
            ("list codes by naming another owner",
             {"fieldFilter": {"field": {"fieldPath": "profile_owner_uid"}, "op": "EQUAL",
                              "value": {"stringValue": "someone-else"}}}),
        ]:
            q = {"from": [{"collectionId": "recovery_codes"}], "limit": 1}
            if where:
                q["where"] = where
            st, body = post(f"{FS}:runQuery", {"structuredQuery": q}, token)
            refused = st == 403
            ok &= refused
            print(("PASS" if refused else "FAIL") + f" {label}: HTTP {st}")
        # Our own (empty) listing must still be allowed — the app's query shape.
        st, body = post(f"{FS}:runQuery", {"structuredQuery": {
            "from": [{"collectionId": "recovery_codes"}], "limit": 1,
            "where": {"fieldFilter": {"field": {"fieldPath": "profile_owner_uid"}, "op": "EQUAL",
                                      "value": {"stringValue": uid}}}}}, token)
        allowed = st == 200
        ok &= allowed
        print(("PASS" if allowed else "FAIL") + f" own-codes listing still allowed: HTTP {st}")
    finally:
        st, _ = post(f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={API_KEY}",
                     {"idToken": token})
        print(f"probe account deleted: HTTP {st}")
    print("LIVE PROBE", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
