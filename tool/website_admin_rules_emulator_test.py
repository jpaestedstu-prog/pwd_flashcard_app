"""Security-rules test for the WEBSITE's Firebase project (website_admin/firestore.rules),
run against the LOCAL Firestore emulator.

    cd website_admin
    firebase emulators:start --only firestore --project demo-flashlearn-site
    python tool/website_admin_rules_emulator_test.py

Never touches a real project: the target is a `demo-` project on 127.0.0.1:8080,
seeded with the emulator's own "owner" token. The public website writes WITHOUT
signing in, so most checks send no token at all; administrators are unsigned
emulator tokens with a chosen sign-in provider.

What it pins: a visitor can only add one to known tallies for today and send a
well-formed rating or message, never read anything back; only a Google or
email sign-in listed in admins/ reads, and even an administrator cannot rewrite
what a visitor sent or forge tallies.
"""
import base64, datetime, json, sys, time, urllib.error, urllib.request

PROJECT = "demo-flashlearn-site"
BASE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
ROOT = f"projects/{PROJECT}/databases/(default)/documents"
sys.stdout.reconfigure(encoding="utf-8")

ADMIN, GOOGLE_ADMIN, ANON_LISTED, STRANGER = "admin-pw", "admin-google", "anon-listed", "stranger-pw"
PROVIDER = {ADMIN: "password", GOOGLE_ADMIN: "google.com", ANON_LISTED: "anonymous", STRANGER: "password"}


def token(uid):
    enc = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
    now = int(time.time())
    return enc({"alg": "none", "typ": "JWT"}) + "." + enc({
        "sub": uid, "user_id": uid, "iat": now, "exp": now + 3600, "auth_time": now,
        "iss": f"https://securetoken.google.com/{PROJECT}", "aud": PROJECT,
        "firebase": {"sign_in_provider": PROVIDER[uid], "identities": {}}}) + "."


def req(method, url, body=None, as_=None):
    """as_=None: the public website (no token). "owner": the emulator's bypass."""
    headers = {"Content-Type": "application/json"}
    if as_ == "owner":
        headers["Authorization"] = "Bearer owner"
    elif as_:
        headers["Authorization"] = "Bearer " + token(as_)
    r = urllib.request.Request(url, method=method, headers=headers,
                               data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def val(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: val(x) for k, x in v.items()}}}
    return {"stringValue": v}


def commit(writes, as_=None):
    return req("POST", f"{BASE}:commit", {"writes": writes}, as_)[0]


def bump(path, keys, as_=None, by=1, extra=None):
    """What site.js sends: add `by` to each key (merge), optionally setting plain fields."""
    extra = extra or {}
    return commit([{"update": {"name": f"{ROOT}/{path}", "fields": {k: val(v) for k, v in extra.items()}},
                    "updateMask": {"fieldPaths": list(extra)},
                    "updateTransforms": [{"fieldPath": k, "increment": {"integerValue": str(by)}} for k in keys]}],
                  as_)


def patch(path, fields, as_=None, mask=None):
    """A plain merge write of literal values (what a forger would send)."""
    w = {"update": {"name": f"{ROOT}/{path}", "fields": {k: val(v) for k, v in fields.items()}},
         "updateMask": {"fieldPaths": mask if mask is not None else list(fields)}}
    return commit([w], as_)


def send(doc_id, fields, as_=None, server_time=True):
    """What the feedback form sends: create-only, `created` stamped by the server."""
    w = {"update": {"name": f"{ROOT}/feedback/{doc_id}", "fields": {k: val(v) for k, v in fields.items()}},
         "currentDocument": {"exists": False}}
    if server_time:
        w["updateTransforms"] = [{"fieldPath": "created", "setToServerValue": "REQUEST_TIME"}]
    return commit([w], as_)


def get(path, as_=None):
    return req("GET", f"{BASE}/{path}", None, as_)


def run_query(collection, as_=None):
    return req("POST", f"{BASE}:runQuery", {"structuredQuery": {"from": [{"collectionId": collection}]}}, as_)[0]


def manila_day(offset_days=0):
    now = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=8, days=offset_days)
    return now.strftime("%Y-%m-%d")


def num(doc, key):
    f = doc["fields"].get(key)
    return None if f is None else int(f.get("integerValue", -1))


results = []


def check(label, ok):
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + label)


ALL_TALLIES = [
    "v", "u", "n",
    "p_index", "p_try", "p_download", "p_how_to_use", "p_games", "p_fsl_dictionary",
    "p_teachers_guide", "p_faq", "p_awareness", "p_about", "p_privacy", "p_gaze_control", "p_other",
    "l_en", "l_fil", "d_phone", "d_tablet", "d_computer",
    "s_direct", "s_search", "s_social", "s_github", "s_qr", "s_other",
    "a_text", "a_dys", "a_hc", "a_still", "o_motion", "o_dark", "o_contrast",
    "e_apk_arm64", "e_apk_arm32", "e_apk_universal", "e_webapp",
    "e_try_card", "e_try_game", "e_film", "e_demo",
]

