#!/usr/bin/env node
// Reports which seed flashcards still have no Filipino Sign Language clip, and
// prints a ready-to-paste manifest stub for each one.
//
//   node tools/fsl_coverage_report.mjs            # human-readable report
//   node tools/fsl_coverage_report.mjs --stubs    # JSON rows to paste
//   node tools/fsl_coverage_report.mjs --apply    # write those rows for you
//   node tools/fsl_coverage_report.mjs --check    # validate the source manifest
//   node tools/fsl_coverage_report.mjs --csv      # recording checklist
//
// Why this exists: the gap is a *content* gap, not a code gap. Nothing in the
// app needs to change to light a word up — dropping a correctly-keyed entry
// into assets/data/fsl_video_manifest.json is enough. The only hard part is
// getting the key exactly right (`category` must be the FlashcardCategory
// label, `slug` the lowercased English word), because a typo silently leaves
// the card dark instead of failing loudly. So this generates the keys.
//
// Guarded by test/fsl_video_manifest_test.dart, which fails if a manifest entry
// does not match a real seed card.

import { readFileSync, writeFileSync } from 'node:fs';

const CATEGORY_LABELS = {
  animals: 'Animals',
  colorsAndShapes: 'Colors & Shapes',
  numbers: 'Numbers',
  bodyParts: 'Body Parts',
  foodAndDrinks: 'Food & Drinks',
  familyAndGreetings: 'Family & Greetings',
  clothing: 'Clothing',
  weather: 'Weather',
  classroom: 'Classroom',
  transportation: 'Transportation',
  emotions: 'Emotions',
  daysAndTime: 'Days & Time',
  actions: 'Actions',
};

// Kept in step with `FslAssetsService._crossCategoryAliases`: a card that
// borrows an identical sign from another category is covered, and must not be
// listed as needing a recording.
const CROSS_CATEGORY_ALIASES = {
  'Actions__walk': 'Transportation__walk',
};

const manifest = JSON.parse(
  readFileSync(new URL('../assets/data/fsl_video_manifest.json', import.meta.url), 'utf8'),
);
const entries = manifest.entries ?? manifest;
const covered = new Set(entries.map((e) => `${e.category}__${e.slug}`));
for (const [borrower, lender] of Object.entries(CROSS_CATEGORY_ALIASES)) {
  if (covered.has(lender)) covered.add(borrower);
}

