#!/usr/bin/env node
// Reports which seed flashcards still have no Filipino Sign Language clip, and
// prints a ready-to-paste manifest stub for each one.
//
//   node tools/fsl_coverage_report.mjs            # human-readable report
//   node tools/fsl_coverage_report.mjs --stubs    # JSON entries to paste
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

import { readFileSync } from 'node:fs';

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

if (mode === '--stubs') {
  // Paste into `entries`, then fill in the two URLs. `download_url` is the
  // primary (GitHub Release), `stream_url` the fallback (Cloudinary).
  console.log(
    JSON.stringify(
      missing.map((c) => ({
        category: c.category,
        slug: c.slug,
        word_english: c.en,
        word_filipino: c.fil,
        download_url: '',
        stream_url: '',
      })),
      null,
      2,
    ),
  );
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
