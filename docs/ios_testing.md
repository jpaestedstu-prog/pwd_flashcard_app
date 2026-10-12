# Testing on iPhone and iPad without owning one

The project has no iPhone, iPad or Mac, and no paid Apple developer account.
This page records what is tested for free, what that proves, and what only a
real Apple device can show. A simulator runs the app's code on a Mac; it does
not prove anything about a real device's camera, Bluetooth, microphone or
speed.

## What runs on every change (free)

GitHub Actions gives public repositories free macOS machines with Xcode and
its iOS simulators ([`.github/workflows/ios.yml`](../.github/workflows/ios.yml)).
On every push:

| Check | Devices | What it shows |
|---|---|---|
| Unsigned release build (IPA) | build only | the app, its plugins and the native code (game controllers, sound level, Gaze Control) compile for iOS |
| Firebase smoke test | iPhone 16 Pro Max | sign-in and the online database work from iOS |
| Walkthrough, 58 screens | iPhone SE, iPhone 16 Pro Max, iPad mini, iPad 13" | every screen opens without an error, overflow or blank space, at each size |
| Same walkthrough sideways | all four | the landscape layouts. iPads only turn for a test build that opts out of Split View (`UIRequiresFullScreen`, added by the workflow, never in a release); the layouts are the same |
| Device checks | iPhone 16 Pro Max | with no camera (a simulator has none): Word Hunt and Sign It say so plainly and Gaze Control stops at "no camera", all without an error; Gaze Control's face detector (Google ML Kit, iOS build) finds the face in a still photo of the signer; the speech engine is asked to speak; iOS's limit of 64 waiting notifications is respected |

Unit and widget tests (more than 5,200) also cover the iOS-specific logic:
the front-camera mirroring fix for Gaze Control, the notification budget, the
game-controller bridge's button mapping on the Dart side, and every screen
at iPhone and iPad sizes in both orientations.

## What a simulator cannot show

Only a real iPhone or iPad can confirm these. None has been tested on one.

- **Camera:** Word Hunt photos, Sign It recording, and Gaze Control following
  a real face (including the mirroring fix for the iOS front camera).
- **Bluetooth game controllers** through Apple's GameController framework.
- **Microphone and speech recognition** for voice commands (the simulator
  would stop at a permission dialog nobody can answer on CI).
- **Notifications arriving** on time, with sound, on a locked device.
- **Speed and battery** on real hardware, and the "sound is off" note
  reading the real volume buttons.
- **App Store signing**, TestFlight and App Check (they need the paid Apple
  Developer account).

## Free ways to go further

| Option | Cost | What it adds | What it needs from you |
|---|---|---|---|
| **A borrowed Mac + iPhone/iPad** with Xcode and a free Apple ID ("Personal Team") | free | the real camera, controllers, microphone and notifications; the app stays installed for 7 days | someone who can lend both for an afternoon; open `ios/Runner.xcworkspace`, pick the free team, press Run |
| **Appetize.io** free tier | free (a small monthly allowance of minutes) | click through the iPhone/iPad app in a web browser, for checking screens by eye | a free account; upload the simulator build from the workflow's artifacts |
| **BrowserStack Open Source Program** | free if accepted | real iPhones and iPads in a browser, including a camera image feed | an application for the public repository |
| Firebase Test Lab (iOS) | skipped | real devices, but iOS tests must be signed with a paid Apple account, and Test Lab shuts down on 30 September 2027 | — |

The paid routes (Apple Developer Program, TestFlight, paid device clouds) are
not used.

## Results

See [release-1.4.0.md](release-1.4.0.md), "Checks", for the latest run.
