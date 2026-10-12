# FlashLearn PWD

An accessible flashcard and learning app for learners with disabilities
(visual, hearing, motor, cognitive and multiple disabilities), their teachers
and their parents. Words come in English and Filipino with Filipino Sign
Language (FSL) videos, games and stories. A learner can use touch, voice,
head movement (Gaze Control), switch scanning or a game controller. Built
with Flutter as a capstone thesis project. It runs entirely on free tiers.

- **Website and download:** https://jpaestedstu-prog.github.io/pwd_flashcard_app/
- **Privacy policy:** [website/privacy.html](website/privacy.html)

## Platforms

| | How it is delivered | Notes |
|---|---|---|
| Android phones and tablets (Android 10+) | APK from the website (`com.example.pwdpwdpwd`) | updates itself from the website |
| Android, Google Play | `--dart-define=FLASHLEARN_DISTRIBUTION=play` (`io.github.jpaestedstuprog.flashlearnpwd`) | store rules applied: no self-update, no `USE_EXACT_ALARM` |
| iPhone and iPad (iOS 15.5+) | built on GitHub Actions (free macOS runners) | needs an Apple Developer account to sign and publish |

Every screen works in portrait and landscape, in split screen and in
resizable windows. A profile can keep one orientation (Settings → Screen
orientation).

## What is in it

- **Learning:** flashcards with pictures, audio and FSL video; 15 games (FSL
  practice has three modes of its own); stories
  with FSL tracks; daily challenge; spaced review; learning paths; Word Hunt
  (find real objects with the camera); Sign It (practise signing on camera).
- **Accessibility by profile:** themes and presentation per disability, text up
  to 2× size, high contrast, dyslexia mode, reduced or slow motion, spoken
  navigation, captions and vibration in place of sound.
- **Hands-free and alternative input:** Gaze Control (head turns and blinks
  with the front camera), switch scanning, voice commands, Bluetooth game
  controllers (Android and iOS).
- **For teachers and parents:** classes and home groups, dashboards,
  assessments with media, reports and certificates (PDF), routines ("My Day")
  that can hold the device, alarms, messages with parent approval, TV Cast.
- **Offline first:** everything works without internet; FSL clips can be saved
  as offline packs; the cloud is a mirror for sharing between devices.

## Building

Flutter **3.44.0** (Dart 3.12). The SDK on the project PC is at `C:\src\flutter`.

```
flutter pub get
flutter run                          # debug build on a connected device
flutter build apk --release --split-per-abi
flutter build appbundle --release --dart-define=FLASHLEARN_DISTRIBUTION=play
```

Android builds are signed with the project key kept outside the folder
([docs/signing.md](docs/signing.md)); without it the build stops on purpose.
iOS builds: see [docs/store/README.md](docs/store/README.md).

## Testing

```
flutter analyze
flutter test                         # ~5,250 unit and widget tests
```

- **On-device walkthrough** (emulators and simulators only, because `flutter drive`
  uninstalls the app when it finishes):
  `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_walkthrough_test.dart --dart-define=FLASHLEARN_OFFLINE=true -d <device>`
  Options: `--dart-define=WALK_ORIENTATION=landscape` (or `=portrait`) walks
  every screen that way round; `WALK_DEVICE=true` also takes a Word Hunt photo,
  records Sign It, streams Gaze Control and checks speech (an emulator's
  "emulated" cameras are enough); `WALK_SCREENSHOTS=false` skips screenshots.
- **Security rules**, against the local Firestore emulator:
  see [docs/security.md](docs/security.md#testing-the-rules).
- **Continuous integration** (GitHub Actions, free for this public repository):
  - [Android](.github/workflows/android.yml): analyze, the whole test suite, release
    APKs with their manifests checked, and walkthroughs on a phone and a tablet
    emulator in both orientations.
  - [iOS](.github/workflows/ios.yml): the unsigned IPA and walkthroughs on four
    simulators (small and large iPhone, iPad mini, 13-inch iPad), each upright and
    sideways.
- **Before publishing**: `python tool/release_artifact_scan.py <apks, aab, ipa>`
  (no keys, passwords, test-only code or learner data inside, nothing
  debuggable) and `python tool/osv_check.py` (the Dart packages against the
  free OSV vulnerability database).

## Project layout

```
lib/
  core/        services (notifications, sync, orientation, App Check), theme, accessibility
  data/        models, Hive (local) and Firestore (cloud) repositories, seed words
  features/    one folder per feature (games, gaze_control, routine, assessment, ...)
  navigation/  go_router routes and shells
  widgets/     shared widgets
android/ ios/  platform code (the game-controller bridges, routine alarms, TV Cast service)
integration_test/  the cross-platform walkthrough
test/          unit and widget tests (support/ holds the device x font-size matrices)
tool/ tools/   rules tests, FSL publishing, website and store-graphics generators
website/       the project website (GitHub Pages)
docs/          documentation (below)
```

## Documentation

| | |
|---|---|
| [docs/store/README.md](docs/store/README.md) | Publishing on Google Play and the App Store: forms, permissions, screenshots |
| [docs/security.md](docs/security.md) | Security rules, App Check, known trade-offs |
| [docs/signing.md](docs/signing.md) | The signing key and its backup |
| [docs/multi_device_sync.md](docs/multi_device_sync.md) | How data moves between devices |
| [docs/fsl_recording_guide.md](docs/fsl_recording_guide.md) | Recording the remaining FSL signs |
| [docs/fsl_signs_plan.md](docs/fsl_signs_plan.md) | The 33 words still without a sign, and the plan for adding them |
| [tools/README.md](tools/README.md) | Publishing FSL videos (free GitHub Releases hosting) |
| [FREE_TIER_FEATURES.md](FREE_TIER_FEATURES.md) | Every feature and the free service behind it |

## Free tier only

The app uses Cloud Firestore and Anonymous Authentication on Firebase's free
Spark plan. Analytics and Crashlytics are opt-in and off by default. There is
no Cloud Storage, no Cloud Functions and no billing account. Media is hosted
on GitHub Releases and Cloudinary's free plan, and CI runs on GitHub's free
runners for public repositories.
