import 'dart:math';

import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../models/assessment_models.dart';

/// How one question behaved across everyone who sat it.
///
/// The app has recorded a row per answered question — with the answer given
/// and how long it took — since assessments existed, and nothing has ever read
/// it back. An educator could see *who* scored badly but never *which words*
/// the class could not do, which is the difference between knowing there is a
/// problem and knowing what to teach on Monday.
class ItemStat {
  final String questionId;

  /// The question as it was asked, when a stored template still has it.
  /// Falls back to the id, which is derived from the flashcard.
  final String prompt;

  /// How many sittings answered this item.
  final int attempts;
  final int correct;

  /// Share correct, 0–1. Classical test theory calls this the *p-value*, and
  /// it runs backwards from intuition: **low means hard**.
  final double difficulty;

  /// How well this item separates the learners who did well overall from the
  /// ones who did not — the top group's success rate minus the bottom
  /// group's, using the conventional upper/lower 27% split.
  ///
  /// Null when too few learners have sat it for the split to mean anything.
  /// Near zero or negative is a warning: an item everybody gets right, or one
  /// the strongest learners get *wrong*, is measuring something other than
  /// what the rest of the test measures — usually confusing wording.
  final double? discrimination;

  /// Median time to answer, in milliseconds. Median, not mean: one learner who
  /// walked away mid-question would drag an average into nonsense.
  final int medianResponseMs;

  /// The wrong answer given most often, and how often — the distractor that is
  /// doing the damage.
  final String? commonWrongAnswer;
  final int commonWrongCount;

  const ItemStat({
    required this.questionId,
    required this.prompt,
    required this.attempts,
    required this.correct,
    required this.difficulty,
    required this.discrimination,
    required this.medianResponseMs,
    required this.commonWrongAnswer,
    required this.commonWrongCount,
  });

  /// Plain-language reading of [difficulty], for an educator who has never
  /// met a p-value and should not have to.
  String get difficultyLabel {
    if (difficulty >= 0.85) return 'Easy for the class';
    if (difficulty >= 0.6) return 'Most got it';
    if (difficulty >= 0.4) return 'Split the class';
    if (difficulty >= 0.2) return 'Hard';
    return 'Almost nobody';
  }

  /// Localized [difficultyLabel]. Nullable l10n falling back to English,
  /// like every other `...Of` getter in this module.
  String difficultyLabelOf(AppLocalizations? l10n) {
    if (l10n == null) return difficultyLabel;
    if (difficulty >= 0.85) return l10n.reportDifficultyEasy;
    if (difficulty >= 0.6) return l10n.reportDifficultyMost;
    if (difficulty >= 0.4) return l10n.reportDifficultySplit;
    if (difficulty >= 0.2) return l10n.reportDifficultyHard;
    return l10n.reportDifficultyNobody;
  }

  /// True when the item looks broken rather than merely hard: a negative or
  /// near-zero discrimination means the learners who did best overall were no
  /// likelier to get this one right.
  bool get needsReview =>
      discrimination != null && discrimination! < 0.1 && attempts >= 4;
}

/// Mean learning gain for one accessibility category.
///
/// The study compares accessibility categories, and no screen has ever shown
/// that comparison — the numbers existed only one learner at a time.
class GroupGain {
  final DisabilityType type;

  /// Learners with both halves finished, i.e. the ones these means are over.
  final int learners;

  /// Learners in this category still missing one half. Reported alongside so a
  /// mean over two learners is never mistaken for a mean over twelve.
  final int pending;

  final double meanPre;
  final double meanPost;

  /// Mean of the per-learner raw gains. Deliberately the mean of the gains
  /// rather than the difference of the means — they are equal here, but only
  /// the first stays right if a learner is ever missing one half.
  final double meanGain;

  /// Mean of Hake's normalized gain, over the learners it is defined for
  /// (a learner whose pre-test was already perfect has none).
  final double? meanNormalizedGain;

  const GroupGain({
    required this.type,
    required this.learners,
    required this.pending,
    required this.meanPre,
    required this.meanPost,
    required this.meanGain,
    required this.meanNormalizedGain,
  });

  bool get hasImproved => meanGain > 0;
}

/// Pure statistics over a set of assessment results. No Hive, no providers —
/// the caller fetches, this counts.
class ClassAnalysis {
  const ClassAnalysis._();

  /// At least this many sittings before an upper/lower split is meaningful.
  static const int minimumForDiscrimination = 4;

