import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/action_clip_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/seasonal_event_provider.dart';
import '../../live_session/models/live_session_models.dart';
import '../../live_session/services/live_session_service.dart';
import '../models/tv_cast_session.dart';
import '../services/tv_cast_asset_bridge.dart';
import '../services/tv_cast_audio_narrator.dart';
import '../services/tv_cast_autoplay_controller.dart';
import '../services/tv_cast_ip_discovery.dart';
import '../services/tv_cast_keep_alive.dart';
import '../services/tv_cast_server.dart';

/// Owns the cast session state machine and the underlying HTTP server.
/// Every mutation bumps `revision` so the TV's poll loop can short-circuit
/// re-renders when nothing has changed.
class TvCastSessionNotifier extends Notifier<TvCastSession> {
  TvCastServer? _server;
  TvCastAutoplayController? _autoplay;
  TvCastAudioNarrator? _narrator;
  Timer? _viewerTickTimer;

  /// Guards the one-shot "time's up" cue so it doesn't fire on every tick once
  /// the clock is at zero. Reset whenever the timer is (re)started or cleared.
  bool _timerChimed = false;

  // ─── Session tally (for the summary shown on Stop) ────
  // Counted here rather than derived from state, because the interesting
  // numbers are *events* (a card advanced past, a question pushed) which state
  // only ever holds one of at a time.
  DateTime? _sessionStartedAt;
  final List<CastMode> _modesUsed = [];
  int _cardsShown = 0;
  int _storyPagesShown = 0;
  int _liveQuestionsPushed = 0;
  int _peakViewers = 0;

  /// Answers to questions already replaced by the next one, so the running
  /// total survives `liveResponders` resetting on each push.
  int _liveAnswersBanked = 0;

  // ─── Progress-mode liveness ───────────────────────────
  // The leaderboard used to be a snapshot the educator had to tap "Next" to
  // refresh, so a class watching their own progress on the TV saw stale numbers
  // for the whole lesson. While progress mode is on we both subscribe to the
  // roster (so a learner earning stars repaints the TV) and keep a slow
  // backstop tick — the roster provider's own liveness depends on whether cloud
  // sync is configured, and a wall display shouldn't quietly go stale when it
  // isn't. `_refreshProgress` no-ops unless the numbers actually changed, so
  // neither path repaints the TV for nothing.
  ProviderSubscription<AsyncValue<List<(UserProfile, LearningProgress)>>>?
      _rosterSub;
  Timer? _progressTickTimer;
  static const _progressBackstopInterval = Duration(seconds: 15);

  // ─── Live interactive session (CastMode.live) ─────────
  final LiveSessionService _liveService = const LiveSessionService();
  StreamSubscription<List<RaisedHand>>? _handsSub;
  StreamSubscription<List<LiveResponse>>? _responsesSub;

  /// Most recent full response set for the session, cached so the responder
  /// count + scoreboard can be recomputed when either it or the current
  /// activity changes.
  List<LiveResponse> _latestResponses = const [];

  @override
  TvCastSession build() {
    ref.onDispose(() {
      _autoplay?.dispose();
      _viewerTickTimer?.cancel();
      _stopProgressWatch();
      unawaited(TvCastKeepAlive.stop());
      unawaited(_handsSub?.cancel());
      unawaited(_responsesSub?.cancel());
      unawaited(_narrator?.stop());
      unawaited(_server?.stop());
    });
    return const TvCastSession();
  }

  /// Lazily builds the phone-side narrator from the app's shared TTS / sound
  /// services. Created on first use so the (idle) provider stays cheap.
  TvCastAudioNarrator _audio() {
    return _narrator ??= TvCastAudioNarrator(
      tts: ref.read(ttsServiceProvider),
      sfx: ref.read(soundServiceProvider),
    );
  }

  /// Speaks the current word / story page from the phone and plays a soft cue,
  /// honouring the per-cast toggle and the app's accessibility settings.
  /// No-op unless the server is running.
  void _narrateCurrent({bool withCue = true}) {
    if (!state.isServerRunning || !state.castAudioEnabled) return;
    // When audio is routed to the TV, the TV browser speaks it (Web Speech);
    // the phone stays silent so the two don't overlap.
    if (state.castAudioTarget != CastAudioTarget.phone) return;

    final settings = ref.read(settingsProvider);
    if (withCue && settings.soundEffects) _audio().cue();
    if (!settings.ttsEnabled) return;

    var (en, fil) = _currentSpeechText();
    // The language filter governs what's spoken as well as what's shown —
    // hearing a language the TV isn't displaying would be more confusing than
    // silence, especially for the cognitive-disability profiles.
    if (state.castLanguage == CastLanguage.english) fil = '';
    if (state.castLanguage == CastLanguage.filipino) en = '';
    if (en.isEmpty && fil.isEmpty) return;
    unawaited(_audio().speakBoth(en, fil));
  }

