import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/parent_provider.dart';
import '../models/educator_audience.dart';

/// What a recommendation is *about*.
///
/// Used to roll several learners with the same problem into one card, and to
/// keep concerns ahead of celebrations no matter which learner raised them.
enum EducatorRecommendationKind {
  wellbeing,
  struggling,
  inactive,
  declining,
  unexplored,
  mastery,
  streak,
  allGood;

  /// Higher wins a place in the feed. Wellbeing outranks everything: a run of
  /// hard days is the one signal a caregiver cannot recover later.
  int get severity => switch (this) {
    EducatorRecommendationKind.wellbeing => 100,
    EducatorRecommendationKind.struggling => 80,
    EducatorRecommendationKind.inactive => 70,
    EducatorRecommendationKind.declining => 60,
    EducatorRecommendationKind.unexplored => 40,
    EducatorRecommendationKind.mastery => 20,
    EducatorRecommendationKind.streak => 10,
    EducatorRecommendationKind.allGood => 0,
  };

  /// Whether this is something to act on rather than something to enjoy.
  ///
  /// Only concerns are rolled up — "3 children are on a streak" is not news an
  /// educator needs collapsed into a count.
  bool get isConcern =>
      severity >= EducatorRecommendationKind.declining.severity;
}

/// One row in the dashboard's recommendation feed.
class ParentRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  /// Empty for a roster-wide card that names no single learner.
  final String childName;

  final EducatorRecommendationKind kind;

  /// The learner this is about, when it is about exactly one. Null for
  /// roster-wide rollups.
  final String? profileId;

  /// Where tapping the card goes, and what its button says.
  ///
  /// A recommendation with no next step is a poster, not a recommendation —
  /// every card built here carries one.
  final String actionLabel;
  final String actionRoute;

  const ParentRecommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.childName,
    this.kind = EducatorRecommendationKind.allGood,
    this.profileId,
    this.actionLabel = 'See analytics',
    this.actionRoute = '/teacher-analytics',
  });
}

String _q(String name) => Uri.encodeQueryComponent(name);

