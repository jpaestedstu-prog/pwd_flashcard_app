#!/usr/bin/env node
// Checks every transcoded clip in build/fsl_mp4/ will actually decode on a
// learner's device, before any of them are uploaded.
//
//   node tools/fsl_check_clips.mjs
//
// Why this exists: `weather__partly-cloudy.mp4` was recorded, transcoded and
// uploaded to the release like the other 143 — and never played. The phone it
// was shot on had HDR on, so it exported as H.264 **High 10** profile
// (yuv420p10le, BT.2020 HLG). The tablet's AVC decoder refuses that outright:
//
//   ExoPlaybackException: MediaCodecVideoRenderer error,
//     format=Format(..., avc1.6E002A, [1920, 1080, 60.0,
//       ColorInfo(BT2020, Limited range, HLG, false, 10bit Luma, 10bit Chroma)]),
//     format_supported=NO_EXCEEDS_CAPABILITIES
//
// Nothing in the pipeline noticed. The upload succeeded, the manifest entry
// looked identical to its neighbours, and the failure only appeared as
// "Unable to load video" in front of a Deaf learner — the one person who
// cannot route around it. Every clip that plays today is 8-bit SDR
// (High / yuv420p / BT.709); this asserts new ones match.
//
// Fix a rejected clip with the tone-mapping recipe in tools/README.md.

import { existsSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MP4_DIR = join(__dirname, '..', 'build', 'fsl_mp4');

// ffmpeg is not reliably on PATH on this machine; fall back to the WinGet
// install location before giving up.
const FFPROBE_CANDIDATES = [
  'ffprobe',
  'C:\\ffmpeg\\bin\\ffprobe.exe',
  '/c/ffmpeg/bin/ffprobe.exe',
];

export function findFfprobe() {
  for (const candidate of FFPROBE_CANDIDATES) {
    try {
      execFileSync(candidate, ['-version'], { stdio: 'ignore' });
      return candidate;
    } catch {
      /* try the next one */
    }
  }
  return null;
}

export function inspect(ffprobe, file) {
  const out = execFileSync(
    ffprobe,
    [
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=profile,pix_fmt,color_transfer,color_primaries,width,height',
      '-of', 'default=noprint_wrappers=1:nokey=0',
      file,
    ],
    { encoding: 'utf8' },
  );
  return Object.fromEntries(
    out
      .trim()
      .split(/\r?\n/)
      .map((line) => line.split('=')),
  );
}

/// The decode rules every published clip has satisfied so far.
export function problemsFor(info) {
  const problems = [];
  if (/10/.test(info.profile ?? '')) {
    problems.push(`H.264 profile "${info.profile}" — 10-bit is not decodable on the target tablets`);
  }
  if (info.pix_fmt && info.pix_fmt !== 'yuv420p') {
    problems.push(`pix_fmt "${info.pix_fmt}" — needs yuv420p (8-bit)`);
  }
  if (info.color_primaries && !['bt709', 'unknown', 'reserved'].includes(info.color_primaries)) {
    problems.push(`color_primaries "${info.color_primaries}" — needs bt709 (SDR)`);
  }
  if (
    info.color_transfer &&
    !['bt709', 'unknown', 'reserved'].includes(info.color_transfer)
  ) {
    problems.push(`color_transfer "${info.color_transfer}" — HDR, needs bt709`);
  }
  return problems;
}

if (import.meta.url === `file://${process.argv[1]}`.replace(/\\/g, '/') ||
    process.argv[1]?.endsWith('fsl_check_clips.mjs')) {
  const ffprobe = findFfprobe();
  if (!ffprobe) {
    console.error('ffprobe not found — install ffmpeg, or check C:\\ffmpeg\\bin.');
    process.exit(1);
  }
  if (!existsSync(MP4_DIR)) {
    console.error(`No ${MP4_DIR} — transcode first (see tools/README.md).`);
    process.exit(1);
  }

  const files = readdirSync(MP4_DIR).filter((f) => f.toLowerCase().endsWith('.mp4'));
  if (!files.length) {
    console.error(`No .mp4 files in ${MP4_DIR}.`);
    process.exit(1);
  }

  let bad = 0;
  for (const file of files) {
    const info = inspect(ffprobe, join(MP4_DIR, file));
    const problems = problemsFor(info);
    if (problems.length) {
      bad++;
      console.error(`✗ ${file}`);
      for (const p of problems) console.error(`    ${p}`);
    } else {
      console.log(`✓ ${file.padEnd(28)} ${info.profile} ${info.pix_fmt} ${info.width}x${info.height}`);
    }
  }

  console.log(`\n${files.length - bad} of ${files.length} clip(s) will decode.`);
  if (bad) {
    console.error(
      `\n${bad} clip(s) would upload and then fail to play. Re-encode them with\n` +
        `the tone-mapping recipe in tools/README.md, then re-run this check.`,
    );
    process.exit(1);
  }
}