  /// The (English, Filipino) text for whatever Flashcard word / Story page is
  /// currently showing. Empty strings for modes that don't speak words
  /// (progress / live / idle). Shared by auto-narration and on-demand replay.
  (String, String) _currentSpeechText() {
    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final cards = _currentCards();
        if (cards.isEmpty) return ('', '');
        final card = cards[state.slideIndex % cards.length];
        return (card.wordEnglish, card.wordFilipino);
      case CastMode.story:
        if (state.storyFinished) return ('', '');
        final story = _currentStory();
        if (story == null) return ('', '');
        final pagesEn = story.sentencesEn;
        final pagesFil = story.sentencesFil;
        final idx = state.storyPageIndex.clamp(0, pagesEn.length - 1);
        final en = idx < pagesEn.length ? pagesEn[idx] : '';
        final fil = idx < pagesFil.length ? pagesFil[idx] : '';
        return (en, fil);
      case CastMode.live:
        // Mirrors the TV's `liveSpeechText`: the question plus its lettered
        // choices, so a class listening on the phone's speaker hears the same
        // thing a TV would say. Filipino is empty — activities are authored in
        // one language by the educator, so there's no second string to read.
        final activity = state.liveActivity;
        if (activity == null) return ('', '');
        return (_liveSpeechText(activity), '');
      case CastMode.progress:
      case CastMode.idle:
        return ('', '');
    }
  }

  /// Spoken form of a live question. Kept in step with `liveSpeechText` in the
  /// TV-side `app.js`; the correct answer is deliberately not part of it.
  String _liveSpeechText(LiveActivity activity) {
    final parts = <String>[];
    switch (activity.type) {
      case LiveActivityType.fslSign:
        parts.add('Watch the sign, then pick the word.');
      case LiveActivityType.pictureChoice:
        parts.add('Which word matches the picture?');
      default:
        final prompt = activity.prompt;
        if (prompt.trim().isNotEmpty) parts.add(prompt);
    }
    if (activity.type == LiveActivityType.trueFalse) {
      parts.add('True, or false?');
    } else {
      final options = activity.options;
      for (var i = 0; i < options.length; i++) {
        parts.add('${String.fromCharCode(65 + i)}. ${options[i]}');
      }
    }
    return parts.join(' ');
  }

  /// Re-speaks the current Flashcard word / Story page on the educator's phone
  /// in a single language. Backs the on-demand "Replay" buttons on the cast
  /// screen: it always plays from the phone (the control device), independent
  /// of the TV/phone audio target, and is a no-op when Text-to-Speech is off or
  /// there is nothing to say.
  void replayCurrentWord({required bool filipino}) {
    final (en, fil) = _currentSpeechText();
    final text = filipino ? fil : en;
    if (text.trim().isEmpty) return;

    // When casting audio to the TV, ask the TV browser to re-speak the current
    // item (so "Replay" works on the TV, not just this phone). Bumping the
    // nonce + revision is what the TV polls and acts on.
    if (state.isServerRunning && state.castAudioTarget == CastAudioTarget.tv) {
      state = state.copyWith(
        ttsReplayNonce: state.ttsReplayNonce + 1,
        ttsReplayLang: filipino ? 'fil' : 'en',
        revision: state.revision + 1,
      );
      return;
    }

    // Otherwise model it on this phone (unchanged behaviour).
    if (!ref.read(settingsProvider).ttsEnabled) return;
    unawaited(_audio().speakOne(text, filipino: filipino));
  }

  // ─── Server lifecycle ─────────────────────────────────

  Future<void> startServer() async {
    if (state.isServerRunning) return;

    // Make sure the FSL video manifest is parsed before the server can be
    // polled. `_enrichState` reports availability synchronously off these
    // maps, and the TV only repaints on revision changes — so if it polled
    // an FSL card before `load()` finished it would show "no video" and never
    // recover. Awaiting here closes that race (it's a fast local asset read).
    await FslAssetsService.load();

    // Likewise parse the flashcard photo manifest so `_enrichState` reports the
    // right `slide.photo` availability from its first poll. Idempotent (it's
    // also loaded at app startup), so this only awaits a ready Future normally.
    await FlashcardPhotoService.load();

    // And the "Show Me" action-clip manifest, so `_enrichState` reports the
    // right `slide.clip` availability (and the phone-side "Show Me" button
    // appears) without waiting on a download. Idempotent / loaded at startup.
    await ActionClipService.load();

    final ip = await TvCastIpDiscovery.findLocalIp();
    if (ip == null) {
      state = state.copyWith(clearListenUrl: true, isServerRunning: false);
      return;
    }

    _server ??= TvCastServer(
      getSession: () => state,
      onTvAudioReport: _onTvAudioReport,
      onRemoteAction: _onRemoteAction,
    );
    final port = await _server!.start();
    // The URL carries the session code the server just minted — the TV proves
    // it was invited simply by opening the link the teacher showed it.
    final url = 'http://$ip:$port${_server!.basePath}';

    // Respect the educator's accessibility setting out of the box: if the app
    // is in high-contrast mode, default the TV output to the high-contrast
    // theme too. They can still switch it from the cast screen.
    final settings = ref.read(settingsProvider);
    final highContrast = settings.highContrastMode;

    state = state.copyWith(
      isServerRunning: true,
      listenUrl: url,
      port: port,
      castCode: _server!.sessionToken,
      castTheme: highContrast ? CastTheme.highContrast : CastTheme.dark,
      // Mirror the accessibility setting so the TV can drop animations.
      reducedMotion: settings.reducedMotion,
      revision: state.revision + 1,
    );

    _sessionStartedAt = DateTime.now();
    _modesUsed.clear();
    _cardsShown = 0;
    _storyPagesShown = 0;
    _liveQuestionsPushed = 0;
    _liveAnswersBanked = 0;
    _peakViewers = 0;

    // Ask Android to keep this process alive for the duration. Best-effort:
    // if it's refused the cast is unchanged, it just loses the guarantee.
    // The permission prompt (Android 13+) is fired first so the ongoing
    // notification is actually visible — but not awaited on the critical path,
    // and a refusal is fine: the service still runs, just silently.
    unawaited(() async {
      try {
        await NotificationService.requestPermission();
      } catch (_) {
        // Never let a permission hiccup block a cast that's already serving.
      }
      await TvCastKeepAlive.start(
        code: state.castCode ?? '',
        detail: _keepAliveDetail(),
      );
    }());

    // Tick the connected-viewer count every 2 s so the phone UI shows
    // how many TVs/browsers are currently pulling state.
    _viewerTickTimer?.cancel();
    _viewerTickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final n = _server?.activeViewerCount ?? 0;
      if (n > _peakViewers) _peakViewers = n;
      if (n != state.connectedViewers) {
        state = state.copyWith(connectedViewers: n);
        _refreshKeepAlive();
      }
      // The lesson timer isn't ticked on this side (see [startTimer]) — nothing
      // would otherwise notice it hitting zero, so piggyback the check here.
      // Within 2 s is plenty for a classroom cue.
      if (state.isTimerFinished && !_timerChimed) {
        _timerChimed = true;
        if (ref.read(settingsProvider).soundEffects) _audio().cue();
      }
    });

    _autoplay ??= TvCastAutoplayController(onTick: _advanceFromAutoplay);
  }

  /// One-line status for the ongoing notification, so a teacher glancing at
  /// the shade sees what the class is looking at without opening the app.
  String _keepAliveDetail() {
    if (state.isAway) return 'Showing "the teacher is out" — tap to resume.';
    final viewers = state.connectedViewers;
    final who = viewers == 0
        ? 'No TV connected yet'
        : '$viewers ${viewers == 1 ? 'TV' : 'TVs'} watching';
    final what = switch (state.mode) {
      CastMode.flashcards => 'Flashcards',
      CastMode.fslVideo => 'FSL signs',
      CastMode.story => 'Stories',
      CastMode.progress => 'Progress',
      CastMode.live => 'Live Activity',
      CastMode.idle => 'Nothing selected',
    };
    return '$what · $who';
  }

  /// Pushes the current mode / viewer count into the ongoing notification.
  /// No-op when no cast is running.
  void _refreshKeepAlive() {
    if (!state.isServerRunning) return;
    unawaited(
      TvCastKeepAlive.update(
        code: state.castCode ?? '',
        detail: _keepAliveDetail(),
      ),
    );
  }

  /// What the cast that's running right now has done so far. Null when nothing
  /// is casting. Read by [stopServer] to hand the educator a receipt.
  TvCastSessionSummary? get sessionSummary {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) return null;
    return TvCastSessionSummary(
      startedAt: startedAt,
      duration: DateTime.now().difference(startedAt),
      modesUsed: List.unmodifiable(_modesUsed),
      cardsShown: _cardsShown,
      storyPagesShown: _storyPagesShown,
      liveQuestionsPushed: _liveQuestionsPushed,
      // The question still on screen hasn't been banked yet.
      liveAnswers: _liveAnswersBanked + state.liveResponders,
      peakViewers: _peakViewers,
    );
  }

  Future<void> stopServer() async {
    _autoplay?.stop();
    unawaited(_narrator?.stop());
    _viewerTickTimer?.cancel();
    _viewerTickTimer = null;
    _stopProgressWatch();
    unawaited(TvCastKeepAlive.stop());
    // Persist the finished cast before dropping the tally. Best-effort: a
    // failed write must not stop the cast from shutting down cleanly.
    final finished = sessionSummary;
    final profile = ref.read(profileProvider);
    if (finished != null && finished.hasContent && profile != null) {
      try {
        await HiveService.addCastSession(profile.id, finished.toJson());
        ref.invalidate(castSessionHistoryProvider(profile.id));
      } catch (_) {
        // History is a convenience; losing one entry is not worth failing on.
      }
    }
    _sessionStartedAt = null; // the tally is a receipt, not live state
    await _endLiveSession(); // ends the Firestore session + cancels streams
    await _server?.stop();
    state = state.copyWith(
      isServerRunning: false,
      mode: CastMode.idle,
      isPaused: false,
      isAway: false,
      tvAudioStatus: TvAudioStatus.unknown,
      slideIndex: 0,
      clearListenUrl: true,
      clearCategory: true,
      clearStoryId: true,
      storyPageIndex: 0,
      connectedViewers: 0,
      clearLiveActivity: true,
      clearLiveSession: true,
      liveResponders: 0,
      liveScoreboard: const [],
      raisedHands: const [],
      revision: state.revision + 1,
    );
  }

  // ─── Mode + content selection ─────────────────────────

  void setMode(CastMode mode) {
    if (state.mode == mode) return;

    state = state.copyWith(
      mode: mode,
      slideIndex: 0,
      storyPageIndex: 0,
      isPaused: false,
      showMeActive: false,
      storyFslActive: false,
      storyImageFlipped: false,
      storyFinished: false,
      cardFlipped: false,
      revision: state.revision + 1,
    );

    if (mode == CastMode.flashcards ||
        mode == CastMode.fslVideo ||
        mode == CastMode.story) {
      if (state.autoAdvanceEnabled) {
        _autoplay?.resume();
        _autoplay?.start(interval: _autoplayIntervalFor(mode));
      } else {
        _autoplay?.stop();
      }
      if (mode == CastMode.fslVideo) _prefetchFslAround();
      if (mode == CastMode.story) {
        _prefetchStoryFslAround();
        _prefetchStoryImagesAround();
      }
      _narrateCurrent();
    } else if (mode == CastMode.progress) {
      _startProgressWatch();
      _autoplay?.stop();
      unawaited(_narrator?.stop());
    } else {
      _autoplay?.stop();
      unawaited(_narrator?.stop());
    }
    if (mode != CastMode.progress) _stopProgressWatch();
    if (mode != CastMode.idle && !_modesUsed.contains(mode)) {
      _modesUsed.add(mode);
    }
    _refreshKeepAlive();
  }

  /// Subscribes to the roster and starts the backstop tick so the TV's progress
  /// display keeps up with the class on its own. Idempotent.
  void _startProgressWatch() {
    _refreshProgress();
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _rosterSub?.close();
      // Listening (not reading) is what keeps the roster provider alive and
      // pushes changes at us — `_refreshProgress` alone only ever saw whatever
      // snapshot happened to be cached.
      _rosterSub = ref.listen(
        educatorRosterProvider(profile.id),
        (previous, next) => _refreshProgress(),
      );
    }
    _progressTickTimer?.cancel();
    _progressTickTimer = Timer.periodic(
      _progressBackstopInterval,
      (_) => _refreshProgress(),
    );
  }

  void _stopProgressWatch() {
    _rosterSub?.close();
    _rosterSub = null;
    _progressTickTimer?.cancel();
    _progressTickTimer = null;
  }

  void setCategory(FlashcardCategory category) {
    state = state.copyWith(
      category: category,
      slideIndex: 0,
      showMeActive: false,
      cardFlipped: false,
      revision: state.revision + 1,
    );
    if (state.mode == CastMode.fslVideo) _prefetchFslAround();
    _narrateCurrent();
  }

  /// Jumps directly to a specific card and pauses autoplay so the teacher can
  /// dwell on a chosen sign. Used by the phone-side per-word picker.
  void jumpToSlide(int index) {
    final cards = _currentCards();
    if (cards.isEmpty) return;
    final clamped = index % cards.length;
    state = state.copyWith(
      slideIndex: clamped,
      isPaused: true,
      showMeActive: false,
      cardFlipped: false,
      revision: state.revision + 1,
    );
    _autoplay?.pause();
    if (state.mode == CastMode.fslVideo) _prefetchFslAround();
    _narrateCurrent();
  }

  /// Switches the TV display template. The TV picks it up on its next state
  /// poll (~1.5s). For the seasonal template we resolve the active event's
  /// emoji + accent colour and stash them so the TV can paint festive accents
  /// inline; switching away clears them.
  void setCastTheme(CastTheme theme) {
    if (state.castTheme == theme) return;
    if (theme == CastTheme.seasonal) {
      final event = ref.read(seasonalEventProvider);
      state = state.copyWith(
        castTheme: theme,
        seasonalEmoji: event?.emoji,
        seasonalAccent: event != null ? _hexOf(event.primaryColor) : null,
        revision: state.revision + 1,
      );
    } else {
      state = state.copyWith(
        castTheme: theme,
        clearSeasonal: true,
        revision: state.revision + 1,
      );
    }
  }

  /// Sets how big the TV's lesson text is. The TV picks it up on its next poll
  /// and re-lays out immediately — no reload needed.
  void setCastTextSize(CastTextSize size) {
    if (state.castTextSize == size) return;
    state = state.copyWith(castTextSize: size, revision: state.revision + 1);
  }

  /// Sets which language the TV shows *and* speaks. Re-narrates the current
  /// item so the change is audible right away rather than at the next slide.
  void setCastLanguage(CastLanguage language) {
    if (state.castLanguage == language) return;
    state = state.copyWith(castLanguage: language, revision: state.revision + 1);
    _narrateCurrent(withCue: false);
  }

  /// Sets (or clears) the optional branding text shown on the TV. Trimmed;
  /// empty becomes null (hides the header).
  void setCastTitle(String? title) {
    final trimmed = title?.trim();
    final next = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (next == state.castTitle) return;
    state = state.copyWith(
      castTitle: next,
      clearCastTitle: next == null,
      revision: state.revision + 1,
    );
  }

  /// `#RRGGBB` for a [Color], using the float channel accessors (the app
  /// targets a Flutter version with `withValues`, so `.r/.g/.b` are present).
  String _hexOf(Color c) {
    String two(double channel) =>
        (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${two(c.r)}${two(c.g)}${two(c.b)}';
  }

  /// Master toggle for spoken word / story narration. Bumps the revision so
  /// the TV picks up the changed `ttsOnTv`. Stops phone speech when turned off;
  /// when turned on, speaks the current item if audio is routed to the phone.
  void setCastAudioEnabled(bool enabled) {
    if (state.castAudioEnabled == enabled) return;
    state = state.copyWith(
      castAudioEnabled: enabled,
      revision: state.revision + 1,
    );
    if (!enabled) {
      unawaited(_narrator?.stop());
    } else {
      _narrateCurrent(withCue: false);
    }
  }

  /// Routes Flashcards/Stories speech to the TV browser or the phone. Bumps
  /// the revision so the TV picks up the changed `ttsOnTv`. Stops the phone
  /// when switching to TV; speaks the current item when switching to phone.
  void setCastAudioTarget(CastAudioTarget target) {
    if (state.castAudioTarget == target) return;
    state = state.copyWith(
      castAudioTarget: target,
      revision: state.revision + 1,
    );
    if (target == CastAudioTarget.tv) {
      unawaited(_narrator?.stop());
    } else {
      _narrateCurrent(withCue: false);
    }
  }

  /// Toggles whether the TV `<video>` plays its own audio track. Bumps the
  /// revision so connected TVs pick it up on their next poll.
  void setTvVideoSound(bool enabled) {
    if (state.tvVideoSoundEnabled == enabled) return;
    state = state.copyWith(
      tvVideoSoundEnabled: enabled,
      revision: state.revision + 1,
    );
  }

  /// Turns "fill the whole TV" (browser fullscreen) on or off for connected
  /// TVs. Bumps the revision so they pick it up on their next poll (~1.5s): the
  /// TV-side app.js enters or exits fullscreen to match. Turning it off reliably
  /// exits everywhere; turning it on fills instantly on lenient casting devices
  /// and on the first remote OK / tap on stricter ones (e.g. Chrome on
  /// Chromecast). The TV always auto-resizes to the screen regardless.
  void setFullscreenOnTv(bool enabled) {
    if (state.fullscreenOnTv == enabled) return;
    state = state.copyWith(
      fullscreenOnTv: enabled,
      revision: state.revision + 1,
    );
  }

  /// Turns the auto-advance slideshow timer on or off. When enabled, resumes
  /// ticking for the current auto-advanceable mode (flashcards / FSL / story)
  /// unless paused or the teacher is away; when disabled, stops the timer so
  /// the cast stays on the current item until the educator taps Next.
  void setAutoAdvanceEnabled(bool enabled) {
    if (state.autoAdvanceEnabled == enabled) return;
    state = state.copyWith(
      autoAdvanceEnabled: enabled,
      revision: state.revision + 1,
    );
    final mode = state.mode;
    final canAuto = mode == CastMode.flashcards ||
        mode == CastMode.fslVideo ||
        mode == CastMode.story;
    if (enabled) {
      if (canAuto && !state.isPaused && !state.isAway) {
        _autoplay?.resume();
        _autoplay?.start(interval: _autoplayIntervalFor(mode));
      }
    } else {
      _autoplay?.stop();
    }
  }

  /// Enables/disables the flashcard photo-flip feature (the "Tap Only" control).
  /// When off, the TV flashcard shows the emoji only (no photo). Always resets
  /// the card back to the emoji face. Bumps the revision so connected TVs pick
  /// it up on their next poll (~1.5s).
  void setFlipTapOnly(bool enabled) {
    if (state.flipTapOnly == enabled) return;
    state = state.copyWith(
      flipTapOnly: enabled,
      cardFlipped: false,
      revision: state.revision + 1,
    );
  }

  /// Flips the current TV flashcard between the emoji and the real photograph
  /// (the phone-side "Flip" button). Works on any receiver — including TVs you
  /// can't touch — because the TV renders the face from this flag and animates
  /// the 3D flip when it changes. No-op unless the photo-flip feature is on.
  void flipCard() {
    if (!state.flipTapOnly) return;
    state = state.copyWith(
      cardFlipped: !state.cardFlipped,
      revision: state.revision + 1,
    );
  }

  /// Shows or hides the current flashcard's "Show Me" action clip on the TV.
  /// Activating pauses autoplay (and phone narration) so the clip isn't cut off
  /// mid-play — mirroring the per-word FSL picker; the clip auto-hides when the
  /// card changes (see [next] / [prev] / [jumpToSlide] / [setCategory]).
  void setShowMe(bool show) {
    if (state.showMeActive == show) return;
    if (show) {
      state = state.copyWith(
        showMeActive: true,
        isPaused: true,
        revision: state.revision + 1,
      );
      _autoplay?.pause();
      unawaited(_narrator?.stop());
    } else {
      state = state.copyWith(showMeActive: false, revision: state.revision + 1);
    }
  }

  /// Shows or hides the current story page's FSL sign-language video on the TV
  /// (the phone-side "Watch in FSL" button). Activating pauses autoplay (and
  /// phone narration) so the clip isn't cut off mid-play — mirroring the
  /// flashcard "Show Me" button; the clip auto-hides when the page / story
  /// changes (see [next] / [prev] / [setStory] / [setMode]). No-op unless the
  /// current page actually has an FSL clip (the phone only shows the button then).
  void setStoryFsl(bool show) {
    if (state.storyFslActive == show) return;
    if (show) {
      state = state.copyWith(
        storyFslActive: true,
        isPaused: true,
        revision: state.revision + 1,
      );
      _autoplay?.pause();
      unawaited(_narrator?.stop());
    } else {
      state = state.copyWith(
        storyFslActive: false,
        revision: state.revision + 1,
      );
    }
  }

  /// Flips the current TV story illustration between the cartoon and the
  /// real-life photograph (the phone-side "Tap to Flip Animation (Cartoon ↔
  /// Picture)" button). Works on any receiver — including TVs you can't touch —
  /// because the TV renders the face from this flag and animates the 3D flip
  /// when it changes. No-op unless the current page actually has a picture pair
  /// (the phone only shows the button then). Mirrors [flipCard] for Flashcards.
  void flipStoryImage() {
    final story = _currentStory();
    if (story == null) return;
    final total = story.sentencesEn.length;
    if (total == 0) return;
    final idx = state.storyPageIndex.clamp(0, total - 1);
    if (TvCastAssetBridge.storyImagePair(story, idx) == null) return;
    state = state.copyWith(
      storyImageFlipped: !state.storyImageFlipped,
      revision: state.revision + 1,
    );
  }

  void setStory(String storyId) {
    final story = SeedStories.all.firstWhere(
      (s) => s.id == storyId,
      orElse: () => SeedStories.all.first,
    );
    state = state.copyWith(
      mode: CastMode.story,
      storyId: story.id,
      storyPageIndex: 0,
      isPaused: false,
      storyFslActive: false,
      storyImageFlipped: false,
      storyFinished: false,
      revision: state.revision + 1,
    );
    if (state.autoAdvanceEnabled) {
      _autoplay?.resume();
      _autoplay?.start(interval: _autoplayIntervalFor(CastMode.story));
    } else {
      _autoplay?.stop();
    }
    _prefetchStoryFslAround();
    _prefetchStoryImagesAround();
    _narrateCurrent();
    _refreshKeepAlive();
  }

  // ─── Remote controls ──────────────────────────────────

  void next() {
    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final cards = _currentCards();
        if (cards.isEmpty) return;
        state = state.copyWith(
          slideIndex: (state.slideIndex + 1) % cards.length,
          showMeActive: false,
          cardFlipped: false,
          revision: state.revision + 1,
        );
        _cardsShown++;
        if (state.mode == CastMode.fslVideo) _prefetchFslAround();
        _narrateCurrent();
        break;
      case CastMode.story:
        final story = _currentStory();
        if (story == null) return;
        if (state.storyPageIndex < story.sentencesEn.length - 1) {
          state = state.copyWith(
            storyPageIndex: state.storyPageIndex + 1,
            storyFslActive: false,
            storyImageFlipped: false,
            revision: state.revision + 1,
          );
          _storyPagesShown++;
          _prefetchStoryFslAround();
          _prefetchStoryImagesAround();
          _narrateCurrent();
        } else if (!state.storyFinished) {
          // Past the last page: close the book rather than leaving the class on
          // the final sentence with the autoplay timer still ticking into
          // nothing. Autoplay stops here — the next move is the teacher's.
          _finishStory();
        }
        break;
      case CastMode.progress:
        _refreshProgress();
        break;
      case CastMode.live:
      case CastMode.idle:
        break;
    }
  }

  void prev() {
    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final cards = _currentCards();
        if (cards.isEmpty) return;
        final next = state.slideIndex - 1;
        state = state.copyWith(
          slideIndex: next < 0 ? cards.length - 1 : next,
          showMeActive: false,
          cardFlipped: false,
          revision: state.revision + 1,
        );
        if (state.mode == CastMode.fslVideo) _prefetchFslAround();
        _narrateCurrent();
        break;
      case CastMode.story:
        if (state.storyFinished) {
          // Back from "The End" returns to the last page, so a teacher can
          // re-read the ending without restarting the whole story.
          state = state.copyWith(
            storyFinished: false,
            revision: state.revision + 1,
          );
          _narrateCurrent();
          return;
        }
        if (state.storyPageIndex > 0) {
          state = state.copyWith(
            storyPageIndex: state.storyPageIndex - 1,
            storyFslActive: false,
            storyImageFlipped: false,
            revision: state.revision + 1,
          );
          _prefetchStoryFslAround();
          _prefetchStoryImagesAround();
          _narrateCurrent();
        }
        break;
      case CastMode.progress:
      case CastMode.live:
      case CastMode.idle:
        break;
    }
  }

  void togglePause() {
    final paused = !state.isPaused;
    state = state.copyWith(isPaused: paused, revision: state.revision + 1);
    if (paused) {
      _autoplay?.pause();
      unawaited(_narrator?.stop());
    } else if (state.autoAdvanceEnabled &&
        (state.mode == CastMode.flashcards ||
            state.mode == CastMode.fslVideo ||
            state.mode == CastMode.story)) {
      _autoplay?.resume();
    }
  }

  /// Steps the teacher away: the TV swaps to a "The teacher is out" screen while
  /// the server keeps running so the cast resumes the moment they're back. Holds
  /// autoplay + narration so nothing advances behind the away screen. Turning it
  /// off resumes autoplay for the slide modes (unless paused). Bumps `revision`
  /// so connected TVs pick up the change on their next poll (~1.5s).
  void setAway(bool away) {
    if (state.isAway == away) return;
    state = state.copyWith(isAway: away, revision: state.revision + 1);
    if (away) {
      _autoplay?.pause();
      unawaited(_narrator?.stop());
    } else if (!state.isPaused &&
        state.autoAdvanceEnabled &&
        (state.mode == CastMode.flashcards ||
            state.mode == CastMode.fslVideo ||
            state.mode == CastMode.story)) {
      _autoplay?.resume();
      _narrateCurrent(withCue: false);
    }
    _refreshKeepAlive();
  }

  // ─── Internal helpers ─────────────────────────────────

  /// Closes the story: the TV swaps to the "The End" screen and autoplay
  /// halts. Also stops phone narration — there is nothing left to read.
  void _finishStory() {
    state = state.copyWith(
      storyFinished: true,
      storyFslActive: false,
      storyImageFlipped: false,
      revision: state.revision + 1,
    );
    _autoplay?.pause();
    unawaited(_narrator?.stop());
    // A soft cue marks the ending for learners who aren't reading the screen.
    if (state.castAudioEnabled &&
        state.castAudioTarget == CastAudioTarget.phone &&
        ref.read(settingsProvider).soundEffects) {
      _audio().cue();
    }
  }

  void _advanceFromAutoplay() {
    if (state.isPaused || !state.autoAdvanceEnabled) return;
    // A closed story has nowhere to advance to; leave the ending on screen.
    if (state.mode == CastMode.story && state.storyFinished) return;
    next();
  }

  /// Folds a TV's reported Web Speech ability (from its `/api/state` poll) into
  /// [TvCastSession.tvAudioStatus] so the phone can explain why the TV is or
  /// isn't speaking. Updates only on change and **without** bumping `revision`
  /// (this is phone-UI-only info — the TV must not repaint for it), mirroring
  /// the `connectedViewers` tick.
  void _onTvAudioReport({required bool supported, required bool unlocked}) {
    final next = !supported
        ? TvAudioStatus.unsupported
        : (unlocked ? TvAudioStatus.ready : TvAudioStatus.needsTap);
    if (next == state.tvAudioStatus) return;
    state = state.copyWith(tvAudioStatus: next);
  }

  /// Handles a TV pressing ◀ ▶ / play-pause on its own remote.
  ///
  /// Routed through the same methods the phone's buttons call, so remote and
  /// phone can't drift apart — and so stepping from the TV pauses autoplay and
  /// re-narrates exactly like stepping from the tablet.
  void _onRemoteAction(String action) {
    switch (action) {
      case 'next':
        next();
      case 'prev':
        prev();
      case 'playpause':
        togglePause();
    }
  }

  // ─── Lesson timer ─────────────────────────────────────

  /// Starts a countdown the whole room can see, overlaid on whatever is being
  /// cast. Replaces any existing timer.
  ///
  /// Only the *deadline* is stored — nothing ticks on this side. A per-second
  /// state change would bump `revision`, and the TV rebuilds its stage on every
  /// revision, so a running timer would restart a playing sign clip once a
  /// second. The TV counts down locally and re-syncs from `secondsLeft` on each
  /// poll instead.
  void startTimer(Duration duration, {String? label}) {
    final seconds = duration.inSeconds;
    if (seconds <= 0) return;
    final trimmed = label?.trim();
    state = state.copyWith(
      timerEndsAt: DateTime.now().add(duration),
      timerTotalSeconds: seconds,
      timerLabel: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      // Drop any freeze from a previous paused timer.
      clearTimerPause: true,
      revision: state.revision + 1,
    );
    _timerChimed = false;
    _refreshKeepAlive();
  }

  /// Freezes the clock, keeping the remaining time.
  void pauseTimer() {
    if (state.timerEndsAt == null || state.timerPausedSecondsLeft != null) {
      return;
    }
    state = state.copyWith(
      timerPausedSecondsLeft: state.timerSecondsLeft ?? 0,
      revision: state.revision + 1,
    );
  }

  /// Resumes from wherever the clock was frozen.
  void resumeTimer() {
    final left = state.timerPausedSecondsLeft;
    if (left == null) return;
    state = state.copyWith(
      timerEndsAt: DateTime.now().add(Duration(seconds: left)),
      clearTimerPause: true,
      revision: state.revision + 1,
    );
    _timerChimed = false;
  }

  /// Removes the timer entirely (the TV drops the overlay).
  void clearTimer() {
    if (state.timerEndsAt == null && state.timerPausedSecondsLeft == null) {
      return;
    }
    state = state.copyWith(clearTimer: true, revision: state.revision + 1);
    _timerChimed = false;
    _refreshKeepAlive();
  }

  /// Turns the TV's own remote on or off as a control surface. Bumps the
  /// revision so a connected TV stops (or starts) binding its arrow keys.
  void setTvRemoteEnabled(bool enabled) {
    if (state.tvRemoteEnabled == enabled) return;
    state = state.copyWith(
      tvRemoteEnabled: enabled,
      revision: state.revision + 1,
    );
  }

  /// Auto-advance cadence per mode: signs dwell longest (8s) so the clip can
  /// play, story pages get reading time (7s), and flashcards flip at 4s.
  Duration _autoplayIntervalFor(CastMode mode) => switch (mode) {
        CastMode.fslVideo => const Duration(seconds: 8),
        CastMode.story => const Duration(seconds: 7),
        _ => const Duration(seconds: 4), // flashcards
      };

  /// Warms up the FSL video disk cache for the current card and the next one
  /// so the TV can stream them without waiting on a download. Fire-and-forget;
  /// [FslAssetsService.prefetch] no-ops when a clip is already cached.
  void _prefetchFslAround() {
    final cat = state.category;
    if (cat == null) return;
    final cards = SeedData.getByCategory(cat);
    if (cards.isEmpty) return;
    final i = state.slideIndex % cards.length;
    final next = (i + 1) % cards.length;
    unawaited(FslAssetsService.prefetch(cards[i]));
    if (next != i) unawaited(FslAssetsService.prefetch(cards[next]));
  }

  /// Warms up the FSL video disk cache for the current story page and the next
  /// one so the TV can stream the sign-language clip the moment the teacher taps
  /// "Watch in FSL" — without waiting on a download. Fire-and-forget;
  /// [FslAssetsService.prefetchUrl] no-ops when a clip is already cached or the
  /// page has no FSL URL. Keyed identically to the in-app reader so a clip the
  /// learner already watched is reused instantly.
  void _prefetchStoryFslAround() {
    final story = _currentStory();
    if (story == null) return;
    final total = story.sentencesEn.length;
    if (total == 0) return;
    final i = state.storyPageIndex.clamp(0, total - 1);
    void warm(int idx) {
      if (idx < 0 || idx >= total) return;
      final url = TvCastAssetBridge.storyFslUrl(story, idx);
      if (url == null) return;
      unawaited(
        FslAssetsService.prefetchUrl(
          url,
          cacheKey: TvCastAssetBridge.storyFslCacheKey(story.id, idx),
        ),
      );
    }

    warm(i);
    warm(i + 1);
  }

  /// Warms the story-picture disk cache for the current page and the next so the
  /// cartoon paints immediately and the real photo is ready the moment the
  /// teacher flips. Fire-and-forget; [TvCastAssetBridge.storyImageFile] no-ops
  /// when a picture is already resolved this session. Keyed identically to the
  /// in-app reader so a picture the learner already saw is reused instantly.
  void _prefetchStoryImagesAround() {
    final story = _currentStory();
    if (story == null) return;
    final total = story.sentencesEn.length;
    if (total == 0) return;
    final i = state.storyPageIndex.clamp(0, total - 1);
    void warm(int idx) {
      if (idx < 0 || idx >= total) return;
      final pair = TvCastAssetBridge.storyImagePair(story, idx);
      if (pair == null) return;
      unawaited(
        TvCastAssetBridge.storyImageFile(
          pair.cartoonUrl,
          TvCastAssetBridge.storyImageCacheKey(story.id, idx, real: false),
        ),
      );
      unawaited(
        TvCastAssetBridge.storyImageFile(
          pair.realUrl,
          TvCastAssetBridge.storyImageCacheKey(story.id, idx, real: true),
        ),
      );
    }

    warm(i);
    warm(i + 1);
  }

  /// Warms the FSL disk cache for a live question's flashcard so the TV can
  /// stream the sign the moment the question lands. Fire-and-forget and a
  /// no-op for text-only questions, cards with no clip, or an already-cached
  /// one — same contract as [_prefetchFslAround].
  void _prefetchLiveActivityClip(LiveActivity activity) {
    final id = activity.flashcardId;
    if (id == null || id.isEmpty) return;
    for (final card in SeedData.allFlashcards) {
      if (card.id == id) {
        unawaited(FslAssetsService.prefetch(card));
        return;
      }
    }
  }

  List _currentCards() {
    final cat = state.category;
    if (cat == null) return const [];
    return SeedData.getByCategory(cat);
  }

  Story? _currentStory() {
    final id = state.storyId;
    if (id == null) return null;
    try {
      return SeedStories.all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Switches the TV between the ranked leaderboard and the non-competitive
  /// class view. Both datasets are already in state, so this only bumps the
  /// revision — the TV repaints on its next poll with nothing to fetch.
  void setCastProgressView(CastProgressView view) {
    if (state.castProgressView == view) return;
    state = state.copyWith(
      castProgressView: view,
      revision: state.revision + 1,
    );
  }

  /// Re-derives *both* progress displays from the educator roster and pushes a
  /// new revision IFF something actually changed (avoids flicker-repainting the
  /// TV on every tick).
  ///
  /// One roster read feeds the ranked top-10 and the alphabetical class
  /// summary, so switching views costs nothing and the two can't disagree.
  void _refreshProgress() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final rosterAsync = ref.read(educatorRosterProvider(profile.id));
    final List<(UserProfile, LearningProgress)> roster =
        rosterAsync.valueOrNull ?? ref.read(allProfilesWithProgressProvider);

    final students = roster
        .where((d) => d.$1.role == UserRole.student && !d.$1.isGuestPlayer)
        .toList();

    // ─ Ranked view: top 10 by stars.
    final byStars = [...students]
      ..sort((a, b) => b.$2.totalStars.compareTo(a.$2.totalStars));
    final rows = <TvCastProgressRow>[];
    for (var i = 0; i < byStars.length && i < 10; i++) {
      final (p, prog) = byStars[i];
      rows.add(
        TvCastProgressRow(
          rank: i + 1,
          name: p.name,
          wordsLearned: prog.wordsLearned,
          streakDays: prog.streakDays,
          stars: prog.totalStars,
        ),
      );
    }

    // ─ Class view: totals + everyone A–Z, rank 0 (there is no rank here).
    final byName = [...students]
      ..sort((a, b) => a.$1.name.toLowerCase().compareTo(
            b.$1.name.toLowerCase(),
          ));
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    var wordsTotal = 0;
    var starsTotal = 0;
    var activeToday = 0;
    var bestStreak = 0;
    final classRows = <TvCastProgressRow>[];
    for (final (p, prog) in byName) {
      wordsTotal += prog.wordsLearned;
      starsTotal += prog.totalStars;
      if (prog.lastActivityDate.isAfter(cutoff)) activeToday++;
      if (prog.streakDays > bestStreak) bestStreak = prog.streakDays;
      // Capped so a large class still fits on a TV without shrinking the type
      // past what the back row can read.
      if (classRows.length < 12) {
        classRows.add(
          TvCastProgressRow(
            rank: 0,
            name: p.name,
            wordsLearned: prog.wordsLearned,
            streakDays: prog.streakDays,
            stars: prog.totalStars,
          ),
        );
      }
    }
    final summary = TvCastClassSummary(
      learnerCount: students.length,
      wordsTotal: wordsTotal,
      starsTotal: starsTotal,
      activeToday: activeToday,
      bestStreak: bestStreak,
      rows: classRows,
    );

    final rowsUnchanged =
        rows.length == state.progress.length &&
        List.generate(
          rows.length,
          (i) => rows[i] == state.progress[i],
        ).every((b) => b);
    if (rowsUnchanged && summary == state.classSummary) return;

    state = state.copyWith(
      progress: rows,
      classSummary: summary,
      revision: state.revision + 1,
    );
  }

  // ─── Live interactive session ─────────────────────────

  /// Whether a live session can run right now (needs cloud sync).
  bool get canHostLive => FirebaseService.isConfigured;

  /// Starts (or resumes) the Firestore live session for [sessionKey] and
  /// subscribes to its raised hands + responses so they flow to the TV. Safe
  /// to call repeatedly — re-subscribes cleanly. Stamps the current scoring
  /// rules. No-ops (returns false) when cloud sync isn't available.
  Future<bool> startLiveSession({
    required String sessionKey,
    required LiveSessionOwnerKind ownerKind,
    LiveScoringRules scoring = const LiveScoringRules(),
    String? displayName,
  }) async {
    if (!FirebaseService.isConfigured) {
      // Still surface the chosen key/rules so the host UI can render its
      // "needs internet" notice with the right context.
      state = state.copyWith(
        liveSessionKey: sessionKey,
        liveScoring: scoring,
        revision: state.revision + 1,
      );
      return false;
    }
    await FirebaseService.ensureSignedIn();
    final profile = ref.read(profileProvider);
    if (profile == null) return false;

    try {
      await _liveService.startSession(
        sessionKey: sessionKey,
        ownerProfileId: profile.id,
        ownerKind: ownerKind,
        scoring: scoring,
      );
    } catch (_) {
      return false;
    }

    _latestResponses = const [];
    await _handsSub?.cancel();
    await _responsesSub?.cancel();

    _handsSub = _liveService.watchHands(sessionKey).listen((hands) {
      state = state.copyWith(raisedHands: hands, revision: state.revision + 1);
    });
    _responsesSub =
        _liveService.watchAllResponses(sessionKey).listen((responses) {
      _latestResponses = responses;
      _recomputeLiveAggregates();
    });

    state = state.copyWith(
      liveSessionKey: sessionKey,
      liveScoring: scoring,
      liveResponders: 0,
      liveScoreboard: const [],
      // Default the TV branding to the hosted class name (unless the educator
      // already set their own title).
      castTitle: state.castTitle ?? displayName,
      revision: state.revision + 1,
    );
    return true;
  }

  /// Pushes a new activity to every connected learner and shows it on the TV.
  Future<void> pushLiveActivity(LiveActivity activity) async {
    final key = state.liveSessionKey;
    // Bank the outgoing question's answers before liveResponders resets, so
    // the session total survives being replaced.
    _liveAnswersBanked += state.liveResponders;
    _liveQuestionsPushed++;
    state = state.copyWith(
      liveActivity: activity,
      liveResponders: 0,
      revision: state.revision + 1,
    );
    // Warm the sign clip before the TV asks for it. An fslSign question now
    // *shows* the sign, so a cold cache would leave the class staring at a
    // placeholder for the first seconds of the question.
    _prefetchLiveActivityClip(activity);
    // And read the question aloud when audio is routed to this phone (the TV
    // does its own speaking via `ttsOnTv`).
    _narrateCurrent(withCue: false);
    if (key == null || !FirebaseService.isConfigured) return;
    try {
      await _liveService.pushActivity(sessionKey: key, activity: activity);
    } catch (_) {
      // Local TV preview still updated; the learner sync just won't fire.
    }
    _recomputeLiveAggregates();
  }

  /// Clears the current question (learners see "waiting for the next one").
  Future<void> clearLiveActivity() async {
    final key = state.liveSessionKey;
    state = state.copyWith(
      clearLiveActivity: true,
      liveResponders: 0,
      revision: state.revision + 1,
    );
    if (key == null || !FirebaseService.isConfigured) return;
    try {
      await _liveService.clearActivity(key);
    } catch (_) {}
  }

  /// Updates the star-scoring rules mid-session.
  Future<void> setLiveScoring(LiveScoringRules rules) async {
    final key = state.liveSessionKey;
    state = state.copyWith(liveScoring: rules, revision: state.revision + 1);
    if (key == null || !FirebaseService.isConfigured) return;
    try {
      await _liveService.updateScoring(sessionKey: key, scoring: rules);
    } catch (_) {}
  }

  /// Educator clears a learner's raised hand (e.g. after helping them).
  Future<void> clearRaisedHand(String profileId) async {
    final key = state.liveSessionKey;
    if (key == null || !FirebaseService.isConfigured) return;
    try {
      await _liveService.lowerHand(sessionKey: key, profileId: profileId);
    } catch (_) {}
  }

  /// Ends the live session and tears down its subscriptions, but keeps the
  /// cast server running so the educator can switch back to other modes.
  Future<void> endLiveSession() async {
    await _endLiveSession();
    state = state.copyWith(
      clearLiveActivity: true,
      clearLiveSession: true,
      liveResponders: 0,
      liveScoreboard: const [],
      raisedHands: const [],
      mode: state.mode == CastMode.live ? CastMode.idle : state.mode,
      revision: state.revision + 1,
    );
  }

  Future<void> _endLiveSession() async {
    final key = state.liveSessionKey;
    await _handsSub?.cancel();
    await _responsesSub?.cancel();
    _handsSub = null;
    _responsesSub = null;
    _latestResponses = const [];
    if (key != null && FirebaseService.isConfigured) {
      try {
        await _liveService.endSession(key);
      } catch (_) {}
    }
  }

  /// Recomputes the responder count (for the current activity) and the
  /// session-wide scoreboard from the cached response set, pushing a new
  /// revision only when something actually changed.
  void _recomputeLiveAggregates() {
    final currentId = state.liveActivity?.id;
    final responders = currentId == null
        ? 0
        : _latestResponses.where((r) => r.activityId == currentId).length;
    final board = LiveSessionService.aggregateScoreboard(_latestResponses);

    final boardUnchanged =
        board.length == state.liveScoreboard.length &&
        List.generate(
          board.length,
          (i) => board[i] == state.liveScoreboard[i],
        ).every((b) => b);
    if (responders == state.liveResponders && boardUnchanged) return;

    state = state.copyWith(
      liveResponders: responders,
      liveScoreboard: board,
      revision: state.revision + 1,
    );
  }
}

final tvCastSessionProvider =
    NotifierProvider<TvCastSessionNotifier, TvCastSession>(
      TvCastSessionNotifier.new,
    );

/// An educator's finished casts, newest first.
///
/// Read straight off Hive (no stream): history only changes when a cast ends,
/// and the notifier invalidates this then. Family-keyed by educator profile id
/// so switching profiles can't show someone else's lessons.
final castSessionHistoryProvider =
    Provider.family<List<TvCastSessionSummary>, String>((ref, profileId) {
  final raw = HiveService.getCastSessions(profileId);
  final out = <TvCastSessionSummary>[];
  for (final entry in raw) {
    try {
      out.add(TvCastSessionSummary.fromJson(entry));
    } catch (_) {
      // A record written by an older build shouldn't take the list down.
    }
  }
  // Stored oldest-first; the teacher wants the most recent lesson at the top.
  return out.reversed.toList();
});
