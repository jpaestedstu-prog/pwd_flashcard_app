# Website admin: visit counts, downloads, ratings and messages

The public website (`website/`, on GitHub Pages) counts its visits and accepts
ratings and messages. This folder holds the **private** side: the dashboard
where the FlashLearn PWD team reads them, and the security rules of the
database they are kept in.

```
 public website (GitHub Pages)                    admin dashboard (Firebase Hosting)
 jpaestedstu-prog.github.io/pwd_flashcard_app     flashlearn-pwd-site.web.app (sign-in)
        │  "one more" to today's tallies,                │  reads, after the rules confirm
        │  a rating or message (write-only)              │  the sign-in is on the admins list
        ▼                                                ▼
        Firebase project flashlearn-pwd-site: Firestore (free Spark plan, Singapore)
        daily/  signs/  feedback/  downloads/  admins/

 GitHub Releases API ── download counts per APK (public, read by the dashboard)

 The app's learners live in another project (pwd-flashcard). This one holds no copy
 of anything from it, and nothing here can reach it.
```

## How the dashboard is kept private

- **Its own address.** It is served from Firebase Hosting
  (`flashlearn-pwd-site.web.app`), a different website from the public one,
  and nothing on the public site links to it. It tells search engines not to
  list it (`robots.txt`, `X-Robots-Tag`).
- **A sign-in, then a list.** Anyone may reach the sign-in page, but the
  database shows data only to a Google (or email) sign-in whose ID is a
  document in `admins/`. That list can be changed only in the Firebase
  console, never from a page. Every read is checked by `firestore.rules` on
  Google's servers, so copying or editing the page's code gets nobody in.
- **Write-only for the public.** The website can only add one to a known
  tally for today, or send one well-formed rating or message. It can never
  read anything back. Even an administrator cannot change what a visitor sent
  or forge a tally.
