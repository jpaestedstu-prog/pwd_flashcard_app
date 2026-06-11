import '../../../data/models/enums.dart';
import '../../live_session/models/live_session_models.dart';

/// What the TV is currently showing.
enum CastMode { idle, flashcards, fslVideo, story, progress, live }

/// Visual template the TV renderer should apply. Sent to the TV in
/// `/api/state` as the `theme` field; the TV-side `app.js` maps it to a
/// `body.theme-<name>` class with a matching CSS block.
///
/// Serialized by `.name` (never index) and not persisted to Hive, so new
/// templates can be appended freely. Cohesive design intents:
///   • dark         — the original high-legibility dark base (default)
///   • light        — bright, clean
///   • classroom    — crisp, neutral, maximum readability for a lit room
///   • playful      — vibrant, rounded, big emoji — kid-friendly
///   • calm         — muted, low-stimulation, extra spacing (no animation)
///   • seasonal     — festive accents from the active [SeasonalEvent]
///   • highContrast — accessibility (mirrors the app's high-contrast mode)
enum CastTheme {
  dark,
  light,
  classroom,
  playful,
  calm,
  seasonal,
  highContrast,
}

extension CastThemeX on CastTheme {
  /// Short label for the educator's template picker.
  String get label => switch (this) {
    CastTheme.dark => 'Dark',
    CastTheme.light => 'Light',
    CastTheme.classroom => 'Classroom',
    CastTheme.playful => 'Playful',
    CastTheme.calm => 'Calm / Focus',
    CastTheme.seasonal => 'Seasonal',
    CastTheme.highContrast => 'High contrast',
  };

  /// One-line description shown under the label in the picker.
  String get description => switch (this) {
    CastTheme.dark => 'High-legibility dark — the classic look.',
    CastTheme.light => 'Bright and clean for well-lit rooms.',
    CastTheme.classroom => 'Crisp and neutral — maximum readability.',
    CastTheme.playful => 'Vibrant and rounded, with big emoji for kids.',
    CastTheme.calm => 'Soft, low-stimulation, calm pacing (no animation).',
    CastTheme.seasonal => 'Festive accents that follow the season.',
    CastTheme.highContrast => 'Black/white/yellow for low vision.',
  };
}

/// Where Flashcards / Stories speech is produced. `tv` makes the TV browser
/// speak (Web Speech API) — sound from the TV's own speakers; `phone` falls
/// back to the teacher's phone (`TvCastAudioNarrator`) for older TVs that
/// lack Web Speech.
enum CastAudioTarget { tv, phone }

/// One leaderboard row sent to the TV in `progress` mode.
class TvCastProgressRow {
  final int rank;
  final String name;
  final int wordsLearned;
  final int streakDays;
  final int stars;

  const TvCastProgressRow({
    required this.rank,
    required this.name,
    required this.wordsLearned,
    required this.streakDays,
    required this.stars,
  });

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'name': name,
    'words': wordsLearned,
    'streak': streakDays,
    'stars': stars,
  };

  @override
  bool operator ==(Object other) =>
      other is TvCastProgressRow &&
      other.rank == rank &&
      other.name == name &&
      other.wordsLearned == wordsLearned &&
      other.streakDays == streakDays &&
      other.stars == stars;

  @override
  int get hashCode => Object.hash(rank, name, wordsLearned, streakDays, stars);
}

/// Immutable snapshot of the cast session. The TV polls `/api/state`
/// every 1.5 s and only repaints when `revision` changes.
class TvCastSession {
  final CastMode mode;
  final int revision;
  final FlashcardCategory? category;
  final int slideIndex;
  final bool isPaused;

  /// When true the TV shows a calm "The teacher is out" screen instead of the
  /// current content. The underlying [mode] / content is preserved so turning
  /// this off resumes instantly. Sent to the TV in `/api/state` as `away`.
  /// Distinct from a dropped connection (which the TV detects on its own when
  /// polls start failing and shows "Oops, the teacher is connecting").
  final bool isAway;

  final String? storyId;
  final int storyPageIndex;
  final bool isServerRunning;
  final String? listenUrl;
  final int port;
  final List<TvCastProgressRow> progress;
  final int connectedViewers;
  final CastTheme castTheme;

