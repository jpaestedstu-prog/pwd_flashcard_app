import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/seed_data.dart';
import '../../data/models/enums.dart';

/// Elo-based knowledge tracing: jointly estimates a continuous student
/// ability θ (global + per category) and a per-word difficulty β from every
/// recorded attempt, fully online and on-device.
///
/// Why Elo over BKT: BKT needs four latent parameters per skill fit via EM
/// over population data — unavailable in an offline-first app — and assumes
/// binary mastery. Elo is parameter-light, cold-start friendly, O(1) per
/// attempt, and well validated for adaptive practice (Klinkenberg et al.
/// 2011, Maths Garden; Pelánek 2016).
///
/// Model: p(correct) = 1 / (1 + e^-(θ - β)); after each outcome o ∈ {0,1}
/// θ ← θ + K_s·(o − p) and β ← β − K_i·(o − p), with K decaying as evidence
/// accumulates (K(n) = K₀·τ/(τ+n)) so early attempts move estimates fast and
/// later ones fine-tune. β is device-local difficulty: with one student per
/// device it is that student's personal difficulty for the word, which is
/// exactly what review prioritization needs; cross-student β aggregation
/// happens researcher-side from `knowledge_state.csv`.
///
/// Persistence mirrors the `sr_` pattern: one JSON blob per profile in the
/// `progress` box under `elo_<profileId>`. Word→category mapping comes from
/// [SeedData]; custom flashcards update the global θ only.
class KnowledgeTracingService {
  KnowledgeTracingService._();

  static const String _boxName = 'progress';
  static Box get _box => Hive.box(_boxName);

  static String _key(String profileId) => 'elo_$profileId';

  // Learning-rate constants. K₀ chosen so ~5 early attempts can move θ by
  // ~1 logit; τ is the evidence count at which K halves.
  static const double _k0Student = 0.35;
  static const double _k0Item = 0.30;
  static const double _kTau = 20.0;

  /// Outcomes kept per word for trend detection.
  static const int _historyCap = 20;

  static Map<String, String>? _categoryByWordIdCache;
  static Map<String, String> get _categoryByWordId =>
      _categoryByWordIdCache ??= {
        for (final card in SeedData.allFlashcards) card.id: card.category.name,
      };

  static double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

  static double _k(double k0, int evidenceCount) =>
      k0 * _kTau / (_kTau + evidenceCount);

  // ─── Persistence ────────────────────────────────────────

