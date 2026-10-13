"""Probe the DEPLOYED Firestore rules for the assessment collections.

    python tool/assessment_rules_probe.py

Signs in two throwaway anonymous users (the same mechanism the app uses), gives
each a profile doc, and then tries the writes the rules are supposed to refuse.
Exits non-zero if any check fails, so it can gate a rules change.

Every assertion is about **production** rules, not a local emulator: this is
the ruleset the tablets actually talk to. Run it after any
`firebase deploy --only firestore:rules` that touches `assessments`,
`assessment_assignments` or `assessment_results` — a mistake there is silent
from inside the app, because AssessmentCloudService swallows sync failures by
design so a hiccup never interrupts a lesson.

The two anonymous users and every doc it writes are cleaned up on the way out;
the throwaway anonymous accounts are deleted too. Needs only the Python standard library.
"""

import json
import sys
import urllib.error
import urllib.request

API_KEY = "AIzaSyBpF2lz17uhYXaJkMClptVR8PhITbDHKoM"
PROJECT = "pwd-flashcard"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

results = []


def post(url, payload, token=None):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def fs_write(path, fields, token):
    """PATCH a document. Returns the HTTP status (200 ok, 403 refused)."""
    url = f"{FS}/{path}"
    data = json.dumps({"fields": fields}).encode()
    req = urllib.request.Request(url, data=data, method="PATCH")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def fs_read(path, token):
    req = urllib.request.Request(f"{FS}/{path}", method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def fs_delete(path, token):
    req = urllib.request.Request(f"{FS}/{path}", method="DELETE")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def s(v):
    return {"stringValue": v}


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
    r = post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
        {"returnSecureToken": True},
    )
    _accounts.append(r["idToken"])
    return r["localId"], r["idToken"]


def strings(d):
    return {"mapValue": {"fields": {k: s(v) for k, v in d.items()}}}