GOOD_MSG = {"type": "idea", "role": "teacher", "message": "Please add more Filipino words.",
            "page": "faq", "lang": "en", "status": "new", "rating": 5, "device": "Galaxy Tab A9"}


def main():
    req("DELETE", f"http://127.0.0.1:8080/emulator/v1/projects/{PROJECT}/databases/(default)/documents")
    for uid in (ADMIN, GOOGLE_ADMIN, ANON_LISTED):
        req("PATCH", f"{BASE}/admins/{uid}", {"fields": {"name": val(uid)}}, "owner")

    today = manila_day()
    day = f"daily/{today}"

    # ---- Visit tallies, from the public website (no sign-in) ----
    first_view = ["v", "u", "n", "p_index", "l_en", "s_direct", "d_phone", "a_text", "a_dys",
                  "a_hc", "a_still", "o_motion", "o_dark", "o_contrast"]
    check("a first page view of the day creates today's tallies (14 at once)",
          bump(day, first_view) == 200)
    check("a later page view adds one more", bump(day, ["v", "p_faq", "l_fil"]) == 200)
    st, doc = get(day, "owner")
    check("the tallies say what was sent (v=2, p_faq=1)",
          st == 200 and num(doc, "v") == 2 and num(doc, "p_faq") == 1 and num(doc, "u") == 1)
    check("an event click adds one (download)", bump(day, ["e_apk_arm64"]) == 200)
    check("every tally the website uses is accepted",
          all(bump(day, ALL_TALLIES[i:i + 14]) == 200 for i in range(0, len(ALL_TALLIES), 14)))
    check("a jump of two is refused", bump(day, ["v"], by=2) == 403)
    check("going backwards is refused", bump(day, ["v"], by=-1) == 403)
    check("an unknown tally name is refused", bump(day, ["v", "x_hack"]) == 403)
    check("more than 16 tallies in one write are refused", bump(day, ALL_TALLIES[:17]) == 403)
    check("writing a number instead of adding one is refused", patch(day, {"v": 99999}) == 403)
    check("a text value is refused", patch(day, {"p_other": "spam"}) == 403)
    check("removing a tally is refused", patch(day, {}, mask=["v"]) == 403)
    check("a day three days ago is refused", bump(f"daily/{manila_day(-3)}", ["v"]) == 403)
    check("a day three days ahead is refused", bump(f"daily/{manila_day(3)}", ["v"]) == 403)
    check("a made-up day name is refused", bump("daily/all-time", ["v"]) == 403)
    check("the public cannot delete a day",
          commit([{"delete": f"{ROOT}/{day}"}]) == 403)
    check("the public cannot read a day", get(day)[0] == 403)
    check("the public cannot list the days", run_query("daily") == 403)
    check("an administrator cannot forge tallies either", bump(day, ["v"], ADMIN, by=5) == 403)

    # ---- FSL sign plays ----
    sday = f"signs/{today}"
    check("a sign play creates today's sign tallies",
          bump(sday, ["w_thank_you"], extra={"last": "w_thank_you"}) == 200)
    check("the same sign again adds one", bump(sday, ["w_thank_you"], extra={"last": "w_thank_you"}) == 200)
    check("another sign adds its own counter", bump(sday, ["w_dog"], extra={"last": "w_dog"}) == 200)
    st, doc = get(sday, "owner")
    check("the sign tallies say what was sent", st == 200 and num(doc, "w_thank_you") == 2 and num(doc, "w_dog") == 1)
    check("two signs in one write are refused",
          bump(sday, ["w_cat", "w_red"], extra={"last": "w_cat"}) == 403)
    check("a counter other than the one named is refused", bump(sday, ["w_cat"], extra={"last": "w_dog"}) == 403)
    check("a jump of two on a sign is refused", bump(sday, ["w_dog"], by=2, extra={"last": "w_dog"}) == 403)
    check("a sign counter without the w_ prefix is refused", bump(sday, ["dog"], extra={"last": "dog"}) == 403)
    check("the public cannot read sign tallies", get(sday)[0] == 403)

    # ---- Ratings and messages ----
    ok_id = "A" * 19 + "1"
    check("a message with a rating is accepted", send(ok_id, GOOD_MSG) == 200)
    check("a rating on its own is accepted (type rating, no words)",
          send("B" * 20, {"type": "rating", "role": "parent", "message": "", "page": "download",
                          "lang": "fil", "status": "new", "rating": 4}) == 200)
    check("a message without a rating is accepted",
          send("C" * 20, {k: v for k, v in GOOD_MSG.items() if k != "rating"}) == 200)
    check("a rating-type entry without a rating is refused",
          send("D" * 20, {"type": "rating", "role": "parent", "message": "", "page": "faq",
                          "lang": "en", "status": "new"}) == 403)
    check("an empty message that is not a rating is refused", send("E" * 20, {**GOOD_MSG, "message": ""}) == 403)
    check("a rating-type entry with words is refused", send("F" * 20, {**GOOD_MSG, "type": "rating"}) == 403)
    for bad, label in ((6, "six stars"), (0, "zero stars"), ("5", "a rating as text"), (4.5, "half a star")):
        check(f"{label} is refused", send("G" * 19 + str(len(label) % 10), {**GOOD_MSG, "rating": bad}) == 403)
    check("a message over 2,000 characters is refused", send("H" * 20, {**GOOD_MSG, "message": "x" * 2001}) == 403)
    check("a message of exactly 2,000 characters is accepted", send("I" * 20, {**GOOD_MSG, "message": "x" * 2000}) == 200)
    check("an extra field (an email address) is refused", send("J" * 20, {**GOOD_MSG, "email": "a@b.c"}) == 403)
    check("an unknown role is refused", send("K" * 20, {**GOOD_MSG, "role": "admin"}) == 403)
    check("an unknown page is refused", send("L" * 20, {**GOOD_MSG, "page": "evil"}) == 403)
    check("a long device name is refused", send("M" * 20, {**GOOD_MSG, "device": "d" * 121}) == 403)
    check("arriving already marked done is refused", send("N" * 20, {**GOOD_MSG, "status": "done"}) == 403)
    check("a date the sender chose (not the server's) is refused",
          send("O" * 20, {**GOOD_MSG, "created": "2020-01-01"}, server_time=False) == 403)
    check("a short or odd document id is refused", send("short-id", GOOD_MSG) == 403)
    check("sending over someone else's message is refused", send(ok_id, GOOD_MSG) in (400, 403, 409))
    check("the public cannot change a message",
          patch(f"feedback/{ok_id}", {"message": "changed"}) == 403)
    check("the public cannot read a message", get(f"feedback/{ok_id}")[0] == 403)
    check("the public cannot list messages", run_query("feedback") == 403)
    check("the public cannot delete a message", commit([{"delete": f"{ROOT}/feedback/{ok_id}"}]) == 403)

    # ---- Administrators ----
    check("an email administrator reads the tallies", get(day, ADMIN)[0] == 200)
    check("a Google administrator reads the tallies", get(day, GOOGLE_ADMIN)[0] == 200)
    check("an administrator lists the messages", run_query("feedback", ADMIN) == 200)
    check("an administrator lists the sign tallies", run_query("signs", GOOGLE_ADMIN) == 200)
    check("an anonymous sign-in is never an administrator, even if listed", get(day, ANON_LISTED)[0] == 403)
    check("a signed-in stranger reads nothing", get(day, STRANGER)[0] == 403 and run_query("feedback", STRANGER) == 403)
    check("an administrator marks a message seen and stars it",
          patch(f"feedback/{ok_id}", {"status": "seen", "starred": True}, ADMIN) == 200)
    check("an administrator cannot use an unknown status",
          patch(f"feedback/{ok_id}", {"status": "archived"}, ADMIN) == 403)
    check("an administrator cannot rewrite what a visitor sent",
          patch(f"feedback/{ok_id}", {"message": "edited"}, ADMIN) == 403)
    check("a stranger cannot mark messages", patch(f"feedback/{ok_id}", {"status": "done"}, STRANGER) == 403)
    check("an administrator deletes a message (spam)",
          commit([{"delete": f"{ROOT}/feedback/{'C' * 20}"}], ADMIN) == 200)

    snap = {"update": {"name": f"{ROOT}/downloads/{today}",
                       "fields": {"total": val(58), "releases": val({"v1.4.2": {"arm64": 4}})}},
            "updateTransforms": [{"fieldPath": "at", "setToServerValue": "REQUEST_TIME"}]}
    check("an administrator saves today's download totals", commit([snap], ADMIN) == 200)
    check("a stranger cannot save download totals", commit([snap], STRANGER) == 403)
    check("the public cannot save download totals", commit([snap]) == 403)
    old = json.loads(json.dumps(snap))
    old["update"]["name"] = f"{ROOT}/downloads/{manila_day(-3)}"
    check("download totals cannot be back-dated", commit([old], ADMIN) == 403)
    extra = json.loads(json.dumps(snap))
    extra["update"]["fields"]["note"] = val("x")
    check("download totals with an extra field are refused", commit([extra], ADMIN) == 403)
    check("the public cannot read download totals", get(f"downloads/{today}")[0] == 403)

    check("an administrator reads their own admins entry", get(f"admins/{ADMIN}", ADMIN)[0] == 200)
    check("an administrator cannot read another admin's entry", get(f"admins/{GOOGLE_ADMIN}", ADMIN)[0] == 403)
    check("nobody can list the administrators", run_query("admins", ADMIN) == 403)
    check("an administrator cannot add an administrator",
          patch(f"admins/{STRANGER}", {"name": "me"}, ADMIN) == 403)
    check("a stranger cannot make themselves an administrator",
          patch(f"admins/{STRANGER}", {"name": "me"}, STRANGER) == 403)
    check("the public cannot read the administrators", get(f"admins/{ADMIN}")[0] == 403)

    failed = results.count(False)
    print(f"\n{len(results) - failed}/{len(results)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
