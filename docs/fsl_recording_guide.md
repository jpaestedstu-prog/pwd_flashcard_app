# Recording the remaining Filipino Sign Language signs

FlashLearn has a sign video for 142 of its 175 words. The other **33 show
"Sign coming soon"** in the app and on the website until a video exists. Only a
person who signs FSL can record them, so no tool, script or service can do
this part. This guide covers how to record them so they match the existing
clips and work on every tablet. Publishing them afterwards takes about ten
minutes with the free tools in [`tools/README.md`](../tools/README.md).

## Which words

The list is [`fsl_recording_checklist.csv`](fsl_recording_checklist.csv)
(category, English, Filipino, the file's slug). As of 1.4.0:

| Category | Words |
|---|---|
| Colors & Shapes | Green, Flower |
| Food & Drinks | Bottle, Cup, Spoon, Fork, Plate |
| Classroom | Table, Paper, Ball, Door, Window, Television, Phone |
| Actions | Run, Jump, Eat, Drink, Sleep, Read, Write, Sing, Dance, Clap, Sit, Stand, Open, Close, Wave, Cry, Laugh, Swim, Play |

The rows are already in `tools/fsl_video_manifest.json` with their file
names, so the clips can be recorded and published a few at a time.

## Before you record

- **Turn HDR off** (iPhone: Settings → Camera → Formats → "Most
  Compatible", and HDR Video off; Android: the camera's HDR switch). HDR
  footage is saved in a format many school tablets cannot decode. The app
  then shows "Unable to load video". The first "Partly Cloudy" clip broke
  this way and had to be converted.
- 1080p at 30 frames per second is plenty. 60 is fine too; the tools convert
  either.
- Hold the phone **sideways (landscape)**, the same as every existing clip
  (1920 × 1080). Use a stand or a second person.
- Plain, light background; light from the front, not behind the signer.
- Signer in the middle, framed from just above the head to the waist, with
  room on both sides: both hands must stay in the picture through the whole
  sign, including at the top and bottom of the movement.
- Plain, dark top with no writing, so the hands stand out.

## While recording

- One word per clip. Start with the hands resting, sign once at a natural
  pace, and return to rest. Two to four seconds is typical.
- If a word has more than one common sign, use the one taught in Philippine
  SPED classrooms. Record the alternative as a second take if you are unsure,
  and let the teacher reviewing it choose.
- Say nothing that matters: the app plays sign clips muted.
- Name each file after the word, or keep the camera's names and note which
  is which. The publisher matches files by the `source` column in
  `tools/fsl_video_manifest.json`, for example `GREEN.MOV` → `build/fsl_mp4/GREEN.mp4`.

## After recording

Follow **"Adding newly recorded signs"** in [`tools/README.md`](../tools/README.md):

1. Convert into `build/fsl_mp4/` with the ffmpeg command there.
2. Run `node tools/fsl_check_clips.mjs`. It refuses HDR and other files a
   tablet cannot play.
3. Run `node tools/fsl_coverage_report.mjs --check`, then
   `node tools/publish_fsl_videos.mjs`. This uploads to the free
   `pwd-fsl-videos` GitHub release and rewrites the app's manifest. Signs
   already published are kept.
4. Commit `assets/data/fsl_video_manifest.json`, then build and release the
   app as usual. The "coming soon" labels disappear for every word that now
   has a clip, in the app and in the next website build.

Everything above is free: GitHub Releases for hosting and ffmpeg/Node for the
conversion.

## Offline sign packs

Learners in classrooms without dependable internet can keep the signs on the
tablet. In **FSL Dictionary → Offline sign packs** they can download one
category or all of them, see how much space each takes, and remove a pack
again. New signs published later appear as "not yet downloaded" in their
category's pack. Nothing downloads by itself, which matters on mobile data.
