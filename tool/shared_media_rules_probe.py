"""Probe the DEPLOYED Firestore rules for shared media.

    python tool/shared_media_rules_probe.py

`shared_media/{id}` and its `chunks` hold the pictures, videos and learner
video answers shared between tablets (SharedMediaService) — on the free Spark
plan, in place of Cloud Storage. This signs in two throwaway anonymous users
(the same mechanism the app uses) and checks that a file can only be shared
for a profile the sharing device owns, that only that profile's device may
write or delete it (and the uploading device once the profile is gone), that
anyone signed in can read it, and that the size limits which keep one upload
from eating the free quota hold.

Runs against **production** rules. Every doc it writes is removed on the way
out; the throwaway anonymous accounts are deleted too. Standard library only.
"""

import base64
import json
import sys
import urllib.error
import urllib.request

API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"
PROJECT = "pwd-flashcard"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

results = []


def call(method, path, token, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(f"{FS}/{path}", data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def write(path, fields, token):
    return call("PATCH", path, token, {"fields": fields})


def read(path, token):
    return call("GET", path, token)


def delete(path, token):
    return call("DELETE", path, token)


def s(v):
    return {"stringValue": v}


def i(v):
    return {"integerValue": str(v)}


def b(n):
    return {"bytesValue": base64.b64encode(b"\x01" * n).decode()}


def meta(uid, profile, size=4, chunks=1, status="uploading"):
    return {
        "owner_uid": s(uid),
        "owner_profile_id": s(profile),
        "ext": s("mp4"),
        "size": i(size),
        "chunk_count": i(chunks),
        "sha256": s("x"),
        "status": s(status),
    }


def check(name, got, want):
    ok = got == want
    results.append((ok, name, got, want))
    print(("PASS " if ok else "FAIL ") + f"{name} (got {got}, want {want})")


# Every throwaway account this run signs in, deleted again on the way out.
_accounts = []


def delete_anon_accounts():
    """Delete the probe's anonymous accounts. An account may always delete
    itself with its own token, so this needs no admin access, and a run
    leaves nothing behind in Authentication either."""
    removed = 0
    for token in _accounts:
        req = urllib.request.Request(
            f"https://identitytoolkit.googleapis.com/v1/accounts:delete?key={API_KEY}",
            data=json.dumps({"idToken": token}).encode(),
            method="POST",
        )
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                if r.status == 200:
                    removed += 1
        except urllib.error.HTTPError:
            pass
    print(f"cleanup: {removed}/{len(_accounts)} throwaway accounts deleted")


def signin_anon():
    req = urllib.request.Request(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
        data=json.dumps({"returnSecureToken": True}).encode(),
        method="POST",
    )
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as r:
        body = json.loads(r.read())
    _accounts.append(body["idToken"])
    return body["localId"], body["idToken"]


def main():
    uid_a, tok_a = signin_anon()
    uid_b, tok_b = signin_anon()
    print(f"uploader uid = {uid_a}\nother uid    = {uid_b}\n")

    media = f"shared_media/rulesprobe-{uid_a[:8]}"
    chunk = f"{media}/chunks/0"
    # A throwaway profile owned by device A — files are shared AS a profile.
    profile_a = f"rulesprobe-profile-{uid_a[:8]}"
    check("device A can create its profile",
          write(f"profiles/{profile_a}", {"owner_uid": s(uid_a), "name": s("probe")}, tok_a), 200)

    # ── the metadata document ─────────────────────────────
    check("uploader can create a file's metadata", write(media, meta(uid_a, profile_a), tok_a), 200)
    check("another device CANNOT create metadata in the uploader's name",
          write(f"shared_media/rulesprobe-forged-{uid_b[:8]}", meta(uid_a, profile_a), tok_b), 403)
    check("a device CANNOT share a file for a profile it does not own",
          write(f"shared_media/rulesprobe-notmine-{uid_b[:8]}", meta(uid_b, profile_a), tok_b), 403)
    check("a device CANNOT share a file for a profile that does not exist",
          write(f"shared_media/rulesprobe-noprofile-{uid_a[:8]}",
                meta(uid_a, f"rulesprobe-missing-{uid_a[:8]}"), tok_a), 403)
    check("a file over 15 MB is refused",
          write(f"shared_media/rulesprobe-big-{uid_a[:8]}",
                meta(uid_a, profile_a, size=15728641, chunks=17), tok_a), 403)
    check("more than 17 pieces is refused",
          write(f"shared_media/rulesprobe-many-{uid_a[:8]}",
                meta(uid_a, profile_a, size=100, chunks=18), tok_a), 403)

    # ── the pieces ────────────────────────────────────────
    check("uploader can write a piece", write(chunk, {"i": i(0), "data": b(4)}, tok_a), 200)
    check("another device CANNOT write a piece into the uploader's file",
          write(f"{media}/chunks/1", {"i": i(1), "data": b(4)}, tok_b), 403)
    check("a piece over 1,000,000 bytes is refused",
          write(f"{media}/chunks/2", {"i": i(2), "data": b(1000001)}, tok_a), 403)
    check("a piece that is not bytes is refused",
          write(f"{media}/chunks/3", {"i": i(3), "data": s("not bytes")}, tok_a), 403)

    # ── reading ───────────────────────────────────────────
    check("another signed-in device CAN read the metadata", read(media, tok_b), 200)
    check("another signed-in device CAN read a piece", read(chunk, tok_b), 200)

    # ── changing and deleting ─────────────────────────────
    check("uploader CANNOT change the recorded size",
          write(media, meta(uid_a, profile_a, size=999), tok_a), 403)
    check("uploader CANNOT hand the file to another profile",
          write(media, meta(uid_a, f"rulesprobe-other-{uid_a[:8]}", status="ready"), tok_a), 403)
    check("uploader can mark the file ready",
          write(media, meta(uid_a, profile_a, status="ready"), tok_a), 200)
    check("another device CANNOT delete a piece", delete(chunk, tok_b), 403)
    check("another device CANNOT delete the metadata", delete(media, tok_b), 403)
    check("the profile's device can delete a piece", delete(chunk, tok_a), 200)
    check("the profile's device can delete the metadata", delete(media, tok_a), 200)

    # ── a deleted profile's leftovers ─────────────────────
    left = f"shared_media/rulesprobe-left-{uid_a[:8]}"
    check("uploader can share a second file", write(left, meta(uid_a, profile_a), tok_a), 200)
    check("uploader can write its piece", write(f"{left}/chunks/0", {"i": i(0), "data": b(4)}, tok_a), 200)
    check("device A can delete its profile", delete(f"profiles/{profile_a}", tok_a), 200)
    check("once the profile is gone, another device still CANNOT delete its file",
          delete(left, tok_b), 403)
    check("once the profile is gone, the uploading device can delete a piece",
          delete(f"{left}/chunks/0", tok_a), 200)
    check("once the profile is gone, the uploading device can delete the file",
          delete(left, tok_a), 200)

    failed = [r for r in results if not r[0]]
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed")
    if failed:
        print("\nFAILURES:")
        for _, name, got, want in failed:
            print(f"  - {name}: got {got}, want {want}")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    finally:
        delete_anon_accounts()
