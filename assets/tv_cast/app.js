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
  var lastFlashcardKey = null; // identifies the flashcard currently painted, so
                               // a Flip press animates instead of rebuilding.
  var lastStoryKey = null;     // identifies the story page currently painted with
                               // its flip picture, so a "Tap to Flip Animation"
                               // press animates instead of rebuilding the DOM.
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
    } else if (state.mode === 'story' && state.story && !state.storyFsl) {
      en = state.story.textEn || '';
      fil = state.story.textFil || '';
      key = 's:' + state.story.pageIndex;
    } else {
      // FSL / progress / idle — and a story page showing its sign-language clip
      // (storyFsl) — never speak on the TV.
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
    } else if (state.mode === 'story' && state.story && !state.storyFsl) {
      en = state.story.textEn || '';
      fil = state.story.textFil || '';
    } else {
      return; // nothing speakable in this mode (or the FSL clip is showing)
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

  // Flashcards entry point. Normally paints the card (renderFlashcardCard); when
  // the teacher activates "Show Me" and the current card has an action clip, the
  // clip takes over the whole stage (renderActionClip) instead.
  function renderFlashcards(state) {
    var slide = state.slide;
    if (!slide) {
      renderIdle();
      return;
    }
    if (state.showMe && slide.clip && slide.clip.available && slide.clip.url) {
      renderActionClip(state);
      return;
    }
    renderFlashcardCard(state);
  }

  // A flashcard styled like the in-app "Cards" section: a light card surface
  // with a category accent strip, a category badge (emoji + label), the word's
  // picture in a tinted tile, the English + Filipino words, and the example.
  // Category colours come from the payload and are applied inline because the
  // TV CSS avoids var() for old browsers. The high-contrast theme overrides
  // these inline colours with !important rules in style.css.
  //
  // The picture tile shows the word's emoji and — when the card has a real
  // photo / animated GIF (slide.photo) AND the "Tap Only" control is on
  // (state.tapOnly) — is a two-faced 3D flip card (emoji front, photo back).
  // Which face shows is driven by the phone's "Flip" button (state.flipped), so
  // the flip works on ANY receiver, including TVs you can't touch. There is no
  // auto-flip and no TV-side tap. When only the flip flag changes for the SAME
  // card we toggle the class on the existing tile (so the 3D flip animates);
  // a new card does a full rebuild (and always starts on the emoji).
  //
  // The rest of the motion (3D flip-in, staggered reveal, emoji pop, glossy
  // shine sweep, floating corner blobs) mirrors the animated in-app flip card
  // and lives entirely in style.css — so old TV browsers, reduced-motion, and
  // the Calm template all degrade to a clean static card.
  function renderFlashcardCard(state) {
    var slide = state.slide;
    var photo = slide.photo;
    var tapEnabled = state.tapOnly !== false; // default on for older payloads
    var hasPhoto = !!(photo && photo.available && photo.url) && tapEnabled;
    var flipped = hasPhoto && !!state.flipped;
    // Identifies the card + whether it has the flip structure, so a Flip press
    // (same key) animates via a class toggle instead of rebuilding the DOM.
    var key = (slide.catLabel || '') + '#' + slide.index + (hasPhoto ? '+p' : '');

    // Same card re-rendering (typically the teacher pressed Flip): just sync the
    // is-flipped class on the existing tile so the CSS transition animates. A
    // full rebuild would drop the animation. Guarded on the flip element still
    // being present (it isn't after a mode/clip switch → falls through).
    if (key === lastFlashcardKey && hasPhoto) {
      var flipEl = document.getElementById('fcard-flip');
      var backEl = document.getElementById('fcard-photo-back');
      if (flipEl && backEl) {
        if (flipped && !backEl.style.backgroundImage) {
          backEl.style.backgroundImage = 'url("' + photo.url + '")';
        }
        flipEl.className = flipped ? 'fcard-flip is-flipped' : 'fcard-flip';
        return;
      }
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

    // Picture tile. With a real photo/GIF AND the photo-flip feature on we build
    // a two-faced 3D flip card (emoji front, photo back); otherwise we keep the
    // plain emoji tile the TV has always shown. Either way the emoji is the face
    // that paints first, so a missing/slow/broken photo — or the control
    // switched off — just shows the emoji.
    var emojiSpan = '<span class="fcard-pic-emoji">' + escapeHtml(slide.emoji) + '</span>';
    var picInner;
    if (hasPhoto) {
      picInner =
        '<div class="fcard-flip" id="fcard-flip">' +
        '<div class="fcard-face fcard-face-front">' + emojiSpan + '</div>' +
        '<div class="fcard-face fcard-face-back" id="fcard-photo-back"></div>' +
        '</div>';
    } else {
      picInner = emojiSpan;
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
      '<div class="fcard-pic" id="fcard-pic" style="background:' + tint + '">' +
      picInner +
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
    lastFlashcardKey = key;
    if (hasPhoto) applyFlashcardPhoto(photo.url, flipped);
  }

  // Preloads the card's photo / GIF onto the flip's back face so the reveal is
  // instant when the teacher presses Flip, and applies the initial face. The
  // photo is a CSS background (background-size: cover) so it scales cleanly back
  // to old Android WebKit and animated GIFs animate too. A failed load just
  // leaves the emoji. `flipped` is normally false on a fresh card (the flag is
  // reset on every card change), so this paints the emoji first with no motion;
  // the animated flip happens later via the same-card class toggle above.
  function applyFlashcardPhoto(url, flipped) {
    var flip = document.getElementById('fcard-flip');
    var back = document.getElementById('fcard-photo-back');
    if (!flip || !back) return;

    var img = new Image();
    img.onload = function () {
      if (back.parentNode) back.style.backgroundImage = 'url("' + url + '")';
    };
    img.onerror = function () { /* keep the emoji face */ };
    img.src = url;

    if (flipped) {
      back.style.backgroundImage = 'url("' + url + '")';
      flip.className = 'fcard-flip is-flipped';
    }
  }

  // Plays the current card's "Show Me" action clip across the whole stage: a
  // GIF as a looping <img>, an MP4 as a muted autoplaying looping <video>
  // (Range-streamed by the server, with the same loading overlay + retry as the
  // FSL video). The phone toggles this on/off and it auto-clears when the card
  // changes. Reuses lastVideoUrl so an unrelated state poll doesn't restart it.
  function renderActionClip(state) {
    var slide = state.slide;
    var clip = slide && slide.clip;
    if (!slide || !clip || !clip.available || !clip.url) {
      renderFlashcardCard(state);
      return;
    }
    if (clip.url === lastVideoUrl) return; // already showing this clip

    var caption =
      '<div class="fsl-caption">' +
      escapeHtml(slide.wordEn) +
      '<span class="fil">' + escapeHtml(slide.wordFil) + '</span>' +
      '</div>';

    if (clip.isGif) {
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="clip-gif-box">' +
        '<img class="clip-gif" src="' + escapeHtml(clip.url) + '" alt="">' +
        '</div>' +
        caption +
        '</div>'
      );
      lastVideoUrl = clip.url;
      return;
    }

    // Muted by default so it autoplays on every browser; the phone can opt in
    // to the clip's own audio track via `videoSound`.
    var mutedAttr = state.videoSound ? '' : 'muted ';
    setStage(
      '<div class="fsl-wrap">' +
      '<div class="fsl-video-box">' +
      '<video autoplay ' + mutedAttr + 'loop playsinline webkit-playsinline ' +
      'controls preload="auto" src="' + escapeHtml(clip.url) + '"></video>' +
      '<div class="fsl-loading" id="fsl-loading">' +
      '<div class="spinner"></div>' +
      '<div class="fsl-loading-text">Loading…</div>' +
      '</div>' +
      '</div>' +
      caption +
      '</div>'
    );
    lastVideoUrl = clip.url;
    attachVideoHandlers(slide);
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
        'Loading "' + escapeHtml(slide.wordEn) + '"…' +
        '</div>' +
        '</div>'
      );
    };
  }

  // Story entry point. Normally paints the story page (text); when the teacher
  // activates "Watch in FSL" and the current page has a sign-language clip, the
  // clip takes over the whole stage (renderStoryFsl) instead — mirroring the
  // flashcard "Show Me" path.
  function renderStory(state) {
    var story = state.story;
    if (!story) {
      renderIdle();
      return;
    }
    var sv = state.storyVideo;
    if (state.storyFsl && sv && sv.available && sv.url) {
      renderStoryFsl(state);
      return;
    }
    // Pages that ship a cartoon ⇄ real-life picture pair drop the emoji and show
    // BOTH pictures as a tap-to-flip card — the TV analog of the in-app Stories
    // illustration. Pages / stories without a pair keep the classic emoji page.
    var img = story.image;
    if (img && img.available && img.cartoonUrl && img.realUrl) {
      renderStoryImage(state);
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
    lastStoryKey = null; // next flip-picture page rebuilds from scratch
  }

  // A story page showing the cartoon ⇄ real-life flip picture instead of the
  // emoji — the TV counterpart of the in-app Stories "tap to flip" illustration.
  // Both faces are pictures resolved + cached by the server (/api/story-image):
  // the cartoon is the front face (shown first) and the real photo the back.
  // Which face shows is driven by the phone's "Tap to Flip Animation (Cartoon ↔
  // Picture)" button (state.storyImageFlipped), so the flip works on ANY
  // receiver — including TVs you can't touch — and the 3D flip animates when it
  // changes. A new page does a full rebuild (and always starts on the cartoon);
  // when only the flip flag changes for the SAME page we toggle the class on the
  // existing card so the rotation animates instead of snapping. The flip motion
  // lives in style.css, so old TV browsers / reduced-motion / Calm degrade to a
  // clean cross-fade or static picture.
  function renderStoryImage(state) {
    var story = state.story;
    var img = story.image;
    var flipped = !!state.storyImageFlipped;
    // Identifies the page (story + page index) so a flip press (same key)
    // animates via a class toggle instead of rebuilding the DOM.
    var key = (story.titleEn || '') + '#' + story.pageIndex;

    // Same page re-rendering (typically the teacher pressed the flip button):
    // just sync the is-flipped class so the CSS transition animates. A full
    // rebuild would drop the animation. Guarded on the flip element still being
    // present (it isn't after an FSL / mode switch → falls through to a rebuild).
    if (key === lastStoryKey) {
      var flipEl = document.getElementById('story-flip');
      var backEl = document.getElementById('story-real');
      if (flipEl && backEl) {
        if (flipped && !backEl.style.backgroundImage) {
          backEl.style.backgroundImage = 'url("' + img.realUrl + '")';
        }
        flipEl.className = flipped ? 'story-flip is-flipped' : 'story-flip';
        return;
      }
    }

    setStage(
      '<div class="story">' +
      '<div class="story-pic">' +
      '<div class="story-flip" id="story-flip">' +
      '<div class="story-flip-face story-flip-front" id="story-cartoon"></div>' +
      '<div class="story-flip-face story-flip-back" id="story-real"></div>' +
      '</div>' +
      '</div>' +
      '<h1 class="story-title">' + escapeHtml(story.titleEn) + '</h1>' +
      '<p class="story-text-en">' + escapeHtml(story.textEn) + '</p>' +
      (story.textFil
        ? '<p class="story-text-fil">' + escapeHtml(story.textFil) + '</p>'
        : '') +
      '</div>'
    );
    lastVideoUrl = null;
    lastStoryKey = key;
    applyStoryImages(img.cartoonUrl, img.realUrl, flipped);
  }

  // Loads both faces of the story flip picture: the cartoon paints onto the
  // front face and the real photo onto the back, so the reveal is instant when
  // the teacher flips. Both are CSS backgrounds (background-size: cover) so they
  // scale cleanly back to old Android WebKit and animated GIFs animate too. A
  // failed load just leaves that face's neutral tint; the page text stays
  // readable. `flipped` is normally false on a fresh page (the flag resets on
  // every page change), so this paints the cartoon first with no motion; the
  // animated flip happens later via the same-page class toggle above.
  function applyStoryImages(cartoonUrl, realUrl, flipped) {
    var front = document.getElementById('story-cartoon');
    var back = document.getElementById('story-real');
    if (!front || !back) return;

    var c = new Image();
    c.onload = function () {
      if (front.parentNode) {
        front.style.backgroundImage = 'url("' + cartoonUrl + '")';
      }
    };
    c.onerror = function () { /* keep the neutral tint */ };
    c.src = cartoonUrl;

    var r = new Image();
    r.onload = function () {
      if (back.parentNode) back.style.backgroundImage = 'url("' + realUrl + '")';
    };
    r.onerror = function () { /* keep the neutral tint */ };
    r.src = realUrl;

    var flip = document.getElementById('story-flip');
    if (flip) flip.className = flipped ? 'story-flip is-flipped' : 'story-flip';
  }

  // Plays the current story page's FSL sign-language video across the whole
  // stage: a muted autoplaying looping <video> (Range-streamed by the server,
  // with the same loading overlay + retry as the flashcard FSL video). The
  // phone toggles this on/off and it auto-clears when the page / story changes.
  // Reuses lastVideoUrl so an unrelated state poll doesn't restart playback. The
  // caption shows the page text (English + Filipino) under the signing.
  function renderStoryFsl(state) {
    var story = state.story;
    var video = state.storyVideo;
    if (!story || !video || !video.available || !video.url) {
      // No clip after all — fall back to the text page (renderStory won't
      // re-enter here because storyVideo is absent / unavailable).
      renderStory(state);
      return;
    }
    if (video.url === lastVideoUrl) return; // already showing this clip

    var caption =
      '<div class="fsl-caption">' +
      escapeHtml(story.textEn) +
      (story.textFil
        ? '<span class="fil">' + escapeHtml(story.textFil) + '</span>'
        : '') +
      '</div>';

    // Muted by default so the sign autoplays on every TV browser. The phone can
    // opt-in to the clip's own audio track (`videoSound`) for clips that include
    // a voiceover — at the cost of autoplay on some browsers.
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
    attachStoryVideoHandlers(story);
  }

  // Wires the loading-overlay + error-retry handlers onto the story FSL <video>
  // (the story-page counterpart of attachVideoHandlers). On error (e.g. the clip
  // is still downloading on the phone, so /api/story-video 404s) we drop
  // lastVideoUrl + lastRev so the next poll rebuilds and retries.
  function attachStoryVideoHandlers(story) {
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
      lastVideoUrl = null;
      lastRev = -1;
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="fsl-missing">' +
        '<span class="emoji">' + escapeHtml(story.emoji) + '</span>' +
        'Loading sign for "' + escapeHtml(story.titleEn) + '"…' +
        '</div>' +
        '</div>'
      );
    };
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
    // Honour the phone's "Fullscreen on TV" toggle (default on for older
    // payloads that don't send the flag). Browsers that allow it fill now;
    // stricter ones fill on the next remote OK / tap (see onActivation).
    applyFullscreen(state.fullscreen !== false);
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

  // ─── Fullscreen + auto-fit ("fill any TV, edge to edge") ───────
  // The teacher controls this from the phone (the "Fullscreen on TV" toggle),
  // exactly like every other cast control: the phone sends a `fullscreen` flag
  // in /api/state and the TV enters/exits browser fullscreen to match — no
  // button is drawn on the TV itself. Two moving parts:
  //   1. Fullscreen API (every vendor prefix, back to 2013 WebKit) drops the
  //      browser chrome. Lenient casting devices (most Smart-TV browsers, Fire
  //      TV Silk, WebView dongles) honour a programmatic request immediately;
  //      stricter ones (Chrome on Chromecast / Google TV) only enter from a user
  //      gesture, so we retry on the first remote OK / tap. Exiting never needs a
  //      gesture, so turning the toggle off always works. TVs with no Fullscreen
  //      API are already edge-to-edge — we just no-op there.
  //   2. fitViewport() pins the stage to the real visible pixels on every size
  //      change, so the layout re-fits instantly after the resolution switches
  //      (1080p⇄4K), fullscreen toggles, or the window rotates/resizes. This is
  //      the "automatic screen resizing to fit any TV" and runs regardless of
  //      the fullscreen flag.

  var wantFs = true;       // phone's desired fullscreen state (default fill)
  var lastFsWant = null;   // last applied desire — avoids re-spamming requests

  // Cross-browser current-fullscreen element (null when windowed). Includes the
  // older capital-S WebKit names used by some smart-TV browsers.
  function fsElement() {
    return document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.webkitCurrentFullScreenElement ||
      document.mozFullScreenElement ||
      document.msFullscreenElement ||
      null;
  }

  function fsRequestFn(el) {
    return el.requestFullscreen ||
      el.webkitRequestFullscreen ||
      el.webkitRequestFullScreen ||
      el.mozRequestFullScreen ||
      el.msRequestFullscreen ||
      null;
  }

  function fsExitFn() {
    return document.exitFullscreen ||
      document.webkitExitFullscreen ||
      document.webkitCancelFullScreen ||
      document.mozCancelFullScreen ||
      document.msExitFullscreen ||
      null;
  }

  function enterFullscreen() {
    var el = document.documentElement;
    var fn = fsRequestFn(el);
    if (!fn) return;
    try {
      // Newer engines return a Promise that rejects when no gesture is active;
      // swallow it so a blocked attempt stays silent (a later gesture retries).
      var r = fn.call(el);
      if (r && typeof r.catch === 'function') r.catch(function () {});
    } catch (e) {}
  }

  function exitFullscreen() {
    var fn = fsExitFn();
    if (!fn) return;
    try { fn.call(document); } catch (e) {}
  }

  // Drives the TV to match the phone's toggle. Only acts on a change of desire
  // (so a slide change doesn't re-request every poll); the gesture handler
  // covers stricter browsers that ignored the programmatic enter.
  function applyFullscreen(want) {
    wantFs = want;
    if (want === lastFsWant) return;
    lastFsWant = want;
    if (want && !fsElement()) enterFullscreen();
    else if (!want && fsElement()) exitFullscreen();
  }

  // Pins the stage to the actual visible pixels. The stylesheet's vw/vh already
  // scale the content; this is the belt-and-suspenders fit for TV browsers that
  // miscompute 100vh (some webOS / Tizen builds) and the instant re-fit after a
  // resolution change or a fullscreen enter/exit, so the frame always reaches
  // every edge.
  function fitViewport() {
    var w = window.innerWidth || document.documentElement.clientWidth || 0;
    var h = window.innerHeight || document.documentElement.clientHeight || 0;
    if (!w || !h) return;
    var s = document.getElementById('stage');
    if (s) {
      s.style.width = w + 'px';
      s.style.height = h + 'px';
    }
  }

  // Re-fit whenever fullscreen flips, under every vendor event name so old
  // smart-TV WebKit fires too.
  function bindFsChange() {
    if (!document.addEventListener) return;
    var names = [
      'fullscreenchange', 'webkitfullscreenchange',
      'mozfullscreenchange', 'MSFullscreenChange'
    ];
    for (var i = 0; i < names.length; i++) {
      document.addEventListener(names[i], fitViewport, false);
    }
  }

  // A real activation gesture (remote OK / tap / touch) unlocks audio and, on
  // stricter browsers that blocked the programmatic request, finishes filling
  // the screen when the phone wants it. Never forces fullscreen when the teacher
  // turned the toggle off.
  function onActivation() {
    primeTts();
    if (wantFs && !fsElement()) enterFullscreen();
  }

  if (document.addEventListener) {
    document.addEventListener('keydown', onActivation, false);
    document.addEventListener('click', onActivation, false);
    document.addEventListener('touchstart', onActivation, false);
  }

  // Fit the current screen and keep re-fitting on every size change (resolution
  // switch, rotation, fullscreen enter/exit).
  fitViewport();
  if (window.addEventListener) {
    window.addEventListener('resize', fitViewport, false);
    window.addEventListener('orientationchange', fitViewport, false);
  }
  bindFsChange();

  // First paint + poll loop
  poll();
  setInterval(poll, POLL_MS);
})();
