// FlashLearn PWD — website admin dashboard.
//
// Reads the WEBSITE's own Firebase project (config.js): the daily visit
// tallies, FSL sign plays, ratings and messages that website/assets/site.js
// sends, plus GitHub's download counts. It cannot reach the app's learner
// data, which lives in another project. Who may read is decided by
// ../firestore.rules (a Google or email sign-in listed in admins/): this page
// only shows what those rules hand back.
//
// Local testing: http://127.0.0.1:<port>/?emulator uses the Auth and
// Firestore emulators of the demo-flashlearn-site project instead.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js';
import {
  getAuth, connectAuthEmulator, onAuthStateChanged, signInWithPopup, GoogleAuthProvider,
  signInWithEmailAndPassword, signOut, setPersistence, browserSessionPersistence, browserLocalPersistence,
} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js';
import {
  getFirestore, connectFirestoreEmulator, collection, query, where, orderBy, limit, getDocs, getDoc,
  doc, setDoc, updateDoc, deleteDoc, documentId, serverTimestamp, writeBatch, Timestamp,
} from 'https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore-lite.js';
import { FIREBASE, SITE } from './config.js';

const $ = (id) => document.getElementById(id);
const LOCAL = /^(localhost|127\.0\.0\.1)$/.test(location.hostname);
const EMULATOR = LOCAL && new URLSearchParams(location.search).has('emulator');
const CONFIG = EMULATOR
  ? { apiKey: 'demo-key', authDomain: location.host, projectId: 'demo-flashlearn-site', appId: 'demo' }
  : FIREBASE;
const IDLE_MS = 30 * 60e3;
const FEEDBACK_LIMIT = 500;
const KEEP_MONTHS = 12;   // ratings and messages; privacy page section 8

// ---- Names for the tallies (website/assets/site.js, firestore.rules) ----------
const PAGES = {
  index: 'Home', try: 'Try It', download: 'Download', how_to_use: 'How to Use', games: 'Learning Games',
  fsl_dictionary: 'FSL Dictionary', teachers_guide: 'Teacher’s Guide', faq: 'FAQ and feedback',
  awareness: 'PWD Awareness', about: 'About', privacy: 'Privacy', gaze_control: 'Gaze Control', other: 'Other pages',
};
const SOURCES = {
  direct: 'Typed in, bookmark or app link', search: 'Search engines', social: 'Social media and chat apps',
  github: 'GitHub', qr: 'QR code (link with ?src=qr)', other: 'Other websites',
};
const DEVICES = { phone: 'Phone', tablet: 'Tablet', computer: 'Computer' };
const LANGS = { en: 'English', fil: 'Filipino' };
const AIDS = [
  ['a_text', 'Larger text (A+ or A++)'], ['a_dys', 'Dyslexia-friendly font'], ['a_hc', 'High contrast'],
  ['a_still', 'Reduce motion (site switch)'], ['o_motion', 'Device setting: reduce motion'],
  ['o_dark', 'Device setting: dark mode'], ['o_contrast', 'Device setting: more contrast'],
];
const EVENTS = [
  ['e_apk_arm64', 'Download pressed: 64-bit APK'], ['e_apk_arm32', 'Download pressed: 32-bit APK'],
  ['e_apk_universal', 'Download pressed: universal APK'], ['e_webapp', 'Opened the web app'],
  ['e_try_card', 'Try It: flipped a flashcard'], ['e_try_game', 'Try It: Word Match games'],
  ['e_film', 'Played the Home film'], ['e_demo', 'Played a how-to or welcome video'],
];
const TYPES = { problem: 'Problem', idea: 'Suggestion', praise: 'Praise', rating: 'Rating only' };
const ROLES = { teacher: 'Teacher', parent: 'Parent or guardian', student: 'Student', other: 'Other' };
// Every tally, in the order of the daily CSV.
const CSV_KEYS = [
  ['u', 'visitors'], ['n', 'new_visitors'], ['v', 'page_views'],
  ...Object.keys(PAGES).map((k) => ['p_' + k, 'views_' + k]),
  ['l_en', 'views_english'], ['l_fil', 'views_filipino'],
  ...Object.keys(DEVICES).map((k) => ['d_' + k, 'visitors_' + k]),
  ...Object.keys(SOURCES).map((k) => ['s_' + k, 'arrived_' + k]),
  ...AIDS.map(([k]) => [k, k.replace(/^a_/, 'aid_').replace(/^o_/, 'device_')]),
  ...EVENTS.map(([k]) => [k, k.slice(2)]),
];

// ---- Small helpers --------------------------------------------------------------
const NUM = new Intl.NumberFormat('en-US');
const fmt = (n) => NUM.format(Math.round(n || 0));
const pct = (part, whole) => (whole ? Math.round((part / whole) * 100) + '%' : '–');
const compact = (n) => (n >= 1e6 ? +(n / 1e6).toFixed(1) + 'M' : n >= 1e3 ? +(n / 1e3).toFixed(n >= 1e4 ? 0 : 1) + 'K' : String(n));
const DAY = 864e5;
const manilaDay = (t = Date.now()) => new Date(t + 8 * 36e5).toISOString().slice(0, 10);
const addDays = (day, n) => new Date(Date.parse(day + 'T00:00:00Z') + n * DAY).toISOString().slice(0, 10);
const dayLabel = (day, year) => new Date(day + 'T00:00:00Z').toLocaleDateString('en-US',
  { month: 'short', day: 'numeric', timeZone: 'UTC', ...(year ? { year: 'numeric' } : {}) });
