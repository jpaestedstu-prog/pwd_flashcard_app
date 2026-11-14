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
    // Attributes as written (a relative src stays relative, as in a browser).
    getAttribute(name) { return this['_attr_' + name] !== undefined ? this['_attr_' + name] : (name === 'src' && this.src !== undefined ? this.src : null); },
    setAttribute(name, value) { this['_attr_' + name] = String(value); },
    focus() {},
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
        // Parsed nodes are children of whatever they were parsed into. app.js
        // guards its deferred image paints on `parentNode` ("is this element
        // still on screen?"), so leaving it null made every picture silently
        // never paint in this harness.
        els[m[1]].parentNode = el;
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

// <audio> / <video> the way a TV browser has them: it can play a WAV, and
// play() answers with a promise — refused (NotAllowedError) while
// `mediaBlocked` is set, which is a browser waiting for a key press.
const mediaLog = [];
let mediaBlocked = false;
function mkMedia(tag) {
  const el = mkEl(tag);
  el.paused = true;
  el.muted = false;
  el.playbackRate = 1;
  el.defaultPlaybackRate = 1;
  el.canPlayType = (t) => (t.indexOf('wav') >= 0 ? 'maybe' : '');
  el.play = function () {
    const self = this;
    if (mediaBlocked) {
      return { then(ok, bad) { if (bad) bad({ name: 'NotAllowedError' }); } };
    }
    self.paused = false;
    mediaLog.push({ tag, src: self.src, rate: self.playbackRate, muted: self.muted });
    if (self.onplaying) self.onplaying();
    return { then(ok) { if (ok) ok(); } };
  };
  el.pause = function () { this.paused = true; };
  return el;
}

// Timers are recorded, not run: a check advances them with flushTimers(),
// so "say the word once the card has landed" is testable without waiting.
let timers = [];
let timerSeq = 0;
function flushTimers(rounds) {
  for (let r = 0; r < (rounds || 3); r++) {
    const due = timers;
    timers = [];
    if (!due.length) return;
    due.forEach((t) => { if (t.fn) t.fn(); });
  }
}

// Key presses arrive the way a TV remote sends them: keydown on the document.
const listeners = {};
function key(code, name) {
  const ev = { keyCode: code, which: code, key: name || '', preventDefault() {} };
  (listeners.keydown || []).forEach((fn) => fn(ev));
}

const historyLog = [];

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
  addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
  fullscreenElement: null,
};
global.document.createElement = (tag) =>
  (tag === 'audio' || tag === 'video' ? mkMedia(tag) : mkEl(tag));

