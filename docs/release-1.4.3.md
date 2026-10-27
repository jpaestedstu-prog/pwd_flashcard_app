# FlashLearn PWD 1.4.3: every control within reach of a D-pad

1.4.3 is about **moving through the app without touching the screen**. At
the owner's request, D-pad navigation was extended to every tile, card,
game, story, Progress panel and Settings choice, for the Guest Player, a
Player with Progress, and Students and Children with each kind of
accessibility need, and made to work the same way with every D-pad the app
has.

"A D-pad" here is three different inputs, which now step through a screen in
the same order:

- **Arrow keys**: a Bluetooth keyboard, a TV-style remote, or a switch box
  set to send arrows. Enter (or the remote's centre button) presses. They
  work in the web app too.
- **The game controller** (Settings > Game Controller): left and right change
  section, up and down walk the items, and it says each one aloud.
- **Gaze Control**: the head D-pad and the voice commands (camera and
  microphone, on the tablet or phone).

Tablet: the Honor NDL-W09 (Android 16), debug builds driven through its
accessibility tree and the app's own debug bridge. Browser: Chrome 155.

## Fixed

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| In the **web app the arrow keys scrolled the page**: a browser maps them to scrolling, so a keyboard, a remote or a switch box could not reach a single tab or tile | High | anyone using the web app without a mouse or touch | the arrow keys move from control to control everywhere, in the browser as on Android; a focused text field still moves its caret | unit tests; in Chrome, down through Home to the tab bar, along it to Cards, Enter opens Cards, down to a deck, Enter opens it (10 of 10, twice) |
| **Ninety-one kinds of control answered only a touch** (in 57 files): deck and story covers, category cards, game answer tiles, the flashcard viewer's card and buttons, Settings' size and choice buttons, mood faces, Talk Board tiles, stickers, the Daily Challenge, the word of the day, the survey, Edit Profile and more. The arrow keys, and the controller and gaze on pushed screens, could not reach them | High | everyone not using touch | each takes focus and Enter (or the controller's A, or a blink) presses it, the same as a tap | a sweep of 95 screens and one of 30 game and drill-down screens: no tap target without a focus stop; the reach matrix below |
| On the hubs, gaze and the controller could not reach **the holiday banner's close button, "See All", each Daily Challenge answer, a guest's floating Home button or the AI Buddy** | Medium | gaze and controller users | each is a cell of the hub's grid, in the order they sit on screen | the reach matrix; on the Honor, every tab's rows read back for a Player, a guest and a Child |
| **Progress was mostly unreachable**: charts, totals and badges are information, not buttons, so a D-pad stepped over them | Medium | everyone not using touch | each panel is a stop, and pressing it reads the panel aloud; each recent game is named by how it went ("Word Match: 4 of 5, 80 percent, 1 star, …"; it said "1 stars") | widget tests; on the Honor, the stops in order, each recent game named by its score, and a press heard by the speech engine (its player starts in the device log) |
| **Arrow keys could not leave a hub**: down never reached the tab bar; right at the end of a row jumped to the Star Shop at the top of Home; and from the tab bar, down jumped back up into the page | Medium | keyboard, remote and switch users | down from a page carries on to the tab bar and stops at the bottom; right at a row's end goes on into the next row; before the last control wraps round, the rest of the page scrolls into view | unit tests; the reach matrix; on the Honor |
| **The guest's Home button and the AI Buddy could not be reached**, and moves between a page and the tab bar went astray. Flutter's search looks at the page first and takes a control there even off to one side; it counts the page itself as one control the size of the page; and it remembers its own steps but not the app's. On the tablet: down from a guest's last deck went back to the first deck; right went up to the other column; left from the AI Buddy jumped to the deck focused last; up from every tab went to the AI Buddy; and up from the last category jumped two rows up into another column | Medium | guests, and every learner with the AI Buddy | a control straight ahead (in the same row or column) comes first, on the page or in the frame around it; controls level with each other count as one row; the page itself is never a target; and every move the app makes itself clears Flutter's memory of the steps before it | widget tests that fail on the old code, one per case; on the Honor (a guest's Cards, the Child's Home, a Player's Home and its tab bar) |
| **Up and down were trapped by a slider** (they changed its value), and a D-pad has no Tab key to get off it | Medium | keyboard and remote users | up and down leave a slider; left and right still change it (all 15 sliders) | unit test |
| The **controller's up and down skipped controls side by side** on screens that publish no list: on Settings, down went "Text size, XL, Below", and S, M and L could not be reached | Medium | controller users | up and down walk those screens in reading order, one control at a time, wrapping at either end, as they do the lists | a test that fails on the old code; on the Honor, sixteen Settings controls in order, S, M, L, XL and the three orientation choices among them |
| The controller called the Star Shop and Settings buttons **"Unnamed item"** | Low | controller users who listen | icon buttons are named by their tooltip | unit test; on the Honor ("Open settings") |
| **No visible focus** for some arrow keys and for the controller on pushed screens: Flutter never switches to keyboard highlighting for keys from Android's virtual keyboard, which a switch box can be | Medium | keyboard, remote and switch users who watch the screen | a ring frames the focused control from the first press until the next touch | unit tests; on the Honor (the ring's place read back); in Chrome (screenshots) |
| The controller kept steering the hub's tiles **under an open AI Buddy panel or a first-visit tour** | Low | controller users | those are stepped by focus; the tour names Next and Skip | unit tests; on the Honor (the panel open) |
| The holiday banner broke words in two at 1.3x and 2x text on a phone | Low | large-text users | the banner's words shrink to fit and the days-left chip moves under them | a test of every holiday, in English and Filipino, at 1.3x and 2x on a 360 dp phone with the app's fonts |