  /// Master switch for spoken word / story narration + cues while casting.
  /// Audible only when the app's `ttsEnabled` / `soundEffects` settings also
  /// allow it. The [castAudioTarget] decides whether the TV or the phone
  /// produces the speech.
  final bool castAudioEnabled;

  /// Where the speech is produced — the TV browser (default) or the phone.
  final CastAudioTarget castAudioTarget;

  /// Whether the TV `<video>` element should play its own audio track (for
  /// FSL clips that include a voiceover). Sent to the TV as `videoSound`.
  /// Default off so signs stay muted (Deaf-appropriate) and can autoplay.
  final bool tvVideoSoundEnabled;

  // ─── Live interactive activity (CastMode.live) ────────
  // Mirrored from the Firestore live session the educator is hosting. The
  // notifier subscribes to that session and folds its current activity,
  // responder count, scoreboard, and raised hands into this snapshot so the
  // TV renders them in a single `/api/state` poll. `raisedHands` is surfaced
  // to the TV in *every* mode (banner overlay), so a hand raised during
  // flashcards still shows.

  /// The activity currently pushed to learners, or null between questions.
  final LiveActivity? liveActivity;

  /// How many learners have answered the current activity.
  final int liveResponders;

  /// Per-learner running scoreboard for the session (stars + correct count).
  final List<LiveScoreRow> liveScoreboard;

  /// Learners with a hand currently raised.
  final List<RaisedHand> raisedHands;

  /// The educator's star-scoring rules for this session. Host-side only —
  /// not serialized to the TV.
  final LiveScoringRules? liveScoring;

  /// The session key (classroom or home-group id) the educator is hosting.
  /// Host-side only.
  final String? liveSessionKey;

  // ─── Display design (templates, branding, motion) ─────

  /// Optional branding text shown on the TV (e.g. "Ms. Cruz — Grade 2").
  /// Hidden when null/empty.
  final String? castTitle;

  /// Decoration emoji for the `seasonal` template — resolved from the active
  /// [SeasonalEvent] by the notifier. Null unless the seasonal template is on.
  final String? seasonalEmoji;

  /// Accent colour (hex `#RRGGBB`) for the `seasonal` template, from the
  /// active event. Applied inline on the TV (the CSS avoids `var()`).
  final String? seasonalAccent;

  /// Mirrors the app's reduced-motion accessibility setting so the TV can
  /// disable entrance/transition animations for motion-sensitive viewers.
  final bool reducedMotion;

  const TvCastSession({
    this.mode = CastMode.idle,
    this.revision = 0,
    this.category,
    this.slideIndex = 0,
    this.isPaused = false,
    this.isAway = false,
    this.storyId,
    this.storyPageIndex = 0,
    this.isServerRunning = false,
    this.listenUrl,
    this.port = 8088,
    this.progress = const [],
    this.connectedViewers = 0,
    this.castTheme = CastTheme.dark,
    this.castAudioEnabled = true,
    this.castAudioTarget = CastAudioTarget.tv,
    this.tvVideoSoundEnabled = false,
    this.liveActivity,
    this.liveResponders = 0,
    this.liveScoreboard = const [],
    this.raisedHands = const [],
    this.liveScoring,
    this.liveSessionKey,
    this.castTitle,
    this.seasonalEmoji,
    this.seasonalAccent,
    this.reducedMotion = false,
  });

