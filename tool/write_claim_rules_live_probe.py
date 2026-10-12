"""Checks the LIVE create rules on a throwaway learner of its own, then deletes it.

    python tool/write_claim_rules_live_probe.py

Signs in anonymously twice, like two copies of the app ("owner" and
"stranger"). The owner puts a throwaway profile in the cloud; the stranger
tries to start that learner's progress, study logs and daily keys first (the
hole closed 2026-10-12) and must be refused; the owner must still be able to
start them. Real learners are never named or touched. Everything the probe
wrote, and both anonymous accounts, are deleted at the end, also when a check
fails.
"""
import json, sys, urllib.error, urllib.request, uuid

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = "pwd-flashcard"
API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"  # the app's public client key
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
AUTH = "https://identitytoolkit.googleapis.com/v1/accounts"


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


def sign_in():
    st, auth = call("POST", f"{AUTH}:signUp?key={API_KEY}", {"returnSecureToken": True})
    assert st == 200, (st, auth)
    return auth["idToken"], auth["localId"]


def fields(d):
    return {"fields": {k: ({"stringValue": v} if isinstance(v, str) else {"integerValue": str(v)})
                       for k, v in d.items()}}


def create(token, path, data):
    st, _ = call("PATCH", f"{FS}/{path}?currentDocument.exists=false", fields(data), token)
    return st


def main():
    owner, owner_uid = sign_in()
    stranger, stranger_uid = sign_in()
    pid = f"rules-probe-{uuid.uuid4()}"
    written = []  # (token, path) for cleanup
    results = []

    def expect(label, status, allowed, token=None, path=None):
        ok = (status == 200) if allowed else (status == 403)
        results.append((ok, label, status))
        if status == 200 and token and path:
            written.append((token, path))

    try:
        st = create(owner, f"profiles/{pid}",
                    {"owner_uid": owner_uid, "name": "rules probe (deleted at once)", "role": 2})
        assert st == 200, ("could not create the throwaway profile", st)
        written.append((owner, f"profiles/{pid}"))

        expect("stranger starts the learner's progress",
               create(stranger, f"progress/{pid}", {"owner_uid": stranger_uid, "stars": 999}),
               False, stranger, f"progress/{pid}")
        log_id = f"rules-probe-{uuid.uuid4()}"
        expect("stranger files a study log for the learner",
               create(stranger, f"session_logs/{log_id}",
                      {"owner_uid": stranger_uid, "profile_id": pid}),
               False, stranger, f"session_logs/{log_id}")
        expect("stranger claims the learner's daily challenge",
               create(stranger, f"app_state/daily_challenge_{pid}",
                      {"owner_uid": stranger_uid, "value": "x"}),
               False, stranger, f"app_state/daily_challenge_{pid}")

        expect("owner starts its own progress",
               create(owner, f"progress/{pid}", {"owner_uid": owner_uid, "stars": 1}),
               True, owner, f"progress/{pid}")
        log_id = f"rules-probe-{uuid.uuid4()}"
        expect("owner files its own study log",
               create(owner, f"session_logs/{log_id}",
                      {"owner_uid": owner_uid, "profile_id": pid}),
               True, owner, f"session_logs/{log_id}")
        expect("owner starts its tutorial flag",
               create(owner, f"app_state/tutorial_seen_{pid}",
                      {"owner_uid": owner_uid, "value": "true"}),
               True, owner, f"app_state/tutorial_seen_{pid}")
    finally:
        # Children before the profile: some rules read the profile.
        for token, path in sorted(written, key=lambda w: w[1].startswith("profiles/")):
            st, body = call("DELETE", f"{FS}/{path}", token=token)
            if st != 200:
                print(f"  cleanup FAILED {path}: {st} {body}")
        for token in (owner, stranger):
            call("POST", f"{AUTH}:delete?key={API_KEY}", {"idToken": token})

    for ok, label, status in results:
        print(f"  {'ok  ' if ok else 'FAIL'} {label} -> {status}")
    failed = [r for r in results if not r[0]]
    print(f"{len(results) - len(failed)} passed, {len(failed)} failed; "
          f"cleaned up {len(written)} document(s) and 2 anonymous accounts")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
