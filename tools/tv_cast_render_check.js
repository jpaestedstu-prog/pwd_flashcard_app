/* TV Cast renderer check.
 *
 *   node tools/tv_cast_render_check.js .
 *
 * `flutter test` covers the /api/state contract but stops at the wire: nothing
 * exercises assets/tv_cast/app.js, and a bug there breaks every connected TV
 * silently while every Dart test stays green. This stubs just enough of a
 * browser to run the real app.js headlessly and drive it with the same
 * payloads the server actually emits.
 *
 * app.js is an IIFE with no exports, so the handle we use is `setInterval`:
 * the stub records every registration by delay, and the driver pumps the
 * 1500 ms one (the state poll) and the 1000 ms one (the lesson-timer tick)
 * by hand. Matching on delay rather than call order means adding another
 * interval to app.js can't silently repoint the driver at the wrong callback.
 *
 * Exits non-zero on the first failing check, so it can gate a release. */
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO = process.argv[2];

function mkEl(id) {
  const el = {
    id,
    _html: '',
    className: '',
    style: {},
    parentNode: null,
    onerror: null,
    children: [],
    appendChild(c) { this.children.push(c); c.parentNode = this; return c; },
    getElementsByTagName(tag) {
      return this._html.indexOf('<' + tag) >= 0 ? [mkEl(tag)] : [];
    },
    getElementsByClassName(cls) {
      return this._html.indexOf('class="' + cls) >= 0 ? [mkEl(cls)] : [];
    },
  };
  // Setting innerHTML in a real browser *parses* the markup into live nodes
  // that getElementById can then find and patch. Model just enough of that:
  // register every id="..." in the new markup as an addressable child whose
  // own innerHTML writes are tracked separately from the parent's.
  Object.defineProperty(el, 'innerHTML', {
    get() { return el._html; },
    set(v) {
      el._html = v;
      const re = /id="([^"]+)"/g;
      let m;
      while ((m = re.exec(v)) !== null) {
        if (m[1] === el.id) continue;
        els[m[1]] = els[m[1]] && els[m[1]]._synthetic
          ? els[m[1]]
          : Object.assign(mkEl(m[1]), { _synthetic: true });
        els[m[1]].innerHTML = '';
      }
    },
  });
  return el;
}

const els = {
  stage: mkEl('stage'),
  'footer-pill': mkEl('footer-pill'),
  'sound-hint': mkEl('sound-hint'),
};

// Elements app.js creates lazily (hands banner, branding, decoration) and then
// looks up by id — register them so the second lookup finds the same node.
function lookup(id) {
  return els[id] || null;
}

let pendingState = { rev: 0, mode: 'idle', live: {} };
let pollFn = null;
const spoken = [];

global.document = {
  getElementById: lookup,
  createElement: mkEl,
  // Lazily-created overlays (hands banner, lesson timer) are appended here and
  // then looked up by id, so registering them keeps both paths consistent.
  body: {
    className: '',
    appendChild(c) { els[c.id] = c; return c; },
  },
  documentElement: mkEl('html'),
  addEventListener() {},
  fullscreenElement: null,
};

global.window = {
  addEventListener() {},
  innerWidth: 1920,
  innerHeight: 1080,
  speechSynthesis: {
    cancel() {},
    speak(u) { spoken.push(u.text); },
  },
  CAST_BASE: '/c/CMRYP',
};
global.SpeechSynthesisUtterance = function (t) { this.text = t; };
global.window.SpeechSynthesisUtterance = global.SpeechSynthesisUtterance;

let lastUrl = null;
global.XMLHttpRequest = function () {
  this.open = (m, url) => { lastUrl = url; };
  this.send = () => {
    this.readyState = 4;
    this.status = 200;
    this.responseText = JSON.stringify(pendingState);
    if (this.onreadystatechange) this.onreadystatechange();
  };
};
// app.js registers more than one interval (the state poll, and a 1 s tick for
// the lesson-timer overlay). Capture them by delay so adding another can't
// silently repoint the driver at the wrong callback.
const intervals = [];
global.setInterval = (fn, ms) => { intervals.push({ fn, ms }); return 0; };
global.setTimeout = () => 0;

eval(fs.readFileSync(path.join(REPO, 'assets/tv_cast/app.js'), 'utf8'));

const pollEntry = intervals.find((i) => i.ms === 1500);
assert.ok(pollEntry, 'app.js should poll /api/state on a 1500 ms interval');
pollFn = pollEntry.fn;
const timerEntry = intervals.find((i) => i.ms === 1000);
assert.ok(timerEntry, 'app.js should tick the lesson timer every 1000 ms');
const tickTimerFn = timerEntry.fn;

