/* FlashLearn PWD — the Try It page: ten real flashcards (flip, speak, FSL clip)
   and a playable five-round Word Match. Moved here unchanged from the old
   one-page site, except the card's category tag class (.chip -> .try-tag). */
(function(){
  // "Try it in your browser" flashcard demo. Words, Filipino translations,
  // emojis, and example sentences mirror the app's seed data exactly
  // (lib/data/local/seed_data.dart + flashcard_emojis.dart). `v` names the
  // FSL clip in assets/videos/fsl/ (compressed from the app's own videos).
  var CARDS = [
    {emoji:'🐕', en:'Dog',       fil:'Aso',        s:'The dog is my best friend.',    catEn:'Animals',            catFil:'Mga Hayop',            v:'dog'},
    {emoji:'🔴', en:'Red',       fil:'Pula',       s:'The apple is red.',             catEn:'Colors & Shapes',    catFil:'Mga Kulay at Hugis',   v:'red'},
    {emoji:'3️⃣', en:'Three',     fil:'Tatlo',      s:'There are three dogs.',         catEn:'Numbers',            catFil:'Mga Numero',           v:'three'},
    {emoji:'🤲', en:'Hands',     fil:'Kamay',      s:'I clap my hands.',              catEn:'Body Parts',         catFil:'Mga Bahagi ng Katawan', v:'hands'},
    {emoji:'💧', en:'Water',     fil:'Tubig',      s:'I drink water.',                catEn:'Food & Drinks',      catFil:'Pagkain at Inumin',    v:'water'},
    {emoji:'🙏', en:'Thank You', fil:'Salamat',    s:'Thank you for helping me.',     catEn:'Family & Greetings', catFil:'Pamilya at Pagbati',   v:'thank-you'},
    {emoji:'👟', en:'Shoes',     fil:'Sapatos',    s:'My shoes are new.',             catEn:'Clothing',           catFil:'Mga Damit',            v:'shoes'},
    {emoji:'🌈', en:'Rainbow',   fil:'Bahaghari',  s:'I see a beautiful rainbow.',    catEn:'Weather',            catFil:'Panahon',              v:'rainbow'},
    {emoji:'✏️', en:'Pencil',    fil:'Lapis',      s:'I write with a pencil.',        catEn:'Classroom',          catFil:'Silid-aralan',         v:'pencil'},
    {emoji:'😊', en:'Happy',     fil:'Masaya',     s:'I am happy today!',             catEn:'Emotions',           catFil:'Damdamin',             v:'happy'}
  ];
  var card = document.getElementById('tryCard');
  if (!card) return;
  var inner = document.getElementById('tryInner');
  var count = document.getElementById('tryCount');
  var idx = 0;

  function render(){
    var c = CARDS[idx];
    inner.innerHTML =
      '<span class="try-face front">' +
        '<span class="try-tag"><span class="en">' + c.catEn + '</span><span class="fil">' + c.catFil + '</span></span>' +
        '<span class="try-emoji" aria-hidden="true">' + c.emoji + '</span>' +
        '<span class="try-word-en">' + c.en + '</span>' +
        '<span class="try-word-fil">' + c.fil + '</span>' +
        '<span class="try-hint"><span class="en">👆 Tap the card to flip it</span><span class="fil">👆 I-tap ang card para baliktarin</span></span>' +
      '</span>' +
      '<span class="try-face back">' +
        '<span class="try-tag"><span class="en">Example sentence</span><span class="fil">Halimbawang pangungusap</span></span>' +
        '<span class="try-back-emoji" aria-hidden="true">' + c.emoji + '</span>' +
        '<span class="try-sentence">&ldquo;' + c.s + '&rdquo;</span>' +
        '<span class="try-word-fil">' + c.en + ' = ' + c.fil + '</span>' +
        '<span class="try-hint"><span class="en">👆 Tap to flip back</span><span class="fil">👆 I-tap para bumalik</span></span>' +
      '</span>';
    card.setAttribute('aria-pressed', 'false');
    count.textContent = (idx + 1) + ' / ' + CARDS.length;
    if (fslBtn) fslBtn.hidden = !fslOk || !c.v;
    syncFaces();
  }
  function syncFaces(){
    var flipped = card.getAttribute('aria-pressed') === 'true';
    inner.children[0].setAttribute('aria-hidden', flipped ? 'true' : 'false');
    inner.children[1].setAttribute('aria-hidden', flipped ? 'false' : 'true');
  }
  card.addEventListener('click', function(){
    card.setAttribute('aria-pressed', card.getAttribute('aria-pressed') === 'true' ? 'false' : 'true');
    syncFaces();
  });
  document.getElementById('tryPrev').addEventListener('click', function(){
    idx = (idx - 1 + CARDS.length) % CARDS.length; render();
  });
  document.getElementById('tryNext').addEventListener('click', function(){
    idx = (idx + 1) % CARDS.length; render();
  });

  // FSL: watch the word signed in Filipino Sign Language. Clips are the app's
  // own videos, compressed for the web; they load only when requested.
  var fslBtn = document.getElementById('tryFsl');
  var fslBox = document.getElementById('fslBox');
  var fslVideo = document.getElementById('fslVideo');
  var fslSlow = document.getElementById('fslSlow');
  var fslOk = !!(fslBox && fslBox.showModal);
  if (fslOk) {
    fslBtn.addEventListener('click', function(){
      var c = CARDS[idx];
      if (!c.v) return;
      document.getElementById('fslWord').textContent = c.en + ' · ' + c.fil;
      fslSlow.setAttribute('aria-pressed', 'false');
      fslVideo.src = 'assets/videos/fsl/' + c.v + '.mp4';
      fslBox.showModal();
      fslVideo.playbackRate = 1;
      fslVideo.play().catch(function(){});
    });
    fslSlow.addEventListener('click', function(){
      var on = fslSlow.getAttribute('aria-pressed') !== 'true';
      fslSlow.setAttribute('aria-pressed', on ? 'true' : 'false');
      fslVideo.playbackRate = on ? 0.5 : 1;
    });
    document.getElementById('fslClose').addEventListener('click', function(){ fslBox.close(); });
    fslBox.addEventListener('click', function(e){ if (e.target === fslBox) fslBox.close(); });
    fslBox.addEventListener('close', function(){
      fslVideo.pause(); fslVideo.removeAttribute('src'); fslVideo.load();
    });
  }

  // Speech via the device's built-in voices (same idea as the app's TTS).
  var synth = window.speechSynthesis;
  // Declared out here (not inside the else) so the Word Match round below can
  // speak too; a no-op when the browser has no speech synthesis.
  var speak = function(){};
  if (!synth) {
    document.getElementById('trySayEn').hidden = true;
    document.getElementById('trySayFil').hidden = true;
    document.getElementById('trySaySentence').hidden = true;
    document.getElementById('tryTtsNote').hidden = true;
  } else {
    if (synth.onvoiceschanged !== undefined) synth.onvoiceschanged = function(){};
    synth.getVoices();
    var voiceFor = function(prefixes){
      var vs = synth.getVoices();
      for (var i = 0; i < prefixes.length; i++)
        for (var j = 0; j < vs.length; j++)
          if ((vs[j].lang || '').toLowerCase().replace('_','-').indexOf(prefixes[i]) === 0) return vs[j];
      return null;
    };
    speak = function(text, lang, prefixes){
      synth.cancel();
      var u = new SpeechSynthesisUtterance(text);
      u.lang = lang; u.rate = 0.9;
      var v = voiceFor(prefixes); if (v) u.voice = v;
      synth.speak(u);
    };
    document.getElementById('trySayEn').addEventListener('click', function(){ speak(CARDS[idx].en, 'en-US', ['en']); });
    document.getElementById('trySayFil').addEventListener('click', function(){ speak(CARDS[idx].fil, 'fil-PH', ['fil','tl']); });
    document.getElementById('trySaySentence').addEventListener('click', function(){ speak(CARDS[idx].s, 'en-US', ['en']); });
  }
  // ---- Playable Word Match round ---------------------------------------
  // Word Match is the game worth demoing: with Memory Match it is one of only
  // two that appear in all six accessibility rosters, and picture -> word is
  // the app's core learning loop. Reuses the same ten cards as the flashcard.
  (function(){
    var ROUNDS = 5, CHOICES = 3;
    var tabCards = document.getElementById('tabCards');
    var tabPlay = document.getElementById('tabPlay');
    var panelCards = document.getElementById('panelCards');
    var panelPlay = document.getElementById('panelPlay');
    if (!tabPlay || !panelPlay) return;

    var elRound = document.getElementById('wmRound');
    var elScore = document.getElementById('wmScore');
    var elEmoji = document.getElementById('wmEmoji');
    var elChoices = document.getElementById('wmChoices');
    var elFeedback = document.getElementById('wmFeedback');
    var elPlay = document.getElementById('wmPlay');
    var elDone = document.getElementById('wmDone');
    var elFinal = document.getElementById('wmFinal');
    var elDoneMsg = document.getElementById('wmDoneMsg');

    var deck = [], round = 0, score = 0, missed = false, timer = null, started = false;

    function shuffle(a){
      a = a.slice();
      for (var i = a.length - 1; i > 0; i--){
        var j = Math.floor(Math.random() * (i + 1)), tmp = a[i];
        a[i] = a[j]; a[j] = tmp;
      }
      return a;
    }
    // Both languages are emitted and CSS shows the active one, so the FIL
    // toggle keeps working on content injected mid-game.
    function bi(en, fil){
      return '<span class="en">' + en + '</span><span class="fil">' + fil + '</span>';
    }

    function start(){
      clearTimeout(timer);
      deck = shuffle(CARDS).slice(0, ROUNDS);
      round = 0; score = 0; started = true;
      elDone.hidden = true; elPlay.hidden = false;
      renderRound();
    }

    function renderRound(){
      missed = false;
      var c = deck[round];
      elEmoji.textContent = c.emoji;
      elRound.innerHTML = bi('Round ' + (round + 1) + ' of ' + ROUNDS,
                             'Round ' + (round + 1) + ' ng ' + ROUNDS);
      elScore.textContent = '\u2B50 ' + score;
      elFeedback.textContent = '';
      elFeedback.className = 'wm-feedback';

      var others = shuffle(CARDS.filter(function(x){ return x.en !== c.en; })).slice(0, CHOICES - 1);
      var opts = shuffle(others.concat([c]));
      elChoices.innerHTML = '';
      opts.forEach(function(o){
        var b = document.createElement('button');
        b.type = 'button';
        b.innerHTML = bi(o.en, o.fil);
        b.addEventListener('click', function(){ pick(b, o, c); });
        elChoices.appendChild(b);
      });
    }

    function pick(btn, chosen, correct){
      if (btn.disabled) return;
      if (chosen.en === correct.en) {
        btn.classList.add('right');
        if (!missed) score++;             // only a first-try answer scores
        [].forEach.call(elChoices.children, function(b){ b.disabled = true; });
        elScore.textContent = '\u2B50 ' + score;
        elFeedback.className = 'wm-feedback good';
        elFeedback.innerHTML = bi(
          '\u2705 Correct! ' + correct.en + ' = ' + correct.fil,
          '\u2705 Tama! ' + correct.en + ' = ' + correct.fil);
        speak(correct.en, 'en-US', ['en']);
        timer = setTimeout(next, 1500);
      } else {
        btn.classList.add('wrong');
        btn.disabled = true;
        missed = true;
        elFeedback.className = 'wm-feedback bad';
        elFeedback.innerHTML = bi('\u274C Not quite \u2014 try again.',
                                  '\u274C Hindi tama \u2014 subukan ulit.');
      }
    }

    function next(){
      round++;
      if (round >= ROUNDS) finish(); else renderRound();
    }

    function finish(){
      elPlay.hidden = true;
      elDone.hidden = false;
      elRound.innerHTML = bi('Finished', 'Tapos na');
      elScore.textContent = '\u2B50 ' + score;
      elFinal.textContent = score + ' / ' + ROUNDS;
      elDoneMsg.innerHTML = (score === ROUNDS)
        ? bi('Perfect score! That is one of the app\u2019s 15 games.',
             'Perpektong puntos! Isa iyan sa 15 laro ng app.')
        : bi('Well played! The app has 15 games and 177 words to practise.',
             'Magaling! May 15 laro at 177 salita ang app.');
      elFeedback.textContent = '';
      elFeedback.className = 'wm-feedback';
    }

    function select(which){
      var playing = (which === 'play');
      clearTimeout(timer);
      if (synth) synth.cancel();
      tabPlay.setAttribute('aria-selected', String(playing));
      tabCards.setAttribute('aria-selected', String(!playing));
      tabPlay.tabIndex = playing ? 0 : -1;
      tabCards.tabIndex = playing ? -1 : 0;
      panelPlay.hidden = !playing;
      panelCards.hidden = playing;
      if (playing && !started) start();
    }

    tabCards.addEventListener('click', function(){ select('cards'); });
    tabPlay.addEventListener('click', function(){ select('play'); });
    // Arrow keys move between tabs, as a tablist is expected to.
    [tabCards, tabPlay].forEach(function(tab){
      tab.addEventListener('keydown', function(e){
        if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
        e.preventDefault();
        var other = (tab === tabCards) ? tabPlay : tabCards;
        select(other === tabPlay ? 'play' : 'cards');
        other.focus();
      });
    });
    document.getElementById('wmAgain').addEventListener('click', function(){
      start();
      var first = elChoices.querySelector('button');
      if (first) first.focus();
    });
  })();

  render();
})();
