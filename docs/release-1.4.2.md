# FlashLearn PWD 1.4.2: phones and the web

1.4.2 is about **phones** and **browsers**. A learner's friend reported that
on their phone the sign videos under Cards (FSL) froze or never played, while
the same videos worked on the tablets. Testing on a real budget phone (and on
the phone and tablet sizes the app supports) found that, and more: things that
work on a tablet but fail, freeze or sit under something else on a phone. The
same app now also runs in a web browser.

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
| **Settings at large text on a phone** (1.4x, the Visual Impairment size, and 2.0x): the sliders, the "Change" button and the language menu squeezed each row's name until its words broke ("Spee / ch", "Reminde / r", "Pagsas / alita"); the language row and the header "MGA MODE NG PAGKATUTO" ran past the screen's edge; three choices across a phone broke "Pinakamalinaw" even at normal size | Medium | large-text and Visual Impairment learners on phones | a row's control moves under its name when the name would otherwise break (a slider then takes the full width); choices stack; headers wrap. At the default size and on tablets the rows look as before | a new test scrolls the whole of Settings at 360 dp in English and Filipino at 1.0x, 1.4x and 2.0x (learner and teacher); renders with the app's own fonts |
| Jigsaw's word and moves line was 155 px wider than a phone at the largest text, so the moves count went off-screen; Pronunciation's answer cards were up to 5 px short | Low | large-text users on phones | the moves count wraps below, words stay whole; the cards shrink their picture | the check above, at 2.0x text |
| Reading words aloud depended on the device maker: Android 11+ hides the speech engines unless the app declares them, which it did not | Medium | voice and screen-reader learners on some phones | declared (as Android's documentation asks) | the phone: text to speech spoke |
| **TV Cast** on a phone sharing its own hotspot could show the mobile network's address, which no TV can open | Low | teachers casting from a phone | the cast link uses the Wi-Fi or hotspot address, never mobile data, VPN or carrier addresses; with none it says to join Wi-Fi | unit tests (tablet, phone on Wi-Fi, phone hotspot, mobile data only) |

## New: the web app

The same app runs in a browser (Chrome, Edge, Firefox, Safari; phones and
computers), built by `tool/build_web.sh`, to be published at
`https://jpaestedstu-prog.github.io/pwd_flashcard_app/app/`.

- Sign videos stream the website's light copies; pictures load from their
  host; data stays in that browser's storage on that device.
- What needs the phone or tablet itself says so where it is offered: Word Hunt
  (on-device recognition) and Gaze Control (on-device face tracking); TV Cast,
  reminders and the My Day lock need the Android app. Nothing in a browser
  offers the APK as an "update".
- The website's offline store leaves `app/` alone, so a new version is never
  paired with old code.
- It loads its drawing engine and the emoji font from Google's servers, as
  apps built with Flutter do (privacy page, section 5).

## Checks

| Check | Result |
|---|---|
| Unit and widget tests | _(to fill: full suite result)_ |
| Walkthrough on the phone (profile build, real camera, speech) | _(to fill)_ |
| The web app in Chrome (phone-sized), every learner screen | _(to fill)_ |
| Safari, Firefox and Chrome on GitHub's machines | _(to fill: .github/workflows/web.yml)_ |
| The Honor tablet | _(to fill)_ |

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
  reminders and the routine lock work only in the Android app.
