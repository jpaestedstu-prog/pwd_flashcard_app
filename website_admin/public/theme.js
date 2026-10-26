// Applies a saved light/dark choice before the first paint (no saved choice:
// the device's own setting). A file, not inline, because the page's
// Content-Security-Policy allows no inline script.
try {
  var t = localStorage.getItem('flp-admin-theme');
  if (t === 'light' || t === 'dark') document.documentElement.setAttribute('data-theme', t);
} catch (e) {}
