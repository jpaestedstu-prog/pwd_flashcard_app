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

  // Every route on the phone lives under a per-cast session code
  // (`/c/<token>`), so this page is only reachable by a TV the teacher handed
  // the link to. The server injects the prefix as window.CAST_BASE just above
  // this script; we prepend it to the state poll and to every media URL the
  // payload carries (those stay root-relative server-side so the API contract
  // — and its tests — don't have to know about the code).
  var BASE = (typeof window !== 'undefined' && window.CAST_BASE) || '';

  // Captions the TV draws itself (not lesson content), in the language of the
  // teacher's app. The phone sends it as `ui` on every state poll; lesson
  // words and stories keep following the "Language on TV" setting instead.
  var uiLang = 'en';
  var UI = {
    en: {
      soundHint: '🔊 Press OK on the remote (or tap) to turn on sound',
      watchSignSpeak: 'Watch the sign, then pick the word.',
      whichPicture: 'Which word matches the picture?',
      trueOrFalse: 'True, or false?',
      pickOnPhone: 'Pick what to cast on the teacher’s phone.',
      teacherOut: 'The teacher is out',
      backSoon: 'Back soon — please wait.',
      reconnecting: 'Oops, the teacher is connecting…',
      sameWifi: 'Make sure the teacher’s device is on the same Wi-Fi.',
      loading: 'Loading…',
      loadingSign: 'Loading sign…',
      noFslFor: 'No FSL video available for',
      loadingWord: 'Loading',
      loadingSignFor: 'Loading sign for',
      theEnd: 'The End',
      pageRead: 'page read',
      pagesRead: 'pages read',
      classWins: 'Our Class Wins 🎉',
      noStudentData: 'No student data yet.',
      wordsTogether: 'words learned together',
      starsEarned: 'stars earned',
      learningToday: 'learning today',
      dayBestStreak: 'day best streak',
      words: 'words',
      dayStreak: 'day streak',
      leaderboard: 'Class Leaderboard',
      scoreboard: 'Scoreboard',
      liveActivity: 'Live Activity',
      getReady: 'Get ready for the next question!',
      answered: 'answered',
      question: 'Question',
      watchSignPick: 'Watch the sign — pick the word on your device',
      trueWord: 'True',
      falseWord: 'False',
      raisedHands: '✋ Raised hands',
      timesUp: 'Time’s up!',
      paused: 'paused',
      page: 'Page',
      forGroups: 'For:',
      remoteTitle: 'TV remote',
      remoteOff: 'The TV remote is turned off on the teacher’s device.',
      pressBackAgain: 'Press Back again to leave the cast.',
      keyCards: 'Previous / next card',
      keySigns: 'Previous / next sign',
      keyPages: 'Previous / next page',
      keyFlip: 'Flip the card',
      keyFlipPic: 'Flip the picture',
      keySignAgain: 'Play the sign again',
      keySayAgain: 'Say it again',
      keyShowMe: 'Show Me',
      keyFsl: 'Watch in FSL',
      keyPause: 'Pause / play',
      keyBack: 'Close / leave',
      keyInfo: 'Show these keys',
      keySound: 'Turn on sound',
      toastNext: 'Next ▶',
      toastPrev: '◀ Previous',
      toastPause: 'Pause / play',
      toastFlip: 'Flip',
      toastAgain: 'Again',
      toastShowMe: 'Show Me',
      toastFsl: 'FSL',
      toastClose: 'Close'
    },
    fil: {
      soundHint: '🔊 Pindutin ang OK sa remote (o i-tap) para bumukas ang tunog',
      watchSignSpeak: 'Panoorin ang senyas, saka piliin ang salita.',
      whichPicture: 'Aling salita ang tugma sa larawan?',
      trueOrFalse: 'Tama, o mali?',
      pickOnPhone: 'Piliin sa phone ng guro ang ika-cast.',
      teacherOut: 'Wala ang guro',
      backSoon: 'Babalik agad — maghintay lang.',
      reconnecting: 'Naku, kumokonekta pa ang guro…',
      sameWifi: 'Tiyaking nasa parehong Wi-Fi ang device ng guro.',
      loading: 'Nilo-load…',
      loadingSign: 'Nilo-load ang senyas…',
      noFslFor: 'Walang video ng FSL para sa',
      loadingWord: 'Nilo-load ang',
      loadingSignFor: 'Nilo-load ang senyas para sa',
      theEnd: 'Wakas',
      pageRead: 'pahinang nabasa',
      pagesRead: 'pahinang nabasa',
      classWins: 'Tagumpay ng Ating Klase 🎉',
      noStudentData: 'Wala pang datos ng mag-aaral.',
      wordsTogether: 'salitang natutunan nang sama-sama',
      starsEarned: 'bituing nakuha',
      learningToday: 'nag-aaral ngayon',
      dayBestStreak: 'pinakamahabang sunod-sunod na araw',
      words: 'salita',
      dayStreak: 'araw na sunod-sunod',
      leaderboard: 'Leaderboard ng Klase',
      scoreboard: 'Scoreboard',
      liveActivity: 'Live na Gawain',
      getReady: 'Humanda sa susunod na tanong!',
      answered: 'ang sumagot',
      question: 'Tanong',
      watchSignPick: 'Panoorin ang senyas — piliin ang salita sa device mo',
      trueWord: 'Tama',
      falseWord: 'Mali',
      raisedHands: '✋ Mga nagtaas ng kamay',
      timesUp: 'Tapos na ang oras!',
      paused: 'naka-pause',
      page: 'Pahina',
      forGroups: 'Para sa:',
      remoteTitle: 'Remote ng TV',
      remoteOff: 'Naka-off ang remote ng TV sa device ng guro.',
      pressBackAgain: 'Pindutin ulit ang Back para umalis sa cast.',
      keyCards: 'Nakaraan / susunod na card',
      keySigns: 'Nakaraan / susunod na senyas',
      keyPages: 'Nakaraan / susunod na pahina',
      keyFlip: 'Baligtarin ang card',
      keyFlipPic: 'Baligtarin ang larawan',
      keySignAgain: 'Ulitin ang senyas',
      keySayAgain: 'Sabihin ulit',
      keyShowMe: 'Ipakita',
      keyFsl: 'Panoorin sa FSL',
      keyPause: 'I-pause / ituloy',
      keyBack: 'Isara / umalis',
      keyInfo: 'Ipakita ang mga pindutan',
      keySound: 'Buksan ang tunog',
      toastNext: 'Susunod ▶',
      toastPrev: '◀ Nakaraan',
      toastPause: 'I-pause / ituloy',
      toastFlip: 'Baligtarin',
      toastAgain: 'Ulit',
      toastShowMe: 'Ipakita',
      toastFsl: 'FSL',
      toastClose: 'Isara'
    }
  };
  function T(key) {
    var table = UI[uiLang] || UI.en;
    return table[key] !== undefined ? table[key] : UI.en[key];
  }

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
  var lastLiveKey = null;      // identifies the live question currently painted,
                               // so a new answer coming in updates the counter
                               // instead of restarting the sign clip.
  var failCount = 0;          // consecutive failed /api/state polls
  var reconnecting = false;   // currently showing the "connecting" overlay
  var FAIL_THRESHOLD = 2;     // ~3s of failures before the overlay appears

  // ─── Sound: the spoken words, through the TV's own speakers ───────────
  // The phone makes each spoken line into a WAV and lists it in `say`
  // ({u: link, t: text, l: 'en' | 'fil'}). We play those with ONE <audio>
  // element — the thing every TV browser can do. TV browsers rarely have a
  // working Web Speech engine (Android TV's WebView has none, many Tizen /
  // webOS builds have no voices), so speaking with the TV's own voice is now
  // only the fallback: for a line whose file fails, or a phone that couldn't
  // make one.
  //
  // Browsers won't play sound until someone has pressed something on the page
  // (the autoplay rules). When a line is refused for that reason we keep it,
  // show "press OK", and play it from inside the very next key press — that
  // press is what the browser is waiting for, and it unlocks the element for
  // every line after it. The element is reused for every line so that unlock
  // sticks on browsers that grant it per element.
  //
  // `speed` (1 or 2, from the phone) is the playbackRate of the words and of
  // every clip, applied to whatever is already playing without restarting it.
  var lastSpokenKey = null;   // sayKey of the item last spoken
  var ttsUnlocked = false;    // the TV's own voice has spoken (or a key was pressed)
  var audioUnlocked = false;  // the <audio> element has played sound
  var activated = false;      // someone pressed a key / tapped since load
  var lastState = null;
  var lastReplayNonce = null; // last seen state.ttsReplay.n (explicit replay)
  var speed = 1;
  var audioEl = null;
  var sayQueue = [];          // lines still to say, in order
  var sayLine = null;         // the line playing right now
  var sayTimer = null;        // a sequence waiting for its card to land
  var sayWatch = null;        // old browsers: notices a play() that never starts
  var blockedSay = false;     // a line is waiting for the unlocking key press
  var speakingNow = false;    // reported to the phone (spk=1) to hold the slideshow
  var cantSpeak = false;      // a line found neither a file nor a voice

  // A tenth of a second of silence (8 kHz, 8-bit mono WAV), built here rather
  // than pasted in: played from inside the first key press so a browser that
  // unlocks per element unlocks this one. Empty where btoa is missing.
  var SILENT_WAV = (function () {
    function u16(v) { return String.fromCharCode(v & 255, (v >> 8) & 255); }
    function u32(v) {
      return String.fromCharCode(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255);
    }
    try {
      var n = 800;
      var body = '';
      for (var i = 0; i < n; i++) body += String.fromCharCode(128);
      var wav = 'RIFF' + u32(36 + n) + 'WAVEfmt ' + u32(16) + u16(1) + u16(1) +
        u32(8000) + u32(8000) + u16(1) + u16(8) + 'data' + u32(n) + body;
      return 'data:audio/wav;base64,' + window.btoa(wav);
    } catch (e) {
      return '';
    }
  })();

  function ttsSupported() {
    return typeof window !== 'undefined' && 'speechSynthesis' in window;
  }

  // Whether this browser plays a WAV at all (the phone's audio format).
  var wavOk = (function () {
    try {
      var a = document.createElement('audio');
      if (!a || !a.canPlayType) return false;
      return !!(a.canPlayType('audio/wav; codecs="1"') ||
        a.canPlayType('audio/wav') || a.canPlayType('audio/x-wav'));
    } catch (e) {
      return false;
    }
  })();

  function showSoundHint() {
    if (hint) {
      hint.innerHTML = escapeHtml(T('soundHint'));
      hint.className = 'sound-hint';
    }
  }

  function hideSoundHint() {
    if (hint) hint.className = 'sound-hint hidden';
  }

  // A small speaker in the corner while a line plays — so the room (and a
  // teacher who can't hear it) can see that the TV is talking.
  function setSpeaking(on) {
    speakingNow = on;
    var el = document.getElementById('say-indicator');
    if (!el) {
      if (!on) return;
      el = document.createElement('div');
      el.id = 'say-indicator';
      el.innerHTML = '🔊';
      document.body.appendChild(el);
    }
    el.className = on ? 'say-indicator' : 'say-indicator hidden';
  }

  function onSoundStarted() {
    // Sound actually came out: whatever the browser wanted, it got.
    blockedSay = false;
    hideSoundHint();
  }

  function getAudio() {
    if (audioEl) return audioEl;
    audioEl = document.createElement('audio');
    audioEl.id = 'cast-audio';
    audioEl.preload = 'auto';
    audioEl.onplaying = function () {
      if (sayWatch) { clearTimeout(sayWatch); sayWatch = null; }
      if (!sayLine) return; // the silent unlock clip
      audioUnlocked = true;
      cantSpeak = false;
      onSoundStarted();
    };
    audioEl.onended = function () {
      if (!sayLine) return;
      sayLine = null;
      playNextLine();
    };
    audioEl.onerror = function () {
      // The file isn't there (the phone couldn't make it) or can't be
      // decoded: say this line with the TV's own voice instead.
      if (!sayLine) return;
      var line = sayLine;
      sayLine = null;
      if (sayWatch) { clearTimeout(sayWatch); sayWatch = null; }
      speakLineWithVoice(line);
    };
    document.body.appendChild(audioEl);
    return audioEl;
  }

  function applyRate(el) {
    try {
      el.defaultPlaybackRate = speed;
      el.playbackRate = speed;
    } catch (e) {}
  }

  // Stops every line, now and queued.
  function stopSpeech() {
    if (sayTimer) { clearTimeout(sayTimer); sayTimer = null; }
    if (sayWatch) { clearTimeout(sayWatch); sayWatch = null; }
    sayQueue = [];
    sayLine = null;
    blockedSay = false;
    if (audioEl) {
      try { audioEl.pause(); } catch (e) {}
    }
    if (ttsSupported()) {
      try { window.speechSynthesis.cancel(); } catch (e) {}
    }
    setSpeaking(false);
  }

  // Says [lines] in order, after [delay] ms (so a word is heard as its card
  // lands, not while the old one is still sliding away).
  function playSequence(lines, delay) {
    stopSpeech();
    var list = [];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i] && lines[i].t) list.push(lines[i]);
    }
    if (!list.length) return;
    sayQueue = list;
    setSpeaking(true);
    if (delay > 0) {
      sayTimer = setTimeout(function () {
        sayTimer = null;
        playNextLine();
      }, delay);
    } else {
      playNextLine();
    }
  }

  function playNextLine() {
    if (!sayQueue.length) {
      sayLine = null;
      setSpeaking(false);
      return;
    }
    var line = sayQueue.shift();
    setSpeaking(true);
    if (line.u && wavOk) {
      playLineFile(line);
    } else {
      speakLineWithVoice(line);
    }
  }

  function playLineFile(line) {
    var a = getAudio();
    sayLine = line;
    try {
      // A line held back by the autoplay rules is already loaded: play it from
      // there when OK comes, rather than fetching it again.
      if (a.getAttribute('src') !== line.u) {
        a.src = line.u;
      } else {
        try { a.currentTime = 0; } catch (e) {}
      }
      applyRate(a);
      var p = a.play();
      if (p && typeof p.then === 'function') {
        p.then(function () {
          applyRate(a);
        }, function (err) {
          if (sayLine !== line) return;
          if (err && err.name === 'NotAllowedError') {
            soundBlocked(line);
          }
          // Any other failure arrives as the element's own error event.
        });
      } else {
        // A browser too old to say whether play() worked: if the line hasn't
        // started in a few seconds, treat it as waiting for a key press.
        if (sayWatch) clearTimeout(sayWatch);
        sayWatch = setTimeout(function () {
          sayWatch = null;
          if (sayLine === line && a.paused) soundBlocked(line);
        }, 3000);
      }
    } catch (e) {
      sayLine = null;
      speakLineWithVoice(line);
    }
  }

  // The browser wants a key press before it plays sound: keep the line, ask
  // for OK, and play it from inside that press (see unlockSound).
  function soundBlocked(line) {
    sayLine = null;
    sayQueue.unshift(line);
    blockedSay = true;
    setSpeaking(false);
    showSoundHint();
  }

  // The fallback: the TV browser's own speech engine, at the cast's speed.
  function speakLineWithVoice(line) {
    if (!ttsSupported()) {
      cantSpeak = true;
      playNextLine();
      return;
    }
    try {
      var u = new SpeechSynthesisUtterance(line.t);
      u.lang = line.l === 'fil' ? 'fil-PH' : 'en-US';
      u.volume = 1.0; // max — the Web Speech API caps volume at 1.0
      u.rate = speed;
      u.onstart = function () {
        ttsUnlocked = true;
        cantSpeak = false;
        onSoundStarted();
      };
      u.onend = function () { playNextLine(); };
      u.onerror = function () { playNextLine(); };
      window.speechSynthesis.speak(u);
      if (!ttsUnlocked && !activated) showSoundHint();
    } catch (e) {
      cantSpeak = true;
      playNextLine();
    }
  }

  // Spoken form of a live question, for a payload without `say`: the prompt
  // (or the type's instruction for a picture / sign question), then the
  // lettered choices. Kept word for word in step with castLiveSpeechText on
  // the phone. The correct answer is never in the payload.
  function liveSpeechText(a) {
    var parts = [];
    if (a.type === 'fslSign') {
      parts.push(T('watchSignSpeak'));
    } else if (a.type === 'pictureChoice') {
      parts.push(T('whichPicture'));
    } else if (a.prompt) {
      parts.push(a.prompt);
    }
    if (a.isTrueFalse) {
      parts.push(T('trueOrFalse'));
    } else if (a.options && a.options.length) {
      for (var i = 0; i < a.options.length; i++) {
        parts.push(String.fromCharCode(65 + i) + '. ' + a.options[i]);
      }
    }
    return parts.join(' ');
  }

  // What to say for the item on screen, and its key: the phone's `say` list
  // when it sent one, else built here the way the TV always did (an older
  // phone). FSL signs, the board, a story's sign clip and its closing screen
  // say nothing.
  function currentLines(state) {
    if (state.say && state.say.length !== undefined) {
      return { key: state.sayKey || '', lines: state.say };
    }
    var en = '', fil = '', key = '';
    if (state.mode === 'flashcards' && state.slide) {
      en = state.slide.wordEn || '';
      fil = state.slide.wordFil || '';
      key = 'f:' + (state.slide.catLabel || '') + ':' + state.slide.index;
    } else if (
      state.mode === 'story' && state.story &&
      !state.storyFsl && !state.storyDone
    ) {
      en = state.story.textEn || '';
      fil = state.story.textFil || '';
      key = 's:' + (state.story.titleEn || '') + ':' + state.story.pageIndex;
    } else if (state.mode === 'live' && state.live && state.live.activity) {
      var la = state.live.activity;
      var text = liveSpeechText(la);
      key = 'l:' + (la.id || la.prompt || '');
      return { key: key, lines: text ? [{ t: text, l: uiLang }] : [] };
    }
    // The language filter governs speech as well as display.
    if (state.lang === 'en') fil = '';
    else if (state.lang === 'fil') en = '';
    var lines = [];
    if (en) lines.push({ t: en, l: 'en' });
    if (fil) lines.push({ t: fil, l: 'fil' });
    return { key: key, lines: lines };
  }

  // Says the item on screen once, when the TV is where the sound plays.
  function maybeSpeak(state, delay) {
    if (!state.ttsOnTv) {
      stopSpeech();
      lastSpokenKey = null;
      hideSoundHint();
      return;
    }
    var cur = currentLines(state);
    if (!cur.lines.length || !cur.key) {
      // Nothing to say here (signs, the board, The End): stop the last item.
      if (lastSpokenKey !== null) stopSpeech();
      lastSpokenKey = null;
      return;
    }
    if (cur.key === lastSpokenKey) return;
    lastSpokenKey = cur.key;
    playSequence(cur.lines, delay || 0);
  }

  // Says the item on screen again, in [lang] ('en', 'fil' or 'both').
  function replayLines(state, lang) {
    var cur = currentLines(state);
    var lines = [];
    for (var i = 0; i < cur.lines.length; i++) {
      var l = cur.lines[i];
      if (lang === 'en' && l.l === 'fil') continue;
      if (lang === 'fil' && l.l === 'en') continue;
      lines.push(l);
    }
    if (!lines.length) return false;
    playSequence(lines, 0);
    return true;
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
    if (!state.ttsOnTv) return;
    replayLines(state, rp.lang || 'both');
  }

  // The first key press / tap: the moment the browser allows sound. Plays a
  // line the browser held back, or else a breath of silence to unlock the
  // element for the lines to come — synchronously, inside the press.
  function unlockSound() {
    if (!activated) activated = true;
    ttsUnlocked = true;
    if (blockedSay && sayQueue.length) {
      blockedSay = false;
      hideSoundHint();
      playNextLine();
    } else if (!audioUnlocked && wavOk && SILENT_WAV) {
      try {
        var a = getAudio();
        if (!sayLine) {
          a.src = SILENT_WAV;
          var p = a.play();
          if (p && typeof p.then === 'function') {
            p.then(function () { audioUnlocked = true; }, function () {});
          }
        }
      } catch (e) {}
    } else {
      hideSoundHint();
    }
    if (ttsSupported() && !audioUnlocked) {
      try {
        var u = new SpeechSynthesisUtterance(' ');
        u.volume = 0;
        window.speechSynthesis.speak(u);
      } catch (e) {}
    }
    unmuteVideos();
  }

  // ─── Clips: speed, and their own sound when the teacher wants it ─────
  // Every clip starts muted, because a muted video may autoplay everywhere.
  // When the phone's "Video sound" is on we unmute it once it is playing and
  // the page has been unlocked; a browser that pauses an unmuted clip gets it
  // muted again (playing beats silent-and-stopped) and the OK hint.
  var wantVideoSound = false;

  function stageVideos() {
    var vids = stage.getElementsByTagName('video');
    return vids || [];
  }

  function syncVideos(state) {
    wantVideoSound = !!state.videoSound;
    var vids = stageVideos();
    for (var i = 0; i < vids.length; i++) {
      var v = vids[i];
      applyRate(v);
      // The live question's sign is always silent: the answers are spoken.
      var sound = wantVideoSound && !(v.className && v.className.indexOf('live-sign') >= 0);
      if (!sound) {
        if (!v.muted) v.muted = true;
      } else if (v.muted && (activated || audioUnlocked)) {
        unmuteVideo(v);
      }
    }
  }

  function unmuteVideo(v) {
    try {
      v.muted = false;
      var p = v.play();
      if (p && typeof p.then === 'function') {
        p.then(function () {}, function () {
          v.muted = true;
          try { v.play(); } catch (e) {}
          showSoundHint();
        });
      }
    } catch (e) {}
  }

  function unmuteVideos() {
    if (!wantVideoSound) return;
    var vids = stageVideos();
    for (var i = 0; i < vids.length; i++) {
      if (vids[i].muted && !(vids[i].className && vids[i].className.indexOf('live-sign') >= 0)) {
        unmuteVideo(vids[i]);
      }
    }
  }

  function applySpeed(state) {
    var s = Number(state.speed);
    if (!(s > 0)) s = 1;
    if (s === speed) return;
    speed = s;
    if (audioEl) applyRate(audioEl);
    var vids = stageVideos();
    for (var i = 0; i < vids.length; i++) applyRate(vids[i]);
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
      '<p>' + escapeHtml(T('pickOnPhone')) + '</p>' +
      '</div>'
    );
    lastVideoUrl = null;
  }

  // "The teacher is out" — a served state (the phone is still reachable, it just
  // told us to show this). Different from the reconnecting overlay below, which
  // we show on our own when the phone stops answering.
  function renderAway() {
    stopSpeech();
    lastSpokenKey = null; // re-speak the current item when the teacher returns
    setStage(
      '<div class="splash away">' +
      '<div class="splash-emoji">☕</div>' +
      '<h1>' + escapeHtml(T('teacherOut')) + '</h1>' +
      '<p>' + escapeHtml(T('backSoon')) + '</p>' +
      '</div>'
    );
    lastVideoUrl = null;
  }

  // Shown by the poll loop when /api/state stops answering — the phone dropped
  // Wi-Fi, switched networks, or closed the cast. The TV keeps polling; the
  // moment the phone is reachable again we repaint the real content.
  function showReconnecting() {
    if (reconnecting) return;
    stopSpeech();
    lastSpokenKey = null; // say the item again once the phone is back
    setStage(
      '<div class="splash reconnect">' +
      '<div class="splash-emoji pulse">📡</div>' +
      '<h1>' + escapeHtml(T('reconnecting')) + '</h1>' +
      '<p>' + escapeHtml(T('sameWifi')) + '</p>' +
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
    lastLiveKey = null;
    lastCardPos = null;
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

  // ─── Card motion, matched to the app's flashcards ───────────────────
  // In the app the cards sit in a page view: the next card slides in from the
  // right as the old one slides out to the left (400 ms, easeOutCubic), and
  // the card that arrives grows from 92% to full size with a little overshoot
  // (400 ms, easeOutBack) while it fades in (300 ms). The TV does the same:
  // the outgoing card is kept on stage for the length of the slide (a copy
  // with its ids stripped, so lookups still find the new card), the incoming
  // one carries the enter animation, and the CSS does the rest. A new
  // category, the first card and a card coming back from a clip only grow and
  // fade in — as the app's first page does. Reduced motion and the Calm
  // template get a plain swap: no copy is made, so nothing can linger.
  var CARD_MS = 400;
  var lastCardPos = null;     // {cat, index} of the card on stage
  var cardEnterDelay = 0;     // ms until the card that just arrived has landed
  var leavingTimer = null;

  function motionReduced(state) {
    return !!state.reducedMotion || state.theme === 'calm';
  }

  // 'next' (slides in from the right), 'prev' (from the left) or '' (no slide)
  // for a move from the card on stage to [slide]. The phone wraps around the
  // deck, so the shorter way round is the direction it went.
  function cardDirection(slide, state) {
    if (motionReduced(state) || !lastCardPos) return '';
    if (!document.getElementById('fc-current')) return '';
    if (lastCardPos.cat !== (slide.catLabel || '')) return '';
    var n = slide.total || 0;
    var d = slide.index - lastCardPos.index;
    if (!d) return '';
    if (n > 2) {
      var fwd = ((d % n) + n) % n;
      return fwd <= n / 2 ? 'next' : 'prev';
    }
    return d > 0 ? 'next' : 'prev';
  }

  // Removes the outgoing card once its slide is over.
  function clearLeavingCards() {
    if (leavingTimer) { clearTimeout(leavingTimer); leavingTimer = null; }
    if (!stage.getElementsByClassName) return;
    var olds = stage.getElementsByClassName('fc-leaving');
    for (var i = olds.length - 1; i >= 0; i--) {
      if (olds[i].parentNode) olds[i].parentNode.removeChild(olds[i]);
    }
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
  // card we toggle the class on the existing tile (so the 3D flip animates —
  // 650 ms easeOutBack, the app's own flip); a new card does a full rebuild
  // (and always starts on the emoji).
  //
  // Any other repaint of the SAME card (a raised hand, the timer, a theme or
  // text-size change all bump the revision) leaves the card alone: those are
  // body classes and overlays, and rebuilding would replay its entrance.
  function renderFlashcardCard(state) {
    var slide = state.slide;
    var photo = slide.photo;
    var cartoon = slide.cartoon;
    var cartoonUrl = (cartoon && cartoon.available && cartoon.url) ? cartoon.url : null;
    var tapEnabled = state.tapOnly !== false; // default on for older payloads
    var hasPhoto = !!(photo && photo.available && photo.url) && tapEnabled;
    var flipped = hasPhoto && !!state.flipped;
    // Identifies the card + whether it has the flip structure, so a Flip press
    // (same key) animates via a class toggle instead of rebuilding the DOM.
    var key = (slide.catLabel || '') + '#' + slide.index + (hasPhoto ? '+p' : '') + (cartoonUrl ? '+c' : '');

    // Same card re-rendering: sync the is-flipped class on the existing tile
    // so the CSS transition animates, and touch nothing else. Guarded on the
    // card still being on stage (it isn't after a mode/clip switch → rebuild).
    if (key === lastFlashcardKey && document.getElementById('fc-current')) {
      if (hasPhoto) {
        var flipEl = document.getElementById('fcard-flip');
        var backEl = document.getElementById('fcard-photo-back');
        if (flipEl && backEl) {
          if (flipped && !backEl.style.backgroundImage) {
            backEl.style.backgroundImage = 'url("' + photo.url + '")';
          }
          flipEl.className = flipped ? 'fcard-flip is-flipped' : 'fcard-flip';
        }
      }
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

    // Picture tile. With a real photo/GIF AND the photo-flip feature on we build
    // a two-faced 3D flip card (emoji front, photo back); otherwise we keep the
    // plain emoji tile the TV has always shown. Either way the emoji is the face
    // that paints first, so a missing/slow/broken photo — or the control
    // switched off — just shows the emoji.
    var emojiSpan = '<span class="fcard-pic-emoji">' + escapeHtml(slide.emoji) + '</span>';
    // Front face mirrors the app: the illustrated picture where the card has
    // one, otherwise the emoji. The emoji also stays put until the cartoon
    // actually loads, so a slow or failed fetch never leaves an empty tile.
    var frontInner = cartoonUrl
      ? '<div class="fcard-face-art" id="fcard-cartoon-front">' + emojiSpan + '</div>'
      : emojiSpan;
    var picInner;
    if (hasPhoto) {
      picInner =
        '<div class="fcard-flip" id="fcard-flip">' +
        '<div class="fcard-face fcard-face-front">' + frontInner + '</div>' +
        '<div class="fcard-face fcard-face-back" id="fcard-photo-back"></div>' +
        '</div>';
    } else {
      picInner = frontInner;
    }

    // Which way the deck moved decides the slide; the card that leaves goes
    // out the other side.
    var dir = cardDirection(slide, state);
    var leaving = '';
    if (dir) {
      var cur = document.getElementById('fc-current');
      var outer = cur && cur.outerHTML;
      if (outer) {
        leaving = outer
          .replace(/ id="[^"]*"/g, '')
          .replace(/class="slide fc-card[^"]*"/, 'class="slide fc-card fc-leaving fc-out-' + dir + '"');
      }
    }
    clearLeavingCards();

    // Decorative tinted corner blobs sit behind the content, which has its own
    // .fcard-body layer so the layers always sort correctly. Colours inline;
    // the motion is CSS.
    setStage(
      leaving +
      '<div class="slide fc-card ' + (dir ? 'fc-in-' + dir : 'fc-in') + '" id="fc-current">' +
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
      '</div>' +
      '</div>'
    );
    if (leaving) leavingTimer = setTimeout(clearLeavingCards, CARD_MS + 120);
    cardEnterDelay = motionReduced(state) ? 0 : CARD_MS;
    lastCardPos = { cat: slide.catLabel || '', index: slide.index };
    lastVideoUrl = null;
    lastFlashcardKey = key;
    if (cartoonUrl) applyFlashcardCartoon(cartoonUrl);
    if (hasPhoto) applyFlashcardPhoto(photo.url, flipped);
  }

  // Paints the card's illustrated face once it has downloaded, replacing the
  // emoji placeholder in place. A failed or slow load simply leaves the emoji,
  // so the tile is never blank. Same CSS-background approach as the photo face
  // for old-WebKit-friendly scaling.
  function applyFlashcardCartoon(url) {
    var front = document.getElementById('fcard-cartoon-front');
    if (!front) return;
    var img = new Image();
    img.onload = function () {
      if (!front.parentNode) return;
      front.style.backgroundImage = 'url("' + url + '")';
      front.innerHTML = '';
    };
    img.onerror = function () { /* keep the emoji face */ };
    img.src = url;
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

    // Always starts muted, so it autoplays on every browser; the phone's
    // "Video sound" unmutes it once it plays (syncVideos).
    var mutedAttr = 'muted ';
    setStage(
      '<div class="fsl-wrap">' +
      '<div class="fsl-video-box">' +
      '<video autoplay ' + mutedAttr + 'loop playsinline webkit-playsinline ' +
      'controls preload="auto" src="' + escapeHtml(clip.url) + '"></video>' +
      '<div class="fsl-loading" id="fsl-loading">' +
      '<div class="spinner"></div>' +
      '<div class="fsl-loading-text">' + escapeHtml(T('loading')) + '</div>' +
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
        escapeHtml(T('noFslFor')) + ' "' + escapeHtml(slide.wordEn) + '"' +
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
      // Always starts muted, so the sign autoplays on every TV browser. The
      // phone's "Video sound" (`videoSound`) unmutes it once it is playing
      // (syncVideos) for clips that include a voiceover — rather than leaving
      // an unmuted clip that some browsers refuse to start at all.
      var mutedAttr = 'muted ';
      setStage(
        '<div class="fsl-wrap">' +
        '<div class="fsl-video-box">' +
        '<video autoplay ' + mutedAttr + 'loop playsinline webkit-playsinline ' +
        'controls preload="auto" src="' + escapeHtml(video.url) + '"></video>' +
        '<div class="fsl-loading" id="fsl-loading">' +
        '<div class="spinner"></div>' +
        '<div class="fsl-loading-text">' + escapeHtml(T('loadingSign')) + '</div>' +
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
        escapeHtml(T('loadingWord')) + ' "' + escapeHtml(slide.wordEn) + '"…' +
        '</div>' +
        '</div>'
      );
    };
  }

  // Story entry point. Normally paints the story page (text); when the teacher
  // activates "Watch in FSL" and the current page has a sign-language clip, the
  // clip takes over the whole stage (renderStoryFsl) instead — mirroring the
  // flashcard "Show Me" path.
  // The closing screen, once the story has been read to the end. Autoplay used
  // to reach the last page and just stop, leaving the final sentence up with no
  // signal the story was over — for a learner tracking a routine, "is it
  // finished?" is exactly the thing the shared screen should answer.
  function renderStoryEnd(state) {
    var story = state.story || {};
    var pages = story.totalPages || 0;
    setStage(
      '<div class="story-end">' +
      '<div class="se-emoji">🎉</div>' +
      '<h1 class="se-title">' + escapeHtml(T('theEnd')) + '</h1>' +
      (story.titleEn
        ? '<div class="se-story">' + escapeHtml(story.titleEn) +
          (story.titleFil
            ? '<span class="fil">' + escapeHtml(story.titleFil) + '</span>'
            : '') +
          '</div>'
        : '') +
      (pages
        ? '<div class="se-pages">' + pages +
          ' ' + escapeHtml(pages === 1 ? T('pageRead') : T('pagesRead')) + '</div>'
        : '') +
      '</div>'
    );
    lastVideoUrl = null;
    lastStoryKey = null;
  }

  function renderStory(state) {
    if (state.storyDone) {
      renderStoryEnd(state);
      return;
    }
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

    // Always starts muted, so the sign autoplays on every TV browser; the
    // phone's "Video sound" unmutes it once it plays (syncVideos).
    var mutedAttr = 'muted ';
    setStage(
      '<div class="fsl-wrap">' +
      '<div class="fsl-video-box">' +
      '<video autoplay ' + mutedAttr + 'loop playsinline webkit-playsinline ' +
      'controls preload="auto" src="' + escapeHtml(video.url) + '"></video>' +
      '<div class="fsl-loading" id="fsl-loading">' +
      '<div class="spinner"></div>' +
      '<div class="fsl-loading-text">' + escapeHtml(T('loadingSign')) + '</div>' +
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
        escapeHtml(T('loadingSignFor')) + ' "' + escapeHtml(story.titleEn) + '"…' +
        '</div>' +
        '</div>'
      );
    };
  }

  // "For: Hearing Class · Cognitive Class" — whose board / question this is,
  // from the phone's class / group picker. Left out when it would only repeat
  // the title the teacher already put on the screen.
  function audienceHtml(state, cls) {
    var who = state.audience || '';
    if (!who || who === state.title) return '';
    return '<div class="' + cls + '">' + escapeHtml(T('forGroups')) + ' ' +
      escapeHtml(who) + '</div>';
  }

  function renderProgress(state) {
    // Default to the non-competitive view for older payloads that predate the
    // toggle — a shared screen shouldn't start out ranking children.
    if (state.progressView !== 'leaderboard') {
      renderClassWins(state);
      return;
    }
    renderLeaderboard(state);
  }

  // The class's shared achievement, then every learner A–Z with their own
  // numbers. No ranks, no medals, no ordering that implies one — the same data
  // as the leaderboard with the competition taken out.
  function renderClassWins(state) {
    var s = state.classSummary || {};
    var rows = s.rows || [];
    var html = '<div class="board wins"><h2>' + escapeHtml(T('classWins')) + '</h2>' +
      audienceHtml(state, 'board-for');

    if (!rows.length) {
      html += '<div class="empty">' + escapeHtml(T('noStudentData')) + '</div></div>';
      setStage(html);
      lastVideoUrl = null;
      return;
    }

    html +=
      '<div class="wins-totals">' +
      '<div class="wins-stat"><span class="v">' + (s.words || 0) + '</span>' +
      escapeHtml(T('wordsTogether')) + '</div>' +
      '<div class="wins-stat"><span class="v">' + (s.stars || 0) + '</span>' +
      escapeHtml(T('starsEarned')) + '</div>' +
      '<div class="wins-stat"><span class="v">' + (s.activeToday || 0) + ' / ' +
      (s.learners || 0) + '</span>' + escapeHtml(T('learningToday')) + '</div>' +
      '<div class="wins-stat"><span class="v">' + (s.bestStreak || 0) + '</span>' +
      escapeHtml(T('dayBestStreak')) + '</div>' +
      '</div>';

    html += '<div class="wins-grid">';
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      html +=
        '<div class="wins-card">' +
        '<div class="wins-name">' + escapeHtml(r.name) + '</div>' +
        '<div class="wins-line">' +
        '<span>' + r.words + ' ' + escapeHtml(T('words')) + '</span>' +
        '<span>' + r.streak + '🔥</span>' +
        '<span>' + r.stars + '⭐</span>' +
        '</div>' +
        '</div>';
    }
    html += '</div></div>';

    setStage(html);
    lastVideoUrl = null;
  }

  function renderLeaderboard(state) {
    var rows = state.progress || [];
    var html = '<div class="board"><h2>' + escapeHtml(T('leaderboard')) + '</h2>' +
      audienceHtml(state, 'board-for');
    if (rows.length === 0) {
      html += '<div class="empty">' + escapeHtml(T('noStudentData')) + '</div>';
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
          '<div class="stat"><span class="v">' + r.words + '</span>' + escapeHtml(T('words')) + '</div>' +
          '<div class="stat"><span class="v">' + r.streak + '</span>' + escapeHtml(T('dayStreak')) + '</div>' +
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
  // Builds the scoreboard block (shared by the full render and the in-place
  // update below, so the two can never drift apart).
  function liveBoardHtml(live) {
    var board = live.board || [];
    if (!board.length) return '';
    var html = '<div class="live-board"><h2>' + escapeHtml(T('scoreboard')) + '</h2>';
    for (var j = 0; j < board.length && j < 6; j++) {
      var r = board[j];
      html +=
        '<div class="live-row">' +
        '<span class="rk">#' + (j + 1) + '</span>' +
        '<span class="nm">' + escapeHtml(r.name) + '</span>' +
        '<span class="sc">' + r.correct + '✔ ' + r.stars + '⭐</span>' +
        '</div>';
    }
    return html + '</div>';
  }

  function renderLive(state) {
    var live = state.live || {};
    var a = live.activity;

    if (!a) {
      lastLiveKey = null;
      lastVideoUrl = null;
      setStage(
        '<div class="live">' +
        '<div class="live-wait">' +
        '<div class="splash-emoji">🎮</div>' +
        '<h1>' + escapeHtml(T('liveActivity')) + '</h1>' +
        '<p>' + escapeHtml(T('getReady')) + '</p>' +
        audienceHtml(state, 'live-for') +
        '</div>' +
        liveBoardHtml(live) +
        '</div>'
      );
      return;
    }

    // Every answer bumps the revision, so a naive rebuild would restart the
    // sign clip each time a learner responded — the one thing an fslSign
    // question can't survive. When the question itself hasn't changed we patch
    // the two volatile bits (answered count, scoreboard) in place and leave the
    // <video> element completely alone.
    var key = a.id || (a.type + '|' + (a.prompt || '') + '|' + (a.flashcardId || ''));
    if (key === lastLiveKey) {
      var respEl = document.getElementById('live-responded');
      if (respEl) {
        respEl.innerHTML = (live.responded || 0) + ' ' + escapeHtml(T('answered'));
      }
      var boardEl = document.getElementById('live-board-slot');
      if (boardEl) {
        var boardHtml = liveBoardHtml(live);
        if (boardEl.innerHTML !== boardHtml) boardEl.innerHTML = boardHtml;
      }
      return;
    }

    var html = '<div class="live">' + audienceHtml(state, 'live-for');
    if (a.questionNumber && a.totalQuestions) {
      html +=
        '<div class="live-qnum">' + escapeHtml(T('question')) + ' ' + a.questionNumber + ' / ' +
        a.totalQuestions + '</div>';
    }

    // An fslSign question shows the actual sign when the phone resolved one —
    // the sign IS the question, and an emoji stand-in makes it unanswerable
    // from the shared screen. Muted + looping so it autoplays on every TV
    // browser and repeats for learners who need another look. Falls back to
    // the emoji when no clip exists (or it's still downloading).
    var signUrl =
      a.type === 'fslSign' && a.video && a.video.available && a.video.url
        ? a.video.url
        : null;
    // A picture question shows the real photograph for the same reason.
    var photoUrl =
      a.type === 'pictureChoice' && a.photo && a.photo.available && a.photo.url
        ? a.photo.url
        : null;

    if (signUrl) {
      html +=
        '<div class="live-media">' +
        '<video class="live-sign" autoplay muted loop playsinline webkit-playsinline ' +
        'preload="auto" src="' + escapeHtml(signUrl) + '"></video>' +
        '</div>' +
        '<div class="live-sub">' + escapeHtml(T('watchSignPick')) + '</div>';
    } else if (photoUrl) {
      html +=
        '<div class="live-media">' +
        '<img src="' + escapeHtml(photoUrl) + '" alt="">' +
        '</div>' +
        '<div class="live-sub">' + escapeHtml(T('whichPicture')) + '</div>';
    } else if (a.type === 'pictureChoice' || a.type === 'fslSign') {
      html += '<div class="live-emoji">' + escapeHtml(a.emoji || '❓') + '</div>';
      html +=
        '<div class="live-sub">' +
        (a.type === 'fslSign'
          ? escapeHtml(T('watchSignPick'))
          : escapeHtml(T('whichPicture'))) +
        '</div>';
    } else if (a.prompt) {
      html += '<h1 class="live-prompt">' + escapeHtml(a.prompt) + '</h1>';
    }

    if (a.isTrueFalse) {
      html +=
        '<div class="live-options">' +
        '<div class="live-opt">✔ ' + escapeHtml(T('trueWord')) + '</div>' +
        '<div class="live-opt">✘ ' + escapeHtml(T('falseWord')) + '</div>' +
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
      '<div class="live-responded" id="live-responded">' +
      (live.responded || 0) + ' ' + escapeHtml(T('answered')) + '</div>';
    html += '<div id="live-board-slot">' + liveBoardHtml(live) + '</div>';
    html += '</div>';

    setStage(html);
    lastLiveKey = key;
    // The live <video> is keyed by lastLiveKey, not lastVideoUrl — clear the
    // latter so returning to Flashcards/FSL mode rebuilds its own player.
    lastVideoUrl = null;
    if (signUrl) attachLiveSignHandlers(a);
  }

  // Retry handler for the live sign clip. The phone prefetches it when the
  // question is pushed, but on a cold cache /api/video can still 404 for a
  // moment — drop the key (and lastRev, or the poll loop short-circuits) so the
  // next poll rebuilds and tries again, exactly like attachVideoHandlers.
  function attachLiveSignHandlers(activity) {
    var vids = stage.getElementsByTagName('video');
    if (!vids || !vids.length) return;
    vids[0].onerror = function () {
      lastLiveKey = null;
      lastVideoUrl = null;
      lastRev = -1;
      var slot = stage.getElementsByClassName('live-media');
      if (slot && slot.length) {
        slot[0].innerHTML =
          '<div class="live-emoji">' + escapeHtml(activity.emoji || '❓') + '</div>';
      }
    };
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
    var inner = '<span class="hand-title">' + escapeHtml(T('raisedHands')) + '</span>';
    for (var i = 0; i < hands.length; i++) {
      inner += '<span class="hand-chip">' + escapeHtml(hands[i]) + '</span>';
    }
    el.innerHTML = inner;
    el.className = 'hands-banner';
  }

  // ─── Lesson timer overlay ─────────────────────────────
  // Sits on top of whatever is being cast — "4:12 left" while the flashcards
  // keep running is the useful version, so this is an overlay (like the raised-
  // hands banner) rather than a mode.
  //
  // Driven from `ok()` on EVERY poll, not from `render()`: render only runs
  // when the revision changes, and the phone deliberately doesn't bump the
  // revision per second (that would rebuild the stage and restart a playing
  // sign clip). Between polls we count down locally off the last `secondsLeft`,
  // and each poll re-syncs — so the clock stays honest without touching the
  // content underneath it.
  var timerLocalLeft = null;   // seconds, decremented by our own 1s tick
  var timerPaused = false;
  var timerTotal = 0;
  var timerLabel = '';
  var timerFinishedShown = false;
  var timerSay = null;         // the phone's audio for "Time's up!"

  function timerEl() {
    var el = document.getElementById('lesson-timer');
    if (!el) {
      el = document.createElement('div');
      el.id = 'lesson-timer';
      document.body.appendChild(el);
    }
    return el;
  }

  function formatClock(total) {
    if (total < 0) total = 0;
    var m = Math.floor(total / 60);
    var s = total % 60;
    return m + ':' + (s < 10 ? '0' + s : s);
  }

  // Folds a fresh /api/state into the local clock.
  function syncTimer(state) {
    var t = state.timer;
    if (!t) {
      timerLocalLeft = null;
      timerFinishedShown = false;
      paintTimer();
      return;
    }
    timerLocalLeft = t.secondsLeft;
    timerPaused = !!t.paused;
    timerTotal = t.total || 0;
    timerLabel = t.label || '';
    timerSay = t.say || null;
    if (timerLocalLeft > 0) timerFinishedShown = false;
    paintTimer();
  }

  // Our own 1s tick between polls, so the clock doesn't visibly stutter at the
  // 1.5s poll cadence. Never goes below zero; the next poll is authoritative.
  function tickTimer() {
    if (timerLocalLeft === null || timerPaused) return;
    if (timerLocalLeft > 0) {
      timerLocalLeft--;
      paintTimer();
    }
  }

  function paintTimer() {
    var el = timerEl();
    if (timerLocalLeft === null) {
      el.className = 'lesson-timer hidden';
      el.innerHTML = '';
      return;
    }
    var done = timerLocalLeft <= 0;
    var cls = 'lesson-timer';
    // Last 30 seconds get a warning tint; zero gets the finished treatment.
    if (done) cls += ' finished';
    else if (timerLocalLeft <= 30) cls += ' ending';
    if (timerPaused) cls += ' paused';
    el.className = cls;
    el.innerHTML =
      '<span class="lt-clock">' + (done ? escapeHtml(T('timesUp')) : formatClock(timerLocalLeft)) + '</span>' +
      (timerLabel ? '<span class="lt-label">' + escapeHtml(timerLabel) + '</span>' : '') +
      (timerPaused && !done ? '<span class="lt-label">' + escapeHtml(T('paused')) + '</span>' : '');

    if (done && !timerFinishedShown) {
      timerFinishedShown = true;
      // Say it once, if the TV is where the sound plays.
      if (lastState && lastState.ttsOnTv) {
        playSequence([timerSay || { t: T('timesUp'), l: uiLang }], 0);
      }
    }
  }

  function updateFooter(state) {
    var bits = [];
    if (state.slide && typeof state.slide.index === 'number') {
      bits.push((state.slide.index + 1) + ' / ' + state.slide.total);
    } else if (state.story && typeof state.story.pageIndex === 'number') {
      bits.push(escapeHtml(T('page')) + ' ' + (state.story.pageIndex + 1) + ' / ' + state.story.totalPages);
    }
    if (state.isPaused) {
      bits.push('<span class="paused">⏸ ' + escapeHtml(T('paused')) + '</span>');
    }
    if (bits.length === 0) {
      pill.className = 'footer-pill hidden';
      pill.innerHTML = '';
    } else {
      pill.className = 'footer-pill';
      pill.innerHTML = bits.join('  ');
    }
  }

  // Single owner of body.className — theme, reduced motion, text size and
  // language filter all live here. They must be set together: whoever writes
  // last would otherwise wipe the others' classes on every poll.
  //
  // Text size and language are applied as classes (not inline styles) so the
  // per-theme rules can still override them, and so a TV browser that ignores
  // an unknown class simply falls back to the default size / both languages.
  function applyTheme(state) {
    var theme = state.theme || 'dark';
    var cls = 'theme-' + theme;
    // Mirror the app's reduced-motion accessibility setting so entrance
    // animations are dropped for motion-sensitive viewers.
    if (state.reducedMotion) cls += ' reduce-motion';
    cls += ' text-' + (state.textSize || 'normal');
    cls += ' lang-' + (state.lang || 'both');
    // "Fullscreen picture & video": the photo / GIF / sign clip fills the stage
    // instead of sitting inside the card frame. Deliberately a body class and
    // nothing else — the whole effect is CSS, so flipping it restyles what is
    // already on screen instead of rebuilding it, and a playing sign clip keeps
    // playing. Off for payloads that predate the toggle.
    if (state.bigPicture) cls += ' big-picture';
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
    // Default on for payloads that predate the switch.
    remoteOn = state.remote !== false;
    // 1× / 2× for the words and the clips — applied to what is already
    // playing, never by restarting it.
    applySpeed(state);
    renderHandsBanner(state);
    renderBranding(state);
    renderSeasonal(state);
    // Anything that replaces the stage invalidates the live question's DOM, so
    // forget its key — otherwise coming back to the same question would try to
    // patch elements that no longer exist and paint nothing.
    if (state.away || state.mode !== 'live') lastLiveKey = null;
    // Away overrides whatever mode is selected; the content stays selected on
    // the phone so it resumes the instant the teacher returns.
    if (state.away) {
      lastCardPos = null;
      renderAway();
      updateFooter({}); // empty → hides the footer pill
      return;
    }
    // Any stage that isn't a flashcard drops a card still sliding out, and
    // the next card that comes back grows in rather than sliding.
    if (state.mode !== 'flashcards' || state.showMe) {
      clearLeavingCards();
      lastCardPos = null;
    }
    cardEnterDelay = 0;
    switch (state.mode) {
      case 'flashcards': renderFlashcards(state); break;
      case 'fslVideo':   renderFslVideo(state);   break;
      case 'story':      renderStory(state);      break;
      case 'progress':   renderProgress(state);   break;
      case 'live':       renderLive(state);       break;
      default:           renderIdle();
    }
    updateFooter(state);
    syncVideos(state);
    // A new card's word is said as the card lands, not while it slides in.
    maybeSpeak(state, cardEnterDelay);
    maybeReplay(state);
    refreshHelp(state);
  }

  // Moves every media URL in a freshly-parsed payload into the session-code
  // namespace. The server emits them root-relative (`/api/image/0/cat`) so the
  // JSON contract stays code-agnostic; the TV is the side that knows its own
  // prefix. Mutates in place — `state` is a throwaway parse of this poll's
  // body — and is a no-op when there's no prefix, so an un-scoped server (and
  // the asset opened directly) still works.
  function scopeMediaUrls(state) {
    if (!BASE || !state) return;
    function scope(obj, key) {
      if (obj && typeof obj[key] === 'string' && obj[key].charAt(0) === '/') {
        obj[key] = BASE + obj[key];
      }
    }
    var slide = state.slide;
    if (slide) {
      scope(slide.photo, 'url');
      scope(slide.cartoon, 'url');
      scope(slide.clip, 'url');
    }
    scope(state.video, 'url');
    scope(state.storyVideo, 'url');
    if (state.story) {
      scope(state.story.image, 'cartoonUrl');
      scope(state.story.image, 'realUrl');
    }
    if (state.live && state.live.activity) {
      scope(state.live.activity.video, 'url');
      scope(state.live.activity.photo, 'url');
    }
    // The spoken words' audio, and "Time's up!".
    if (state.say && state.say.length) {
      for (var i = 0; i < state.say.length; i++) scope(state.say[i], 'u');
    }
    if (state.timer && state.timer.say) scope(state.timer.say, 'u');
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
      scopeMediaUrls(state);
      // Outside the revision short-circuit below: the timer re-syncs on every
      // poll precisely so the phone never has to bump the revision for it.
      syncTimer(state);
      // Coming back from a disconnect: the revision may be unchanged, so force a
      // repaint to replace the "connecting" overlay with the live content.
      if (reconnecting) {
        reconnecting = false;
        lastRev = -1;
      }
      var nextUi = state.ui === 'fil' ? 'fil' : 'en';
      if (nextUi !== uiLang) {
        uiLang = nextUi;
        lastRev = -1;
      }
      if (state.rev === lastRev) return;
      lastRev = state.rev;
      render(state);
    }

    // Tell the phone whether this TV can make speech at all (play the phone's
    // audio files, or speak with its own voice), whether the browser has let
    // it play sound yet, and whether it is talking right now — so the phone
    // can explain why the TV is/isn't speaking, and hold the slideshow until a
    // line has been heard to the end.
    var ttsFlag = ((wavOk || ttsSupported()) && !cantSpeak) ? '1' : '0';
    var unlockedFlag = (audioUnlocked || ttsUnlocked) && !blockedSay ? '1' : '0';
    var spkFlag = speakingNow ? '1' : '0';
    xhr.open(
      'GET',
      BASE + '/api/state?tts=' + ttsFlag + '&unlocked=' + unlockedFlag +
        '&spk=' + spkFlag,
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

  // A real activation gesture (remote key / tap / touch) unlocks sound and, on
  // stricter browsers that blocked the programmatic request, finishes filling
  // the screen when the phone wants it. Never forces fullscreen when the teacher
  // turned the toggle off. It is also the only moment the Back-key guards may
  // be added (see "The Back key"): Chrome skips entries added without one.
  function onActivation() {
    unlockSound();
    if (wantFs && !fsElement()) enterFullscreen();
    topUpGuard();
  }

  // ─── TV remote ───────────────────────────────────────
  // Every key on an ordinary TV remote does something, so a teacher at the
  // board needs neither the tablet nor a mouse, keyboard or touchscreen:
  //   ◀ ▶  (⏪ ⏩, CH− CH+)  previous / next card, sign or page
  //   OK / Enter            flip the card or the story picture; replay a sign.
  //                         The very first OK on a silent page only turns the
  //                         sound (and full screen) on.
  //   ▲                     say the word / page / question again
  //   ▼                     the card's "Show Me" clip / the page's FSL clip
  //   ▶❚❚  ▶  ❚❚  ■         pause / play the slideshow
  //   Back                  close a clip or flip the card back; twice, leave
  //   Info / Menu           show these keys on the TV
  // Key codes first: 2014-era TV browsers predate KeyboardEvent.key. Tizen
  // (10009 Back, 10252 play/pause) and webOS (461 Back) have their own.
  //
  // Lesson moves go to the phone (/api/nudge), which enforces the educator's
  // on/off switch; the TV polls straight after so the change shows at once
  // instead of on the next 1.5 s tick. Saying a word again and the key list
  // are the TV's own business and work even with the remote switched off.
  var remoteOn = true;
  var lastNudgeAt = 0;
  var lastNudgeAction = '';

  var KEYS = {
    prev: [[37, 412, 428, 34], ['ArrowLeft', 'Left', 'MediaRewind', 'MediaTrackPrevious', 'ChannelDown']],
    next: [[39, 417, 427, 33], ['ArrowRight', 'Right', 'MediaFastForward', 'MediaTrackNext', 'ChannelUp']],
    ok: [[13], ['Enter', 'Select', 'Accept']],
    up: [[38], ['ArrowUp', 'Up']],
    down: [[40], ['ArrowDown', 'Down']],
    playpause: [[179, 10252, 32], ['MediaPlayPause', ' ', 'Spacebar']],
    play: [[415, 250], ['MediaPlay', 'Play']],
    pause: [[19, 413, 178], ['MediaPause', 'Pause', 'MediaStop']],
    back: [[10009, 461, 166], ['GoBack', 'BrowserBack']],
    close: [[27, 8], ['Escape', 'Esc', 'Backspace']],
    info: [[457, 93, 112], ['Info', 'ContextMenu', 'Help', 'F1']]
  };

  function has(list, v) {
    for (var i = 0; i < list.length; i++) if (list[i] === v) return true;
    return false;
  }

  function keyAction(e) {
    var code = e.keyCode || e.which || 0;
    var name = e.key || '';
    for (var action in KEYS) {
      if (!KEYS.hasOwnProperty(action)) continue;
      if (code && has(KEYS[action][0], code)) return action;
      if (name && has(KEYS[action][1], name)) return action;
    }
    return '';
  }

  // A short note at the bottom of the screen, so a key press always shows
  // that it landed — even when its effect takes a moment to arrive.
  var toastTimer = null;
  function toast(text) {
    var el = document.getElementById('remote-toast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'remote-toast';
      document.body.appendChild(el);
    }
    el.innerHTML = escapeHtml(text);
    el.className = 'remote-toast';
    if (toastTimer) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      el.className = 'remote-toast hidden';
    }, 1800);
  }

  function nudge(action, label) {
    if (!remoteOn) {
      toast(T('remoteOff'));
      return;
    }
    // A held-down key repeats fast; one step per press is what a teacher
    // means, and it keeps us off the phone's back.
    var now = new Date().getTime();
    if (action === lastNudgeAction && now - lastNudgeAt < 300) return;
    lastNudgeAt = now;
    lastNudgeAction = action;
    if (label) toast(label);
    try {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', BASE + '/api/nudge?a=' + action, true);
      xhr.timeout = 3000;
      xhr.onreadystatechange = function () {
        if (xhr.readyState !== 4) return;
        if (xhr.status === 200) {
          poll(); // show the result now, not at the next tick
        } else if (xhr.status === 403) {
          remoteOn = false;
          toast(T('remoteOff'));
        }
      };
      xhr.send();
    } catch (e) {}
  }

  // Starts the clip on stage from the beginning (a sign to watch again).
  function replayClip() {
    var vids = stageVideos();
    if (!vids.length) return false;
    try {
      vids[0].currentTime = 0;
      vids[0].play();
    } catch (e) {}
    return true;
  }

  function onOk(st) {
    hideHelp();
    if (st.mode === 'flashcards' && st.slide && !st.showMe &&
        st.slide.photo && st.slide.photo.available && st.tapOnly !== false) {
      nudge('flip', T('toastFlip'));
    } else if (st.mode === 'story' && st.story && st.story.image &&
        st.story.image.available && !st.storyFsl && !st.storyDone) {
      nudge('flip', T('toastFlip'));
    } else {
      replayClip();
    }
  }

  function onSayAgain(st) {
    hideHelp();
    if (st.ttsOnTv) {
      if (replayLines(st, 'both')) toast('🔊 ' + T('toastAgain'));
      else replayClip();
      return;
    }
    if (st.mode === 'fslVideo') {
      replayClip();
      return;
    }
    // The sound comes from the phone: it says it.
    nudge('replay', '🔊 ' + T('toastAgain'));
  }

  function onShowMe(st) {
    hideHelp();
    if (st.mode === 'flashcards' && st.slide && st.slide.clip &&
        st.slide.clip.available) {
      nudge('showme', st.showMe ? T('toastClose') : T('toastShowMe'));
    } else if (st.mode === 'story' && st.storyVideo &&
        st.storyVideo.available && !st.storyDone) {
      nudge('showme', st.storyFsl ? T('toastClose') : T('toastFsl'));
    }
  }

  // Whatever is open on top of the card: a clip, or a flipped face.
  function closeOverlay(st) {
    if (st.away) return false;
    if (st.showMe || st.storyFsl || st.flipped || st.storyImageFlipped) {
      nudge('back', T('toastClose'));
      return true;
    }
    return false;
  }

  // ─── The Back key ────────────────────────────────────
  // A TV browser's Back goes back in history, which leaves the cast. So extra
  // history entries stand guard: each Back lands on one and is used here — to
  // close a clip / flip the card back, or else to say "press Back again to
  // leave", and a second press within 3 s then leaves.
  //
  // The guards are only ever added inside a key press or tap. Chrome steps
  // over entries a page adds without one, so a guard put back from the Back
  // handler itself was skipped by the next Back, which then left the cast with
  // no warning (found with Chrome on the tablet, Back from the system). Two
  // are kept topped up, so closing a clip and then the warning both fit
  // between key presses. (A browser in fullscreen spends the first Back on
  // leaving fullscreen; that one never reaches the page.)
  var BACK_ARM_MS = 3000;
  var GUARD_DEPTH = 2;
  var guardDepth = 0;         // our entries above the cast's own
  var exitArmed = false;
  var exitTimer = null;
  var backKeyAt = 0;

  function topUpGuard() {
    try {
      if (!window.history || !window.history.pushState) return;
      while (guardDepth < GUARD_DEPTH) {
        window.history.pushState({ flCast: guardDepth + 1 }, '');
        guardDepth++;
      }
    } catch (e) {}
  }

  // Leaves the cast the way Back would have: past every guard still there.
  function leaveCast() {
    try { window.history.go(-(guardDepth + 1)); } catch (e) {}
  }

  // One Back press. True when it was used up here; false when it should
  // leave the cast.
  function handleBack(st) {
    if (hideHelp()) return true;
    if (closeOverlay(st)) return true;
    if (exitArmed) return false;
    exitArmed = true;
    toast(T('pressBackAgain'));
    if (exitTimer) clearTimeout(exitTimer);
    exitTimer = setTimeout(function () {
      exitTimer = null;
      exitArmed = false;
    }, BACK_ARM_MS);
    return true;
  }

  function onPopState() {
    if (guardDepth > 0) guardDepth--; // the browser stepped off one guard
    // Some TVs send a Back key AND step back in history: the key did it.
    if (new Date().getTime() - backKeyAt < 700) return;
    if (!handleBack(lastState || {})) leaveCast();
  }

  function onBackKey(st) {
    backKeyAt = new Date().getTime();
    if (!handleBack(st)) leaveCast();
  }

  // ─── The key list on the TV ──────────────────────────
  // Shown on its own once, on the waiting screen the TV opens on (where it
  // covers nothing), so whoever holds the remote learns what it does; it
  // closes itself when the first lesson appears. After that it comes back on
  // Info / Menu, or when a key the cast doesn't use (a number, a colour) is
  // pressed — never on top of a card unasked.
  var helpTimer = null;
  var helpOpen = false;
  var helpShownOnce = false;
  var helpAuto = false;       // the open list is the waiting screen's intro

  function helpEl() {
    var el = document.getElementById('remote-help');
    if (!el) {
      el = document.createElement('div');
      el.id = 'remote-help';
      el.className = 'remote-help hidden';
      document.body.appendChild(el);
    }
    return el;
  }

  function helpRows(st) {
    // While the teacher is away the lesson waits: only leaving is on offer.
    if (st.away) return [['Back', T('keyBack')], ['Info', T('keyInfo')]];
    var m = st.mode;
    var stepper = m === 'flashcards' || m === 'fslVideo' || m === 'story';
    var rows = [];
    if (!audioUnlocked && !ttsUnlocked) rows.push(['OK', T('keySound')]);
    if (st.remote !== false) {
      if (stepper) {
        rows.push(['◀ ▶', T(m === 'story' ? 'keyPages' : (m === 'fslVideo' ? 'keySigns' : 'keyCards'))]);
      }
      if (m === 'flashcards') rows.push(['OK', T('keyFlip')]);
      else if (m === 'story') rows.push(['OK', T('keyFlipPic')]);
      else if (m === 'fslVideo') rows.push(['OK', T('keySignAgain')]);
    }
    if (m === 'flashcards' || m === 'story' || m === 'live') {
      rows.push(['▲', T('keySayAgain')]);
    }
    if (st.remote !== false) {
      if (m === 'flashcards') rows.push(['▼', T('keyShowMe')]);
      else if (m === 'story') rows.push(['▼', T('keyFsl')]);
      if (stepper) rows.push(['▶❚❚', T('keyPause')]);
    }
    rows.push(['Back', T('keyBack')]);
    rows.push(['Info', T('keyInfo')]);
    return rows;
  }

  function helpHtml(st) {
    var rows = helpRows(st);
    var html = '<div class="rh-title">' + escapeHtml(T('remoteTitle')) + '</div>';
    if (st.remote === false) {
      html += '<div class="rh-off">' + escapeHtml(T('remoteOff')) + '</div>';
    }
    html += '<div class="rh-rows">';
    for (var i = 0; i < rows.length; i++) {
      html += '<div class="rh-row"><span class="rh-key">' + escapeHtml(rows[i][0]) +
        '</span><span class="rh-do">' + escapeHtml(rows[i][1]) + '</span></div>';
    }
    return html + '</div>';
  }

  function showHelp(auto) {
    var el = helpEl();
    el.innerHTML = helpHtml(lastState || {});
    el.className = 'remote-help';
    helpOpen = true;
    helpAuto = !!auto;
    if (helpTimer) clearTimeout(helpTimer);
    helpTimer = setTimeout(hideHelp, auto ? 15000 : 10000);
  }

  function hideHelp() {
    if (helpTimer) { clearTimeout(helpTimer); helpTimer = null; }
    if (!helpOpen) return false;
    helpOpen = false;
    helpAuto = false;
    helpEl().className = 'remote-help hidden';
    return true;
  }

  function refreshHelp(st) {
    var waiting = !st.mode || st.mode === 'idle';
    if (!helpShownOnce && waiting && !st.away) {
      helpShownOnce = true;
      showHelp(true);
      return;
    }
    // The intro steps aside for the lesson; a list someone asked for stays.
    if (helpOpen && helpAuto && !waiting) {
      hideHelp();
      return;
    }
    if (helpOpen) helpEl().innerHTML = helpHtml(st);
  }

  function onKeyDown(e) {
    if (e.ctrlKey || e.altKey || e.metaKey) return; // the browser's shortcuts
    var action = keyAction(e);
    var code = e.keyCode || e.which || 0;
    // The very first OK on a page that can't make sound yet is the one press
    // the browser is waiting for: it turns the sound (and full screen) on and
    // does nothing else, as the phone's key list says.
    var silent = !activated && !audioUnlocked && action === 'ok';
    if (action !== 'back' && action !== 'close') onActivation();
    if (!action) {
      // Numbers and the colour keys: show what the remote does here.
      if ((code >= 48 && code <= 57) || (code >= 96 && code <= 105) ||
          (code >= 403 && code <= 406)) {
        showHelp(false);
      }
      return;
    }
    if (e.preventDefault) e.preventDefault();
    var st = lastState || {};
    // Stepping and pausing only mean something in the slide modes — and not
    // while the teacher is away, when the lesson must wait for them rather
    // than move on behind the "teacher is out" screen. Elsewhere the key shows
    // what the remote does here instead of a note that promises a move.
    if (st.away && action !== 'info' && action !== 'close' && action !== 'back') {
      showHelp(false);
      return;
    }
    var stepper = !st.away &&
      (st.mode === 'flashcards' || st.mode === 'fslVideo' || st.mode === 'story');
    if (!stepper && (action === 'prev' || action === 'next' ||
        action === 'playpause' || action === 'play' || action === 'pause')) {
      showHelp(false);
      return;
    }
    switch (action) {
      case 'info':
        if (!hideHelp()) showHelp(false);
        return;
      case 'close':
        if (!hideHelp()) closeOverlay(st);
        return;
      case 'back':
        onBackKey(st);
        return;
      case 'ok':
        if (silent) {
          toast('🔊 ' + T('keySound'));
          return;
        }
        onOk(st);
        return;
      case 'up':
        onSayAgain(st);
        return;
      case 'down':
        onShowMe(st);
        return;
      case 'prev':
        hideHelp();
        nudge('prev', T('toastPrev'));
        return;
      case 'next':
        hideHelp();
        nudge('next', T('toastNext'));
        return;
      default:
        hideHelp();
        nudge(action, T('toastPause'));
    }
  }

  if (document.addEventListener) {
    document.addEventListener('keydown', onKeyDown, false);
    document.addEventListener('click', onActivation, false);
    document.addEventListener('touchstart', onActivation, false);
  }
  if (window.addEventListener) {
    window.addEventListener('popstate', onPopState, false);
  }
  // Somewhere for a TV browser to deliver its keys: some only send the D-pad
  // to the focused element and move a pointer around otherwise.
  try {
    stage.setAttribute('tabindex', '-1');
    stage.focus();
  } catch (e) {}

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
  // Separate 1s tick just for the countdown, so it doesn't stutter at the
  // 1.5s poll cadence. Cheap: it only touches the overlay's own node.
  setInterval(tickTimer, 1000);
})();
