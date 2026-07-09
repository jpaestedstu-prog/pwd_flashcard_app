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
  }
  btnFont.addEventListener('click', function(){
    prefs.font = prefs.font === 'lg' ? 'xl' : (prefs.font === 'xl' ? '' : 'lg');
    applyFont(); save();
  });
  btnDys.addEventListener('click', function(){ prefs.dys = !prefs.dys; applyDys(); save(); });
  btnHC.addEventListener('click', function(){ prefs.hc = !prefs.hc; applyHC(); save(); });
  btnLang.addEventListener('click', function(){ prefs.fil = !prefs.fil; applyLang(); save(); });
  applyFont(); applyDys(); applyHC(); applyLang();

  // PWA: register the service worker (http/https only)
  if ('serviceWorker' in navigator && location.protocol.indexOf('http') === 0) {
    navigator.serviceWorker.register('sw.js').catch(function(){});
  }
})();