global.window = {
  addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
  history: {
    pushState() { historyLog.push('push'); },
    back() { historyLog.push('back'); },
    go(n) { historyLog.push('go ' + n); },
  },
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

// Pictures, GIFs and story illustrations are preloaded through `new Image()`
// and only painted onto the card once they resolve, so without this the whole
// photo path throws and the checks silently never reach it. Firing onload the
// moment a src is assigned is the useful stub: the paint actually runs, so a
// check can assert the picture reached the face it was meant to.
global.Image = function () {
  const self = this;
  self.onload = null;
  self.onerror = null;
  Object.defineProperty(self, 'src', {
    get() { return self._src; },
    set(v) { self._src = v; if (self.onload) self.onload(); },
  });
};

let lastUrl = null;
const urls = [];
global.XMLHttpRequest = function () {
  this.open = (m, url) => { lastUrl = url; urls.push(url); };
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
global.setTimeout = (fn, ms) => { timers.push({ fn, ms }); return ++timerSeq; };
global.clearTimeout = () => {};

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
  // The TV writes it with a typographic apostrophe (Time’s up!), like every
  // caption in the app.
  assert.ok(/Time[’']s up!/.test(t.innerHTML), t.innerHTML);
  assert.ok(t.className.indexOf('finished') >= 0, 'missing finished class');
  tickTimerFn();
  assert.ok(/Time[’']s up!/.test(t.innerHTML), 'counted past zero');
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

check('the dyslexia template reaches the body as a theme class', () => {
  // The accessibility templates are the ones that must not silently no-op:
  // a learner who reads in dyslexia mode on their phone should get the same
  // page on the class TV. app.js builds the class from state.theme, so this
  // guards the whole path from /api/state to the CSS block.
  push({ mode: 'flashcards', ttsOnTv: false, theme: 'dyslexia',
         slide: { index: 0, total: 1, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕', catLabel: 'Animals' } });
  const cls = global.document.body.className || '';
  assert.ok(cls.indexOf('theme-dyslexia') >= 0,
    'dyslexia template did not reach the body: ' + cls);
});

const BIG_SLIDE = {
  index: 0, total: 3, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕',
  catLabel: 'Animals', catColor: '#dbeafe', catColorDark: '#1565c0',
  photo: { available: true, url: '/api/image/0/dog' },
};

check('"fullscreen picture" reaches the body as a class', () => {
  push({ mode: 'flashcards', ttsOnTv: false, bigPicture: true, slide: BIG_SLIDE });
  const cls = global.document.body.className || '';
  assert.ok(cls.indexOf('big-picture') >= 0, 'flag did not reach the body: ' + cls);
  // applyTheme is the single owner of body.className, so the danger is not that
  // the class is missing but that adding it wipes a neighbour.
  assert.ok(cls.indexOf('theme-') >= 0, 'theme class was clobbered: ' + cls);
  assert.ok(cls.indexOf('text-') >= 0, 'text size class was clobbered: ' + cls);
  assert.ok(cls.indexOf('lang-') >= 0, 'language class was clobbered: ' + cls);
  // The picture is the whole point of the mode, so check one actually landed
  // on the card face the CSS then blows up to fill the screen.
  assert.ok(
    (els['fcard-photo-back'].style.backgroundImage || '').indexOf('/api/image/0/dog') >= 0,
    'the photo never reached the card face: ' + els['fcard-photo-back'].style.backgroundImage);
});

check('turning it off removes the class again', () => {
  push({ mode: 'flashcards', ttsOnTv: false, bigPicture: false, slide: BIG_SLIDE });
  const cls = global.document.body.className || '';
  assert.ok(cls.indexOf('big-picture') < 0, 'class stuck on: ' + cls);
});

check('a payload that predates the toggle is not big', () => {
  push({ mode: 'flashcards', ttsOnTv: false, slide: BIG_SLIDE });
  const cls = global.document.body.className || '';
  assert.ok(cls.indexOf('big-picture') < 0, 'defaulted on: ' + cls);
});

check('the flashcard markup is unchanged - the effect is purely CSS', () => {
  // If big picture ever starts rewriting the stage instead of restyling it,
  // this is the check that says so - and the next one explains why that matters.
  const plain = push({ mode: 'flashcards', ttsOnTv: false, slide: BIG_SLIDE });
  const bigHtml = push({ mode: 'flashcards', ttsOnTv: false, bigPicture: true, slide: BIG_SLIDE });
  assert.strictEqual(bigHtml, plain, 'big picture rewrote the card markup');
});

check('toggling it mid-clip does not restart the sign video', () => {
  // The reason it is a body class and not a render mode: a teacher hitting the
  // switch while a sign plays must not send the clip back to frame one.
  const SIGN = { index: 0, total: 1, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕' };
  const VID = { available: true, url: '/api/video/0/dog' };
  const before = push({ mode: 'fslVideo', ttsOnTv: false, slide: SIGN, video: VID });
  const after = push({ mode: 'fslVideo', ttsOnTv: false, bigPicture: true, slide: SIGN, video: VID });
  assert.strictEqual(after, before, 'the stage was rebuilt under the playing clip');
  assert.ok(global.document.body.className.indexOf('big-picture') >= 0,
    'the class did not apply on the same-clip poll');
});

check('language filter also silences the other language', () => {
  spoken.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, lang: 'en',
         slide: { index: 5, total: 9, wordEn: 'Dog', wordFil: 'Aso', emoji: '🐕', catLabel: 'Animals' } });
  flushTimers(); // the word is said once the card has landed
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

// ─── Card motion (matches the app's page view) ───────
const CARD = (i, extra) => Object.assign({
  index: i, total: 9, wordEn: 'W' + i, wordFil: 'F' + i, emoji: '🐕', catLabel: 'Animals',
}, extra || {});

check('the first card of a deck grows in without sliding', () => {
  push({ mode: 'idle' });
  const html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(0) });
  assert.ok(/class="slide fc-card fc-in"/.test(html), html.slice(0, 160));
});

check('the next card slides in from the right, the previous from the left', () => {
  let html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(1) });
  assert.ok(html.indexOf('fc-in-next') >= 0, 'next did not slide: ' + html.slice(0, 120));
  html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(0) });
  assert.ok(html.indexOf('fc-in-prev') >= 0, 'previous did not slide back');
  html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(8) });
  assert.ok(html.indexOf('fc-in-prev') >= 0, 'back past the first card is not "previous"');
  html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(0) });
  assert.ok(html.indexOf('fc-in-next') >= 0, 'on past the last card is not "next"');
});

