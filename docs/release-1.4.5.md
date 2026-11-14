# FlashLearn PWD 1.4.5: TV Cast for your classes

1.4.5 is one test build (29), made after 1.4.4 at the owner's request on
14 November 2026 and approved by the owner for release the same day. It
changes only TV Cast, the teacher's or parent's lesson shown on a TV, and only
for teachers and parents; nothing a learner sees in the app changes.

Devices: the Honor NDL-W09 tablet (Android 16) as the teacher's device; as the
TV, Chrome on a Windows PC and the tablet's own Chrome driven by Android remote
key codes.

## What changed

**Which classes a cast is for**
- On the TV Cast screen a teacher picks the classes the cast is for (a parent,
  the home groups): one, several, or "All classes" as one choice that also
  covers classes made later. Picking every class one by one turns back into
  All. The choice is saved per teacher or parent and can be changed at any
  time, even while casting.
- The TV's Progress board shows only the learners of the chosen classes, and a
  line on the TV names them ("For: …").
- Live Activity sends its questions to the chosen classes only, one live
  session per class, and follows a change of choice mid-session. A learner
  still opens only the live session of their own class or home group.

**A short address**
- The TV opens the cast at `<tablet address>:8088/<CODE>`, and the screen shows
  it without `http://`. The QR code and the Copy button keep the full link;
  older `…/c/<CODE>` links keep working.

**Cards that move like the app**
- On the TV the next card slides in as the old one slides out (the other way
  when going back), and grows in slightly, with the app's timings and curves;
  the flip to the photo turns at the app's speed and depth. With Reduced
  Motion the cards simply change and the flip is quick.

**Sound through the TV**
- The tablet makes each spoken line into a short sound file in its own
  English and Filipino voices, and the TV plays it, so the sound also works on
  TVs whose browser cannot speak. If a file cannot be made, the TV speaks the
  line itself where it can.
- A 🔊 sign shows on the TV while a word plays, and the slideshow waits for a
  word or story line to end before it moves on.
- New Playback speed under Audio: 1× Normal or 2× Fast, for the words and the
  sign and Show Me videos.
- When the TV's browser holds sound back until a key is pressed, the TV says
  so, and one press of OK turns it on.

**The TV remote**
- ◀ ▶ (and ⏪ ⏩, CH − / CH +) step through cards, signs and story pages; OK
  flips the card or replays a sign; ▲ says the word again; ▼ plays the Show
  Me clip or the story page in FSL; ▶❚❚ and the Play, Pause and Stop keys
  pause and resume; Back closes what is open, then asks before leaving the
  cast; Info or Menu shows the list of keys. The same list is on the tablet
  under TV remote.
- Each press shows a short note on the TV. With "Control from the TV remote"
  turned off on the tablet, the TV says so.

## Checked on the release code

All on build 29, built from the release commit.

- The full test suite: **10,450 tests, all passing**, run on this code after
  the build; `flutter analyze` clean. New tests cover the class choice and its
  saving, the picker on phones and tablets at large text in both languages,
  the short link, the speech files, the remote keys and 2×.
- The TV page's own checks (`node tools/tv_cast_render_check.js`): 60/60.
- The TV page in real Chrome (headless): the card slides in 400 ms from the
  correct side and the old card is removed after; the grow-in carries the
  app's small overshoot; the flip takes 650 ms; layout at 720p, 1080p and 4K
  with three text sizes, the full-screen picture and the three templates;
  sound plays from the files, English then Filipino, and at 2×; every remote
  key and Back work; no console errors (39/39). With the browser blocking
  sound: the hint shows, one key press turns the sound on (41/41).
- **Honor tablet**: a real cast with Sir Kevin's six classes. The choice was
  kept after closing and reopening the app; the TV's board showed only the
  chosen classes' 4 learners, then 9 for All classes; a live session
  went to exactly the 2 chosen classes and its question reached the TV; the
  tablet made the speech files in its English (en-US) and Filipino (fil-PH)
  voices and the TV played them at 1× and 2×; the tablet's own Chrome as the
  TV answered real remote key codes (the arrows, OK, play/pause, Back) and
  played the sound through its speakers.
- The release arm64 APK (code 2029) installed on the Honor over the test copy
  with every profile kept; its checksum matches the table below.

Release files (`build/release-v1.4.5`, the tested build 29 copied unchanged):

| File | SHA-256 |
|---|---|
| FlashLearnPWD-v1.4.5-arm64.apk (code 2029) | `9af1b362d0c9c8bc73f2ff2ee63e14dc24e7a22783a34bf4e86658900fa30eec` |
| FlashLearnPWD-v1.4.5-arm32.apk (code 1029) | `34ea8177a18f27df03ffcc8aacd8a3adc5dc57a55f5b526065e892ea0cbe364e` |
| FlashLearnPWD-v1.4.5-universal.apk (code 29) | `2afa85f0ba7695cc2d94f57ac471a52c420d7a5760fb39145e8801dce80dcfa4` |

Signed with the original key, so each installs over 1.4.4 as an update and
keeps every profile.

## Not checked, and limits

- No smart-TV browser (Samsung, LG, Android TV) was used. Their remote keys
  are mapped and checked in the TV page's own checks, not on a real TV.
- A browser in full screen spends the first Back on leaving full screen; the
  cast's own Back handling starts from the next press.
- On a phone hotspot the link between the tablet and the TV dropped for a
  while during testing; the TV shows that the teacher is reconnecting and
  carries on when the link returns.
- TV Cast still needs the Android app: the web app says so where it is
  offered.
- Found while testing, outside TV Cast and not changed: three Filipino
  messages say "1" for counts such as 2, 3 or 5 (the stars earned on Home, an
  assessment already taken, and cards exported from a deck).
