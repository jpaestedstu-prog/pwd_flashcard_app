// Publishes the 143 FSL videos to a GitHub Release and regenerates the
// bundled manifest the Flutter app reads at startup.
//
// What it does:
//   1. Reads tools/fsl_video_manifest.json (source-of-truth: category, slug,
//      English / Filipino labels, original .MOV filename).
//   2. For each entry, finds the transcoded .mp4 in build/fsl_mp4/ and
//      renames it to a URL-safe `<category-slug>__<word-slug>.mp4`.
//   3. Uploads all files to the configured GitHub Release via `gh CLI`
//      (idempotent — `--clobber` overwrites existing assets).
//   4. Writes assets/data/fsl_video_manifest.json with each entry's public
//      download URL — this is what the Flutter app loads.
//
// Why GitHub Releases:
//   - Completely free, no billing, no bandwidth quotas you'll realistically
//     hit for a thesis project.
//   - Stable URLs that don't expire.
//   - One-shot upload via `gh CLI`.
//
// Prerequisites:
//   - `gh` CLI installed and logged in (`gh auth status` works).
//   - A repo + release tag to upload to (defaults below — override with
//     FSL_REPO / FSL_TAG env vars).
//   - .mp4 files already transcoded to build/fsl_mp4/ — see tools/README.md.
//
// Run:
//   $env:FSL_REPO = "your-github-username/pwd-fsl-videos"  # one-time
//   $env:FSL_TAG  = "v1"                                    # one-time
//   node tools/publish_fsl_videos.mjs              # uploads everything
//   node tools/publish_fsl_videos.mjs --dry        # preview without uploading
//   node tools/publish_fsl_videos.mjs --only=dog   # one entry by slug

