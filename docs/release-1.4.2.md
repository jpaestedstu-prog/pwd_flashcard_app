# FlashLearn PWD 1.4.2: phones and the web

1.4.2 is about **phones** and **browsers**. A learner's friend reported that
on their phone the sign videos under Cards (FSL) froze or never played, while
the same videos worked on the tablets. Testing on a real budget phone (and on
the phone and tablet sizes the app supports) found that, and more: things that
work on a tablet but fail, freeze or sit under something else on a phone. The
same app now also runs in a web browser.

Before release the whole app was reviewed again: on the real Honor tablet
(all 19 of its profiles), screen by screen for accessibility (every button
named, every target big enough for a finger), at large text in English and
Filipino, and in the browser version for what it cannot do. What that found is
under **Found in the review before release**.

Test phone: **Villaon V671N**, Android 16 (Go edition, 3.5 GB of memory),
Unisoc UMS9621S, a 720 x 1600 screen (423 dp wide at its display-size setting,
360 dp at the default), gesture navigation. Tablet: the Honor NDL-W09.

## Fixed

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| **Sign videos froze or never started on phones**: every sign is the original 1920 x 1080 recording at 60 frames a second (H.264 High, level 5.0), about 8 MB, downloaded whole before it can start. On the test phone each sign took **11 to 17 seconds** to appear over Wi-Fi (longer on mobile data), and many budget phones' video decoders stop at 1080p at 30 frames a second, so the picture freezes or never starts | High | learners on phones, slow or mobile-data connections | phones (and low-memory devices, decoders not rated for 1080p60, metered connections) play the light copy of the same recording that the website already serves: 854 x 480, 30 frames a second, silent, about 0.3 MB. A copy is attached to a sign only when it is provably the same recording (same length within 0.15 s): **139 of 143** signs. Tablets on Wi-Fi keep the originals. Settings > Data > **Sign videos**: Automatic, Smaller, Sharpest | on the phone: the sign plays its light copy (854 x 480) **1.5 s** after the tap, and keeps playing; unit tests for the choice and the order of sources; a manifest guard (every light copy exists on the website and belongs to the same word) |
| The **Break** pill floated over the bottom-left corner of every game and covered the game's own buttons: in **11 of 13 games** on a phone (and some on a tablet at large text) a tap on an answer card, "Still Learning", "Clear" or a puzzle piece opened a break instead | High | learners on phones, large-text users | the pill has a lane of its own under the game (on a sideways phone it sits in the top bar instead), so nothing of the game is ever underneath it | a new check compares every tap target of all 13 games with the pill at 5 sizes and 3 text sizes (195 cases, and fails on any layout overflow); it fails on the old code at every phone size |
| On a phone held sideways, the Flashcard Quiz's whole left (and right) strip counted as "Still Learning" ("I Know"): the buttons' tap areas ran the full height of the screen | Medium | learners on sideways phones | the buttons are only as tall as their circle and label | the check above |
| A stroke begun near the screen's edge in **Tracing**, or a word dragged from the edge in **Drag & Drop**, went "back" (paused the game) on phones with gesture navigation | Medium | learners on most current phones | both keep clear of the system's back-gesture strips | widget tests; the phone's strips measured (51 px each side) |
| The floating **AI buddy** sat over every game, the card viewer and the story reader, covering answer cards and puzzle pieces on a phone | Medium | learners on phones | it appears over the five main tabs only (the full tutor is one tap away there) | unit test |
| The **full-screen sign player** held upright showed the sign in a strip a quarter of the screen high, and many phones keep auto-rotate off | Medium | learners on phones | a "turn the video sideways" button, which works with auto-rotate off and gives the screen back on close | unit tests |
| **Settings at large text on a phone** (1.4x, the Visual Impairment size, and 2.0x): the sliders, the "Change" button and the language menu squeezed each row's name until its words broke ("Spee / ch", "Reminde / r", "Pagsas / alita"); the language row and the header "MGA MODE NG PAGKATUTO" ran past the screen's edge; three choices across a phone broke "Pinakamalinaw" even at normal size | Medium | large-text and Visual Impairment learners on phones | a row's control moves under its name when the name would otherwise break (a slider then takes the full width); choices stack; headers wrap. At the default size and on tablets the rows look as before, except Screen orientation on a 360-dp phone, whose "Turns with device" was cut to "Turns / with…" and now stacks | a new test scrolls the whole of Settings at 360 dp in English and Filipino at 1.0x, 1.4x and 2.0x (learner and teacher); renders with the app's own fonts |
| Jigsaw's word and moves line was 155 px wider than a phone at the largest text, so the moves count went off-screen; Pronunciation's answer cards were up to 5 px short | Low | large-text users on phones | the moves count wraps below, words stay whole; the cards shrink their picture | the check above, at 2.0x text |
| Reading words aloud depended on the device maker: Android 11+ hides the speech engines unless the app declares them, which it did not | Medium | voice and screen-reader learners on some phones | declared (as Android's documentation asks) | the phone: text to speech spoke |
| **TV Cast** on a phone sharing its own hotspot could show the mobile network's address, which no TV can open | Low | teachers casting from a phone | the cast link uses the Wi-Fi or hotspot address, never mobile data, VPN or carrier addresses; with none it says to join Wi-Fi | unit tests (tablet, phone on Wi-Fi, phone hotspot, mobile data only) |

## Found in the review before release

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| After a **full-screen sign video**, the **My Day lock** or the **Time's up** screen, Android's status bar (clock, battery, notifications) stayed hidden until the app was restarted. The Flutter version the app is built with asks Android for "edge to edge" in a way newer Android versions ignore after a full-screen page | Medium | everyone on recent Android | the bars are asked back in two steps, the way that works on every version (`SystemBars.restore`) | a test of the exact calls made to Android, and a guard that no screen restores the bars the old way; on the Honor: the bar comes back on leaving the full-screen player (Android reports it shown; on the test build it stayed hidden) |
| About **20 buttons had no spoken name**: a screen reader said only "button" (calendar month arrows, Messages back and send, the Focus timer's 5-minute buttons, the Talk Board's edit button, the AI Tutor's send button, closing a lock warning, the back buttons of Join a class and the setup pages, and more) | Medium | screen-reader users | each has a name, in English and Filipino | a new check of every tap target on 89 screens |
| **Buttons and chips smaller than a finger** (48 dp): the AI Tutor's topic chips, quiz answers and "Listen"; the Notes filters; the dashboard's sort button; Student Comparison's names; the Play Together name fields; the Quiz Builder's word rows; and the chip strips of 8 screens, whose 40 to 46 dp strip capped every chip inside it | Medium | learners with motor impairments | 48 dp | the same check: 50 findings before, none now (4 it cannot judge: chips cut off at the edge of a strip that scrolls sideways) |
| **Large text on phones** (1.4x, the Visual Impairment size, and 2.0x): words broke in the middle ("Assessme / nts", "Kate / gorya", "Pangangaila / ngan") or rows ran off the screen. 82 places in English, and 74 more in Filipino, whose words run longer: Home's lower sections and greeting, the child Home's tiles, onboarding, the dashboards, Recommendations, Word of the Day, the game cards, learning paths, Settings-like screens (Game Controller, Gaze Control, Parental Controls), the Assessment builder, the survey, empty pages and more | Medium | the Visual Impairment preset and large-text learners, most of all in Filipino | words shrink only as much as they need to stay whole; rows wrap or stack; side-by-side buttons stack; at large text on a phone Home's small tiles take two columns and the child Home one | a new check scrolls every screen to its end at 1.0x, 1.4x and 2.0x, in English and in Filipino, with the app's own fonts: no problems in either language |
| **Exports failed for a learner whose name has a slash**, such as the "Cognitive/Learning Anak" profile: the file name pointed into a folder that does not exist | Low | teachers and parents exporting | file names are cleaned | unit tests |
| With a screen reader on, the full-screen sign player hid its controls after 3 seconds, halfway through a swipe to "Close" | Low | screen-reader users | the controls stay while one is on | |

In the browser version:

| Problem | Severity | Who it hit | Fix | Checked by |
|---|---|---|---|---|
| Backup files, TV Cast, reminders, game controllers, and adding a photo or video to a card, a message, a My Day step or a test question offered buttons that failed in a browser, or seemed to work and did nothing (a reminder that never comes) | Medium | browser users | each says it needs the Android app, with a link to the download page; a pasted link still works for media; Backup points to the Cloud Recovery Code | a test of each screen as the browser version shows it; the browser walk checks the TV Cast, Backup and Game Controller notices |
| **Exports** (progress CSV, research data, flashcards, a student's profile, the class report) failed in a browser: they first wrote to a folder a browser does not have. Importing flashcards or a student's profile failed the same way | Medium | teachers using the browser | they download (or open the browser's share sheet), and imports read the chosen file directly | unit tests |
| A learner taking a test in a browser was **stuck on a "record your answer" video question**: no camera recording there, and no way past it | Medium | learners using the browser | it says video answers are recorded in the Android app, and offers **Skip** (the question is not scored and nothing is sent) | a widget test, through to the saved result |
| In Chrome on an Android phone, My Day offered an Android permission ("Display over other apps") that a browser cannot grant | Low | browser users on Android phones | not offered in a browser | |
| Sign It in a browser: saving a practice take showed "Something went wrong" | Low | browser users | the take replays from the browser's own recording | |
| Each look at a shared photo or video downloaded all of it from the cloud, then threw it away (Firestore reads, against the free quota) | Low | browser users | not fetched in a browser; it says to open it in the Android app | a widget test (Messages) |
| Picking a picture for a new card in a browser showed "Something went wrong" | Low | browser users | the browser version says pictures are added in the Android app | the browser-version test |

## New: the web app

The same app runs in a browser, built by `tool/build_web.sh`, to be
published at `https://jpaestedstu-prog.github.io/pwd_flashcard_app/app/`.
Every learner screen was walked through in Chrome, Firefox and Safari on
computers (desktop and phone-sized windows), in Chrome as an Android phone
(a Pixel 7, emulated), and in Mobile Safari on an iPhone (the iOS
Simulator). Edge shares Chrome's engine and was not tested separately.

- Sign videos stream the website's light copies; pictures load from their
  host; data stays in that browser's storage on that device.
- What needs the phone or tablet itself says so where it is offered, with a
  link to the download page: Word Hunt (on-device recognition) and Gaze
  Control (on-device face tracking); TV Cast, reminders and the My Day lock,
  backup files, game controllers, recording a video answer, and adding photos
  or videos need the Android app. Exports download. Nothing in a browser
  offers the APK as an "update".
- The website's offline store leaves `app/` alone, so a new version is never
  paired with old code.
- It loads its drawing engine and the emoji font from Google's servers, as
  apps built with Flutter do (privacy page, section 5).

## Checks

| Check | Result |
|---|---|
| Unit and widget tests | 6,219 passed, 0 failed (686 of them new in this release, including the two whole-app checks below); `flutter analyze`: no issues, at every commit |
| Every tap target on 89 screens (`test/a11y_tap_targets_test.dart`) | named, and at least 48 dp, on every screen; the app's own theme and fonts, each screen scrolled to its end |
| Every screen at large text (`test/deep_scroll_layout_test.dart`) | 88 screens on a 360 dp phone, scrolled to the end, at 1.0x, 1.4x and 2.0x, in English and Filipino (528 cases): no overflow, no word broken in two |
| Walkthrough on the phone (profile build, real camera, speech) | 58 screens, 0 problems, four times: upright at the phone's own display size (423 dp wide), sideways, upright at Android's default size (360 dp), and again on the final code. Every run: a sign plays its light copy (854 x 480) 1.5 to 2.2 s after the tap and keeps playing; Word Hunt takes a photo; Sign It records and plays back; Gaze Control starts the camera and finds a face; text to speech speaks; speech recognition is available; Settings opens its rows; the profile deletes itself |
| The web app in Chrome (phone-sized), every learner screen | 57 screens, 0 problems (the offline test build, `tool/web_smoke.py`). A rehearsal of the deployment (the website and the release web app served together, as GitHub Pages will): 6 of 6 checks and no console errors; the website's offline store leaves `app/` alone; Firebase sign-in works from a browser. Rebuilt on 17 October from the final code (`build/web-v1.4.2`): it opens on its welcome screen in Chrome on a computer and as a Pixel 7, with no console errors |
| Safari, Firefox and Chrome on GitHub's machines (`.github/workflows/web.yml`) | 57 of 57 learner screens, 0 problems, in each of: Safari on macOS (desktop and phone-sized window), Mobile Safari on an iPhone 17 Pro (iOS Simulator), Firefox (desktop and phone-sized), Chrome (desktop, and as a Pixel 7). The walk itself needed three fixes on the way (waiting for the browser's driver; how Flutter turns on its semantics in a phone browser; typing on iOS), the app none. Again on 17 October with the final code: 57 of 57, 0 problems, in all six, and the Backup and Game Controller screens show their "needs the Android app" notice in each |
| Android emulators on GitHub (`.github/workflows/android.yml`) | the walkthrough on a phone and a tablet, upright and sideways: all four pass; the full test suite and `flutter analyze` pass; the website and Google Play release builds succeed and their manifests check out. Again on 17 October with the final code: all pass |
| The release files (`bash tool/build_release.sh`, 17 October) | `build/release-v1.4.2`: arm64, arm32 and universal APKs and SHA256SUMS.txt, signed with the original key; `build/store-v1.4.2`: the Google Play APK and bundle (upload key). Manifests, signers and the release-file scan: all ok |
| The Honor tablet (NDL-W09, Android 16, MagicOS 10) | the 1.4.2 test build installed over 1.4.1, keeping all 19 profiles. Every profile opened and walked (learner tabs and tools; every educator Home tile): 145 screen visits screens, 0 problems, and no Flutter errors, crashes or freezes in the device log. Sign videos: on the hotspot (a metered connection) Automatic plays the light copy (854 x 480); Sharpest plays the full 1920 x 1080 recording; the tablet's decoder is rated for 1080p60. Then the final release build (arm64) was installed the same way: the status bar returns after full screen, and a second walk with the final build (a Visual Impairment learner at 1.4x text, and a teacher's every Home tile) found 32 screens, 0 problems, no errors in the log |

## Known limitations

- Four signs have no light copy, because the website's clip is a different
  recording: Chicken (Animals) and Airplane, and **Yellow and Windy**, whose
  website and Cloudinary copies follow the word mapping chosen on 29 July
  while the GitHub originals follow the first one. On phones those four play
  the 720p copy (half the size of the original). Which recording is right for
  Yellow and Windy is the owner's call.
- Story sign clips (204, 720p at 60 frames a second, about 7 MB each) have no
  light copies yet; they play on phones but are slow on mobile data.
- The web app needs the internet to start; Word Hunt, Gaze Control, TV Cast,
  reminders, the routine lock, backup files, game controllers, video answers
  and adding photos or videos work only in the Android app (each says so).
  Photos and videos shared in messages, My Day steps and tests are not shown
  in a browser; it says to open them in the app.
- In a browser, a test made only of video questions, all skipped, ends on
  "Sent to your teacher or parent" although nothing was sent.
