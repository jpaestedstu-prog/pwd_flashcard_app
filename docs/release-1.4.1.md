# FlashLearn PWD 1.4.1: what changed and how it was checked

Version **1.4.1 (14)**, for Android phones and tablets: a fix-up release for
1.4.0, from the on-screen checks of the published 1.4.0 on the Honor tablet
and a review of the code, the security rules and the screens on 13 October
2026. Branch `work/v1.4.1`. **Status: prepared and checked; not published (waiting for the owner's approval).**

The parts that did not need a new app are already live: the security rules
(13 October, 10:18), the cloud clean-up, and the repository changes on `main`.
The 1.4.0 report, with every earlier check, is
[release-1.4.0-verification.md](release-1.4.0-verification.md) (section 11
summarises this round).

## Fixed

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| Joining a class or family group copied the learner's **PIN hash and salt, birth date and grade level** into the cloud profile, which anyone who knows its id can read; a 4-digit PIN falls to a brute force of its hash | High | every learner who joined a group (live: 159 profiles, 1 with a PIN) | joins send none of them, every profile sync removes them ([`profile_cloud_fields.dart`](../lib/data/remote/profile_cloud_fields.dart)); the live copies were removed on 13 October ([`profile_private_fields_cleanup.py`](../tool/profile_private_fields_cleanup.py)); an older app that joins again writes them again until that tablet updates | unit tests, a guard over the whole app; a re-check of the live profiles found none left |
| **Parents on an older app** could not read the notes about, or set the time limit, alarms and routines of, a child who joins their family group after the 13 October rules | Medium | parents on 1.2.7 or earlier | the rules accept the family group on the child's own profile, as they do the class for teachers (**live since 13 October, 10:18**; no app change needed) | emulator: 6 new checks fail on the old rules; live probe 31/31 |
| Joining a class **replaced the whole cloud profile**, dropping the family group it named (and other fields) | Low | learners who join a second group | joins merge | unit test |
| Six screens showed a **game-accuracy average as category progress or mastery**: the learner Dashboard, the child details, the weekly PDF report, Teacher Analytics, Student Comparison and the Progress Timeline ("Animals 28%" for 1 word of 12; "doing great" at a category with no word learned) | Medium | teachers, parents, learners | words learned over the category's words, as the Cards and Progress tabs already showed; accuracy keeps its own figure | unit and widget tests, fail on the old code |
| The **All Students** roster kept a streak that had ended ("1d" while the learner's home said 0) | Low | teachers, parents | today's streak | widget test, fails on the old code |
| Turning on a **daily time limit** started at 0 minutes, which the lock ignores: saved straight away, it enforced nothing | Medium | teachers, parents | starts from the length recommended for the learner (30-60 minutes); a limit that has a length keeps it | widget tests |
| A note's **delete**, the Daily Challenge **speakers** and the seasonal banner's **close** were bare icons: no name for a screen reader, no focus for a switch, gaze or keyboard, and targets of 18-24 pixels | Medium | screen-reader, switch, gaze and keyboard users | real buttons with names (one new Filipino and English label) and 48 dp targets | widget tests (name, focus by Tab, size); a guard over the whole app |

Also in this round, without a new app:

- **Repository privacy** (on `main`): three tracked settings files named this
  PC's user folder; they are untracked and ignored (the local files are
  unchanged). The release scanner no longer names anyone: it reads the build
  PC's home folder at run time, and now also catches the 8.3 short form.
  Older commits still contain the files (see [security.md](security.md),
  "Repository history").
- **iOS stopped** (owner's decision): the iOS CI is removed, the `ios/`
  folder stays as it was, and the docs and website text say Android only.

## Checks

| Check | Result |
|---|---|
| Unit and widget tests (CI) | **5,279 passed**, 0 failed; `flutter analyze` no issues; release APKs built; walkthroughs on a phone and a tablet emulator, upright and sideways: 58 screens / 0 problems each (run 38345882378, eb41f6a). The first run (496bc0b) failed 3 tests whose harness lacked the word list the Analytics screen now reads; fixed in eb41f6a |
| Firestore rules, local emulator | 32 + 119 + 14 + 107 = 272 checks passed |
| Firestore rules, live after the 10:18 deploy | 178 checks passed (trust 31, write-claim 6, reads 32, messaging 63, assessments 17, shared media 26, recovery codes 3); the live ruleset read back: identical to the file |
| Cloud clean-up | 159 profiles cleaned, 0 failed; re-check: 0 left; all 433 profiles keep their other fields |
| The published 1.4.0 on the Honor (real device) | every on-screen check passed; found the streak, time-limit, icon-button and category problems above |
| Release build (`tool/build_release.sh`) | eb41f6a, 13 Oct 12:19-12:31: website APKs arm64 `8bbc275b…` (76,806,346 bytes), arm32 `98c7b979…` (69,088,062), universal `9d20d6cb…` (179,256,800); the Play APK and bundle; version 1.4.1 (14), 16 KB aligned, no advertising id; website APKs on the original key (installed copies update), Play builds on the upload key |
| Release files scan | all five clean: no keys, passwords, test-only code, learner data or build-PC paths, nothing debuggable |
| Website, local, with the 1.4.1 download section | headless Chrome audit 1,378 passed / 0 failed (a first run had one timing failure in the dictionary dialog check, unchanged page, which passed on the rerun) |
| Update on the Honor, 1.4.0 → 1.4.1 | installed over the published 1.4.0 with `adb install -r` (12:40): version 1.4.1 (2014), every profile and the learner data kept (173 stars, 17 words). On screen: All Students reads the live streaks (0 for runs that ended), the learner Dashboard shows words learned per category (Animals 8%, 28% in 1.4.0), turning on a time limit starts at 60 minutes (left unsaved), the Daily Challenge speaker is a 48 dp button (84 × 84 px at 1.75×); no app error in the log |

## Not fixed in this round, and why

- **Reading by id, joining by id, and messages or assignments from
  strangers on older apps.** Narrowing these in the rules would refuse
  requests that installed apps make today; each needs the app to change
  first and the rules once older apps are gone. None of them lets a stranger
  change a learner's records: the risks are reading a learner's profile and
  progress by id, and unwanted messages or tests reaching apps older than
  1.4.0 (see [security.md](security.md), "Known trade-offs").
- **Real-hardware checks that need a person**: speech recognition, the X3
  game controller, a physical phone.
- **The 33 unrecorded signs** stay "Sign coming soon".
- **A possible improvement, not made:** leaving the time-limit editor with
  unsaved changes discards them without asking (as in 1.4.0).

## Waiting for approval

1. GitHub Release v1.4.1 with the three website APKs.
2. The website: the 1.4.1 download section, and the Android-only wording on
   the download page, the FAQ and the privacy page.
3. `main` fast-forwarded to the release.
