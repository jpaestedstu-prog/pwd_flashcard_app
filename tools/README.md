# FSL video publishing tool

Free-tier pipeline for hosting the 143 sign-language recordings on **GitHub
Releases** and serving them to the Flutter app via on-device caching.

## Why GitHub Releases (not Firebase Storage)

Firebase Storage now requires the Blaze (paid) plan, which isn't an option
for this thesis project. GitHub Releases is:

- **Free**, no billing, no bandwidth quota you'll realistically hit for a
  thesis demo or small classroom rollout.
- **Stable URLs** that don't expire.
- **One-shot upload** via the `gh` CLI — no SDK or service account needed.

The app reads a small JSON manifest bundled at
`assets/data/fsl_video_manifest.json` (under 30 KB) to know which videos
exist and where to fetch them. The video files themselves are downloaded on
first play and cached on-device by `flutter_cache_manager`.

## What you'll do

1. Create a separate GitHub repo for the videos (one-time, ~1 min).
2. Transcode `.MOV` → `.mp4` (one-time, ~10–30 min).
3. Run `node tools/publish_fsl_videos.mjs` — uploads to the GitHub Release
   and regenerates the app's bundled manifest.
4. Commit the updated `assets/data/fsl_video_manifest.json` and run the app.

## Prerequisites

- **ffmpeg** — `winget install Gyan.FFmpeg` in PowerShell, then restart your
  terminal so `ffmpeg` is on PATH.
- **Node.js 18+** — `node --version` to check.
- **GitHub CLI** — `winget install GitHub.cli`, then `gh auth login` and
  follow the prompts.

## Step 1 — Create the videos repo

Make a separate, public GitHub repo to hold the videos. Public so the asset
URLs work without auth; the FSL videos aren't sensitive.

```powershell
gh repo create pwd-fsl-videos --public --description "Filipino Sign Language videos for the PWD Flashcard app"
```

You don't need to clone it. The publish script attaches files to a
**Release** on that repo without ever pushing a commit.

## Step 2 — Transcode `.MOV` → `.mp4`

From the app's repo root in PowerShell:

```powershell
$src = "$PWD\assets\fsl videos"
$dst = "$PWD\build\fsl_mp4"
New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $src -Filter *.MOV | ForEach-Object {
  $out = Join-Path $dst ($_.BaseName + ".mp4")
  & ffmpeg -y -i $_.FullName `
    -vcodec libx264 -preset medium -crf 23 `
    -acodec aac -b:a 128k -movflags +faststart $out
}
```

This produces 143 `.mp4` files in `build/fsl_mp4/`. Each is typically 1–5 MB
(down from 10–30 MB of the original `.MOV`).

Spot-check one in any media player to confirm it plays.

## Step 3 — Publish

Set the env vars once per shell, then run:

```powershell
$env:FSL_REPO = "your-github-username/pwd-fsl-videos"
$env:FSL_TAG  = "v1"
node tools/publish_fsl_videos.mjs
```

Output looks like:

```
Publishing 143 videos to your-username/pwd-fsl-videos @ v1
Creating release v1...
• stage animals__dog.mp4                       (1.4 MB)
• stage animals__cat.mp4                       (1.2 MB)
...
Uploading 143 files via gh release upload...
Wrote .../assets/data/fsl_video_manifest.json with 143 entries.
uploaded=143 skipped=0 failed=0
```

Useful flags:

- `node tools/publish_fsl_videos.mjs --dry` — preview without uploading.
- `node tools/publish_fsl_videos.mjs --only=dog` — push just one entry
  (re-runs are safe; `--clobber` overwrites existing assets).

See **Recording the remaining clips** below for the incremental workflow —
you do not have to record everything before publishing again.

## Step 4 — Verify in the app

```powershell
flutter pub get
flutter run
```

`assets/data/fsl_video_manifest.json` has been regenerated with the live
URLs. Commit it:

```powershell
git add assets/data/fsl_video_manifest.json
git commit -m "FSL: publish 143 videos to GH Releases"
```

In the app:

1. **Cards → FSL Videos**: tap a word. First play downloads (~1 s on wifi);
   replays are instant from cache.
2. **FSL Dictionary**: each category shows cards with the play-circle icon
   (registered) vs the cam-off icon (not registered).
3. **Games → FSL Practice**: both modes should be playable for all 12
   categories. _Colors & Shapes_ is one video short (Green missing) — still
   meets the ≥3 floor.

