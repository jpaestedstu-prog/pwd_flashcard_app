# Security and data protection

FlashLearn PWD keeps a learner's data on their own device first (Hive) and
mirrors it to Cloud Firestore on Firebase's free Spark plan, so classes and
families can share it across devices. There is no server code: everything
the cloud enforces is in [`firestore.rules`](../firestore.rules). This page
explains what protects the data, how that is tested, and what is still open.

## Who can do what

Every copy of the app signs in **anonymously** (Firebase Authentication), and
each cloud document records the anonymous account that owns it
(`owner_uid`). "Signed in" therefore only means "has a copy of the app".
The rules do the real work:

| Data | Read | Write |
|---|---|---|
| Profiles, progress | the learner's own device, their educators, and a device with a profile in the same class or family group (its group link); a missing one reads as missing; lists only for the owner, or up to 20 named ids each checked the same way | owner device only; recovery code moves ownership |
| Test results | the learner's own device and their educators (an educator's roster proves up to 30 at once) | the learner's own device |
| Custom cards (words only), app-state flags (tutorial seen, last daily challenge, streak count), equipped cosmetics | by exact id; lists only for the owner (custom cards: one device's at a time, for recovery) | owner device only; recovery code moves ownership |
| Messages | only the profiles involved | between contacts only: a learner and the teacher or parent of the group their own profile names (either way), friends, or two profiles on one tablet; blocks are enforced |
| Friend requests, friendships, game rooms | only the profiles involved (and a child's parent for approvals) | sender must own the sending profile; blocks are enforced; a child's friendship needs their real parent's yes |
| Classes, home groups and their members | the teacher or parent, their members' devices (group link) and the learner's own; a class is found by its exact join code | the teacher / parent who owns them; a learner joins only themselves, with the join code |
| Group links, rosters | the device itself | group link: a member's own device; roster: the educator's device or a joining learner's, one proven learner at a time (see "1.4.1") |
| Parent-teacher notes | the learner's own device and the learner's educators | the same people, as themselves |
| Time limits, alarms, routines, routine actions, unlocks, study time | the learner, their educators and the adult who set them | only the learner's own device or one of their educators |
| Achievements, shop purchases | the learner's own device | the learner's own device |
| Assignments | the educator who set them and the learners' devices | the educator, naming only learners and devices on their roster; a learner's app takes work only from their own educators |
| Shared files (Firestore chunks) | anyone signed in, by the file's random id (named only in the items above) | owner only, size-capped |
| Recovery codes | by the exact code; the issuing device lists its own | create: profile owner; redeem: once |
| Safeguarding reports | nobody in the app (reviewed in the console) | the reporting learner |

"One of their educators" means the device that owns the class or family group
the learner joined: it holds an *educator link*, `note_readers/{device}_{learner}`,
naming that group, and the rules check on every use that the learner is still a
member (or that the learner's own profile names the class and the membership is
real). Only the learner's own device can make a membership, so no one can make
themselves somebody else's teacher or parent.

### Deployed on 12 October 2026: who may start a learner's records

Before 1.4.0, the device that wrote a learner-keyed document first owned it.
Anyone who had seen a learner's id (on a class roster, for example) could
create that learner's cloud progress, streak, tutorial flag or equipped item
first, so the learner's own device could never sync them again, and could
file made-up study time under the learner's name. Now only the device that
owns the learner may start those documents (with exceptions for a learner not
yet in the cloud, a valid recovery code, and a profile from before
`owner_uid`). Deployed with the owner's approval (02fd573) and checked live
with [`tool/write_claim_rules_live_probe.py`](../tool/write_claim_rules_live_probe.py).

### Deployed on 12 and 13 October 2026: who is whose

The 12-13 October review found that the rules' idea of "a learner's teacher or
parent" could be faked, and that what an adult sets for a child was open:

| Gap (live until 12/13 October) | Impact |
|---|---|
| A group's owner could file **any** learner in their own class or family group, and a friend request could arrive already marked "approved by the child's parent" | a stranger with only a child's handle could become the child's friend without the parent (their device could even write the friendship), and could rename someone else's learner |
| Time limits, alarms, routines, routine actions and unlocks only checked that the writer owned *some* profile | a stranger could overwrite a child's time limit and lock them out, or send the child alarms and routines with words of their own |
| The notes about a learner were readable and writable by any signed-in user | anyone who knew a learner's id could read what their teacher and parent wrote about them |
| A learner's achievements and shop purchases were listable by anyone | minor |

The fix, in [`firestore.rules`](../firestore.rules): memberships only from the
learner's own device, with fixed ids; new friend requests without approvals or
the recipient's group; educator links (`educatesLearner`, `mayGuide`) for the
notes and everything an adult sets for a child; achievements and purchases
owner-only. Every release since 1.0.0 was checked against it.

**Deployment.** The first part (memberships, friend requests, achievements,
the educator-link collection; commit b4d1cbd) was live at 21:35 on
12 October; the owner made that deploy (confirmed on 13 October). The second part
(notes and child settings; commit adbaf21) was deployed at 00:02 on
13 October, after [`tool/educator_links_backfill.py`](../tool/educator_links_backfill.py)
had filed an educator link for each of the 143 relationships that existed (125
class and 19 family memberships; one skipped, its group owner having no
device), so teachers and parents on older apps keep working. A teacher is
also recognised through the class on the learner's own profile, which covers
students who join later. The live ruleset was read back and compared with the
file: identical. To roll back: `git show b4d1cbd:firestore.rules` (before the
second part) or `git show 02fd573:firestore.rules` (before the review).

**Parents on older apps** (deployed 13 October, 10:18; commit 832e7e6). A
parent's app from before 1.4.0 files no educator link, so after the second
part it could no longer read the notes about, or set the time limit, alarms,
routines and unlocks of, a child who joins their family group later from
another device. Parents now have the teacher's fallback: the owner of the
family group the child's own profile names (`parentsThroughProfile`; every
release's family join writes `home_group_id` from the child's device), while
the child is still a member. It only adds a way to be allowed, checked after
every existing one, so nothing that worked before can be refused. Live data
(read-only): all 19 family members' and all 125 class members' profiles name
their group. Rollback: `git show 1dccc86:firestore.rules`.

**Checked live after the deployment** (13 October; each probe uses throwaway
anonymous accounts, writes as the app would, and deletes everything it wrote
and its accounts afterwards):

| Probe | Checks |
|---|---|
| [`privacy_rules_live_probe.py`](../tool/privacy_rules_live_probe.py) (1.4.1) | 31/31: a stranger with a learner's or a class's id cannot read the learner's profile or progress, the class (and its code) or its members, join without the code, file a group link into it or put themselves on the teacher's roster; the learner, the teacher and a classmate's linked device can, until the classmate leaves (16 of them failed live before the 1.4.1 rules) |
| [`trust_rules_live_probe.py`](../tool/trust_rules_live_probe.py) | 31/31: a stranger cannot pose as a child's parent or a student's teacher, pre-approve or write a friendship with a child, rename a learner, read achievements or notes, write a note, or set a child's time limit, alarm, routine, routine day or unlock; the real teacher, parent and learner still can, and so can a teacher or parent on an older app through the learner's own profile (the two parent checks failed live before the 10:18 deploy) |
| [`write_claim_rules_live_probe.py`](../tool/write_claim_rules_live_probe.py) | 6/6 |
| [`firestore_read_rules_live_probe.py`](../tool/firestore_read_rules_live_probe.py) | 32/32 |
| [`messaging_rules_probe.py`](../tool/messaging_rules_probe.py) | 74/74 (contacts only, joining with a code, blocking, a class broadcast of 3 × 8, parent approval) |
| [`assessment_rules_probe.py`](../tool/assessment_rules_probe.py) | 25/25 (a stranger cannot set a learner a test or read their result) |
| [`shared_media_rules_probe.py`](../tool/shared_media_rules_probe.py) | 26/26 |
| [`recovery_code_live_probe.py`](../tool/recovery_code_live_probe.py) | 3/3 |

All 228 pass after the 1.4.1 deploy (13 October, 16:41); the 178 that
existed before passed after the 10:18 deploy.

Read-only looks at the live database found no sign that any of these gaps
had been used: no child has a friendship, no child is in two family groups,
every membership's id matches its fields, and every existing time limit,
alarm, routine, routine action and unlock was set by the child's own educator.

### In the app (1.4.0)

- **Messages from strangers.** Until the 1.4.1 rules the database delivered
  a message from anyone who knew a profile's id. A learner's inbox and
  Messages badge show only their contacts (friends, their class's teacher,
  their family group's parent) and people they have written to. Teachers'
  and parents' inboxes are unchanged. Since the 1.4.1 rules the database
  itself refuses a message between people who are not contacts, so older
  apps are protected too.
- **Assignments.** Until the 1.4.1 rules any device could file an
  assignment naming a learner. A learner's app takes one only from the
  teachers of their classes or the owners of their family groups (or a
  profile on the same tablet); when it cannot tell, it drops nothing. Since
  the 1.4.1 rules an assignment may name only learners on its setter's
  roster. All 6 live assignments pass both.
- **Educator links.** A teacher's or parent's app files an educator link for
  every learner on their roster, once per learner and device.

### Private fields kept off the cloud (1.4.1)

Until the 1.4.1 rules a learner's `profiles/{id}` document could be read by
any signed-in user who knew the id. Until 1.4.1, joining a class or family
group also copied the learner's **PIN hash, PIN salt and algorithm, birth
date and grade level** there. No version ever read them back from the cloud;
a 4-digit PIN falls to a brute force of its salted hash in moments.

- 1.4.1 joins send none of them ([`profile_cloud_fields.dart`](../lib/data/remote/profile_cloud_fields.dart)),
  and every profile sync removes them from the device's own profiles. A guard
  test fails if any other code writes those keys.
- [`tool/profile_private_fields_cleanup.py`](../tool/profile_private_fields_cleanup.py)
  removed them from the live profiles on 13 October: 159 profiles (159 birth
  dates, 1 PIN hash), nothing else touched; a re-check found none left. The
  birth dates went to a local backup file first (in the owner's Documents
  folder); each tablet keeps its own copy anyway.
- An older app that joins a class again writes them again for that profile,
  until that device updates (its first 1.4.1 sync removes them).

### 1.4.1: who may read a learner, join a group, and message or test them

Until the 1.4.1 rules a learner's records were protected only by their random
id: anyone signed in who knew it (from a username handle, a roster, a message
or a friend request) could read the learner's profile (name, avatar,
disability type and support options, class, device), progress, test results
and what was set for them; anyone who knew a class's id could read its join
code and its members and join it; and anyone could message a learner or send
them a test (apps from 1.4.0 hid those; older apps showed them).

| Now | How the rules know |
|---|---|
| A learner's profile and progress: their own device, their teachers and parents, and a device with a profile in the same class or family group (the leaderboard) | educator links and the group on the learner's own profile, as before; a **group link** `group_readers/{group}_{device}` naming one of the device's profiles in the group, re-checked against the membership every time |
| Test results, and the time limits, alarms, routines, routine days, unlocks and study time set for a learner: the learner's own device and their teachers and parents (and whoever set them) | the same educator proof; an educator's 30-learner results query through their **roster** |
| A class's or family group's document (with its join code) and its members: the teacher or parent, members' devices and the learner's own; anyone finds a class only by its exact code | the owner's profile, the group link |
| Joining needs the join code | the membership carries `join_code`, which must equal the group's |
| Messages only between contacts | the same tablet; a learner and the teacher or parent of the group their own profile names, either way; friends |
| Tests only to an educator's own learners | every learner and device an assignment names is on the setter's roster |

**Rosters.** A rules request may look up 10 documents (a batched write 20 in
all), but an educator's results query names up to 30 learners and an
assignment may name a whole class, so checking each learner on their own
cannot work. Each educator's device has a roster, `educator_rosters/{device}`,
mapping its learners to their devices, which the rules read once. An entry is
proven when it is added, one per write: by the educator's device (the learner
is on the same tablet, or it is their educator) or by the learner's own
device when it joins (a member of a group whose teacher's or parent's profile
that device owns). The educator's device takes off learners who left
whenever it opens their group, and a learner's device may take itself off.

