# FlashLearn PWD 1.4.6: voice only, a hands-free pause, break reminders, Help & Guides

1.4.6 is one test build (30), made on 15 November 2026 and approved by the owner for
release on 16 November 2026, together with the companion website and the admin dashboard.

## What changed

- **Voice only:** in Gaze Control, "Voice only (camera off)" lets a learner move around the
  app and choose by voice alone. The camera stays off, and Voice commands turn on with it.
- **A hands-free pause:** saying "stop listening" pauses hands-free control and shows a
  banner; "resume", a long blink, a switch press or a tap on the banner brings it back. New
  phrases also read the screen aloud ("read the screen"), repeat the last words ("say
  again") and list what you can say ("what can I say"), in English and Filipino.
- **Break reminders:** in Time limits, a teacher or parent can turn on "Remind them to take a
  break" every 10 to 60 minutes. The learner sees "Time for a short break" with Take a break
  and Keep learning; the reminder waits until a test is finished and counts learning time
  from the end of the last break.
- **Help & Guides in the app:** Settings → About → Help & Guides holds 12 step-by-step guides
  in English and Filipino, each with Read aloud; learners see the guides meant for them,
  teachers and parents see theirs first. On a child's or a guest's Home, the guides are in the
  accessibility button.
- **Rate & Feedback:** Settings → About → Rate & Feedback opens the website's feedback form
  (on a student's or child's profile, a grown-up check comes first).

## Checked on the release code

- The full test suite: **10,491 tests, all passing** (16 November, on this app code);
  `flutter analyze` clean.
- Build 30 holds the last app commit (d8bb0a2, committed 10 seconds before the build
  started): its new routine line in the teachers' guide is in the compiled code
  (`lib/arm64-v8a/libapp.so`) and the old line is not. No app file changed after it.
- The release files are the tested build 30, copied unchanged: version codes 2030 (arm64),
  1030 (arm32) and 30 (universal), all above 1.4.5's, and signed with the original key
  (certificate SHA-256 `afd730b9…2ba8`, the same as 1.4.5), so each installs as an update.
- On the tablet emulator (Android, x86_64): the published 1.4.5 universal APK installed; a
  "Player (with Progress)" profile made through the real screens (Tess, 5 stars); its Check
  for updates said "This tablet has the newest version (1.4.5)". Then the 1.4.6 universal APK
  installed over it as an update: the app opened on Tess's Home with her 5 stars, Settings →
  About showed Version 1.4.6, Help & Guides and Rate & Feedback, a learner saw only the
  learners' guides, a guide opened with its numbered steps, and nothing crashed.

Release files (`build/release-v1.4.6`, the tested build 30 copied unchanged):

| File | SHA-256 |
|---|---|
| FlashLearnPWD-v1.4.6-arm64.apk (code 2030) | `6547c83dd943e68358b4a109e6a7a38fbc8c1af456d7a4ebdffa740fb9aa2611` |
| FlashLearnPWD-v1.4.6-arm32.apk (code 1030) | `734a49d14c71dc5e22c64c90a365ba035256043fc5bdd42b6917b843cbdfafd4` |
| FlashLearnPWD-v1.4.6-universal.apk (code 30) | `a71ac924d0d86c463e8ecfe2c0acd73a6d942361cce631e41eca10d65f48d89e` |

## Not checked, and limits

- Voice commands need a person speaking near the device; they are covered by automatic tests,
  not by a real voice in this round.
- The arm64 and arm32 files were not installed on a phone or tablet in this round. The owner's
  Honor tablet holds study profiles and is updated by the owner; the emulator ran the universal
  file.

## Published

Published 16 November 2026 (about 11:20 Philippine time), with the owner's go-ahead, from
the tested files only:

- Release **v1.4.6** (Latest) on b81904b, which adds the website's download section,
  changelog and version.json, and the email notifier's address, to the app code of d8bb0a2.
  It was made as a draft first; its three APKs went up in about 11 minutes, GitHub's SHA-256 of
  each equalled the table above, and only then was it published.
- The website and web app went to gh-pages **8d9411e** (from 27fc842): the `website/` folder of
  b81904b, and the web app built for 1.4.6 (`tool/build_web.sh`) under `app/`. Before the push,
  the new tree was served on this PC under the live site's path: every page, the 1.4.6 download
  details, the three download links and the web app's first screen at 1280 and 412 pixels wide
  (8/8).
- Live checks: 95 site files byte-identical to 8d9411e; the same 8 checks on the live site
  (8/8); the admin dashboard's live check, including the website part (33/33).
- The update path, on the tablet emulator against the live site: the published 1.4.5 found
  1.4.6 by itself ("Version 1.4.6 is ready — tap to see how to update"); the live download link
  gave the tested universal file (SHA-256 matched); it installed over 1.4.5 as an update and
  kept the profile and its stars; 1.4.6 then said it was the newest version (8/8).
- The admin dashboard (`flashlearn-pwd-site.web.app`) was deployed the same day: the database
  rules and the redesigned dashboard with email notices; its five files are byte-identical to
  this commit. The owner signed in with Google as jaj4ngpinasto@gmail.com, which was added as
  an administrator, and saw Email notices "Connected".
- Email notices: the owner deployed the notifier (a Google Apps Script web app) in the
  jaj4ngpinasto@gmail.com account, and its address was connected to the website and the
  dashboard. The owner confirmed three emails in that inbox: the set-up test, a test notice
  sent through the deployed notifier, and a rating sent from the live website's form. Bad
  requests are refused, and a request cannot change who receives the email.
- After publishing: the full suite again (10,491 passing), the website's own checks (guides
  50/50, menus 34/34, offline 11/11, accessibility 28 + 28 audits with no violations, 504 page
  loads at every width, Microsoft Edge with no problems), and the dashboard's (107/107 end to
  end, rules 80/80, notifier 29/29).
- The Honor tablet was not updated in this round: it holds study profiles, and the owner
  updates it (the app's Check for updates now offers 1.4.6).
