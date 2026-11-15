/**
 * FlashLearn PWD: email notices for the website's feedback form.
 *
 * A Google Apps Script web app that runs in the team's own Google account.
 * When a visitor presses "Send to the team" on the feedback form
 * (website/faq.html), the website posts the rating or message here, and this
 * script emails it to ADMIN_EMAIL with MailApp. The website also saves it in
 * the admin dashboard (Firestore), so a notice is a copy, never the only one.
 *
 * What it can do, and nothing more:
 *   - send a plain-text email to ADMIN_EMAIL, the one address written below.
 *     Nothing in a request can change who receives it;
 *   - keep a few small counters (Script properties and Script cache) so it
 *     sends at most DAILY_CAP notices a day and BURST_CAP in ten minutes, and
 *     never the same feedback twice.
 * It reads no mailbox, keeps no copy of the feedback, and stores no password,
 * app password or key: Google runs it as its owner after the owner allowed it
 * once ("Send email as you"). See website_admin/README.md, "Email notices",
 * for setting it up, testing it and turning it off.
 *
 * Free: Apps Script is free with a Google account. Gmail lets a free account's
 * scripts email 100 recipients a day; DAILY_CAP stays well under that.
 *
 * Tested by tool/website_admin_notifier_test.mjs (Node, with stand-ins for
 * Google's services).
 */

const ADMIN_EMAIL = 'jaj4ngpinasto@gmail.com';
const DASHBOARD_URL = 'https://flashlearn-pwd-site.web.app/#feedback';
const DAILY_CAP = 40;      // notices a day (Gmail's free limit is 100 recipients a day)
const BURST_CAP = 8;       // notices within ten minutes
const VERSION = 1;

// The same names as the website's form and the admin dashboard use.
const KINDS = { problem: 'Problem or bug', idea: 'Suggestion', praise: 'Praise or story', rating: 'Rating only' };
const HEADLINES = { problem: 'problem report', idea: 'suggestion', praise: 'praise or story' };
const ROLES = { teacher: 'Teacher', parent: 'Parent or guardian', student: 'Student', other: 'Other' };
const ROLE_PHRASE = { teacher: 'a teacher', parent: 'a parent or guardian', student: 'a student', other: 'someone' };
const PAGES = {
  index: 'Home', try: 'Try It', download: 'Download', how_to_use: 'How to Use', games: 'Learning Games',
  fsl_dictionary: 'FSL Dictionary', teachers_guide: 'Teacher’s Guide', faq: 'FAQ and feedback',
  awareness: 'PWD Awareness', about: 'About', privacy: 'Privacy', gaze_control: 'Gaze Control', other: 'Other pages',
};
const LANGS = { en: 'English', fil: 'Filipino' };

// ---- Web app entry points ----------------------------------------------------------

/** "Is it there?": the dashboard's "Check the connection". */
function doGet() {
  return reply_({
    ok: true, service: 'flashlearn-feedback-mail', version: VERSION,
    to: maskEmail_(ADMIN_EMAIL), left: Math.max(0, DAILY_CAP - usedToday_()),
  });
}

/** A rating or message from the website, or {"test": true} from the dashboard. */
function doPost(e) {
  let body = null;
  try {
    body = JSON.parse((e && e.postData && e.postData.contents) || '');
  } catch (err) {
    return reply_({ ok: false, error: 'bad-request' });
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) return reply_({ ok: false, error: 'bad-request' });
  if (body.test === true) return send_(null, testEmail_);
  const f = clean_(body);
  if (!f) return reply_({ ok: false, error: 'invalid' });
  return send_(f.id, function () { return feedbackEmail_(f); });
}

/**
 * Run this once from the script editor (choose it in the list, press Run):
 * Google asks the owner to allow "Send email as you", then one test email
 * arrives at ADMIN_EMAIL. Nothing else needs a password or key.
 */
function checkSetup() {
  const m = testEmail_();
  MailApp.sendEmail({ to: ADMIN_EMAIL, subject: m.subject, body: m.body, name: 'FlashLearn PWD website' });
  console.log('A test email went to ' + ADMIN_EMAIL + '. Gmail allows this account ' +
              MailApp.getRemainingDailyQuota() + ' more recipients today.');
}

// ---- Sending ----------------------------------------------------------------------------

function send_(id, compose) {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) return reply_({ ok: false, error: 'busy' });
  try {
    const cache = CacheService.getScriptCache();
    // The same feedback again (the website retries after a lost answer): already sent.
    if (id && cache.get('sent:' + id)) return reply_({ ok: true, duplicate: true });
    const props = PropertiesService.getScriptProperties();
    const day = manilaDay_();
    const used = Number(props.getProperty('day:' + day) || 0);
    if (used >= DAILY_CAP) return reply_({ ok: false, error: 'daily-limit' });
    const burst = Number(cache.get('burst') || 0);
    if (burst >= BURST_CAP) return reply_({ ok: false, error: 'burst-limit' });
    if (MailApp.getRemainingDailyQuota() < 1) return reply_({ ok: false, error: 'gmail-quota' });

    const m = compose();
    MailApp.sendEmail({ to: ADMIN_EMAIL, subject: m.subject, body: m.body, name: 'FlashLearn PWD website' });

    props.setProperty('day:' + day, String(used + 1));
    cache.put('burst', String(burst + 1), 600);
    if (id) cache.put('sent:' + id, '1', 21600);   // six hours, the cache's longest
    forgetOldDays_(props, day);
    return reply_({ ok: true });
  } catch (err) {
    // The details stay in the owner's execution log, not in the public answer.
    console.error('Not sent: ' + (err && err.message ? err.message : err));
    return reply_({ ok: false, error: 'send-failed' });
  } finally {
    lock.releaseLock();
  }
}

