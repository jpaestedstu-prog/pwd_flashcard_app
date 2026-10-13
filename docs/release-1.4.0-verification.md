# FlashLearn PWD 1.4.0: final verification report

Android phones and tablets. Prepared 13 October 2026. Every "fixed" below
names the change; every "verified" names the check that was actually run.
What was not tested says so. The change list is in
[release-1.4.0.md](release-1.4.0.md); security detail in
[security.md](security.md); running costs in [costs.md](costs.md).

## 1. Release status

**FlashLearn PWD 1.4.0 is published for Android phones and tablets.**

| Step | When (Philippine time) | Result |
|---|---|---|
| Firestore rules, part 1 (memberships, friend requests, achievements; b4d1cbd) | 12 Oct, 21:35 | live; deployed outside this work session, identical to the reviewed file |
| Educator-link backfill (143 links) | 13 Oct, just before 00:02 | created 143, failed 0; a second run found nothing left to do |
| Firestore rules, part 2 (notes, a child's settings; adbaf21) | 13 Oct, 00:02 | live; read back and compared with the file: identical; 171 live checks pass |
| GitHub Release [v1.4.0](https://github.com/jpaestedstu-prog/pwd_flashcard_app/releases/tag/v1.4.0), the three website APKs | 13 Oct, 01:59 | latest; tag on e53cca6 (the commit the APKs were built from); each file byte-identical to the scanned build; the arm64 downloaded back through the public link, same SHA-256 |
| Website ([download page](https://jpaestedstu-prog.github.io/pwd_flashcard_app/download.html)) | 13 Oct, 02:01 (gh-pages 9b02bfa, built 02:02) | every checked page byte-identical to the commit; every download link, checksum and `version.json` entry matches the release |
| Branches | 13 Oct, 02:03 | `main`, `work/v1.4.0` and `work/sign-interpreter` all at ba8f2f2: the release line, with `main`'s June commits recorded as merged (their features were already in it); no force-push |
| The Honor tablet | 13 Oct, 02:05; checked 10:50-11:35 | the published arm64 installed over the earlier 1.4.0 build (data kept); every on-screen check passed (section 4), and they found four app bugs, fixed for 1.4.1 (section 11) |

Not released: the iPhone/iPad version and Google Play (both need paid
accounts; see [ios_testing.md](ios_testing.md) and [costs.md](costs.md)).

## 2. Issues found in this round and what happened to them

Severity: **Critical** (a child could be put at risk), **High** (learners'
data or core features), **Medium**, **Low**.

### Security and privacy

| # | Issue | Severity | Status | Evidence |
|---|---|---|---|---|
| S1 | A stranger with only a child's handle could file the child in a "family group" of their own and send a friend request already marked "approved by the parent"; their device could even write the friendship | Critical | **Fixed and verified** (rules b4d1cbd, live 12 Oct) | emulator: the attack worked against the old rules, refused by the new; live probe 27/27 |
| S2 | Anyone owning *some* profile could set or overwrite any child's time limit, alarms, routines, routine actions and unlocks (lock a child out, send them words of their own) | High | **Fixed and verified** (rules adbaf21, live 13 Oct 00:02) | as S1; no existing setting was found that a stranger had made |
| S3 | The notes teachers and parents write about a learner were readable and writable by any signed-in user | High | **Fixed and verified** (adbaf21 + backfill of 143 educator links) | live probe: stranger refused, teacher, parent and learner allowed |
| S4 | A stranger could rename someone else's learner through a class of their own | High | **Fixed and verified** (b4d1cbd) | live probe |
| S5 | A learner's achievements and shop purchases were listable by anyone with their id | Medium | **Fixed and verified** (b4d1cbd) | live probe |
| S6 | A learner's inbox showed, and badged, messages from strangers (the database delivers to any known profile) | Medium | **Fixed in the app** (f87679b); the rules still accept such messages | unit and widget tests; old app versions still show them |
| S7 | Any device could file an assignment ("test") naming a learner | Medium | **Fixed in the app** (a3f9ccb): taken only from the learner's own educators; the rules cannot check it | unit tests; all 6 live assignments pass the check |
| S8 | Joining a class or family group needs its id, not its join code | Low-Medium | **Deferred** (needs the app to send proof first, then a rules change) | documented in security.md |
| S9 | A learner's profile, progress, test results and settings can be read one at a time by anyone who knows their id | Medium | **Deferred** (two-phase change; nothing can be *changed* by a stranger) | documented in security.md |
| S10 | Signing keys and passwords were not ignored by git outside `android/` | Low | **Fixed** (9e66be8) | `git check-ignore` |
| S11 | Both signing passwords exist only on this PC (the key backups are without them, by design) | Medium | **Owner action** | backups compared byte for byte; see section 10 |
| S12 | GitHub secret-scanning alerts on three Google API keys | Info | **Not a leak**: Firebase client keys are public by design; optional restriction documented | alert locations checked |
| S13 | A generated plugin file rewritten by a debug-mode `pub get` names a test-only plugin: two release builds failed on it, and test code must never reach a release file | Low | **Fixed** ([`tool/build_release.sh`](../tool/build_release.sh)) and **verified** (a trial run of the script; the release-file scan) | every release file scanned clean |
| S14 | Three tracked settings files (`.claude/settings.json`, `.claude/settings.local.json`, `.vscode/settings.json`) name this PC's user folder in the public repository; so did the release scanner's pattern | Low | **Fixed** (4bb2b9d, on `main` 13 Oct): untracked and ignored, the local files unchanged; the scanner reads the home folder at run time. Older commits still contain the files | searched: no passwords, tokens, keys or e-mail addresses in them; the files return 404 on `main` |
| S15 | Parents on an app from before 1.4.0 could not read the notes about, or set the limits of, a child who joins their family group after the 13 October rules (no educator link) | Medium | **Fixed and verified** (rules 832e7e6, live 13 Oct 10:18): the family group on the child's own profile counts, as the class does for teachers | emulator: 6 new checks fail on the old rules, pass now; live probe 31/31 (the 2 parent checks failed before the deploy) |
| S16 | Joining a class or family group copied the learner's PIN hash and salt, birth date and grade level into the cloud profile anyone with its id can read (a 4-digit PIN falls to a brute force of its hash) | High | **Fixed** in the cloud (13 Oct: 159 profiles cleaned, 1 PIN hash and 159 birth dates, nothing else touched) and in the app (1.4.1: joins send none, syncs remove them) | a re-check found none left; unit tests and a guard test |

### Bugs and data

| # | Issue | Severity | Status | Evidence |
|---|---|---|---|---|
| B1 | Stars, words learned, category progress and Star Shop spending reached the cloud only with the next game | High | **Fixed and verified on the tablet** (fc79bac) | cloud 150 → 165 stars at once |
| B2 | "Turn sound up" said it worked but the Honor's speaker stayed silent | Medium | **Fixed and verified on the tablet** (e7be7a0) | volume 0 → 5 of 15 |
| B3 | On a phone held sideways, a date picker overflowed while the keyboard was still on screen | Medium | **Fixed and verified** (2f99a6a) | widget test with a control; CI sideways phone walk green since |
| B4 | The notes screen would have waited 8 s on every visit when offline (found in review, before any release) | Medium | **Fixed** (fc7262a) | code review; tests |
| B5 | "Category mastery" goals and the student detail screen read an accuracy average as words learned | Medium | **Fixed** (bc0643e) | unit tests |
| B6 | The website said the iPhone/iPad version was "built and tested"; release notes implied iOS and Google Play versions | Low | **Fixed** (23633cc) | page text |
| B7 | Outdated docs: a guide pointed at a missing section, wrong counts in the README and tools guide | Low | **Fixed** | — |
| B8 | The assessment live probe still used the field the rules stopped reading on 4 October | Low | **Fixed** (9b96754) | probe 17/17 |
| B9 | The script that builds the website's sign list (`fsl-dict.js`) was never saved in the repository | Low | **Documented** (fsl_signs_plan.md) | — |
| B10 | Offline, tapping FSL on a word that *has* a recorded sign said "Sign coming soon" (found by the phone-emulator run of the release APK) | Medium | **Fixed and verified** (e53cca6) | widget test (fails without the fix); the release APK on the emulator: "needs the internet" offline, plays online, replays offline |
| B11 | The All Students roster showed a streak that had ended ("1d" for a learner last active on 5 October; their own home said 0) | Low | **Fixed in 1.4.1** | widget test, fails on the old code; seen on the Honor |
| B12 | Turning on a daily time limit started at 0 minutes, which the lock ignores: saved straight away, nothing was enforced | Medium | **Fixed in 1.4.1** (starts from the length recommended for the learner) | widget tests; seen on the Honor |
| B13 | A note's delete, the Daily Challenge speakers and the seasonal banner's close were bare icons: no screen-reader name, no focus for a switch, gaze or keyboard, targets of 18-24 px | Medium | **Fixed in 1.4.1** (real buttons) | widget tests and a guard over the whole app; seen on the Honor |
| B14 | Six teacher, parent and learner screens showed a game-accuracy average as category progress or mastery ("Animals 28%" for 1 word of 12; a category "doing great" with no word learned) | Medium | **Fixed in 1.4.1** (words learned) | unit and widget tests, fail on the old code; seen on the Honor |
| B15 | Joining a class replaced the whole cloud profile, dropping the family group it named (and other fields) | Low | **Fixed in 1.4.1** (merge) | unit test |

### Toolchain and dependencies

| # | Item | Status |
|---|---|---|
| T1 | Flutter 3.47.7 (newest stable): all tests pass and the app builds, but it asks for Gradle 9.1, Android Gradle Plugin 9.0.1 and Kotlin 2.3.20 | **Deferred** to the next version (1.4.0 stays on 3.44, as decided) |
| T2 | 22 packages have newer major versions (Firebase, go_router, Riverpod, notifications, ...) | **Deferred**; no known vulnerabilities in the current ones (OSV, 88 packages) |

## 3. Security checks, before and after deployment

**Before** (local Firestore emulator, never the live project): 32 + 119 + 14 +
91 = 256 checks pass on the deployed rules. The trust test was also run
against the rules that were live before each deploy, to prove it sees the
attacks: 34 failures against the rules of 12 October morning, 17 against the
rules live before the second deploy.

**Read-only looks at the live data** before deploying: 19 child profiles, none
with a friendship; no child in two family groups; every membership's id
matching its fields; every existing time limit, alarm, routine, routine action
and unlock set by the child's own educator; all 6 assignments from the
learner's own educator. No sign of misuse.

**Deploys**: b4d1cbd (live at 21:35, 12 October; not deployed from this work
session) and adbaf21 (00:02, 13 October, after the educator-link backfill).
Each time the live ruleset was read back and compared with the committed file:
identical.

**After** (live, throwaway accounts that delete everything they wrote):

| Probe | Result |
|---|---|
| trust_rules_live_probe (posing as parent or teacher, friendships, renames, private data, a child's settings, and the real people still working) | 27/27 |
| write_claim_rules_live_probe | 6/6 |
| firestore_read_rules_live_probe | 32/32 |
| messaging_rules_probe | 63/63 |
| assessment_rules_probe | 17/17 |
| shared_media_rules_probe | 26/26 |

**The app and its files**: no secrets in any tracked file (only Firebase's
public client keys); the release files scanned for keys, passwords, test
code, learner data and build-PC paths (section 5); only the launcher is
exported in the Android manifest, no deep links, backup off; research exports
are anonymised.

## 4. Devices and configurations

| Device or configuration | Build | What was checked | Result |
|---|---|---|---|
| **Honor NDL W09 tablet** (real device, Android 16, 1200 x 1920) | 1.4.0 from fc7262a (12 Oct, 20:41) | update over the earlier build; all profiles kept; the "sound is off" note; a class learner's home, stars and words as in the cloud; Messages tile and inbox (teacher listed with history); teacher home (7 students) and Parent Notes (reader records refused by the rules of that hour, silently) | passed, no app error |
| Honor, earlier on 12 Oct | 1.4.0 builds | cloud sync of progress, study time, stars, words and shop spending (found B1, fixed, re-checked: 150 → 165 stars at once); "Turn sound up" (found B2, fixed: 0 → 5 of 15); cameras (Word Hunt, Sign It record/replay, Gaze Control), speech output; upright and sideways | passed after the fixes |
| Honor | **final published build** (e53cca6) | installed at 02:05 on 13 Oct (1.4.0, 2013). On screen, 10:50-11:35: teacher home (7 students), All Students, Parent Notes (a note written, found in the cloud, then deleted), Manage Classes and a time limit (saved, found in the cloud, then removed), a learner's home and Messages (only their teacher, with the old history), FSL offline (a saved sign played; an unsaved one said it needs the internet, not "coming soon") and online (it downloaded and played), Word Match 6/6 (the stars reached the cloud at once); no app error in the log. Settings and volume put back | **passed**; found B11-B14 |
| **Phone emulator** (Android 16, 1080 x 2400) | the final release APK (universal) | with no network: first start, onboarding, a Guest profile with Hearing Impairment settings, home, flashcards, joining a class (says to go online), a full Word Match game (stars, an achievement); found B10 (below), fixed; then with the fixed APK: update in place kept the profile, offline, a word with a recorded sign says "needs the internet", online the sign downloads and plays, offline again it replays from the saved copy; reconnecting clears the offline banner and keeps progress | passed |
| CI emulators (GitHub Actions) | final code e53cca6 | phone and tablet, each upright and sideways: 58 screens each, 0 problems (run 38283913034) | passed |
| iOS simulators (GitHub Actions) | fc7262a, then the released app code | fc7262a: 58 screens, 0 problems on all eight (run 38227394474). On the released app code (three runs): IPA and simulator builds passed; one iPad mini run passed all 58 screens and then lost its test connection at teardown, another failed on an Apple audio-player error (DarwinAudioError); both are iOS-only | **iOS support stopped on 13 October** (owner); never released |

**Not tested on real hardware in this round, and why:**

- **Speech recognition of spoken words** (voice commands, speaking games):
  needs a person to speak to the tablet; the microphone permission on the
  Honor had lapsed. The voice features are covered by tests only.
- **A Bluetooth game controller** (the X3): needs it switched on and paired by
  a person.
- **A physical Android phone**: only the phone emulator and CI phones were
  used; the real device was the Honor tablet.

B10, found by the phone-emulator run: offline, tapping FSL on a word that has
a recorded sign (e.g. "Dog") said "Sign coming soon", the promise meant only
for the 33 unrecorded words. Fixed (e53cca6) in the flashcard viewer, Play
Together and story pages; a widget test fails without the fix.

## 5. Automated tests and release-build checks

| Check | Result |
|---|---|
| Unit and widget tests, final code (CI, e53cca6) | **5,260 passed**, 0 failed; `flutter analyze` no issues |
| Firestore rules, local emulator | 32 + 119 + 14 + 91 = 256 checks passed |
| Firestore rules, live after the deploy | 171 checks passed (section 3) |
| Contrast sweep over every screen matrix (app themes) | 0 failures (545 screen tests) |
| Release build (e53cca6, 13 Oct 01:37) | website APKs arm64 `dceb8be1…`, arm32 `1ab1c6d5…`, universal `da298e83…`; Play APK and bundle; versions, permissions and 16 KB alignment checked; website APKs on the original key `AF:D7…2B:A8`, Play builds on the upload key `78:8C…C3:16` |
| Release files scan (`tool/release_artifact_scan.py`) | all five clean: no keys, passwords, private keys, test-only code or fixtures, learner data, build-PC paths, nothing debuggable; a deliberately bad control file is caught |
| Reproducible build (13 Oct, 02:17-02:35: `tool/build_release.sh` on the merged `main`, whose app code is the tagged code) | the three website APKs and the Play APK came out **byte-identical** to the published files, so they demonstrably come from the tagged source; the bundle differs only in the build time R8 records and the signature over it |
| Build safety | twice, something outside the build (most likely the editor's automatic `pub get`) put the test-only plugin back into the generated registrant seconds into a build and the compile failed. The fix is in the repository as [`tool/build_release.sh`](../tool/build_release.sh): it regenerates the file in release mode, builds without `pub get`, keeps the file read-only while each build runs, checks the manifests, signers and contents, and refuses to write over published files. A trial run into separate folders (13 October, 02:17-02:35) built and passed all five files; the published files were left untouched |
| Dart packages (OSV) | 88 packages, no known vulnerabilities |
| Website, live after the deploy (headless Chrome against the public site: 12 pages at 6 screen widths, then the menu, accessibility panel, language switch, old links, every interactive page, dark mode and offline use) | **1,378 passed**, 0 failed |
| CI after publishing (13 Oct, released code) | Android on `main`, `work/v1.4.0` and `work/sign-interpreter`: all passed; one tablet walkthrough first failed on a corrupt NDK download on GitHub's runner (before any app code ran) and passed on re-run |

## 6. Updating an existing installation

- Every website APK is signed with the original key (SHA-256
  `AF:D7:30:B9…2B:A8`), the same key as every release since 1.0.0, so an
  installed copy updates in place; a different key would force an uninstall
  that deletes the profiles.
- Version code 13 (arm64 2013, arm32 1013, universal 13) is higher than
  1.2.7's, so Android accepts it as an update; the app's update check offers
  the same variant the tablet has.
- Checked: 1.2.7 → 1.4.0 on an emulator (profile, XP and stars kept) and on
  the Honor tablet (all 19 profiles, a learner's level, XP, streak, words and
  stars identical before and after). Later 1.4.0 builds were installed over
  the earlier ones on the tablet the same way.
- Nothing in 1.4.0 changes how data is stored on the device; the cloud rules
  accept everything an older app writes for its own learners.

## 7. Limitations and known risks

- **iOS**: support stopped on 13 October (owner); there is no iOS version ([ios_testing.md](ios_testing.md)).
- **Not tested on real hardware this round**: speech recognition of spoken
  words (needs a person to speak), a Bluetooth game controller (needs the X3
  switched on and paired). See section 4.
- **Older app versions** keep showing stranger messages and assignments
  until they update. Their teachers and parents keep guiding learners who
  join later, through the class or family group on the learner's own
  profile (parents since 13 October, 10:18).
- **Reading by id** and **joining by id** (S8, S9) remain; both are planned
  as two-phase changes.
- **Free quotas**: a script could use up a day's reads and pause syncing
  until the reset; App Check would be the stronger defence once store
  accounts exist.
- **The 33 signs** without a video say "Sign coming soon"; nothing presents
  them as finished ([fsl_signs_plan.md](fsl_signs_plan.md)).

## 8. Costs

The app is free for users, for good: no purchases, subscriptions, ads or paid
tiers. Running it costs the owner nothing today: Firebase Spark, GitHub and
Cloudinary free plans, with no billing account anywhere, so a limit pauses a
service instead of charging. Measured use over the last 30 days: usually under
3 % of any daily Firestore quota. Details, the quotas and how to watch them:
[costs.md](costs.md).

## 9. Recommended next

1. The toolchain move (Flutter 3.47+, Gradle 9.1, AGP 9, Kotlin 2.3.20,
   built-in Kotlin) and the package updates, as the first change of the next
   version, with the full checks and a tablet run.
2. Two-phase privacy work: narrow reads by id to the learner and their
   educators (the educator links are the building block), prove the join code
   when joining, and require a link for messages and assignments in the rules.
3. When a Deaf signer is available: the 33 signs ([fsl_signs_plan.md](fsl_signs_plan.md)).

## 10. What the owner needs to do personally

1. ~~Store both signing passwords~~ and ~~copy the backup folder to a USB
   drive~~: done by the owner on 13 October.
2. **Confirm the rules deploy at 21:35 on 12 October was yours.** It matches
   the reviewed rules exactly, but it was not made from this work session.
3. ~~Unlock the Honor tablet~~: done; every on-screen check passed (section 4).
4. Optional, needs a person: speak to the tablet once for speech
   recognition, and switch on the X3 controller for the controller check.
5. Optional: restrict the Firebase API keys in Google Cloud (security.md,
   "Public client keys").
6. **Decide on 1.4.1** (section 11): publishing it is what brings the app
   fixes to the tablets.
7. Later, by choice: Google Play (one-time fee). Apple is no longer needed.

## 11. After publishing (13 October)

The on-screen checks of the published build, and a review of the code,
security and screens, found more problems. What was done:

| | What | Where it stands |
|---|---|---|
| Rules | Parents on older apps (S15) | **live** since 10:18; 178 live checks pass |
| Cloud data | PIN hashes and birth dates removed from 159 profiles (S16) | **done**; the birth dates are kept in a local backup file in the owner's Documents folder |
| Repository | Settings files untracked, scanner without a name (S14); iOS CI removed; docs and website text say Android only | **on `main`** (e9226c4); the website text goes live with the next website deploy |
| App | S16, B11-B15 | **1.4.1 prepared, not published**: [release-1.4.1.md](release-1.4.1.md) |
