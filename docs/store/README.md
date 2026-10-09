# Publishing FlashLearn PWD on Google Play and the App Store

Everything the app itself needs for both stores is done and tested. What is
left is account work in the two store consoles, and **each store charges a
fee for its developer account** — the only costs in this whole process:

| | Google Play | Apple App Store |
|---|---|---|
| Developer account | Google Play Console — **US$25 once** | Apple Developer Program — **US$99 every year** |
| Free alternative | none | Apple waives the fee for some accredited schools and non-profits in some countries — ask the school to look up "Apple Developer Program fee waiver" on developer.apple.com |
| What you upload | an Android App Bundle (`.aab`) | an archive signed with your Apple team |
| App id (permanent after the first upload) | `io.github.jpaestedstuprog.flashlearnpwd` | `io.github.jpaestedstuprog.flashlearnpwd` |
| Updates | by Play — the app's own "Check for updates" is switched off | by the App Store — switched off too |

The website APKs keep their old id (`com.example.pwdpwdpwd`) so every tablet
that already has the app keeps receiving updates and keeps its profiles. The
Play copy is a **separate app** on a device: a tablet with both would have two
icons and two sets of profiles. Profiles move between them with the recovery
code (Settings → Data → Cloud Recovery Code).

Listing text (English and Filipino) is in [listing.md](listing.md). Graphics:
`graphics/` (made by `python tools/store_graphics_build.py`). Screenshots come
from the automated walkthrough — see "Screenshots" below.

---

## Building the store copies

**Google Play** (on this PC):

```
flutter build appbundle --release --dart-define=FLASHLEARN_DISTRIBUTION=play
```

Output: `build/app/outputs/bundle/release/app-release.aab`. That one flag gives
the bundle the Play application id, drops `USE_EXACT_ALARM` (see below) and
hides the website update check. It is signed with the same private key as the
website APKs (`~/.flashlearn-signing`), which becomes your Play **upload key**.

**iPhone and iPad** need a Mac to sign. There is none here, so every push to
`work/ios-and-stores` builds the app on GitHub's macOS machines (free for a
public repository — `.github/workflows/ios.yml`) and tests it on four
simulators. That build is **unsigned**: it proves the app compiles and runs,
but Apple accepts only a signed archive. With an Apple Developer account,
either:

- on any Mac with Xcode 26: open `ios/Runner.xcworkspace` → Runner →
  Signing & Capabilities → pick your Team → Product → Archive → Distribute App
  → App Store Connect; or run `flutter build ipa --release` there; or
- without a Mac: add your App Store Connect API key and signing certificate as
  GitHub repository secrets and add a signing-and-upload step to
  `.github/workflows/ios.yml` (for example with fastlane). The runner stays
  free.

---

## Google Play — what to fill in

Create the app: name **FlashLearn PWD**, default language English (add a
Filipino translation of the listing), App, Free.

**App content**

- *Privacy policy:* https://jpaestedstu-prog.github.io/pwd_flashcard_app/privacy.html
- *Ads:* the app contains no ads.
- *App access:* all features are available without a login. Reviewers can
  choose "Player (with Progress)" or "Guest Player" on the first screen. A
  Student or Child profile needs a class/home-group code: make a Teacher
  profile first, then Home → Share Code → create a class.
