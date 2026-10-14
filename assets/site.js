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
    b.addEventListener('click', function(){ prefs.font = b.getAttribute('data-font') || ''; save(); applyAll(); });
  });
  if ($('btnDys')) $('btnDys').addEventListener('click', function(){ prefs.dys = !prefs.dys; save(); applyAll(); });
  if ($('btnHC')) $('btnHC').addEventListener('click', function(){ prefs.hc = !prefs.hc; save(); applyAll(); });
  // "Reduce motion" is an explicit, site-wide answer: it also overrides a
  // Play/Pause pressed earlier on the app preview.
  if ($('btnStill')) $('btnStill').addEventListener('click', function(){ prefs.still = !prefs.still; loopChoice = null; save(); applyAll(); });
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
    if (!nav) return;
    // Measure the inline layout (menu closed, not compact), all in one task so
    // nothing is painted in between.
    var wasOpen = nav.classList.contains('open');
    nav.classList.remove('open');
    html.classList.remove('nav-compact');
    var ul = nav.querySelector('ul');
    var inline = getComputedStyle(nav).display !== 'none';   // false below the CSS breakpoint
    if (inline && ul && ul.scrollWidth > ul.clientWidth + 1) html.classList.add('nav-compact');
    var compact = !inline || html.classList.contains('nav-compact');
    if (wasOpen && compact) nav.classList.add('open');
    else if (wasOpen && menuBtn) menuBtn.setAttribute('aria-expanded', 'false');
  }
  function measureHeader(){
    if (header) html.style.setProperty('--header-h', Math.round(header.getBoundingClientRect().height) + 'px');
  }
  var raf = 0;
  function layoutChanged(){
    if (raf) return;
    raf = requestAnimationFrame(function(){ raf = 0; fitNav(); measureHeader(); });
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

  applyAll();
  fitNav();
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
