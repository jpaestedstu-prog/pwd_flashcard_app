import 'dart:async';
import 'dart:ui' show Color, Locale;

import 'package:flutter/foundation.dart';
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
import '../../../core/services/streak_service.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/seasonal_event_provider.dart';
import '../../live_session/models/live_session_models.dart';
import '../../live_session/services/live_session_service.dart';
import '../models/cast_group_selection.dart';
import '../models/tv_cast_session.dart';
import '../services/tv_cast_asset_bridge.dart';
import '../services/tv_cast_audio_narrator.dart';
import '../services/tv_cast_autoplay_controller.dart';
import '../services/tv_cast_ip_discovery.dart';
import '../services/tv_cast_keep_alive.dart';
import '../services/tv_cast_server.dart';
import '../services/tv_cast_speech.dart';
import 'cast_group_provider.dart';

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
  // One Firestore session per hosted class / home group (see
  // [TvCastSession.liveSessionKeys]); their hands and responses are merged
  // here into the single picture the TV and the host panel show.
  final LiveSessionService _liveService = const LiveSessionService();
  final Map<String, StreamSubscription<List<RaisedHand>>> _handsSubs = {};
  final Map<String, StreamSubscription<List<LiveResponse>>> _responsesSubs =
      {};
  final Map<String, List<RaisedHand>> _handsByKey = {};

  /// Most recent full response set per hosted group, cached so the responder
  /// count + scoreboard can be recomputed when either it or the current
  /// activity changes.
  final Map<String, List<LiveResponse>> _responsesByKey = {};

  /// Serialises re-targeting the live session when the class / group picker
  /// changes mid-session, so two quick taps can't start a group twice.
  Future<void> _liveRetarget = Future.value();

  // ─── Class / group selection ──────────────────────────
  // Which of the educator's classes / home groups this cast is for. Read from
  // [castGroupSelectionProvider] (saved per profile) while a cast runs, and
  // listened to so a change in the picker reaches the TV at once.
  String? _castProfileId;
  ProviderSubscription<CastGroupSelection>? _groupSub;

  // ─── Spoken words as audio the TV plays ───────────────
  TvCastSpeech? _speech;

  /// When a TV last reported that it is speaking. The slideshow holds while a
  /// word or page is still being heard, rather than cutting it off.
  DateTime? _tvSpeakingSeenAt;
  Timer? _speechHoldTimer;
  DateTime? _speechHoldSince;

  /// Whether the autoplay timer is stopped by a speech hold (as opposed to
  /// by the educator's pause), so cancelling the hold knows to restart it.
  bool _heldForSpeech = false;

  /// Longest the slideshow waits for speech to finish before moving on
  /// anyway — a stuck report must never freeze the lesson.
  static const _maxSpeechHold = Duration(seconds: 12);

  @override
  TvCastSession build() {
    ref.onDispose(() {
      _autoplay?.dispose();
      _viewerTickTimer?.cancel();
      _speechHoldTimer?.cancel();
      _stopProgressWatch();
      _groupSub?.close();
      unawaited(TvCastKeepAlive.stop());
      unawaited(_cancelLiveStreams());
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
      baseRate: () => ref.read(settingsProvider).ttsSpeed,
    );
  }

  /// Whether the app is in Filipino — the language of a live question read
  /// aloud and of the TV's own captions.
  bool get _uiFilipino => ref.read(settingsProvider).locale == 'fil';

  /// Speaks the current word / story page from the phone and plays a soft cue,
  /// honouring the per-cast toggle and the app's accessibility settings.
  /// When the TV is the one speaking, has its audio made ahead instead.
  /// No-op unless the server is running.
  void _narrateCurrent({bool withCue = true}) {
    _cancelSpeechHold();
    if (!state.isServerRunning || !state.castAudioEnabled) return;
    // When audio is routed to the TV, the TV plays it (audio the phone makes
    // for it, or its own Web Speech); the phone stays silent so the two don't
    // overlap.
    if (state.castAudioTarget != CastAudioTarget.phone) {
      _prefetchSpeech();
      return;
    }

    final settings = ref.read(settingsProvider);
    if (withCue && settings.soundEffects) _audio().cue();
    if (!settings.ttsEnabled) return;

    final (en, fil) = _filteredSpeechText();
    if (en.isEmpty && fil.isEmpty) return;
    unawaited(
      _audio().speakBoth(en, fil, speed: state.castPlaybackSpeed.rate),
    );
  }

  /// [_currentSpeechText] with the "Language on TV" filter applied: it
  /// governs what's spoken as well as what's shown — hearing a language the
  /// TV isn't displaying would be more confusing than silence, especially for
  /// the cognitive-disability profiles. A live question is exempt: it is said
  /// in the app's language, as on the TV.
  (String, String) _filteredSpeechText() {
    var (en, fil) = _currentSpeechText();
    if (state.mode != CastMode.live) {
      if (state.castLanguage == CastLanguage.english) fil = '';
      if (state.castLanguage == CastLanguage.filipino) en = '';
    }
    return (en, fil);
  }

  /// Has the TV's audio for the item on screen — and the one after it — made
  /// now, so a word is heard the moment its card lands instead of after the
  /// TV has asked for it and waited. Fire-and-forget.
  void _prefetchSpeech() {
    final speech = _speech;
    if (speech == null || !state.isServerRunning || !state.castAudioEnabled) {
      return;
    }
    if (state.castAudioTarget != CastAudioTarget.tv) return;
    final ui = _uiFilipino;
    speech.prefetch(castSpeechLinesFor(state, uiFilipino: ui));
    final upNext = _peekNext();
    if (upNext != null) {
      speech.prefetch(castSpeechLinesFor(upNext, uiFilipino: ui));
    }
  }

  /// The session as it will be after [next], for warming the next item's
  /// audio. Null when there is no next item to warm.
  TvCastSession? _peekNext() {
    switch (state.mode) {
      case CastMode.flashcards:
        final cards = _currentCards();
        if (cards.length < 2) return null;
        return state.copyWith(
          slideIndex: (state.slideIndex + 1) % cards.length,
        );
      case CastMode.story:
        final story = _currentStory();
        if (story == null) return null;
        if (state.storyPageIndex >= story.sentencesEn.length - 1) return null;
        return state.copyWith(storyPageIndex: state.storyPageIndex + 1);
      default:
        return null;
    }
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
        // The question plus its lettered choices — the same words the TV
        // says (castLiveSpeechText), so a class listening on the phone's
        // speaker hears what a TV would. In the app's language: activities
        // are authored once, so only the instructions have a second one.
        final activity = state.liveActivity;
        if (activity == null) return ('', '');
        final filipino = _uiFilipino;
        final text = castLiveSpeechText(activity, filipino: filipino);
        return filipino ? ('', text) : (text, '');
      case CastMode.progress:
      case CastMode.idle:
        return ('', '');
    }
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
    unawaited(
      _audio().speakOne(
        text,
        filipino: filipino,
        speed: state.castPlaybackSpeed.rate,
      ),
    );
  }

  /// "Say it again" in every language on screen — the TV remote's ▲ key.
  ///
  /// When the TV is the one speaking it replays the item itself (it only sends
  /// this when the sound comes from the phone), but answering here too keeps
  /// the two paths the same: the TV is asked to re-speak through the replay
  /// nonce, otherwise this phone says it.
  void replayCurrent() {
    final (en, fil) = _filteredSpeechText();
    if (en.trim().isEmpty && fil.trim().isEmpty) return;
    if (state.isServerRunning && state.castAudioTarget == CastAudioTarget.tv) {
      state = state.copyWith(
        ttsReplayNonce: state.ttsReplayNonce + 1,
        ttsReplayLang: 'both',
        revision: state.revision + 1,
      );
      return;
    }
    if (!state.castAudioEnabled || !ref.read(settingsProvider).ttsEnabled) {
      return;
    }
    unawaited(
      _audio().speakBoth(en, fil, speed: state.castPlaybackSpeed.rate),
    );
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
      // No LAN address to hand the TV — with Wi-Fi off the device has only
      // 127.0.0.1. This genuinely cannot work, so the honest thing is to say
      // so: it used to return silently and the button looked broken.
      state = state.copyWith(
        clearListenUrl: true,
        isServerRunning: false,
        startError: _l10n.tcpNotOnWifi,
      );
      return;
    }

    // The TV's spoken words, made on this phone as audio files the TV plays
    // through its own speakers. The engine rate follows the app's own speech
    // speed (flutter_tts maps 0.5 to Android's normal 1.0), so the TV's voice
    // runs at the pace the learner is used to.
    _speech ??= TvCastSpeech(
      engineRate: () => ref.read(settingsProvider).ttsSpeed * 2,
    );
    unawaited(_speech!.prune());

    _server ??= TvCastServer(
      getSession: () => state,
      onTvAudioReport: _onTvAudioReport,
      onRemoteAction: _onRemoteAction,
      getUiLanguage: () => ref.read(settingsProvider).locale,
      speech: _speech,
    );
    final port = await _server!.start();
    // The URL carries the session code the server just minted — the TV proves
    // it was invited simply by opening the link the teacher showed it. The
    // short form (`/K7M2Q`, not `/c/K7M2Q`) is what gets shown and shared:
    // it is typed with a TV remote. The long form keeps working.
    final url = 'http://$ip:$port${_server!.shortPath}';

    // Respect the educator's accessibility setting out of the box: if the app
    // is in high-contrast mode, default the TV output to the high-contrast
    // theme too. They can still switch it from the cast screen.
    final settings = ref.read(settingsProvider);
    final highContrast = settings.highContrastMode;
    // Dyslexia-friendly mode carries to the TV too. A learner who needs Lexend
    // and looser spacing needs it most on the shared screen the lesson is read
    // from — losing the accommodation the moment the teacher casts defeats it.
    // High contrast wins when both are on: it is the stronger accommodation
    // and the app's own theme cascade resolves them the same way.
    final dyslexia = settings.dyslexiaMode;

    state = state.copyWith(
      isServerRunning: true,
      listenUrl: url,
      port: port,
      castCode: _server!.sessionToken,
      clearStartError: true,
      castTheme: highContrast
          ? CastTheme.highContrast
          : dyslexia
          ? CastTheme.dyslexia
          : CastTheme.dark,
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

    // Which classes / groups the cast is for, as picked (and saved) on the
    // cast screen — followed live, so a change reaches the TV at once.
    _watchGroups();

    // Ask Android to keep this process alive for the duration. Best-effort:
    // if it's refused the cast is unchanged, it just loses the guarantee.
    // The permission prompt (Android 13+) is fired first so the ongoing
    // notification is actually visible — but not awaited on the critical path,
    // and a refusal is fine: the service still runs, just silently.
    unawaited(() async {
      try {
        // Only where the keep-alive notification exists: on iOS the prompt
        // would ask for something the cast never shows.
        if (TvCastKeepAlive.isSupported) {
          await NotificationService.requestPermission();
        }
      } catch (_) {
        // Never let a permission hiccup block a cast that's already serving.
      }
      await TvCastKeepAlive.start(
        code: state.castCode ?? '',
        detail: _keepAliveDetail(),
        title: _keepAliveTitle(),
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
    final t = _l10n;
    if (state.isAway) return t.tcpAway;
    final viewers = state.connectedViewers;
    final who = viewers == 0 ? t.tcpNoTv : t.tcpWatching(viewers);
    final what = switch (state.mode) {
      CastMode.flashcards => t.tcFlashcards,
      CastMode.fslVideo => t.tcFslSigns,
      CastMode.story => t.tcStories,
      CastMode.progress => t.tcProgress,
      CastMode.live => t.tcLiveActivity,
      CastMode.idle => t.tcpNothing,
    };
    return '$what · $who';
  }

  /// The ongoing notification's title, in the app's language.
  String _keepAliveTitle() {
    final code = state.castCode ?? '';
    return code.isEmpty ? _l10n.tcpCasting : _l10n.tcpCastingCode(code);
  }

  /// Strings for text that leaves the widget tree (the notification shade,
  /// the start error) — the provider has no `BuildContext` to look them up.
  AppLocalizations get _l10n => lookupAppLocalizations(
    Locale(ref.read(settingsProvider).locale == 'fil' ? 'fil' : 'en'),
  );

  /// Pushes the current mode / viewer count into the ongoing notification.
  /// No-op when no cast is running.
  void _refreshKeepAlive() {
    if (!state.isServerRunning) return;
    unawaited(
      TvCastKeepAlive.update(
        code: state.castCode ?? '',
        detail: _keepAliveDetail(),
        title: _keepAliveTitle(),
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
    _cancelSpeechHold(restart: false);
    unawaited(_narrator?.stop());
    _viewerTickTimer?.cancel();
    _viewerTickTimer = null;
    _stopProgressWatch();
    _groupSub?.close();
    _groupSub = null;
    _castProfileId = null;
    _tvSpeakingSeenAt = null;
    unawaited(TvCastSpeech.release());
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

  // ─── Class / group selection ──────────────────────────

  /// Follows the educator's class / group picker for the length of the cast.
  /// Listening (not reading) keeps the saved selection alive and pushes every
  /// change here, so the TV's progress board, the live session and the
  /// audience line follow the picker without the screen telling anyone.
  void _watchGroups() {
    final profile = ref.read(profileProvider);
    _groupSub?.close();
    _groupSub = null;
    _castProfileId = profile?.id;
    if (profile == null) return;
    _groupSub = ref.listen<CastGroupSelection>(
      castGroupSelectionProvider(profile.id),
      (_, _) => _onGroupsChanged(),
    );
    _refreshAudience();
  }

  /// The educator's classes / home groups, as this device last saw them.
  List<CastGroupOption> get _groupOptions {
    final id = _castProfileId;
    return id == null ? const [] : cachedCastGroupOptions(id);
  }

  CastGroupSelection get _groupSelection {
    final id = _castProfileId;
    if (id == null) return const CastGroupSelection.all();
    return ref.read(castGroupSelectionProvider(id));
  }

  /// The groups this cast is for — every group when "All" is picked.
  List<CastGroupOption> get castGroups =>
      _groupSelection.resolve(_groupOptions);

  /// Whether the cast is for every class / group (so nothing is filtered).
  bool get _castsForAll => _groupSelection.coversAll(_groupOptions);

  void _onGroupsChanged() {
    _refreshAudience();
    if (state.mode == CastMode.progress) _refreshProgress();
    if (state.liveSessionKeys.isNotEmpty) {
      // Chained, so two quick taps re-target in order; a failure must not
      // stop the chain for every change after it.
      _liveRetarget = _liveRetarget
          .then((_) => _retargetLive())
          .catchError((Object _) {});
    }
  }

  /// Puts "who is this cast for" into the state the TV reads (`audience`).
  void _refreshAudience() {
    final label = _audienceLabel();
    if (label == state.castAudienceLabel) return;
    state = state.copyWith(
      castAudienceLabel: label,
      clearCastAudience: label == null,
      revision: state.revision + 1,
    );
  }

  /// "Hearing Class · Cognitive Class", one group's own name, or "All
  /// classes" (in the app's language). Null with no group to name.
  String? _audienceLabel() {
    final options = _groupOptions;
    if (options.isEmpty) return null;
    if (_castsForAll) {
      if (options.length == 1) return options.first.name;
      return castAllGroupsLabel(_l10n, options);
    }
    return castGroups.map((g) => g.name).join(' · ');
  }

  void setCategory(FlashcardCategory category) {
    state = state.copyWith(
      category: category,
      slideIndex: 0,
      showMeActive: false,
      cardFlipped: false,
      revision: state.revision + 1,
    );
    // The first card of the new deck gets a full beat. The slideshow timer
    // kept the phase it started with when the mode was picked, so the first
    // card could be replaced a second after it appeared — before its word
    // had even been said (seen on the tablet: "Dog" lasted ~1 s).
    if (state.autoAdvanceEnabled &&
        !state.isPaused &&
        !state.isAway &&
        (state.mode == CastMode.flashcards ||
            state.mode == CastMode.fslVideo)) {
      _autoplay?.start(interval: _autoplayIntervalFor(state.mode));
    }
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

  /// Sets how fast the TV plays its words and clips (1× / 2×). The TV applies
  /// it to whatever is playing on its next poll, without restarting anything;
  /// the phone's own narration uses it from the next word.
  void setCastPlaybackSpeed(CastPlaybackSpeed speed) {
    if (state.castPlaybackSpeed == speed) return;
    state = state.copyWith(
      castPlaybackSpeed: speed,
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

  /// Turns "fill the screen with the picture" on or off for connected TVs.
  ///
  /// The counterpart of [setFullscreenOnTv]: that one drops the *browser's*
  /// chrome, this one drops the *cast page's* — the card frame, category badge
  /// and example sentence go, and the photo / GIF / FSL clip grows to fill the
  /// stage so it is legible from the back of a classroom. The word (and, in a
  /// story, the sentence) stay on screen.
  ///
  /// Bumps the revision so TVs pick it up on their next poll (~1.5s). The TV
  /// applies it as a body class, so the change restyles what is already
  /// rendered: toggling it mid-clip does not restart the video.
  void setBigPictureOnTv(bool enabled) {
    if (state.bigPictureOnTv == enabled) return;
    state = state.copyWith(
      bigPictureOnTv: enabled,
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
    _cancelSpeechHold();
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
    _cancelSpeechHold();
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
    _cancelSpeechHold();
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
    _cancelSpeechHold();
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
    _cancelSpeechHold(restart: false);
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
    if (_holdForSpeech()) return;
    next();
  }

  // ─── Keeping the slideshow in step with the sound ─────
  // Autoplay turns the card on a fixed beat (4 s, 7 s for a story page), but a
  // long story line read in English then Filipino — or anything at a slow
  // speech rate — can still be playing when the beat comes, and the next page
  // used to cut it off mid-sentence. So the beat now waits while the current
  // item is being heard: the TV reports `spk=1` on every poll while it plays
  // a line, the phone knows when its own engine is talking. It re-checks every
  // half second and never waits longer than [_maxSpeechHold].

  bool get _inAutoplayMode =>
      state.mode == CastMode.flashcards ||
      state.mode == CastMode.fslVideo ||
      state.mode == CastMode.story;

  /// Whether the current item is still being said, wherever the sound is.
  bool _speechStillPlaying() {
    if (!state.castAudioEnabled) return false;
    if (state.castAudioTarget == CastAudioTarget.phone) {
      return TtsService.speaking.value;
    }
    final seen = _tvSpeakingSeenAt;
    return seen != null &&
        DateTime.now().difference(seen) < const Duration(milliseconds: 2500);
  }

  /// Holds the slideshow while speech is still playing. True when it holds.
  bool _holdForSpeech() {
    if (!_speechStillPlaying()) {
      _speechHoldSince = null;
      return false;
    }
    final since = _speechHoldSince ??= DateTime.now();
    if (DateTime.now().difference(since) >= _maxSpeechHold) {
      _speechHoldSince = null;
      return false;
    }
    if (!_heldForSpeech) {
      _heldForSpeech = true;
      _autoplay?.pause();
    }
    _speechHoldTimer?.cancel();
    _speechHoldTimer = Timer(
      const Duration(milliseconds: 500),
      _speechHoldTick,
    );
    return true;
  }

  void _speechHoldTick() {
    _speechHoldTimer = null;
    if (!_heldForSpeech) return;
    if (state.isPaused ||
        state.isAway ||
        !state.autoAdvanceEnabled ||
        !_inAutoplayMode) {
      // Someone else took charge of the slideshow meanwhile; leave it be.
      _heldForSpeech = false;
      _speechHoldSince = null;
      return;
    }
    if (_holdForSpeech()) return;
    next(); // cancels the hold and restarts the beat for the new item
  }

  /// Drops a speech hold — the item changed, or the educator paused. With
  /// [restart] the slideshow beat starts over (a full interval for whatever
  /// is now on screen) when it should be running.
  void _cancelSpeechHold({bool restart = true}) {
    _speechHoldTimer?.cancel();
    _speechHoldTimer = null;
    _speechHoldSince = null;
    if (!_heldForSpeech) return;
    _heldForSpeech = false;
    if (restart &&
        !state.isPaused &&
        !state.isAway &&
        state.autoAdvanceEnabled &&
        _inAutoplayMode) {
      _autoplay?.resume();
    }
  }

  /// Folds a TV's reported sound (from its `/api/state` poll) into
  /// [TvCastSession.tvAudioStatus] so the phone can explain why the TV is or
  /// isn't speaking, and notes whether it is speaking right now for the
  /// slideshow hold. Updates the status only on change and **without**
  /// bumping `revision` (this is phone-UI-only info — the TV must not repaint
  /// for it), mirroring the `connectedViewers` tick.
  void _onTvAudioReport({
    required bool supported,
    required bool unlocked,
    required bool speaking,
  }) {
    if (speaking) {
      _tvSpeakingSeenAt = DateTime.now();
    } else if (state.connectedViewers <= 1) {
      // The one TV says it has finished: no need to wait out the window.
      _tvSpeakingSeenAt = null;
    }
    final next = !supported
        ? TvAudioStatus.unsupported
        : (unlocked ? TvAudioStatus.ready : TvAudioStatus.needsTap);
    if (next == state.tvAudioStatus) return;
    state = state.copyWith(tvAudioStatus: next);
  }

  /// Handles a key pressed on the TV's own remote.
  ///
  /// Routed through the same methods the phone's buttons call, so remote and
  /// phone can't drift apart — and so stepping from the TV pauses autoplay and
  /// re-narrates exactly like stepping from the tablet. Every action means
  /// something sensible in every mode, or nothing at all.
  void _onRemoteAction(String action) {
    switch (action) {
      case 'next':
        next();
      case 'prev':
        prev();
      case 'playpause':
        togglePause();
      case 'play':
        if (state.isPaused) togglePause();
      case 'pause':
        if (!state.isPaused) togglePause();
      case 'flip':
        _remoteFlip();
      case 'showme':
        _remoteShowMe();
      case 'replay':
        replayCurrent();
      case 'back':
        _remoteBack();
    }
  }

  /// What a TV remote key does to the cast — [_onRemoteAction], for tests.
  @visibleForTesting
  void handleRemoteAction(String action) => _onRemoteAction(action);

  /// The flashcard on screen, or null outside flashcards mode.
  Flashcard? get _currentCard {
    if (state.mode != CastMode.flashcards) return null;
    final cards = _currentCards();
    if (cards.isEmpty) return null;
    return cards[state.slideIndex % cards.length] as Flashcard;
  }

  /// OK on the remote: flip the card to its photo (and back), or flip the
  /// story picture — the TV's equivalent of tapping the card in the app.
  void _remoteFlip() {
    switch (state.mode) {
      case CastMode.flashcards:
        final card = _currentCard;
        if (card != null && TvCastAssetBridge.hasPhoto(card)) flipCard();
      case CastMode.story:
        if (!state.storyFinished && !state.storyFslActive) flipStoryImage();
      default:
        break;
    }
  }

  /// ▼ on the remote: the card's "Show Me" clip, or the page's sign-language
  /// clip — on, or back off. Only where there is one to show.
  void _remoteShowMe() {
    switch (state.mode) {
      case CastMode.flashcards:
        final card = _currentCard;
        if (card != null && TvCastAssetBridge.hasActionClip(card)) {
          setShowMe(!state.showMeActive);
        }
      case CastMode.story:
        final story = _currentStory();
        if (story == null || state.storyFinished) return;
        final total = story.sentencesEn.length;
        if (total == 0) return;
        final idx = state.storyPageIndex.clamp(0, total - 1);
        if (TvCastAssetBridge.storyFslUrl(story, idx) != null) {
          setStoryFsl(!state.storyFslActive);
        }
      default:
        break;
    }
  }

  /// Back on the remote: closes whatever was opened on top of the card — a
  /// clip, then a flipped face. With nothing open the TV offers to leave the
  /// cast itself and never sends this.
  void _remoteBack() {
    if (state.showMeActive) {
      setShowMe(false);
    } else if (state.storyFslActive) {
      setStoryFsl(false);
    } else if (state.cardFlipped) {
      flipCard();
    } else if (state.storyImageFlipped) {
      flipStoryImage();
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
    // Have "Time's up!" ready as audio for the TV before the clock runs out.
    if (state.castAudioEnabled &&
        state.castAudioTarget == CastAudioTarget.tv) {
      _speech?.prefetch([castTimesUpLine(uiFilipino: _uiFilipino)]);
    }
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
    final allLocal = ref.read(allProfilesWithProgressProvider);
    // Offline, scope to what local enrolment can prove instead of every
    // learner on the device — a cast leaderboard must not put another
    // family's children on the TV. See [localEducatorRoster].
    var roster =
        rosterAsync.valueOrNull ??
        localEducatorRoster(profile.id, allLocal) ??
        allLocal;

    // Only the learners of the classes / groups this cast is for: a TV cast
    // for the Hearing class must not put the Cognitive class on the screen.
    if (!_castsForAll) {
      final groupIds = {for (final g in castGroups) g.id};
      final members = cachedCastMemberIds(groupIds, [
        for (final r in roster) r.$1,
      ]);
      roster = [
        for (final r in roster)
          if (members.contains(r.$1.id)) r,
      ];
    }

    final views = buildProgressViews(roster);
    final rows = views.ranked;
    final summary = views.summary;

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

  /// The two things the TV shows, computed from a roster: the ranked top ten
  /// and the whole-class summary.
  ///
  /// Pure and static so it can be tested without a cast session, a Firestore
  /// roster or a live TV — none of which a test can conjure, which is why the
  /// filtering below went unnoticed for so long.
  ///
  /// [now] decides who counts as active today; it defaults to the real clock
  /// but a caller can pin it rather than racing a 24-hour boundary.
  @visibleForTesting
  static ({List<TvCastProgressRow> ranked, TvCastClassSummary summary})
  buildProgressViews(
    List<(UserProfile, LearningProgress)> roster, {
    DateTime? now,
  }) {
    // `isEnrollableLearner`, not `== UserRole.student`: a Parent casting their
    // home group has `child`-role members, and filtering on `student` left
    // their TV showing an empty leaderboard. Same invariant every other
    // educator roster consumer follows — see `UserRoleX.isEnrollableLearner`.
    final students = roster
        .where((d) => d.$1.role.isEnrollableLearner && !d.$1.isGuestPlayer)
        .toList();

    final at = now ?? DateTime.now();
    // The streak as it stands on [at]: 0 after a missed day.
    int streakOf(LearningProgress prog) => StreakService.liveStreak(
          streak: prog.streakDays,
          lastActivity: prog.lastActivityDate,
          now: at,
        );

    // ─ Ranked view: top 10 by stars.
    final byStars = [...students]
      ..sort((a, b) => b.$2.totalStars.compareTo(a.$2.totalStars));
    final ranked = <TvCastProgressRow>[];
    for (var i = 0; i < byStars.length && i < 10; i++) {
      final (p, prog) = byStars[i];
      ranked.add(
        TvCastProgressRow(
          rank: i + 1,
          name: p.name,
          wordsLearned: prog.wordsLearned,
          streakDays: streakOf(prog),
          stars: prog.totalStars,
        ),
      );
    }

    // ─ Class view: totals + everyone A–Z, rank 0 (there is no rank here).
    final byName = [...students]
      ..sort((a, b) => a.$1.name.toLowerCase().compareTo(
            b.$1.name.toLowerCase(),
          ));
    final cutoff = at.subtract(const Duration(hours: 24));
    var wordsTotal = 0;
    var starsTotal = 0;
    var activeToday = 0;
    var bestStreak = 0;
    final classRows = <TvCastProgressRow>[];
    for (final (p, prog) in byName) {
      wordsTotal += prog.wordsLearned;
      starsTotal += prog.totalStars;
      if (prog.lastActivityDate.isAfter(cutoff)) activeToday++;
      if (streakOf(prog) > bestStreak) bestStreak = streakOf(prog);
      // Capped so a large class still fits on a TV without shrinking the type
      // past what the back row can read.
      if (classRows.length < 12) {
        classRows.add(
          TvCastProgressRow(
            rank: 0,
            name: p.name,
            wordsLearned: prog.wordsLearned,
            streakDays: streakOf(prog),
            stars: prog.totalStars,
          ),
        );
      }
    }

    return (
      ranked: ranked,
      summary: TvCastClassSummary(
        learnerCount: students.length,
        wordsTotal: wordsTotal,
        starsTotal: starsTotal,
        activeToday: activeToday,
        bestStreak: bestStreak,
        rows: classRows,
      ),
    );
  }

  // ─── Live interactive session ─────────────────────────

  /// Whether a live session can run right now (needs cloud sync).
  bool get canHostLive => FirebaseService.isConfigured;

  /// Starts (or resumes) a Firestore live session for each of [groups] — by
  /// default the classes / groups this cast is for ([castGroups]) — and
  /// subscribes to their raised hands + responses so they reach the TV as one
  /// session.
  ///
  /// Every group keeps its own session document, keyed by its id. A learner's
  /// app only ever opens the document of its own class or home group, so a
  /// question pushed here reaches exactly the learners of the picked groups,
  /// and nobody joins a group they don't belong to. A group whose session
  /// cannot start is left out rather than sinking the others.
  ///
  /// Safe to call repeatedly — re-subscribes cleanly. Stamps the current
  /// scoring rules. Returns false when cloud sync isn't available or no group
  /// could start.
  Future<bool> startLiveSession({
    List<CastGroupOption>? groups,
    LiveScoringRules scoring = const LiveScoringRules(),
    String? displayName,
  }) async {
    final targets = groups ?? castGroups;
    if (targets.isEmpty) return false;
    if (!FirebaseService.isConfigured) {
      // Still surface the chosen groups/rules so the host UI can render its
      // "needs internet" notice with the right context.
      state = state.copyWith(
        liveSessionKeys: [for (final g in targets) g.id],
        liveScoring: scoring,
        revision: state.revision + 1,
      );
      return false;
    }
    await FirebaseService.ensureSignedIn();
    final profile = ref.read(profileProvider);
    if (profile == null) return false;

    final started = <String>[];
    for (final g in targets) {
      try {
        await _liveService.startSession(
          sessionKey: g.id,
          ownerProfileId: profile.id,
          ownerKind: g.kind,
          scoring: scoring,
        );
        started.add(g.id);
      } catch (_) {
        // This group's learners can't be reached; the others still can.
      }
    }
    // Counts only — the device check reads which groups went live.
    debugPrint(
      'TvCastLive: hosting ${started.length} of ${targets.length} groups',
    );
    if (started.isEmpty) return false;

    await _cancelLiveStreams();
    for (final key in started) {
      _subscribeLive(key);
    }

    state = state.copyWith(
      liveSessionKeys: started,
      liveScoring: scoring,
      liveResponders: 0,
      liveScoreboard: const [],
      raisedHands: const [],
      // Default the TV branding to the hosted class name (unless the educator
      // already set their own title).
      castTitle: state.castTitle ?? displayName,
      revision: state.revision + 1,
    );
    return true;
  }

  /// Follows one hosted group's raised hands and responses.
  void _subscribeLive(String key) {
    _handsSubs[key] = _liveService.watchHands(key).listen((hands) {
      _handsByKey[key] = hands;
      _recomputeHands();
    });
    _responsesSubs[key] = _liveService.watchAllResponses(key).listen((
      responses,
    ) {
      _responsesByKey[key] = responses;
      _recomputeLiveAggregates();
    });
  }

  Future<void> _unsubscribeLive(String key) async {
    await _handsSubs.remove(key)?.cancel();
    await _responsesSubs.remove(key)?.cancel();
    _handsByKey.remove(key);
    _responsesByKey.remove(key);
  }

  Future<void> _cancelLiveStreams() async {
    for (final key in {..._handsSubs.keys, ..._responsesSubs.keys}) {
      await _unsubscribeLive(key);
    }
    _handsByKey.clear();
    _responsesByKey.clear();
  }

  /// Runs a cloud write for one group, ignoring its failure: the TV preview is
  /// already updated, and one unreachable group must not stop the others.
  Future<void> _quietly(Future<Object?> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }

  /// The learners who belong to hosted group [key], or null when this device
  /// cannot tell (no membership known) — then nobody is filtered out rather
  /// than everybody.
  Set<String>? _liveMembersOf(String key) {
    final profile = ref.read(profileProvider);
    final roster = profile == null
        ? null
        : ref.read(educatorRosterProvider(profile.id)).valueOrNull;
    final learners = [
      for (final r in roster ?? const <(UserProfile, LearningProgress)>[])
        r.$1,
    ];
    final ids = cachedCastMemberIds({key}, learners);
    return ids.isEmpty ? null : ids;
  }

  /// Hands from every hosted group as one list: only learners who belong to
  /// the group they raised it in (a stray hand from outside the class never
  /// reaches the shared screen), each learner once, oldest first.
  void _recomputeHands() {
    final merged = <String, RaisedHand>{};
    for (final entry in _handsByKey.entries) {
      final members = _liveMembersOf(entry.key);
      for (final h in entry.value) {
        if (members != null && !members.contains(h.profileId)) continue;
        final seen = merged[h.profileId];
        if (seen == null || h.raisedAt.isBefore(seen.raisedAt)) {
          merged[h.profileId] = h;
        }
      }
    }
    final hands = merged.values.toList()
      ..sort((a, b) => a.raisedAt.compareTo(b.raisedAt));
    final current = state.raisedHands;
    final same =
        hands.length == current.length &&
        List.generate(
          hands.length,
          (i) =>
              hands[i].profileId == current[i].profileId &&
              hands[i].profileName == current[i].profileName &&
              hands[i].raisedAt == current[i].raisedAt,
        ).every((b) => b);
    if (same) return;
    state = state.copyWith(raisedHands: hands, revision: state.revision + 1);
  }

  /// Every response from every hosted group, members only (see
  /// [_recomputeHands]).
  List<LiveResponse> get _allResponses {
    final all = <LiveResponse>[];
    for (final entry in _responsesByKey.entries) {
      final members = _liveMembersOf(entry.key);
      for (final r in entry.value) {
        if (members == null || members.contains(r.profileId)) all.add(r);
      }
    }
    return all;
  }

  /// Follows a change of the class / group picker during a live session:
  /// groups taken off end their session (their learners see it close), groups
  /// added start one — showing them the question already on screen.
  Future<void> _retargetLive() async {
    if (state.liveSessionKeys.isEmpty || !FirebaseService.isConfigured) {
      return;
    }
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final wanted = castGroups;
    final wantedIds = {for (final g in wanted) g.id};
    final current = state.liveSessionKeys.toSet();
    if (wantedIds.length == current.length && wantedIds.containsAll(current)) {
      return;
    }
    final scoring = state.liveScoring ?? const LiveScoringRules();

    for (final key in current.difference(wantedIds)) {
      await _unsubscribeLive(key);
      await _quietly(() => _liveService.endSession(key));
    }
    final added = <String>[];
    for (final g in wanted) {
      if (current.contains(g.id)) continue;
      try {
        await _liveService.startSession(
          sessionKey: g.id,
          ownerProfileId: profile.id,
          ownerKind: g.kind,
          scoring: scoring,
        );
        final activity = state.liveActivity;
        if (activity != null) {
          await _liveService.pushActivity(sessionKey: g.id, activity: activity);
        }
        _subscribeLive(g.id);
        added.add(g.id);
      } catch (_) {
        // Unreachable group: left out, the others carry on.
      }
    }
    final keys = [
      for (final k in state.liveSessionKeys)
        if (wantedIds.contains(k)) k,
      ...added,
    ];
    state = state.copyWith(
      liveSessionKeys: keys,
      clearLiveSession: keys.isEmpty,
      revision: state.revision + 1,
    );
    _recomputeHands();
    _recomputeLiveAggregates();
  }

  /// Pushes a new activity to every connected learner and shows it on the TV.
  Future<void> pushLiveActivity(LiveActivity activity) async {
    final keys = state.liveSessionKeys;
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
    if (keys.isEmpty || !FirebaseService.isConfigured) return;
    await Future.wait([
      for (final key in keys)
        _quietly(
          () => _liveService.pushActivity(sessionKey: key, activity: activity),
        ),
    ]);
    _recomputeLiveAggregates();
  }

  /// Clears the current question (learners see "waiting for the next one").
  Future<void> clearLiveActivity() async {
    final keys = state.liveSessionKeys;
    state = state.copyWith(
      clearLiveActivity: true,
      liveResponders: 0,
      revision: state.revision + 1,
    );
    if (keys.isEmpty || !FirebaseService.isConfigured) return;
    await Future.wait([
      for (final key in keys) _quietly(() => _liveService.clearActivity(key)),
    ]);
  }

  /// Updates the star-scoring rules mid-session.
  Future<void> setLiveScoring(LiveScoringRules rules) async {
    final keys = state.liveSessionKeys;
    state = state.copyWith(liveScoring: rules, revision: state.revision + 1);
    if (keys.isEmpty || !FirebaseService.isConfigured) return;
    await Future.wait([
      for (final key in keys)
        _quietly(
          () => _liveService.updateScoring(sessionKey: key, scoring: rules),
        ),
    ]);
  }

  /// Educator clears a learner's raised hand (e.g. after helping them), in
  /// whichever hosted group it was raised.
  Future<void> clearRaisedHand(String profileId) async {
    final keys = state.liveSessionKeys;
    if (keys.isEmpty || !FirebaseService.isConfigured) return;
    final raisedIn = [
      for (final key in keys)
        if ((_handsByKey[key] ?? const <RaisedHand>[]).any(
          (h) => h.profileId == profileId,
        ))
          key,
    ];
    await Future.wait([
      for (final key in raisedIn.isEmpty ? keys : raisedIn)
        _quietly(
          () => _liveService.lowerHand(sessionKey: key, profileId: profileId),
        ),
    ]);
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
    final keys = state.liveSessionKeys;
    await _cancelLiveStreams();
    if (keys.isEmpty || !FirebaseService.isConfigured) return;
    await Future.wait([
      for (final key in keys) _quietly(() => _liveService.endSession(key)),
    ]);
  }

  /// Recomputes the responder count (for the current activity) and the
  /// session-wide scoreboard from the cached response sets of every hosted
  /// group, pushing a new revision only when something actually changed.
  void _recomputeLiveAggregates() {
    final responses = _allResponses;
    final currentId = state.liveActivity?.id;
    final responders = currentId == null
        ? 0
        : responses.where((r) => r.activityId == currentId).length;
    final board = LiveSessionService.aggregateScoreboard(responses);

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