check('a new category starts with the grow-in, not a slide', () => {
  const html = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(1, { catLabel: 'Colors' }) });
  assert.ok(/class="slide fc-card fc-in"/.test(html), html.slice(0, 160));
});

check('reduced motion swaps cards without a slide', () => {
  const html = push({ mode: 'flashcards', ttsOnTv: false, reducedMotion: true,
                      slide: CARD(2, { catLabel: 'Colors' }) });
  assert.ok(html.indexOf('fc-in-next') < 0 && html.indexOf('fc-out-') < 0, html.slice(0, 160));
});

check('a repaint of the same card leaves it alone (no replayed entrance)', () => {
  const before = push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(3) });
  const after = push({ mode: 'flashcards', ttsOnTv: false, theme: 'light', textSize: 'lg',
                       live: { hands: ['Ana'] }, slide: CARD(3) });
  assert.strictEqual(after, before, 'the card was rebuilt for a theme / hands change');
});

// ─── Sound through the TV's own speakers ─────────────
const SAY = [
  { u: '/api/speech/aaa111.wav', t: 'Dog', l: 'en' },
  { u: '/api/speech/bbb222.wav', t: 'Aso', l: 'fil' },
];

check("a word is played from the phone's audio, English then Filipino", () => {
  mediaLog.length = 0;
  spoken.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:4', slide: CARD(4) });
  assert.strictEqual(mediaLog.length, 0, 'spoke before the card had landed');
  flushTimers();
  const audio = els['cast-audio'];
  assert.ok(audio, 'no <audio> element');
  assert.strictEqual(mediaLog.length, 1, 'expected one line playing, got ' + mediaLog.length);
  assert.strictEqual(mediaLog[0].src, '/c/CMRYP/api/speech/aaa111.wav',
    'not scoped to the session code: ' + mediaLog[0].src);
  audio.onended();
  assert.strictEqual(mediaLog[1].src, '/c/CMRYP/api/speech/bbb222.wav');
  assert.strictEqual(spoken.length, 0, 'fell back to the TV voice while the files played');
});

check('the same card polled again is not said twice', () => {
  mediaLog.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:4', slide: CARD(4) });
  flushTimers();
  assert.strictEqual(mediaLog.length, 0, 'repeated the word on a repaint');
});

check('the TV tells the phone it is speaking (the slideshow waits for it)', () => {
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:5', slide: CARD(5) });
  flushTimers();
  pollFn();
  assert.ok(lastUrl.indexOf('spk=1') >= 0, lastUrl);
  els['cast-audio'].onended();
  els['cast-audio'].onended();
  pollFn();
  assert.ok(lastUrl.indexOf('spk=0') >= 0, 'still "speaking" after the last line: ' + lastUrl);
  assert.ok(lastUrl.indexOf('tts=1') >= 0, 'claimed it cannot speak: ' + lastUrl);
});

check('2× reaches the line that is playing', () => {
  mediaLog.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, speed: 2, say: SAY, sayKey: 'f:0:6', slide: CARD(6) });
  flushTimers();
  assert.strictEqual(els['cast-audio'].playbackRate, 2);
  assert.strictEqual(mediaLog[0].rate, 2, 'played at ' + mediaLog[0].rate);
  push({ mode: 'flashcards', ttsOnTv: true, speed: 1, say: SAY, sayKey: 'f:0:6', slide: CARD(6) });
  assert.strictEqual(els['cast-audio'].playbackRate, 1, 'speed did not come back to 1×');
});

