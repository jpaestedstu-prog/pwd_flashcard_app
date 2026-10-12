# FlashLearn PWD 1.4.0: what changed and how it was checked

Version **1.4.0 (13)**, for Android phones and tablets. **Published on 13
October 2026**: [GitHub Release v1.4.0](https://github.com/jpaestedstu-prog/pwd_flashcard_app/releases/tag/v1.4.0)
(tag on e53cca6), the website's download page, the security rules, and the
branches merged (`main` = `work/v1.4.0` = `work/sign-interpreter`). Built on
the unpublished 1.3.0. The final verification report, with every issue, check
and device, is [release-1.4.0-verification.md](release-1.4.0-verification.md).

## Bugs fixed

| Problem | Who it hit | Fix |
|---|---|---|
| **Word → Sign** answers broke ("infinite height") as soon as their sign videos loaded | every learner, since 2026-09-10 | the controller focus ring no longer stretches a list row (`GamepadFocusable`) |
| A stranger who knew a learner's id could create that learner's cloud **progress, streak, tutorial flag, equipped item or study logs** first, locking the learner's own device out of them | every synced learner (live rules) | `mayStartFor()` in `firestore.rules`; **deployed 2026-10-12**, checked live (stranger refused, owner allowed) |
| iOS keeps only 64 pending notifications; child alarms alone could ask for 224 | iPhone and iPad | one shared budget (62); an every-day alarm is one daily repeat |
| The Google Play build gets no exact alarms on Android 14+, so reminders, alarms and locks could arrive up to an hour late, silently | Play build | "Allow on-time alarms" in the routine builder, the alarm list and the learner's My Day; schedulers re-check on resume |
| **Gaze Control on iPhone/iPad** moved the highlight the wrong way (the iOS camera mirrors front-camera frames) | iOS | readings turned back into Android's frame |
| The splash overflowed on every sideways start; onboarding text sat below the fold | sideways phones | compact splash; side-by-side welcome and tour pages |
| A sideways phone (914 dp wide) was treated as a large tablet | sideways phones | size classes follow the shortest side |
| Flashcard Quiz, Sign It and Sign → Word did not fit a sideways phone | sideways phones | their own side-by-side layouts |
| **Memory Match** showed one row of cards sideways and could not be finished; **Word Match, Picture-Word, Pronunciation** showed two of four answers. The grids do not scroll, and a clipped grid raises no error, so no test had noticed | sideways phones | every card and answer fits: the prompt beside the answers on short wide screens, cells sized to the space |
| The **flashcard viewer** shrank the card to an unreadable thumbnail sideways | sideways phones | the actions become a side panel |
| **Sign It and Word Hunt** showed "Something went wrong" on a device with no camera (CameraX reports it as a PlatformException) | devices without a camera | treated as "no camera here" |
| The walkthrough blamed the wrong screen for errors (the error log is newest first) and never checked onboarding | testing | errors matched by time; onboarding checked |
| **Found on the real tablet:** the status bar's clock and battery were white on the light pages of every screen with a top bar (Flutter reads a transparent bar as black), and other screens kept whatever the last one left | everyone, every device | icons follow what is really behind them; one app-wide default; white on the camera and video pages; checked for all 38 themes |
| **Found on the real tablet:** Sign It's **Record** and **Replay** sat below the fold whenever the camera worked (upright and sideways on a 10" tablet), so a learner could not record a sign | tablets with a camera | the video and camera take the space the buttons leave |
| **Found on the real tablet:** Memory Match paid 3 stars for one flip and "Quit to Games"; Jigsaw, Drag & Drop and the Flashcard Quiz also paid full stars on a quit or when Beat the Clock ran out, so stars, XP and 3-star bests could be farmed | every learner | an unfinished round earns stars for the share actually done (90/70/50 %) |
| Memory Match's time-up result showed a perfect score and marked every word correct | Beat the Clock | the real score and review |
| The Progress and Showcase headers left a white title (and status bar) on the light page once folded | everyone | they stay coloured |
| The day streak kept its old length after a missed day until the learner played again, then "dropped" to 1; educators could be told to celebrate a run that had ended; leaderboards, teacher analytics, the TV view, exports and the tutor used the same stale number | learners, educators, exports | every place that shows or sorts by the streak uses the live one (0 after a missed day); the best streak, XP, stickers and showcase milestones are unchanged |
| The educator's "streak was broken" alert could never fire (it waited for a stored streak of 0) | educators | fires once per broken run of 2+ days |
| The score animation ran on a closed screen when the result was left within 200 ms | every game | checks the screen is still open |
| **Found in the tablet's sync test:** stars, words learned, category progress and Star Shop spending were saved on the tablet only; a class learner's online copy lagged until their next game (35 stars on the tablet, 25 online) | learners in a class, and their teachers' views | every change goes through the same save-and-sync path as a game result |
| **Found on the real tablet:** "Turn sound up" said it worked, but the Honor's speaker stayed silent (the tablet ignores a direct volume setting) | some Android tablets | steps the volume like the volume keys and shows the system panel; on the Honor: 0 → 5 of 15 |
| **Security review:** a stranger with only a child's handle could make themselves the child's "parent" and approve a friendship (or write it themselves), and rename someone else's learner; anyone with a learner's id could list their achievements and purchases | learners, children above all (live rules) | fixed in `firestore.rules` and tested; **deployed** (live 21:35 on 12 October) and checked live ([security.md](security.md)) |
| A learner's inbox showed messages from people who were not their friends, teachers or family as a read-only thread, and the Messages badge counted them (the database delivers a message to any known profile) | learners | a learner sees only their contacts and people they have written to |
| On a phone held sideways, the date pickers overflowed while the keyboard was still on screen (the landscape walk caught it on the birth date) | sideways phones | the keyboard is closed, and has left, before a date picker opens |
| **Security review, part 2:** anyone who owned some profile could set or overwrite any child's time limit, alarms, routines, routine actions and unlocks; any signed-in user could read and write the notes teachers and parents keep about a learner | children; every learner with notes (live rules) | only the learner's own device and their own teachers and parents (`mayGuide`); deployed at 00:02 on 13 October, after an educator link was filed for each of the 143 existing relationships (`tool/educator_links_backfill.py`); checked live |
| Any device could file a test (assignment) naming a learner | learners | a learner's app takes assignments only from their own teachers and parents |
| "Category mastery" goals and the student detail screen counted an accuracy average as words learned | learners with category goals; educators | both count words learned |
| **Found on the phone emulator:** offline, the FSL button on a word that *has* a recorded sign said "Sign coming soon", the promise meant only for the 33 unrecorded words | learners offline | it says the sign needs the internet; the 33 keep "Sign coming soon" |

## New

- **Landscape and resizable windows** on phones and tablets (Android split
  screen, freeform and resizable windows; iPad Split View, Slide Over, Stage
  Manager). **Settings → Screen orientation** (per profile): turns with the
  device, always portrait, or always landscape. Gaze Control keeps the
  screen still while its camera runs. Android 16 ignores orientation
  requests on large screens unless the app keeps
  `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY`, so that property stays
  (until targetSdk 37); iPadOS decides the orientation for an app that
  shares the screen.
- **"Your device sound is off"**: a small note at the top of the screen when
  the app speaks while the media volume is at zero, for learners who listen
  to the words (Visual Impairment or Voice-Guided Navigation, by default;
  **Settings → Tell me when the sound is off** for anyone). It never blocks
  the screen, goes by itself, offers **Turn sound up** on Android (a third of
  the way, with the system volume panel), **OK**, or **Don't remind me**, and
  is announced to screen readers, which speak on their own volume.
- **Bluetooth game controllers on iPhone and iPad** (Apple's GameController
  framework, same wire format as Android).
- **Firebase App Check**, compiled in and switched off: it needs paid store
  accounts to mean anything (see [security.md](security.md)).
- **Android CI** on GitHub Actions: analyze, the whole test suite, release
  APKs with checked manifests, and walkthroughs on phone and tablet
  emulators in both orientations. The iOS CI also walks both iPhones
  sideways. The runner has no GPU: with Flutter's Impeller renderer on its
  software Vulkan the emulator itself died within seconds, so the CI walk
  draws with Skia (`--no-enable-impeller`). Real devices keep Impeller.
- **Walkthrough options:** `WALK_ORIENTATION=landscape|portrait`,
  `WALK_DEVICE=true` (Word Hunt photo, Sign It recording, Gaze camera,
  speech), `WALK_SCREENSHOTS=false`; Android screenshots are scaled to keep
  the app's memory in check.
- **Google Play upload key** (free `keytool`): Play builds are signed with
  it automatically; the website key is untouched (see "Signing" in
  [store/README.md](store/README.md)).
- **The 33 unsigned words stay placeholders** by the project owner's decision
  ("Sign coming soon"); a test keeps the recording checklist and the app's
  unsigned words identical. [fsl_signs_plan.md](fsl_signs_plan.md) is the
  plan for adding them later (app and website, free tools).
- **Parent-teacher notes are private** (rules live since 13 October): only
  the learner's own device and their own teachers and parents can read or
  write them. A teacher's or parent's app records which of their classes or
  family groups links them to a learner (when it opens the notes and when it
  loads the roster), and the rules check that membership again on every
  read ([security.md](security.md)). The same check guards a child's time
  limits, alarms, routines and unlocks.
- **Release safety tools:** `tool/release_artifact_scan.py` fails if an
  APK, bundle or IPA carries keys, passwords, test-only code, learner data or
  paths from the build PC, or is debuggable; `tool/osv_check.py` checks the
  app's Dart packages against the free OSV vulnerability database. The
  repository now ignores key, password, provisioning and Hive files anywhere.
- **Docs:** [README](../README.md), [security.md](security.md),
  [fsl_recording_guide.md](fsl_recording_guide.md),
  [ios_testing.md](ios_testing.md) (free iPhone/iPad testing and its limits),
  store notes, and the platform facts in `capstone_thesis.md`.

## Checks

The published build is `e53cca6`. Rows marked *release candidate* were run
on `fc7262a` on 12 October, before the last three fixes (educator links,
category goals, the offline sign message). The final checks, device by
device, are in [release-1.4.0-verification.md](release-1.4.0-verification.md).

| Check | Result |
|---|---|
| Unit and widget tests, **published code** (`e53cca6`, Android CI run 38283913034) | **5,260 passed**, 0 failed; `flutter analyze` no issues; release APKs (debug-signed on CI) built; walkthroughs on the phone and the tablet emulator, upright and sideways: 58 screens / 0 problems each |
| Unit and widget tests (`flutter test`) | **5,252 passed**, 0 failed on the release candidate (`fc7262a`, GitHub's Linux runner); 5,249 on this PC before the last three tests were added (1.3.0: 5,094) |
| `flutter analyze` | no issues |
| Firestore rules, local emulator | 32 + 119 + 14 + 91 = 256 checks passed on the deployed rules. The 91 trust checks (memberships, friend requests, achievements, note readers, notes, a child's settings) fail 34 times against the rules live on the morning of 12 October and 17 times against those live before the second deploy, because the attacks they describe worked there: proof that the test sees them |
| Live database, read-only look (12 October) | no sign the membership gap was used: 19 child profiles, no friendship with a child, no friend request carrying a parent's yes, no child in two family groups, every membership's id matches its fields |
| Dart packages against the OSV vulnerability database (`tool/osv_check.py`) | 88 packages, no known vulnerabilities (native Android and iOS libraries are not covered by this check) |
| Firestore rules, **live after the write-claim deploy** (2026-10-12) | write probe on its own throwaway learner: a second device refused the learner's progress, study log and daily challenge (403), the owner allowed (200), everything it wrote deleted; read probe passed |
| Firestore rules, **live after the security deploys** (13 October) | 171 checks with throwaway accounts that delete everything they wrote: trust 27/27 (posing as a parent or teacher, friendships, renames, private data, a child's settings, the real teachers and parents still working), write-claim 6/6, reads 32/32, messaging 63/63, assessments 17/17, shared media 26/26. Each deployed ruleset was read back: identical to the file |
| Phone emulator (Android 16, 1080 x 2400), sideways, with camera and speech checks | 58 screens, 0 problems; Word Hunt photo, Sign It record + replay, Gaze camera streaming, speech spoke, recogniser present |
| Tablet emulator (Android 16, 2560 x 1600), asked for portrait | the request was honoured (1200 x 1600 window); 58 screens; Word Hunt, Gaze and speech fine (Sign It's sign video did not load in time over the emulator's network) |
| **iOS on GitHub Actions, release candidate** (run 38227394474, `fc7262a`) | unsigned IPA and simulator build; walkthroughs on iPhone SE, iPhone 16 Pro Max, iPad mini and iPad 13", **each upright and sideways**: 58 screens / 0 problems on all eight. Device checks on the iPhone 16 Pro Max (no camera): Word Hunt and Sign It say so, Gaze stops at "no camera", Gaze Control's face detector found the face (head turn -0.2), the sound level read through the iOS channel, 0 of 64 notifications pending |
| iOS on GitHub Actions (run 38200672991, before the review) | the same eight walkthroughs, 58 / 0 each |
| iOS on GitHub Actions (earlier: 38156484024, 38136152361) | unsigned IPA; walkthroughs passed on iPhone SE and iPhone 16 Pro Max upright **and sideways**, iPad mini and 13" iPad; Firebase smoke test passed |
| Android on GitHub Actions, release candidate (run 38227394416, `fc7262a`) | all six jobs pass: analyze, 5,252 tests, release APKs with their manifests checked, four walkthroughs (phone and tablet, upright and sideways) 58 screens / 0 problems each |
| Android on GitHub Actions (run 38219951241, `ba43164`) | the sideways phone walk failed once: the date picker overflowed under a keyboard the slow emulator showed 2.5 s late (fixed in `2f99a6a`, then green in every run) |
| Android on GitHub Actions, device checks (run 38198512241) | all six jobs pass. Phone with cameras: Word Hunt photo, Sign It record + replay, Gaze streaming, the face detector finds the face in the still photo (head turn 0.4), speech, recogniser; 58 screens / 0 problems. Tablet **without** a camera: Word Hunt and Sign It say so, Gaze stops at "no camera", face detector, speech, recogniser; 58 / 0 |
| Android emulators on this PC, same checks | phone with cameras and tablet without: 58 screens / 0 problems each, the same results |
| Android on GitHub Actions (earlier runs 38156484030, 38141730593) | analyze, all tests and the release APKs with their manifest checks pass; walkthroughs on the phone and the tablet emulator (Android 14), upright and sideways: 58 screens and 0 problems each, no crash in the logs. The upright phone also took a Word Hunt photo, recorded and replayed Sign It, streamed Gaze Control's camera (12 frames), spoke, and found a speech recogniser |
| Release build, release candidate (2026-10-12 20:38, `fc7262a`) | website APKs (arm64 / arm32 / universal) and the Play APK + bundle: application ids, permissions, version 1.4.0 (13), 16 KB alignment all checked; **signers checked**: website APKs on the original key (`AF:D7…2B:A8`, so installed copies update), Play APK and bundle on the upload key (`CN=FlashLearn PWD`, `78:8C…C3:16`). SHA-256: arm64 `4ca9e7c0…`, arm32 `69327f0d…`, universal `3692e106…`, since replaced by the published build |
| **Release build, published** (2026-10-13 01:37, `e53cca6`) | the same checks, signers included. SHA-256: arm64 `dceb8be1…`, arm32 `1ab1c6d5…`, universal `da298e83…` (`build/release-v1.4.0/SHA256SUMS.txt`); the files on the GitHub Release are byte-identical |
| Release files scanned (`tool/release_artifact_scan.py`) | all five clean: no keys, passwords, private keys, test-only code or fixtures, Hive data, build-PC paths, nothing debuggable; a deliberately bad control file is caught |
| Build safety | a debug-mode package fetch (an editor's automatic `pub get`, a test run) can put the test-only plugin back into the generated registrant, which failed two release builds, the second time seconds after the build had started. [`tool/build_release.sh`](../tool/build_release.sh) regenerates the file in release mode before each build, builds with `--no-pub`, keeps the file read-only while each build runs, checks the manifests, signers and contents, and refuses to write over a folder of published files. A trial run on 13 October built and passed all five files: the website APKs and the Play APK came out byte-identical to the published ones (the bundle differs only in the build time R8 records and the signature over it) |
| Upgrade 1.2.7 → 1.4.0 (universal, emulator) | profile, XP and stars kept; Screen orientation reads "turns with the device" and Landscape turns the app |
| **Real tablet** (Honor NDL W09, Android 16, 1200 x 1920), release build installed over 1.2.7 with `adb install -r` | all 19 profiles kept; a learner's level, XP, streak, words and stars identical before and after. Upright and sideways: Home, Games, Memory Match (all 16 Hard cards), flashcard viewer, Progress, sheets. Word Hunt took a photo with the back camera and analysed it; Sign It played the sign video, recorded with the front camera and replayed the take; Gaze Control streamed the front camera; spoken progress played through the speech engine (the tablet's media volume was at 0, so it was silent on the device); a speech recogniser is installed. Portrait chosen in Settings held while the tablet was sideways (Android 16 shows the app in a tall window). Settings put back afterwards |
| **Real tablet, sync test** (12 October, after the write-claim rules went live) | a class learner's game round reached the cloud straight away (progress, study time in `active_time_logs`); stars, words and Star Shop spending did not until the fix above, then did (cloud 150 → 165 stars at once). The daily-challenge record and session logs stay on the tablet by design |
| **Real tablet, "Turn sound up"** | before the fix it said it worked and the speaker stayed at 0; after it: 0 → 5 of 15 with the system volume panel. The owner's volume was put back to 0 |
| **Real tablet, release candidate** (`fc7262a`, installed with `adb install -r` at 20:41) | every profile kept; the "sound is off" note showed (media volume 0) and closed; a class learner's home (13 words, 150 of 165 stars, as in the cloud), Messages tile without a stray count, and the inbox listing their teacher with the old history; the teacher's home (7 students) and Parent Notes opened normally while the reader records were refused by today's rules, silently, as expected until the new rules are deployed; no app error in the log. Tablet settings and volume put back |
| Website (local server, release candidate, 12 October evening) | download page and `version.json` regenerated from the final APKs (SHA-256s and sizes match; service worker cache v32); audit 1,378 passed / 0 failed (a first run lost one image to a socket-buffer error on this PC while a build was running; the rerun was clean); contrast sweep 0 failures in all six display modes; every external link answers (the v1.4.0 download links are skipped: they work once the GitHub Release exists) |
| **Phone emulator** (Android 16, 1080 x 2400), the release APK (13 October) | with no network: first start, onboarding, a Guest profile with Hearing Impairment settings, flashcards, joining a class (asks to go online), a whole Word Match game. This run found the offline sign message above; with the fixed APK: updated in place with the profile kept; offline the sign "needs the internet"; online it downloads and plays; offline again it replays the saved copy |
| **Real tablet, published build** (`e53cca6` arm64, installed with `adb install -r` at 02:05 on 13 October) | installed over the candidate with the data kept, version 1.4.0 (2013); no crash or app error in the log. **Its on-screen checks are still to do**: the tablet was locked |
| Website, **live** (13 October, after the deploy) | audit 1,378 passed / 0 failed against the public site; every download link, checksum and `version.json` entry matches the GitHub Release |

## Published (13 October 2026)

1. Firestore rules: the write-claim fix (12 Oct), the who-is-whose fix
   (b4d1cbd, live 21:35 on 12 Oct) and the notes and a child's settings
   (adbaf21, 00:02 on 13 Oct, after the educator-link backfill); 171 live
   checks pass ([security.md](security.md)).
2. GitHub Release v1.4.0 with the three website APKs (01:59), then the
   website (02:01); both checked live against the build.
3. Branches merged (02:03): `main`, `work/v1.4.0` and `work/sign-interpreter`
   at ba8f2f2, without force-pushing.

Still to do, by choice or with the owner: store uploads (Google Play
Console, Apple Developer Program; [store/README.md](store/README.md)), the
optional settings in [security.md](security.md) (Dependabot alerts,
restricting the Firebase API keys), and the owner's steps in the
verification report.

## Not possible in this round

- **Real-device tests that need a person:** on the Honor, the microphone
  (its permission was given "only this time" and has lapsed, and checking
  recognition needs someone to speak) and a Bluetooth game controller (the
  X3 has to be switched on and paired) were not tried this round. The
  cameras, speech output, sync, the sound note and the release candidate's main
  screens were (see Checks). No iPhone or iPad was available, so Gaze
  Control, controllers and camera features on iOS are checked by code,
  tests and the simulator only.
- **The 33 missing FSL signs** stay "Sign coming soon" placeholders until the
  project owner says otherwise; nothing was recorded, generated or
  downloaded for them. The guide and tools are kept for later.
- **App Check enforcement** needs the paid store accounts, and can never be
  enforced while website APKs are in use.
- **Real iPhones and iPads:** none is available. Everything iOS is checked on
  simulators (see [ios_testing.md](ios_testing.md) for what that does and
  does not prove). iPads are now walked sideways too, in a test-only build
  without Split View.

## Build warnings looked into

Every Android build prints that the app and eight plugins (audioplayers_android,
camera_android_camerax, firebase_analytics, flutter_tts, package_info_plus,
share_plus, speech_to_text, video_player_android) "apply the Kotlin Gradle
Plugin", which "future versions of Flutter" will refuse. Nothing is broken
today, and no removal date has been set. The fix is Flutter's "built-in Kotlin",
which needs **Android Gradle Plugin 9 and Flutter 3.47 or later**; this project
is on Flutter 3.44 (AGP 8.11), where it cannot be switched on, and updating
plugins alone would not remove the warning. Changing the build toolchain in a
release candidate is not safe, so 1.4.0 keeps it. The plan for the next
toolchain update: move to Flutter 3.47+ and AGP 9, remove `kotlin-android`
and `kotlinOptions` from `android/app/build.gradle.kts` (use
`kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }`), update the eight
plugins to versions that support built-in Kotlin, set
`android.builtInKotlin=true`, and run the full checks
([Flutter's guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)).

**Flutter 3.47.7 tried on a side branch** (12 October; the newest stable,
Dart 3.13.5, installed separately so the project's 3.44 was untouched; local
branch `work/toolchain-3.47`, not pushed or merged): `flutter pub get` moved
five SDK-pinned packages, `flutter analyze` found no issues, and all 5,237
tests passed (on the code before the security review). The Android app
builds with it (a debug APK), and the "applies the Kotlin Gradle Plugin"
warning is gone, but 3.47.7 warns instead that its support for this
project's Gradle 8.14, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20
"will soon be dropped": it wants Gradle 9.1, AGP 9.0.1 and Kotlin 2.3.20.
So moving to 3.47 is possible, but it brings a whole Android build-tool
upgrade with it, and it changes the compiler under every screen. **Recommendation: ship 1.4.0 on 3.44 and make the move,
with AGP 9, the first change of the next version**, with the full checks and
a tablet run.

## Recommended next

- **Copy both signing passwords** (`key.properties`, `play-upload.properties`)
  into a password manager or onto paper, and the backup folder to a USB
  drive. Both keys are backed up in `Documents\FlashLearn PWD - signing key
  backup` (checked identical to the originals on 12 October), but the
  passwords are, by design, not in that folder: today they exist only on
  this PC, and without them the backups cannot sign anything. The folder is
  also on the same PC.
- **Built-in Kotlin** with the next toolchain update (above).
- **Two-phase security changes for a later version** (both need the app to
  send something first, then a rules change once older apps have updated):
  joining a class or family group should prove the join code, and messages
  should need a link (friends, class or family) in the rules themselves.
