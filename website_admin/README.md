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

 Email notices (once set up): the feedback form also posts each rating or message to
 a Google Apps Script in the admin's own Google account, which emails it to
 jaj4ngpinasto@gmail.com (email_notifier/, see "Email notices" below).

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

## Live updates

While the dashboard is open it listens to Firestore (real-time listeners,
`onSnapshot`) for three things: today's tallies (`daily/<today>`), today's sign
plays (`signs/<today>`) and the newest 500 ratings and messages. So:

- the **Today** panel on the Overview (visitors, page views, Download presses,
  sign videos played) and every tile and chart follow the website as people use it;
- **Live activity** lists, in words, what changed since the page was opened
  ("1 page view: Learning Games (in Filipino) · a new visitor on a phone, from a
  search engine", "FSL sign played: Thank you", "New rating ★★★★★ from a
  teacher"). It is worked out by comparing the server's answers, so it only
  shows real changes, and nothing of it is stored;
- a new rating or message brings a notice in the corner, the unread count on
  **Feedback** and in the tab's title, and appears in the inbox. If you are
  working in the inbox at that moment, a "new messages — show them" button is
  offered instead of redrawing the list under your hands.

The pill next to **Refresh** says **Live**, **Offline** (showing the last
numbers) or **Paused**: a tab hidden for 10 minutes stops listening, to save
reads, and catches up when it is looked at again. Earlier days never change
(the rules accept counts for today only), so they are read once per load.
GitHub's download numbers are fetched again every 10 minutes while the page is
looked at.

## Email notices (to jaj4ngpinasto@gmail.com)

Every rating or message sent with **Send to the team** is saved in this dashboard,
as before, and, once this is set up, also arrives as an email at
**jaj4ngpinasto@gmail.com** within a few seconds. Firebase's own email route
(the Trigger Email extension) needs Cloud Functions, which need the paid Blaze
plan, so the email is sent by a small **Google Apps Script** in the admin's own
Google account instead. It is free with any Google account.

```
 visitor presses "Send to the team" on faq.html
   │ 1. the notice (plain text)              │ 2. the save, as before, with what happened to
   ▼                                         ▼    the notice: mail = sent | unconfirmed | off
 Apps Script web app (email_notifier/)      Firestore feedback/{id} ──► dashboard inbox
 in the jaj4ngpinasto@gmail.com account        ("Email notice sent", "not confirmed", ...)
   │ MailApp, to ADMIN_EMAIL only
   ▼
 jaj4ngpinasto@gmail.com
```

**Nothing secret is stored anywhere.** There is no Gmail password, app password or
API key in this repository, the website or the dashboard. Google runs the script as
its owner after the owner allows it once; its only permission is **Send email as
you**. The script can only ever email `ADMIN_EMAIL` (written once, in `Code.gs`):
nothing in a request can change who receives it. Its web app address is public (it
is in `site.js`, like any form's address), so it sends at most **40 emails a day and
8 in ten minutes**, plain text only, and never the same feedback twice. Gmail allows
a free account's scripts 100 recipients a day.

`configure.py --mail-url` also lets the dashboard's Content-Security-Policy reach
that one address (and `script.googleusercontent.com`, where Apps Script answers
from), never every Apps Script; with notices off it allows neither. The inbox's
"Email notice sent / not confirmed" is what the visitor's browser reported when it
saved the message: to check the notifier itself, use **Tools → Email notices**.

### What the visitor is told (only what really happened)

| What happened | The form says |
|---|---|
| Saved in this dashboard, emailed, or both (the database or the notifier confirmed it) | **Your feedback has been sent successfully!** |
| Neither worked (offline, a limit, an error) | **Your feedback could not be sent. Please try again.** |
| *Open in your email app*, and the email app came to the front | **Your email application has been opened. Please send your message to complete submission.** |
| *Open in your email app*, and nothing seemed to open | **If your email app opened, press Send there to complete submission.** (and, if not, to copy the message) |
| The same feedback again within 30 minutes | **This feedback was already sent successfully. You do not need to send it again.** |

A retry uses the same document ID, so a send whose answer was lost is never saved
(the database answers 409) or emailed (the notifier answers "duplicate") twice.

### Set it up (once, about 10 minutes, in the jaj4ngpinasto@gmail.com account)

1. Sign in to Google as **jaj4ngpinasto@gmail.com**. Open
   <https://script.google.com> and press **New project**.
2. Click **Untitled project** at the top and name it `FlashLearn PWD feedback notifier`.
3. In `Code.gs`, select everything and delete it. Paste the whole of
   `website_admin/email_notifier/Code.gs` from this repository. Press **Save** (the disk icon).
4. Press **Project Settings** (the gear on the left) and tick **Show "appsscript.json"
   manifest file in editor**. Back in the **Editor** (`< >`), open `appsscript.json`,
   replace everything with `website_admin/email_notifier/appsscript.json`, and save.
5. In the function list in the toolbar, choose **checkSetup** and press **Run**. Google
   asks for permission: **Review permissions** → choose jaj4ngpinasto@gmail.com →
   *Google hasn't verified this app* → **Advanced** → **Go to FlashLearn PWD feedback
   notifier (unsafe)** → **Allow**. (It says "unverified" only because you made it
   yourself.) The **Execution log** then shows *A test email went to
   jaj4ngpinasto@gmail.com*, and a "[FlashLearn PWD] Test email" arrives in the inbox.
6. Press **Deploy → New deployment**. Next to *Select type* press the gear and choose
   **Web app**. Description `v1`, **Execute as: Me**, **Who has access: Anyone**.
   Press **Deploy** and copy the **Web app URL** (it ends in `/exec`).
7. On this computer, from the repository folder:
   `python website_admin/configure.py --mail-url <the Web app URL>`, then
   `python website_admin/configure.py --check`.
8. Publish (only with the owner's go-ahead): `cd website_admin`,
   `firebase deploy --only firestore:rules,hosting` **first**, then the website
   (gh-pages). The website still works with the old rules (it saves without the
   notice's outcome), but the dashboard can only show the outcome after the new rules.
9. Check it live: dashboard **Tools → Email notices → Check the connection** (says
   *Connected* and *ja…to@gmail.com*), then **Send a test email** (says *SENT*, and the
   email arrives; look in Spam the first time and mark it *Not spam*). Then send one
   real rating from the website's feedback form.

**Changing the script later:** edit it in the Apps Script editor, then **Deploy →
Manage deployments → ✎ Edit → Version: New version → Deploy**. The address stays the same.

**Turning it off:** **Deploy → Manage deployments → Archive** (the website then saves
to the dashboard only and marks the notice *not confirmed*), or
`python website_admin/configure.py --mail-url ""` and publish the website (marked
*No email notice (notices were off)*).

**Keeping the 12-month promise for the email copies** (privacy page, section 8): once a
month, search Gmail for `subject:"[FlashLearn PWD] New" older_than:1y`, select all and
delete. (Deleting old email automatically would need full access to the mailbox, which
the notifier deliberately does not ask for.)

**Messages sent with "Open in your email app"** come straight from the visitor's own
email to jaj4ngpinasto@gmail.com. They never pass through this website, so they are
only in that inbox; **Tools → Email notices → Open the inbox in Gmail** opens a search
for "[FlashLearn PWD]" there.

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
| 50,000 reads | the dashboard: about 2 × (days shown) + up to 500 messages per load, plus 1 per request for the administrator check; while it is open, 1 per change the live listeners receive (about 1 per page view on the website) |
| 20,000 deletes | the 12-month clean-up (normally a handful) and messages deleted in the inbox |
| Hosting: 10 GB stored, 360 MB a day sent | the dashboard is about 0.4 MB |
| Apps Script (not Firebase): Gmail lets a free account's scripts email 100 recipients a day | email notices: at most 40 a day and 8 in ten minutes; over that, the website still saves to the dashboard |

When a daily limit is reached, counting pauses until the quota resets
(midnight, US Pacific time). **Nothing is ever charged** on Spark, and the
app is not affected: its database is a different project with its own quota.

## Tests

Local, against the emulators (nothing real is touched):

```
cd website_admin
firebase emulators:start --only firestore,auth --project demo-flashlearn-site
# then, from the repository root, in another terminal:
python tool/website_admin_rules_emulator_test.py   # 80 rule checks
python tool/website_admin_e2e_check.py             # checks in headless Chrome: live updates, email notices (a stand-in notifier)
python tool/website_device_check.py [serial]       # the same flows in a phone's or tablet's own Chrome (adb)
```

To try the website and the dashboard together by hand (same emulators; offline is fine):

```
python tool/website_admin_preview.py   # prints a website address, a dashboard address and a sign-in
```

Browse the local website in one tab and watch the dashboard in another: every page,
Download press, sign video and message appears there as it happens.

Without the emulators:

```
node tool/website_admin_notifier_test.mjs    # the email notifier (Code.gs) with stand-ins for Google's services
python website_admin/configure.py --check     # one project, one admin email, one notifier address everywhere
python tool/website_responsive_check.py   # 12 pages x 9 widths x 4 modes: no sideways scrolling, header fits, no script errors
python tool/website_a11y_check.py         # axe-core (WCAG 2.2 AA) on every page, computer and phone
python tool/website_nav_check.py          # the grouped navigation (mouse, keyboard, phone), theme choice, arrival animation
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
count, the delete dialog, sorting and "mark the shown new ones as seen", the
12-month clean-up, CSV exports, GitHub's numbers and the release check, live
updates (a page view and a message written the way the website writes them,
through the rules, while the dashboard stays open), phone and dark layouts,
accessibility (axe, every section), CSP violations and script errors. The device check needs Developer options on
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
| `public/index.html`, `admin.js`, `admin.css`, `theme.js` | the dashboard (no build step; Firebase JS SDK 12.19.0 from gstatic, with the full Firestore library for live updates): a split-screen sign-in, then a sidebar of five sections (Overview, Audience, Downloads, Feedback, Tools), each with its own address (`#audience`); on phones a top bar with tabs. The same look as the website and the app (tile tones, raised icons, purple into teal) |
| `public/config.js` | the project's public web settings, and `MAIL` (the notice address and the notifier's web app address) |
| `email_notifier/Code.gs`, `appsscript.json` | the email notifier: a Google Apps Script web app, pasted into script.google.com in the admin's Google account (see "Email notices") |
