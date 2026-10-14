/* The FlashLearn PWD film, drawn frame by frame by the website's own CSS.

   tools/site_video_build.py opens stage.html in headless Chrome and calls
     await FLP.setup(config)   -> {duration, holds}
     await FLP.frame(t)        -> the page now shows the film at t seconds
   then screenshots the page for every frame. Everything on screen is a pure
   function of t (no CSS animations, no timers), so frames can be drawn in any
   order and two renders of the same version are identical.

   config: {lang, shape: 'wide'|'tall', fps, copy, footage, assets}
   The words come from the build script (one source for the film and for the
   transcript on the page). The app footage is real: frames cut from the
   site's own demo recording (assets/videos/app-demo.mp4). */
(function(){
  'use strict';

  // ---------------------------------------------------------------- easing
  var E = {
    lin: function(t){ return t; },
    out: function(t){ return 1 - Math.pow(1 - t, 3); },
    out4: function(t){ return 1 - Math.pow(1 - t, 4); },
    in: function(t){ return t * t * t; },
    io: function(t){ return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; },
    sine: function(t){ return -(Math.cos(Math.PI * t) - 1) / 2; },
    back: function(t){ var c1 = 1.15, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); }
  };
  var TAU = Math.PI * 2;

  // ---------------------------------------------------------------- the timeline
  // Scenes overlap a little so one can leave while the next arrives.
  var T = {
    open:  { a: 0.0,  b: 4.4 },
    intro: { a: 4.1,  b: 9.3 },
    cards: { a: 9.1,  b: 14.7 },
    fsl:   { a: 14.5, b: 20.1 },
    games: { a: 19.9, b: 25.5 },
    talk:  { a: 25.3, b: 31.0 },
    learn: { a: 30.8, b: 37.6 },
    teach: { a: 37.4, b: 42.8 },
    end:   { a: 42.6, b: 50.0 }
  };
  var DURATION = 50.0;
  // A moment in each scene when everything has arrived and nothing has left:
  // the build script checks the layout there and draws its review stills.
  var HOLDS = [
    ['open', 2.9], ['intro', 7.6], ['cards', 12.6], ['fsl', 18.0], ['games', 23.6],
    ['talk', 29.2], ['learn', 35.6], ['teach', 41.2], ['end', 47.0]
  ];

  // ---------------------------------------------------------------- tracks
  // A track moves one element through keyframes [t, {props}, easing]. Props:
  // o (opacity), x, y (px), s (scale), r (deg), rx, ry (3D deg), clip (circle
  // reveal radius in %, -1 = none). A missing prop keeps its previous value.
  var DEF = { o: 1, x: 0, y: 0, s: 1, r: 0, rx: 0, ry: 0, clip: -1 };
  var tracks = [], hooks = [], footage = [];

  function track(el, keys, opts){
    var cur = {}, ks = [];
    for (var p in DEF) cur[p] = DEF[p];
    keys.forEach(function(k){
      var v = {};
      for (var q in cur) v[q] = (q in k[1]) ? k[1][q] : cur[q];
      cur = v;
      ks.push({ t: k[0], v: v, e: E[k[2] || 'out'] });
    });
    ks.sort(function(a, b){ return a.t - b.t; });
    var tr = { el: el, ks: ks, o: opts || {} };
    tracks.push(tr);
    return tr;
  }
  function valueAt(ks, t){
    if (t <= ks[0].t) return ks[0].v;
    var last = ks[ks.length - 1];
    if (t >= last.t) return last.v;
    for (var i = 0; i < ks.length - 1; i++) {
      var a = ks[i], b = ks[i + 1];
      if (t >= a.t && t < b.t) {
        var p = b.t > a.t ? b.e((t - a.t) / (b.t - a.t)) : 1, v = {};
        for (var k in a.v) v[k] = a.v[k] + (b.v[k] - a.v[k]) * p;
        return v;
      }
    }
    return last.v;
  }
  function apply(tr, t){
    var v = valueAt(tr.ks, t), el = tr.el, f = tr.o.float;
    var x = v.x, y = v.y, r = v.r, rx = v.rx, ry = v.ry, s = v.s;
    if (f) {
      x += (f.ax || 0) * Math.sin(TAU * t / f.p + f.ph);
      y += (f.ay || 0) * Math.sin(TAU * t / (f.p * 1.17) + f.ph * 1.7);
      r += (f.ar || 0) * Math.sin(TAU * t / (f.p * 1.31) + f.ph * 0.6);
      rx += (f.arx || 0) * Math.sin(TAU * t / (f.p * 1.21) + f.ph);
      ry += (f.ary || 0) * Math.sin(TAU * t / (f.p * 0.93) + f.ph * 1.3);
      s *= 1 + (f.as || 0) * Math.sin(TAU * t / (f.p * 0.77) + f.ph);
    }
    var o = Math.max(0, Math.min(1, v.o));
    el.style.opacity = o.toFixed(4);
    el.style.visibility = o < 0.002 ? 'hidden' : 'visible';
    var tf = 'translate3d(' + x.toFixed(2) + 'px,' + y.toFixed(2) + 'px,0)';
    if (rx || ry) tf += ' rotateX(' + rx.toFixed(3) + 'deg) rotateY(' + ry.toFixed(3) + 'deg)';
    if (r) tf += ' rotate(' + r.toFixed(3) + 'deg)';
    if (Math.abs(s - 1) > 1e-5) tf += ' scale(' + s.toFixed(5) + ')';
    el.style.transform = tf;
    if (v.clip >= 0 && v.clip < 99.9) {
      el.style.clipPath = 'circle(' + v.clip.toFixed(3) + '% at ' + (tr.o.cx || '50%') + ' ' + (tr.o.cy || '50%') + ')';
    } else el.style.clipPath = '';
  }

  // Ready-made entrances and exits. Every exit starts from the resting pose.
  var REST = { o: 1, x: 0, y: 0, s: 1, r: 0 };
  function rest(extra){ var v = {}, k; for (k in REST) v[k] = REST[k]; for (k in extra || {}) v[k] = extra[k]; return v; }
  var IN = {
    up:    function(t){ return [[t, { o: 0, y: 46 }], [t + .62, rest(), 'back']]; },
    rise:  function(t){ return [[t, { o: 0, y: 70, s: .96 }], [t + .8, rest(), 'out4']]; },
    pop:   function(t){ return [[t, { o: 0, s: .45, r: -8 }], [t + .62, rest(), 'back']]; },
    fade:  function(t){ return [[t, { o: 0 }], [t + .5, rest(), 'out']]; },
    left:  function(t){ return [[t, { o: 0, x: -70 }], [t + .7, rest(), 'out4']]; },
    right: function(t){ return [[t, { o: 0, x: 90 }], [t + .7, rest(), 'out4']]; }
  };
  var OUT = {
    up:     function(t){ return [[t, rest()], [t + .38, { o: 0, y: -40 }, 'in']]; },
    down:   function(t){ return [[t, rest()], [t + .38, { o: 0, y: 46 }, 'in']]; },
    shrink: function(t){ return [[t, rest()], [t + .36, { o: 0, s: .55 }, 'in']]; },
    fade:   function(t){ return [[t, rest()], [t + .34, { o: 0 }, 'in']]; }
  };
  function life(el, tIn, tOut, inK, outK, opts){
    var keys = IN[inK || 'up'](tIn);
    if (tOut != null) keys = keys.concat(OUT[outK || 'up'](tOut));
    return track(el, keys, opts);
  }

  // ---------------------------------------------------------------- DOM helpers
  var stage = document.getElementById('stage');
  var CFG = null, W = 0, H = 0, TALL = false;

  function el(tag, cls, html, parent){
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    (parent || stage).appendChild(e);
    return e;
  }
  function esc(s){ return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  // <acc>…</acc> in a pill = the Filipino word, in the site's accent pink.
  function rich(s){
    return esc(s).replace(/&lt;acc&gt;/g, '<span class="acc">').replace(/&lt;ok&gt;/g, '<span class="ok">')
      .replace(/&lt;\/(acc|ok)&gt;/g, '</span>');
  }
  // Words become spans (so they can arrive one after another); **…** words
  // get the site's purple-to-pink gradient.
  function words(s){
    var out = [], grad = false;
    String(s).split(/(\*\*)/).forEach(function(part){
      if (part === '**') { grad = !grad; return; }
      part.split(/(\s+)/).forEach(function(w){
        if (!w) return;
        if (/^\s+$/.test(w)) { out.push(' '); return; }
        out.push('<span class="w' + (grad ? ' g' : '') + '">' + esc(w) + '</span>');
      });
    });
    return out.join('');
  }
  function staggerWords(root, t0, step, outT){
    var ws = root.querySelectorAll('.w');
    for (var i = 0; i < ws.length; i++) life(ws[i], t0 + i * (step || .055), null, 'up');
    return ws.length;
  }
  function tile(tone, icon, parent){ return el('span', 'tile ico t-' + tone, esc(icon), parent); }
  function wordmark(parent, cls){
    return el('span', 'wordmark' + (cls ? ' ' + cls : ''), '<span class="w">FlashLearn</span> <b class="w">PWD</b>', parent);
  }

  // Deterministic "random": the same sparkles in every render.
  var seed = 7;
  function rnd(){ seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }

  // ---------------------------------------------------------------- footage
  function pad(n){ return ('000' + n).slice(-4); }
  function footageLayer(parent, name, t0){
    var f = CFG.footage[name];
    var lyr = el('div', 'lyr', null, parent);
    var img = el('img', '', null, lyr);
    img.alt = '';
    var rec = { name: name, img: img, dir: f.dir, count: f.count, t0: t0, until: Infinity, cur: -1, pending: null };
    footage.push(rec);
    return { lyr: lyr, rec: rec };
  }
  function showFootage(rec, t){
    if (t < rec.t0 - .2 || t > rec.until) return;
    var i = Math.floor((t - rec.t0) * CFG.fps + 1e-6);
    i = Math.max(0, Math.min(rec.count - 1, i));
    if (i === rec.cur) return;
    rec.cur = i;
    rec.img.src = rec.dir + '/' + pad(i + 1) + '.jpg';
    rec.pending = rec.img.decode().catch(function(){});
  }

  // ---------------------------------------------------------------- the film
  function build(){
    var C = CFG.copy, A = CFG.assets;
    seed = 7;

    // ---- background glows (the home page hero's, slowly drifting)
    var bg = el('div', 'bg');
    function glow(color, w, h, x, y, opts){
      var g = el('div', 'glow ' + color, null, bg);
      g.style.width = w + 'px'; g.style.height = h + 'px';
      g.style.left = (x - w / 2) + 'px'; g.style.top = (y - h / 2) + 'px';
      return g;
    }
    var base = TALL
      ? [['pink', 1300, 1100, 120, 260, 17], ['teal', 1200, 1100, 980, 520, 19], ['purple', 1500, 1300, 540, 1700, 23]]
      : [['pink', 1500, 1000, 230, 120, 17], ['teal', 1400, 1000, 1760, 260, 19], ['purple', 1800, 1100, 1000, 1080, 23]];
    base.forEach(function(b, i){
      var g = glow(b[0], b[1], b[2], b[3], b[4]);
      track(g, [[0, {}]], { float: { ax: 70, ay: 50, p: b[5], ph: i * 2.1, as: .04 } });
    });
    // One accent glow per scene, behind the device, in that scene's colour.
    var ax = TALL ? 540 : 1420, ay = TALL ? 1350 : 540;
    [['intro', 'purple'], ['cards', 'purple'], ['fsl', 'teal'], ['games', 'pink'], ['talk', 'orange'],
     ['learn', 'blue'], ['teach', 'green'], ['end', 'purple']].forEach(function(s, i){
      var sc = T[s[0]], g = glow(s[1], 1250, 1250, s[0] === 'learn' || s[0] === 'end' ? W / 2 : ax, s[0] === 'learn' ? H * .62 : ay);
      track(g, [[sc.a, { o: 0 }], [sc.a + .9, { o: 1 }, 'sine'], [sc.b - .3, { o: 1 }], [sc.b + .6, { o: 0 }, 'sine']],
        { float: { ax: 40, ay: 40, p: 13, ph: i, as: .05 } });
    });

    // ---- sparkles: small four-point stars drifting upwards
    var decor = el('div', 'decor');
    var STAR = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 0C13 7.4 16.6 11 24 12 16.6 13 13 16.6 12 24 11 16.6 7.4 13 0 12 7.4 11 11 7.4 12 0Z"/></svg>';
    var COLORS = ['#F7CE4E', '#F291B5', '#9C8CF2', '#71CEC5', '#79B8EC', '#F5A45F'];
    for (var i = 0; i < 16; i++) {
      var sz = 16 + rnd() * 26, sp = el('div', 'spark', STAR, decor);
      sp.style.width = sp.style.height = sz.toFixed(1) + 'px';
      sp.style.color = COLORS[i % COLORS.length];
      var x0 = rnd() * (W - 60) + 30, y0 = rnd() * H, speed = 9 + rnd() * 14, ph = rnd() * TAU, o = .45 + rnd() * .35;
      sp.style.left = x0.toFixed(1) + 'px';
      (function(sp, y0, speed, ph, o){
        hooks.push(function(t){
          var y = ((y0 - t * speed) % (H + 80) + H + 80) % (H + 80) - 40;
          var s = .82 + .22 * Math.sin(TAU * t / 3.7 + ph);
          sp.style.top = y.toFixed(1) + 'px';
          sp.style.transform = 'rotate(' + (t * 12 + ph * 40).toFixed(1) + 'deg) scale(' + s.toFixed(3) + ')';
          sp.style.opacity = o.toFixed(2);
        });
      })(sp, y0, speed, ph, o);
    }

    // ---- device (built early so the text can be measured against it)
    var devwrap = el('div', 'devwrap');
    var dev = el('div', 'dev', null, devwrap);
    var screen = el('div', 'screen', null, dev);
    var home = el('div', 'lyr', null, screen);
    var homeImg = el('img', '', null, home); homeImg.src = A.home; homeImg.alt = '';
    var L = {};
    [['cards', T.cards.a], ['fsl', T.fsl.a], ['games', T.games.a], ['talk', T.talk.a]].forEach(function(s){
      L[s[0]] = footageLayer(screen, s[0], s[1] + .05);
    });
    L.progress = footageLayer(screen, 'progress', T.teach.a + .1);
    el('div', 'glass', null, screen);
    var glint = el('div', 'glint', null, screen);

    // Screen changes: each new screen opens as a circle over the old one, and
    // a soft light sweeps across the glass.
    var seq = ['cards', 'fsl', 'games', 'talk'];
    seq.forEach(function(n, i){
      var a = T[n].a + .05, lyr = L[n].lyr;
      var keys = [[a, { clip: 0 }], [a + .7, { clip: 100 }, 'io']];
      var next = seq[i + 1];
      if (next) keys.push([T[next].a + .8, { o: 1 }], [T[next].a + .81, { o: 0 }, 'lin']);
      track(lyr, keys, { cx: '50%', cy: '58%' });
      L[n].rec.until = next ? T[next].a + .85 : T.talk.b + .6;
    });
    track(home, [[T.cards.a + .8, { o: 1 }], [T.cards.a + .81, { o: 0 }, 'lin']]);
    track(L.progress.lyr, [[T.teach.a - .2, { o: 0 }], [T.teach.a - .19, { o: 1 }, 'lin']]);
    var gw = TALL ? 520 : 560, gk = [[0, { o: 0, x: -gw * .5 }]];
    [T.cards.a, T.fsl.a, T.games.a, T.talk.a].forEach(function(a){
      gk.push([a + .15, { o: 0, x: -gw * .5 }], [a + .2, { o: 1, x: -gw * .5 }, 'lin'], [a + 1.05, { o: 1, x: gw * 1.15 }, 'io'], [a + 1.06, { o: 0, x: gw * 1.15 }, 'lin']);
    });
    track(glint, gk);

    // The device arrives with the intro, leaves for "every learner", comes
    // back for teachers and parents, and leaves before the end card.
    var away = TALL ? { o: 0, x: 0, y: 260, s: .94 } : { o: 0, x: 160, y: 0, s: .94 };
    track(devwrap, [
      [T.intro.a + .2, { o: 0, y: 160, s: .92 }], [T.intro.a + 1.1, rest(), 'out4'],
      [T.talk.b - .35, rest()], [T.talk.b + .3, away, 'in'],
      [T.teach.a, away], [T.teach.a + .85, rest(), 'out4'],
      [T.teach.b - .55, rest()], [T.teach.b - .1, { o: 0, y: 80, s: .94 }, 'in']
    ]);
    var baseRy = TALL ? 0 : -9, baseRx = TALL ? 5 : 2;
    track(dev, [
      [T.intro.a + .2, { ry: baseRy - 26, rx: baseRx + 8 }], [T.intro.a + 1.3, { ry: baseRy, rx: baseRx }, 'out4'],
      [T.teach.a, { ry: baseRy - 22, rx: baseRx }], [T.teach.a + 1, { ry: baseRy, rx: baseRx }, 'out4']
    ], { float: { arx: 1.6, ary: 3, ay: 10, p: 7.5, ph: .4 } });

    // ---- floating tiles around the device in the intro
    var fl = el('div', 'devwrap');  // same box as the device, without the 3D tilt
    var FT = TALL
      ? [['purple', '🃏', -104, 110], ['teal', '🤟', 500, 30], ['pink', '🎮', -96, 560], ['gold', '⭐', 512, 470], ['orange', '📚', 226, 770]]
      : [['purple', '🃏', -110, 150], ['teal', '🤟', 540, 50], ['pink', '🎮', -84, 640], ['gold', '⭐', 556, 520], ['orange', '📚', 250, 852]];
    FT.forEach(function(f, i){
      var w = el('div', 'ftile', null, fl);
      w.style.left = f[2] + 'px'; w.style.top = f[3] + 'px';
      tile(f[0], f[1], w);
      life(w, T.intro.a + .9 + i * .13, T.intro.b - .55 + i * .03, 'pop', 'shrink',
        { float: { ax: 6, ay: 12, ar: 4, p: 4.2 + i * .37, ph: i * 1.3 } });
    });

    // ---- feature pills beside the device
    function pill(html, x, y, tIn, tOut, parent){
      var p = el('div', 'pill', html, parent || fl);
      p.style.left = x + 'px'; p.style.top = y + 'px';
      life(p, tIn, tOut, 'pop', 'shrink', { float: { ay: 7, ar: 1.2, p: 3.9, ph: tIn } });
      return p;
    }
    var PP = TALL ? { cards: [-150, -30], fsl: [300, -40], games: [-160, 380], talk: [-150, -40], teach: [260, -40] }
                  : { cards: [-240, 110], fsl: [-250, 690], games: [-300, 420], talk: [-300, 150], teach: [330, 760] };
    var g = CFG.footage;
    pill(rich(C.cards.pill), PP.cards[0], PP.cards[1], T.cards.a + 1.4, T.cards.b - .5);
    pill(rich(C.fsl.pill), PP.fsl[0], PP.fsl[1], T.fsl.a + 1.6, T.fsl.b - .5);
    // The game pill appears the moment the learner's answer turns green.
    pill(rich(C.games.pill), PP.games[0], PP.games[1], T.games.a + .05 + g.games.mark, T.games.b - .5);
    pill(rich(C.talk.pill), PP.talk[0], PP.talk[1], T.talk.a + .05 + g.talk.mark, T.talk.b - .5);
    pill(rich(C.teach.pill), PP.teach[0], PP.teach[1], T.teach.a + 1.5, T.teach.b - .45);

    // ---- brand bug (after the opening, until the end card)
    // The opening's logo glides into the corner and becomes this one; the
    // name slides in beside it once the logo has landed.
    var bug = el('div', 'bug');
    var bugLogo = el('img', '', null, bug); bugLogo.src = A.logo; bugLogo.alt = '';
    var bugWord = wordmark(bug);
    track(bug, [[T.end.a - .1, rest()], [T.end.a + .3, { o: 0 }, 'in']]);
    track(bugLogo, [[4.33, { o: 0 }], [4.35, { o: 1 }, 'lin']]);
    track(bugWord, [[4.25, { o: 0, x: -28 }], [4.8, rest(), 'out4']]);

    // ---- opening
    var open = el('div', 'open');
    var mlogo = el('div', '', null, open); mlogo.style.transformOrigin = '0 0';
    var logo = el('img', 'logo mv', null, mlogo); logo.src = A.logo; logo.alt = '';
    var mword = el('div', '', null, open); mword.style.transformOrigin = '0 0';
    var bigWord = wordmark(mword);
    var tag = el('div', 'tag', null, open);
    life(logo, .25, null, 'pop');
    staggerWords(bigWord, .78, .12);
    var rows = C.tag.map(function(r){
      var row = el('span', 'row', null, tag);
      if (/^\*\*[^*]+\*\*$/.test(r)) { row.innerHTML = '<span class="g">' + esc(r.slice(2, -2)) + '</span>'; }
      else row.innerHTML = words(r);
      return row;
    });
    staggerWords(rows[0], 1.5, .06);
    life(rows[1], 2.0, null, 'up');
    track(tag, [[3.4, rest()], [3.78, { o: 0, y: -34 }, 'in']]);
    // A few stars burst gently from behind the logo (placed once the logo
    // has been laid out — see morph()).
    var burst = el('div', 'decor');
    stage.insertBefore(burst, open);   // behind the logo
    var stars = [];
    for (var b = 0; b < 9; b++) {
      var st = el('div', 'spark', STAR, burst), ang = (b / 9) * TAU + .3, dist = 210 + (b % 3) * 50, sz = 22 + (b % 3) * 8;
      st.style.width = st.style.height = sz + 'px';
      st.style.color = COLORS[b % COLORS.length];
      stars.push({ el: st, sz: sz });
      track(st, [[.45, { o: 0, s: .3 }], [.6, { o: .95 }, 'lin'],
                 [1.75, { o: .9, x: Math.cos(ang) * dist, y: Math.sin(ang) * dist * .8, s: 1, r: 90 }, 'out4'],
                 [2.4, { o: 0, s: .6, r: 120 }, 'in']]);
    }

    // ---- text blocks for the scenes beside the device
    function sideBlock(sc, data, opts){
      var blk = el('div', 'blk side');
      if (data.eyebrow) life(el('div', 'eyebrow2', esc(data.eyebrow), blk), T[sc].a + .4, null, 'up');
      if (data.label) {
        var lbl = el('div', 'lbl', null, blk);
        life(tile(data.tone, data.icon, lbl), T[sc].a + .3, null, 'pop');
        life(el('span', '', esc(data.label), lbl), T[sc].a + .42, null, 'left');
      }
      var title = el('div', 'title' + (opts && opts.xl ? ' xl' : ''), words(data.title), blk);
      var n = staggerWords(title, T[sc].a + .55, .06);
      if (data.line) life(el('div', 'line', esc(data.line), blk), T[sc].a + .75 + n * .06, null, 'up');
      track(blk, OUT.up(T[sc].b - .5));
      return blk;
    }
    sideBlock('intro', C.intro, { xl: true });
    ['cards', 'fsl', 'games', 'talk', 'teach'].forEach(function(n){ sideBlock(n, C[n]); });

    // ---- every learner
    var lhead = el('div', 'lhead');
    var lt = el('div', 'title xl', words(C.learn.title), lhead);
    var ln = staggerWords(lt, T.learn.a + .45, .06);
    life(el('div', 'line', esc(C.learn.line), lhead), T.learn.a + .65 + ln * .06, null, 'up');
    track(lhead, OUT.up(T.learn.b - .55));
    var lcards = el('div', 'lcards');
    C.learn.items.forEach(function(it, i){
      var card = el('div', 'lcard', null, lcards);
      tile(it.tone, it.icon, card);
      var txt = el('div', '', null, card);
      el('div', 'ln', esc(it.name), txt);
      el('div', 'ls', esc(it.sub), txt);
      life(card, T.learn.a + 1.05 + i * .14, T.learn.b - .62 + i * .04, TALL ? 'right' : 'rise', 'down');
    });

    // ---- end card
    var band = el('div', 'band');
    var main = el('div', 'main', null, band);
    var brandrow = el('div', 'brandrow', null, main);
    var bl = el('img', '', null, brandrow); bl.src = A.logo; bl.alt = '';
    wordmark(brandrow);
    life(brandrow, T.end.a + .6, null, 'up');
    var bt = el('div', 'bt', words(C.end.title), main);
    var en = staggerWords(bt, T.end.a + .75, .07);
    var chips = el('div', 'tchips', null, main);
    C.end.chips.forEach(function(c, i){ life(el('span', 'tchip', esc(c), chips), T.end.a + 1.2 + en * .07 + i * .1, null, 'pop'); });
    var dl = el('div', 'dl', esc(C.end.button), main);
    life(dl, T.end.a + 1.75 + en * .07, null, 'pop');
    life(el('div', 'sub', esc(C.end.sub), main), T.end.a + 1.95 + en * .07, null, 'up');
    var qr = el('div', 'qrcard', null, band);
    var qi = el('img', '', null, qr); qi.src = A.qr; qi.alt = '';
    el('div', 'qc', esc(C.end.qr), qr);
    el('div', 'url', esc(C.end.url).replace(/\//g, '/<wbr>'), qr);   // breaks after the slash, never mid-word
    life(qr, T.end.a + 1.35, null, 'pop');
    track(band, IN.rise(T.end.a + .2));

    // ---- the logo and name glide from the opening into the corner
    return { mlogo: mlogo, logo: logo, mword: mword, bigWord: bigWord, bugLogo: bugLogo, bugWord: bugWord, stars: stars };
  }

  // Once fonts are in, measure where the opening's logo and name must land.
  function morph(m){
    var a = m.logo.getBoundingClientRect(), b = m.bugLogo.getBoundingClientRect();
    var sr = stage.getBoundingClientRect(), cx = a.left + a.width / 2 - sr.left, cy = a.top + a.height / 2 - sr.top;
    m.stars.forEach(function(s){
      s.el.style.left = (cx - s.sz / 2) + 'px';
      s.el.style.top = (cy - s.sz / 2) + 'px';
    });
    track(m.mlogo, [[3.55, rest()], [4.35, { x: b.left - a.left, y: b.top - a.top, s: b.width / a.width }, 'io'],
                    [4.36, { o: 0 }, 'lin']]);
    track(m.mword, [[3.45, rest()], [3.85, { o: 0, y: -30, s: .97 }, 'in']]);
  }

  // ---------------------------------------------------------------- poster
  // The still shown before the film plays: no words in either language, so
  // one picture serves English and Filipino visitors.
  function buildPoster(){
    var A = CFG.assets;
    tracks = []; hooks = []; footage = [];
    stage.innerHTML = '';
    var keep = T;
    build();
    // Drop everything except the background, sparkles, device and tiles.
    ['.open', '.bug', '.blk', '.lhead', '.lcards', '.band', '.pill'].forEach(function(sel){
      Array.prototype.forEach.call(stage.querySelectorAll(sel), function(n){ n.remove(); });
    });
    tracks = tracks.filter(function(tr){ return document.contains(tr.el); });
    var pm = el('div', 'poster-mark');
    var li = el('img', '', null, pm); li.src = A.logo; li.alt = '';
    wordmark(pm);
    return keep.intro.a + 2.6;   // the intro, with everything arrived
  }

  // ---------------------------------------------------------------- checks
  function opacityOf(n){
    var o = 1;
    for (; n && n !== document.documentElement; n = n.parentElement) {
      var cs = getComputedStyle(n);
      if (cs.visibility === 'hidden' || cs.display === 'none') return 0;
      o *= parseFloat(cs.opacity);
    }
    return o;
  }
  function inter(a, b){ return !(a.right <= b.left || b.right <= a.left || a.bottom <= b.top || b.bottom <= a.top); }
  function desc(n){ return (n.className || n.tagName) + ' “' + (n.textContent || '').trim().slice(0, 40) + '”'; }
  function textRect(n){
    // The box of the text itself, not of a stretched flex child.
    var r = document.createRange(); r.selectNodeContents(n);
    return r.getBoundingClientRect();
  }

  window.FLP = {
    setup: async function(cfg){
      CFG = cfg;
      TALL = cfg.shape === 'tall';
      W = TALL ? 1080 : 1920; H = TALL ? 1920 : 1080;
      stage.className = 'stage ' + (TALL ? 'tall' : 'wide');
      document.documentElement.lang = cfg.lang === 'fil' ? 'fil' : 'en';
      await Promise.all(['600 80px Fredoka', '500 80px Fredoka', '400 40px Nunito', '700 40px Nunito', '800 40px Nunito']
        .map(function(f){ return document.fonts.load(f); }));
      await document.fonts.ready;
      tracks = []; hooks = []; footage = []; stage.innerHTML = '';
      var posterAt = null;
      if (cfg.poster) posterAt = buildPoster();
      else morph(build());
      await Promise.all(Array.prototype.map.call(stage.querySelectorAll('img[src]'), function(i){
        return i.decode().catch(function(){ throw new Error('image failed: ' + i.src); });
      }));
      return { duration: DURATION, holds: HOLDS, scenes: T, posterAt: posterAt, footage: footage.length };
    },
    frame: async function(t){
      for (var i = 0; i < tracks.length; i++) apply(tracks[i], t);
      for (i = 0; i < hooks.length; i++) hooks[i](t);
      var waits = [];
      footage.forEach(function(f){ showFootage(f, t); if (f.pending) { waits.push(f.pending); f.pending = null; } });
      await Promise.all(waits);
      await new Promise(function(res){ requestAnimationFrame(function(){ requestAnimationFrame(res); }); });
      return true;
    },
    // Layout problems at the current frame: text off the frame or into the
    // device, a word too wide for its line, pills over the words.
    check: function(){
      var out = [], M = 24, sr = stage.getBoundingClientRect();
      var texts = stage.querySelectorAll('.title,.line,.lbl,.eyebrow2,.pill,.ln,.ls,.bt,.tchip,.dl,.sub,.qc,.url,.tag,.wordmark');
      // Shown = itself visible and, if its words or tile arrive one by one,
      // at least one of them has arrived.
      function shown(n){
        if (opacityOf(n) <= .6) return false;
        var kids = n.querySelectorAll('.w,.tile,.lbl > span');
        if (!kids.length) return true;
        for (var i = 0; i < kids.length; i++) if (opacityOf(kids[i]) > .6) return true;
        return false;
      }
      var vis = [];
      Array.prototype.forEach.call(texts, function(n){ if (shown(n)) vis.push(n); });
      var devR = null, dv = stage.querySelector('.dev');
      if (dv && opacityOf(dv) > .6) devR = dv.getBoundingClientRect();
      vis.forEach(function(n){
        var r = n.getBoundingClientRect();
        if (r.left < sr.left + M || r.top < sr.top + M || r.right > sr.right - M || r.bottom > sr.bottom - M) out.push('off the frame: ' + desc(n));
        if (n.scrollWidth > n.clientWidth + 2) out.push('too wide for its box: ' + desc(n));
        if (devR && !TALL && /title|line|lbl|eyebrow2/.test(n.className) && n.closest('.blk')) {
          if (inter(textRect(n), devR)) out.push('runs into the device: ' + desc(n));
        }
        if (devR && TALL && n.closest('.blk') && textRect(n).bottom > devR.top - 10) out.push('runs into the device: ' + desc(n));
      });
      var pills = vis.filter(function(n){ return n.classList.contains('pill'); });
      pills.forEach(function(p){
        var pr = p.getBoundingClientRect();
        vis.forEach(function(n){
          if (n.closest('.blk') && !n.classList.contains('pill') && inter(pr, textRect(n))) out.push('pill covers words: ' + desc(p) + ' / ' + desc(n));
        });
      });
      Array.prototype.forEach.call(stage.querySelectorAll('.band .main,.qrcard,.lcard'), function(n){
        if (opacityOf(n) < .6) return;
        var r = n.getBoundingClientRect(), pr = n.parentElement.getBoundingClientRect();
        if (n.scrollHeight > n.clientHeight + 2) out.push('content taller than its box: ' + desc(n));
        if (r.bottom > sr.bottom - M) out.push('box below the frame: ' + desc(n));
      });
      return out;
    }
  };
})();