To verify offline behaviour: play a few videos online, then toggle airplane
mode and replay them. They should still work (served from
`flutter_cache_manager`'s on-device store).

## What's in this folder

- `fsl_video_manifest.json` — **source-of-truth** mapping: category, slug,
  English / Filipino labels, original `.MOV` filename. Edit this when you
  add or rename a video.
- `publish_fsl_videos.mjs` — the publish script.
- `service-account.json` — _legacy, no longer used_; safe to delete.
- `tv_cast_render_check.js` — headless check of the TV Cast display. Run with
  `node tools/tv_cast_render_check.js .` — it stubs a browser, loads the real
  `assets/tv_cast/app.js`, and drives it with the payloads the cast server
  emits. Worth running after touching `app.js` or the `/api/state` shape:
  `flutter test` covers the wire format but nothing else exercises the
  TV-side rendering, so a bug there is invisible until a class is watching.

## Known mapping notes

- `GREEN.MOV` is **missing** — record one later and add an entry to
  `fsl_video_manifest.json`. The script will pick it up on the next run.
- `BUTTTERFLY.MOV` (3 T's) and `SUPRISED.MOV` are uploaded under the correct
  slugs (`butterfly`, `surprised`). The source filename mismatch is just
  cosmetic — only the slug + category matter for the app.
- "Chicken" appears in both Animals (animal) and Food & Drinks (cooked).
  The manifest maps `CHICKEN.MOV` → animal, `CHICKEN- FOOD.MOV` → food.
  Release asset names disambiguate (`animals__chicken.mp4` vs
  `food-and-drinks__chicken.mp4`), and the app's catalog keys on
  `(category, slug)`.


## Recording the remaining clips

34 seed words still have no sign. `node tools/fsl_coverage_report.mjs` lists
them; `docs/fsl_recording_checklist.csv` is the same list as a shooting sheet.

**All 34 rows are already staged** in `tools/fsl_video_manifest.json`
(`node tools/fsl_coverage_report.mjs --apply` did it, and is idempotent if you
add seed words later). A staged row whose `.mp4` is not on disk is skipped, so
you can record a few at a time and publish after each session.

Per session:

0. **Turn HDR off on the camera** before you shoot — see *The decode trap*.
1. **Record**, then transcode into `build/fsl_mp4/` using the Step 2 recipe.
   Name each file after the row's `source` field with `.MOV` swapped for
   `.mp4` — `GREEN.mp4`, `BOTTLE.mp4`, `RUN.mp4`. **Not** the release asset
   name (`colors-shapes__green.mp4`); the publisher derives that itself, and a
   file named the wrong way fails as a silent `SKIP`.
2. **Check** the clips and the manifest, both before anything uploads:

   ```powershell
   node tools/fsl_check_clips.mjs             # will these actually decode?
   node tools/fsl_coverage_report.mjs --check # is every row keyed correctly?
   ```
3. **Publish**: `node tools/publish_fsl_videos.mjs`. Rows with no file yet print
   `SKIP`; signs already live print `KEEP` and are carried into the regenerated
   manifest unchanged.
4. **Verify**: `flutter test test/fsl_video_manifest_test.dart`, then commit
   `assets/data/fsl_video_manifest.json` and `tools/fsl_video_manifest.json`.

### Why the manifest can only grow

The bundled manifest is rewritten from the rows the publisher walked. Before
the `KEEP` behaviour existed, publishing five newly recorded clips with only
those five files in `build/fsl_mp4/` would have rewritten the manifest with
**five entries** — dropping the other 143 signs out of the app while printing
what looked like a successful run. The videos would still be on the release;
the app would simply stop knowing about them.

Two things now prevent that: previously-published entries are carried forward,
and the script refuses to write a manifest smaller than the one it is replacing
(naming the signs that would be lost). `--allow-shrink` overrides it, and is
only correct when you genuinely mean to retire a sign.

`test/fsl_video_manifest_test.dart` guards the same invariant from the other
side: every published sign must still have a row in the source manifest.

### Matching the existing recordings

New clips sit next to 143 already in the app, so keep them consistent: plain
light background, signer framed head-to-mid-torso and centred, solid dark top,
even front lighting, no on-screen text, and just the sign — start and end with
hands at rest. The app plays these at 0.25x–1.5x, so a clip that is rushed at
1x becomes unreadable slowed down.


## The decode trap (found 2026-08-15)

`weather__partly-cloudy.mp4` was recorded, transcoded and uploaded to the
release exactly like the other 143 — and never played. It was shot on a phone
with **HDR enabled**, so it exported as H.264 **High 10** profile
(`yuv420p10le`, BT.2020 HLG). The tablet's AVC decoder refuses that outright:

```
ExoPlaybackException: MediaCodecVideoRenderer error,
  format=Format(..., avc1.6E002A, [1920, 1080, 60.0,
    ColorInfo(BT2020, Limited range, HLG, false, 10bit Luma, 10bit Chroma)]),
  format_supported=NO_EXCEEDS_CAPABILITIES
```

Nothing noticed. The upload succeeded, the manifest row looked identical to its
neighbours, and the only symptom was **"Unable to load video"** in front of a
Deaf learner — the one person who cannot route around a missing sign.

Every clip that plays today is 8-bit SDR:

| | plays | fails |
|---|---|---|
| profile | `High` | `High 10` |
| pix_fmt | `yuv420p` | `yuv420p10le` |
| primaries / transfer | `bt709` | `bt2020` / `arib-std-b67` |

**Prevention:** shoot with HDR **off**. `node tools/fsl_check_clips.mjs`
verifies every file in `build/fsl_mp4/` before you publish, and
`publish_fsl_videos.mjs` now refuses to upload a clip that fails the same
check, so a bad export cannot reach a learner again.

**Salvaging HDR footage** you have already shot — tone-map it down to SDR
rather than reshooting:

```powershell
& C:fmpeginfmpeg.exe -y -i in.mp4 `
  -vf "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" `
  -c:v libx264 -profile:v high -crf 23 -preset medium `
  -c:a aac -b:a 128k -movflags +faststart out.mp4
```

A plain `-pix_fmt yuv420p` also converts, but without tone-mapping HLG footage
comes out washed out and flat — which costs exactly the hand/background
contrast a sign needs to be readable.