  static EloState getState(String profileId) {
    final raw = _box.get(_key(profileId));
    if (raw == null) return EloState.initial();
    return EloState.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<void> _saveState(String profileId, EloState state) =>
      _box.put(_key(profileId), state.toJson());

  // ─── Recording ──────────────────────────────────────────

  /// Records one attempt. Safe to call from any flow that knows a wordId and
  /// an outcome — games, tutor quizzes, flashcards all funnel here via
  /// SpacedRepetitionService.
  static Future<void> recordAttempt({
    required String profileId,
    required String wordId,
    required bool wasCorrect,
  }) async {
    final state = getState(profileId);
    _applyAttempt(state, wordId, wasCorrect);
    await _saveState(profileId, state);
  }

  /// Batch variant — one load/save for a whole game's results.
  static Future<void> recordBatch({
    required String profileId,
    required Map<String, bool> results,
  }) async {
    if (results.isEmpty) return;
    final state = getState(profileId);
    for (final entry in results.entries) {
      _applyAttempt(state, entry.key, entry.value);
    }
    await _saveState(profileId, state);
  }

  static void _applyAttempt(EloState state, String wordId, bool wasCorrect) {
    final item = state.items.putIfAbsent(wordId, () => EloItemState.initial());
    final category = _categoryByWordId[wordId];

    final theta = _effectiveTheta(state, category);
    final p = _sigmoid(theta - item.beta);
    final outcome = wasCorrect ? 1.0 : 0.0;
    final error = outcome - p;

    state.thetaGlobal += _k(_k0Student, state.attemptsGlobal) * error;
    state.attemptsGlobal++;

    if (category != null) {
      final catAttempts = state.attemptsByCategory[category] ?? 0;
      state.thetaByCategory[category] =
          (state.thetaByCategory[category] ?? 0.0) +
              _k(_k0Student, catAttempts) * error;
      state.attemptsByCategory[category] = catAttempts + 1;
    }

    item.beta -= _k(_k0Item, item.attempts) * error;
    item.attempts++;
    item.lastP = p;
    item.lastSeen = DateTime.now();
    item.history.add(wasCorrect ? 1 : 0);
    if (item.history.length > _historyCap) {
      item.history.removeRange(0, item.history.length - _historyCap);
    }
  }

  /// Category θ when the student has evidence there, else global θ.
  static double _effectiveTheta(EloState state, String? category) {
    if (category != null) {
      final t = state.thetaByCategory[category];
      if (t != null) return t;
    }
    return state.thetaGlobal;
  }

  // ─── Prediction ─────────────────────────────────────────

  /// Predicted probability the student answers [wordId] correctly right now.
  /// Unseen words use β = 0 (average difficulty).
  static double pCorrect({
    required String profileId,
    required String wordId,
  }) {
    final state = getState(profileId);
    return _pCorrect(state, wordId);
  }

  static double _pCorrect(EloState state, String wordId) {
    final beta = state.items[wordId]?.beta ?? 0.0;
    final theta = _effectiveTheta(state, _categoryByWordId[wordId]);
    return _sigmoid(theta - beta);
  }

  /// wordId → predicted p(correct) for every word with at least one attempt.
  static Map<String, double> masterySnapshot(String profileId) {
    final state = getState(profileId);
    return {
      for (final wordId in state.items.keys) wordId: _pCorrect(state, wordId),
    };
  }

  /// Per-word trend over the recent outcome history: success rate of the
  /// newer half minus the older half of the last [window] outcomes, in
  /// [-1, 1]. Returns 0 when there is too little evidence (< 6 outcomes).
  static double trendSlope(List<int> history, {int window = 8}) {
    final recent = history.length > window
        ? history.sublist(history.length - window)
        : history;
    if (recent.length < 6) return 0.0;
    final mid = recent.length ~/ 2;
    final older = recent.sublist(0, mid);
    final newer = recent.sublist(mid);
    final olderRate = older.reduce((a, b) => a + b) / older.length;
    final newerRate = newer.reduce((a, b) => a + b) / newer.length;
    return newerRate - olderRate;
  }

  /// Words whose recent success rate is falling — practiced but getting
  /// worse, the strongest early-warning signal a dashboard can surface.
  static List<String> decliningWords(
    String profileId, {
    double threshold = -0.15,
  }) {
    final state = getState(profileId);
    return [
      for (final entry in state.items.entries)
        if (trendSlope(entry.value.history) < threshold) entry.key,
    ];
  }

  /// Dashboard summary for one student.
  static EloSummary summary(String profileId) {
    final state = getState(profileId);
    final mastery = <double>[];
    final struggling = <String>[];
    for (final entry in state.items.entries) {
      final p = _pCorrect(state, entry.key);
      mastery.add(p);
      if (entry.value.attempts >= 3 && p < 0.5) struggling.add(entry.key);
    }
    return EloSummary(
      thetaGlobal: state.thetaGlobal,
      thetaByCategory: Map.unmodifiable(state.thetaByCategory),
      totalAttempts: state.attemptsGlobal,
      trackedWords: state.items.length,
      predictedMastery: mastery.isEmpty
          ? 0.0
          : mastery.reduce((a, b) => a + b) / mastery.length,
      strugglingWordIds: struggling,
      decliningWordIds: decliningWords(profileId),
    );
  }

  /// Per-word rows for `knowledge_state.csv`.
  static List<EloWordReport> wordReports(String profileId) {
    final state = getState(profileId);
    return [
      for (final entry in state.items.entries)
        EloWordReport(
          wordId: entry.key,
          category: _categoryByWordId[entry.key] ?? '',
          beta: entry.value.beta,
          pCorrect: _pCorrect(state, entry.key),
          attempts: entry.value.attempts,
          trendSlope: trendSlope(entry.value.history),
          lastSeen: entry.value.lastSeen,
        ),
    ];
  }

  // ─── Difficulty policy ──────────────────────────────────

  /// Cross-session difficulty driven by θ headroom: how much ability the
  /// student has over an average word. Complements (does not replace) the
  /// within-session AdaptiveDifficultyService window.
  static DifficultyPolicy policyFor({
    required String profileId,
    FlashcardCategory? category,
  }) {
    final state = getState(profileId);
    final theta = _effectiveTheta(state, category?.name);
    if (state.attemptsGlobal < 5 || theta < -0.25) {
      return DifficultyPolicy.relaxed;
    }
    if (theta <= 0.5) return DifficultyPolicy.standard;
    return DifficultyPolicy.challenge;
  }

  /// Same thresholds expressed as the existing [GameDifficulty] enum, so
  /// game setup code can consume Elo without a new type.
  static GameDifficulty recommendDifficulty({
    required String profileId,
    FlashcardCategory? category,
  }) {
    final policy = policyFor(profileId: profileId, category: category);
    if (identical(policy, DifficultyPolicy.relaxed)) {
      return GameDifficulty.easy;
    }
    if (identical(policy, DifficultyPolicy.standard)) {
      return GameDifficulty.medium;
    }
    return GameDifficulty.hard;
  }

  /// Test/diagnostic helper — wipes one profile's Elo state.
  static Future<void> resetProfile(String profileId) =>
      _box.delete(_key(profileId));
}

// ─── Data models ─────────────────────────────────────────────

/// Mutable in-memory Elo state for one profile (persisted as JSON).
class EloState {
  double thetaGlobal;
  int attemptsGlobal;
  final Map<String, double> thetaByCategory;
  final Map<String, int> attemptsByCategory;
  final Map<String, EloItemState> items;