check("a line whose file fails is said with the TV's own voice", () => {
  spoken.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:7', slide: CARD(7) });
  flushTimers();
  els['cast-audio'].onerror();
  assert.deepStrictEqual(spoken, ['Dog'], 'no fallback: ' + spoken.join('|'));
});

check('a browser that blocks sound gets "press OK", and OK plays the held line', () => {
  mediaBlocked = true;
  mediaLog.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:8', slide: CARD(8) });
  flushTimers();
  assert.ok(els['sound-hint'].className.indexOf('hidden') < 0, 'no hint while blocked');
  pollFn();
  assert.ok(lastUrl.indexOf('unlocked=0') >= 0, 'reported unlocked while blocked: ' + lastUrl);
  mediaBlocked = false;
  key(13, 'Enter');
  assert.ok(mediaLog.length >= 1, 'OK did not play the held line');
  assert.strictEqual(mediaLog[0].src, '/c/CMRYP/api/speech/aaa111.wav');
  assert.ok(els['sound-hint'].className.indexOf('hidden') >= 0, 'hint stayed after sound started');
});

check('sound routed to the phone: the TV stays silent', () => {
  mediaLog.length = 0;
  spoken.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(1) });
  flushTimers();
  assert.strictEqual(mediaLog.length + spoken.length, 0);
});

// ─── The TV remote ───────────────────────────────────
check('◀ ▶ step the lesson through the phone, and the TV shows it at once', () => {
  flushTimers();
  urls.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, remote: true, slide: CARD(2) });
  key(39, 'ArrowRight');
  assert.ok(urls.some((u) => u.indexOf('/c/CMRYP/api/nudge?a=next') === 0), urls.join(' '));
  assert.ok(urls[urls.length - 1].indexOf('/api/state') >= 0, 'did not poll straight after');
  urls.length = 0;
  key(37, 'ArrowLeft');
  assert.ok(urls.some((u) => u.indexOf('nudge?a=prev') >= 0), urls.join(' '));
});

check('TV-brand media keys (Tizen play/pause, Play, Pause)', () => {
  urls.length = 0;
  key(10252, '');
  key(415, '');
  key(19, '');
  const n = urls.filter((u) => u.indexOf('nudge?a=') >= 0).map((u) => u.split('a=')[1]);
  assert.deepStrictEqual(n, ['playpause', 'play', 'pause'], n.join(','));
});

check('OK flips a card that has a photo; ▼ asks for "Show Me"', () => {
  urls.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(3, {
    photo: { available: true, url: '/api/image/0/dog' },
    clip: { available: true, url: '/api/clip/0/dog', isGif: true },
  }) });
  key(13, 'Enter');
  key(40, 'ArrowDown');
  const n = urls.filter((u) => u.indexOf('nudge?a=') >= 0).map((u) => u.split('a=')[1]);
  assert.deepStrictEqual(n, ['flip', 'showme'], n.join(','));
});

check('▲ says the word again on the TV itself', () => {
  mediaLog.length = 0;
  push({ mode: 'flashcards', ttsOnTv: true, say: SAY, sayKey: 'f:0:3', slide: CARD(3) });
  flushTimers();
  const n = mediaLog.length;
  urls.length = 0;
  key(38, 'ArrowUp');
  assert.ok(mediaLog.length > n, 'nothing replayed');
  assert.ok(!urls.some((u) => u.indexOf('nudge') >= 0), 'asked the phone for a local replay');
});

check('Back closes an open clip first', () => {
  urls.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, showMe: true,
         slide: CARD(3, { clip: { available: true, url: '/api/clip/0/dog', isGif: true } }) });
  key(10009, '');
  assert.ok(urls.some((u) => u.indexOf('nudge?a=back') >= 0), urls.join(' '));
});

check('Back with nothing open asks for a second press, which leaves', () => {
  flushTimers();
  historyLog.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, slide: CARD(5) });
  key(461, '');
  assert.ok(els['remote-toast'].innerHTML.indexOf('Back again') >= 0, els['remote-toast'].innerHTML);
  assert.ok(!historyLog.some((h) => h === 'back' || h.indexOf('go') === 0), 'left on the first press');
  key(461, '');
  assert.ok(historyLog.some((h) => /^go -\d+$/.test(h)), historyLog.join(','));
});