const whenLabel = (date) => date.toLocaleString('en-PH',
  { timeZone: 'Asia/Manila', year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
const starsText = (r) => '★'.repeat(r) + '☆'.repeat(5 - r);

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text != null) e.textContent = text;
  return e;
}
function srOnly(text) { return el('span', 'sr-only', text); }
const SVGNS = 'http://www.w3.org/2000/svg';
function svg(tag, attrs, parent) {
  const e = document.createElementNS(SVGNS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function say(node, text, kind) {
  node.textContent = text;
  node.classList.toggle('bad', kind === 'bad');
  node.classList.toggle('ok', kind === 'ok');
}
function stored(k, v) {
  try {
    if (v === undefined) return localStorage.getItem(k);
    localStorage.setItem(k, v);
  } catch (e) { return null; }
  return v;
}

// One shared tooltip; it only repeats what a label or table already shows.
const tip = $('tip');
function showTip(content, x, y) {
  tip.textContent = '';
  tip.appendChild(content);
  tip.hidden = false;
  moveTip(x, y);
}
function moveTip(x, y) {
  const w = tip.offsetWidth, h = tip.offsetHeight;
  tip.style.left = Math.max(8, Math.min(x + 14, innerWidth - w - 8)) + 'px';
  tip.style.top = (y + 14 + h > innerHeight - 8 ? Math.max(8, y - h - 14) : y + 14) + 'px';
}
function hideTip() { tip.hidden = true; }

// ---- Theme ----------------------------------------------------------------------
(function theme() {
  const btn = $('btnTheme'), root = document.documentElement;
  const dark = () => root.getAttribute('data-theme') === 'dark' ||
    (!root.hasAttribute('data-theme') && matchMedia('(prefers-color-scheme: dark)').matches);
  const sync = () => btn.setAttribute('aria-pressed', String(dark()));
  btn.addEventListener('click', () => {
    const next = dark() ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    stored('flp-admin-theme', next);
    sync();
  });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', sync);
  sync();
})();
// ---- Views ------------------------------------------------------------------------
// Loading, set-up, sign-in and not-an-administrator fill the page; the
// dashboard brings the sidebar.
const VIEWS = ['viewLoading', 'viewSetup', 'viewSignIn', 'viewDenied', 'viewDash'];
function show(view) {
  VIEWS.forEach((v) => { $(v).hidden = v !== view; });
  $('side').hidden = view !== 'viewDash';
  $('app').classList.toggle('with-side', view === 'viewDash');
}

// The dashboard's sections, one at a time, named in the address (#audience),
// so Back and bookmarks work.
const SECTIONS = { overview: 'Overview', audience: 'Audience', downloads: 'Downloads', feedback: 'Feedback', tools: 'Tools' };
function route(focus) {
  const name = SECTIONS[location.hash.slice(1)] ? location.hash.slice(1) : 'overview';
  document.querySelectorAll('.view').forEach((v) => { v.hidden = v.dataset.view !== name; });
  document.querySelectorAll('.side-nav a').forEach((a) => {
    if (a.dataset.view !== name) return a.removeAttribute('aria-current');
    a.setAttribute('aria-current', 'page');
    a.scrollIntoView({ block: 'nearest', inline: 'nearest' });   // the phone's tab strip
  });
  $('pageTitle').textContent = SECTIONS[name];
  document.title = SECTIONS[name] + ' · FlashLearn PWD Admin';
  hideTip();
  if (focus) $('pageTitle').focus();   // a screen reader announces the new section
}
addEventListener('hashchange', () => route(true));

let auth, db;   // set by start(), at the end of this file

// ---- Signing in -------------------------------------------------------------------
const stay = $('chkStay');
function wireSignIn() {
  stay.checked = stored('flp-admin-stay') === '1';
  // Set ahead of the click: a sign-in window must open straight from the press.
  const applyStay = () => {
    stored('flp-admin-stay', stay.checked ? '1' : '0');
    return setPersistence(auth, stay.checked ? browserLocalPersistence : browserSessionPersistence).catch(() => {});
  };
  stay.addEventListener('change', applyStay);
  applyStay();
  const msg = $('signInMsg');
  try {
    if (sessionStorage.getItem('flp-admin-idle')) {
      sessionStorage.removeItem('flp-admin-idle');
      say(msg, 'You were signed out after 30 minutes without using the page.');
    }
  } catch (e) {}
  $('btnGoogle').addEventListener('click', () => {
    say(msg, '');
    signInWithPopup(auth, new GoogleAuthProvider()).catch((e) => say(msg, authError(e), 'bad'));
  });
  $('formEmail').addEventListener('submit', (e) => {
    e.preventDefault();
    say(msg, 'Signing in…');
    signInWithEmailAndPassword(auth, $('inEmail').value.trim(), $('inPassword').value)
      .then(() => { $('inPassword').value = ''; say(msg, ''); })
      .catch((err) => say(msg, authError(err), 'bad'));
  });
  // Signing out reloads the page, so no statistics stay behind in it.
  const out = () => signOut(auth).then(() => location.reload());
  $('btnSignOut').addEventListener('click', out);
  $('btnDeniedOut').addEventListener('click', out);
  $('btnCopyUid').addEventListener('click', () => {
    const done = (ok) => say($('deniedMsg'), ok ? 'Copied.' : 'Select the ID and copy it.', ok ? 'ok' : 'bad');
    navigator.clipboard.writeText($('deniedUid').textContent).then(() => done(true), () => done(false));
  });
}

function authError(e) {
  const code = (e && e.code) || '';
  if (code === 'auth/popup-closed-by-user' || code === 'auth/cancelled-popup-request') return 'The sign-in window was closed before signing in.';
  if (code === 'auth/popup-blocked') return 'The browser blocked the sign-in window. Allow pop-ups for this page, then try again.';
  if (code === 'auth/operation-not-allowed') return 'This way of signing in is not turned on in the website’s Firebase project (Authentication → Sign-in method).';
  if (code === 'auth/unauthorized-domain') return 'This address is not an authorized domain of the website’s Firebase project (Authentication → Settings).';
  if (/auth\/(invalid-credential|wrong-password|user-not-found|invalid-email|invalid-login-credentials)/.test(code)) return 'That email and password do not match an account.';
  if (code === 'auth/user-disabled') return 'This account has been turned off.';
  if (code === 'auth/too-many-requests') return 'Too many tries. Wait a few minutes, then try again.';
  if (code === 'auth/network-request-failed') return 'No connection to Firebase. Check the internet, then try again.';
  return 'Signing in did not work' + (code ? ' (' + code + ')' : '') + '.';
}

let idleTimer = 0, idleWired = false;
function watchIdle() {
  clearTimeout(idleTimer);
  if (stay.checked) return;
  const reset = () => {
    clearTimeout(idleTimer);
    if (!auth.currentUser || stay.checked) return;
    idleTimer = setTimeout(() => {
      signOut(auth).then(() => {
        try { sessionStorage.setItem('flp-admin-idle', '1'); } catch (e) {}
        location.reload();
      });
    }, IDLE_MS);
  };
  if (!idleWired) {
    idleWired = true;
    ['pointerdown', 'keydown', 'wheel', 'touchstart'].forEach((t) => addEventListener(t, reset, { passive: true }));
  }
  reset();
}

let dashReady = false;
async function onUser(user) {
  clearTimeout(idleTimer);
  hideTip();
  if (!user) {
    $('who').hidden = true;
    show('viewSignIn');
    return;
  }
  $('who').hidden = false;
  $('whoEmail').textContent = user.email || 'Signed in';
  let admin;
  try {
    admin = (await getDoc(doc(db, 'admins', user.uid))).exists();
  } catch (e) {
    // Offline, or Firebase unreachable: say so instead of "not an administrator".
    if (auth.currentUser !== user) return;
    $('loadingMsg').textContent = 'The list of administrators could not be checked (' + (e.code || e.message) +
      '). Check the internet connection, then reload the page.';
    show('viewLoading');
    return;
  }
  if (auth.currentUser !== user) return;
  if (!admin) {
    $('deniedEmail').textContent = user.email || '(an account without an email address)';
    $('deniedUid').textContent = user.uid;
    say($('deniedMsg'), '');
    show('viewDenied');
    return;
  }
  $('aboutAdmin').textContent = 'Signed in as ' + (user.email || user.uid) +
    '. Administrators are the documents in Firestore → admins, edited only in the Firebase console.';
  show('viewDash');
  route(false);
  watchIdle();
  if (!dashReady) initDash();
  load();
}

// ---- Loading ------------------------------------------------------------------------
const state = { range: '30', daily: [], signs: [], snaps: [], feedback: [], gh: null, site: null };
let period = null, loadSeq = 0;

function makePeriod(range, earliest) {
  const to = manilaDay();
  let from, prevFrom = null, prevTo = null, n = null;
  if (range === 'all') {
    from = earliest && earliest < to ? earliest : to;
  } else {
    n = +range;
    from = addDays(to, -(n - 1));
    prevFrom = addDays(from, -n);
    prevTo = addDays(from, -1);
  }
  const days = [];
  for (let d = from; d <= to; d = addDays(d, 1)) days.push(d);
  const label = from === to ? dayLabel(to, true) : dayLabel(from, from.slice(0, 4) !== to.slice(0, 4)) + ' – ' + dayLabel(to, true);
  const prevName = n === 365 ? 'the 12 months before' : n ? 'the ' + n + ' days before' : null;
  return { range, from, to, days, prevFrom, prevTo, n, label, prevName };
}

async function load() {
  const seq = ++loadSeq;
  const dash = $('dash');
  dash.classList.add('loading');
  $('dashError').hidden = true;
  const r = state.range, today = manilaDay();
  const since = (days) => (r === 'all' ? null : addDays(today, -(days - 1)));
  const docs = (name, from) => getDocs(from ? query(collection(db, name), where(documentId(), '>=', from)) : collection(db, name))
    .then((s) => s.docs.map((d) => ({ id: d.id, ...d.data() })));
  const expired = deleteExpired().catch(() => 0);
  const github = loadGitHub().then(() => {
    if (seq !== loadSeq) return;
    renderDownloads();
    renderHealth();
    if (period) renderKpis();
  });
  const firestore = Promise.all([
    docs('daily', since(2 * +r)),            // this period and the one before, for the change
    docs('signs', since(+r)),
    docs('downloads', since(+r + 1)),        // and the day before, for the change in downloads
    getDocs(query(collection(db, 'feedback'), orderBy('created', 'desc'), limit(FEEDBACK_LIMIT)))
      .then((s) => s.docs.map((d) => {
        const f = { id: d.id, ...d.data() };
        f.created = f.created && f.created.toDate ? f.created.toDate() : null;
        return f;
      }).filter((f) => f.created && f.created >= keepSince())),
  ]).then(([daily, signs, snaps, feedback]) => {
    if (seq !== loadSeq) return;
    Object.assign(state, { daily, signs, snaps, feedback });
    const earliest = daily.reduce((m, x) => (!m || x.id < m ? x.id : m), null);
    period = makePeriod(r, earliest);
    renderAll();
    $('updatedAt').textContent = 'Updated ' + new Date().toLocaleTimeString('en-PH',
      { timeZone: 'Asia/Manila', hour: 'numeric', minute: '2-digit' });
  });
  try {
    await firestore;
  } catch (e) {
    if (seq === loadSeq) {
      const denied = e && e.code === 'permission-denied';
      $('dashError').textContent = denied
        ? 'The database refused to show the statistics. Is this account still on the list of administrators?'
        : 'The statistics could not be loaded (' + ((e && (e.code || e.message)) || 'unknown error') + '). Check the connection, then press Refresh.';
      $('dashError').hidden = false;
    }
  } finally {
    if (seq === loadSeq) dash.classList.remove('loading');
  }
  await github;
  if (seq === loadSeq) saveSnapshot();
  const removed = await expired;
  if (removed && seq === loadSeq) {
    $('expiredNote').textContent = fmt(removed) + (removed === 1 ? ' rating or message' : ' ratings and messages') +
      ' older than ' + KEEP_MONTHS + ' months ' + (removed === 1 ? 'was' : 'were') + ' deleted just now.';
  }
}

// GitHub's public API: 60 calls an hour per network, so answers are kept for
// ten minutes in this tab.
async function loadGitHub(force) {
  const KEY = 'flp-admin-github';
  let cached = null;
  try { cached = JSON.parse(sessionStorage.getItem(KEY) || 'null'); } catch (e) {}
  if (!force && cached && Date.now() - cached.at < 10 * 60e3) {
    state.gh = cached.gh;
    state.site = cached.site;
    return;
  }
  const api = (path) => fetch('https://api.github.com/repos/' + SITE.repo + path,
    { headers: { Accept: 'application/vnd.github+json' }, credentials: 'omit', referrerPolicy: 'no-referrer' })
    .then((res) => {
      if (res.status === 403 || res.status === 429) throw new Error('GitHub’s hourly limit for this network was reached. The numbers come back within the hour.');
      if (!res.ok) throw new Error('GitHub answered ' + res.status + '.');
      return res.json();
    });
  try {
    const [list, latest] = await Promise.all([api('/releases?per_page=100'), api('/releases/latest')]);
    const releases = list.filter((x) => !x.draft).map((x) => {
      const apks = x.assets.filter((a) => /\.apk$/i.test(a.name));
      const variants = {};
      apks.forEach((a) => {
        const m = /-(arm64|arm32|universal)\.apk$/i.exec(a.name);
        const k = m ? m[1].toLowerCase() : 'other';
        variants[k] = (variants[k] || 0) + a.download_count;
      });
      return {
        tag: x.tag_name, date: x.published_at, variants,
        total: apks.reduce((s, a) => s + a.download_count, 0),
        apks: apks.map((a) => ({ name: a.name, ok: a.state === 'uploaded' })),
      };
    });
    state.gh = { ok: true, releases, total: releases.reduce((s, x) => s + x.total, 0), latest: latest.tag_name, latestDate: latest.published_at };
  } catch (e) {
    state.gh = { ok: false, error: e.message || 'GitHub could not be reached.' };
  }
  try {
    const res = await fetch(SITE.url + 'version.json', { cache: 'no-store', credentials: 'omit', referrerPolicy: 'no-referrer' });
    state.site = res.ok ? await res.json() : null;
  } catch (e) { state.site = null; }
  if (state.gh.ok) {
    try { sessionStorage.setItem(KEY, JSON.stringify({ at: Date.now(), gh: state.gh, site: state.site })); } catch (e) {}
  }
}

// Ratings and messages are kept for KEEP_MONTHS (privacy page, section 8). With
// no server code on the free plan, the dashboard deletes older ones each time
// an administrator opens it; the list never shows them either way.
function keepSince() {
  const d = new Date();
  d.setMonth(d.getMonth() - KEEP_MONTHS);
  return d;
}
async function deleteExpired() {
  const before = Timestamp.fromDate(keepSince());
  let removed = 0;
  // 20 per batch: a batched write may make at most 20 rule lookups (the
  // administrator check), however Firestore counts repeats.
  for (let round = 0; round < 50; round++) {
    const old = await getDocs(query(collection(db, 'feedback'), where('created', '<', before), limit(20)));
    if (old.empty) break;
    const batch = writeBatch(db);
    old.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += old.size;
  }
  return removed;
}

// GitHub keeps only running totals; one saved total a day draws them over time.
async function saveSnapshot() {
  const gh = state.gh;
  if (!gh || !gh.ok || !period) return;
  const today = manilaDay();
  const have = state.snaps.find((s) => s.id === today);
  if (have && have.total === gh.total) return;
  const releases = {};
  gh.releases.forEach((x) => { releases[x.tag] = { ...x.variants }; });
  try {
    await setDoc(doc(db, 'downloads', today), { total: gh.total, releases, at: serverTimestamp() });
    state.snaps = state.snaps.filter((s) => s.id !== today).concat({ id: today, total: gh.total, releases });
    renderDownloadTrend();
    renderKpis();
  } catch (e) { /* tried again the next time the page loads */ }
}

// ---- Sums ----------------------------------------------------------------------------
function totals(rows, from, to) {
  const t = {};
  rows.forEach((r) => {
    if (r.id < from || r.id > to) return;
    for (const k in r) if (typeof r[k] === 'number') t[k] = (t[k] || 0) + r[k];
  });
  return t;
}
function perDay(rows, days, key) {
  const byId = new Map(rows.map((r) => [r.id, r]));
  return days.map((d) => (byId.get(d) || {})[key] || 0);
}
// Long periods are drawn per week (weeks start on Monday).
function buckets(days) {
  if (days.length <= 120) return days.map((d) => ({ label: d, days: [d] }));
  const out = [];
  days.forEach((d) => {
    if (!out.length || new Date(d + 'T00:00:00Z').getUTCDay() === 1) out.push({ label: d, days: [] });
    out[out.length - 1].days.push(d);
  });
  return out;
}
const inPeriod = (date) => date && manilaDay(date.getTime()) >= period.from;

// ---- Rendering -----------------------------------------------------------------------
function renderAll() {
  $('periodNote').textContent = period.label;
  renderKpis();
  renderVisits();
  renderOverview();
  renderBreakdowns();
  renderRatings();
  renderInbox();
  renderDownloads();
  renderHealth();
  renderDownloadTrend();
}

function change(cur, prev) {
  if (prev == null) return null;
  cur = cur || 0;
  if (!prev) return cur ? { text: '▲ from 0 in ' + period.prevName, cls: 'up' } : { text: 'None in ' + period.prevName + ' either', cls: '' };
  const d = Math.round(((cur - prev) / prev) * 100);
  if (!d) return { text: '= the same as ' + period.prevName, cls: '' };
  return { text: (d > 0 ? '▲ ' : '▼ ') + Math.abs(d) + '% from ' + period.prevName, cls: d > 0 ? 'up' : 'down' };
}

const ICONS = {
  visitors: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8"/><path d="M18 14.3a6.5 6.5 0 0 1 3.5 5.7"/>',
  views: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  downloads: '<path d="M12 3.5v11.5"/><path d="M7 10.5l5 5 5-5"/><path d="M4 20h16"/>',
  rating: '<path d="M12 3.2l2.7 5.5 6 .9-4.35 4.25 1.03 6L12 17.02l-5.38 2.83 1.03-6L3.3 9.6l6-.9z"/>',
  messages: '<path d="M4 4.5h16v11.5H9.5L4 20.5z"/><path d="M8 9h8M8 12.5h5"/>',
};
function icon(name) {
  const s = svg('svg', { viewBox: '0 0 24 24', 'aria-hidden': 'true', focusable: 'false' });
  s.innerHTML = ICONS[name];   // the fixed shapes above
  return s;
}

function tile(label, value, sub, spark, iconName) {
  const t = el('article', 'tile');
  const top = el('div', 'tile-top'), ico = el('span', 'tile-ico');
  ico.appendChild(icon(iconName));
  top.append(ico, el('h2', 'tile-label', label));
  t.append(top, el('p', 'tile-value', value));
  if (sub) t.appendChild(el('p', 'tile-sub' + (sub.cls ? ' ' + sub.cls : ''), sub.text));
  if (spark && spark.length > 1 && spark.some((v) => v)) {
    const W = 200, H = 34, max = Math.max(...spark, 1);
    const s = svg('svg', { class: 'spark', viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: 'none', 'aria-hidden': 'true' });
    const X = (i) => 3 + (i * (W - 6)) / (spark.length - 1), Y = (v) => H - 4 - (v / max) * (H - 8);
    svg('path', { d: spark.map((v, i) => (i ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(v).toFixed(1)).join(' '), 'vector-effect': 'non-scaling-stroke' }, s);
    t.appendChild(s);
  }
  return t;
}

function renderKpis() {
  if (!period) return;
  const p = period;
  const cur = totals(state.daily, p.from, p.to);
  const prev = p.prevFrom ? totals(state.daily, p.prevFrom, p.prevTo) : null;
  const host = $('kpis');
  host.textContent = '';
  host.append(
    tile('Visitors', fmt(cur.u), change(cur.u, prev && (prev.u || 0)), perDay(state.daily, p.days, 'u'), 'visitors'),
    tile('Page views', fmt(cur.v), change(cur.v, prev && (prev.v || 0)), perDay(state.daily, p.days, 'v'), 'views'),
  );
  // Downloads: GitHub's all-time total; the change from the saved totals, or
  // else the website's own Download presses.
  const gh = state.gh;
  let sub;
  const before = state.snaps.filter((s) => s.id < p.from).sort((a, b) => (a.id < b.id ? 1 : -1))[0];
  const last = state.snaps.filter((s) => s.id >= p.from).sort((a, b) => (a.id < b.id ? 1 : -1))[0];
  const presses = (cur.e_apk_arm64 || 0) + (cur.e_apk_arm32 || 0) + (cur.e_apk_universal || 0);
  if (before && last) sub = { text: 'All time · +' + fmt(last.total - before.total) + ' in this period', cls: last.total > before.total ? 'up' : '' };
  else sub = { text: 'All time · ' + fmt(presses) + (presses === 1 ? ' press' : ' presses') + ' of Download on the site in this period', cls: '' };
  host.appendChild(tile('Downloads', gh && gh.ok ? fmt(gh.total) : gh ? '–' : '…', gh && !gh.ok ? { text: 'GitHub could not be read', cls: 'down' } : sub, null, 'downloads'));
  const rated = state.feedback.filter((f) => f.rating && inPeriod(f.created));
  const avg = rated.length ? rated.reduce((s, f) => s + f.rating, 0) / rated.length : 0;
  host.appendChild(tile('Average rating', rated.length ? avg.toFixed(1) + ' ★' : '–',
    { text: rated.length ? 'from ' + fmt(rated.length) + (rated.length === 1 ? ' rating' : ' ratings') : 'No ratings in this period', cls: '' },
    null, 'rating'));
  const words = state.feedback.filter((f) => f.message && inPeriod(f.created)).length;
  const unseen = state.feedback.filter((f) => f.status === 'new').length;
  host.appendChild(tile('Messages', fmt(words), { text: fmt(unseen) + ' not yet seen (all dates)', cls: unseen ? 'up' : '' }, null, 'messages'));
  // The sidebar's Feedback item shows how many are waiting.
  $('navUnseen').replaceChildren(document.createTextNode(String(unseen)), srOnly(' not yet seen'));
  $('navUnseen').hidden = !unseen;
}

function renderVisits() {
  const p = period, b = buckets(p.days), weekly = b.length !== p.days.length;
  const byId = new Map(state.daily.map((r) => [r.id, r]));
  const sum = (x, key) => x.days.reduce((s, d) => s + ((byId.get(d) || {})[key] || 0), 0);
  $('visitsNote').textContent = weekly ? 'per week (weeks start on Monday)' : 'per day';
  lineChart($('chartVisits'), {
    labels: b.map((x) => x.label), weekly,
    name: weekly ? 'Visitors and page views per week' : 'Visitors and page views per day',
    series: [
      { name: 'Visitors', cls: 's1', values: b.map((x) => sum(x, 'u')) },
      { name: 'Page views', cls: 's2', values: b.map((x) => sum(x, 'v')) },
    ],
  });
  table($('tableVisits'), [weekly ? 'Week of' : 'Day', 'Visitors', 'New visitors', 'Page views'],
    b.map((x) => [dayLabel(x.label, true), sum(x, 'u'), sum(x, 'n'), sum(x, 'v')]).reverse(), 'Visitors and page views, table');
}

function renderOverview() {
  const t = totals(state.daily, period.from, period.to);
  bars($('barsTopPages'), Object.keys(PAGES).map((k) => ({ label: PAGES[k], value: t['p_' + k] || 0 }))
    .sort((a, b) => b.value - a.value).slice(0, 5), { total: t.v || 0 });
  const ul = $('latestFeedback');
  ul.textContent = '';
  const latest = state.feedback.slice(0, 3);
  if (!latest.length) ul.appendChild(el('li', 'empty', 'No ratings or messages yet.'));
  latest.forEach((f) => {
    const li = el('li'), head = el('div', 'mini-head');
    if (f.status === 'new') head.appendChild(el('span', 'tag new', 'New'));
    if (f.rating) {
      const s = el('span', 'stars-text', starsText(f.rating));
      s.setAttribute('aria-hidden', 'true');
      head.append(s, srOnly('Rated ' + f.rating + ' out of 5'));
    }
    head.append(el('span', null, TYPES[f.type] || f.type), el('span', null, ROLES[f.role] || f.role));
    if (f.created) head.appendChild(el('span', null, whenLabel(f.created)));
    li.append(head, el('p', 'mini-text', f.message || 'A rating, with no message.'));
    ul.appendChild(li);
  });
}

function renderBreakdowns() {
  const p = period, t = totals(state.daily, p.from, p.to);
  const views = t.v || 0, visitors = t.u || 0;
  const byValue = (a, b) => b.value - a.value;
  bars($('barsPages'), Object.keys(PAGES).map((k) => ({ label: PAGES[k], value: t['p_' + k] || 0 })).sort(byValue), { total: views });
  const arrivals = Object.keys(SOURCES).reduce((s, k) => s + (t['s_' + k] || 0), 0);
  bars($('barsSources'), Object.keys(SOURCES).map((k) => ({ label: SOURCES[k], value: t['s_' + k] || 0 })).sort(byValue), { total: arrivals });
  bars($('barsDevices'), Object.keys(DEVICES).map((k) => ({ label: DEVICES[k], value: t['d_' + k] || 0, keep: true })), { total: visitors });
  bars($('barsLangs'), Object.keys(LANGS).map((k) => ({ label: LANGS[k], value: t['l_' + k] || 0, keep: true })), { total: views });
  bars($('barsAids'), AIDS.map(([k, label]) => ({ label, value: t[k] || 0, keep: true })), { total: visitors,
    tipNote: 'of ' + fmt(visitors) + ' visitors' });
  bars($('barsEvents'), EVENTS.map(([k, label]) => ({ label, value: t[k] || 0, keep: true })), { share: false });
  const signs = totals(state.signs, p.from, p.to);
  const words = Object.keys(signs).filter((k) => k.startsWith('w_'));
  const plays = words.reduce((s, k) => s + signs[k], 0);
  $('signsNote').textContent = plays ? fmt(plays) + ' plays of ' + fmt(words.length) + ' different signs' : 'Dictionary and Try It';
  bars($('barsSigns'), words.map((k) => ({ label: signName(k), value: signs[k] })).sort(byValue).slice(0, 10),
    { total: plays, empty: 'No sign videos played in this period yet.' });
}
function signName(k) {
  const s = k.slice(2).replace(/_/g, ' ');
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function renderRatings() {
  const p = period;
  const rated = state.feedback.filter((f) => f.rating && inPeriod(f.created));
  const all = state.feedback.filter((f) => f.rating);
  const avg = (list) => list.reduce((s, f) => s + f.rating, 0) / list.length;
  const hero = $('ratingHero');
  hero.textContent = '';
  if (rated.length) {
    const a = avg(rated);
    const stars = el('span', 'stars-text', starsText(Math.round(a)));
    stars.setAttribute('aria-hidden', 'true');
    hero.append(el('p', 'tile-label', 'Average rating'), el('p', 'rating-big', a.toFixed(1)), stars,
      el('p', 'small muted', 'out of 5, from ' + fmt(rated.length) + (rated.length === 1 ? ' rating' : ' ratings')));
  } else {
    hero.append(el('p', 'tile-label', 'Average rating'), el('p', 'empty', 'No ratings in this period yet.'));
  }
  if (all.length && all.length !== rated.length) {
    hero.appendChild(el('p', 'small', 'All time: ' + avg(all).toFixed(1) + ' from ' + fmt(all.length) + ' ratings.'));
  }
  bars($('barsStars'), [5, 4, 3, 2, 1].map((n) => ({ label: n + (n === 1 ? ' star' : ' stars'),
    value: rated.filter((f) => f.rating === n).length, keep: true })), { total: rated.length, empty: 'No ratings in this period yet.' });
  const inP = state.feedback.filter((f) => inPeriod(f.created));
  table($('tableRoles'), ['Who', 'Ratings', 'Average', 'Messages'], Object.keys(ROLES).map((k) => {
    const r = inP.filter((f) => f.role === k && f.rating);
    return [ROLES[k], r.length, r.length ? avg(r).toFixed(1) : '–', inP.filter((f) => f.role === k && f.message).length];
  }), 'Ratings and messages by who sent them', true);
}

// ---- Messages ------------------------------------------------------------------------
const inbox = { status: 'all', type: 'all', starred: false, q: '', shown: 25 };
function renderInbox() {
  const q = inbox.q.toLowerCase();
  const list = state.feedback.filter((f) => (inbox.status === 'all' || f.status === inbox.status) &&
    (inbox.type === 'all' || f.type === inbox.type) && (!inbox.starred || f.starred) &&
    (!q || ((f.message || '') + ' ' + (f.device || '')).toLowerCase().includes(q)));
  const more = state.feedback.length >= FEEDBACK_LIMIT ? ' The newest ' + FEEDBACK_LIMIT + ' are loaded.' : '';
  $('inboxCount').textContent = list.length
    ? 'Showing ' + fmt(Math.min(inbox.shown, list.length)) + ' of ' + fmt(list.length) + '.' + more
    : state.feedback.length ? 'No messages match.' : 'No ratings or messages yet.';
  const ul = $('inbox');
  ul.textContent = '';
  list.slice(0, inbox.shown).forEach((f) => ul.appendChild(messageItem(f)));
  $('btnMore').hidden = list.length <= inbox.shown;
}

function messageItem(f) {
  const li = el('li', 'msg-item');
  const sync = () => {
    li.classList.toggle('is-new', f.status === 'new');
    li.classList.toggle('is-done', f.status === 'done');
    badge.hidden = f.status !== 'new';
  };
  const head = el('div', 'msg-head');
  const badge = el('span', 'tag new', 'New');
  head.appendChild(badge);
  if (f.rating) {
    const s = el('span', 'stars-text', starsText(f.rating));
    s.setAttribute('aria-hidden', 'true');
    head.append(s, srOnly('Rated ' + f.rating + ' out of 5'));
  }
  head.append(el('span', 'tag', TYPES[f.type] || f.type), el('span', null, ROLES[f.role] || f.role));
  if (f.created) {
    const t = el('time', null, whenLabel(f.created));
    t.dateTime = f.created.toISOString();
    head.appendChild(t);
  }
  head.appendChild(el('span', null, (PAGES[f.page] || f.page) + ' page · ' + (LANGS[f.lang] || f.lang)));
  if (f.device) head.appendChild(el('span', null, 'Device: ' + f.device));
  const text = el('p', 'msg-text' + (f.message ? '' : ' none'), f.message || 'A rating, with no message.');
  const actions = el('div', 'msg-actions');
  const status = el('label', 'field field-inline', 'Status ');
  const sel = el('select');
  [['new', 'New'], ['seen', 'Seen'], ['done', 'Done']].forEach(([v, name]) => {
    const o = el('option', null, name);
    o.value = v;
    sel.appendChild(o);
  });
  sel.value = f.status;
  status.appendChild(sel);
  const star = el('button', 'btn btn-secondary btn-sm');
  star.type = 'button';
  const showStar = () => { star.textContent = f.starred ? '★ Starred' : '☆ Star'; star.setAttribute('aria-pressed', String(!!f.starred)); };
  showStar();
  const del = el('button', 'btn btn-danger btn-sm', 'Delete');
  del.type = 'button';
  const note = el('span', 'msg bad');
  note.setAttribute('aria-live', 'polite');
  actions.append(status, star, del, note);
  li.append(head, text, actions);
  sync();

  const save = (patch, undo) => updateDoc(doc(db, 'feedback', f.id), patch)
    .then(() => { say(note, ''); renderKpis(); renderOverview(); }, (e) => { undo(); say(note, 'Not saved (' + (e.code || e.message) + ').', 'bad'); });
  sel.addEventListener('change', () => {
    const before = f.status;
    f.status = sel.value;
    sync();
    save({ status: f.status }, () => { f.status = before; sel.value = before; sync(); });
  });
  star.addEventListener('click', () => {
    f.starred = !f.starred;
    showStar();
    save({ starred: f.starred }, () => { f.starred = !f.starred; showStar(); });
  });
  del.addEventListener('click', () => {
    if (!confirm('Delete this ' + (f.message ? 'message' : 'rating') + ' for good? This cannot be undone.')) return;
    del.disabled = true;
    deleteDoc(doc(db, 'feedback', f.id)).then(() => {
      state.feedback = state.feedback.filter((x) => x !== f);
      renderInbox();
      renderKpis();
      renderRatings();
      renderOverview();
    }, (e) => { del.disabled = false; say(note, 'Not deleted (' + (e.code || e.message) + ').', 'bad'); });
  });
  return li;
}

// ---- Downloads -----------------------------------------------------------------------
function renderDownloads() {
  const gh = state.gh;
  if (!gh) return;
  if (!gh.ok) {
    for (const id of ['barsReleases', 'barsVariants']) {
      $(id).textContent = '';
      $(id).appendChild(el('p', 'empty', gh.error));
    }
    $('ghNote').textContent = '';
    return;
  }
  $('ghNote').textContent = fmt(gh.total) + ' APK downloads in all';
  bars($('barsReleases'), gh.releases.slice(0, 12).map((x) => ({
    label: x.tag + ' · ' + dayLabel(manilaDay(Date.parse(x.date)), true), value: x.total, keep: true,
  })), { share: false });
  const v = {};
  gh.releases.forEach((x) => { for (const k in x.variants) v[k] = (v[k] || 0) + x.variants[k]; });
  bars($('barsVariants'), [
    { label: '64-bit (arm64, most devices)', value: v.arm64 || 0, keep: true },
    { label: '32-bit (arm32, older devices)', value: v.arm32 || 0, keep: true },
    { label: 'Universal (any device)', value: v.universal || 0, keep: true },
  ], { total: gh.total });
}

function renderDownloadTrend() {
  if (!period) return;
  const byId = new Map(state.snaps.map((s) => [s.id, s.total]));
  const values = period.days.map((d) => (byId.has(d) ? byId.get(d) : null));
  const saved = period.days.filter((d) => byId.has(d));
  lineChart($('chartDownloads'), {
    labels: period.days, connect: true, minPoints: 2, name: 'Total downloads, as saved each day',
    series: [{ name: 'Total downloads', cls: 's1', values }],
    empty: saved.length
      ? 'One total saved so far in this period: ' + fmt(byId.get(saved[0])) + ' on ' + dayLabel(saved[0], true) +
        '. The line starts once a second day is saved (each day an administrator opens this page).'
      : 'No totals saved in this period. One is saved each day an administrator opens this page.',
  });
  const rows = [];
  let prev = state.snaps.filter((s) => s.id < period.from).sort((a, b) => (a.id < b.id ? 1 : -1))[0];
  prev = prev ? prev.total : null;
  period.days.forEach((d) => {
    if (!byId.has(d)) return;
    const t = byId.get(d);
    rows.push([dayLabel(d, true), t, prev == null ? '–' : (t - prev >= 0 ? '+' : '') + fmt(t - prev)]);
    prev = t;
  });
  table($('tableDownloads'), ['Day saved', 'Total downloads', 'Change since the last save'], rows.reverse(), 'Total downloads over time, table');
}

function renderHealth() {
  ['healthBody', 'healthSummary'].forEach((id) => fillHealth($(id)));
}
function fillHealth(host) {
  const gh = state.gh, site = state.site;
  if (!gh) return;
  host.textContent = '';
  const latest = site && site.latest;
  const siteTag = latest && latest.apks && latest.apks.arm64 ? (/\/download\/([^/]+)\//.exec(latest.apks.arm64.url) || [])[1] : null;
  host.appendChild(el('p', 'small', latest
    ? 'The website’s update file (version.json) offers ' + latest.version + (siteTag ? ', with the files of ' + siteTag : '') + '.'
    : 'The website’s update file (version.json) could not be read.'));
  if (!gh.ok) return;
  const rel = gh.releases.find((x) => x.tag === gh.latest);
  host.appendChild(el('p', 'small', 'GitHub’s latest release: ' + gh.latest +
    (gh.latestDate ? ', ' + dayLabel(manilaDay(Date.parse(gh.latestDate)), true) : '') +
    (rel ? ', with ' + rel.apks.length + ' APK files' : '') + '.'));
  const bad = rel ? rel.apks.filter((a) => !a.ok) : [];
  let line;
  if (siteTag && siteTag !== gh.latest) {
    line = el('p', 'status-line warn', '⚠ The download links point at ' + siteTag + ', but GitHub’s latest release is ' + gh.latest +
      '. Rebuild the download page (tools/release_page_build.py) and deploy the site.');
  } else if (bad.length) {
    line = el('p', 'status-line warn', '⚠ Not fully uploaded on GitHub: ' + bad.map((a) => a.name).join(', ') + '.');
  } else if (siteTag) {
    line = el('p', 'status-line good', '✓ The download links point at the latest release, and its files are uploaded.');
  }
  if (line) host.appendChild(line);
}

// ---- Charts --------------------------------------------------------------------------
function niceStep(raw) {
  const p = Math.pow(10, Math.floor(Math.log10(raw)));
  const f = raw / p;
  return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
}

function lineChart(host, opt) {
  host._opt = opt;
  drawLine(host);
  if (!host._ro) {
    host._ro = new ResizeObserver(() => { if (host._w !== host.clientWidth) drawLine(host); });
    host._ro.observe(host);
  }
}

function drawLine(host) {
  const opt = host._opt, { labels, series } = opt;
  host.textContent = '';
  host._w = host.clientWidth;
  host.onkeydown = host.onfocus = host.onblur = null;
  host.removeAttribute('tabindex');
  const values = series.flatMap((s) => s.values.filter((v) => v != null));
  if (!labels.length || values.length < (opt.minPoints || 1) || (!opt.connect && !values.some((v) => v))) {
    host.appendChild(el('p', 'empty', opt.empty || 'Nothing counted in this period yet.'));
    return;
  }
  if (series.length > 1) {
    const legend = el('ul', 'legend');
    series.forEach((s) => {
      const li = el('li');
      li.append(el('span', 'key ' + s.cls), document.createTextNode(s.name));
      legend.appendChild(li);
    });
    host.appendChild(legend);
  }
  const W = Math.max(260, host.clientWidth), H = 230, L = 44, R = 18, T = 14, B = 28;
  const lo = opt.connect ? Math.min(...values) : 0;
  const step = niceStep(Math.max(1, (Math.max(...values) - lo) / 4) || 1);
  const min = opt.connect ? Math.floor(lo / step) * step : 0;
  const max = Math.max(min + step, Math.ceil(Math.max(...values) / step) * step);
  const n = labels.length;
  const X = (i) => L + (n === 1 ? (W - L - R) / 2 : (i * (W - L - R)) / (n - 1));
  const Y = (v) => T + (H - T - B) * (1 - (v - min) / (max - min));
  const lastOf = (s) => { for (let i = n - 1; i >= 0; i--) if (s.values[i] != null) return i; return -1; };
  const summary = series.map((s) => s.name + ' ' + fmt(opt.connect ? s.values[lastOf(s)] : s.values.reduce((a, v) => a + (v || 0), 0)))
    .join(', ');
  const root = svg('svg', { viewBox: `0 0 ${W} ${H}`, width: W, height: H, role: 'img',
    'aria-label': opt.name + ', ' + period.label + ': ' + summary + (opt.connect ? ' at the end' : ' in all') + '. The numbers are in the table below.' }, host);
  for (let v = min; v <= max + 1e-9; v += step) {
    svg('line', { class: v === min ? 'axis' : 'grid', x1: L, x2: W - R, y1: Y(v), y2: Y(v) }, root);
    svg('text', { class: 'tick', x: L - 8, y: Y(v) + 4, 'text-anchor': 'end' }, root).textContent = compact(v);
  }
  // Dates along the bottom: the first, the last, and evenly between.
  const dateAt = (i, anchor) => {
    svg('text', { class: 'tick', x: X(i), y: H - 8, 'text-anchor': anchor }, root).textContent = dayLabel(labels[i]);
  };
  if (n === 1) dateAt(0, 'middle');
  else {
    const every = Math.max(1, Math.ceil(n / Math.max(2, Math.floor((W - L - R) / 72))));
    const gap = (W - L - R) / (n - 1);
    for (let i = 0; i < n - 1; i += every) if (i === 0 || (n - 1 - i) * gap >= 64) dateAt(i, i === 0 ? 'start' : 'middle');
    dateAt(n - 1, 'end');
  }
  series.forEach((s) => {
    let d = '', pen = false;
    s.values.forEach((v, i) => {
      if (v == null) { if (!opt.connect) pen = false; return; }
      d += (pen ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(v).toFixed(1) + ' ';
      pen = true;
    });
    svg('path', { class: 'line ' + s.cls, d }, root);
    if (opt.connect) {
      s.values.forEach((v, i) => { if (v != null) svg('circle', { class: 'mark ' + s.cls, cx: X(i), cy: Y(v), r: 4 }, root); });
    }
  });
  // Direct labels at the line ends, unless they would overlap.
  const ends = series.map((s) => ({ s, i: lastOf(s) })).filter((e) => e.i >= 0);
  const ys = ends.map((e) => Y(e.s.values[e.i]));
  const apart = ys.every((y, k) => ys.every((y2, j) => j === k || Math.abs(y - y2) >= 16));
  ends.forEach((e, k) => {
    if (!opt.connect) svg('circle', { class: 'mark ' + e.s.cls, cx: X(e.i), cy: ys[k], r: 4 }, root);
    if (apart) {
      svg('text', { class: 'end-label', x: X(e.i) - 8, y: ys[k] - 9, 'text-anchor': 'end' }, root)
        .textContent = fmt(e.s.values[e.i]);
    }
  });
  // Hover and keyboard: a crosshair snaps to the nearest day and the tooltip
  // lists every series there.
  const cross = svg('line', { class: 'cross', x1: 0, x2: 0, y1: T, y2: H - B, visibility: 'hidden' }, root);
  const dots = series.map((s) => svg('circle', { class: 'mark ' + s.cls, r: 5, visibility: 'hidden' }, root));
  const hit = svg('rect', { class: 'hit', x: L - 6, y: 0, width: W - L - R + 12, height: H - B }, root);
  let cur = -1;
  const point = (i, cx, cy) => {
    cur = i;
    cross.setAttribute('x1', X(i));
    cross.setAttribute('x2', X(i));
    cross.setAttribute('visibility', 'visible');
    const box = el('div');
    box.appendChild(el('div', 'tip-head', (opt.weekly ? 'Week of ' : '') + dayLabel(labels[i], true)));
    series.forEach((s, j) => {
      const v = s.values[i];
      if (v == null) { dots[j].setAttribute('visibility', 'hidden'); return; }
      dots[j].setAttribute('cx', X(i));
      dots[j].setAttribute('cy', Y(v));
      dots[j].setAttribute('visibility', 'visible');
      const row = el('div', 'tip-row');
      row.append(el('span', 'key ' + s.cls), el('b', null, fmt(v)), document.createTextNode(s.name));
      box.appendChild(row);
    });
    if (box.children.length === 1) box.appendChild(el('div', null, opt.connect ? 'Not saved that day' : 'Nothing counted'));
    showTip(box, cx, cy);
  };
  const off = () => {
    cross.setAttribute('visibility', 'hidden');
    dots.forEach((d) => d.setAttribute('visibility', 'hidden'));
    hideTip();
  };
  const indexAt = (clientX) => {
    const r = root.getBoundingClientRect();
    const x = ((clientX - r.left) * W) / r.width;
    return n === 1 ? 0 : Math.max(0, Math.min(n - 1, Math.round(((x - L) / (W - L - R)) * (n - 1))));
  };
  hit.addEventListener('pointermove', (e) => point(indexAt(e.clientX), e.clientX, e.clientY));
  hit.addEventListener('pointerleave', off);
  host.tabIndex = 0;
  const keyPoint = (i) => {
    const r = root.getBoundingClientRect();
    point(i, r.left + (X(i) * r.width) / W, r.top + T + 20);
  };
  host.onfocus = () => keyPoint(cur >= 0 ? cur : n - 1);
  host.onblur = off;
  host.onkeydown = (e) => {
    const next = { ArrowLeft: cur - 1, ArrowRight: cur + 1, Home: 0, End: n - 1 }[e.key];
    if (next == null) return;
    e.preventDefault();
    keyPoint(Math.max(0, Math.min(n - 1, next)));
  };
}

function bars(host, rows, opt = {}) {
  host.textContent = '';
  const shown = rows.filter((r) => r.value > 0 || r.keep);
  if (!shown.length || !shown.some((r) => r.value > 0)) {
    host.appendChild(el('p', 'empty', opt.empty || 'Nothing counted in this period yet.'));
    return;
  }
  const max = Math.max(...shown.map((r) => r.value), 1);
  const share = opt.share !== false && opt.total;
  const ul = el('ul', 'bars');
  shown.forEach((r) => {
    const li = el('li');
    const track = el('span', 'bar-track');
    const fill = el('span', 'bar-fill' + (r.value ? '' : ' zero'));
    fill.style.width = (r.value / max) * 100 + '%';
    track.appendChild(fill);
    const val = el('span', 'bar-val', fmt(r.value));
    if (share) val.appendChild(el('span', 'share', ' · ' + pct(r.value, opt.total)));
    li.append(el('span', 'bar-name', r.label), track, val);
    li.addEventListener('pointerenter', (e) => {
      const box = el('div');
      box.append(el('div', 'tip-head', r.label));
      const row = el('div', 'tip-row');
      row.append(el('b', null, fmt(r.value)), document.createTextNode(share ? pct(r.value, opt.total) + ' ' + (opt.tipNote || 'of ' + fmt(opt.total)) : ''));
      box.appendChild(row);
      showTip(box, e.clientX, e.clientY);
    });
    li.addEventListener('pointermove', (e) => moveTip(e.clientX, e.clientY));
    li.addEventListener('pointerleave', hideTip);
    ul.appendChild(li);
  });
  host.appendChild(ul);
}

// A table in its own scrolling box: focusable and named, so a keyboard can scroll it.
function table(host, head, rows, name, compact) {
  host.textContent = '';
  if (!rows.length) {
    host.appendChild(el('p', 'empty', 'No rows in this period.'));
    return;
  }
  const wrap = el('div', 'tbl-wrap'), t = el('table', 'tbl' + (compact ? ' compact' : ''));
  wrap.tabIndex = 0;
  wrap.setAttribute('role', 'region');
  wrap.setAttribute('aria-label', name);
  const tr = el('tr');
  head.forEach((h, i) => { const th = el('th', i ? 'num' : null, h); th.scope = 'col'; tr.appendChild(th); });
  t.appendChild(el('thead')).appendChild(tr);
  const body = el('tbody');
  rows.forEach((r) => {
    const row = el('tr');
    r.forEach((c, i) => row.appendChild(el(i ? 'td' : 'th', i ? 'num' : null, typeof c === 'number' ? fmt(c) : c)));
    row.firstChild.scope = 'row';
    body.appendChild(row);
  });
  t.appendChild(body);
  wrap.appendChild(t);
  host.appendChild(wrap);
}

// ---- Exports -------------------------------------------------------------------------
// A cell that starts like a formula (= + - @) is written as text, so a
// visitor's words can never run as a spreadsheet formula.
function csvCell(v) {
  let s = v == null ? '' : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}
function saveCsv(name, rows) {
  const text = '﻿' + rows.map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';
  const a = el('a');
  a.href = URL.createObjectURL(new Blob([text], { type: 'text/csv;charset=utf-8' }));
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}
function exportDaily() {
  const byId = new Map(state.daily.map((r) => [r.id, r]));
  const signs = new Map(state.signs.map((r) => [r.id, r]));
  const rows = period.days.map((d) => {
    const r = byId.get(d) || {}, s = signs.get(d) || {};
    const plays = Object.keys(s).filter((k) => k.startsWith('w_')).reduce((a, k) => a + s[k], 0);
    return [d, ...CSV_KEYS.map(([k]) => r[k] || 0), plays];
  });
  saveCsv('flashlearn-website-daily-' + period.from + '-to-' + period.to + '.csv',
    [['date_manila', ...CSV_KEYS.map(([, name]) => name), 'fsl_sign_plays'], ...rows]);
}
function exportMessages() {
  const rows = state.feedback.map((f) => [
    f.created ? manilaDay(f.created.getTime()) + ' ' + new Date(f.created.getTime() + 8 * 36e5).toISOString().slice(11, 16) : '',
    TYPES[f.type] || f.type, ROLES[f.role] || f.role, f.rating || '', f.message || '', f.device || '',
    PAGES[f.page] || f.page, LANGS[f.lang] || f.lang, f.status, f.starred ? 'yes' : '',
  ]);
  saveCsv('flashlearn-website-messages-' + manilaDay() + '.csv',
    [['sent_manila', 'kind', 'who', 'rating', 'message', 'device', 'page', 'language', 'status', 'starred'], ...rows]);
}

// ---- Controls ------------------------------------------------------------------------
// A row of radio buttons: one choice, arrow keys move it.
function radioRow(row, attr, value, onPick) {
  const items = [...row.querySelectorAll('[' + attr + ']')];
  const set = (v) => items.forEach((b) => {
    const on = b.getAttribute(attr) === v;
    b.setAttribute('aria-checked', String(on));
    b.tabIndex = on ? 0 : -1;
  });
  items.forEach((b, i) => {
    b.addEventListener('click', () => { set(b.getAttribute(attr)); onPick(b.getAttribute(attr)); });
    b.addEventListener('keydown', (e) => {
      const j = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: items.length - 1 }[e.key];
      if (j == null) return;
      e.preventDefault();
      const t = items[(j + items.length) % items.length];
      t.focus();
      t.click();
    });
  });
  set(value);
}

function initDash() {
  dashReady = true;
  const saved = stored('flp-admin-range');
  if (['7', '30', '90', '365', 'all'].includes(saved)) state.range = saved;
  radioRow(document.querySelector('.page-tools .seg'), 'data-range', state.range, (v) => {
    state.range = v;
    stored('flp-admin-range', v);
    load();
  });
  $('btnRefresh').addEventListener('click', () => {
    try { sessionStorage.removeItem('flp-admin-github'); } catch (e) {}
    load();
  });
  radioRow(document.querySelector('.inbox-tools .seg'), 'data-status', inbox.status, (v) => { inbox.status = v; inbox.shown = 25; renderInbox(); });
  $('selType').addEventListener('change', (e) => { inbox.type = e.target.value; inbox.shown = 25; renderInbox(); });
  $('chkStarred').addEventListener('change', (e) => { inbox.starred = e.target.checked; renderInbox(); });
  let typing = 0;
  $('inSearch').addEventListener('input', (e) => {
    clearTimeout(typing);
    typing = setTimeout(() => { inbox.q = e.target.value.trim(); inbox.shown = 25; renderInbox(); }, 200);
  });
  $('btnMore').addEventListener('click', () => { inbox.shown += 25; renderInbox(); });
  $('btnCsvDaily').addEventListener('click', () => period && exportDaily());
  $('btnCsvMessages').addEventListener('click', exportMessages);
  $('lnkNoCount').href = SITE.url + '?nocount=on';
  $('lnkCount').href = SITE.url + '?nocount=off';
  const firebase = 'https://console.firebase.google.com/project/' + CONFIG.projectId;
  const links = [
    ['The public website', SITE.url],
    ['GitHub releases (download files)', 'https://github.com/' + SITE.repo + '/releases'],
    ['Firebase: the data (Firestore)', firebase + '/firestore/databases/-default-/data'],
    ['Firebase: who has signed in (Authentication)', firebase + '/authentication/users'],
    ['Firebase: how much of the free quota is used', firebase + '/usage'],
  ];
  const ul = $('links');
  links.forEach(([name, href]) => {
    const a = el('a', null, name);
    a.href = href;
    a.target = '_blank';
    a.rel = 'noopener';
    ul.appendChild(el('li')).appendChild(a);
  });
}

// ---- Start (last, once everything above is defined) ---------------------------------
if (!CONFIG.apiKey || !CONFIG.projectId) {
  show('viewSetup');
} else {
  const app = initializeApp(CONFIG);
  auth = getAuth(app);
  db = getFirestore(app);
  if (EMULATOR) {
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
    connectFirestoreEmulator(db, '127.0.0.1', 8080);
    $('emuBadge').hidden = false;
  }
  wireSignIn();
  onAuthStateChanged(auth, onUser);
}