**Lists by id.** The rules engine counts every name in a by-id list as a
document read and refuses a request of more than 20 in all, whatever the
rules say. The live rules refused lists of 21 names before 1.4.1 too, so the
deleted-learner check and the download of assigned tests, which asked for 30,
failed for every teacher or parent with more than 20. 1.4.1 asks for 10 and
falls back to single reads.

**The app (1.4.1).** Joining sends the code and files the group link and the
learner's place on the roster; every start files them for groups joined
earlier or restored to the device. An educator's roster files its educator
links, keeps its roster in line and names its device on its classes and
family groups (`teacher_uid`, `owner_uid`), so a learner joining later knows
whose roster to join. Assignments put their learners on the roster first.
Recovery claims a profile before reading it. A refused message batch is
retried one message at a time, so a safety report still reaches the other
grown-ups. A refused profile read tells the ownership banner that the
profile moved.

**Older versions.** Before the rules went live,
[`tool/privacy_backfill.py`](../tool/privacy_backfill.py) filed, for every
membership that existed, the member device's group link, every teacher's and
parent's roster (their members, and the learners on their own tablet) and the
device on every class and family group. So a device on 1.4.0 or older that
was already in a class keeps its leaderboard and its class's messages, and a
teacher or parent on an older version keeps their roster, results and
assignments for those learners. What older versions lose until they update:
joining a class or family group (they send no code) and restoring a profile
with a recovery code (they read the profile first).