  EloState({
    required this.thetaGlobal,
    required this.attemptsGlobal,
    required this.thetaByCategory,
    required this.attemptsByCategory,
    required this.items,
  });

  factory EloState.initial() => EloState(
        thetaGlobal: 0.0,
        attemptsGlobal: 0,
        thetaByCategory: {},
        attemptsByCategory: {},
        items: {},
      );

  Map<String, dynamic> toJson() => {
        'thetaGlobal': thetaGlobal,
        'attemptsGlobal': attemptsGlobal,
        'thetaByCategory': thetaByCategory,
        'attemptsByCategory': attemptsByCategory,
        'items': items.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory EloState.fromJson(Map<String, dynamic> json) => EloState(
        thetaGlobal: (json['thetaGlobal'] as num?)?.toDouble() ?? 0.0,
        attemptsGlobal: (json['attemptsGlobal'] as num?)?.toInt() ?? 0,
        thetaByCategory: Map<String, dynamic>.from(
          (json['thetaByCategory'] as Map?) ?? const {},
        ).map((k, v) => MapEntry(k, (v as num).toDouble())),
        attemptsByCategory: Map<String, dynamic>.from(
          (json['attemptsByCategory'] as Map?) ?? const {},
        ).map((k, v) => MapEntry(k, (v as num).toInt())),
        items: Map<String, dynamic>.from((json['items'] as Map?) ?? const {})
            .map(
          (k, v) => MapEntry(
            k,
            EloItemState.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
      );
}

/// Per-word Elo state: device-local difficulty plus a short outcome history
/// for trend detection.
class EloItemState {
  double beta;
  int attempts;
  double lastP;
  DateTime lastSeen;
  final List<int> history;

  EloItemState({
    required this.beta,
    required this.attempts,
    required this.lastP,
    required this.lastSeen,
    required this.history,
  });

  factory EloItemState.initial() => EloItemState(
        beta: 0.0,
        attempts: 0,
        lastP: 0.5,
        lastSeen: DateTime.now(),
        history: [],
      );

  Map<String, dynamic> toJson() => {
        'beta': beta,
        'attempts': attempts,
        'lastP': lastP,
        'lastSeen': lastSeen.toIso8601String(),
        'history': history,
      };

  factory EloItemState.fromJson(Map<String, dynamic> json) => EloItemState(
        beta: (json['beta'] as num?)?.toDouble() ?? 0.0,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastP: (json['lastP'] as num?)?.toDouble() ?? 0.5,
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ??
            DateTime.now(),
        history: List<int>.from((json['history'] as List?) ?? const []),
      );
}

/// Knob settings a game can consume at setup time. Distinct from the
/// within-session easy/medium/hard ladder: this is the cross-session layer.
class DifficultyPolicy {
  /// Number of answer choices to present (including the correct one).
  final int choiceCount;

  /// 0..1 — how semantically close distractors should be (1 = pick words
  /// with β nearest the target word).
  final double distractorSimilarity;

  /// Multiplier on the game's base time limit (>1 = more time).
  final double timeLimitFactor;

  const DifficultyPolicy({
    required this.choiceCount,
    required this.distractorSimilarity,
    required this.timeLimitFactor,
  });

  static const relaxed = DifficultyPolicy(
    choiceCount: 3,
    distractorSimilarity: 0.2,
    timeLimitFactor: 1.25,
  );
  static const standard = DifficultyPolicy(
    choiceCount: 4,
    distractorSimilarity: 0.5,
    timeLimitFactor: 1.0,
  );
  static const challenge = DifficultyPolicy(
    choiceCount: 4,
    distractorSimilarity: 0.85,
    timeLimitFactor: 0.8,
  );
}

/// One row of `knowledge_state.csv`.
class EloWordReport {
  final String wordId;
  final String category;
  final double beta;
  final double pCorrect;
  final int attempts;
  final double trendSlope;
  final DateTime lastSeen;

  const EloWordReport({
    required this.wordId,
    required this.category,
    required this.beta,
    required this.pCorrect,
    required this.attempts,
    required this.trendSlope,
    required this.lastSeen,
  });
}

/// Teacher-dashboard summary of one student's knowledge state.
class EloSummary {
  final double thetaGlobal;
  final Map<String, double> thetaByCategory;
  final int totalAttempts;
  final int trackedWords;

  /// Mean predicted p(correct) across attempted words.
  final double predictedMastery;

  /// Words with ≥3 attempts predicted below 50%.
  final List<String> strugglingWordIds;

  /// Words whose recent success rate is falling.
  final List<String> decliningWordIds;

  const EloSummary({
    required this.thetaGlobal,
    required this.thetaByCategory,
    required this.totalAttempts,
    required this.trackedWords,
    required this.predictedMastery,
    required this.strugglingWordIds,
    required this.decliningWordIds,
  });

  bool get needsAttention =>
      decliningWordIds.isNotEmpty ||
      (totalAttempts >= 10 && predictedMastery < 0.45);
}
