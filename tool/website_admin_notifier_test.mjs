// Tests website_admin/email_notifier/Code.gs (the feedback email notifier) in
// Node, with small stand-ins for the Google services it uses (MailApp,
// CacheService, PropertiesService, LockService, ContentService). Nothing is
// sent anywhere.
//
//     node tool/website_admin_notifier_test.mjs
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const DIR = join(ROOT, 'website_admin', 'email_notifier');
const SOURCE = readFileSync(join(DIR, 'Code.gs'), 'utf8');
const MANIFEST = JSON.parse(readFileSync(join(DIR, 'appsscript.json'), 'utf8'));
// The code without its comments (the comments explain that there is no password).
const CODE = SOURCE.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:'"])\/\/.*$/gm, '$1');

let passed = 0, failed = 0;
function check(label, ok, detail) {
  if (ok) passed++; else failed++;
  console.log((ok ? 'PASS ' : 'FAIL ') + label + (ok || detail === undefined ? '' : '  [' + JSON.stringify(detail).slice(0, 300) + ']'));
}

// A fresh copy of the script with fresh stand-ins.
function load(opts = {}) {
  const mail = { sent: [], quota: opts.quota ?? 100, fail: false };
  const cache = new Map(), props = new Map();
  const logs = [];
  const sandbox = {
    console: { log: (m) => logs.push(String(m)), error: (m) => logs.push('ERROR ' + m) },
    MailApp: {
      sendEmail(o) {
        if (mail.fail) throw new Error('Service invoked too many times for one day: email.');
        if (typeof o !== 'object') throw new Error('expected one options object');
        mail.sent.push(o);
      },
      getRemainingDailyQuota: () => mail.quota,
    },
    CacheService: { getScriptCache: () => ({ get: (k) => (cache.has(k) ? cache.get(k) : null), put: (k, v) => cache.set(k, String(v)) }) },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (k) => (props.has(k) ? props.get(k) : null),
        setProperty: (k, v) => props.set(k, String(v)),
        getKeys: () => [...props.keys()],
        deleteProperty: (k) => props.delete(k),
      }),
    },
    LockService: { getScriptLock: () => ({ tryLock: () => opts.lockFree !== false, releaseLock() {} }) },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: (s) => ({ text: s, mime: null, setMimeType(m) { this.mime = m; return this; } }),
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(SOURCE, sandbox, { filename: 'Code.gs' });
  const get = (name) => vm.runInContext(name, sandbox);
  const post = (body) => {
    const out = sandbox.doPost({ postData: { contents: typeof body === 'string' ? body : JSON.stringify(body), type: 'text/plain' } });
    return { ...JSON.parse(out.text), _mime: out.mime };
  };
  return { sandbox, mail, cache, props, logs, get, post, doGet: () => JSON.parse(sandbox.doGet().text) };
}

const ID = 'AbCdEfGhIjKlMnOpQrSt';
const MSG = { id: ID, type: 'problem', role: 'teacher', message: 'The Next button\nis hard to press.', rating: 4,
              device: 'Galaxy Tab A9', page: 'faq', lang: 'fil' };
const today = new Date(Date.now() + 8 * 3600e3).toISOString().slice(0, 10);

// ---- The one address ----
{
  const s = load();
  check('the notices go to jaj4ngpinasto@gmail.com, written once in the script', s.get('ADMIN_EMAIL') === 'jaj4ngpinasto@gmail.com'
        && (SOURCE.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}/g) || []).every((a) => a === 'jaj4ngpinasto@gmail.com'));
  check('it uses MailApp only: no Gmail mailbox access, no web requests, no HTML email',
        !/GmailApp|UrlFetchApp|htmlBody|DriveApp|SpreadsheetApp/.test(SOURCE));
  check('it holds no password, app password, token or key',
        !/password|passwd|secret|api[_-]?key|token|credential/i.test(CODE)
        && !/AIza[0-9A-Za-z_-]{20,}|ya29\.|sk-[A-Za-z0-9]{20,}|-----BEGIN/.test(SOURCE));
  check("the manifest asks Google for one permission only: 'Send email as you'",
        JSON.stringify(MANIFEST.oauthScopes) === JSON.stringify(['https://www.googleapis.com/auth/script.send_mail']));
  check('the web app runs as its owner and accepts the public website (anyone, no sign-in)',
        MANIFEST.webapp.executeAs === 'USER_DEPLOYING' && MANIFEST.webapp.access === 'ANYONE_ANONYMOUS');
}