let rev = 0;
function push(state) {
  state.rev = ++rev;
  if (!state.live) state.live = {};
  pendingState = state;
  pollFn();
  return els.stage.innerHTML;
}

// ─── Checks ───────────────────────────────────────────
const results = [];
function check(name, fn) {
  try { fn(); results.push(['PASS', name]); }
  catch (e) { results.push(['FAIL', name + ' — ' + e.message]); }
}

const FSL_Q = {
  id: 'q1',
  type: 'fslSign',
  prompt: '',
  options: ['Horse', 'Cow', 'Pig', 'Dog'],
  isTrueFalse: false,
  flashcardId: 'a01',
  word: 'Dog',
  emoji: '🐕',
  video: { available: true, url: '/api/video/0/dog' },
  photo: { available: true, url: '/api/image/0/dog' },
};

check('poll URL carries the session code', () => {
  assert.ok(lastUrl.indexOf('/c/CMRYP/api/state') === 0, lastUrl);
});

check('fslSign question renders the sign video, not an emoji', () => {
  const html = push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  assert.ok(html.indexOf('<video') >= 0, 'expected a <video> element');
  assert.ok(html.indexOf('class="live-emoji"') < 0, 'emoji should not be the question');
  assert.ok(html.indexOf('loop') >= 0 && html.indexOf('muted') >= 0, 'must autoplay muted+looping');
});

check('the sign URL is moved into the session-code namespace', () => {
  assert.ok(
    els.stage.innerHTML.indexOf('src="/c/CMRYP/api/video/0/dog"') >= 0,
    'video src was not code-scoped: ' + els.stage.innerHTML.slice(0, 400)
  );
});

check('answer options still render', () => {
  const html = els.stage.innerHTML;
  ['A. Horse', 'B. Cow', 'C. Pig', 'D. Dog'].forEach((o) =>
    assert.ok(html.indexOf(o) >= 0, 'missing ' + o));
});

check('a new answer patches the count and leaves the video untouched', () => {
  const before = els.stage.innerHTML;
  push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 3 } });
  // The stage markup — which contains the <video> — must be byte-identical:
  // that is the proof the element was never re-created and playback never
  // restarted mid-sign.
  assert.strictEqual(els.stage.innerHTML, before, 'stage was rebuilt');
  // …while the counter node itself was patched in place.
  assert.strictEqual(
    els['live-responded'].innerHTML, '3 answered',
    'counter did not update: ' + els['live-responded'].innerHTML
  );
});

check('a NEW question does rebuild', () => {
  const q2 = Object.assign({}, FSL_Q, { id: 'q2', word: 'Cat', video: { available: true, url: '/api/video/0/cat' } });
  const html = push({ mode: 'live', ttsOnTv: false, live: { activity: q2, responded: 0 } });
  assert.ok(html.indexOf('/c/CMRYP/api/video/0/cat') >= 0, 'did not switch clips');
});

check('pictureChoice renders the real photo', () => {
  const q = { id: 'p1', type: 'pictureChoice', options: ['Dog', 'Cat'], emoji: '🐕',
              photo: { available: true, url: '/api/image/0/dog' } };
  const html = push({ mode: 'live', ttsOnTv: false, live: { activity: q, responded: 0 } });
  assert.ok(html.indexOf('<img src="/c/CMRYP/api/image/0/dog"') >= 0, html.slice(0, 300));
});

check('no clip available falls back to the emoji', () => {
  const q = { id: 'p2', type: 'fslSign', options: ['A', 'B'], emoji: '🐕' };
  const html = push({ mode: 'live', ttsOnTv: false, live: { activity: q, responded: 0 } });
  assert.ok(html.indexOf('class="live-emoji"') >= 0, 'expected emoji fallback');
});

check('live question is spoken once, with its options', () => {
  spoken.length = 0;
  push({ mode: 'live', ttsOnTv: true, live: { activity: FSL_Q, responded: 0 } });
  assert.strictEqual(spoken.length, 1, 'expected one utterance, got ' + spoken.length);
  assert.ok(spoken[0].indexOf('Watch the sign') >= 0, spoken[0]);
  assert.ok(spoken[0].indexOf('A. Horse') >= 0, spoken[0]);
  // Same question again (one more answer) → must not re-read it.
  push({ mode: 'live', ttsOnTv: true, live: { activity: FSL_Q, responded: 1 } });
  assert.strictEqual(spoken.length, 1, 're-read the question on an answer');
});