- **Locked-down page.** `firebase.json` sends a strict Content-Security-Policy
  (scripts only from this site, Google's Firebase files and Google sign-in),
  forbids framing (clickjacking) and sends no referrer. A visitor's words are
  always shown as text, never as HTML, and the CSV export keeps a cell that
  starts like a formula as text.
- **Short sessions.** A sign-in lasts until the tab closes, or 30 minutes
  without use, unless "Stay signed in on this computer" was ticked. Signing
  out reloads the page, so no statistics stay behind on a shared computer.

## Setup

Done on 26 October 2026 with the Firebase CLI, on the account that owns
`pwd-flashcard` (billing is **not** enabled; the live check confirms it on
every run):

```
firebase projects:create flashlearn-pwd-site --display-name "FlashLearn PWD Website"
firebase apps:create WEB "FlashLearn PWD Website" --project flashlearn-pwd-site
# turn on the Cloud Firestore API for the project (free), then:
firebase firestore:databases:create "(default)" --location asia-southeast1 --edition standard \
    --delete-protection ENABLED --point-in-time-recovery DISABLED --project flashlearn-pwd-site
python website_admin/configure.py --project flashlearn-pwd-site --api-key <apiKey> --app-id <appId>
```

`configure.py` writes the project's public web settings everywhere they are
needed; `python website_admin/configure.py --check` compares them.

### Still to do, in this order

1. **Google sign-in** (console only): open
   <https://console.firebase.google.com/project/flashlearn-pwd-site/authentication>,
   press **Get started**, choose **Google**, switch it on, pick a support
   email and press **Save**.
2. **Publish the rules and the dashboard** (needs the owner's go-ahead):
   `cd website_admin` then `firebase deploy --only firestore:rules,hosting`.
3. **Check what is live:** `python tool/website_admin_live_check.py`.
4. **Make yourself an administrator:** open
   <https://flashlearn-pwd-site.web.app>, press **Sign in with Google**. The
   page says **Not an administrator** and shows your ID. In the Firebase
   console open **Firestore Database → Start collection**, name it `admins`,
   paste the ID as the **Document ID**, add a field `name` (string) with your
   name, press **Save**, and reload the dashboard.
5. **Publish the website** (gh-pages) once the privacy page is approved, then
   `python tool/website_admin_live_check.py --site`.
6. On every phone, tablet and computer the team uses for testing, open
   **Tools → Stop counting this browser** once.

## Adding or removing an administrator

- **Add:** they open the dashboard and sign in, then send you the ID shown on
  the **Not an administrator** page. You add `admins/<that ID>` in the
  Firebase console (step 4).
- **Remove:** delete their `admins/<ID>` document. Their next read is
  refused. To stop the sign-in itself, delete or disable the user under
  **Authentication → Users**.

## What is counted

Per Philippine day (UTC+8), in `daily/<YYYY-MM-DD>`. Each value is a number
of page views, visitors or presses for the whole day, nothing per person.

| Tallies | Counted when |
|---|---|
| `v`, `p_<page>`, `l_en` / `l_fil` | every page view: total, which page, which language |
| `u`, `n`, `d_phone` / `d_tablet` / `d_computer` | a browser's first page of the day: a visitor, a new visitor (first time on that browser), the kind of device |
| `a_text`, `a_dys`, `a_hc`, `a_still` | that visitor has the site's larger text, dyslexia font, high contrast or reduce motion on (once a day each) |
| `o_motion`, `o_dark`, `o_contrast` | the device itself asks for reduced motion, dark mode or more contrast |
| `s_direct`, `s_search`, `s_social`, `s_github`, `s_qr`, `s_other` | arriving from outside the site (not on a reload or Back). `s_qr` needs a link ending in `?src=qr` |
| `e_apk_arm64` / `e_apk_arm32` / `e_apk_universal`, `e_webapp`, `e_try_card`, `e_try_game`, `e_film`, `e_demo` | Download pressed, web app opened, Try It card flipped / Word Match game started, the Home film or a how-to video played (once per page view; each Word Match game counts) |

`signs/<day>` counts each FSL sign video played (`w_thank_you`, ...).
`feedback/` holds the ratings and messages. `downloads/<day>` keeps GitHub's
download total as the dashboard saw it that day, which builds the trend line.

Nothing is counted when the browser sends **Do Not Track** or **Global
Privacy Control**, on any copy of the site but the published one, or after
`?nocount=on`. The privacy page (section 8) says all of this to visitors.

## Keeping messages for 12 months

Ratings and messages are deleted 12 months after they were sent (privacy page,
section 8). Firestore's own automatic expiry (TTL) needs a billing account, so
it is not used. Instead the dashboard deletes expired ones each time an
administrator opens it (`KEEP_MONTHS` in `admin.js`, in batches of 20), and
never lists them. If nobody opens the dashboard for a while, the deletion waits
until someone does. The daily visit totals hold nothing about a person and are
kept.

## Free-tier budget

| Spark limit (per day) | Used by |
|---|---|
| 20,000 writes | 1 per page view, 1 per counted press or sign, 1 per message, 1 per day for the download total. Roughly 15,000 page views a day before counting pauses. |
| 50,000 reads | the dashboard: about 2 × (days shown) + up to 500 messages per load, plus 1 per request for the administrator check |
| 20,000 deletes | the 12-month clean-up (normally a handful) and messages deleted in the inbox |
| Hosting: 10 GB stored, 360 MB a day sent | the dashboard is about 0.4 MB |

When a daily limit is reached, counting pauses until the quota resets
(midnight, US Pacific time). **Nothing is ever charged** on Spark, and the
app is not affected: its database is a different project with its own quota.

## Tests

Local, against the emulators (nothing real is touched):

```
cd website_admin
firebase emulators:start --only firestore,auth --project demo-flashlearn-site
# then, from the repository root, in another terminal:
python tool/website_admin_rules_emulator_test.py   # 75 rule checks
python tool/website_admin_e2e_check.py             # 60 checks in headless Chrome
python tool/website_device_check.py [serial]       # the same flows in a phone's or tablet's own Chrome (adb)
```

Without the emulators:

```
python tool/website_responsive_check.py   # 12 pages x 5 widths x 4 modes: no sideways scrolling, header fits, no script errors
python tool/website_a11y_check.py         # axe-core (WCAG 2.2 AA) on every page, computer and phone
```

After a deploy:

```
python tool/website_admin_live_check.py          # billing off, headers, sign-in page, the live rules
python tool/website_admin_live_check.py --site   # also the published website's counting and form
```

The emulators need Java (`C:\Program Files\Java\jdk-25.0.2\bin` on this PC).
The end-to-end check serves `website/` and `public/` itself and drives
Chrome: counting, the feedback form, sign-in, the not-an-administrator page,
the sidebar and its sections (address, Back, focus), the inbox and its unread
count, the 12-month clean-up, CSV exports, GitHub's numbers and the release
check, phone and dark layouts, accessibility (axe, every section), CSP
violations and script errors. The device check needs Developer options on
(Chrome opens its DevTools socket only then) and Chrome past its first-run
screens; on an emulator, Play Store updates can use mobile data. The live check writes only test data, and undoes it with the
Firebase CLI's owner access (the token stays in memory).

## Files

| File | What it is |
|---|---|
| `firestore.rules` | who may write and read what |
| `firebase.json` | the Hosting headers (CSP and the rest) and the emulator ports |
| `.firebaserc` | which project `firebase deploy` uses (written by `configure.py`) |
| `configure.py` | writes the project's values everywhere they are needed; `--check` compares them |
| `public/index.html`, `admin.js`, `admin.css`, `theme.js` | the dashboard (no build step; Firebase JS SDK 12.19.0 from gstatic): a sidebar of five sections (Overview, Audience, Downloads, Feedback, Tools), each with its own address (`#audience`); on phones a top bar with tabs |
| `public/config.js` | the project's public web settings |
