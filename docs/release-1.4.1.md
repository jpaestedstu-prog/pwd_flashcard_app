# FlashLearn PWD 1.4.1: what changed and how it was checked

Version **1.4.1 (14)**, for Android phones and tablets: a privacy and
fix-up release for 1.4.0, from the on-screen checks of the published 1.4.0 on
the Honor tablet and a review of the code, the security rules and the screens
on 13 October 2026. **Status: published on 13 October 2026** (approved by
the owner once every open issue was fixed and verified, and the remaining
limitations below accepted).

The 1.4.0 report, with every earlier check, is
[release-1.4.0-verification.md](release-1.4.0-verification.md); the rules are
described in [security.md](security.md).

## Fixed

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| **Strangers could read a learner's records by id**: anyone signed in who knew a learner's random id (from a username handle, a roster, a message or a friend request) could read their profile (name, avatar, disability type and support options, class, device), progress, test results, and the time limits, alarms, routines, routine days, unlocks and study time set for them | High | every learner in the cloud | the 1.4.1 rules: the learner's own device, their teachers and parents, and (profile and progress, for the leaderboard) a device with a profile in the same class or family group, through a group link the member's device files; an educator's 30-learner results query is proven by their roster ([security.md](security.md), "1.4.1") | emulator: 135 privacy checks, 45 of whose attack checks get through on the old rules; live: privacy probe 31/31 (16 failed before the deploy) |
| **Joining by id**: a class's or family group's document, readable by anyone who knew its id, held its join code; its member list was open; a membership needed no code | High | every class and family group | the document and its members are read only by the teacher or parent and members' devices; a membership carries the join code, which must match | emulator (privacy, trust, read suites); live privacy and messaging probes |
| **Messages and tests from strangers** reached apps older than 1.4.0 (1.4.0 hid them on the learner's side only) | Medium | learners on older apps | the database takes a message only between contacts (a learner and the teacher or parent of the group their profile names, either way; friends; one tablet) and an assignment only for learners and devices on the setter's roster | emulator; live messaging (74/74) and assessment (25/25) probes |
| Joining a class or family group copied the learner's **PIN hash and salt, birth date and grade level** into the cloud profile | High | every learner who joined a group (live: 159 profiles, 1 with a PIN) | joins send none of them, every profile sync removes them ([`profile_cloud_fields.dart`](../lib/data/remote/profile_cloud_fields.dart)); the live copies were removed on 13 October ([`profile_private_fields_cleanup.py`](../tool/profile_private_fields_cleanup.py)); the backup of the removed birth dates is kept, as the owner asked | unit tests, a guard over the whole app; a re-check of the live profiles found none left; a 1.4.1 join on a second device wrote none |
| **Lists of more than 20 by id were always refused**: the deleted-learner check and the download of assigned tests asked for 30 at a time, and the rules engine counts every name as a document read, 20 at most per request (the live rules refused 21 names) | Medium | teachers and parents with more than 20 learners or tests | 10 names a query, falling back to single reads | live read-only probe (20 allowed, 21 refused); unit tests pin the sizes |
| Leaving the **time-limit editor** with unsaved changes dropped them without a word | Medium | teachers, parents | Back (the button or the Android gesture) asks: save, leave without saving, or keep editing; a failed save keeps the editor and the changes | 7 widget and unit tests (English and Filipino); on the Honor: the dialog, Keep editing, Back key, Leave without saving |
| A teacher's change to **retakes** never reached learners on their own tablets: the device cached the class once, when the learner joined | Medium | learners on their own tablets | every start refreshes the cached class or family group | 3 unit tests |
| **Parents on an older app** could not read the notes about, or set the time limit, alarms and routines of, a child who joins their family group after the 13 October rules | Medium | parents on 1.2.7 or earlier | the rules accept the family group on the child's own profile, as they do the class for teachers (live since 13 October, 10:18) | emulator; live trust probe 31/31 |
| Six screens showed a **game-accuracy average as category progress or mastery** ("Animals 28%" for 1 word of 12) | Medium | teachers, parents, learners | words learned over the category's words; accuracy keeps its own figure | unit and widget tests, fail on the old code |
| Turning on a **daily time limit** started at 0 minutes, which the lock ignores | Medium | teachers, parents | starts from the length recommended for the learner | widget tests |
| A note's **delete**, the Daily Challenge **speakers** and the seasonal banner's **close** were bare icons (no name, no focus, 18-24 px) | Medium | screen-reader, switch, gaze and keyboard users | real buttons with names and 48 dp targets | widget tests; a guard over the whole app |
| One refused **upload** held back every other one in its batch (an assignment naming a learner who left: every template and assignment made offline alongside it stayed unsent) | Medium | teachers, parents | a refused batch is written one document at a time | assessment tests; on the Honor |
| One refused recipient sank a whole **message batch** (a safety report to several grown-ups, a class broadcast) | Low | learners, teachers | a refused batch is sent one message at a time | rules checks; code review |
| The **roster and leaderboard** failed as a whole when one member could not be read | Low | teachers, parents, learners | that member is left out | on the Honor (7 learners on four devices) |
| A **pending delete** of a test or template already deleted elsewhere was retried at every sync, forever | Low | teachers, parents | cleared once the server no longer lists the document | unit tests; on the Honor |
| The **All Students** roster kept a streak that had ended | Low | teachers, parents | today's streak | widget test |
| Joining a class **replaced the whole cloud profile**, dropping the family group it named | Low | learners who join a second group | joins merge | unit test |

Also in this round:

- **Repository privacy** (on `main`): three tracked settings files named this
  PC's user folder; they are untracked and ignored. Older commits still
  contain them ([security.md](security.md), "Repository history").
- **iOS stopped** (owner's decision): the iOS CI is removed, the `ios/` folder
  stays as it was, and the docs and website say Android only.
- **The rules and the backfill** went live on 13 October (below).

## Checks

| Check | Result |
|---|---|
| Unit and widget tests (CI) | **5,304 passed**, 0 failed; `flutter analyze` no issues; walkthroughs on a phone and a tablet emulator, upright and sideways: 58 screens / 0 problems each; release APKs built (run 38379426263, 1472905). One earlier run (4170650) failed only because the test driver lost its connection in one walkthrough; every later run passed in full |
| Firestore rules, local emulator | 32 + 121 + 14 + 110 + 135 = **412 checks passed** on the deployed file (eb5c446); against the rules live before, 45 of the privacy suite's attack checks get through |
| Backfill ([`privacy_backfill.py`](../tool/privacy_backfill.py)), 16:19-16:38 | dry run and emulator test (16 checks) first; then 139 group links, 153 roster entries on 83 devices and the device on 147 classes and family groups: 369 written, 0 failed; a second run: nothing left; all 6 existing assignments on their setter's roster |
| Rules deploy (with the owner's approval) | 16:41:57; the live ruleset read back: identical to eb5c446 |
| Live probes after the deploy | **228 checks passed**: privacy 31, trust 31, messaging 74, assessments 25, reads 32, write-claim 6, shared media 26, recovery codes 3. Every probe document and throwaway account is removed; two leftovers of an earlier run against the old rules were found and removed, and the probes now clean those up themselves |
| The Honor (1.4.1, real device, under the new rules) | first start: its own group links and roster filed, no refusal and no app error; Sir Kevin's home, All Students (7 learners on four devices) and Manage Classes load; the time-limit warning (above); messages; assignment tracking pulls results |
| A second device (emulator, 1.4.1) | joined Sir Kevin's class with the code: the membership carries the code, no private fields reached the cloud, its own app filed its group link and put it on the teacher's roster; the teacher saw it, messaged it and set it a test; it replied, received and sat the test, and the result reached the teacher; removed from the class, it lost its access and left the teacher's roster. Its documents were then removed from the cloud |
| Release build (`tool/build_release.sh`) | 1472905, 13 Oct 17:52-18:07: website APKs arm64 `824127b9…` (76,806,346 bytes), arm32 `bd9a25d0…` (69,120,830), universal `e07f26f5…` (179,355,104); the Play APK and bundle; version 1.4.1 (14), 16 KB aligned, no advertising id; website APKs on the original key (installed copies update), Play builds on the upload key. Installed on the Honor over the earlier 1.4.1 (18:10), every profile kept; its first sync cleared the two stuck deletes, the second had no refused write |
| Release files scan | all five clean: no keys, passwords, test-only code, learner data or build-PC paths, nothing debuggable |
| Website, local, with the 1.4.1 download section | headless Chrome audit 1,378 passed / 0 failed, with the download section, the changelog and `version.json` generated from these APKs |

## Recorded on the owner's confirmation (13 October)

- **The rules deploy at 21:35 on 12 October** was the owner's.
- **Real hardware that needs a person**: the owner tested speech recognition,
  the X3 game controller and the app on a physical phone personally and
  reported that everything works well. No further details (device, version,
  steps) were given, so none are recorded.

## Approved exception

- **The 33 unrecorded signs** stay "Sign coming soon" in 1.4.1 (approved by
  the owner on 13 October). They need recordings by someone who signs FSL;
  none exist, and signs are never generated or downloaded. The recording plan
  is [fsl_signs_plan.md](fsl_signs_plan.md); they ship in a later version.

## Known limitations

- **Versions before 1.4.1** cannot join a class or family group or restore a
  profile with a recovery code (approved). A device that was already in a
  class keeps its leaderboard and messages, and a teacher or parent keeps
  their roster, results and assignments for the learners they had. A class
  made by an older version after the update names no teacher's device, so a
  learner who joins it cannot put themselves on that teacher's roster until
  the teacher updates (or the backfill is run again).
- **Reading by exact id**: custom cards (words only), the app-state flags
  (tutorial seen, last daily challenge, streak count), equipped cosmetics,
  test templates and shared files can still be read by anyone signed in who
  has the exact id; none holds personal details beyond a leaderboard's.
- **A roster can lag** until the teacher's app next opens the group: until
  then a teacher can list a departed learner's test results and set them a
  test (which their 1.4.1 app ignores).
- **Times across devices** (when a message was sent, when a learner joined)
  are shown as the sending device wrote them, so they read correctly only
  between devices set to the same time zone. Every device in a Philippine
  class is; the test emulator (UTC) showed the 8-hour difference.
- Everything else in [security.md](security.md), "Known trade-offs".

## Publication (13 October, approved by the owner)

| Step | When (Philippine time) | Result |
|---|---|---|
| Firestore rules (eb5c446), after the backfill | 16:41 | live; read back: identical to the file; 228 live checks pass |
| GitHub Release [v1.4.1](https://github.com/jpaestedstu-prog/pwd_flashcard_app/releases/tag/v1.4.1) (id 411548245), the three website APKs | 18:30 | latest; tag on 1472905 (the commit the APKs were built from); uploaded as a draft over the owner's phone hotspot (with their OK), each file's digest equal to the scanned build before it was made public |
| Website ([download page](https://jpaestedstu-prog.github.io/pwd_flashcard_app/download.html)) | 18:30 (gh-pages 7eb0e77 from 734c6f6, built 18:31) | every checked page byte-identical to the commit; the live page's links, sizes and checksums and `version.json` match the release; the arm64 downloaded back through the public link: same SHA-256 |
| `main` | 18:32 | fast-forwarded from e9226c4 to 734c6f6 (the release line); no force-push |