## The reach matrix

`test/dpad_reach_test.dart` opens every learner tab as each kind of learner
(the Guest Player; a Player with Progress; a Student and a Child under each
of the six accessibility types), at the Honor's size, with the AI Buddy over
them as in the app: 81 pages, 1,749 controls. On each it checks that every
control is a gaze and controller cell (Settings excepted: it is not a hub),
takes focus, is reached by the arrow keys **pointing at it** (a control met
only by wrapping round the page is one nobody finds; that rule is what showed
the AI Buddy unreachable on a guest's two-column Cards page), and has a cell
of its own.

## Checked

- The full test suite: **6,633 tests**, all passing, and `flutter analyze`
  clean, on the release code (45eb7da).
- The D-pad tests above: 528, all passing on the final code; each new rule's
  test was run against the old code first and failed there.
- The release files (`bash tool/build_release.sh` into
  `build/release-v1.4.3`, from 45eb7da): arm64 `56bf88c9…`, arm32
  `7f7f4b2c…`, universal `bb95ec69…`, signed with the original key; the Play
  APK and bundle with the upload key; manifests, signers and the release-file
  scan all ok. The release arm64 APK installed over the tablet's build,
  keeping every profile, and walked by keyboard: down to the tab bar, along
  it to Cards, Enter, down to a deck (the ring around it), Enter opens it; no
  errors in the device log.
- On the Honor NDL-W09: the Guest Player (Cards, Home button, AI Buddy);
  Player with Progress (Home to the tab bar and back up from each tab,
  Settings by keyboard and by controller, Progress); a Child (Cognitive):
  Home by keyboard, gaze rows on all five tabs, Buddy; Students (Hearing, and
  Cognitive): the Daily Reward collected with down and Enter. Each profile's
  gaze settings were saved first and put back after (checked equal).
- In Chrome 155 (the offline test build): the web D-pad check 10 of 10,
  twice; the web smoke walk 57 screens, no problems, as a desktop and as a
  Pixel 7.
- GitHub's Android workflow (analyze and the whole suite, the release APKs,
  walkthroughs on a phone and a tablet, each upright and sideways) and Web
  workflow (Chrome and Firefox as a desktop and as a phone, Safari on macOS
  and iOS) pass on 1942466.

Published 27 October 2026, with the owner's go-ahead: release
**v1.4.3** (Latest) on 1942466, its three APKs uploaded over a phone hotspot
in about 7 minutes and GitHub's SHA-256 of each matching SHA256SUMS; each
download link answers with the right size. The website and web app went to
gh-pages **0730853** (from 7b3e84e: the download section, changelog,
version.json and service worker v41, and the web app's four changed files);
all eight are byte-identical live, and the live web app reaches its first
screen with no errors as a desktop and as a phone.

## Not checked, and limits

- **The controller's hub grid with a real pad paired.** Without a paired pad,
  the tablet treats injected controller presses as an unpaired device, so
  only the controller's focus-moving mode was walked there; the grid mode is
  covered by widget tests.
- **Voice commands spoken aloud.** They share the D-pad's moves, which were
  tested; saying them needs a speaking person at the tablet.
- **Sliders on the tablet.** Covered by a widget test only.
- **Web screen readers.** 31 controls in 21 files set their own accessible
  label over a tap area, which keeps them out of the page's own focus: the
  arrow keys reach them and the ring shows it, but a screen reader in a
  browser is not told. On Android, TalkBack keeps its own focus and is not
  affected. Older than this release; a fix is planned.
- **No game controller or Gaze Control in the web app**, as before (the app
  says so where they are offered).
- Once, the first arrow press on the tablet's Daily Reward dialog did
  nothing; two more tries could not repeat it (most likely the test's
  on-screen accessibility menu holding the keys for a moment).
- Right from the last tab, or from a page's last control, starts the page
  again from the top, by design.
- Gaze and the controller used together each keep their own highlight.
- Unsending a message is a long press, which no D-pad has.
