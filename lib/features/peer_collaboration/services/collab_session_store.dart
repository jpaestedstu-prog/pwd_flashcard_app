import 'package:hive_flutter/hive_flutter.dart';

import '../models/collab_models.dart';

/// Where a pair was when they walked away from a Peer Collab activity.
///
/// One record per profile — unlike `GameSessionService`, which keys by profile
/// *and* game, because a learner can only be in one collab session at a time.
/// Stored in the `progress` box in that service's style, and local-only: this
/// is convenience state, not progress, so there is nothing here to sync or
/// export. (Peer Collab awards no stars, XP or streak, exactly like Play
/// Together — see `LocalRaceScreen`.)
///
/// Like the games' resume, this stores **the deck, not the rendered rounds**:
/// card ids in order, plus where the pair had got to. The screen re-draws each
/// round's answer choices from the live card pool on restore, which keeps the
/// snapshot small and stops a pair farming an answer by leaving and coming
/// back.
class CollabSessionStore {
  CollabSessionStore._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  /// A snapshot older than this is dropped rather than offered. Two children
  /// do not remember being mid-round yesterday, and offering it would confuse
  /// more than it helps — the same call `GameSessionService` makes.
  static const Duration resumeMaxAge = Duration(hours: 24);

  static String _key(String profileId) => 'collab_resume_$profileId';

  /// Record where [session] had got to.
  ///
  /// A session nobody has taken a turn in, and a finished one, are both
  /// discarded instead: there is nothing to come back to, and offering "carry
  /// on" for either would be noise.
  static void save({required String? profileId, required CollabSession session}) {
    if (profileId == null || profileId.isEmpty) return;
    if (session.isComplete || session.turns.isEmpty) {
      clear(profileId);
      return;
    }
    _box.put(_key(profileId), CollabResumeSnapshot.of(session).toMap());
  }

  /// The unfinished session for this learner, or null when there is none, it
  /// has aged past [resumeMaxAge], or it cannot be decoded.
  static CollabResumeSnapshot? read(String? profileId) {
    if (profileId == null || profileId.isEmpty) return null;
    final raw = _box.get(_key(profileId));
    if (raw is! Map) return null;

    final CollabResumeSnapshot snapshot;
    try {
      snapshot = CollabResumeSnapshot.fromMap(
        Map<String, dynamic>.from(raw),
      );
    } catch (_) {
      // Written by an older build. Drop it rather than throw on a screen that
      // reads this every time the picker is shown.
      clear(profileId);
      return null;
    }

    if (DateTime.now().difference(snapshot.savedAt) > resumeMaxAge) {
      clear(profileId);
      return null;
    }
    return snapshot;
  }

  /// Forget the unfinished session — on resume, on finish, and on Play Again.
  static void clear(String? profileId) {
    if (profileId == null || profileId.isEmpty) return;
    if (!_box.containsKey(_key(profileId))) return;
    _box.delete(_key(profileId));
  }
}

/// A serialisable freeze-frame of a [CollabSession].
class CollabResumeSnapshot {
  final CollabActivityType activityType;
  final String player1Name;
  final String player2Name;

  /// The flashcard behind each round, in order. Rounds are rebuilt from these.
  final List<String> cardIds;

  final int roundIndex;
  final int currentPlayerIndex;
  final int player1Score;
  final int player2Score;
  final String revealed;
  final int wrongAttempts;
  final bool clueGiven;
  final List<CollabTurn> turns;
  final DateTime savedAt;

  const CollabResumeSnapshot({
    required this.activityType,
    required this.player1Name,
    required this.player2Name,
    required this.cardIds,
    required this.roundIndex,
    required this.currentPlayerIndex,
    required this.player1Score,
    required this.player2Score,
    required this.revealed,
    required this.wrongAttempts,
    required this.clueGiven,
    required this.turns,
    required this.savedAt,
  });

