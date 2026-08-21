/* FlashLearn PWD site — shared accessibility + language toggles.
   Used by every page; preferences persist in localStorage ('flp-a11y') so a
   choice made on one page follows the visitor across the whole site.
   Pages set their bilingual <title> via data-title-en / data-title-fil on <html>. */
(function(){
  var html = document.documentElement;
  var prefs = {};
  try { prefs = JSON.parse(localStorage.getItem('flp-a11y') || '{}'); } catch(e){}
  function save(){ try{ localStorage.setItem('flp-a11y', JSON.stringify(prefs)); }catch(e){} }

  var btnFont = document.getElementById('btnFont');
  var btnDys  = document.getElementById('btnDys');
  var btnHC   = document.getElementById('btnHC');
  var btnLang = document.getElementById('btnLang');
  if (!btnFont || !btnDys || !btnHC || !btnLang) return;

  // font size cycles: normal -> lg -> xl -> normal
  function applyFont(){
    html.classList.toggle('fs-lg', prefs.font === 'lg');
    html.classList.toggle('fs-xl', prefs.font === 'xl');
    btnFont.setAttribute('aria-pressed', prefs.font ? 'true' : 'false');
    btnFont.textContent = prefs.font === 'lg' ? 'A++' : (prefs.font === 'xl' ? 'A' : 'A+');
    btnFont.title = prefs.font === 'xl' ? 'Reset text size' : 'Larger text';
  }
  function applyDys(){
    html.classList.toggle('dys', !!prefs.dys);
    btnDys.setAttribute('aria-pressed', prefs.dys ? 'true' : 'false');
  }
  function applyHC(){
    html.classList.toggle('hc', !!prefs.hc);
    btnHC.setAttribute('aria-pressed', prefs.hc ? 'true' : 'false');
  }
  function applyLang(){
    var fil = !!prefs.fil;
    html.classList.toggle('fil', fil);
    html.setAttribute('lang', fil ? 'fil' : 'en');
    btnLang.setAttribute('aria-pressed', fil ? 'true' : 'false');
    btnLang.textContent = fil ? 'EN' : 'FIL';
    btnLang.title = fil ? 'Switch to English' : 'Lumipat sa Filipino';
    var title = html.getAttribute(fil ? 'data-title-fil' : 'data-title-en');
    if (title) document.title = title;
    // <option> text can't hold the usual .en/.fil spans, so it carries both
    // languages in data-en / data-fil and is swapped here instead.
    document.querySelectorAll('option[data-en]').forEach(function(o){
      o.textContent = (fil ? o.getAttribute('data-fil') : o.getAttribute('data-en')) || o.textContent;
    });
    // Video captions follow the site language (only tracks the visitor hasn't
    // manually disabled with the CC button stay in sync).
    document.querySelectorAll('video').forEach(function(v){
      var tracks = v.textTracks || [];
      var anyShowing = false;
      for (var i = 0; i < tracks.length; i++) anyShowing = anyShowing || tracks[i].mode === 'showing';
      for (var j = 0; j < tracks.length; j++) {
        var want = tracks[j].language === (fil ? 'fil' : 'en');
        if (anyShowing || tracks[j].mode !== 'disabled') tracks[j].mode = want ? 'showing' : 'hidden';
      }
    });
  }
  btnFont.addEventListener('click', function(){
    prefs.font = prefs.font === 'lg' ? 'xl' : (prefs.font === 'xl' ? '' : 'lg');
    applyFont(); save();
  });
  btnDys.addEventListener('click', function(){ prefs.dys = !prefs.dys; applyDys(); save(); });
  btnHC.addEventListener('click', function(){ prefs.hc = !prefs.hc; applyHC(); save(); });
  btnLang.addEventListener('click', function(){ prefs.fil = !prefs.fil; applyLang(); save(); });
  applyFont(); applyDys(); applyHC(); applyLang();

  // "You are here" for in-page nav links, so the header marks the current
  // section the same way sub-pages mark the current page. Sub-page links
  // (href without a leading #) already carry a static aria-current.
  // Position-based, not intersection-ratio based: sections here differ in
  // height by 5x, and the tallest one never wins on ratio alone.
  var spy = [].slice.call(document.querySelectorAll('nav.links a[href^="#"]'))
    .map(function(a){ return { a: a, el: document.querySelector(a.getAttribute('href')) }; })
    .filter(function(x){ return x.el; });
  if (spy.length) {
    var ticking = false;
    var markSpy = function(){
      ticking = false;
      // The line a section counts as "reached" is the same one the browser
      // parks it on (html{scroll-padding-top}), never less than the header.
      var header = document.querySelector('header');
      var headerH = header ? header.getBoundingClientRect().height : 0;
      var pad = parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop) || 0;
      var line = Math.max(pad, headerH) + 4;
      var current = null;
      spy.forEach(function(x){
        if (x.el.getBoundingClientRect().top <= line) current = x.a;
      });
      // Nothing reached yet (still in the hero) leaves every link unmarked.
      spy.forEach(function(x){
        if (x.a === current) x.a.setAttribute('aria-current', 'true');
        else x.a.removeAttribute('aria-current');
      });
    };
    var onScroll = function(){
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(markSpy);
    };
    addEventListener('scroll', onScroll, { passive: true });
    addEventListener('resize', onScroll);
    markSpy();
  }

  // PWA: register the service worker (http/https only)
  if ('serviceWorker' in navigator && location.protocol.indexOf('http') === 0) {
    navigator.serviceWorker.register('sw.js').catch(function(){});
  }
})();