- *Content rating (IARC):* educational; no violence, sexual content,
  profanity, drugs, gambling or real-money purchases. **Users can interact:**
  yes — Messages between learners, teachers and parents (friend requests to a
  child need a parent's approval). Shares location: no.
- *Target audience:* includes children under 13 (learners) and adults
  (teachers, parents), so the **Families policy** applies: no ads, the
  advertising ID is removed from the manifest, and Firebase Analytics and
  Crashlytics stay off unless a teacher or parent turns them on in Settings.
- *Data safety* (match `privacy.html`):

  | Data type (Play's name) | Collected | Shared | Why | Optional? |
  |---|---|---|---|---|
  | Name | yes | no | App functionality | yes — a Guest Player sends nothing |
  | User IDs (anonymous sign-in id, message handle) | yes | no | App functionality | yes |
  | Health info (the learner's disability/accessibility preset) | yes | no | App functionality, personalisation | yes |
  | Other info (a learner's birth date) | yes | no | App functionality | yes |
  | Other in-app messages | yes | no | App functionality | yes |
  | Photos, Videos, Voice or sound recordings (lesson media, video answers) | yes | no | App functionality | yes |
  | App interactions, Other user-generated content (progress, notes, mood check-ins, routines) | yes | no | App functionality | yes |
  | Crash logs, Diagnostics | only if an adult opts in | no | Analytics | yes |

  Data is encrypted in transit: yes. Users can ask for deletion: yes — in the
  app (Settings → Data → **Delete this profile**) and on the web at
  https://jpaestedstu-prog.github.io/pwd_flashcard_app/privacy.html#delete
  (Play requires both).
- *Permission declarations Play will ask for:*
  - **Foreground service, type dataSync** — TV Cast keeps serving the lesson
    to the classroom TV while the tablet's screen is off. Play wants a short
    video: start a cast, show the ongoing notification.
  - **Full-screen intent** — a My Day step that locks the app shows its lock
    over the lock screen. Not an alarm or calling app, so Play will not grant
    it by default; the app already asks for it in the routine builder.
  - Exact alarms: the Play build does **not** declare `USE_EXACT_ALARM` (Play
    allows it only for alarm and calendar apps). It keeps
    `SCHEDULE_EXACT_ALARM`, which the user grants under "Alarms & reminders";
    without it, My Day reminders still come, just less precisely timed.

**Testing before production.** A *personal* Play developer account created
after November 2023 must run a **closed test with at least 12 testers for 14
days in a row** before it may publish to everyone. (An organisation account —
for example the school's — does not.) Start the closed test early.

**Signing.** Let Google manage the app signing key (Play App Signing) and use
the existing key as the upload key. Keep `~/.flashlearn-signing` backed up: a
lost upload key can be reset through Play support, a lost website key cannot.

**Graphics:** icon `graphics/play-icon-512.png`, feature graphic
`graphics/play-feature-graphic.png`, at least 2 phone screenshots and, for the
tablet badge, 7-inch and 10-inch tablet screenshots.

---

## Apple App Store — what to fill in

Register the bundle id `io.github.jpaestedstuprog.flashlearnpwd` (no special
capabilities: the app uses no push notifications, iCloud or App Groups), then
create the app in App Store Connect: name **FlashLearn PWD**, primary language
English, SKU `flashlearnpwd`.

- *Category:* **Education**. Do **not** pick the Kids Category for now: it
  forbids third-party analytics (Firebase Analytics/Crashlytics are in the app,
  even though they are off by default) and requires a parental gate on every
  link out of the app.
- *App Privacy:* answer as in the Play table above. The same answers are
  declared in `ios/Runner/PrivacyInfo.xcprivacy` (Apple lists disability under
  **Sensitive Info**). No tracking; nothing is used for advertising.
- *Age rating:* no objectionable content; **in-app messaging: yes**, limited to
  classmates and family, with parent approval for a child's friend requests.
- *Export compliance:* already answered in the app (`ITSAppUsesNonExemptEncryption = NO`
  — only HTTPS and on-device PIN hashing).
- *Account deletion* (guideline 5.1.1(v)): Settings → Data → Delete this profile.
- *Review notes* (paste into App Review Information):

  > No login is needed. On the first screen choose "Player (with Progress)"
  > (or "Guest Player", which keeps everything on the device). Student and
  > Child profiles join a class with a code: create a Teacher profile, then
  > Home → Share Code → create a class, and use that code. Camera features
  > (Word Hunt, Gaze Control, Sign It) and voice commands need a real device.
  > TV Cast needs the iPad and a browser on the same Wi-Fi.

- *Screenshots:* 6.9-inch iPhone (1320 × 2868) and 13-inch iPad (2064 × 2752)
  — the walkthrough's `iphone-large` and `ipad-large` runs capture exactly
  these sizes.
- *TestFlight:* upload a build, add yourselves as internal testers (no review
  needed), then external testers (one short beta review).

---

## What works differently on iPhone and iPad

Checked on the simulators and by reading the code; all of these are iOS
rules, not bugs:

- **My Day locks** cannot pull the app to the front or cover other apps — iOS
  allows no app to do that. A due step arrives as a notification instead. For
  a learner who must stay in the app, an adult can turn on iOS's built-in
  **Guided Access** (Settings → Accessibility → Guided Access).
- **TV Cast** serves the lesson only while FlashLearn is open on screen; iOS
  pauses an app's server in the background.
- **Bluetooth game controllers** (Gamepad settings) are Android-only for now.
- **Reminders:** iOS keeps at most 64 scheduled notifications per app. A very
  large set of routines and alarms can reach that; the app re-plans them every
  time it opens.
- **Updates** come from the App Store; there is no "Check for updates" row.

## Screenshots

`integration_test/app_walkthrough_test.dart` opens every learner screen and
saves a screenshot of each. On a PC with the emulator running:

```
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_walkthrough_test.dart \
  --dart-define=FLASHLEARN_OFFLINE=true -d emulator-5554
```

(screenshots land in `build/walkthrough/`). The iOS ones are artifacts of each
GitHub Actions run (Actions tab → the run → Artifacts). **Never run
`flutter drive` on a tablet with real profiles** — when it finishes it
uninstalls the app, which deletes every profile on that device.

`python tools/store_screenshots_build.py <walkthrough folder> <set name>
[--play]` picks the same eight screens from any device and saves them as
JPEGs in `docs/store/screenshots/<set name>/`. Use `--play` for Google Play
sets: Play refuses a screenshot whose long side is more than twice the short
side, and a 1080 × 2400 phone is 2.22 : 1, so `--play` crops it to 2 : 1. The
sets made so far come from a test profile with no progress yet — retake them
with a profile that has stars, streaks and a routine for a livelier listing.

## Building the iPhone app on a Mac

The project is set up so a Mac only needs Xcode 26, CocoaPods and Flutter
3.44 (`flutter build ipa`, or open `ios/Runner.xcworkspace`). Three settings
in it are deliberate — keep them:

- `pubspec.yaml` → `enable-swift-package-manager: false`. With Swift Package
  Manager on, Flutter mixes it with CocoaPods (Google ML Kit, printing and
  flutter_tts exist only as pods) and the simulator build failed to link.
- `ios/Podfile` → the `post_integrate` hook that removes CocoaPods' empty
  `Pods_Runner.framework` from the app's link phase. Without it a Debug
  simulator build fails: "Framework 'Pods_Runner' not found" (Xcode never
  scheduled that umbrella target; every real pod is linked anyway).
- `ios/Podfile` → iOS 15.5 minimum (ML Kit's), and Firestore built from
  source. The precompiled Firestore that FlutterFire suggests cannot be
  installed at this version (a broken archive link), so a clean first build
  takes about 20 minutes; later builds are quick.
