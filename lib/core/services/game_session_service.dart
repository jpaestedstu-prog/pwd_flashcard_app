import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/enums.dart';

/// What a learner chose the last time they started a game, and where they were
/// when they walked away from one.
///
/// Two related records, both keyed by profile **and** game type, both stored in
/// the `progress` box alongside the adaptive engine's history (see
/// `AdaptiveDifficultyService`, whose storage style this mirrors):
///
///   • **Last setup** — the difficulty, categories and timed-mode a learner
///     last started this game with. Surfaces as the "Last played" badge in the
///     difficulty picker and the pre-ticked rows in the category picker, so a
///     learner who always plays Animals on Easy stops re-answering two sheets
///     every single time.
///
///   • **Resume snapshot** — the round a learner was on when they quit, plus
///     the deck that run was dealt from. Lets the Games hub offer "Continue"
///     instead of silently discarding a half-finished run.
///
/// Both are per profile, so two learners sharing a tablet never see each
/// other's choices, and both are local-only: they are convenience state, not
/// progress, so there is nothing here worth syncing or exporting.
class GameSessionService {
  GameSessionService._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  /// A resume snapshot older than this is dropped rather than offered. A
  /// half-finished run from last week is not something a learner remembers
  /// being in the middle of, and offering it would be more confusing than
  /// helpful.
  static const Duration resumeMaxAge = Duration(hours: 24);

  static String _setupKey(String profileId) => 'game_last_setup_$profileId';
  static String _resumeKey(String profileId) => 'game_resume_$profileId';

  // ─── Last setup ───────────────────────────────────────

  /// Record what [gameType] was just started with. Called at launch, not at
  /// finish, so a run the learner abandoned still counts as "what I picked".
  static void saveSetup({
    required String? profileId,
    required GameType gameType,
    required GameDifficulty difficulty,
    required List<FlashcardCategory> categories,
    required bool timedMode,
  }) {
    if (profileId == null || profileId.isEmpty) return;
    final all = _readMap(_setupKey(profileId));
    all[gameType.name] = {
      'difficulty': difficulty.name,
      'categories': categories.map((c) => c.name).toList(),
      'timedMode': timedMode,
    };
    _box.put(_setupKey(profileId), all);
  }

  /// The setup [gameType] was last started with, or null if never.
  static GameSetup? lastSetup({
    required String? profileId,
    required GameType gameType,
  }) {
    if (profileId == null || profileId.isEmpty) return null;
    final raw = _readMap(_setupKey(profileId))[gameType.name];
    if (raw == null) return null;
    return GameSetup.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  // ─── Resume snapshot ──────────────────────────────────

  /// Store where the learner was when they left [gameType]. Overwrites any
  /// previous snapshot for the same game — only the most recent unfinished run
  /// is ever offered.
  static void saveResume(GameResumeSnapshot snapshot) {
    final profileId = snapshot.profileId;
    if (profileId.isEmpty) return;
    // A run with nothing done, or one already at its last round, is not worth
    // coming back to — treat both as "no snapshot" so the hub stays quiet.
    if (snapshot.roundIndex <= 0 ||
        snapshot.roundIndex >= snapshot.cardIds.length) {
      clearResume(profileId: profileId, gameType: snapshot.gameType);
      return;
    }
    final all = _readMap(_resumeKey(profileId));
    all[snapshot.gameType.name] = snapshot.toMap();
    _box.put(_resumeKey(profileId), all);
  }

  /// The unfinished run for [gameType], or null when there is none, it has
  /// aged past [resumeMaxAge], or it cannot be decoded.
  static GameResumeSnapshot? resumeFor({
    required String? profileId,
    required GameType gameType,
  }) {
    if (profileId == null || profileId.isEmpty) return null;
    final raw = _readMap(_resumeKey(profileId))[gameType.name];
    if (raw == null) return null;
    final GameResumeSnapshot snapshot;
    try {
      snapshot = GameResumeSnapshot.fromMap(
        profileId: profileId,
        map: Map<String, dynamic>.from(raw as Map),
      );
    } catch (_) {
      // A snapshot written by an older build. Drop it rather than crash the
      // hub that reads it on every build.
      clearResume(profileId: profileId, gameType: gameType);
      return null;
    }
    if (DateTime.now().difference(snapshot.savedAt) > resumeMaxAge) {
      clearResume(profileId: profileId, gameType: gameType);
      return null;
    }
    return snapshot;
  }

  /// Every game this learner has an offerable unfinished run in.
  static Map<GameType, GameResumeSnapshot> allResumes(String? profileId) {
    if (profileId == null || profileId.isEmpty) return const {};
    final out = <GameType, GameResumeSnapshot>{};
    for (final key in _readMap(_resumeKey(profileId)).keys) {
      final game = GameType.values.where((g) => g.name == key).firstOrNull;
      if (game == null) continue;
      final snapshot = resumeFor(profileId: profileId, gameType: game);
      if (snapshot != null) out[game] = snapshot;
    }
    return out;
  }

  /// Forget the unfinished run for [gameType] — called when it is resumed, and
  /// whenever a run of that game reaches its result screen.
  static void clearResume({
    required String? profileId,
    required GameType gameType,
  }) {
    if (profileId == null || profileId.isEmpty) return;
    final all = _readMap(_resumeKey(profileId));
    if (all.remove(gameType.name) == null) return;
    _box.put(_resumeKey(profileId), all);
  }

  static Map<String, dynamic> _readMap(String key) {
    final raw = _box.get(key);
    if (raw is! Map) return {};
    return Map<String, dynamic>.from(raw);
  }
}

/// The difficulty / categories / timed-mode a game was last started with.
class GameSetup {
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  const GameSetup({
    required this.difficulty,
    required this.categories,
    required this.timedMode,
  });

