/* FlashLearn PWD site service worker — offline support for every page.
   Screenshots and videos are not precached (they load when shown, then stay
   cached); assets/fsl-dict.js is build input for the dictionary page, not
   something a page loads. */
const CACHE = 'flp-site-v24-a3ddb18a';
const CORE = [
  './',
  'index.html',
  'try.html',
  'download.html',
  'how-to-use.html',
  'games.html',
  'fsl-dictionary.html',
  'teachers-guide.html',
  'faq.html',
  'awareness.html',
  'about.html',
  'privacy.html',
  'gaze-control.html',
  'manifest.webmanifest',
  'assets/site.css?v=1032330bac',
  'assets/site.js?v=66570b5b38',
  'assets/try.js?v=97e7687e01',
  'assets/logo.webp',
  'assets/videos/app-demo.en.vtt',
  'assets/videos/app-demo.fil.vtt',
  'assets/videos/gaze-demo.en.vtt',
  'assets/videos/gaze-demo.fil.vtt',
  'assets/icon-192.png',
  'assets/qr-site.png',
  'assets/fonts/Fredoka-SemiBold.woff2',
  'assets/fonts/Fredoka-Medium.woff2',
  'assets/fonts/Nunito-Regular.woff2',
  'assets/fonts/Nunito-Bold.woff2',
  'assets/fonts/Nunito-ExtraBold.woff2',
  'assets/fonts/Lexend-Regular.woff2',
  'assets/fonts/Lexend-SemiBold.woff2',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== location.origin) return;
  // The release manifest must always be fresh — never answer it from cache.
  if (url.pathname.endsWith('/version.json')) return;

  // Pages: network first (fresh content), fall back to cache when offline.
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
          return res;
        })
        .catch(() => caches.match(req).then((m) => m || caches.match('index.html')))
    );
    return;
  }

  // Assets: cache first, then network (and cache complete 200 responses —
  // video elements fetch byte ranges, and partial 206 responses can't be cached).
  e.respondWith(
    caches.match(req).then((m) =>
      m ||
      fetch(req).then((res) => {
        if (res.status === 200) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      })
    )
  );
});