/// Build the recommendation feed from a roster snapshot.
///
/// Three rules, each learned from watching the old feed on a real roster:
///
/// 1. **Concerns outrank celebrations**, and wellbeing outranks both.
/// 2. **One card per learner before any learner gets a second.** The old
///    version emitted every rule for learner 1, then every rule for learner 2,
///    then truncated at 6 — so a six-child roster where nobody had played
///    filled all six slots with the same "hasn't studied" card, and on a mixed
///    roster the alphabetically-first learners crowded everyone else out.
/// 3. **Three or more learners with the same concern collapse into one card.**
///    Six identical cards tell an educator less than one card that says six.
///
/// [now] is a seam so tests can pin the "days since" arithmetic instead of
/// depending on the calendar.
List<ParentRecommendation> generateEducatorRecommendations(
  List<ChildSummary> children, {
  EducatorAudience audience = EducatorAudience.parent,
  bool filipino = false,
  DateTime? now,
  int maxCards = 6,
}) {
  final asOf = now ?? DateTime.now();

  // ── 1. Every candidate, grouped by learner ────────────
  final byChild = <String, List<ParentRecommendation>>{};
  void add(ChildSummary child, ParentRecommendation rec) =>
      (byChild[child.profileId] ??= []).add(rec);

  for (final child in children) {
    final name = child.name;
    final nameQ = _q(name);

    // Wellbeing — a pattern of hard days, never the learner's own words.
    if (child.moodSummary.needsAttention) {
      add(
        child,
        ParentRecommendation(
          title: filipino ? 'Kumustahin si $name' : 'Check in with $name',
          description: filipino
              ? 'Nagtala si $name ng ${child.moodSummary.lowCount} mahihirap '
                    'na check-in ngayong linggo. Mas mahalaga marahil ang '
                    'maikling usapan kaysa sa aralin sa ngayon.'
              : '$name logged ${child.moodSummary.lowCount} difficult '
                    'check-ins this week. A short conversation may matter more '
                    'than a lesson right now.',
          icon: Icons.favorite_rounded,
          color: AppColors.warning,
          childName: name,
          kind: EducatorRecommendationKind.wellbeing,
          profileId: child.profileId,
          actionLabel: filipino ? 'Magsulat ng tala' : 'Write a note',
          actionRoute: '/parent-teacher-notes/${child.profileId}?name=$nameQ',
        ),
      );
    }

    // Struggling — only once there is enough graded play to mean anything.
    // A bare `accuracy < 0.5` sweeps in everyone who has never played, whose
    // accuracy defaults to zero.
    if (child.gamesPlayed >= 3 && child.averageAccuracy < 0.5) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Baka kailangan ni $name ng mas madaling gawain'
              : '$name may need easier activities',
          description: filipino
              ? 'Sa ${(child.averageAccuracy * 100).round()}% na katumpakan sa '
                    '${child.gamesPlayed} laro, makakatulong kay $name ang '
                    'pagbalik-aral sa flashcard bago maglaro.'
              : 'With ${(child.averageAccuracy * 100).round()}% accuracy over '
                    '${child.gamesPlayed} games, $name might benefit from '
                    'reviewing flashcards before playing.',
          icon: Icons.lightbulb_outline_rounded,
          color: AppColors.info,
          childName: name,
          kind: EducatorRecommendationKind.struggling,
          profileId: child.profileId,
          actionLabel: filipino ? 'Tingnan ang timeline' : 'View timeline',
          actionRoute: '/progress-timeline/${child.profileId}?name=$nameQ',
        ),
      );
    }

    // Away from the app
    final idleDays = asOf.difference(child.lastActivityDate).inDays;
    if (!child.isRecentlyActive && idleDays > 2) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Hikayatin si $name na magsanay'
              : 'Encourage $name to practice',
          description: filipino
              ? 'Hindi nag-aral si $name sa loob ng $idleDays araw. Ang '
                    'araw-araw na paalala at 5 minutong sesyon ay nakakatulong '
                    'para hindi bumaba ang progreso.'
              : '$name has not studied in $idleDays days. A daily reminder and '
                    'a quick 5-minute session keep progress from slipping.',
          icon: Icons.notifications_active_rounded,
          color: AppColors.warning,
          childName: name,
          kind: EducatorRecommendationKind.inactive,
          profileId: child.profileId,
          actionLabel: filipino ? 'Magtakda ng paalala' : 'Set a reminder',
          actionRoute: '/child-alarms/${child.profileId}?name=$nameQ',
        ),
      );
    }

    // Study time falling away
    if (child.weekOverWeekChange < -30) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Bumaba ang oras ng pag-aaral ni $name'
              : '$name’s study time dropped',
          description: filipino
              ? 'Bumaba ng ${child.weekOverWeekChange.abs().round()}% ang oras '
                    'ng pag-aaral kumpara noong nakaraang linggo '
                    '(${child.studyMinutesThisWeek}m kumpara sa '
                    '${child.studyMinutesLastWeek}m). Subukang magtakda ng '
                    'araw-araw na paalala nang magkasama.'
              : 'Study time fell ${child.weekOverWeekChange.abs().round()}% '
                    'versus last week (${child.studyMinutesThisWeek}m vs '
                    '${child.studyMinutesLastWeek}m). Consider setting a daily '
                    'learning reminder together.',
          icon: Icons.trending_down_rounded,
          color: AppColors.error,
          childName: name,
          kind: EducatorRecommendationKind.declining,
          profileId: child.profileId,
          actionLabel: filipino ? 'Magtakda ng paalala' : 'Set a reminder',
          actionRoute: '/child-alarms/${child.profileId}?name=$nameQ',
        ),
      );
    }

    // Unexplored categories — only once they have started. On a learner who
    // has never played, "13 categories unexplored" just restates "hasn't
    // begun", which the inactive card already says better.
    final unexplored = child.unexploredCategories;
    if (child.gamesPlayed > 0 &&
        unexplored.isNotEmpty &&
        unexplored.length <= 6) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Bagong kategorya para kay $name'
              : 'New categories for $name',
          description: filipino
              ? 'Hindi pa natutuklasan ni $name ang '
                    '${unexplored.take(3).join(', ')}. Ang bagong paksa ay '
                    'nagpapasigla sa pag-aaral.'
              : '$name has not explored ${unexplored.take(3).join(', ')} yet. '
                    'Introducing a new topic keeps learning fresh.',
          icon: Icons.explore_rounded,
          color: AppColors.secondary,
          childName: name,
          kind: EducatorRecommendationKind.unexplored,
          profileId: child.profileId,
          actionLabel: filipino ? 'Tingnan ang mga deck' : 'Browse decks',
          actionRoute: '/flashcards',
        ),
      );
    }

    // Celebrations
    if (child.masteredCategories >= 3) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Nagawang mahusay ni $name ang '
                    '${child.masteredCategories} kategorya!'
              : '$name mastered ${child.masteredCategories} categories!',
          description: filipino
              ? 'Natapos ni $name ang 80% pataas ng mga salita sa '
                    '${child.masteredCategories} kategorya. Karapat-dapat '
                    'itong purihin nang malakas.'
              : '$name has covered 80%+ of the words in '
                    '${child.masteredCategories} categories. Worth saying out '
                    'loud.',
          icon: Icons.workspace_premium_rounded,
          color: AppColors.primary,
          childName: name,
          kind: EducatorRecommendationKind.mastery,
          profileId: child.profileId,
          actionLabel: filipino ? 'Magpadala ng papuri' : 'Send praise',
          actionRoute: '/parent-teacher-notes/${child.profileId}?name=$nameQ',
        ),
      );
    }

    if (child.streakDays >= 5) {
      add(
        child,
        ParentRecommendation(
          title: filipino
              ? 'Tuloy-tuloy si $name! 🎉'
              : '$name is on a roll! 🎉',
          description: filipino
              ? '${child.streakDays} araw na streak. Ipagdiwang ito at '
                    'hikayatin si $name na ipagpatuloy.'
              : '${child.streakDays}-day streak. Celebrate it and encourage '
                    '$name to keep the run going.',
          icon: Icons.emoji_events_rounded,
          color: AppColors.success,
          childName: name,
          kind: EducatorRecommendationKind.streak,
          profileId: child.profileId,
          actionLabel: filipino ? 'Magpadala ng papuri' : 'Send praise',
          actionRoute: '/parent-teacher-notes/${child.profileId}?name=$nameQ',
        ),
      );
    }
  }

  // Highest severity first within each learner, so the round-robin below
  // always takes that learner's most important card first.
  for (final list in byChild.values) {
    list.sort((a, b) => b.kind.severity.compareTo(a.kind.severity));
  }

  // ── 2. Roll up concerns shared by three or more learners ──
  final rolledUp = <EducatorRecommendationKind>{};
  final feed = <ParentRecommendation>[];

  for (final kind
      in EducatorRecommendationKind.values.where((k) => k.isConcern)) {
    final affected = children
        .where(
          (c) => byChild[c.profileId]?.any((r) => r.kind == kind) ?? false,
        )
        .toList();
    if (affected.length < 3) continue;
    rolledUp.add(kind);
    feed.add(_rollup(kind, affected, audience, filipino));
  }

  // ── 3. Round-robin the rest, best card per learner first ──
  final remaining = {
    for (final entry in byChild.entries)
      entry.key: entry.value.where((r) => !rolledUp.contains(r.kind)).toList(),
  };
  // Keep the roster's own order (active first, then name) so the feed reads in
  // the same sequence as the learner cards above it.
  final order = children.map((c) => c.profileId).toList();

  var round = 0;
  while (feed.length < maxCards) {
    var tookAny = false;
    for (final id in order) {
      if (feed.length >= maxCards) break;
      final list = remaining[id];
      if (list == null || list.length <= round) continue;
      feed.add(list[round]);
      tookAny = true;
    }
    if (!tookAny) break;
    round++;
  }

  // Concerns above celebrations. Ties keep insertion order, so the
  // round-robin's per-learner fairness survives the sort.
  final ordered =
      (feed.asMap().entries.toList()..sort((a, b) {
            final bySeverity = b.value.kind.severity.compareTo(
              a.value.kind.severity,
            );
            return bySeverity != 0 ? bySeverity : a.key.compareTo(b.key);
          }))
          .map((e) => e.value)
          .toList();

  if (ordered.isEmpty) {
    return [
      ParentRecommendation(
        title: filipino
            ? 'Magpatuloy sa magandang gawa!'
            : 'Keep up the great work!',
        description: filipino
            ? 'Lahat sa iyong talaan ay natututo sa maayos na bilis. '
                  'Hikayatin silang tuklasin ang bagong kategorya at subukan '
                  'ang ibang laro.'
            : 'Everyone on your roster is learning at a healthy pace. '
                  'Encourage them to explore new categories and try different '
                  'games.',
        actionLabel: filipino
            ? 'Tingnan ang analytics'
            : 'See analytics',
        icon: Icons.thumb_up_rounded,
        color: AppColors.success,
        childName: '',
      ),
    ];
  }

  return ordered;
}