check('the correct answer is never rendered', () => {
  assert.ok(els.stage.innerHTML.indexOf('correct') < 0);
});

check('classWins is the default progress view and shows totals + A-Z', () => {
  const html = push({
    mode: 'progress',
    progressView: 'classWins',
    progress: [{ rank: 1, name: 'Zoe', words: 9, streak: 2, stars: 40 }],
    classSummary: {
      learners: 2, words: 12, stars: 56, activeToday: 1, bestStreak: 3,
      rows: [
        { rank: 0, name: 'Ana', words: 3, streak: 1, stars: 16 },
        { rank: 0, name: 'Zoe', words: 9, streak: 2, stars: 40 },
      ],
    },
  });
  assert.ok(html.indexOf('Our Class Wins') >= 0, 'wrong heading');
  assert.ok(html.indexOf('words learned together') >= 0);
  assert.ok(html.indexOf('>12<') >= 0, 'class word total missing');
  assert.ok(html.indexOf('Ana') < html.indexOf('Zoe'), 'not alphabetical');
  assert.ok(html.indexOf('#1') < 0 && html.indexOf('rank') < 0, 'a rank leaked into the class view');
});

check('leaderboard view still ranks', () => {
  const html = push({
    mode: 'progress',
    progressView: 'leaderboard',
    progress: [{ rank: 1, name: 'Zoe', words: 9, streak: 2, stars: 40 }],
    classSummary: { learners: 1, words: 9, stars: 40, activeToday: 0, bestStreak: 2, rows: [] },
  });
  assert.ok(html.indexOf('Class Leaderboard') >= 0);
  assert.ok(html.indexOf('#1') >= 0);
});