  factory CollabResumeSnapshot.of(CollabSession session) =>
      CollabResumeSnapshot(
        activityType: session.activityType,
        player1Name: session.player1Name,
        player2Name: session.player2Name,
        cardIds: session.rounds.map((r) => r.cardId).toList(),
        roundIndex: session.roundIndex,
        currentPlayerIndex: session.currentPlayerIndex,
        player1Score: session.player1Score,
        player2Score: session.player2Score,
        revealed: session.revealed,
        wrongAttempts: session.wrongAttempts,
        clueGiven: session.clueGiven,
        turns: session.turns,
        savedAt: DateTime.now(),
      );

  /// 1-based, for the "you stopped at round N of M" line.
  int get roundNumber => (roundIndex + 1).clamp(1, cardIds.length);
  int get roundsTotal => cardIds.length;

  /// Rebuild the live session around [rounds], which the caller resolves from
  /// [cardIds] against the current card pool (and re-draws choices for).
  CollabSession toSession({
    required String id,
    required List<CollabRound> rounds,
  }) =>
      CollabSession(
        id: id,
        activityType: activityType,
        player1Name: player1Name,
        player2Name: player2Name,
        rounds: rounds,
        roundIndex: roundIndex,
        currentPlayerIndex: currentPlayerIndex,
        turns: turns,
        player1Score: player1Score,
        player2Score: player2Score,
        revealed: revealed,
        wrongAttempts: wrongAttempts,
        clueGiven: clueGiven,
      );

  Map<String, dynamic> toMap() => {
        'activity': activityType.name,
        'p1': player1Name,
        'p2': player2Name,
        'cardIds': cardIds,
        'roundIndex': roundIndex,
        'current': currentPlayerIndex,
        'p1Score': player1Score,
        'p2Score': player2Score,
        'revealed': revealed,
        'wrongAttempts': wrongAttempts,
        'clueGiven': clueGiven,
        'turns': turns
            .map((t) => {
                  'player': t.playerIndex,
                  'content': t.content,
                  'correct': t.isCorrect,
                  'checked': t.isChecked,
                  'clue': t.isClue,
                  'at': t.timestamp.millisecondsSinceEpoch,
                })
            .toList(),
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory CollabResumeSnapshot.fromMap(Map<String, dynamic> m) {
    final activity = CollabActivityType.values
        .where((a) => a.name == m['activity'])
        .firstOrNull;
    // An activity name this build no longer has is not recoverable; let the
    // caller's catch drop the whole snapshot.
    if (activity == null) throw const FormatException('unknown activity');

    final cardIds = ((m['cardIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (cardIds.isEmpty) throw const FormatException('no rounds');

    final turns = ((m['turns'] as List?) ?? const []).map((raw) {
      final t = Map<String, dynamic>.from(raw as Map);
      return CollabTurn(
        playerIndex: (t['player'] as num?)?.toInt() ?? 0,
        content: t['content']?.toString() ?? '',
        isCorrect: t['correct'] as bool? ?? true,
        isChecked: t['checked'] as bool? ?? false,
        isClue: t['clue'] as bool? ?? false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (t['at'] as num?)?.toInt() ?? 0,
        ),
      );
    }).toList();

    return CollabResumeSnapshot(
      activityType: activity,
      player1Name: m['p1']?.toString() ?? '',
      player2Name: m['p2']?.toString() ?? '',
      cardIds: cardIds,
      roundIndex: (m['roundIndex'] as num?)?.toInt() ?? 0,
      currentPlayerIndex: (m['current'] as num?)?.toInt() ?? 0,
      player1Score: (m['p1Score'] as num?)?.toInt() ?? 0,
      player2Score: (m['p2Score'] as num?)?.toInt() ?? 0,
      revealed: m['revealed']?.toString() ?? '',
      wrongAttempts: (m['wrongAttempts'] as num?)?.toInt() ?? 0,
      clueGiven: m['clueGiven'] as bool? ?? false,
      turns: turns,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['savedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