// ---- Health check ----
{
  const s = load();
  const g = s.doGet();
  check('"Check the connection" answers with the service, its version, a masked address and the notices left today',
        g.ok === true && g.service === 'flashlearn-feedback-mail' && g.version === 1 && g.to === 'ja…to@gmail.com' && g.left === 40, g);
}

// ---- A message ----
{
  const s = load();
  const r = s.post(MSG);
  const m = s.mail.sent[0] || {};
  check('a valid message is emailed once and answered ok (JSON)', r.ok === true && !r.duplicate && s.mail.sent.length === 1
        && r._mime === 'application/json', r);
  check('…to the admin address only', m.to === 'jaj4ngpinasto@gmail.com' && !m.cc && !m.bcc && !m.replyTo, m);
  check('…with a subject naming the kind, who sent it, the stars and a reference',
        m.subject === '[FlashLearn PWD] New problem report from a teacher ★★★★☆ (ref AbCdEfGh)', m.subject);
  check('…and a body with every detail, the words as written and the dashboard link',
        /Kind: +Problem or bug/.test(m.body) && /From: +Teacher/.test(m.body) && /Rating: +4 out of 5/.test(m.body)
        && /Device: +Galaxy Tab A9/.test(m.body) && /Page: +FAQ and feedback \(in Filipino\)/.test(m.body)
        && m.body.includes('Reference:  ' + ID) && m.body.includes('The Next button\nis hard to press.')
        && m.body.includes('https://flashlearn-pwd-site.web.app/#feedback'), m.body);
  check('the email is plain text (no htmlBody)', !('htmlBody' in m));
  const again = s.post(MSG);
  check('the same feedback again (a retry) is answered ok, as a duplicate, and not emailed twice',
        again.ok === true && again.duplicate === true && s.mail.sent.length === 1, again);
  check('the day counter counts one notice', s.props.get('day:' + today) === '1');
  check('…and the health check shows 39 left', s.doGet().left === 39);
}

// ---- A rating on its own ----
{
  const s = load();
  const r = s.post({ id: 'R'.repeat(20), type: 'rating', role: 'parent', message: '', rating: 5, page: 'download', lang: 'en' });
  const m = s.mail.sent[0] || {};
  check('a rating on its own is emailed with its stars', r.ok === true && m.subject === '[FlashLearn PWD] New rating ★★★★★ from a parent or guardian (ref RRRRRRRR)'
        && m.body.includes('(A rating with no message.)'), [r, m.subject]);
}

// ---- Nothing in a request can change who receives it ----
{
  const s = load();
  const r = s.post({ ...MSG, id: 'X'.repeat(20), to: 'stranger@example.com', cc: 'x@example.com', bcc: 'y@example.com',
                     replyTo: 'z@example.com', subject: 'hijack', htmlBody: '<b>hi</b>' });
  const m = s.mail.sent[0] || {};
  check('extra fields (to, cc, bcc, replyTo, subject, htmlBody) are ignored: it still goes only to the admin',
        r.ok === true && m.to === 'jaj4ngpinasto@gmail.com' && !m.cc && !m.bcc && !m.replyTo && !m.htmlBody
        && !m.subject.includes('hijack'), m);
}