const seed = readFileSync(
  new URL('../lib/data/local/seed_data.dart', import.meta.url),
  'utf8',
);
const CARD = /wordEnglish:\s*'([^']+)',\s*wordFilipino:\s*'([^']+)'[\s\S]*?category:\s*FlashcardCategory\.(\w+)\)/g;

const cards = [];
for (const [, en, fil, cat] of seed.matchAll(CARD)) {
  const category = CATEGORY_LABELS[cat];
  if (!category) continue;
  cards.push({ category, en, fil, slug: en.toLowerCase() });
}

const missing = cards.filter((c) => !covered.has(`${c.category}__${c.slug}`));
const mode = process.argv[2];

if (mode === '--stubs' || mode === '--apply') {
  // Source-manifest shape, NOT the app-manifest shape.
  //
  // These rows are pasted into tools/fsl_video_manifest.json, which
  // publish_fsl_videos.mjs reads with
  //   const { category, slug, wordEnglish, wordFilipino, source } = entry;
  // The app manifest it *writes* uses snake_case (word_english, download_url,
  // stream_url). Emitting that shape here — which this tool used to do — meant
  // every pasted row published as `word_english: undefined` with no file to
  // upload, silently, once per clip.
  const rows = missing.map((c) => ({
    category: c.category,
    slug: c.slug,
    wordEnglish: c.en,
    wordFilipino: c.fil,
    // Matches the convention of the 143 already published: the English word,
    // uppercased, as recorded off the camera.
    source: `${c.en.toUpperCase()}.MOV`,
  }));

  if (mode === '--stubs') {
    console.log(JSON.stringify(rows, null, 2));
  } else {
    const url = new URL('./fsl_video_manifest.json', import.meta.url);
    const src = JSON.parse(readFileSync(url, 'utf8'));
    const have = new Set(src.entries.map((e) => `${e.category}__${e.slug}`));
    const added = rows.filter((r) => !have.has(`${r.category}__${r.slug}`));
    src.entries.push(...added);
    writeFileSync(url, JSON.stringify(src, null, 2) + '\n');
    console.log(
      `Staged ${added.length} row(s) in tools/fsl_video_manifest.json ` +
        `(${rows.length - added.length} already present).`,
    );
    if (added.length) {
      // publish_fsl_videos.mjs looks the file up by the row's `source` field
      // with .MOV swapped for .mp4 — it derives the URL-safe
      // `<category>__<slug>.mp4` asset name itself, at upload time. Naming the
      // transcoded file after the asset name instead is the obvious mistake,
      // and it fails as a silent "SKIP ... missing".
      console.log('\nTranscode each recording to build/fsl_mp4/ named:');
      for (const r of added) {
        console.log(`    ${r.source.replace(/\.MOV$/i, '.mp4').padEnd(22)}  (${r.category} / ${r.wordEnglish})`);
      }
      console.log(
        '\nRows with no file yet are skipped, so you can publish after each ' +
          'recording session:\n    node tools/publish_fsl_videos.mjs',
      );
    }
  }
} else if (mode === '--check') {
  // Validates the SOURCE manifest, before anything is uploaded.
  //
  // test/fsl_video_manifest_test.dart guards the *app* manifest, which only
  // exists after a successful publish — so a malformed source row is not
  // caught until the upload has already happened.
  const src = JSON.parse(
    readFileSync(new URL('./fsl_video_manifest.json', import.meta.url), 'utf8'),
  );
  const seedKeys = new Set(cards.map((c) => `${c.category}__${c.slug}`));
  const problems = [];
  const seen = new Set();

  for (const [i, e] of src.entries.entries()) {
    const where = `entry ${i} (${e.category ?? '?'} / ${e.slug ?? '?'})`;
    for (const field of ['category', 'slug', 'wordEnglish', 'wordFilipino', 'source']) {
      if (!e[field]) problems.push(`${where}: missing "${field}"`);
    }
    if (e.word_english || e.word_filipino || e.download_url || e.stream_url) {
      problems.push(
        `${where}: app-manifest fields (word_english / download_url / …) — ` +
          'this file uses wordEnglish / wordFilipino / source',
      );
    }
    const key = `${e.category}__${e.slug}`;
    if (seen.has(key)) problems.push(`${where}: duplicate key "${key}"`);
    seen.add(key);
    if (e.category && e.slug && !seedKeys.has(key)) {
      problems.push(`${where}: "${key}" matches no seed card — the clip would never be reachable`);
    }
  }

  if (problems.length) {
    console.error(`Source manifest: ${problems.length} problem(s)
`);
    for (const p of problems) console.error(`  ✗ ${p}`);
    process.exit(1);
  }
  console.log(`Source manifest OK — ${src.entries.length} rows, all keyed to a real seed card.`);
} else if (mode === '--csv') {
  console.log('category,word_english,word_filipino,manifest_slug');
  for (const c of missing) {
    console.log(`"${c.category}","${c.en}","${c.fil}","${c.slug}"`);
  }
} else {
  const byCategory = new Map();
  for (const c of missing) {
    if (!byCategory.has(c.category)) byCategory.set(c.category, []);
    byCategory.get(c.category).push(c);
  }
  console.log(`FSL coverage: ${cards.length - missing.length} of ${cards.length} seed words have a sign`);
  console.log(`Still to record: ${missing.length}\n`);
  for (const [category, words] of [...byCategory].sort((a, b) => b[1].length - a[1].length)) {
    const total = cards.filter((c) => c.category === category).length;
    console.log(`${category} — ${words.length} of ${total} missing`);
    for (const c of words) {
      console.log(`    ${c.en.padEnd(16)} ${c.fil.padEnd(18)} slug: ${c.slug}`);
    }
    console.log('');
  }
  console.log('Run with --csv for a recording checklist, or --stubs for manifest entries.');
}
