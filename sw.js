/* FlashLearn PWD site service worker — offline support for the core pages. */
const CACHE = 'flp-site-v12';
const CORE = [
  './',
  'index.html',
  'teachers-guide.html',
  'fsl-dictionary.html',
  'games.html',
  'privacy.html',
  'manifest.webmanifest',
  'assets/site.js',
  'assets/fsl-dict.js',
  'assets/videos/app-demo.en.vtt',
  'assets/videos/app-demo.fil.vtt',
  'assets/icon-192.png',
  'assets/icon-512.png',
  'assets/qr-site.png',
  'assets/fonts/Fredoka-SemiBold.ttf',
  'assets/fonts/Fredoka-Medium.ttf',
  'assets/fonts/Nunito-Regular.ttf',
  'assets/fonts/Nunito-Bold.ttf',
  'assets/fonts/Nunito-ExtraBold.ttf',
  'assets/fonts/Lexend-Regular.ttf',
  'assets/fonts/Lexend-SemiBold.ttf',
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
