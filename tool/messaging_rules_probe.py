"""Probe the DEPLOYED Firestore rules for Messages: blocking and parent approval.

    python tool/messaging_rules_probe.py

Checks, against production rules, that

  * a message or friend request from someone the recipient has **blocked** is
    refused by the server (a block used to be a client-side filter only);
  * the blocker can still write, and an unblock lets messages through again;
  * a teacher's "message the whole class" — sent in batches of 8, as the app
    does — fits inside the per-batch lookup limit;
  * no one gets round a block by editing their own profile's role, and a block
    cannot be filed under someone else's pair;
  * a friendship with a Child is refused until their parent has said yes;
  * only the **real parent** of a Child (the owner of the home group the child
    is actually a member of) can approve or decline that child's friend
    request, and only the approval fields can change that way.

Signs in throwaway anonymous users (the same mechanism the app uses) and
creates throwaway profiles, a home group and requests. Every document it
writes is deleted on the way out; the throwaway anonymous accounts
are deleted too. Standard library only.
"""

import base64
import json
import sys
import urllib.error
import urllib.request
import uuid

API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"
PROJECT = "pwd-flashcard"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
FS = f"https://firestore.googleapis.com/v1/{ROOT}"

results = []
created = []  # (path, token) to delete at the end, newest last


def call(method, url, token, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def write(path, fields, token, track=True, mask=None):
    url = f"{FS}/{path}"
    if mask:
        url += "?" + "&".join(f"updateMask.fieldPaths={m}" for m in mask)
    status = call("PATCH", url, token, {"fields": fields})
    if status == 200 and track and all(p != path for p, _ in created):
        created.append((path, token))
    return status


def delete(path, token):
    return call("DELETE", f"{FS}/{path}", token)


def commit(writes, token):
    return call("POST", f"{FS}:commit", token, {"writes": writes})


def s(v):
    return {"stringValue": v}


def i(v):
    return {"integerValue": str(v)}


def bo(v):
    return {"booleanValue": v}


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


def profile(tag, uid, tok, role):
    pid = f"rulesprobe-{tag}-{uid[:8]}"
    check(f"{tag}: can create its profile",
          write(f"profiles/{pid}", {"owner_uid": s(uid), "name": s(tag), "role": i(role)}, tok), 200)
    return pid


def message(sender, recipient, uid, tok, mid=None):
    mid = mid or f"rulesprobe-msg-{uuid.uuid4().hex[:12]}"
    return f"messages/{mid}", {
        "id": s(mid),
        "sender_profile_id": s(sender),
        "recipient_profile_id": s(recipient),
        "sender_name": s("probe"),
        "content": s("hello"),
        "type": i(0),
        "timestamp": s("2026-09-26T00:00:00.000"),
        "sender_uid": s(uid),
        "is_read": bo(False),
    }


def request(frm, to, uid, extra=None):
    fields = {
        "id": s(f"{frm}_{to}"),
        "from_profile_id": s(frm),
        "to_profile_id": s(to),
        "from_owner_uid": s(uid),
        "from_display_name": s("probe"),
        "status": s("pending"),
        "created_at": s("2026-09-26T00:00:00.000"),
    }
    fields.update(extra or {})
    return f"friend_requests/{frm}_{to}", fields


def main():
    users = {k: signin_anon() for k in ["learner", "blocker", "teacher", "parent", "child", "stranger", "parent2"]}
    uid = {k: v[0] for k, v in users.items()}
    tok = {k: v[1] for k, v in users.items()}

    learner = profile("learner", uid["learner"], tok["learner"], 0)
    blocker = profile("blocker", uid["blocker"], tok["blocker"], 0)
    teacher = profile("teacher", uid["teacher"], tok["teacher"], 1)
    parent = profile("parent", uid["parent"], tok["parent"], 2)
    child = profile("child", uid["child"], tok["child"], 3)
    parent2 = profile("parent2", uid["parent2"], tok["parent2"], 2)
    stranger = profile("stranger", uid["stranger"], tok["stranger"], 0)

    # ── blocking ─────────────────────────────────────────
    p, f = message(learner, blocker, uid["learner"], tok["learner"])
    check("a message goes through before any block", write(p, f, tok["learner"]), 200)

    block = f"blocks/{blocker}_{learner}"
    check("the blocker can block", write(block, {
        "blocker_profile_id": s(blocker), "blocked_profile_id": s(learner),
        "blocker_uid": s(uid["blocker"]), "created_at": s("2026-09-26"),
    }, tok["blocker"]), 200)

    p, f = message(learner, blocker, uid["learner"], tok["learner"])
    check("a BLOCKED sender's message is refused", write(p, f, tok["learner"]), 403)
    p, f = message(blocker, learner, uid["blocker"], tok["blocker"])
    check("the blocker can still send", write(p, f, tok["blocker"]), 200)
    p, f = request(learner, blocker, uid["learner"])
    check("a BLOCKED sender's friend request is refused", write(p, f, tok["learner"]), 403)
    p, f = message(learner, child, uid["learner"], tok["learner"])
    check("a block on one person does not stop messages to others", write(p, f, tok["learner"]), 200)

    # No exemption by role: a profile's owner can edit their own `role`, so a
    # "teachers skip the check" rule would be a way round any block.
    tblock = f"blocks/{blocker}_{teacher}"
    check("the blocker can block a teacher profile too", write(tblock, {
        "blocker_profile_id": s(blocker), "blocked_profile_id": s(teacher),
        "blocker_uid": s(uid["blocker"]), "created_at": s("x"),
    }, tok["blocker"]), 200)
    p, f = message(teacher, blocker, uid["teacher"], tok["teacher"])
    check("a blocked profile is refused even with a teacher role", write(p, f, tok["teacher"]), 403)
    check("(unblock the teacher again)", delete(tblock, tok["blocker"]), 200)
    created[:] = [c for c in created if c[0] != tblock]

    # A block must be filed under its own pair: hasBlocked() reads it by id.
    check("a block filed under SOMEONE ELSE'S pair is refused",
          write(f"blocks/{child}_{learner}", {
              "blocker_profile_id": s(stranger), "blocked_profile_id": s(learner),
              "blocker_uid": s(uid["stranger"]), "created_at": s("x"),
          }, tok["stranger"]), 403)
    check("a block whose id does not match its contents is refused",
          write(f"blocks/{stranger}_{child}", {
              "blocker_profile_id": s(stranger), "blocked_profile_id": s(learner),
              "blocker_uid": s(uid["stranger"]), "created_at": s("x"),
          }, tok["stranger"]), 403)

    check("the blocker can unblock", delete(block, tok["blocker"]), 200)
    created[:] = [c for c in created if c[0] != block]
    p, f = message(learner, blocker, uid["learner"], tok["learner"])
    check("after an unblock, messages go through again", write(p, f, tok["learner"]), 200)

    # ── a class broadcast: 24 messages in batches of 8 (the app's size) ──
    for batch_no in range(3):
        writes = []
        for n in range(8):
            p, f = message(teacher, f"rulesprobe-kid{batch_no}{n}-{uid['teacher'][:8]}",
                           uid["teacher"], tok["teacher"])
            writes.append({"update": {"name": f"{ROOT}/{p}", "fields": f},
                           "currentDocument": {"exists": False}})
        status = commit(writes, tok["teacher"])
        check(f"a teacher's broadcast batch {batch_no + 1} of 8 messages is accepted", status, 200)
        if status == 200:
            created.extend((w["update"]["name"].split("/documents/")[1], tok["teacher"]) for w in writes)
    # A learner's report goes to two grown-ups in one batch.
    writes = []
    for rec in [teacher, parent]:
        p, f = message(learner, rec, uid["learner"], tok["learner"])
        writes.append({"update": {"name": f"{ROOT}/{p}", "fields": f}, "currentDocument": {"exists": False}})
    status = commit(writes, tok["learner"])
    check("a learner's two-recipient report batch is accepted", status, 200)
    if status == 200:
        created.extend((w["update"]["name"].split("/documents/")[1], tok["learner"]) for w in writes)

    # ── parent approval ──────────────────────────────────
    group = f"rulesprobe-group-{uid['parent'][:8]}"
    group2 = f"rulesprobe-group2-{uid['parent2'][:8]}"
    check("parent can create a home group",
          write(f"home_groups/{group}", {"owner_profile_id": s(parent), "name": s("probe"), "code": s("PRB001")}, tok["parent"]), 200)
    check("parent2 can create a home group",
          write(f"home_groups/{group2}", {"owner_profile_id": s(parent2), "name": s("probe2"), "code": s("PRB002")}, tok["parent2"]), 200)
    member = f"home_group_members/{group}_{child}"
    check("the child can join the parent's group",
          write(member, {"home_group_id": s(group), "profile_id": s(child), "display_name": s("child"),
                         "joined_at": s("2026-09-26")}, tok["child"]), 200)

    # Child → learner: the child's side needs the parent.
    req, f = request(child, learner, uid["child"], {"from_home_group_id": s(group)})
    check("a child can send a request tagged with their home group", write(req, f, tok["child"]), 200)
    check("the recipient can accept into awaiting_parent",
          write(req, {"status": s("awaiting_parent"), "updated_at": s("x")}, tok["learner"], mask=["status", "updated_at"]), 200)
    check("the CHILD cannot approve their own request",
          write(req, {"from_approved": bo(True)}, tok["child"], mask=["from_approved"]), 403)
    check("a stranger cannot approve",
          write(req, {"from_approved": bo(True)}, tok["stranger"], mask=["from_approved"]), 403)
    check("another parent cannot approve",
          write(req, {"from_approved": bo(True)}, tok["parent2"], mask=["from_approved"]), 403)
    check("the parent cannot approve the OTHER side",
          write(req, {"to_approved": bo(True)}, tok["parent"], mask=["to_approved"]), 403)
    check("the parent cannot change who the request is for",
          write(req, {"to_profile_id": s(teacher)}, tok["parent"], mask=["to_profile_id"]), 403)
    check("the parent cannot mark it accepted",
          write(req, {"status": s("accepted")}, tok["parent"], mask=["status"]), 403)
    check("the real parent CAN approve",
          write(req, {"from_approved": bo(True), "updated_at": s("y")}, tok["parent"],
                mask=["from_approved", "updated_at"]), 200)
    check("then a learner device can finish it (status accepted)",
          write(req, {"status": s("accepted"), "updated_at": s("z")}, tok["learner"], mask=["status", "updated_at"]), 200)
    lo, hi = sorted([child, learner])
    friendship = f"friendships/{lo}_{hi}"
    check("with the parent's yes, the child's device can write the friendship",
          write(friendship, {"id": s(f"{lo}_{hi}"), "profile_a": s(lo), "profile_b": s(hi),
                             "created_at": s("x"), "request_id": s(req.split("/")[1])}, tok["child"]), 200)
    check("(and remove it again)", delete(friendship, tok["child"]), 200)
    created[:] = [c for c in created if c[0] != friendship]

    # Without the parent's yes the server now refuses the friendship itself.
    req_x, f = request(child, stranger, uid["child"], {"from_home_group_id": s(group)})
    check("a child asks another learner", write(req_x, f, tok["child"]), 200)
    check("the learner says yes (awaiting_parent)",
          write(req_x, {"status": s("awaiting_parent")}, tok["stranger"], mask=["status"]), 200)
    lo, hi = sorted([child, stranger])
    check("a child CANNOT write the friendship before the parent says yes",
          write(f"friendships/{lo}_{hi}", {"id": s(f"{lo}_{hi}"), "profile_a": s(lo), "profile_b": s(hi),
                "created_at": s("x"), "request_id": s(req_x.split("/")[1])}, tok["child"]), 403)
    check("nor with no request named at all",
          write(f"friendships/{lo}_{hi}", {"id": s(f"{lo}_{hi}"), "profile_a": s(lo), "profile_b": s(hi),
                "created_at": s("x")}, tok["child"]), 403)
    check("nor from the other learner's device",
          write(f"friendships/{lo}_{hi}", {"id": s(f"{lo}_{hi}"), "profile_a": s(lo), "profile_b": s(hi),
                "created_at": s("x"), "request_id": s(req_x.split("/")[1])}, tok["stranger"]), 403)
    lo, hi = sorted([learner, blocker])
    check("two ordinary learners still become friends as before (no request needed)",
          write(f"friendships/{lo}_{hi}", {"id": s(f"{lo}_{hi}"), "profile_a": s(lo), "profile_b": s(hi),
                "created_at": s("x")}, tok["learner"]), 200)

    # Learner → child: the child stamps their group when accepting.
    req2, f = request(learner, child, uid["learner"])
    check("a learner can ask a child", write(req2, f, tok["learner"]), 200)
    check("the child accepts, stamping their home group",
          write(req2, {"status": s("awaiting_parent"), "to_home_group_id": s(group), "updated_at": s("x")},
                tok["child"], mask=["status", "to_home_group_id", "updated_at"]), 200)
    check("the child's parent can approve the to-side",
          write(req2, {"to_approved": bo(True)}, tok["parent"], mask=["to_approved"]), 200)

    # A request tagged with a group the child is NOT in gets nobody's approval.
    req3, f = request(child, blocker, uid["child"], {"from_home_group_id": s(group2)})
    check("a child can tag a group they are not in (harmless)", write(req3, f, tok["child"]), 200)
    check("that group's owner still CANNOT approve (no membership)",
          write(req3, {"from_approved": bo(True)}, tok["parent2"], mask=["from_approved"]), 403)
    check("that group's owner CANNOT decline it either",
          write(req3, {"status": s("parent_declined")}, tok["parent2"], mask=["status"]), 403)

    req4, f = request(child, teacher, uid["child"], {"from_home_group_id": s(group)})
    check("a child can ask someone else", write(req4, f, tok["child"]), 200)
    check("the parent can decline it",
          write(req4, {"status": s("parent_declined"), "updated_at": s("d")}, tok["parent"],
                mask=["status", "updated_at"]), 200)

    # ── clean up (children first) ────────────────────────
    owner_of = {tok[k]: k for k in tok}
    bad = 0
    for path, t in reversed(created):
        # Requests are deletable by their sender only.
        status = delete(path, t)
        if status != 200:
            bad += 1
            print(f"cleanup: could not delete {path} as {owner_of.get(t)} ({status})")
    print(f"\ncleanup: {len(created) - bad}/{len(created)} documents removed")

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
