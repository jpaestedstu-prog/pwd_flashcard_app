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
| Profiles, progress, custom cards, app state | by exact id; lists only for the owner or named ids | owner device only; recovery code moves ownership |
| Messages, friend requests, friendships, game rooms | only the profiles involved (and a child's parent for approvals) | sender must own the sending profile; blocks are enforced; a child's friendship needs their real parent's yes |
| Classes, home groups, rosters | by id or exact join code | the teacher / parent who owns them; a learner joins only themselves |
| Parent-teacher notes | the learner's own device and the learner's educators | the same people, as themselves |
| Time limits, alarms, routines, routine actions, unlocks | the learner and the adults who set them | only the learner's own device or one of their educators |
| Achievements, shop purchases | the learner's own device | the learner's own device |
| Assignments | the educator who set them and the learners' devices | the educator; a learner's app takes work only from their own educators |
| Shared files (Firestore chunks) | as the item they belong to | owner only, size-capped |
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
12 October; that deploy was not made from this work session. The second part
(notes and child settings; commit adbaf21) was deployed at 00:02 on
13 October, after [`tool/educator_links_backfill.py`](../tool/educator_links_backfill.py)
had filed an educator link for each of the 143 relationships that existed (125
class and 19 family memberships; one skipped, its group owner having no
device), so teachers and parents on older apps keep working. A teacher is
also recognised through the class on the learner's own profile, which covers
students who join later. The live ruleset was read back and compared with the
file: identical. To roll back: `git show b4d1cbd:firestore.rules` (before the
second part) or `git show 02fd573:firestore.rules` (before the review).

**Checked live after the deployment** (13 October; each probe uses throwaway
anonymous accounts, writes as the app would, and deletes everything it wrote
and its accounts afterwards):

| Probe | Checks |
|---|---|
| [`trust_rules_live_probe.py`](../tool/trust_rules_live_probe.py) | 27/27: a stranger cannot pose as a child's parent or a student's teacher, pre-approve or write a friendship with a child, rename a learner, read achievements or notes, write a note, or set a child's time limit, alarm, routine, routine day or unlock; the real teacher, parent and learner still can |
| [`write_claim_rules_live_probe.py`](../tool/write_claim_rules_live_probe.py) | 6/6 |
| [`firestore_read_rules_live_probe.py`](../tool/firestore_read_rules_live_probe.py) | 32/32 |
| [`messaging_rules_probe.py`](../tool/messaging_rules_probe.py) | 63/63 (blocking, parent approval) |
| [`assessment_rules_probe.py`](../tool/assessment_rules_probe.py) | 17/17 |
| [`shared_media_rules_probe.py`](../tool/shared_media_rules_probe.py) | 26/26 |

Read-only looks at the live database found no sign that any of these gaps
had been used: no child has a friendship, no child is in two family groups,
every membership's id matches its fields, and every existing time limit,
alarm, routine, routine action and unlock was set by the child's own educator.

### In the app (1.4.0)

- **Messages from strangers.** The database delivers a message from anyone
  who knows a profile's id (see "Known trade-offs"). A learner's inbox and
  Messages badge now show only their contacts (friends, their class's
  teacher, their family group's parent) and people they have written to.
  Teachers' and parents' inboxes are unchanged.
- **Assignments.** Any device can file an assignment naming a learner. A
  learner's app now takes one only from the teachers of their classes or the
  owners of their family groups (or a profile on the same tablet); when it
  cannot tell, it drops nothing. All 6 live assignments pass.
- **Educator links.** A teacher's or parent's app files an educator link for
  every learner on their roster, once per learner and device.

Older copies of the app keep their old behaviour for messages and
assignments until they update.

### Testing the rules

The rules are tested against the **local Firestore emulator**, never the live
project (a `demo-` project id, seeded with the emulator's admin token):

```
firebase emulators:exec --only firestore --project demo-flashlearn ^
  "python tool/write_claim_rules_emulator_test.py && python tool/firestore_read_rules_emulator_test.py && python tool/recovery_code_rules_emulator_test.py && python tool/trust_rules_emulator_test.py"
```

(32 + 119 + 14 + 91 checks, all passing.) Set `FLASHLEARN_RULES_FILE` to
another rules file to run the trust test against it: against the rules live
before the second part, 17 of its checks fail, because those attacks worked.
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
| App Store | App Attest, DeviceCheck fallback | the Apple Developer Program (yearly fee) |
| Website APK | none possible | installed outside any store: nothing can vouch for it |

Once a store account exists:

1. Build that store copy with `--dart-define=FLASHLEARN_APP_CHECK=true`.
2. In the Firebase console, App Check → Apps: register the Play app (with its
   SHA-256 signing-key fingerprint from Play App Signing) and the iOS app
   (App Attest needs the App Attest capability in the provisioning profile).
3. Watch **App Check → APIs → Cloud Firestore** for a few weeks: it shows how
   many requests are verified. Debug builds use the debug provider and print a
   token to register under "Manage debug tokens".
4. **Do not enforce** while website APKs are in use. Enforcement would refuse
   every website tablet. It can only be turned on once every learner gets the
   app from a store.

Until then, the free protections are the security rules above, anonymous
ownership, and keeping everything else local.

## Known trade-offs

- **Reading by id.** Anyone signed in who knows a learner's random id (from
  their username handle, or a class roster they can see) can still read, one
  document at a time: the learner's profile (name, role, avatar, disability
  type and support options, class), their progress (stars, words, accuracy),
  their test results, and the time limits, alarms and routines set for them.
  A teacher's roster, a parent's dashboard, friends' names and profile
  recovery read these by id, from apps already installed, so narrowing them
  is a two-phase change (the app first, the rules once older apps have gone;
  the educator links above are the building block). Lists that used to hand
  out ids are closed, and nothing here can be changed by a stranger.
- **Assignments.** The rules cannot tie an assignment to its learners' real
  teacher (it names many learners at once), so a stranger could still file
  one; since 1.4.0 the learner's app ignores it. Older apps would show it.
- **Public client keys.** The Firebase API keys in the app (and in the three
  GitHub secret-scanning alerts) are public by design: every copy of any
  Firebase app ships them, and access is controlled by the rules above. They
  can optionally be restricted in Google Cloud (APIs & Services ->
  Credentials) to the Firebase APIs the app uses; with no billing account a
  misused key cannot cost money, and a wrong restriction would stop every
  installed app, so this was left to the owner.
- **Messages.** Any copy of the app that knows a profile's id can message it.
  Blocks are enforced in the rules, a child's friend requests need a parent,
  reports reach the console, and from 1.4.0 a learner's inbox hides anyone
  who is not their contact. Requiring a shared class or friendship for
  *every* message would refuse messages from apps already installed, because
  they do not send that context. It is a candidate for a later rules version
  once those apps have updated.
- **Joining by id.** Joining a class or family group checks that a learner
  joins only themselves, not that they know the group's join code. Someone
  who learns a class's id could join it and appear on the teacher's roster
  (the teacher can remove them). Proving the code needs the app to send it,
  so this too is a two-phase change for a later version.
- **Quotas.** The free plan allows 50,000 reads and 20,000 writes a day. A
  script could use them up and stall syncing for everyone until the next day
  (the app keeps working offline). App Check is the defence once it can be
  enforced; there is no free rate limiting without server code.
- **Scores are self-reported.** Progress and test results are written by the
  learner's device. The rules stop one device writing another's, but cannot
  check a score itself without server code.

## On the device

- Local data lives in the app's private storage. Android backup is off
  (`allowBackup="false"`), so a profile cannot be copied off by `adb backup`
  or cloud backup. Moving to a new device goes through a recovery code.
- Teacher and parent profiles can have a PIN (hashed on the device).
- Release APKs are signed with one key kept off the project folder
  ([`docs/signing.md`](signing.md)). CI builds use Android's throwaway debug
  key and can never be published or installed over a real copy.
- Settings → Data → **Delete this profile** removes a profile from the device
  and the cloud (the stores' account-deletion rule). The web form in the
  privacy policy covers learners who no longer have the app.
