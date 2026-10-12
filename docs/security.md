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
| Messages, friend requests, friendships, game rooms | only the profiles involved (and a child's parent for approvals) | sender must own the sending profile; blocks are enforced |
| Classes, home groups, rosters | by id or exact join code | the teacher / parent who owns them; a learner joins only themselves |
| Parent-teacher notes | any signed-in user (phase 2 below narrows it) | the author |
| Achievements, shop purchases | the learner's own device | the learner's own device |
| Alarms, routines, routine logs | the learner and the adults who set them | the adult who set them (logs: the learner) |
| Shared files (Firestore chunks) | as the item they belong to | owner only, size-capped |
| Recovery codes | by the exact code; the issuing device lists its own | create: profile owner; redeem: once |
| Safeguarding reports | nobody in the app (reviewed in the console) | the reporting learner |

### Fixed in 1.4.0, waiting to be deployed

Before 1.4.0, the device that wrote a learner-keyed document first owned it.
Anyone who had seen a learner's id (on a class roster, for example) could
create that learner's cloud progress, streak, tutorial flag or equipped item
first. The learner's own device could then never sync them again. They could
also file made-up study time under the learner's name.

Now only the device that owns the learner may *start* those documents. Three
exceptions keep the app's existing flows working: a learner not yet in the
cloud (offline first), a valid recovery code, and a learner whose profile is
still unclaimed (from before `owner_uid`; refusing those would have stopped an
older tablet's study logs). A learner id is read from the whole key, since an
imported profile may keep an id with "_".
[`tool/write_claim_rules_emulator_test.py`](../tool/write_claim_rules_emulator_test.py)
pins this with 32 checks, 12 of them on the data that exists today.

**Deployed on 12 October 2026** (`firebase deploy --only firestore:rules`,
approved by the project owner). Checked live straight after with
[`tool/write_claim_rules_live_probe.py`](../tool/write_claim_rules_live_probe.py):
on a throwaway learner of its own, a second device was refused the learner's
progress, study log and daily challenge (403) while the owning device was
allowed (200); the probe then deleted everything it wrote and both of its
anonymous accounts. The read probe passed too. To roll back, deploy the
previous rules: `git show 1af2345:firestore.rules`.

Installed copies keep working: the app writes these documents only from the
owning device.

### Found in the 12 October review, fixed, waiting for approval to deploy

The rules treat a class or family-group membership as proof that someone is
a learner's teacher or parent. But a group's owner could file **any** learner
in their own group, and a friend request could be sent already marked
"approved by the child's parent". Together that let a stranger, with nothing
but a child's id (their handle is enough), become the child's friend
**without the parent**: their own device could write the friendship, and the
child then sees them as a friend. Checked in the emulator against the rules
live today: the stranger's device wrote the friendship. The same gap let a stranger rename someone else's learner through
a class of their own. Separately, a learner's achievements and shop purchases
could be listed by anyone who knew the learner's id.

The fix, in [`firestore.rules`](../firestore.rules):

- A class or family-group membership is created only by the **learner's own
  device** (the join-code flow), under `{group}_{learner}`, and its two ids
  never change. Teachers and parents still remove members.
- A new friend request carries **no approvals and no recipient group**; the
  recipient stamps their own group when they answer, and only that group's
  real owner approves.
- Achievements and shop purchases are read only by the learner's own device.
- New, additive: `note_readers` (see the notes section below).

Every installed copy keeps working. Each release since 1.0.0 was checked: all
of them join a class only from the learner's device, never pre-fill a
request's approvals, and read achievements only in the owner's own restore.
[`tool/trust_rules_emulator_test.py`](../tool/trust_rules_emulator_test.py)
pins it with 66 checks. Run against today's live rules
(`FLASHLEARN_RULES_FILE=<copy of the deployed rules>`), 34 of them fail:
the attacks above succeed. That run is the proof the test can see them.

A read-only look at the live database the same day found no sign the gap was
used: of 19 child profiles, none has a friendship, no friend request carries
a parent's approval, no child is in two family groups, and every membership
document's id matches its own fields.

**Deploying is a production change and waits for the project owner's
approval** (`firebase deploy --only firestore:rules`; roll back by deploying
the previous file, `git show 02fd573:firestore.rules`).

### Parent-teacher notes: two phases

Today any signed-in user who knows a learner's id can read, and write, the
notes about them. Every release before 1.4.0 reads a learner's notes without
saying who the reader is to the learner, so a tighter rule now would cut
those teachers and parents off. So:

1. **Phase 1 (1.4.0).** When it opens the notes, a teacher's or parent's
   app files `note_readers/{device}_{learner}` (once per learner and device)
   naming the class or family group of theirs that the learner joined. The rules accept it only if that
   membership exists and the caller owns the group.
2. **Phase 2 (later).** Once every teacher's and parent's device runs 1.4.0
   or later, the notes block in `firestore.rules` is replaced by
   [`tool/notes_rules_phase2.rules`](../tool/notes_rules_phase2.rules): notes
   are read and written only by the learner's own device and by educators
   whose reader document still stands on a real membership (checked on every
   read, so a learner who leaves the class takes the access with them). The
   emulator test above runs phase 2 too. Deploying it early would stop older
   apps from seeing the other side's notes, so it waits.

### Messages from strangers (1.4.0, in the app)

The database delivers a message from anyone who knows a profile's id (see
"Known trade-offs"). A learner's inbox used to show such a message as a
read-only thread, and the Messages badge counted it. From 1.4.0 a learner's
inbox and badge show only their contacts (friends, their class's teacher,
their family group's parent) and people they have written to themselves.
Teachers' and parents' inboxes are unchanged. Older copies of the app still
show such messages until they update.

### Testing the rules

The rules are tested against the **local Firestore emulator**, never the live
project (a `demo-` project id, seeded with the emulator's admin token):

```
firebase emulators:exec --only firestore --project demo-flashlearn ^
  "python tool/write_claim_rules_emulator_test.py && python tool/firestore_read_rules_emulator_test.py && python tool/recovery_code_rules_emulator_test.py && python tool/trust_rules_emulator_test.py"
```

(32 + 118 + 14 + 66 checks, all passing for 1.4.0.)

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

- **Reading by id.** A profile, a class or a friend request can be read by
  anyone who knows its random id; a teacher's roster, a parent's dashboard and
  profile recovery depend on it. Lists that used to hand out ids are closed.
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