check('the Back guards are only ever added inside a key press', () => {
  // Chrome steps over history entries a page adds without one, so the
  // popstate handler must never put a guard back itself.
  historyLog.length = 0;
  (listeners.popstate || []).forEach((fn) => fn({}));
  assert.ok(!historyLog.some((h) => h === 'push'), 'pushed a guard from Back: ' + historyLog.join(','));
  key(37, 'ArrowLeft');
  assert.ok(historyLog.some((h) => h === 'push'), 'a key press did not top the guards up');
});

check('Info shows the keys for the mode on screen, and closes again', () => {
  flushTimers();
  push({ mode: 'story', ttsOnTv: false, story: STORY });
  flushTimers();
  key(457, '');
  const help = els['remote-help'];
  assert.ok(help.className.indexOf('hidden') < 0, 'Info did not open the key list');
  assert.ok(help.innerHTML.indexOf('Previous / next page') >= 0, help.innerHTML);
  key(457, '');
  assert.ok(help.className.indexOf('hidden') >= 0, 'Info did not close it');
});

check('with the remote switched off a key says so instead of moving', () => {
  flushTimers();
  urls.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, remote: false, slide: CARD(4) });
  key(39, 'ArrowRight');
  assert.ok(!urls.some((u) => u.indexOf('nudge') >= 0), 'nudged with the remote off');
  assert.ok(els['remote-toast'].innerHTML.indexOf('turned off') >= 0, els['remote-toast'].innerHTML);
});

check('◀ ▶ on a live question show the keys instead of a step that cannot happen', () => {
  flushTimers();
  urls.length = 0;
  push({ mode: 'live', ttsOnTv: false, live: { activity: FSL_Q, responded: 0 } });
  key(39, 'ArrowRight');
  key(179, 'MediaPlayPause');
  assert.ok(!urls.some((u) => u.indexOf('nudge') >= 0), urls.join(' '));
  assert.ok(els['remote-help'].className.indexOf('hidden') < 0, 'no key list shown');
});

check('while the teacher is away, the remote cannot move the lesson', () => {
  flushTimers();
  urls.length = 0;
  push({ mode: 'flashcards', ttsOnTv: false, away: true,
         slide: CARD(3, { photo: { available: true, url: '/api/image/0/dog' } }) });
  ['right', 'left', 'ok', 'down', 'up'].forEach((k) => key({ right: 39, left: 37, ok: 13, down: 40, up: 38 }[k], ''));
  assert.ok(!urls.some((u) => u.indexOf('nudge') >= 0), 'moved the lesson while away: ' + urls.join(' '));
  assert.ok(els['remote-help'].innerHTML.indexOf('Flip') < 0, 'offered lesson keys while away');
});

// ─── Who the cast is for ─────────────────────────────
const SUMMARY = {
  learners: 1, words: 3, stars: 16, activeToday: 1, bestStreak: 1,
  rows: [{ rank: 0, name: 'Ana', words: 3, streak: 1, stars: 16 }],
};

check('the progress board says which classes it is for', () => {
  const html = push({ mode: 'progress', progressView: 'classWins',
                      audience: 'Hearing Class · Cognitive Class', classSummary: SUMMARY });
  assert.ok(html.indexOf('For: Hearing Class · Cognitive Class') >= 0, html.slice(0, 300));
});

check('…but not when it would only repeat the title', () => {
  const html = push({ mode: 'progress', progressView: 'classWins', title: 'Hearing Class',
                      audience: 'Hearing Class', classSummary: SUMMARY });
  assert.ok(html.indexOf('board-for') < 0, html.slice(0, 300));
});

check('a class name is escaped, never markup', () => {
  const html = push({ mode: 'progress', progressView: 'leaderboard',
                      audience: '<b>x</b>', progress: [], classSummary: SUMMARY });
  assert.ok(html.indexOf('<b>x</b>') < 0 && html.indexOf('&lt;b&gt;') >= 0, html.slice(0, 300));
});

let failed = 0;
for (const [status, name] of results) {
  if (status === 'FAIL') failed++;
  console.log(status + '  ' + name);
}
console.log('\n' + (results.length - failed) + '/' + results.length + ' passed');
process.exit(failed ? 1 : 0);