// ---- Refused: nothing is sent ----
{
  const bad = [
    ['not JSON', 'hello'],
    ['a list instead of one feedback', [MSG]],
    ['no id', { ...MSG, id: undefined }],
    ['a short id', { ...MSG, id: 'abc' }],
    ['an id with symbols', { ...MSG, id: 'AbCdEfGhIjKlMnOpQr/.' }],
    ['an unknown kind', { ...MSG, type: 'spam' }],
    ['an unknown role', { ...MSG, role: 'admin' }],
    ['an unknown page', { ...MSG, page: 'evil' }],
    ['an unknown language', { ...MSG, lang: 'xx' }],
    ['a message over 2,000 characters', { ...MSG, message: 'x'.repeat(2001) }],
    ['a message that is only spaces', { ...MSG, message: '   ' }],
    ['a rating-only entry with words', { ...MSG, type: 'rating' }],
    ['a rating-only entry without stars', { ...MSG, type: 'rating', message: '', rating: undefined }],
    ['six stars', { ...MSG, rating: 6 }],
    ['half a star', { ...MSG, rating: 4.5 }],
    ['stars as text', { ...MSG, rating: '5' }],
    ['a device name over 120 characters', { ...MSG, device: 'd'.repeat(121) }],
    ['a kind that is an inherited name', { ...MSG, type: 'toString' }],
  ];
  const s = load();
  const wrong = bad.filter(([, b]) => { const r = s.post(b); return r.ok !== false || !['bad-request', 'invalid'].includes(r.error); }).map(([n]) => n);
  check('bad requests are refused (' + bad.length + ' kinds) and nothing is emailed', !wrong.length && s.mail.sent.length === 0, wrong);
  check('a message of exactly 2,000 characters is accepted', s.post({ ...MSG, id: 'L'.repeat(20), message: 'x'.repeat(2000) }).ok === true);
}

// ---- Hidden characters ----
{
  const s = load();
  s.post({ ...MSG, id: 'C'.repeat(20), device: 'Tab\nA9\u0007', message: 'Line one\r\nLine two\u0000\u001b[31m' });
  const m = s.mail.sent[0] || {};
  check('control characters are taken out; a message keeps its line breaks, a device name stays on one line',
        m.body.includes('Device:     Tab A9') && m.body.includes('Line one\nLine two[31m') && !/[\u0000\u0007\u001b\r]/.test(m.body), m.body);
}

// ---- Limits ----
{
  const s = load();
  for (let i = 0; i < 8; i++) s.post({ ...MSG, id: 'B'.repeat(19) + i });
  const r = s.post({ ...MSG, id: 'B'.repeat(19) + 'x' });
  check('no more than 8 notices in ten minutes (the 9th is refused, not sent)', r.ok === false && r.error === 'burst-limit' && s.mail.sent.length === 8, r);
}
{
  const s = load();
  s.props.set('day:' + today, '40');
  const r = s.post(MSG);
  check('no more than 40 notices a day', r.ok === false && r.error === 'daily-limit' && s.mail.sent.length === 0, r);
}
{
  const s = load({ quota: 0 });
  const r = s.post(MSG);
  check("Gmail's own daily limit reached: refused, nothing tried", r.ok === false && r.error === 'gmail-quota' && s.mail.sent.length === 0, r);
}
{
  const s = load({ lockFree: false });
  const r = s.post(MSG);
  check('another notice still being sent: refused as busy, not sent twice', r.ok === false && r.error === 'busy' && s.mail.sent.length === 0, r);
}
{
  const s = load();
  s.mail.fail = true;
  const r = s.post(MSG);
  check('when Gmail refuses, the answer says not sent, without Google\'s error text', r.ok === false && r.error === 'send-failed'
        && !('detail' in r) && s.logs.some((l) => l.startsWith('ERROR Not sent')), r);
  check('…nothing is counted, and the same feedback can still be sent later', !s.props.has('day:' + today) && !s.cache.has('sent:' + ID));
  s.mail.fail = false;
  check('…and is, when Gmail works again', s.post(MSG).ok === true && s.mail.sent.length === 1);
}
{
  const s = load();
  s.props.set('day:2020-01-01', '12');
  s.post(MSG);
  check("older days' counters are forgotten", !s.props.has('day:2020-01-01') && s.props.get('day:' + today) === '1');
}

// ---- The dashboard's test email and the editor's checkSetup ----
{
  const s = load();
  const r = s.post({ test: true });
  const m = s.mail.sent[0] || {};
  check('"Send a test email" sends one test notice to the admin', r.ok === true && m.to === 'jaj4ngpinasto@gmail.com'
        && m.subject === '[FlashLearn PWD] Test email: email notices work', [r, m.subject]);
  s.sandbox.checkSetup();
  check('checkSetup (run once in the editor) sends a test email and logs the Gmail quota left',
        s.mail.sent.length === 2 && s.logs.some((l) => l.includes('A test email went to jaj4ngpinasto@gmail.com')));
}

console.log(`\n${passed}/${passed + failed} checks passed`);
process.exit(failed ? 1 : 0);