// ---- Checking what arrived (the same limits as the database rules) ---------------------

function clean_(b) {
  const id = b.id, type = b.type, role = b.role, page = b.page, lang = b.lang;
  if (typeof id !== 'string' || !/^[A-Za-z0-9]{20}$/.test(id)) return null;
  if (!has_(KINDS, type) || !has_(ROLES, role) || !has_(PAGES, page) || !has_(LANGS, lang)) return null;
  if (typeof b.message !== 'string' || b.message.length > 2000) return null;
  const message = text_(b.message, true).trim();
  if ((type === 'rating') !== (message.length === 0)) return null;
  let rating = 0;
  if (b.rating !== undefined && b.rating !== null && b.rating !== 0) {
    if (typeof b.rating !== 'number' || b.rating % 1 !== 0 || b.rating < 1 || b.rating > 5) return null;
    rating = b.rating;
  }
  if (type === 'rating' && !rating) return null;
  let device = '';
  if (b.device !== undefined && b.device !== null) {
    if (typeof b.device !== 'string' || b.device.length > 120) return null;
    device = text_(b.device, false).trim();
  }
  return { id: id, type: type, role: role, page: page, lang: lang, message: message, rating: rating, device: device };
}

function has_(table, key) {
  return typeof key === 'string' && Object.prototype.hasOwnProperty.call(table, key);
}

// Control characters out (they could hide text or break the layout); a message
// keeps its line breaks and tabs, a device name stays on one line.
function text_(s, multiline) {
  const t = String(s).replace(/\r\n?/g, '\n');
  return multiline ? t.replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, '')
                   : t.replace(/[\u0000-\u001F\u007F]/g, ' ');
}

// ---- The emails (plain text only, so nothing a visitor writes can act as HTML) -------

function feedbackEmail_(f) {
  const ref = f.id.slice(0, 8);
  const stars = f.rating ? '★★★★★'.slice(0, f.rating) + '☆☆☆☆☆'.slice(0, 5 - f.rating) : '';
  const who = ROLE_PHRASE[f.role];
  const subject = f.type === 'rating'
    ? '[FlashLearn PWD] New rating ' + stars + ' from ' + who + ' (ref ' + ref + ')'
    : '[FlashLearn PWD] New ' + HEADLINES[f.type] + ' from ' + who + (stars ? ' ' + stars : '') + ' (ref ' + ref + ')';
  const lines = [
    'A visitor sent this with “Send to the team” on the FlashLearn PWD website.',
    '',
    'Kind:       ' + KINDS[f.type],
    'From:       ' + ROLES[f.role],
  ];
  if (f.rating) lines.push('Rating:     ' + f.rating + ' out of 5 (' + stars + ')');
  if (f.device) lines.push('Device:     ' + f.device);
  lines.push('Page:       ' + PAGES[f.page] + ' (in ' + LANGS[f.lang] + ')');
  lines.push('Reference:  ' + f.id);
  lines.push('');
  if (f.message) {
    lines.push('Message:', '----------', f.message, '----------', '');
  } else {
    lines.push('(A rating with no message.)', '');
  }
  lines.push(
    'Find it in the admin dashboard by its reference, to mark it seen or done:',
    DASHBOARD_URL,
    '',
    'The visitor gave no email address, so replying to this email does not reach them.',
    'Sent automatically by the FlashLearn PWD feedback notifier (Google Apps Script in this account).'
  );
  return { subject: subject, body: lines.join('\n') };
}

function testEmail_() {
  return {
    subject: '[FlashLearn PWD] Test email: email notices work',
    body: [
      'This is a test from the FlashLearn PWD admin dashboard (Tools → Email notices).',
      '',
      'If you can read this, ratings and messages sent with “Send to the team” on the',
      'website will also arrive here as emails, at most ' + DAILY_CAP + ' a day.',
      '',
      'Admin dashboard: ' + DASHBOARD_URL,
    ].join('\n'),
  };
}

// ---- Small helpers --------------------------------------------------------------------------

function reply_(o) {
  return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON);
}

/** The first two and last two letters of the name, then the domain: enough for the
 *  dashboard to compare with the address it expects, not a whole address. */
function maskEmail_(email) {
  const at = email.indexOf('@');
  const name = email.slice(0, at);
  return (name.length > 4 ? name.slice(0, 2) + '…' + name.slice(-2) : name.slice(0, 1) + '…') + email.slice(at);
}

/** Today in the Philippines (UTC+8), like the website's own counts. */
function manilaDay_() {
  return new Date(Date.now() + 8 * 3600e3).toISOString().slice(0, 10);
}

function usedToday_() {
  return Number(PropertiesService.getScriptProperties().getProperty('day:' + manilaDay_()) || 0);
}

function forgetOldDays_(props, today) {
  props.getKeys().forEach(function (k) {
    if (k.indexOf('day:') === 0 && k !== 'day:' + today) props.deleteProperty(k);
  });
}