**Deployment** (13 October 2026, with the owner's approval). The backfill ran
from 16:19 to 16:38: 139 group links, 153 roster entries on 83 devices and
the device on 147 classes and family groups, 369 written and 0 failed; a
second run found nothing left to do, and all 6 existing assignments name
only learners on their setter's roster. The rules (commit eb5c446) went live
at 16:41:57; the live ruleset was read back and compared with the file:
identical. Rollback: `git show 832e7e6:firestore.rules`, the rules live
before. Checked live afterwards: the probes below (228 checks), and on real
devices: the Honor (1.4.1) filed its own links and roster at its first start
with no refusal, a second device joined a class with its code, was put on
the teacher's roster by its own app, exchanged messages with the teacher,
received and sat a test the teacher set, whose result reached the teacher;
removed from the class, it lost its access and left the teacher's roster.

### Testing the rules

The rules are tested against the **local Firestore emulator**, never the live
project (a `demo-` project id, seeded with the emulator's admin token):

```
firebase emulators:exec --only firestore --project demo-flashlearn ^
  "python tool/write_claim_rules_emulator_test.py && python tool/firestore_read_rules_emulator_test.py && python tool/recovery_code_rules_emulator_test.py && python tool/trust_rules_emulator_test.py && python tool/privacy_rules_emulator_test.py"
```

(32 + 121 + 14 + 110 + 135 checks, all passing.) Set `FLASHLEARN_RULES_FILE`
to another rules file to run a suite against it: against the rules live
before the second part, 17 of the trust checks fail, because those attacks
worked; against those live before the parent fallback, the 6 parent checks
fail; against those live before 1.4.1, 45 of the privacy suite's attack
checks get through. The privacy suite also pins the engine's limits: a
30-learner results query through a roster, by-id lists of 10 names (21 are
refused) and a class broadcast of 8 messages in one batch.
The live probes above are the second half: run them after every deploy.

## Firebase App Check

App Check would let Firestore accept requests only from genuine copies of the
app, instead of from anyone holding the project's public API key. The code is
in place ([`app_check_service.dart`](../lib/core/services/app_check_service.dart))
but **switched off**, because what makes it meaningful is not free, and one
channel can never have it:

| Channel | Attestation | What it needs |
|---|---|---|
| Google Play | Play Integrity | a Google Play Console account (one-time registration fee) |
| Website APK | none possible | installed outside any store: nothing can vouch for it |

Once a store account exists:

1. Build that store copy with `--dart-define=FLASHLEARN_APP_CHECK=true`.
2. In the Firebase console, App Check → Apps: register the Play app (with its
   SHA-256 signing-key fingerprint from Play App Signing). (iOS support was
   stopped on 13 October 2026, so there is no App Store copy to register.)
3. Watch **App Check → APIs → Cloud Firestore** for a few weeks: it shows how
   many requests are verified. Debug builds use the debug provider and print a
   token to register under "Manage debug tokens".
4. **Do not enforce** while website APKs are in use. Enforcement would refuse
   every website tablet. It can only be turned on once every learner gets the
   app from a store.

Until then, the free protections are the security rules above, anonymous
ownership, and keeping everything else local.

## Known trade-offs

- **Reading by exact id.** Custom cards (the words a device made; their
  pictures stay on the device), the app-state flags (tutorial seen, last
  daily challenge, streak count), equipped cosmetics, assessment templates
  and shared files can still be read by anyone signed in who has the exact
  id. None holds personal details beyond what a leaderboard shows; a file's
  id appears only in documents that are now limited to the people involved
  (a learner's results, messages, routines, a teacher's templates). Closing
  the app-state flags too needs the recovery flow changed first (it reads
  them before it owns them): a candidate for a later version.
- **A roster can lag.** A teacher's or parent's roster lists a learner who
  left their group until their app next opens it (it then takes them off).
  Until then that device can still list the learner's test results and set
  them a test, which a 1.4.1 learner's app ignores (it takes tests only from
  the learner's own teachers and parents). Reads of the learner's profile
  and progress check the membership every time and stop at once.
- **Teachers and parents on older versions.** A class or family group made
  by a version before 1.4.1 after the backfill names no device, so a learner
  who joins it cannot put themselves on that teacher's roster: until the
  teacher updates (or the backfill is run again), that teacher cannot set
  them a test, and a results query naming more than a few such learners is
  refused. Everything a 1.4.1 teacher or parent does is unaffected.
- **Public client keys.** The Firebase API keys in the app (and in the three
  GitHub secret-scanning alerts) are public by design: every copy of any
  Firebase app ships them, and access is controlled by the rules above. They
  can optionally be restricted in Google Cloud (APIs & Services ->
  Credentials) to the Firebase APIs the app uses; with no billing account a
  misused key cannot cost money, and a wrong restriction would stop every
  installed app, so this was left to the owner.
- **Quotas.** The free plan allows 50,000 reads and 20,000 writes a day. A
  script could use them up and stall syncing for everyone until the next day
  (the app keeps working offline). App Check is the defence once it can be
  enforced; there is no free rate limiting without server code.
- **Repository history.** Until 13 October three tracked settings files
  (`.vscode/settings.json`, `.claude/settings.json`,
  `.claude/settings.local.json`) named this PC's user folder. They are no
  longer tracked, but older commits of this public repository still contain
  them (no passwords, tokens, keys or e-mail addresses). Removing them from
  history would mean rewriting and force-pushing every branch, so it is left
  to the owner. Sample data in tests and one website screenshot use a
  teacher's first name, "Sir Kevin".
- **Scores are self-reported.** Progress and test results are written by the
  learner's device. The rules stop one device writing another's, but cannot
  check a score itself without server code.

## The website: visit counts, feedback and the admin dashboard

The public website counts visits and takes ratings and messages; the team
reads them on a private dashboard ([`website_admin/`](../website_admin/README.md)).

- **A separate Firebase project.** The counts, messages and administrator list
  live in the website's own project (`flashlearn-pwd-site`, Spark plan, billing
  not enabled, Firestore in Singapore), not in `pwd-flashcard`. No learner data
  is copied there, so a mistake or a stolen administrator sign-in on the
  website side cannot expose learners. A flood of fake counts can only use up
  the website project's own free quota, never stall the app's syncing.
- **Public writes, pinned down.** The website writes without signing in.
  `website_admin/firestore.rules` lets it add exactly one to known tallies for
  today (at most 16 per write, nothing renamed, removed or back-dated) or create
  one rating/message of a fixed shape: limited lengths, server time, status
  "new", no extra fields such as an email address. Nothing can be read back.
- **Administrators.** Reads need a Google or email sign-in whose uid has a
  document in `admins/`, a list only the Firebase console can change. An
  anonymous sign-in never counts, even if listed. Administrators can mark,
  star and delete messages but never edit what a visitor sent.
- **The dashboard page.** Its own origin (`<project>.web.app`), not linked
  from the public site, `noindex`; a strict Content-Security-Policy (no inline
  script, scripts only from itself, gstatic and Google sign-in),
  `frame-ancestors 'none'`, no referrer; visitors' words are inserted as text
  only; CSV exports neutralise formula-like cells; sign-ins end with the tab
  or after 30 idle minutes unless the administrator chooses otherwise, and
  signing out reloads the page so no statistics stay in it.
- **Privacy.** No cookies, IDs or IP addresses are kept: only daily totals.
  The browser keeps one note that never leaves it (the day it was last
  counted, that it was counted before, the reading aids counted that day). Do
  Not Track and Global Privacy Control turn counting off, and `?nocount=on`
  turns it off for any browser. Ratings and messages are deleted after 12
  months by the dashboard each time an administrator opens it: Firestore's
  automatic expiry (TTL) would need billing. Privacy page section 8.
- **Trade-offs.** Without server code there is no rate limit per visitor: a
  script can inflate the tallies or send spam messages (a hidden form field,
  a minimum fill-in time and five sends a day per browser stop casual bots;
  the inbox deletes the rest). The counts are a measure of interest, not an
  audited figure. The web API key is public by design, like the app's.
- **Tests.** `tool/website_admin_rules_emulator_test.py` (75 checks; an
  allow-everything ruleset fails 53 of them); `tool/website_admin_e2e_check.py`
  (53 checks in headless Chrome against the emulators, including CSP
  violations and axe-core on the dashboard); `tool/website_responsive_check.py`
  and `tool/website_a11y_check.py` for the public pages; and, once deployed,
  `tool/website_admin_live_check.py` (billing off, headers, the live rules).

## On the device

- Local data lives in the app's private storage. Android backup is off
  (`allowBackup="false"`), so a profile cannot be copied off by `adb backup`
  or cloud backup. Moving to a new device goes through a recovery code.
- Teacher and parent profiles can have a PIN, hashed on the device. Since
  1.4.1 the hash never leaves it (see "Private fields kept off the cloud").
- Release APKs are signed with one key kept off the project folder
  ([`docs/signing.md`](signing.md)). CI builds use Android's throwaway debug
  key and can never be published or installed over a real copy.
- Settings → Data → **Delete this profile** removes a profile from the device
  and the cloud (the stores' account-deletion rule). The web form in the
  privacy policy covers learners who no longer have the app.
