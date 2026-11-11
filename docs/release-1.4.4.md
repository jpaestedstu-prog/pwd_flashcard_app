# FlashLearn PWD 1.4.4: easier to read, hear and reach

1.4.4 gathers eleven test builds (18 to 28) made after 1.4.3 at the owner's
request, from 27 October to 11 November 2026. The owner tested each build
before the next, and approved build 28 for release. Nothing in it changes what
a learner is taught; it changes how well the app can be read, heard, reached
and trusted on real phones and tablets.

Devices: the Honor NDL-W09 tablet (Android 16) and the Villaon Aeon One 5G
phone (Android 16 Go); emulators with Android 10, 13 and 16. Browsers:
Chrome, Edge and Firefox.

## What changed

**Screen readers**
- TalkBack reads every screen once (a sweep of every screen in both
  languages finds nothing read twice), in English or Filipino as the screen
  is, and TalkBack's own words follow the app's language.
- Every button has a name and every slider says its value; times are said in
  words; emoji are no longer read by name ("robot", "star-struck").
- Progress's Achievements are one sentence ("Earned: Game Star. 36 more to
  earn.") instead of forty names read twice.
- The tab bar stays readable on a page opened over a main page (Settings).
- In the web app, desktop screen readers are told the page's language and its
  headings.
- Filipino words are spoken by a Filipino voice when the device has one, and
  Settings shows how to add one.

**Words and layout**
- No text is cut off with "…" or split in the middle of a word, on a 320 dp
  phone or at the largest text, in either language (a survey found 349 cut
  texts before; none now).
- One styling system for phones, tablets and computers: buttons fit their
  words, pages keep a readable width, nothing smaller than 11 px.
- The AI Buddy is a floating button in the bottom-right corner, above the tab
  bar and never in it: the pages use the whole screen, the end of every page
  scrolls clear of it, it steps aside under pop-ups, tours and celebrations,
  and messages appear above it.
- List items (decks, messages, stories, class lists) appear as soon as they
  scroll into view. They used to wait their turn in the opening animation,
  blank and unreachable by TalkBack and the controller.

**Controllers and keyboards**
- The game controller keeps working right after a keyboard or TalkBack was
  used, and one press does one job.
- From a tab, up reaches the AI Buddy first; a card half hidden behind the
  tab bar no longer counts as level with the tabs.

**Data and correctness**
- Opening a learner from a teacher's or parent's list no longer erases the
  learner's PIN, birth date or home group on a shared tablet (this was in
  1.4.3).
- Messages and friends recover by themselves after the connection drops;
  Home and the Daily Reward follow the new day.
- No "Something went wrong" after Settings > Switch, or on a guest's Home;
  the error message no longer stays on screen forever.
- The screen stays on only while Gaze Control or voice commands are on;
  otherwise the device's own screen timeout applies, as in any app.
- The display asks for its fastest refresh rate only at the resolution in use.

## Checked on the release code

All on build 28, built from the release commit (its app source has the
fingerprint `1c85a1c4…` taken before and after the tests and the build).

- The full test suite: **10,397 tests, all passing**; `flutter analyze`
  clean.
- Layout: 8,960 combinations (128 screens × 7 window shapes × 10 mixes of
  theme, text size and language): nothing overflowing, nothing cut off.
- Database rules (unchanged since 1.4.3): 412 app checks and 75 website-admin
  checks pass.
- Browsers: Chrome 57 screens with no problems (desktop and phone size),
  keyboard 14/14, mouse 26/26; Edge 57/0; Firefox 57/0 (desktop and phone),
  keyboard 14/14, mouse 26/26.
- **Honor tablet** (this exact APK): a pass over all 22 profiles it then held
  (every tab, a deck, a game and a story for each learner; every one of the
  18 to 20 tiles on each teacher's and parent's home): 322 checks; an
  accessibility label audit of 23 screens (467 labels, no unnamed control);
  a TalkBack walk of Home, Cards, Games, Stories, Progress, the AI Buddy and
  Settings; cold start 0.78 to 0.87 s; 195 MB; no crashes.
- **Villaon phone** (this exact APK): 15/15 over its profiles; a walk of the
  guest home, the card viewer, games and Jules at the owner's settings, the
  largest text, the largest Display size and sideways: 47/47; 9 screens
  audited (137 labels); cold start 0.64 to 0.71 s; 154 MB; no crashes; its
  data kept across a restart.
- Emulators with build 28: Android 10 and 13, each as a tablet and a phone
  (setup from scratch, then 13/13 each), and an Android 16 phone (14/14).

Release files (`build/release-v1.4.4`, the tested build 28 copied unchanged):

| File | SHA-256 |
|---|---|
| FlashLearnPWD-v1.4.4-arm64.apk (code 2028) | `0048595d75f8c5a0782d9d2a8b6868328b34d921348a500335bdccc751414881` |
| FlashLearnPWD-v1.4.4-arm32.apk (code 1028) | `13e29e4acac1237341c8b61474861501494821f1314c7b6fa19c1e54044b2d07` |
| FlashLearnPWD-v1.4.4-universal.apk (code 28) | `b89832c94723176fa307675aa7bbed0faaf732a500f663392c3523000bd30a0d` |

Signed with the original key, so each installs over 1.4.3 as an update and
keeps every profile.

## The Honor's profiles (10–11 November)

On 10 November a debug build run from the code editor was numbered 27 while
the tablet held build 26's arm64 APK (2026). Android refused the older
number, and Flutter's tool answers a failed install by uninstalling the app:
the tablet's profiles went with it. The 21 profiles still in the cloud were
restored with one-time recovery codes through the app's own "I have a
recovery code" screen, birth dates from the owner's backups; the tablet now
holds the 18 it had before plus the owner's Jules. The commit after this
release makes such editor builds take their APK's number
(`android/app/build.gradle.kts`, see [signing.md](signing.md)); it changes
no release file.

## Not checked, and limits

- Android 11, 12, 14 and 15 were not run (Android 10, 13 and 16 were).
- On the devices every screen and tile was opened, not every action inside it
  (finishing a game, sending a message, building a test); those are covered
  by the test suite.
- With Reduced Motion on, list entrances and every looping animation stop,
  but some brief one-time effects (a card fading in once) still play.
- The TV Cast screen's back button is named "Back"; most screens say
  "Go back". Both are read correctly.