  TvCastSession copyWith({
    CastMode? mode,
    int? revision,
    FlashcardCategory? category,
    bool clearCategory = false,
    int? slideIndex,
    bool? isPaused,
    bool? isAway,
    String? storyId,
    bool clearStoryId = false,
    int? storyPageIndex,
    bool? isServerRunning,
    String? listenUrl,
    bool clearListenUrl = false,
    int? port,
    List<TvCastProgressRow>? progress,
    int? connectedViewers,
    CastTheme? castTheme,
    bool? castAudioEnabled,
    CastAudioTarget? castAudioTarget,
    bool? tvVideoSoundEnabled,
    LiveActivity? liveActivity,
    bool clearLiveActivity = false,
    int? liveResponders,
    List<LiveScoreRow>? liveScoreboard,
    List<RaisedHand>? raisedHands,
    LiveScoringRules? liveScoring,
    String? liveSessionKey,
    bool clearLiveSession = false,
    String? castTitle,
    bool clearCastTitle = false,
    String? seasonalEmoji,
    String? seasonalAccent,
    bool clearSeasonal = false,
    bool? reducedMotion,
  }) {
    return TvCastSession(
      mode: mode ?? this.mode,
      revision: revision ?? this.revision,
      category: clearCategory ? null : (category ?? this.category),
      slideIndex: slideIndex ?? this.slideIndex,
      isPaused: isPaused ?? this.isPaused,
      isAway: isAway ?? this.isAway,
      storyId: clearStoryId ? null : (storyId ?? this.storyId),
      storyPageIndex: storyPageIndex ?? this.storyPageIndex,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      listenUrl: clearListenUrl ? null : (listenUrl ?? this.listenUrl),
      port: port ?? this.port,
      progress: progress ?? this.progress,
      connectedViewers: connectedViewers ?? this.connectedViewers,
      castTheme: castTheme ?? this.castTheme,
      castAudioEnabled: castAudioEnabled ?? this.castAudioEnabled,
      castAudioTarget: castAudioTarget ?? this.castAudioTarget,
      tvVideoSoundEnabled: tvVideoSoundEnabled ?? this.tvVideoSoundEnabled,
      liveActivity: clearLiveActivity
          ? null
          : (liveActivity ?? this.liveActivity),
      liveResponders: liveResponders ?? this.liveResponders,
      liveScoreboard: liveScoreboard ?? this.liveScoreboard,
      raisedHands: raisedHands ?? this.raisedHands,
      liveScoring: clearLiveSession
          ? null
          : (liveScoring ?? this.liveScoring),
      liveSessionKey: clearLiveSession
          ? null
          : (liveSessionKey ?? this.liveSessionKey),
      castTitle: clearCastTitle ? null : (castTitle ?? this.castTitle),
      seasonalEmoji:
          clearSeasonal ? null : (seasonalEmoji ?? this.seasonalEmoji),
      seasonalAccent:
          clearSeasonal ? null : (seasonalAccent ?? this.seasonalAccent),
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }

  /// JSON payload served from `/api/state` to the TV browser.
  /// Keys are short to keep the polled body small.
  Map<String, dynamic> toApiJson() {
    return {
      'rev': revision,
      'mode': mode.name,
      'theme': castTheme.name,
      // Optional branding text shown on the TV; empty string when unset so the
      // TV can simply check truthiness.
      'title': (castTitle != null && castTitle!.trim().isNotEmpty)
          ? castTitle!.trim()
          : '',
      // Lets the TV disable entrance/transition animations.
      'reducedMotion': reducedMotion,
      // Festive accents for the `seasonal` template (null on other templates).
      // Carried in the payload because the TV CSS avoids `var()` for old
      // browsers, so dynamic colours must be applied inline by app.js.
      'seasonal': castTheme == CastTheme.seasonal
          ? {'emoji': seasonalEmoji, 'accent': seasonalAccent}
          : null,
      'isPaused': isPaused,
      'away': isAway,
      'category': category?.label,
      'categoryIndex': category?.index,
      'slideIndex': slideIndex,
      'storyId': storyId,
      'storyPageIndex': storyPageIndex,
      'videoSound': tvVideoSoundEnabled,
      // The TV browser speaks the words/story itself (Web Speech) only when
      // audio is on AND routed to the TV; otherwise the phone handles it.
      'ttsOnTv': castAudioEnabled && castAudioTarget == CastAudioTarget.tv,
      'progress': progress.map((r) => r.toJson()).toList(),
      // Always present so the TV can render the raised-hands banner in any
      // mode. `activity` / `board` / `responded` are only meaningful in
      // CastMode.live. The correct answer is deliberately NOT sent — learners
      // answer on their own devices, and the TV is a shared display.
      'live': {
        'hands': raisedHands.map((h) => h.profileName).toList(),
        'responded': liveResponders,
        'board': liveScoreboard.map((r) => r.toJson()).toList(),
        'activity': liveActivity == null
            ? null
            : {
                'type': liveActivity!.type.name,
                'prompt': liveActivity!.prompt,
                'options': liveActivity!.options,
                'isTrueFalse':
                    liveActivity!.type == LiveActivityType.trueFalse,
                'flashcardId': liveActivity!.flashcardId,
                'questionNumber': liveActivity!.questionNumber,
                'totalQuestions': liveActivity!.totalQuestions,
              },
      },
    };
  }
}