check('leaving live mode and coming back repaints the question', () => {
  push({ mode: 'flashcards', ttsOnTv: false,
         slide: { index: 0, total: 1, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕', catLabel: 'Animals' } });
  const html = push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  assert.ok(html.indexOf('<video') >= 0, 'stale lastLiveKey left the stage blank');
});

check('away screen overrides live and clears the key', () => {
  push({ mode: 'live', away: true, ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  assert.ok(els.stage.innerHTML.indexOf('teacher is out') >= 0);
  const html = push({ mode: 'live', away: false, ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  assert.ok(html.indexOf('<video') >= 0, 'did not resume the question after away');
});

check('timer overlay appears without disturbing the content', () => {
  const withTimer = Object.assign(
    { mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } },
    { timer: { secondsLeft: 125, total: 300, paused: false, label: 'Clean up' } }
  );
  const stageBefore = push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  push(withTimer);
  // The timer lives in its own overlay node — the cast content is untouched,
  // which is what lets a countdown run over a playing sign clip.
  assert.strictEqual(els.stage.innerHTML, stageBefore, 'timer rebuilt the stage');
  const t = els['lesson-timer'];
  assert.ok(t, 'timer overlay was never created');
  assert.ok(t.innerHTML.indexOf('2:05') >= 0, 'wrong clock: ' + t.innerHTML);
  assert.ok(t.innerHTML.indexOf('Clean up') >= 0, 'label missing');
});

check('timer counts down locally between polls', () => {
  const t = els['lesson-timer'];
  tickTimerFn();
  assert.ok(t.innerHTML.indexOf('2:04') >= 0, 'local tick did not run: ' + t.innerHTML);
  tickTimerFn();
  assert.ok(t.innerHTML.indexOf('2:03') >= 0, t.innerHTML);
});

check('a poll re-syncs the clock (phone is authoritative)', () => {
  push(Object.assign(
    { mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } },
    { timer: { secondsLeft: 90, total: 300, paused: false, label: 'Clean up' } }
  ));
  assert.ok(els['lesson-timer'].innerHTML.indexOf('1:30') >= 0,
    'did not re-sync: ' + els['lesson-timer'].innerHTML);
});

check('paused timer stops counting', () => {
  push(Object.assign(
    { mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } },
    { timer: { secondsLeft: 90, total: 300, paused: true, label: '' } }
  ));
  const before = els['lesson-timer'].innerHTML;
  tickTimerFn();
  tickTimerFn();
  assert.strictEqual(els['lesson-timer'].innerHTML, before, 'paused clock moved');
  assert.ok(before.indexOf('paused') >= 0, 'no paused marker');
});

check('zero shows "Time\'s up!" and never counts past it', () => {
  push(Object.assign(
    { mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } },
    { timer: { secondsLeft: 0, total: 300, paused: false, label: '' } }
  ));
  const t = els['lesson-timer'];
  assert.ok(t.innerHTML.indexOf("Time's up!") >= 0, t.innerHTML);
  assert.ok(t.className.indexOf('finished') >= 0, 'missing finished class');
  tickTimerFn();
  assert.ok(t.innerHTML.indexOf("Time's up!") >= 0, 'counted past zero');
});

check('the last 30 seconds are marked by more than colour', () => {
  push(Object.assign(
    { mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } },
    { timer: { secondsLeft: 20, total: 300, paused: false, label: '' } }
  ));
  assert.ok(els['lesson-timer'].className.indexOf('ending') >= 0,
    'no "ending" class — a colour-only cue fails a colour-blind learner');
});

check('clearing the timer hides the overlay', () => {
  push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  assert.ok(els['lesson-timer'].className.indexOf('hidden') >= 0,
    'overlay outlived its timer');
});

check('text size and language become body classes', () => {
  push({ mode: 'flashcards', ttsOnTv: false, textSize: 'xl', lang: 'fil',
         slide: { index: 0, total: 1, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕', catLabel: 'Animals' } });
  const cls = global.document.body.className || '';
  assert.ok(cls.indexOf('text-xl') >= 0, 'missing text size class: ' + cls);
  assert.ok(cls.indexOf('lang-fil') >= 0, 'missing language class: ' + cls);
  assert.ok(cls.indexOf('theme-') >= 0, 'theme class was clobbered: ' + cls);
});

check('language filter also silences the other language', () => {
  spoken.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, lang: 'en',
         slide: { index: 5, total: 9, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕', catLabel: 'Animals' } });
  assert.ok(spoken.length >= 1, 'nothing spoken');
  assert.ok(spoken.join(' ').indexOf('Aso') < 0,
    'spoke the hidden language: ' + spoken.join(' | '));
  assert.ok(spoken.join(' ').indexOf('Dog') >= 0, 'did not speak the shown one');
});

const STORY = {
  titleEn: 'A Day at the Farm',
  titleFil: 'Isang Araw sa Bukid',
  emoji: '🐄',
  pageIndex: 4,
  totalPages: 5,
  textEn: 'The cow says moo.',
  textFil: 'Ang baka ay umuungal.',
};

check('a story page renders normally while pages remain', () => {
  const html = push({ mode: 'story', ttsOnTv: false, storyDone: false, story: STORY });
  assert.ok(html.indexOf('The cow says moo.') >= 0, 'page text missing');
  assert.ok(html.indexOf('The End') < 0, 'closed too early');
});

check('finishing a story shows "The End" instead of the last page', () => {
  const html = push({ mode: 'story', ttsOnTv: false, storyDone: true, story: STORY });
  assert.ok(html.indexOf('The End') >= 0, 'no closing screen');
  assert.ok(html.indexOf('A Day at the Farm') >= 0, 'story title missing');
  assert.ok(html.indexOf('5 pages read') >= 0, 'page count missing: ' + html);
  // The final sentence must be gone — leaving it up is the bug this fixes.
  assert.ok(html.indexOf('The cow says moo.') < 0, 'still showing the last page');
});

check('the closing screen is silent', () => {
  spoken.length = 0;
  push({ mode: 'story', ttsOnTv: true, storyDone: true, story: STORY });
  assert.strictEqual(spoken.length, 0, 'read something at the end: ' + spoken.join('|'));
});

check('Replay does not read the last page over "The End" either', () => {
  spoken.length = 0;
  // Same nonce bump the phone's Replay button sends.
  push({ mode: 'story', ttsOnTv: true, storyDone: true, story: STORY,
         ttsReplay: { n: 1, lang: 'both' } });
  push({ mode: 'story', ttsOnTv: true, storyDone: true, story: STORY,
         ttsReplay: { n: 2, lang: 'both' } });
  assert.strictEqual(spoken.length, 0, 'replayed a page that is not on screen: ' + spoken.join('|'));
});

check('stepping Back from "The End" repaints the page', () => {
  const html = push({ mode: 'story', ttsOnTv: false, storyDone: false, story: STORY });
  assert.ok(html.indexOf('The cow says moo.') >= 0, 'did not return to the page');
  assert.ok(html.indexOf('The End') < 0, 'closing screen stuck');
});

let failed = 0;
for (const [status, name] of results) {
  if (status === 'FAIL') failed++;
  console.log(status + '  ' + name);
}
console.log('\n' + (results.length - failed) + '/' + results.length + ' passed');
process.exit(failed ? 1 : 0);
