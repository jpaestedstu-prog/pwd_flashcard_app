/* FlashLearn PWD site service worker — offline support for the core pages. */
const CACHE = 'flp-site-v1';
const CORE = [
  './',
  'index.html',
  'teachers-guide.html',
  'manifest.webmanifest',
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
  'assets/screenshots/01-choose-profile.png',
  'assets/screenshots/02-home.png',
  'assets/screenshots/03-cards-decks.png',
  'assets/screenshots/04-flashcard-viewer.png',
  'assets/screenshots/05-games.png',
  'assets/screenshots/06-stories.png',
  'assets/screenshots/07-progress.png',
  'assets/screenshots/08-settings.png'
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
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;

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

  // Assets: cache first, then network (and cache what we fetch).
  e.respondWith(
    caches.match(req).then((m) =>
      m ||
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
        return res;
      })
    )
  );
});
