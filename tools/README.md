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

When you record `GREEN` later, drop it in `build/fsl_mp4/`, add a row to
`tools/fsl_video_manifest.json`, and re-run `node tools/publish_fsl_videos.mjs`.

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