import { readFileSync, writeFileSync, existsSync, statSync, copyFileSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { inspect, problemsFor, findFfprobe } from './fsl_check_clips.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const MP4_DIR = join(REPO_ROOT, 'build', 'fsl_mp4');
const STAGE_DIR = join(REPO_ROOT, 'build', 'fsl_release');
const SOURCE_MANIFEST = join(__dirname, 'fsl_video_manifest.json');
const APP_MANIFEST = join(REPO_ROOT, 'assets', 'data', 'fsl_video_manifest.json');

const REPO = process.env.FSL_REPO || 'YOUR-GITHUB-USERNAME/pwd-fsl-videos';
const TAG = process.env.FSL_TAG || 'v1';

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry');
const onlyArg = [...args].find((a) => a.startsWith('--only='));
const onlySlug = onlyArg ? onlyArg.slice('--only='.length) : null;

if (REPO.startsWith('YOUR-GITHUB-USERNAME')) {
  console.error(
    'Set the FSL_REPO env var first, e.g.:\n' +
      '  $env:FSL_REPO = "your-username/pwd-fsl-videos"\n' +
      'Or hard-code REPO at the top of this file.',
  );
  process.exit(1);
}

// Ensure gh CLI is available and authenticated.
const ghCheck = spawnSync('gh', ['auth', 'status'], { stdio: 'pipe', encoding: 'utf8' });
if (ghCheck.status !== 0) {
  console.error(
    'gh CLI is not installed or not authenticated.\n' +
      '  Install: https://cli.github.com/\n' +
      '  Then: gh auth login',
  );
  process.exit(1);
}

const source = JSON.parse(readFileSync(SOURCE_MANIFEST, 'utf8'));
const entries = source.entries.filter((e) => !onlySlug || e.slug === onlySlug);
console.log(
  `Publishing ${entries.length} videos to ${REPO} @ ${TAG}${dryRun ? ' (dry-run)' : ''}\n`,
);

// Make sure the release exists. `gh release view` exits 1 if not found.
if (!dryRun) {
  const view = spawnSync('gh', ['release', 'view', TAG, '--repo', REPO], { stdio: 'pipe' });
  if (view.status !== 0) {
    console.log(`Creating release ${TAG}...`);
    const create = spawnSync(
      'gh',
      [
        'release',
        'create',
        TAG,
        '--repo',
        REPO,
        '--title',
        `FSL videos ${TAG}`,
        '--notes',
        'Filipino Sign Language sign videos for the PWD Flashcard app.',
      ],
      { stdio: 'inherit' },
    );
    if (create.status !== 0) {
      console.error('Failed to create release.');
      process.exit(2);
    }
  }
}

// Stage all the renamed files in build/fsl_release/, then upload in one batch.
if (existsSync(STAGE_DIR)) {
  rmSync(STAGE_DIR, { recursive: true, force: true });
}
mkdirSync(STAGE_DIR, { recursive: true });

// What the app already ships, keyed the same way as the source rows.
//
// The bundled manifest is rewritten from `publishedEntries` at the end of this
// script, and a row whose .mp4 is not in build/fsl_mp4/ never reaches that
// list. Without carrying the previous entry forward, publishing a handful of
// newly recorded clips would rewrite the manifest with *only* those clips and
// silently drop every sign already live — the videos would still be on the
// release, but the app would go dark for all of them. Recording the remaining
// clips a few at a time is the expected workflow, so the manifest has to grow,
// never shrink.
const existingByKey = new Map();
if (existsSync(APP_MANIFEST)) {
  try {
    const prev = JSON.parse(readFileSync(APP_MANIFEST, 'utf8'));
    for (const e of prev.entries ?? []) {
      existingByKey.set(`${e.category}__${e.slug}`, e);
    }
  } catch {
    console.warn('! Could not read the existing app manifest — nothing to carry forward.');
  }
}

const publishedEntries = [];
let staged = 0;
let skipped = 0;
let carried = 0;
const rejected = [];
const ffprobe = findFfprobe();
if (!ffprobe) {
  console.warn('! ffprobe not found — skipping the decode check on each clip.');
}

for (const entry of entries) {
  const { category, slug, wordEnglish, wordFilipino, source: sourceFile } = entry;
  const mp4Name = sourceFile.replace(/\.MOV$/i, '.mp4');
  const localPath = join(MP4_DIR, mp4Name);

  if (!existsSync(localPath)) {
    const prior = existingByKey.get(`${category}__${slug}`);
    if (prior) {
      publishedEntries.push(prior);
      carried++;
      console.log(`• KEEP ${slug.padEnd(20)} already published`);
    } else {
      console.log(`• SKIP ${slug.padEnd(20)} missing ${mp4Name}`);
      skipped++;
    }
    continue;
  }

  // Refuse to upload a clip the target devices cannot decode.
  //
  // weather__partly-cloudy.mp4 got all the way onto the release and into a
  // learner's hands as "Unable to load video" because it was exported in
  // 10-bit HDR. Nothing in this pipeline looked at the file itself.
  if (ffprobe) {
    const problems = problemsFor(inspect(ffprobe, localPath));
    if (problems.length) {
      console.error(`• REJECT ${slug.padEnd(18)} ${mp4Name}`);
      for (const p of problems) console.error(`      ${p}`);
      rejected.push(slug);
      const prior = existingByKey.get(`${category}__${slug}`);
      if (prior) publishedEntries.push(prior); // keep whatever already worked
      continue;
    }
  }

  const assetName = `${safeSlug(category)}__${safeSlug(slug)}.mp4`;
  const stagedPath = join(STAGE_DIR, assetName);
  copyFileSync(localPath, stagedPath);

  publishedEntries.push({
    category,
    slug,
    word_english: wordEnglish,
    word_filipino: wordFilipino,
    download_url: `https://github.com/${REPO}/releases/download/${encodeURIComponent(
      TAG,
    )}/${encodeURIComponent(assetName)}`,
    size_bytes: statSync(localPath).size,
  });

  console.log(`• stage ${assetName.padEnd(40)} (${prettySize(localPath)})`);
  staged++;
}

if (staged === 0) {
  console.error(
    '\nNothing to upload. Did you run the transcode step first? See tools/README.md.',
  );
  process.exit(2);
}

// Upload all staged files to the release — in batches so we don't blow the
// command-line length limit (Windows ~32 KB) or trip per-call timeouts on
// large uploads. 25 files * ~150-byte paths leaves plenty of headroom.
const BATCH_SIZE = 25;
let uploaded = 0;
let failed = 0;
if (!dryRun) {
  const stagedFiles = readdirSync(STAGE_DIR).map((f) => join(STAGE_DIR, f));
  console.log(
    `\nUploading ${stagedFiles.length} files via gh release upload (batched)...`,
  );
  for (let i = 0; i < stagedFiles.length; i += BATCH_SIZE) {
    const batch = stagedFiles.slice(i, i + BATCH_SIZE);
    const batchNo = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(stagedFiles.length / BATCH_SIZE);
    console.log(
      `  batch ${batchNo}/${totalBatches} — ${batch.length} files...`,
    );
    const upload = spawnSync(
      'gh',
      ['release', 'upload', TAG, ...batch, '--repo', REPO, '--clobber'],
      { stdio: 'inherit' },
    );
    if (upload.status !== 0) {
      console.error(`  ✗ batch ${batchNo} failed — see gh output above.`);
      failed += batch.length;
    } else {
      uploaded += batch.length;
    }
  }
  if (failed > 0) {
    console.error(
      `\n${failed} file(s) failed to upload. Manifest NOT regenerated so the ` +
        `app keeps the previous URLs. Fix the underlying issue (check ` +
        `gh auth status, the repo name, and your network) and re-run.`,
    );
    process.exit(2);
  }

  // Verify the release actually has the expected number of assets — guards
  // against a "happy path" gh CLI that doesn't return non-zero on quota or
  // server-side errors.
  const verify = spawnSync(
    'gh',
    [
      'release',
      'view',
      TAG,
      '--repo',
      REPO,
      '--json',
      'assets',
      '-q',
      '.assets | length',
    ],
    { encoding: 'utf8' },
  );
  const remoteCount = parseInt(verify.stdout?.trim() || '0', 10);
  if (remoteCount < publishedEntries.length) {
    console.error(
      `\nRemote release has only ${remoteCount} assets but we expected ` +
        `${publishedEntries.length}. Manifest NOT regenerated. Re-run the ` +
        `script (it's idempotent with --clobber) to retry the missing ones.`,
    );
    process.exit(2);
  }
  console.log(`\n✓ Verified: ${remoteCount} assets on the remote release.`);
} else {
  console.log(`\n(dry-run) would upload ${staged} files via gh release upload.`);
  console.log(
    `(dry-run) manifest NOT regenerated — re-run without --dry to publish for real.`,
  );
  console.log(`uploaded=0 skipped=${skipped} failed=0  (dry-run)`);
  process.exit(0);
}

// Last line of defence before overwriting the file the app ships.
//
// Coverage is only ever supposed to grow. If this run would publish fewer
// signs than are already live, something is wrong with the inputs (a
// half-populated build/fsl_mp4/, a truncated source manifest) — and writing it
// out would take working signs away from learners. Refuse instead, and say
// exactly what was about to be lost.
if (publishedEntries.length < existingByKey.size) {
  const now = new Set(publishedEntries.map((e) => `${e.category}__${e.slug}`));
  const lost = [...existingByKey.keys()].filter((k) => !now.has(k));
  console.error(
    `\n✗ Refusing to write the manifest: it would drop from ` +
      `${existingByKey.size} to ${publishedEntries.length} entries.`,
  );
  console.error(`  These signs would disappear from the app:`);
  for (const k of lost.slice(0, 15)) console.error(`    - ${k}`);
  if (lost.length > 15) console.error(`    … and ${lost.length - 15} more`);
  console.error(
    `\n  The uploads above are safe on the release; nothing was lost. Restore\n` +
      `  the missing rows in tools/fsl_video_manifest.json (or the .mp4 files in\n` +
      `  build/fsl_mp4/) and re-run. Pass --allow-shrink only if you genuinely\n` +
      `  mean to retire those signs.`,
  );
  if (!process.argv.includes('--allow-shrink')) process.exit(3);
}

// Only regenerate the bundled manifest once we know the upload succeeded.
const appManifest = {
  generated_at: new Date().toISOString(),
  release_tag: TAG,
  release_repo: REPO,
  entries: publishedEntries,
};
writeFileSync(APP_MANIFEST, JSON.stringify(appManifest, null, 2) + '\n');
console.log(
  `\nWrote ${APP_MANIFEST} with ${publishedEntries.length} entries ` +
    `(${uploaded} new this run, ${carried} carried forward).`,
);
console.log(
  `uploaded=${uploaded} carried=${carried} skipped=${skipped} failed=${failed}`,
);

function safeSlug(s) {
  return s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function prettySize(path) {
  const bytes = statSync(path).size;
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}