  factory GameSetup.fromMap(Map<String, dynamic> m) {
    final rawCats = (m['categories'] as List?) ?? const [];
    return GameSetup(
      difficulty:
          GameDifficulty.values
              .where((d) => d.name == m['difficulty'])
              .firstOrNull ??
          GameDifficulty.medium,
      categories: rawCats
          .map(
            (name) => FlashcardCategory.values
                .where((c) => c.name == name.toString())
                .firstOrNull,
          )
          .whereType<FlashcardCategory>()
          .toList(),
      timedMode: m['timedMode'] == true,
    );
  }
}

/// Where a learner was when they walked away from a game.
///
/// Stores the **deck**, not the rendered rounds: the card ids the run was
/// dealt, in order, plus how far through them the learner got. A game rebuilds
/// its own rounds from those cards on resume, so each game keeps owning its
/// own round shape (distractors, letter banks, puzzle cuts) and nothing about
/// that shape has to survive in storage. Distractors are re-drawn, which also
/// means a learner cannot farm a known answer by quitting and resuming.
class GameResumeSnapshot {
  final String profileId;
  final GameType gameType;
  final GameDifficulty difficulty;
  final List<FlashcardCategory> categories;
  final bool timedMode;

  /// Card ids for the whole run, in the order they were dealt.
  final List<String> cardIds;

  /// Index of the round the learner had reached — also the number of rounds
  /// already answered.
  final int roundIndex;

  /// Correct answers so far.
  final int score;

  /// Per-card outcome so far, so resuming does not lose what the spaced
  /// repetition record and the review sheet already know.
  final Map<String, bool> cardResults;

  final DateTime savedAt;

  const GameResumeSnapshot({
    required this.profileId,
    required this.gameType,
    required this.difficulty,
    required this.categories,
    required this.timedMode,
    required this.cardIds,
    required this.roundIndex,
    required this.score,
    required this.cardResults,
    required this.savedAt,
  });

  /// Rounds still to play.
  int get roundsLeft => cardIds.length - roundIndex;

  Map<String, dynamic> toMap() => {
    'gameType': gameType.name,
    'difficulty': difficulty.name,
    'categories': categories.map((c) => c.name).toList(),
    'timedMode': timedMode,
    'cardIds': cardIds,
    'roundIndex': roundIndex,
    'score': score,
    'cardResults': cardResults,
    'savedAt': savedAt.toIso8601String(),
  };

  factory GameResumeSnapshot.fromMap({
    required String profileId,
    required Map<String, dynamic> map,
  }) {
    final rawCats = (map['categories'] as List?) ?? const [];
    final rawResults = (map['cardResults'] as Map?) ?? const {};
    return GameResumeSnapshot(
      profileId: profileId,
      gameType: GameType.values.firstWhere((g) => g.name == map['gameType']),
      difficulty:
          GameDifficulty.values
              .where((d) => d.name == map['difficulty'])
              .firstOrNull ??
          GameDifficulty.medium,
      categories: rawCats
          .map(
            (name) => FlashcardCategory.values
                .where((c) => c.name == name.toString())
                .firstOrNull,
          )
          .whereType<FlashcardCategory>()
          .toList(),
      timedMode: map['timedMode'] == true,
      cardIds: ((map['cardIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      roundIndex: (map['roundIndex'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      cardResults: rawResults.map((k, v) => MapEntry(k.toString(), v == true)),
      savedAt: DateTime.parse(map['savedAt'] as String),
    );
  }
}
