/* FlashLearn PWD site — behaviour shared by every page.

   * Preferences (text size, dyslexia font, high contrast, reduce motion,
     language) persist in localStorage 'flp-a11y', so a choice made on one page
     follows the visitor everywhere. A tiny script in each page's <head> applies
     them before the first paint; this file wires up the controls.
   * Header: the menu button (narrow screens, or whenever the links do not fit)
     and the accessibility panel.
   * Language: shows .en or .fil spans, and also swaps the things a span cannot
     hold — aria-labels (data-label-en/-fil), <option> text (data-en/-fil),
     placeholders (data-ph-en/-fil), the page title and video captions.
   * Moving pictures on Home: the app preview inside the phone, and the film
     (which only loads when someone presses Play).
   * Visit counts and the feedback form's "Send to the team": anonymous daily
     tallies in the website's own statistics database (see "Visit counts").
   * Small helpers: screenshot zoom (img.zoomable), the "On this page" spy,
     --header-h, and the offline copy (service worker). */
(function(){
  var html = document.documentElement;
  html.classList.add('js');
  var prefs = {};
  try { prefs = JSON.parse(localStorage.getItem('flp-a11y') || '{}') || {}; } catch(e){ prefs = {}; }
  function save(){ try { localStorage.setItem('flp-a11y', JSON.stringify(prefs)); } catch(e){} }
  function $(id){ return document.getElementById(id); }
  function each(sel, fn, root){ Array.prototype.forEach.call((root || document).querySelectorAll(sel), fn); }

  // ---- Preferences ------------------------------------------------------
  function applyFont(){
    html.classList.toggle('fs-lg', prefs.font === 'lg');
    html.classList.toggle('fs-xl', prefs.font === 'xl');
    each('[data-font]', function(b){
      b.setAttribute('aria-pressed', String((b.getAttribute('data-font') || '') === (prefs.font || '')));
    });
  }
  function applySwitch(id, on, cls){
    html.classList.toggle(cls, !!on);
    var b = $(id); if (b) b.setAttribute('aria-checked', on ? 'true' : 'false');
  }
  function applyLang(){
    var fil = !!prefs.fil;
    html.classList.toggle('fil', fil);
    html.setAttribute('lang', fil ? 'fil' : 'en');
    var en = $('btnLangEn'), fl = $('btnLangFil');
    if (en) en.setAttribute('aria-pressed', String(!fil));
    if (fl) fl.setAttribute('aria-pressed', String(fil));
    var title = html.getAttribute(fil ? 'data-title-fil' : 'data-title-en');
    if (title) document.title = title;
    var lang = fil ? 'fil' : 'en';
    each('[data-label-en]', function(el){
      var v = el.getAttribute('data-label-' + lang); if (v) el.setAttribute('aria-label', v);
    });
    each('option[data-en]', function(o){
      o.textContent = o.getAttribute('data-' + lang) || o.textContent;
    });
    each('[data-ph-en]', function(el){
      var v = el.getAttribute('data-ph-' + lang); if (v) el.setAttribute('placeholder', v);
    });
    // Captions follow the site language (tracks the visitor switched off stay off).
    each('video', function(v){
      var tracks = v.textTracks || [], anyShowing = false, i;
      for (i = 0; i < tracks.length; i++) anyShowing = anyShowing || tracks[i].mode === 'showing';
      for (i = 0; i < tracks.length; i++) {
        if (anyShowing || tracks[i].mode !== 'disabled') tracks[i].mode = tracks[i].language === lang ? 'showing' : 'hidden';
      }
    });
    filmFollow();   // the film's words are in the picture: swap to the other language's copy
  }
  function applyAll(){
    applyFont();
    applySwitch('btnDys', prefs.dys, 'dys');
    applySwitch('btnHC', prefs.hc, 'hc');
    applySwitch('btnStill', prefs.still, 'still');
    applyLang();
    loopSync();
    layoutChanged();
  }

  each('[data-font]', function(b){
    b.addEventListener('click', function(){ prefs.font = b.getAttribute('data-font') || ''; save(); applyAll(); if (prefs.font) countAid('a_text'); });
  });
  if ($('btnDys')) $('btnDys').addEventListener('click', function(){ prefs.dys = !prefs.dys; save(); applyAll(); if (prefs.dys) countAid('a_dys'); });
  if ($('btnHC')) $('btnHC').addEventListener('click', function(){ prefs.hc = !prefs.hc; save(); applyAll(); if (prefs.hc) countAid('a_hc'); });
  // "Reduce motion" is an explicit, site-wide answer: it also overrides a
  // Play/Pause pressed earlier on the app preview.
  if ($('btnStill')) $('btnStill').addEventListener('click', function(){ prefs.still = !prefs.still; loopChoice = null; save(); applyAll(); if (prefs.still) countAid('a_still'); });
  if ($('btnA11yReset')) $('btnA11yReset').addEventListener('click', function(){
    prefs.font = ''; prefs.dys = false; prefs.hc = false; prefs.still = false; loopChoice = null; save(); applyAll();
  });
  if ($('btnLangEn')) $('btnLangEn').addEventListener('click', function(){ prefs.fil = false; save(); applyAll(); });
  if ($('btnLangFil')) $('btnLangFil').addEventListener('click', function(){ prefs.fil = true; save(); applyAll(); });

  // ---- Header: menu + accessibility panel --------------------------------
  var header = document.querySelector('.site-header');
  var nav = $('siteNav'), menuBtn = $('btnMenu');
  var panel = $('a11yPanel'), a11yBtn = $('btnA11y');

  function setMenu(open, focusBack){
    if (!nav || !menuBtn) return;
    nav.classList.toggle('open', open);
    menuBtn.setAttribute('aria-expanded', String(open));
    if (open) { setPanel(false); var cur = nav.querySelector('a[aria-current]') || nav.querySelector('a'); if (cur) cur.focus(); }
    else if (focusBack) menuBtn.focus();
  }
  function setPanel(open, focusBack){
    if (!panel || !a11yBtn) return;
    panel.hidden = !open;
    a11yBtn.setAttribute('aria-expanded', String(open));
    if (open) { setMenu(false); var first = panel.querySelector('[aria-pressed="true"]') || panel.querySelector('button'); if (first) first.focus(); }
    else if (focusBack) a11yBtn.focus();
  }
  if (menuBtn) menuBtn.addEventListener('click', function(){ setMenu(!nav.classList.contains('open')); });
  if (a11yBtn) a11yBtn.addEventListener('click', function(){ setPanel(panel.hidden); });
  document.addEventListener('keydown', function(e){
    if (e.key !== 'Escape') return;
    if (nav && nav.classList.contains('open')) setMenu(false, true);
    if (panel && !panel.hidden) setPanel(false, true);
  });
  // A click or focus outside either one closes it.
  function outside(e){
    if (!header || header.contains(e.target)) return;
    if (nav && nav.classList.contains('open')) setMenu(false);
    if (panel && !panel.hidden) setPanel(false);
  }
  document.addEventListener('click', outside);
  document.addEventListener('focusin', outside);
  if (panel) panel.addEventListener('focusout', function(e){
    if (e.relatedTarget && !panel.contains(e.relatedTarget) && e.relatedTarget !== a11yBtn) setPanel(false);
  });

  // The links stay in the header only when they actually fit. Measured, not
  // guessed: Filipino labels and the larger text sizes are much wider.
  function fitNav(){
    // Measure the full header (menu closed, not compact, wordmark shown), all
    // in one task so nothing is painted in between.
    html.classList.remove('nav-compact', 'head-tight');
    if (!nav) return;
    var wasOpen = nav.classList.contains('open');
    nav.classList.remove('open');
    var ul = nav.querySelector('ul');
    var inline = getComputedStyle(nav).display !== 'none';   // false below the CSS breakpoint
    if (inline && ul && ul.scrollWidth > ul.clientWidth + 1) html.classList.add('nav-compact');
    var compact = !inline || html.classList.contains('nav-compact');
    if (wasOpen && compact) nav.classList.add('open');
    else if (wasOpen && menuBtn) menuBtn.setAttribute('aria-expanded', 'false');
  }
  // Then the wordmark and the Menu label give way (as they do below 420 px)
  // whenever the controls would still run past the screen: large phones, a
  // phone set to a small display size, the larger text.
  function fitHead(){
    var inner = header && header.querySelector('.header-inner'), tools = header && header.querySelector('.header-tools');
    if (!inner || !tools) return;
    var edge = inner.getBoundingClientRect().right - (parseFloat(getComputedStyle(inner).paddingRight) || 0);
    if (tools.getBoundingClientRect().right > edge + 0.5) html.classList.add('head-tight');
  }
  function measureHeader(){
    if (header) html.style.setProperty('--header-h', Math.round(header.getBoundingClientRect().height) + 'px');
  }
  var raf = 0;
  function layoutChanged(){
    if (raf) return;
    raf = requestAnimationFrame(function(){ raf = 0; fitNav(); fitHead(); measureHeader(); scrollBoxes(); });
  }

  // A table wider than the screen scrolls sideways inside its .table-scroll
  // box. A keyboard user can only scroll a box they can focus, so a box that
  // scrolls becomes a focusable region named after the heading above it.
  function scrollBoxes(){
    each('.table-scroll', function(box){
      var scrolls = box.scrollWidth > box.clientWidth + 1;
      if (scrolls === box.hasAttribute('tabindex')) return;
      if (!scrolls) {
        ['tabindex', 'role', 'aria-label', 'data-label-en', 'data-label-fil'].forEach(function(a){ box.removeAttribute(a); });
        return;
      }
      var heads = [].filter.call(document.querySelectorAll('h2, h3'), function(h){
        return h.compareDocumentPosition(box) & Node.DOCUMENT_POSITION_FOLLOWING;
      });
      var h = heads[heads.length - 1], text = function(sel){
        var s = h && (h.querySelector(sel) || h);
        return s ? s.textContent.trim() : '';
      };
      box.setAttribute('tabindex', '0');
      box.setAttribute('role', 'region');
      box.setAttribute('data-label-en', 'Table: ' + text('.en') + ' (scrolls sideways)');
      box.setAttribute('data-label-fil', 'Talahanayan: ' + text('.fil') + ' (naiiscroll pakanan)');
      box.setAttribute('aria-label', box.getAttribute(prefs.fil ? 'data-label-fil' : 'data-label-en'));
    });
  }
  addEventListener('resize', layoutChanged);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(layoutChanged);

  // ---- Screenshot zoom ----------------------------------------------------
  var zoom = null;
  function openZoom(img){
    if (!zoom) {
      zoom = document.createElement('dialog');
      zoom.className = 'lightbox';
      zoom.setAttribute('aria-label', html.classList.contains('fil') ? 'Pinalaking larawan' : 'Enlarged screenshot');
      zoom.innerHTML = '<button class="close" type="button" aria-label="Close">✕</button><img alt="">';
      document.body.appendChild(zoom);
      zoom.querySelector('.close').addEventListener('click', function(){ zoom.close(); });
      zoom.addEventListener('click', function(e){ if (e.target === zoom) zoom.close(); });
      zoom.addEventListener('close', function(){ var i = zoom.querySelector('img'); i.removeAttribute('src'); i.alt = ''; });
    }
    var big = zoom.querySelector('img');
    big.src = img.currentSrc || img.src; big.alt = img.alt;
    zoom.querySelector('.close').setAttribute('aria-label', html.classList.contains('fil') ? 'Isara' : 'Close');
    zoom.showModal();
  }
  if (typeof HTMLDialogElement === 'function') {
    each('img.zoomable', function(img){
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');
      img.addEventListener('click', function(){ openZoom(img); });
      img.addEventListener('keydown', function(e){
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openZoom(img); }
      });
    });
  }

  // ---- Video chapters: <ol class="chapters" data-video="id"> of [data-t] buttons
  each('.chapters[data-video]', function(list){
    var v = document.getElementById(list.getAttribute('data-video'));
    if (!v) return;
    each('[data-t]', function(b){
      b.addEventListener('click', function(){
        try { v.currentTime = parseFloat(b.getAttribute('data-t')) || 0; } catch(e){}
        var p = v.play(); if (p && p.catch) p.catch(function(){});
        v.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      });
    }, list);
  });

  // ---- "On this page": mark the section being read -------------------------
  var tocLinks = [].slice.call(document.querySelectorAll('.toc a[href^="#"]'))
    .map(function(a){ return { a: a, el: document.getElementById(decodeURIComponent(a.getAttribute('href').slice(1))) }; })
    .filter(function(x){ return x.el; });
  if (tocLinks.length) {
    var spyTick = false;
    var spy = function(){
      spyTick = false;
      var line = (header ? header.getBoundingClientRect().height : 0) + 24, cur = null;
      tocLinks.forEach(function(x){ if (x.el.getBoundingClientRect().top <= line) cur = x.a; });
      tocLinks.forEach(function(x){
        if (x.a === cur) x.a.setAttribute('aria-current', 'true'); else x.a.removeAttribute('aria-current');
      });
    };
    addEventListener('scroll', function(){ if (!spyTick) { spyTick = true; requestAnimationFrame(spy); } }, { passive: true });
    spy();
    // On a narrow screen the contents box starts closed (it would push the
    // guide a screen down) and closes again after a jump.
    if (matchMedia('(max-width:980px)').matches) each('.toc details', function(d){ d.open = false; });
    each('.toc a', function(a){
      a.addEventListener('click', function(){
        var d = a.closest('details');
        if (d && matchMedia('(max-width:980px)').matches) d.open = false;
      });
    });
  }

  // ---- The app preview in Home's phone (<div class="device" data-loop>) -----
  // Plays by itself only when the visitor has not asked for less motion (the
  // "Reduce motion" switch, or the device's own setting) and the connection is
  // not in data-saver or 2G mode. It waits for the page to finish loading,
  // stops while scrolled out of view, and Pause/Play is always next to it.
  // A paused or never-started preview leaves the screenshot showing.
  var loopHost = document.querySelector('.device[data-loop]');
  var loopBtn = $('btnLoop'), heroArt = $('heroArt');
  var loopVid = null, loopChoice = null, loopBlocked = false, loopSeen = true, loopReady = false;
  var mqReduce = window.matchMedia ? matchMedia('(prefers-reduced-motion: reduce)') : { matches: false };
  function lowData(){
    var c = navigator.connection;
    return !!(c && (c.saveData || /(^|-)2g$/.test(c.effectiveType || '')));
  }
  function loopOn(){
    if (loopChoice) return loopChoice === 'play';
    return !prefs.still && !mqReduce.matches && !lowData() && !loopBlocked;
  }
  function loopMake(){
    if (loopVid) return loopVid;
    var v = loopVid = document.createElement('video');
    v.className = 'loop';
    v.muted = true; v.defaultMuted = true; v.loop = true; v.playsInline = true;
    v.setAttribute('muted', ''); v.setAttribute('playsinline', ''); v.setAttribute('loop', '');
    v.setAttribute('disablepictureinpicture', ''); v.setAttribute('disableremoteplayback', '');
    v.setAttribute('aria-hidden', 'true'); v.setAttribute('tabindex', '-1');
    v.preload = 'auto';
    v.src = loopHost.getAttribute('data-loop');
    v.addEventListener('playing', function(){ loopHost.classList.add('is-playing'); });
    // Offline, or the file cannot load: back to the screenshot, and the
    // button offers Play (which tries again with a fresh element).
    v.addEventListener('error', function(){
      loopHost.classList.remove('is-playing');
      if (v.parentNode) v.parentNode.removeChild(v);
      if (loopVid === v) loopVid = null;
      loopChoice = null; loopBlocked = true;
      loopSync();
    });
    loopHost.appendChild(v);
    return v;
  }
  function loopSync(){
    if (!loopHost) return;
    var on = loopOn();
    if (loopBtn) loopBtn.classList.toggle('is-off', !on);
    if (heroArt) heroArt.classList.toggle('paused', !on);
    if (!loopReady) return;   // nothing loads before the page has
    if (on && loopSeen && !document.hidden) {
      var v = loopMake(), p = v.play();
      if (p && p.catch) p.catch(function(){
        // The browser refused (some do in battery saver): show Play instead.
        if (!loopChoice) { loopBlocked = true; loopSync(); }
      });
    } else if (loopVid) {
      loopVid.pause();
    }
  }
  if (loopHost) {
    if (loopBtn) loopBtn.addEventListener('click', function(){
      loopChoice = loopOn() ? 'pause' : 'play';
      loopBlocked = false;
      loopSync();
    });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function(es){
        loopSeen = es[es.length - 1].intersectionRatio > 0.2;
        loopSync();
      }, { threshold: [0, 0.2, 0.5] }).observe(loopHost);
    }
    document.addEventListener('visibilitychange', loopSync);
    if (mqReduce.addEventListener) mqReduce.addEventListener('change', loopSync);
    var loopStart = function(){ setTimeout(function(){ loopReady = true; loopSync(); }, 400); };
    if (document.readyState === 'complete') loopStart();
    else addEventListener('load', loopStart);
  }

  // ---- The film (<div class="film" data-film>) -------------------------------
  // A poster with a big Play button; the video is only created (and only
  // downloaded) when it is pressed. Without JavaScript the button is a plain
  // link to the English film. Its words are part of the picture, so there is
  // a copy per language, and an upright copy for phones held upright: the page
  // swaps between them at the same moment if either changes mid-film.
  var film = $('filmPlayer'), filmVid = null, filmSrcs = null;
  var mqTall = window.matchMedia ? matchMedia('(max-width: 640px) and (orientation: portrait)') : { matches: false };
  function filmLang(){ return html.classList.contains('fil') ? 'fil' : 'en'; }
  function filmSrc(){
    var s = filmSrcs[filmLang()] || filmSrcs.en;
    return s[mqTall.matches ? 'tall' : 'wide'] || s.wide;
  }
  function filmFollow(){
    if (!filmVid || document.fullscreenElement || document.webkitFullscreenElement) return;
    var want = filmSrc();
    if (filmVid.getAttribute('src') === want) return;
    var t = filmVid.currentTime || 0, playing = !filmVid.paused && !filmVid.ended;
    filmVid.setAttribute('src', want);
    filmVid.addEventListener('loadedmetadata', function once(){
      filmVid.removeEventListener('loadedmetadata', once);
      try { filmVid.currentTime = Math.min(t, (filmVid.duration || t) - 0.05); } catch(e){}
      if (playing) { var p = filmVid.play(); if (p && p.catch) p.catch(function(){}); }
    });
  }
  if (film) {
    try { filmSrcs = JSON.parse(film.getAttribute('data-film')); } catch(e){ filmSrcs = null; }
    var facade = film.querySelector('.film-facade'), filmMsg = film.querySelector('.film-msg');
    if (filmSrcs && filmSrcs.en && facade) {
      facade.addEventListener('click', function(e){
        // Ctrl/Cmd/Shift-click or the middle button: let the browser open the file.
        if (e.ctrlKey || e.metaKey || e.shiftKey || e.altKey || e.button) return;
        e.preventDefault();
        if (filmMsg) filmMsg.hidden = true;
        var v = filmVid = document.createElement('video');
        var img = facade.querySelector('img');
        v.controls = true; v.playsInline = true; v.setAttribute('playsinline', '');
        v.preload = 'auto';
        if (img) v.poster = img.currentSrc || img.src;
        v.setAttribute('src', filmSrc());
        v.setAttribute('data-label-en', film.getAttribute('data-film-en'));
        v.setAttribute('data-label-fil', film.getAttribute('data-film-fil'));
        v.setAttribute('aria-label', film.getAttribute('data-film-' + filmLang()));
        // Cannot load (offline — the film is not part of the offline copy):
        // the poster and its Play button come back, with a note why.
        v.addEventListener('error', function(){
          if (v.parentNode) v.parentNode.removeChild(v);
          if (filmVid === v) filmVid = null;
          facade.hidden = false;
          film.classList.remove('is-open');
          if (filmMsg) filmMsg.hidden = false;
          facade.focus();
        });
        film.appendChild(v);
        facade.hidden = true;
        film.classList.add('is-open');
        v.focus();
        var p = v.play(); if (p && p.catch) p.catch(function(){});
      });
      if (mqTall.addEventListener) mqTall.addEventListener('change', filmFollow);
      else if (mqTall.addListener) mqTall.addListener(filmFollow);
      // No swapping in fullscreen (phones go fullscreen when turned while
      // playing); catch up when fullscreen ends.
      document.addEventListener('fullscreenchange', filmFollow);
      document.addEventListener('webkitfullscreenchange', filmFollow);
    }
  }

  // ---- Visit counts ----------------------------------------------------------
  // Each page view adds one to a few named tallies for today in the website's
  // own statistics database: a Firebase project of its own, separate from the
  // app's (website_admin/README.md), whose rules accept nothing but "one more"
  // and let no one but the team read. The tallies: the page, its language, the
  // kind of device, how the visitor arrived and which reading aids are on.
  // No cookies, no IDs, no IP addresses kept. The browser keeps one small note
  // ('flp-visit', never sent): the day it was last counted, so a visitor
  // counts once a day; that it was counted before; and the reading aids
  // already counted that day.
  // Nothing is counted when the browser asks not to be tracked (Do Not Track,
  // Global Privacy Control), on any copy of the site but the published one, or
  // on a device the team excluded with ?nocount=on (?nocount=off undoes it).
  // The feedback form on faq.html sends through the same database.
  var STATS = { host: 'jpaestedstu-prog.github.io', project: 'flashlearn-pwd-site', key: 'AIzaSyAGjW0oU_R0KZYQmyYujaGP1fghr9fXRNE' };
  var PAGE_KEYS = ['index', 'try', 'download', 'how_to_use', 'games', 'fsl_dictionary',
                   'teachers_guide', 'faq', 'awareness', 'about', 'privacy', 'gaze_control'];
  var EVENTS = ['apk_arm64', 'apk_arm32', 'apk_universal', 'webapp', 'try_card', 'try_game', 'film', 'demo'];
  var db = (function(){
    var base = 'https://firestore.googleapis.com/v1', project = STATS.project, key = STATS.key, test = null;
    if (/^(localhost|127\.0\.0\.1)$/.test(location.hostname)) {
      // A local copy counts only when a test points it at the Firestore emulator.
      try { test = JSON.parse(localStorage.getItem('flp-stats-test') || 'null'); } catch(e){}
      if (!test || !test.base || !test.project) return null;
      base = test.base; project = test.project; key = '';
    } else if (location.hostname !== STATS.host) return null;
    if (!project || !window.fetch) return null;
    var root = 'projects/' + project + '/databases/(default)/documents';
    return { url: base + '/' + root + ':commit' + (key ? '?key=' + encodeURIComponent(key) : ''), root: root, test: !!test };
  })();
  function stored(k){ try { return localStorage.getItem(k); } catch(e){ return undefined; } }

  var noCount = /[?&]nocount=(on|off)(&|$)/.exec(location.search);
  if (noCount) {
    try {
      if (noCount[1] === 'on') localStorage.setItem('flp-nocount', '1'); else localStorage.removeItem('flp-nocount');
    } catch(e){}
    // Out of the address bar, so the link is never shared with it.
    try {
      history.replaceState(null, '', location.pathname +
        location.search.replace(/([?&])nocount=(on|off)(&|$)/, '$1').replace(/[?&]$/, '') + location.hash);
    } catch(e){}
    var note = document.createElement('p');
    note.className = 'site-notice';
    note.setAttribute('role', 'status');
    note.innerHTML = noCount[1] === 'on'
      ? '<span class="en">This browser’s visits are no longer counted.</span><span class="fil">Hindi na binibilang ang mga pagbisita mula sa browser na ito.</span>'
      : '<span class="en">This browser’s visits are counted again.</span><span class="fil">Binibilang na ulit ang mga pagbisita mula sa browser na ito.</span>';
    document.body.appendChild(note);
    setTimeout(function(){ if (note.parentNode) note.parentNode.removeChild(note); }, 8000);
  }

  var dnt = navigator.doNotTrack === '1' || navigator.doNotTrack === 'yes' || window.doNotTrack === '1' ||
            navigator.globalPrivacyControl === true;
  var robot = !!navigator.webdriver ||
              /bot|crawl|spider|slurp|headless|lighthouse|pagespeed|prerender|preview|inspectiontool/i.test(navigator.userAgent || '');
  var counting = !!db && !dnt && stored('flp-nocount') !== '1' && (db.test || !robot);

  function today(){ return new Date(Date.now() + 8 * 36e5).toISOString().slice(0, 10); }   // Philippine day (UTC+8)
  function mq(q){ return !!(window.matchMedia && matchMedia(q).matches); }

  function commit(writes, keepalive){
    return fetch(db.url, {
      method: 'POST', body: JSON.stringify({ writes: writes }), keepalive: !!keepalive,
      headers: { 'Content-Type': 'application/json' }, credentials: 'omit', referrerPolicy: 'no-referrer'
    }).then(function(r){ if (!r.ok) throw new Error('HTTP ' + r.status); return r; });
  }
  // Adds one to each of `keys` in one document (created on its first write);
  // `fields` are plain values written alongside.
  function bump(path, keys, keepalive, fields){
    fields = fields || {};
    return commit([{
      update: { name: db.root + '/' + path, fields: fields },
      updateMask: { fieldPaths: Object.keys(fields) },
      updateTransforms: keys.map(function(k){ return { fieldPath: k, increment: { integerValue: '1' } }; })
    }], keepalive);
  }

  function pageKey(){
    var f = (location.pathname.split('/').pop() || 'index').replace(/\.html$/, '').replace(/-/g, '_');
    return PAGE_KEYS.indexOf(f) === -1 ? 'other' : f;
  }
  function deviceKind(){
    if (!mq('(pointer: coarse)')) return 'computer';
    return Math.min(screen.width || 0, screen.height || 0) < 600 ? 'phone' : 'tablet';
  }
  // How the visitor arrived. Counted when they come from outside the site,
  // not between its pages, not on a reload or Back.
  function source(){
    var nav = window.performance && performance.getEntriesByType && performance.getEntriesByType('navigation')[0];
    if (nav && (nav.type === 'reload' || nav.type === 'back_forward')) return null;
    if (/[?&](src|utm_source)=qr(&|$)/i.test(location.search)) return 'qr';
    var r = document.referrer || '', h = '';
    if (!r) return 'direct';
    try { h = new URL(r).hostname.toLowerCase(); } catch(e){}
    if (h === location.hostname) return null;
    if (/facebook|messenger|instagram|tiktok|youtube|youtu\.be|linkedin|reddit|pinterest|threads|viber|telegram|whatsapp|discord|twitter|(^|\.)(t\.co|x\.com|fb\.me|m\.me|fb\.com)$/.test(h)) return 'social';
    if (/(^|\.)(google|bing|yahoo|duckduckgo|ecosia|baidu|yandex|naver|qwant|startpage|brave)\.|^search\./.test(h)) return 'search';
    if (/(^|\.)github\.(com|io)$/.test(h)) return 'github';
    return 'other';
  }
  function aidsOn(){
    var on = [];
    if (prefs.font === 'lg' || prefs.font === 'xl') on.push('a_text');
    if (prefs.dys) on.push('a_dys');
    if (prefs.hc) on.push('a_hc');
    if (prefs.still) on.push('a_still');
    return on;
  }
  function deviceSettings(){
    var on = [];
    if (mq('(prefers-reduced-motion: reduce)')) on.push('o_motion');
    if (mq('(prefers-color-scheme: dark)')) on.push('o_dark');
    if (mq('(prefers-contrast: more)') || mq('(forced-colors: active)')) on.push('o_contrast');
    return on;
  }
  // 'flp-visit' = { d: day last counted, a: reading aids counted that day,
  // r: 1 once this browser has been counted before }. null when the browser
  // keeps no storage: such a visit still counts as a page view, never as a
  // visitor.
  function visit(){
    var s = stored('flp-visit');
    if (s === undefined) return null;
    try { return JSON.parse(s || '{}') || {}; } catch(e){ return {}; }
  }
  function keepVisit(v){ try { localStorage.setItem('flp-visit', JSON.stringify(v)); } catch(e){} }

  function countView(){
    var day = today(), keys = ['v', 'p_' + pageKey(), prefs.fil ? 'l_fil' : 'l_en'];
    var src = source(), seen = visit(), next = null;
    if (src) keys.push('s_' + src);
    if (seen && seen.d !== day) {   // this browser's first page today
      var aids = aidsOn();
      keys.push('u', 'd_' + deviceKind());
      if (!seen.r) keys.push('n');
      keys = keys.concat(aids, deviceSettings());
      next = { d: day, a: aids, r: 1 };
    }
    // Remembered only once counted: a visit that could not be sent is
    // counted on the next page instead.
    bump('daily/' + day, keys).then(function(){ if (next) keepVisit(next); }, function(){});
  }
  // A reading aid switched on after today's first page.
  function countAid(k){
    if (!counting) return;
    var seen = visit();
    if (!seen || seen.d !== today() || (seen.a || []).indexOf(k) !== -1) return;
    seen.a = (seen.a || []).concat(k);
    keepVisit(seen);
    bump('daily/' + seen.d, [k]).catch(function(){});
  }
  // Downloads, the web app, Try It and the videos: once per page view each,
  // except Word Match games, which count every time one starts.
  var counted = {};
  function countEvent(name, keepalive){
    if (!counting || EVENTS.indexOf(name) === -1 || (counted[name] && name !== 'try_game')) return;
    counted[name] = 1;
    bump('daily/' + today(), ['e_' + name], keepalive).catch(function(){});
  }
  function countSign(name){
    if (!counting || counted['w_' + name] || !/^[a-z0-9_]{1,40}$/.test(name)) return;
    counted['w_' + name] = 1;
    bump('signs/' + today(), ['w_' + name], false, { last: { stringValue: 'w_' + name } }).catch(function(){});
  }
  window.flpCount = countEvent;

  function linkCount(e){
    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (!a || (e.type === 'auxclick' && e.button !== 1)) return;
    var href = a.getAttribute('href') || '';
    var apk = /\/releases\/download\/[^\/]+\/[^\/]*-(arm64|arm32|universal)\.apk$/i.exec(href);
    // keepalive: the count still goes out when the link leaves the page.
    if (apk) countEvent('apk_' + apk[1].toLowerCase(), true);
    else if (/^(\.\/)?app\/?$/.test(href)) countEvent('webapp', true);
  }
  document.addEventListener('click', linkCount, true);
  document.addEventListener('auxclick', linkCount, true);
  // `play` does not bubble: listen while it travels down.
  document.addEventListener('play', function(e){
    var v = e.target;
    if (!v || v.tagName !== 'VIDEO' || v.classList.contains('loop')) return;   // not the Home preview
    var src = v.currentSrc || v.getAttribute('src') || '';
    var sign = /\/videos\/fsl\/([a-z0-9-]+)\.mp4/i.exec(src);
    if (sign) countSign(sign[1].toLowerCase().replace(/-/g, '_'));
    else if (/\/videos\/film-/.test(src)) countEvent('film');
    else if (/\/videos\/(app-demo|gaze-demo|fsl-welcome)\./.test(src)) countEvent('demo');
  }, true);

  if (counting) {
    // After the page itself has loaded, and only once it is actually seen
    // (not a tab opened in the background and never looked at, not a prerender).
    var startCount = function(){
      if (document.prerendering) {
        document.addEventListener('prerenderingchange', startCount, { once: true });
      } else if (document.visibilityState === 'hidden') {
        var onShow = function(){
          if (document.visibilityState !== 'visible') return;
          document.removeEventListener('visibilitychange', onShow);
          countView();
        };
        document.addEventListener('visibilitychange', onShow);
      } else countView();
    };
    if (document.readyState === 'complete') setTimeout(startCount, 300);
    else addEventListener('load', function(){ setTimeout(startCount, 300); });
  }

  // ---- "Send to the team" (faq.html) ------------------------------------------
  // One rating and/or message, written once and never readable from here.
  // Sending is something the visitor chose, so Do Not Track does not stop it.
  function randomId(){
    var abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', id = '';
    var bytes = new Uint8Array(20);
    window.crypto.getRandomValues(bytes);
    for (var i = 0; i < bytes.length; i++) id += abc[bytes[i] % abc.length];
    return id;
  }
  window.flpFeedback = {
    ready: !!(db && window.crypto && window.crypto.getRandomValues),
    // f = { type, role, message, rating (1-5, optional), device (optional) }
    send: function(f){
      var fields = {
        type: { stringValue: f.type }, role: { stringValue: f.role }, message: { stringValue: f.message },
        page: { stringValue: pageKey() }, lang: { stringValue: prefs.fil ? 'fil' : 'en' },
        status: { stringValue: 'new' }
      };
      if (f.rating) fields.rating = { integerValue: String(f.rating) };
      if (f.device) fields.device = { stringValue: f.device };
      return commit([{
        update: { name: db.root + '/feedback/' + randomId(), fields: fields },
        currentDocument: { exists: false },
        updateTransforms: [{ fieldPath: 'created', setToServerValue: 'REQUEST_TIME' }]
      }]);
    }
  };

  applyAll();
  fitNav();
  fitHead();
  measureHeader();

  // ---- Offline copy --------------------------------------------------------
  // Registered after the page has loaded: the install downloads the offline
  // copy of the site, which must not compete with the page's own images.
  if ('serviceWorker' in navigator && location.protocol.indexOf('http') === 0) {
    var registerSw = function(){ navigator.serviceWorker.register('sw.js').catch(function(){}); };
    if (document.readyState === 'complete') registerSw();
    else addEventListener('load', registerSw);
  }
})();
