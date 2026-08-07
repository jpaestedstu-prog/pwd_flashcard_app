// Regenerate the app's bundled FSL manifest so every entry carries a
// `download_url` pointing at the GitHub Release (the stable, non-expiring,
// free primary source). The existing `stream_url` (Cloudinary) is preserved
// as the runtime fallback — FslAssetsService tries download_url first,
// stream_url second.
//
// This does NOT upload anything: the 143 mp4 assets already live on the
// release. It only rewrites assets/data/fsl_video_manifest.json, and it
// REFUSES to write unless every generated URL matches a real release asset
// (so a slug quirk can't silently produce a 404 link).
//
// Usage:
//   node tools/regen_manifest_download_urls.mjs            # validate + write
//   node tools/regen_manifest_download_urls.mjs --dry      # validate only
//
// Repo/tag default to the confirmed FSL videos release; override with
// FSL_REPO / FSL_TAG env vars if you re-publish elsewhere.

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');
const APP_MANIFEST = join(REPO_ROOT, 'assets', 'data', 'fsl_video_manifest.json');

const REPO = process.env.FSL_REPO || 'jpaestedstu-prog/pwd-fsl-videos';
const TAG = process.env.FSL_TAG || 'v1';
const dryRun = process.argv.slice(2).includes('--dry');

// Identical to safeSlug() in publish_fsl_videos.mjs — the names on the
// release were produced by that exact function, so reusing it reproduces them.
function safeSlug(s) {
  return s
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function assetNameFor(entry) {
  return `${safeSlug(entry.category)}__${safeSlug(entry.slug)}.mp4`;
}

function downloadUrlFor(assetName) {
  return `https://github.com/${REPO}/releases/download/${encodeURIComponent(
    TAG,
  )}/${encodeURIComponent(assetName)}`;
}

// --- Pull the live asset list so we can validate against reality. ---------
const view = spawnSync(
  'gh',
  ['release', 'view', TAG, '--repo', REPO, '--json', 'assets'],
  { stdio: 'pipe', encoding: 'utf8' },
);
if (view.status !== 0) {
  console.error(
    `Could not read release ${REPO} @ ${TAG} via gh.\n${view.stderr || ''}` +
      '\nIs the gh CLI installed and authenticated (gh auth status)?',
  );
  process.exit(1);
}
const liveAssets = new Set(
  (JSON.parse(view.stdout).assets || []).map((a) => a.name),
);
console.log(`Release ${REPO} @ ${TAG}: ${liveAssets.size} assets live.`);

// --- Rewrite the manifest entries. ----------------------------------------
const manifest = JSON.parse(readFileSync(APP_MANIFEST, 'utf8'));
const entries = manifest.entries || [];

const missing = [];
const rebuilt = entries.map((e) => {
  const assetName = assetNameFor(e);
  if (!liveAssets.has(assetName)) {
    missing.push({ category: e.category, slug: e.slug, assetName });
  }
  // Re-emit fields in a stable, readable order; download_url before the
  // stream_url fallback. Any unexpected extra keys are carried through.
  const { category, slug, word_english, word_filipino, stream_url, ...rest } = e;
  return {
    category,
    slug,
    word_english,
    word_filipino,
    download_url: downloadUrlFor(assetName),
    ...(stream_url ? { stream_url } : {}),
    ...rest,
  };
});

if (missing.length) {
  console.error(
    `\nABORT: ${missing.length} entr${missing.length === 1 ? 'y has' : 'ies have'} ` +
      'no matching release asset — refusing to write 404 links:',
  );
  for (const m of missing) {
    console.error(`  • ${m.category} / ${m.slug}  →  expected ${m.assetName}`);
  }
  process.exit(2);
}

console.log(`All ${rebuilt.length} entries matched a live release asset.`);

if (dryRun) {
  console.log('Dry run — manifest not written.');
  process.exit(0);
}

manifest.entries = rebuilt;
manifest.generated_at = new Date().toISOString();
manifest.video_source = {
  primary: 'github_release',
  fallback: 'cloudinary',
  repo: REPO,
  tag: TAG,
};
writeFileSync(APP_MANIFEST, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
console.log(
  `Wrote ${APP_MANIFEST}\n  ${rebuilt.length} entries, each with download_url ` +
    '(GitHub Release) + stream_url (fallback).',
);
