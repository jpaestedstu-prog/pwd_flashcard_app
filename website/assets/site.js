/* FlashLearn PWD site — behaviour shared by every page.

   * Preferences (text size, dyslexia font, high contrast, language) persist in
     localStorage 'flp-a11y', so a choice made on one page follows the visitor
     everywhere. A tiny script in each page's <head> applies them before the
     first paint; this file wires up the controls.
   * Header: the menu button (narrow screens, or whenever the links do not fit)
     and the accessibility panel.
   * Language: shows .en or .fil spans, and also swaps the things a span cannot
     hold — aria-labels (data-label-en/-fil), <option> text (data-en/-fil),
     placeholders (data-ph-en/-fil), the page title and video captions.
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
  }
  function applyAll(){
    applyFont();
    applySwitch('btnDys', prefs.dys, 'dys');
    applySwitch('btnHC', prefs.hc, 'hc');
    applyLang();
    layoutChanged();
  }

  each('[data-font]', function(b){
    b.addEventListener('click', function(){ prefs.font = b.getAttribute('data-font') || ''; save(); applyAll(); });
  });
  if ($('btnDys')) $('btnDys').addEventListener('click', function(){ prefs.dys = !prefs.dys; save(); applyAll(); });
  if ($('btnHC')) $('btnHC').addEventListener('click', function(){ prefs.hc = !prefs.hc; save(); applyAll(); });
  if ($('btnA11yReset')) $('btnA11yReset').addEventListener('click', function(){
    prefs.font = ''; prefs.dys = false; prefs.hc = false; save(); applyAll();
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
