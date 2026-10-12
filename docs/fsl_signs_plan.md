# Plan: adding the 33 remaining FSL signs

**Status (12 October 2026): on hold by the project owner's decision.** The 33
words stay "Sign coming soon" placeholders until the owner says otherwise.
Nothing is recorded, generated, downloaded or replaced meanwhile. This page is
the plan for when that changes; [`fsl_recording_guide.md`](fsl_recording_guide.md)
is the how-to for the person filming.

## What remains

FlashLearn has a sign video for 142 of its 175 words. The other 33 are listed,
with their Filipino words and file names, in
[`fsl_recording_checklist.csv`](fsl_recording_checklist.csv):

| Category | Count | Words |
|---|---:|---|
| Colors & Shapes | 2 | Green, Flower |
| Food & Drinks | 5 | Bottle, Cup, Spoon, Fork, Plate |
| Classroom | 7 | Table, Paper, Ball, Door, Window, Television, Phone |
| Actions | 19 | Run, Jump, Eat, Drink, Sleep, Read, Write, Sing, Dance, Clap, Sit, Stand, Open, Close, Wave, Cry, Laugh, Swim, Play |

**Actions** has no sign of its own yet (its Walk card borrows the
Transportation sign), so it is the category to record first: its sign games
and its offline pack have nothing to offer until then.

## How the app handles them today

- Each of the 33 words keeps its picture, English and Filipino text and
  spoken audio in every flashcard, game and story.
- Where a sign would play, the app says "Sign coming soon" (English and
  Filipino), and the FSL Dictionary tags the word "Coming soon". The website's
  FSL Dictionary lists them under "Signs coming soon".
- The sign games (Sign → Word, Word → Sign, Sign It) draw only from words
  that have a sign, and show a friendly empty screen when a category has too
  few.
- The offline sign packs count only words that have a sign, and say "No signs
  recorded yet" for a category with none.
- [`fsl_placeholders_test.dart`](../test/fsl_placeholders_test.dart) keeps
  the checklist and the app's unsigned words identical, so neither changes
  silently.

## Steps, when the owner gives the go-ahead

1. **Choose the signs.** With a Deaf signer or an FSL teacher, confirm the
   sign taught in Philippine SPED classrooms for each word (some have
   variants). Note any choice in the checklist.
2. **Consent.** The signer's face appears in the app and on the website; get
   their written consent, as for the existing clips.
3. **Record** following [`fsl_recording_guide.md`](fsl_recording_guide.md):
   HDR off, sideways (landscape) 1080p, plain light background, one word per
   clip. A phone on a stand is enough. One category at a time, Actions first.
4. **Review.** The signer or teacher checks every clip; re-record any that
   are unclear.
5. **Publish to the app** ("Recording the remaining clips" in
   [`tools/README.md`](../tools/README.md)). The 33 rows are already staged in
   `tools/fsl_video_manifest.json`; name each converted file after its
   `source` column (`GREEN.MOV` → `build/fsl_mp4/GREEN.mp4`), not after the
   upload name, or it is silently skipped. Then `fsl_check_clips.mjs`
   (refuses HDR), `fsl_coverage_report.mjs --check`, and
   `publish_fsl_videos.mjs`, which uploads to the free `pwd-fsl-videos`
   GitHub release and rewrites `assets/data/fsl_video_manifest.json`.
6. **Publish to the website.** Make a small web copy of each clip into
   `website/assets/videos/fsl/<slug>.mp4`:

   ```
   ffmpeg -i GREEN.mp4 -vf "scale=-2:480,fps=30" -c:v libx264 -profile:v main -crf 30 -preset slow -an -movflags +faststart -pix_fmt yuv420p green.mp4
   ```

   Add one line per word to `website/assets/fsl-dict.js` in the existing
   format, `{c:<category number in FSL_CATS>,f:"<clip name>",en:"Green",fil:"Berde",e:"<emoji>",s:"<the card's example sentence>"}`.
   The script that first generated that file was never committed, so for now
   these lines are added by hand. Then run `python tools/fsl_dict_page_build.py`:
   it fails if a clip is missing, and the "Signs coming soon" list shrinks by
   itself.
7. **Update the checklist:** remove each published row from
   `fsl_recording_checklist.csv`. The placeholders test fails until the
   checklist and the app agree, which is the point.
8. **Test:** the FSL, manifest and offline-pack tests, the walkthroughs, and
   playing each new sign on a real tablet (the only way to catch a clip the
   tablet cannot decode).
9. **Release:** the app's sign list is bundled, so learners get new signs with
   an app update (a 1.4.x release); the website needs its own deploy. Both
   are public steps that wait for the owner's approval.

## What it costs

Nothing to buy: a phone and a stand, ffmpeg, Node and GitHub Releases are
free, and the app needs no new hosting. The real cost is people's time:
roughly an afternoon per category for the signer and the reviewer, and about
an hour to publish a batch to the app and the website.