def main():
    uid_a, tok_a = signin_anon()
    uid_b, tok_b = signin_anon()
    uid_x, tok_x = signin_anon()
    print(f"teacher uid = {uid_a}\nlearner uid = {uid_b}\n")

    prof_a = f"rulesprobe-teacher-{uid_a[:8]}"
    prof_b = f"rulesprobe-learner-{uid_b[:8]}"
    prof_x = f"rulesprobe-stranger-{uid_x[:8]}"
    cls = f"rulesprobe-class-{uid_a[:8]}"
    code = f"P{uid_a[:5]}"
    assess = f"rulesprobe-assessment-{uid_a[:8]}"
    assign = f"rulesprobe-assignment-{uid_a[:8]}"
    result_b = f"rulesprobe-result-{uid_b[:8]}"

    # Each user owns their own profile — that is what ownsProfile() checks.
    check("teacher can create own profile",
          fs_write(f"profiles/{prof_a}", {"id": s(prof_a), "owner_uid": s(uid_a), "role": {"integerValue": "1"}},
                   tok_a), 200)
    check("learner can create own profile",
          fs_write(f"profiles/{prof_b}", {"id": s(prof_b), "owner_uid": s(uid_b), "role": {"integerValue": "0"},
                                          "classroom_id": s(cls)}, tok_b), 200)
    check("a stranger's device has a teacher profile of its own",
          fs_write(f"profiles/{prof_x}", {"id": s(prof_x), "owner_uid": s(uid_x), "role": {"integerValue": "1"}},
                   tok_x), 200)
    # Since 1.4.1 an assignment may name only learners on the setter's roster:
    # the teacher's class, the learner joining it with its code, the roster.
    check("teacher creates a class",
          fs_write(f"classrooms/{cls}", {"teacher_id": s(prof_a), "name": s("probe"), "code": s(code),
                                         "teacher_uid": s(uid_a)}, tok_a), 200)
    check("learner joins it with the code",
          fs_write(f"classroom_members/{cls}_{prof_b}", {"classroom_id": s(cls), "profile_id": s(prof_b),
                                                         "join_code": s(code)}, tok_b), 200)
    check("the teacher's device puts the learner on its roster",
          fs_write(f"educator_rosters/{uid_a}", {"learners": strings({prof_b: uid_b}),
                                                 "via": strings({prof_b: cls}), "learner": s(prof_b)}, tok_a), 200)

    # ── assessments ────────────────────────────────────────
    check("teacher can create their own assessment",
          fs_write(f"assessments/{assess}",
                   {"id": s(assess), "created_by_profile_id": s(prof_a), "owner_uid": s(uid_a)},
                   tok_a), 200)
    check("learner CANNOT create an assessment owned by the teacher",
          fs_write(f"assessments/rulesprobe-forged-{uid_b[:8]}",
                   {"id": s("forged"), "created_by_profile_id": s(prof_a), "owner_uid": s(uid_b)},
                   tok_b), 403)
    check("learner CANNOT overwrite the teacher's assessment",
          fs_write(f"assessments/{assess}",
                   {"id": s(assess), "created_by_profile_id": s(prof_a), "owner_uid": s(uid_b)},
                   tok_b), 403)
    check("learner CAN read the assessment assigned to them",
          fs_read(f"assessments/{assess}", tok_b), 200)
    check("learner CANNOT delete the teacher's assessment",
          fs_delete(f"assessments/{assess}", tok_b), 403)

    # ── assignments ────────────────────────────────────────
    # Since 2026-10-04 a learner finds their work by their device's uid
    # (`student_uids`), as the app has written it since 1.2.2.
    check("teacher can create their own assignment",
          fs_write(f"assessment_assignments/{assign}",
                   {"id": s(assign), "assignedBy": s(prof_a), "owner_uid": s(uid_a),
                    "studentIds": {"arrayValue": {"values": [s(prof_b)]}},
                    "student_uids": {"arrayValue": {"values": [s(uid_b)]}}},
                   tok_a), 200)
    check("learner CANNOT assign work to themselves as the teacher",
          fs_write(f"assessment_assignments/rulesprobe-selfassign-{uid_b[:8]}",
                   {"id": s("selfassign"), "assignedBy": s(prof_a), "owner_uid": s(uid_b),
                    "studentIds": {"arrayValue": {"values": [s(prof_b)]}}},
                   tok_b), 403)
    check("learner CANNOT edit the teacher's assignment (e.g. drop themselves)",
          fs_write(f"assessment_assignments/{assign}",
                   {"id": s(assign), "assignedBy": s(prof_a), "owner_uid": s(uid_a),
                    "studentIds": {"arrayValue": {"values": []}}},
                   tok_b), 403)
    check("learner CAN read the assignment naming them",
          fs_read(f"assessment_assignments/{assign}", tok_b), 200)
    check("a stranger CANNOT set the learner a test (not on their roster)",
          fs_write(f"assessment_assignments/rulesprobe-stranger-{uid_x[:8]}",
                   {"id": s("stranger"), "assignedBy": s(prof_x), "owner_uid": s(uid_x),
                    "studentIds": {"arrayValue": {"values": [s(prof_b)]}},
                    "student_uids": {"arrayValue": {"values": [s(uid_b)]}}},
                   tok_x), 403)
    check("... nor address one to the learner's device alone",
          fs_write(f"assessment_assignments/rulesprobe-stranger2-{uid_x[:8]}",
                   {"id": s("stranger2"), "assignedBy": s(prof_x), "owner_uid": s(uid_x),
                    "studentIds": {"arrayValue": {"values": []}},
                    "student_uids": {"arrayValue": {"values": [s(uid_b)]}}},
                   tok_x), 403)
    check("a stranger CANNOT put the learner on their own roster",
          fs_write(f"educator_rosters/{uid_x}", {"learners": strings({prof_b: uid_b}),
                                                 "via": strings({prof_b: cls}), "learner": s(prof_b)}, tok_x), 403)

    # ── results: the asymmetry that makes tracking trustworthy ──
    check("learner can submit their own result",
          fs_write(f"assessment_results/{result_b}",
                   {"id": s(result_b), "profileId": s(prof_b), "assessmentId": s(assess),
                    "owner_uid": s(uid_b), "score": {"integerValue": "1"}},
                   tok_b), 200)
    check("teacher CAN read the learner's result",
          fs_read(f"assessment_results/{result_b}", tok_a), 200)
    check("a stranger CANNOT read the learner's result",
          fs_read(f"assessment_results/{result_b}", tok_x), 403)
    check("teacher CANNOT forge a result for the learner",
          fs_write(f"assessment_results/rulesprobe-forged-result-{uid_a[:8]}",
                   {"id": s("forged"), "profileId": s(prof_b), "assessmentId": s(assess),
                    "owner_uid": s(uid_a), "score": {"integerValue": "99"}},
                   tok_a), 403)
    check("teacher CANNOT alter the learner's submitted score",
          fs_write(f"assessment_results/{result_b}",
                   {"id": s(result_b), "profileId": s(prof_b), "assessmentId": s(assess),
                    "owner_uid": s(uid_b), "score": {"integerValue": "0"}},
                   tok_a), 403)
    check("teacher CANNOT delete the learner's result",
          fs_delete(f"assessment_results/{result_b}", tok_a), 403)
    check("learner CAN delete their own result (profile-deletion cleanup)",
          fs_delete(f"assessment_results/{result_b}", tok_b), 200)

    # ── cleanup ────────────────────────────────────────────
    # The stranger's writes are refused under the rules this checks; run
    # against older rules they land, so they are removed too.
    for doc in (f"rulesprobe-stranger-{uid_x[:8]}", f"rulesprobe-stranger2-{uid_x[:8]}"):
        fs_delete(f"assessment_assignments/{doc}", tok_x)
    fs_delete(f"educator_rosters/{uid_x}", tok_x)
    fs_delete(f"assessment_assignments/{assign}", tok_a)
    fs_delete(f"assessments/{assess}", tok_a)
    fs_delete(f"educator_rosters/{uid_a}", tok_a)
    fs_delete(f"classroom_members/{cls}_{prof_b}", tok_b)
    fs_delete(f"classrooms/{cls}", tok_a)
    fs_delete(f"profiles/{prof_a}", tok_a)
    fs_delete(f"profiles/{prof_b}", tok_b)
    fs_delete(f"profiles/{prof_x}", tok_x)

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
