import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/sound_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/services/action_clip_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
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
import '../services/tv_cast_server.dart';

/// Owns the cast session state machine and the underlying HTTP server.
/// Every mutation bumps `revision` so the TV's poll loop can short-circuit
/// re-renders when nothing has changed.
class TvCastSessionNotifier extends Notifier<TvCastSession> {
  TvCastServer? _server;
  TvCastAutoplayController? _autoplay;
  TvCastAudioNarrator? _narrator;
  Timer? _viewerTickTimer;

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

    final (en, fil) = _currentSpeechText();
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
        final story = _currentStory();
        if (story == null) return ('', '');
        final pagesEn = story.sentencesEn;
        final pagesFil = story.sentencesFil;
        final idx = state.storyPageIndex.clamp(0, pagesEn.length - 1);
        final en = idx < pagesEn.length ? pagesEn[idx] : '';
        final fil = idx < pagesFil.length ? pagesFil[idx] : '';
        return (en, fil);
      case CastMode.progress:
      case CastMode.live:
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
    );
    final port = await _server!.start();
    final url = 'http://$ip:$port';

    // Respect the educator's accessibility setting out of the box: if the app
    // is in high-contrast mode, default the TV output to the high-contrast
    // theme too. They can still switch it from the cast screen.
    final settings = ref.read(settingsProvider);
    final highContrast = settings.highContrastMode;

    state = state.copyWith(
      isServerRunning: true,
      listenUrl: url,
      port: port,
      castTheme: highContrast ? CastTheme.highContrast : CastTheme.dark,
      // Mirror the accessibility setting so the TV can drop animations.
      reducedMotion: settings.reducedMotion,
      revision: state.revision + 1,
    );

    // Tick the connected-viewer count every 2 s so the phone UI shows
    // how many TVs/browsers are currently pulling state.
    _viewerTickTimer?.cancel();
    _viewerTickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final n = _server?.activeViewerCount ?? 0;
      if (n != state.connectedViewers) {
        state = state.copyWith(connectedViewers: n);
      }
    });

    _autoplay ??= TvCastAutoplayController(onTick: _advanceFromAutoplay);
  }

  Future<void> stopServer() async {
    _autoplay?.stop();
    unawaited(_narrator?.stop());
    _viewerTickTimer?.cancel();
    _viewerTickTimer = null;
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
      _refreshProgress();
      _autoplay?.stop();
      unawaited(_narrator?.stop());
    } else {
      _autoplay?.stop();
      unawaited(_narrator?.stop());
    }
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
          _prefetchStoryFslAround();
          _prefetchStoryImagesAround();
          _narrateCurrent();
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
  }

  // ─── Internal helpers ─────────────────────────────────

  void _advanceFromAutoplay() {
    if (state.isPaused || !state.autoAdvanceEnabled) return;
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

  /// Re-derives the leaderboard DTO from the educator roster and
  /// pushes a new revision IFF the values actually changed (avoids
  /// flicker-repainting the TV every 2 s).
  void _refreshProgress() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final rosterAsync = ref.read(educatorRosterProvider(profile.id));
    final List<(UserProfile, LearningProgress)> roster =
        rosterAsync.valueOrNull ?? ref.read(allProfilesWithProgressProvider);

    final students = roster
        .where((d) => d.$1.role == UserRole.student && !d.$1.isGuestPlayer)
        .toList();
    students.sort((a, b) => b.$2.totalStars.compareTo(a.$2.totalStars));

    final rows = <TvCastProgressRow>[];
    for (var i = 0; i < students.length && i < 10; i++) {
      final (p, prog) = students[i];
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

    final unchanged =
        rows.length == state.progress.length &&
        List.generate(
          rows.length,
          (i) => rows[i] == state.progress[i],
        ).every((b) => b);
    if (unchanged) return;

    state = state.copyWith(progress: rows, revision: state.revision + 1);
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
    state = state.copyWith(
      liveActivity: activity,
      liveResponders: 0,
      revision: state.revision + 1,
    );
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