  /// Per-question statistics across every sitting in [results].
  ///
  /// Sorted hardest first, because that is the order an educator wants to read
  /// it in. [prompts] maps question id → the text as asked; ids not in it fall
  /// back to the id itself rather than dropping the row.
  static List<ItemStat> itemStats(
    Iterable<AssessmentResult> results, {
    Map<String, String> prompts = const {},
  }) {
    // One entry per sitting: its overall fraction, and what it answered.
    final sittings = <({double score, Map<String, QuestionAnswer> answers})>[];
    for (final result in results) {
      if (result.answers.isEmpty) continue;
      sittings.add((
        score: result.percentage,
        answers: {for (final a in result.answers) a.questionId: a},
      ));
    }
    if (sittings.isEmpty) return const [];

    // Upper / lower 27% by overall score — the conventional split for a
    // discrimination index, and stable enough for classroom-sized groups.
    final ranked = [...sittings]
      ..sort((a, b) => b.score.compareTo(a.score));
    final bandSize = max(1, (ranked.length * 0.27).round());
    final upper = ranked.take(bandSize).toList();
    final lower = ranked.reversed.take(bandSize).toList();
    final canDiscriminate = sittings.length >= minimumForDiscrimination;

    final ids = <String>{for (final s in sittings) ...s.answers.keys};
    final stats = <ItemStat>[];

    for (final id in ids) {
      final answered = sittings
          .map((s) => s.answers[id])
          .whereType<QuestionAnswer>()
          .toList();
      if (answered.isEmpty) continue;

      final correct = answered.where((a) => a.isCorrect).length;
      final times = answered.map((a) => a.responseTimeMs).toList()..sort();

      final wrong = <String, int>{};
      for (final a in answered) {
        if (a.isCorrect) continue;
        final given = a.givenAnswer.trim();
        if (given.isEmpty) continue;
        wrong[given] = (wrong[given] ?? 0) + 1;
      }
      final worst = wrong.entries.isEmpty
          ? null
          : wrong.entries.reduce((a, b) => b.value > a.value ? b : a);

      stats.add(
        ItemStat(
          questionId: id,
          prompt: prompts[id] ?? id,
          attempts: answered.length,
          correct: correct,
          difficulty: correct / answered.length,
          discrimination: canDiscriminate
              ? _shareCorrect(upper, id) - _shareCorrect(lower, id)
              : null,
          medianResponseMs: _median(times),
          commonWrongAnswer: worst?.key,
          commonWrongCount: worst?.value ?? 0,
        ),
      );
    }

    stats.sort((a, b) {
      final byDifficulty = a.difficulty.compareTo(b.difficulty);
      // Ties broken by id so the list does not reshuffle between builds.
      return byDifficulty != 0
          ? byDifficulty
          : a.questionId.compareTo(b.questionId);
    });
    return stats;
  }

  /// Share of [band] that got [id] right, over the ones who answered it.
  /// Returns 0 when nobody in the band saw the item.
  static double _shareCorrect(
    List<({double score, Map<String, QuestionAnswer> answers})> band,
    String id,
  ) {
    final seen = band
        .map((s) => s.answers[id])
        .whereType<QuestionAnswer>()
        .toList();
    if (seen.isEmpty) return 0;
    return seen.where((a) => a.isCorrect).length / seen.length;
  }

  static int _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Mean learning gain per accessibility category.
  ///
  /// [rows] is one entry per enrolled learner: their category, and their
  /// learning-gain report when they have finished both halves. Learners with
  /// only one half are counted in [GroupGain.pending] rather than dropped, so
  /// the coverage of the figure is always visible next to it.
  ///
  /// Categories nobody is enrolled in are left out entirely.
  static List<GroupGain> gainsByAccessibility(
    Iterable<({DisabilityType type, LearningGainReport? report})> rows,
  ) {
    final byType = <DisabilityType, List<LearningGainReport?>>{};
    for (final row in rows) {
      byType.putIfAbsent(row.type, () => []).add(row.report);
    }

    final out = <GroupGain>[];
    for (final type in DisabilityType.values) {
      final entries = byType[type];
      if (entries == null || entries.isEmpty) continue;
      final complete = entries.whereType<LearningGainReport>().toList();
      if (complete.isEmpty) {
        out.add(
          GroupGain(
            type: type,
            learners: 0,
            pending: entries.length,
            meanPre: 0,
            meanPost: 0,
            meanGain: 0,
            meanNormalizedGain: null,
          ),
        );
        continue;
      }

      final normalized = complete
          .map((r) => r.normalizedGain)
          .whereType<double>()
          .toList();

      out.add(
        GroupGain(
          type: type,
          learners: complete.length,
          pending: entries.length - complete.length,
          meanPre: _mean(complete.map((r) => r.preTestPercentage)),
          meanPost: _mean(complete.map((r) => r.postTestPercentage)),
          meanGain: _mean(complete.map((r) => r.improvement)),
          meanNormalizedGain: normalized.isEmpty ? null : _mean(normalized),
        ),
      );
    }
    return out;
  }

  static double _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
