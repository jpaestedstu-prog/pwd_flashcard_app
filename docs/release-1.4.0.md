# FlashLearn PWD 1.4.0: what changed and how it was checked

Branch `work/v1.4.0`, built on the unpublished 1.3.0 (`work/ios-and-stores`).
Version **1.4.0 (13)**. Nothing in this round has been published: no store
upload, no GitHub Release, no website deploy and no Firestore rules deploy.
Each needs the project owner's go-ahead (see "Waiting for approval").

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
- **Docs:** [README](../README.md), [security.md](security.md),
  [fsl_recording_guide.md](fsl_recording_guide.md), store notes.

## Checks

| Check | Result |
|---|---|
| Unit and widget tests (`flutter test`) | **5,220 passed**, 0 failed on the final code, on this PC and on GitHub's Linux runner (1.3.0: 5,094) |
| `flutter analyze` | no issues |
| Firestore rules, local emulator | 20 + 118 + 14 checks passed |
| Phone emulator (Android 16, 1080 x 2400), sideways, with camera and speech checks | 58 screens, 0 problems; Word Hunt photo, Sign It record + replay, Gaze camera streaming, speech spoke, recogniser present |
| Tablet emulator (Android 16, 2560 x 1600), asked for portrait | the request was honoured (1200 x 1600 window); 58 screens; Word Hunt, Gaze and speech fine (Sign It's sign video did not load in time over the emulator's network) |
| iOS on GitHub Actions (final code: run 38156484024; also 38136152361) | unsigned IPA; walkthroughs passed on iPhone SE and iPhone 16 Pro Max upright **and sideways**, iPad mini and 13" iPad; Firebase smoke test passed |
| Android on GitHub Actions (final code: run 38156484030; also 38141730593) | analyze, all tests and the release APKs with their manifest checks pass; walkthroughs on the phone and the tablet emulator (Android 14), upright and sideways: 58 screens and 0 problems each, no crash in the logs. The upright phone also took a Word Hunt photo, recorded and replayed Sign It, streamed Gaze Control's camera (12 frames), spoke, and found a speech recogniser |
| Release build | website APKs (arm64 / arm32 / universal) and the Play APK + bundle: application ids, permissions, version 1.4.0 (13), 16 KB alignment all checked; rebuilt on 2026-10-12 with every fix above; SHA-256s in `build/release-v1.4.0/SHA256SUMS.txt` |
| Upgrade 1.2.7 → 1.4.0 (universal, emulator) | profile, XP and stars kept; Screen orientation reads "turns with the device" and Landscape turns the app |
| **Real tablet** (Honor NDL W09, Android 16, 1200 x 1920), release build installed over 1.2.7 with `adb install -r` | all 19 profiles kept; a learner's level, XP, streak, words and stars identical before and after. Upright and sideways: Home, Games, Memory Match (all 16 Hard cards), flashcard viewer, Progress, sheets. Word Hunt took a photo with the back camera and analysed it; Sign It played the sign video, recorded with the front camera and replayed the take; Gaze Control streamed the front camera; spoken progress played through the speech engine (the tablet's media volume was at 0, so it was silent on the device); a speech recogniser is installed. Portrait chosen in Settings held while the tablet was sideways (Android 16 shows the app in a tall window). Settings put back afterwards |
| Website (local server) | audit 1,378 passed / 0 failed; contrast sweep 0 failures in all six display modes |

## Waiting for approval

1. ~~`firebase deploy --only firestore:rules`~~: approved and deployed on
   2026-10-12, then checked live (see [security.md](security.md)).
2. Publishing 1.4.0: GitHub Release with the three APKs, then the website.
3. Merging `work/v1.4.0` into `work/sign-interpreter` / `main`.
4. Store uploads, after the Google Play Console and Apple Developer
   accounts exist ([store/README.md](store/README.md)). The Play bundle must
   first be built with a separate upload key: the website key's certificate
   is named `CN=Android Debug`, which Play refuses ("Signing" in the store
   notes).

## Not possible in this round

- **Real-device tests:** the Honor tablet was tested once it was unlocked
  (see Checks); no iPhone or iPad was available, so Gaze Control,
  controllers and camera features on iOS are checked by code, tests and the
  simulator only. On the tablet the microphone was not tried: its
  permission had been given "only this time" and has lapsed, and checking
  recognition needs someone to speak.
- **The 33 missing FSL signs** need a person who signs FSL; the guide and
  tools are ready, and offline sign packs were already in the app.
- **App Check enforcement** needs the paid store accounts, and can never be
  enforced while website APKs are in use.
- **iPad landscape walkthrough:** iPadOS ignores an app's orientation request
  while the app supports Split View, so only the iPhones are walked sideways
  on CI; iPad landscape sizes are covered by the widget tests.

## Recommended next

- **A "sound is off" hint for learners who rely on speech.** With the
  tablet's media volume at 0, every spoken word is silent and nothing tells
  the learner why. A blind learner cannot read an on-screen hint, and
  raising the volume automatically is a product decision, so this is left
  to the project owner.
- **The thesis text** in `docs/capstone_thesis.md` still describes the app
  as portrait-only and Android-only (its "locked to portrait" and "Android
  only" passages); worth updating when the chapters are next revised.
