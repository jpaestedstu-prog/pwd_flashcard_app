# FlashLearn PWD 1.4.0: what changed and how it was checked

Branch `work/v1.4.0`, built on the unpublished 1.3.0 (`work/ios-and-stores`).
Version **1.4.0 (13)**. Nothing in this round has been published: no store
upload, no GitHub Release, no website deploy and no Firestore rules deploy.
Each needs the project owner's go-ahead (see "Waiting for approval").

## Bugs fixed

| Problem | Who it hit | Fix |
|---|---|---|
| **Word → Sign** answers broke ("infinite height") as soon as their sign videos loaded | every learner, since 2026-09-10 | the controller focus ring no longer stretches a list row (`GamepadFocusable`) |
| A stranger who knew a learner's id could create that learner's cloud **progress, streak, tutorial flag, equipped item or study logs** first, locking the learner's own device out of them | every synced learner (live rules) | `mayStartFor()` in `firestore.rules`; **not deployed yet** |
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
- **Bluetooth game controllers on iPhone and iPad** (Apple's GameController
  framework, same wire format as Android).
- **Firebase App Check**, compiled in and switched off: it needs paid store
  accounts to mean anything (see [security.md](security.md)).
- **Android CI** on GitHub Actions: analyze, the whole test suite, release
  APKs with checked manifests, and walkthroughs on phone and tablet
  emulators in both orientations. The iOS CI also walks both iPhones
  sideways.
- **Walkthrough options:** `WALK_ORIENTATION=landscape|portrait`,
  `WALK_DEVICE=true` (Word Hunt photo, Sign It recording, Gaze camera,
  speech), `WALK_SCREENSHOTS=false`; Android screenshots are scaled to keep
  the app's memory in check.
- **Docs:** [README](../README.md), [security.md](security.md),
  [fsl_recording_guide.md](fsl_recording_guide.md), store notes.

## Checks

Filled in from the final runs: see the bottom of this page.

## Waiting for approval

1. `firebase deploy --only firestore:rules` (the security fix above).
2. Publishing 1.4.0: GitHub Release with the three APKs, then the website.
3. Merging `work/v1.4.0` into `work/sign-interpreter` / `main`.
4. Store uploads, after the Google Play Console and Apple Developer
   accounts exist ([store/README.md](store/README.md)).

## Not possible in this round

- **Real-device tests:** the Honor tablet was connected but locked behind
  its screen lock the whole time, and no iPhone or iPad was available. The
  camera, microphone and speech checks ran on Android emulators with
  emulated cameras instead. Gaze Control, controllers and camera features on
  iOS are checked by code, tests and the simulator only.
- **The 33 missing FSL signs** need a person who signs FSL; the guide and
  tools are ready, and offline sign packs were already in the app.
- **App Check enforcement** needs the paid store accounts, and can never be
  enforced while website APKs are in use.
- **iPad landscape walkthrough:** iPadOS ignores an app's orientation request
  while the app supports Split View, so only the iPhones are walked sideways
  on CI; iPad landscape sizes are covered by the widget tests.