ParentRecommendation _rollup(
  EducatorRecommendationKind kind,
  List<ChildSummary> affected,
  EducatorAudience audience,
  bool filipino,
) {
  final names = affected.map((c) => c.name).toList();
  final others = names.length - 2;
  final who = others > 0
      ? (filipino
            ? '${names.take(2).join(', ')} at $others pa'
            : '${names.take(2).join(', ')} and $others more')
      : names.join(filipino ? ' at ' : ' and ');
  // A numeral already pluralises in Filipino, so the count takes the singular.
  final noun = filipino
      ? audience.learnerNounOf(filipino: true)
      : audience.learnerNounPlural;
  final count = names.length;
  final action = filipino ? 'Tingnan ang analytics' : 'See analytics';

  return switch (kind) {
    EducatorRecommendationKind.wellbeing => ParentRecommendation(
      title: filipino ? '$count $noun ang maaaring nangangailangan ng suporta' : '$count $noun may need support',
      description: filipino
          ? 'Nagtala sina $who ng ilang mahihirap na check-in ngayong '
            'linggo. Kumustahin sila isa-isa bago ang susunod na sesyon.'
          : '$who logged several difficult check-ins this week. Consider '
          'checking in with each of them before the next session.',
      icon: Icons.favorite_rounded,
      color: AppColors.warning,
      childName: '',
      kind: kind,
      actionLabel: action,
    ),
    EducatorRecommendationKind.struggling => ParentRecommendation(
      title: filipino ? '$count $noun ang mas mababa sa 50% na katumpakan' : '$count $noun are below 50% accuracy',
      description: filipino
          ? 'Mas marami ang mali kaysa tama nina $who. Nakakatulong ang '
            'pagbalik-aral sa flashcard bago maglaro, o ang pagpapadali ng '
            'antas.'
          : '$who are getting more wrong than right. Reviewing flashcards before '
          'games, or easing the difficulty, usually helps.',
      icon: Icons.lightbulb_outline_rounded,
      color: AppColors.info,
      childName: '',
      kind: kind,
      actionLabel: action,
    ),
    EducatorRecommendationKind.inactive => ParentRecommendation(
      title: filipino ? '$count $noun ang matagal nang hindi nagsasanay' : '$count $noun have not practised recently',
      description: filipino
          ? 'Mahigit dalawang araw nang wala sina $who. Mas madaling sundin '
            'ang iisang oras ng paalala kaysa sa magkakahiwalay.'
          : '$who have been away for more than two days. One shared reminder '
          'time is usually easier to keep than several individual ones.',
      icon: Icons.notifications_active_rounded,
      color: AppColors.warning,
      childName: '',
      kind: kind,
      actionLabel: action,
    ),
    _ => ParentRecommendation(
      title: filipino
          ? '$count $noun ang mas kaunti ang pag-aaral kaysa noong nakaraang '
                'linggo'
          : '$count $noun are studying less than last week',
      description: filipino
          ? 'Bumaba nang mahigit 30% ang oras ng pag-aaral nina $who. '
                'Tingnan kung ano ang nagbago sa kanilang linggo.'
          : '$who each dropped more than 30% of their study time. Worth '
                'looking at what changed in their week.',
      icon: Icons.trending_down_rounded,
      color: AppColors.error,
      childName: '',
      kind: kind,
      actionLabel: action,
    ),
  };
}
