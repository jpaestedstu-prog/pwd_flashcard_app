/* FlashLearn TV Cast — TV-side renderer.
 * ES5 only: var, function declarations, XMLHttpRequest. No fetch,
 * no Promises, no arrow functions, no template literals — so this
 * runs on every smart-TV browser from ~2014 forward (Tizen 2.x,
 * webOS 1.x, Fire OS Silk gen 1+, old Chromecasts, etc.).
 *
 * The phone is the source of truth. We poll /api/state every
 * POLL_MS milliseconds, compare the `rev` field, and only repaint
 * when revision changes.
 */
(function () {
  var POLL_MS = 1500;
  var stage = document.getElementById('stage');
  var pill = document.getElementById('footer-pill');
  var hint = document.getElementById('sound-hint');
  var lastRev = -1;
  var lastVideoUrl = null;
  var failCount = 0;          // consecutive failed /api/state polls
  var reconnecting = false;   // currently showing the "connecting" overlay
  var FAIL_THRESHOLD = 2;     // ~3s of failures before the overlay appears

  // ─── TV-side speech (Web Speech API) ───────────────────
  // The phone routes Flashcards/Stories audio here (ttsOnTv). We speak the
  // English then Filipino text the TV already has. Some browsers need one
  // user gesture before audio is allowed — handled by primeTts() + a hint.
  var lastSpokenKey = null;
  var ttsUnlocked = false;
  var lastState = null;
  var lastReplayNonce = null;   // last seen state.ttsReplay.n (explicit replay)

  function ttsSupported() {
    return typeof window !== 'undefined' && 'speechSynthesis' in window;
  }

  function showSoundHint() {
    if (hint) {
      hint.innerHTML = '🔊 Press OK on the remote (or tap) to turn on sound';
      hint.className = 'sound-hint';
    }
  }

  function hideSoundHint() {
    if (hint) hint.className = 'sound-hint hidden';
  }

  function onUtteranceStart() {
    // Audio actually started — no gesture was needed, drop the hint.
    ttsUnlocked = true;
    hideSoundHint();
  }

  function speakSequence(en, fil) {
    if (!ttsSupported()) return;
    try {
      window.speechSynthesis.cancel();
      if (en) {
        var u1 = new SpeechSynthesisUtterance(en);
        u1.lang = 'en-US';
        u1.volume = 1.0; // max — the Web Speech API caps volume at 1.0
        u1.onstart = onUtteranceStart;
        window.speechSynthesis.speak(u1);
      }
      if (fil) {
        var u2 = new SpeechSynthesisUtterance(fil);
        u2.lang = 'fil-PH';
        u2.volume = 1.0; // max — the Web Speech API caps volume at 1.0
        u2.onstart = onUtteranceStart;
        window.speechSynthesis.speak(u2);
      }
    } catch (e) {
      // Web Speech unavailable / blocked — phone fallback covers it.
    }
  }

  // Speaks the current Flashcard word / Story page when audio is routed to the
  // TV. Cancels speech (and clears the hint) when it isn't.
  function maybeSpeak(state) {
    if (!ttsSupported()) return;
    if (!state.ttsOnTv) {
      window.speechSynthesis.cancel();
      lastSpokenKey = null;
      hideSoundHint();
      return;
    }
    var en = '', fil = '', key = '';
    if (state.mode === 'flashcards' && state.slide) {
      en = state.slide.wordEn || '';
      fil = state.slide.wordFil || '';
      key = 'f:' + state.slide.index;
    } else if (state.mode === 'story' && state.story) {
      en = state.story.textEn || '';
      fil = state.story.textFil || '';
      key = 's:' + state.story.pageIndex;
    } else {
      // FSL / progress / idle never speak on the TV.
      window.speechSynthesis.cancel();
      lastSpokenKey = null;
      return;
    }
    if (key === lastSpokenKey) return;
    lastSpokenKey = key;
    speakSequence(en, fil);
    if (!ttsUnlocked) showSoundHint();
  }

  // Explicit "Replay" from the phone: re-speak the CURRENT item whenever the
  // replay nonce changes, even though the slide/page key hasn't. `lang` picks
  // English ('en'), Filipino ('fil'), or both. We seed lastReplayNonce on the
  // first sighting so a reconnecting TV doesn't replay stale taps.
  function maybeReplay(state) {
    var rp = state.ttsReplay;
    if (!rp || typeof rp.n !== 'number') return;
    if (lastReplayNonce === null) { lastReplayNonce = rp.n; return; }
    if (rp.n === lastReplayNonce) return;
    lastReplayNonce = rp.n;
    if (!ttsSupported()) return;
    var en = '', fil = '';
    if (state.mode === 'flashcards' && state.slide) {
      en = state.slide.wordEn || '';
      fil = state.slide.wordFil || '';
    } else if (state.mode === 'story' && state.story) {
      en = state.story.textEn || '';
      fil = state.story.textFil || '';
    } else {
      return; // nothing speakable in this mode
    }
    if (rp.lang === 'en') fil = '';
    else if (rp.lang === 'fil') en = '';
    speakSequence(en, fil);
    if (!ttsUnlocked) showSoundHint();
  }

  // First user interaction on the TV unlocks audio for browsers that gate
  // speech behind a gesture, then re-speaks the current content.
  function primeTts() {
    if (ttsUnlocked) return;
    ttsUnlocked = true;
    hideSoundHint();
    if (ttsSupported()) {
      try {
        var u = new SpeechSynthesisUtterance(' ');
        u.volume = 0;
        window.speechSynthesis.speak(u);
      } catch (e) {}
    }
    if (lastState) {
      lastSpokenKey = null;
      maybeSpeak(lastState);
    }
  }

  function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function setStage(html) {
    if (stage.innerHTML !== html) {
      stage.innerHTML = html;
    }
  }

  function renderIdle() {
    setStage(
      '<div class="splash">' +
      '<div class="splash-emoji">📺</div>' +
      '<h1>FlashLearn TV</h1>' +
      '<p>Pick what to cast on the teacher\'s phone.</p>' +
      '</div>'
    );
    lastVideoUrl = null;
  }

  // "The teacher is out" — a served state (the phone is still reachable, it just
  // told us to show this). Different from the reconnecting overlay below, which
  // we show on our own when the phone stops answering.
  function renderAway() {
    if (ttsSupported()) {
      try { window.speechSynthesis.cancel(); } catch (e) {}
    }
    lastSpokenKey = null; // re-speak the current item when the teacher returns
    setStage(
      '<div class="splash away">' +
      '<div class="splash-emoji">☕</div>' +
      '<h1>The teacher is out</h1>' +
      '<p>Back soon — please wait.</p>' +
      '</div>'
    );
    lastVideoUrl = null;
  }

  // Shown by the poll loop when /api/state stops answering — the phone dropped
  // Wi-Fi, switched networks, or closed the cast. The TV keeps polling; the
  // moment the phone is reachable again we repaint the real content.
  function showReconnecting() {
    if (reconnecting) return;
    if (ttsSupported()) {
      try { window.speechSynthesis.cancel(); } catch (e) {}
    }
    setStage(
      '<div class="splash reconnect">' +
      '<div class="splash-emoji pulse">📡</div>' +
      '<h1>Oops, the teacher is connecting…</h1>' +
      '<p>Make sure the teacher\'s device is on the same Wi-Fi.</p>' +
      '</div>'
    );
    if (pill) { pill.className = 'footer-pill hidden'; pill.innerHTML = ''; }
    if (hint) hint.className = 'sound-hint hidden';
    var hb = document.getElementById('hands-banner');
    if (hb) { hb.className = 'hands-banner hidden'; hb.innerHTML = ''; }
    var cb = document.getElementById('cast-brand');
    if (cb) cb.style.display = 'none';
    var cd = document.getElementById('cast-decoration');
    if (cd) cd.style.display = 'none';
    lastVideoUrl = null;
    reconnecting = true;
  }

  // A flashcard styled like the in-app "Cards" section: a light card surface
  // with a category accent strip, a category badge (emoji + label), the word's
  // emoji in a tinted tile, the English + Filipino words, and the example.
  // Category colours come from the payload and are applied inline because the
  // TV CSS avoids var() for old browsers. The high-contrast theme overrides
  // these inline colours with !important rules in style.css.
  //
  // The motion (3D flip-in, staggered reveal, emoji pop, glossy shine sweep,
  // floating corner blobs) mirrors the animated in-app flip card and lives
  // entirely in style.css — so old TV browsers, reduced-motion, and the Calm
  // template all degrade to a clean static card. setStage() replaces the DOM
  // on every revision change, which is what re-triggers the entrance each time
  // a new card is pushed from the phone.
  function renderFlashcards(state) {
    var slide = state.slide;
    if (!slide) {
      renderIdle();
      return;
    }
    var accent = slide.catColorDark || '#1565c0'; // deep — strips, fil, badge text
    var tint = slide.catColor || '#dbeafe';        // pastel — badge + pic tile

    var badge = '';
    if (slide.catLabel) {
      badge =
        '<div class="fcard-badge" style="background:' + tint + ';color:' + accent + '">' +
        '<span class="fcard-badge-ico">' + escapeHtml(slide.catEmoji || '') + '</span>' +
        '<span>' + escapeHtml(slide.catLabel) + '</span>' +
        '</div>';
    }

    var example = '';
    if (slide.example) {
      example =
        '<div class="fcard-example">' +
        '<span class="quote" style="color:' + accent + '">“</span>' +
        escapeHtml(slide.example) +
        '<span class="quote" style="color:' + accent + '">”</span>' +
        '</div>';
    }

    // Decorative tinted corner blobs (behind the content) + the glossy shine
    // overlay (above it). The content sits in its own .fcard-body layer so the
    // three z-index layers always sort correctly. Colours are inline; the
    // motion is CSS.
    setStage(
      '<div class="slide">' +
      '<div class="fcard">' +
      '<div class="fcard-accent" style="background:' + accent + '"></div>' +
      '<span class="fcard-blob fcard-blob-tr" style="background:' + tint + '"></span>' +
      '<span class="fcard-blob fcard-blob-bl" style="background:' + tint + '"></span>' +
      '<div class="fcard-body">' +
      badge +
      '<div class="fcard-pic" style="background:' + tint + '">' +
      '<span class="fcard-pic-emoji">' + escapeHtml(slide.emoji) + '</span>' +
      '</div>' +
      '<h1 class="fcard-word-en">' + escapeHtml(slide.wordEn) + '</h1>' +
      '<div class="fcard-word-fil" style="color:' + accent + '">' +
      escapeHtml(slide.wordFil) + '</div>' +
      example +
      '</div>' +
      '<div class="fcard-shine"></div>' +
      '</div>' +
      '</div>'
    );
    lastVideoUrl = null;
  }

  function renderFslVideo(state) {
    var slide = state.slide;
    var video = state.video;
    if (!slide) {
      renderIdle();
      return;
    }
    if (!video || !video.available || !video.url) {
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="fsl-missing">' +
        '<span class="emoji">' + escapeHtml(slide.emoji) + '</span>' +
        'No FSL video available for "' + escapeHtml(slide.wordEn) + '"' +
        '</div>' +
        '</div>'
      );
      lastVideoUrl = null;
      return;
    }
    // Only rebuild the <video> element when the URL changes, otherwise the
    // browser would restart playback every state poll. `loop` repeats the
    // short sign clip; `muted` keeps autoplay allowed on every TV browser.
    if (video.url !== lastVideoUrl) {
      var caption =
        '<div class="fsl-caption">' +
        escapeHtml(slide.wordEn) +
        '<span class="fil">' + escapeHtml(slide.wordFil) + '</span>' +
        '</div>';
      // Muted by default so the sign autoplays on every TV browser. The phone
      // can opt-in to the clip's own audio track (`videoSound`) for FSL clips
      // that include a voiceover — at the cost of autoplay on some browsers.
      var mutedAttr = state.videoSound ? '' : 'muted ';
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="fsl-video-box">' +
        '<video autoplay ' + mutedAttr + 'loop playsinline webkit-playsinline ' +
        'controls preload="auto" src="' + escapeHtml(video.url) + '"></video>' +
        '<div class="fsl-loading" id="fsl-loading">' +
        '<div class="spinner"></div>' +
        '<div class="fsl-loading-text">Loading sign…</div>' +
        '</div>' +
        '</div>' +
        caption +
        '</div>'
      );
      lastVideoUrl = video.url;
      attachVideoHandlers(slide);
    }
  }

  // Wires loading-overlay + error-retry handlers onto the freshly-rendered
  // <video>. On error (e.g. the clip is still downloading on the phone, so
  // /api/video 404s) we drop lastVideoUrl so the next poll rebuilds and
  // retries instead of leaving a dead element on screen.
  function attachVideoHandlers(slide) {
    var vids = stage.getElementsByTagName('video');
    if (!vids || !vids.length) return;
    var v = vids[0];
    var loading = document.getElementById('fsl-loading');
    function hideLoading() {
      if (loading) loading.className = 'fsl-loading hidden';
    }
    v.onplaying = hideLoading;
    v.oncanplay = hideLoading;
    v.onerror = function () {
      // Force a full rebuild + retry on the next poll. We must clear lastRev
      // too — otherwise the poll loop short-circuits because the revision
      // hasn't changed, and the retry would never fire.
      lastVideoUrl = null;
      lastRev = -1;
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="fsl-missing">' +
        '<span class="emoji">' + escapeHtml(slide.emoji) + '</span>' +
        'Loading sign for "' + escapeHtml(slide.wordEn) + '"…' +
        '</div>' +
        '</div>'
      );
    };
  }

  function renderStory(state) {
    var story = state.story;
    if (!story) {
      renderIdle();
      return;
    }
    setStage(
      '<div class="story">' +
      '<div class="story-emoji">' + escapeHtml(story.emoji) + '</div>' +
      '<h1 class="story-title">' + escapeHtml(story.titleEn) + '</h1>' +
      '<p class="story-text-en">' + escapeHtml(story.textEn) + '</p>' +
      (story.textFil
        ? '<p class="story-text-fil">' + escapeHtml(story.textFil) + '</p>'
        : '') +
      '</div>'
    );
    lastVideoUrl = null;
  }

  function renderProgress(state) {
    var rows = state.progress || [];
    var html = '<div class="board"><h2>Class Leaderboard</h2>';
    if (rows.length === 0) {
      html += '<div class="empty">No student data yet.</div>';
    } else {
      for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        var rankCls = 'rank';
        if (r.rank === 1) rankCls += ' top1';
        else if (r.rank === 2) rankCls += ' top2';
        else if (r.rank === 3) rankCls += ' top3';
        html +=
          '<div class="row">' +
          '<div class="' + rankCls + '">#' + r.rank + '</div>' +
          '<div class="name">' + escapeHtml(r.name) + '</div>' +
          '<div class="stat"><span class="v">' + r.words + '</span>words</div>' +
          '<div class="stat"><span class="v">' + r.streak + '</span>day streak</div>' +
          '<div class="stat"><span class="v">' + r.stars + '</span>⭐</div>' +
          '</div>';
      }
    }
    html += '</div>';
    setStage(html);
    lastVideoUrl = null;
  }

  // Interactive live activity: the educator pushes a question; learners answer
  // on their own devices. The TV shows the question, how many have answered,
  // and the live scoreboard. The correct answer is intentionally never sent.
  function renderLive(state) {
    var live = state.live || {};
    var a = live.activity;
    var html = '<div class="live">';
    if (!a) {
      html +=
        '<div class="live-wait">' +
        '<div class="splash-emoji">🎮</div>' +
        '<h1>Live Activity</h1>' +
        '<p>Get ready for the next question!</p>' +
        '</div>';
    } else {
      if (a.questionNumber && a.totalQuestions) {
        html +=
          '<div class="live-qnum">Question ' + a.questionNumber + ' / ' +
          a.totalQuestions + '</div>';
      }
      if (a.type === 'pictureChoice' || a.type === 'fslSign') {
        html += '<div class="live-emoji">' + escapeHtml(a.emoji || '❓') + '</div>';
        html +=
          '<div class="live-sub">' +
          (a.type === 'fslSign'
            ? 'Watch the sign — pick the word on your device'
            : 'Which word matches the picture?') +
          '</div>';
      } else if (a.prompt) {
        html += '<h1 class="live-prompt">' + escapeHtml(a.prompt) + '</h1>';
      }
      if (a.isTrueFalse) {
        html +=
          '<div class="live-options">' +
          '<div class="live-opt">✔ True</div>' +
          '<div class="live-opt">✘ False</div>' +
          '</div>';
      } else if (a.options && a.options.length) {
        html += '<div class="live-options">';
        for (var i = 0; i < a.options.length; i++) {
          html +=
            '<div class="live-opt">' +
            String.fromCharCode(65 + i) + '. ' + escapeHtml(a.options[i]) +
            '</div>';
        }
        html += '</div>';
      }
      html +=
        '<div class="live-responded">' + (live.responded || 0) + ' answered</div>';
    }

    var board = live.board || [];
    if (board.length) {
      html += '<div class="live-board"><h2>Scoreboard</h2>';
      for (var j = 0; j < board.length && j < 6; j++) {
        var r = board[j];
        html +=
          '<div class="live-row">' +
          '<span class="rk">#' + (j + 1) + '</span>' +
          '<span class="nm">' + escapeHtml(r.name) + '</span>' +
          '<span class="sc">' + r.correct + '✔ ' + r.stars + '⭐</span>' +
          '</div>';
      }
      html += '</div>';
    }
    html += '</div>';
    setStage(html);
    lastVideoUrl = null;
  }

  // Raised-hands banner — overlaid in EVERY mode so a hand raised during any
  // activity (flashcards, story, live, …) is immediately visible. Driven by
  // state.live.hands (an array of learner names). The element is created
  // lazily so index.html needs no change.
  function renderHandsBanner(state) {
    var el = document.getElementById('hands-banner');
    if (!el) {
      el = document.createElement('div');
      el.id = 'hands-banner';
      document.body.appendChild(el);
    }
    var live = state.live || {};
    var hands = live.hands || [];
    if (!hands.length) {
      el.className = 'hands-banner hidden';
      el.innerHTML = '';
      return;
    }
    var inner = '<span class="hand-title">✋ Raised hands</span>';
    for (var i = 0; i < hands.length; i++) {
      inner += '<span class="hand-chip">' + escapeHtml(hands[i]) + '</span>';
    }
    el.innerHTML = inner;
    el.className = 'hands-banner';
  }

  function updateFooter(state) {
    var bits = [];
    if (state.slide && typeof state.slide.index === 'number') {
      bits.push((state.slide.index + 1) + ' / ' + state.slide.total);
    } else if (state.story && typeof state.story.pageIndex === 'number') {
      bits.push('Page ' + (state.story.pageIndex + 1) + ' / ' + state.story.totalPages);
    }
    if (state.isPaused) {
      bits.push('<span class="paused">⏸ paused</span>');
    }
    if (bits.length === 0) {
      pill.className = 'footer-pill hidden';
      pill.innerHTML = '';
    } else {
      pill.className = 'footer-pill';
      pill.innerHTML = bits.join('  ');
    }
  }

  function applyTheme(state) {
    var theme = state.theme || 'dark';
    var cls = 'theme-' + theme;
    // Mirror the app's reduced-motion accessibility setting so entrance
    // animations are dropped for motion-sensitive viewers.
    if (state.reducedMotion) cls += ' reduce-motion';
    if (document.body.className !== cls) {
      document.body.className = cls;
    }
  }

  // Optional "Show on TV" branding pill. textContent keeps it injection-safe.
  function renderBranding(state) {
    var el = document.getElementById('cast-brand');
    var title = state.title || '';
    if (!el) {
      el = document.createElement('div');
      el.id = 'cast-brand';
      document.body.appendChild(el);
    }
    if (!title) {
      el.style.display = 'none';
      el.textContent = '';
      return;
    }
    el.style.display = 'block';
    el.textContent = title;
  }

  // Seasonal template accents — recolour the festive frame + show the event's
  // decoration emoji, using values from the payload (the CSS avoids var() so
  // dynamic colours are applied inline here).
  function renderSeasonal(state) {
    var deco = document.getElementById('cast-decoration');
    var stage = document.getElementById('stage');
    var seasonal = (state.theme === 'seasonal') ? (state.seasonal || {}) : null;
    if (!seasonal) {
      if (deco) deco.style.display = 'none';
      if (stage) stage.style.borderColor = '';
      return;
    }
    var accent = seasonal.accent || '#8e24aa';
    if (stage) stage.style.borderColor = accent;
    if (!deco) {
      deco = document.createElement('div');
      deco.id = 'cast-decoration';
      document.body.appendChild(deco);
    }
    if (seasonal.emoji) {
      deco.style.display = 'block';
      deco.textContent = seasonal.emoji;
    } else {
      deco.style.display = 'none';
    }
  }

  function render(state) {
    lastState = state;
    applyTheme(state);
    // The raised-hands banner, branding, and seasonal accents show in every
    // mode (including "away") so the TV always feels designed and a learner
    // asking for help is always visible.
    renderHandsBanner(state);
    renderBranding(state);
    renderSeasonal(state);
    // Away overrides whatever mode is selected; the content stays selected on
    // the phone so it resumes the instant the teacher returns.
    if (state.away) {
      renderAway();
      updateFooter({}); // empty → hides the footer pill
      return;
    }
    switch (state.mode) {
      case 'flashcards': renderFlashcards(state); break;
      case 'fslVideo':   renderFslVideo(state);   break;
      case 'story':      renderStory(state);      break;
      case 'progress':   renderProgress(state);   break;
      case 'live':       renderLive(state);       break;
      default:           renderIdle();
    }
    updateFooter(state);
    maybeSpeak(state);
    maybeReplay(state);
  }

  function poll() {
    var xhr = new XMLHttpRequest();
    // Guard so a single poll counts at most once — onreadystatechange and
    // onerror/ontimeout can both fire for the same failed request.
    var done = false;

    function fail() {
      if (done) return;
      done = true;
      failCount++;
      if (failCount >= FAIL_THRESHOLD) showReconnecting();
    }

    function ok(state) {
      if (done) return;
      done = true;
      failCount = 0;
      // Coming back from a disconnect: the revision may be unchanged, so force a
      // repaint to replace the "connecting" overlay with the live content.
      if (reconnecting) {
        reconnecting = false;
        lastRev = -1;
      }
      if (state.rev === lastRev) return;
      lastRev = state.rev;
      render(state);
    }

    // Tell the phone whether this TV can synthesize speech and whether audio
    // has been unlocked yet, so it can explain why the TV is/isn't talking.
    var ttsFlag = ttsSupported() ? '1' : '0';
    var unlockedFlag = ttsUnlocked ? '1' : '0';
    xhr.open(
      'GET',
      '/api/state?tts=' + ttsFlag + '&unlocked=' + unlockedFlag,
      true
    );
    xhr.timeout = 4000;
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      if (xhr.status !== 200) { fail(); return; }
      var state;
      try {
        state = JSON.parse(xhr.responseText);
      } catch (e) {
        fail();
        return;
      }
      ok(state);
    };
    xhr.onerror = fail;
    xhr.ontimeout = fail;
    xhr.send();
  }

  // Unlock TV audio on the first interaction (remote OK / tap / click).
  if (document.addEventListener) {
    document.addEventListener('keydown', primeTts, false);
    document.addEventListener('click', primeTts, false);
    document.addEventListener('touchstart', primeTts, false);
  }

  // First paint + poll loop
  poll();
  setInterval(poll, POLL_MS);
})();
