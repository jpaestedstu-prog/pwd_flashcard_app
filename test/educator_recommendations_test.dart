import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_summary.dart';
import 'package:pwdpwdpwd/features/parent/models/educator_audience.dart';
import 'package:pwdpwdpwd/features/parent/services/educator_recommendations.dart';
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// The dashboard's recommendation feed.
///
/// Found on a live six-child Parent roster: every one of the six slots was
/// the same "hasn't studied in 18 days" card, because the generator walked
/// learner by learner and truncated at six. These tests pin the three rules
/// that replaced that behaviour — rollup, round-robin, and severity order —
/// plus the fact that every card offers a next step.

final _now = DateTime(2026, 9, 7, 12);

ChildSummary _child(
  String name, {
  int wordsLearned = 20,
  int gamesPlayed = 5,
  double accuracy = 0.8,
  int streakDays = 0,
  int studyThisWeek = 40,
  int studyLastWeek = 40,
  int idleDays = 0,
  MoodSummary mood = MoodSummary.empty,
  Map<String, double> coverage = const {},
  Map<String, double> categoryProgress = const {},
}) {
  return ChildSummary(
    profileId: 'id-$name',
    name: name,
    avatarEmoji: '🐼',
    avatarIndex: 0,
    disabilityType: DisabilityType.none,
    wordsLearned: wordsLearned,
    totalStars: 10,
    streakDays: streakDays,
    gamesPlayed: gamesPlayed,
    averageAccuracy: accuracy,
    studyMinutesThisWeek: studyThisWeek,
    studyMinutesLastWeek: studyLastWeek,
    totalSessions: 4,
    dailyStudyMinutes: const {},
    categoryProgress: categoryProgress,
    categoryCoverage: coverage,
    wordHuntFinds: 0,
    signsWatched: 0,
    moodSummary: mood,
    wordHuntStreak: 0,
    recentScores: const [],
    lastActivityDate: _now.subtract(Duration(days: idleDays)),
  );
}

MoodSummary _lowMood(int lowCount) => MoodSummary(
  entryCount: lowCount,
  dominantMood: MoodType.sad,
  latestMood: MoodType.sad,
  lowCount: lowCount,
);

List<ParentRecommendation> _run(
  List<ChildSummary> children, {
  EducatorAudience audience = EducatorAudience.teacher,
  int maxCards = 6,
}) => generateEducatorRecommendations(
  children,
  audience: audience,
  now: _now,
  maxCards: maxCards,
);

void main() {
  group('rollup', () {
    test('three or more learners with one concern collapse into one card', () {
      final recs = _run([
        for (final n in ['Ana', 'Ben', 'Cy', 'Dee', 'Eli', 'Fay'])
          _child(n, idleDays: 18),
      ], audience: EducatorAudience.parent);

      final inactive = recs
          .where((r) => r.kind == EducatorRecommendationKind.inactive)
          .toList();
      expect(
        inactive,
        hasLength(1),
        reason: 'six identical cards is what this replaced',
      );
      expect(inactive.single.title, '6 children have not practised recently');
      expect(inactive.single.description, contains('Ana, Ben and 4 more'));
      expect(
        inactive.single.childName,
        isEmpty,
        reason: 'a rollup names no single learner',
      );
      expect(inactive.single.profileId, isNull);
    });

    test('two learners stay as individual cards', () {
      final recs = _run([
        _child('Ana', idleDays: 18),
        _child('Ben', idleDays: 18),
      ]);

      expect(
        recs.where((r) => r.kind == EducatorRecommendationKind.inactive),
        hasLength(2),
      );
      expect(recs.map((r) => r.title), contains('Encourage Ana to practice'));
      expect(recs.map((r) => r.title), contains('Encourage Ben to practice'));
    });

    test('the rollup noun follows the audience', () {
      final children = [
        for (final n in ['Ana', 'Ben', 'Cy']) _child(n, idleDays: 18),
      ];
      expect(_run(children).first.title, contains('students'));
      expect(
        _run(children, audience: EducatorAudience.parent).first.title,
        contains('children'),
      );
    });

    test('celebrations are never rolled up', () {
      final recs = _run([
        for (final n in ['Ana', 'Ben', 'Cy', 'Dee']) _child(n, streakDays: 9),
      ]);

      final streaks = recs
          .where((r) => r.kind == EducatorRecommendationKind.streak)
          .toList();
      expect(streaks, hasLength(4));
      expect(streaks.every((r) => r.childName.isNotEmpty), isTrue);
    });
  });

  group('fairness', () {
    test('every learner is heard before any learner speaks twice', () {
      // Ana qualifies for four separate cards; the old generator would have
      // spent the whole feed on her and Ben.
      final recs = _run([
        _child(
          'Ana',
          idleDays: 18,
          accuracy: 0.2,
          studyThisWeek: 5,
          studyLastWeek: 60,
          mood: _lowMood(4),
        ),
        _child('Ben', idleDays: 18),
        _child('Cy', streakDays: 9),
        _child('Dee', coverage: const {'Animals': 0.9, 'Colors': 0.85, 'Food': 0.9}),
      ]);

      final named = recs.map((r) => r.childName).toSet();
      expect(named, containsAll(<String>['Ana', 'Ben', 'Cy', 'Dee']));
    });

    test('a learner keeps only their most severe card in the first round', () {
      // Two idle learners, so the inactive rollup (three or more) stays out of
      // the way and the round-robin is what is under test. Ana qualifies for
      // three cards; with only two slots she must still yield one to Ben.
      final recs = _run([
        _child('Ana', idleDays: 18, accuracy: 0.2, mood: _lowMood(4)),
        _child('Ben', idleDays: 18),
      ], maxCards: 2);

      expect(recs.map((r) => r.childName), ['Ana', 'Ben']);
      expect(
        recs.first.kind,
        EducatorRecommendationKind.wellbeing,
        reason: 'wellbeing outranks accuracy and absence',
      );
    });

    test('a rollup speaks for the learners it absorbed', () {
      // Ana has her own louder concerns, but Ben and Cy have nothing except
      // the absence they share with her — they are heard through the rollup
      // rather than being crowded out entirely.
      final recs = _run([
        _child('Ana', idleDays: 18, accuracy: 0.2, mood: _lowMood(4)),
        _child('Ben', idleDays: 18),
        _child('Cy', idleDays: 18),
      ], maxCards: 3);

      expect(recs.map((r) => r.kind), [
        EducatorRecommendationKind.wellbeing,
        EducatorRecommendationKind.struggling,
        EducatorRecommendationKind.inactive,
      ]);
      final rollup = recs.last;
      expect(rollup.childName, isEmpty);
      expect(rollup.title, '3 students have not practised recently');
      // Two names then a count, so a long roster cannot blow the card open.
      expect(rollup.description, startsWith('Ana, Ben and 1 more'));
    });

    test('respects maxCards', () {
      final recs = _run([
        for (final n in ['Ana', 'Ben', 'Cy', 'Dee', 'Eli', 'Fay', 'Gus'])
          _child(n, streakDays: 9),
      ]);
      expect(recs, hasLength(6));
    });
  });

  group('severity order', () {
    test('concerns come before celebrations', () {
      final recs = _run([
        _child('Ana', streakDays: 9),
        _child('Ben', accuracy: 0.3, gamesPlayed: 6),
      ]);

      expect(recs.first.kind, EducatorRecommendationKind.struggling);
      expect(recs.last.kind, EducatorRecommendationKind.streak);
    });

    test('wellbeing outranks every other concern', () {
      final recs = _run([
        _child('Ana', accuracy: 0.1, gamesPlayed: 9),
        _child('Ben', mood: _lowMood(5)),
      ]);
      expect(recs.first.kind, EducatorRecommendationKind.wellbeing);
      expect(recs.first.childName, 'Ben');
    });
  });

  group('thresholds', () {
    test('a learner who has never played is not called struggling', () {
      // accuracy defaults to 0 with no graded games — the old rule
      // (`accuracy > 0 && accuracy < 0.5`) let a single lucky game through
      // while this one waits for three.
      final recs = _run([_child('Ana', gamesPlayed: 0, accuracy: 0)]);
      expect(
        recs.map((r) => r.kind),
        isNot(contains(EducatorRecommendationKind.struggling)),
      );
    });

    test('unexplored categories only surface once a learner has started', () {
      final never = _run([
        _child('Ana', gamesPlayed: 0, accuracy: 0),
      ]);
      expect(
        never.map((r) => r.kind),
        isNot(contains(EducatorRecommendationKind.unexplored)),
        reason: '"13 categories unexplored" just restates "hasn\'t begun"',
      );
    });

    test('an idle learner inside the grace window raises nothing', () {
      final recs = _run([_child('Ana')]);
      expect(recs.single.kind, EducatorRecommendationKind.allGood);
    });

    test('a falling study trend is reported with both weeks', () {
      final recs = _run([
        _child('Ana', studyThisWeek: 10, studyLastWeek: 60),
      ]);
      final declining = recs.singleWhere(
        (r) => r.kind == EducatorRecommendationKind.declining,
      );
      expect(declining.description, contains('10m vs 60m'));
    });
  });

  group('Filipino', () {
    // The dashboard around these cards is localised, so a Filipino educator
    // reading an English recommendation is the one thing left in English.
    List<ParentRecommendation> runFil(
      List<ChildSummary> children, {
      EducatorAudience audience = EducatorAudience.parent,
    }) => generateEducatorRecommendations(
      children,
      audience: audience,
      filipino: true,
      now: _now,
    );

    test('every card and action is translated', () {
      final en = _run([
        _child('Ana', mood: _lowMood(4)),
        _child('Ben', idleDays: 18),
        _child('Cy', accuracy: 0.2, gamesPlayed: 8),
        _child('Dee', streakDays: 9),
        _child('Eli', studyThisWeek: 5, studyLastWeek: 60),
      ], audience: EducatorAudience.parent);
      final fil = runFil([
        _child('Ana', mood: _lowMood(4)),
        _child('Ben', idleDays: 18),
        _child('Cy', accuracy: 0.2, gamesPlayed: 8),
        _child('Dee', streakDays: 9),
        _child('Eli', studyThisWeek: 5, studyLastWeek: 60),
      ]);

      expect(fil, hasLength(en.length));
      for (var i = 0; i < fil.length; i++) {
        expect(fil[i].kind, en[i].kind);
        expect(fil[i].title, isNot(en[i].title), reason: '${fil[i].kind}');
        expect(
          fil[i].description,
          isNot(en[i].description),
          reason: '${fil[i].kind}',
        );
        expect(
          fil[i].actionLabel,
          isNot(en[i].actionLabel),
          reason: '${fil[i].kind} action',
        );
        // Routes are not copy and must not be translated.
        expect(fil[i].actionRoute, en[i].actionRoute);
      }
    });

    test('the rollup counts in Filipino take the singular noun', () {
      // "6 mga anak" is a double plural; the numeral already pluralises.
      final recs = runFil([
        for (final n in ['Ana', 'Ben', 'Cy', 'Dee', 'Eli', 'Fay'])
          _child(n, idleDays: 18),
      ]);
      final rollup = recs.singleWhere(
        (r) => r.kind == EducatorRecommendationKind.inactive,
      );
      expect(rollup.title, contains('6 anak'));
      expect(rollup.title, isNot(contains('mga anak')));
      expect(rollup.description, contains('Ana, Ben at 4 pa'));
    });

    test('the teacher rollup uses the teacher noun', () {
      final recs = runFil([
        for (final n in ['Ana', 'Ben', 'Cy']) _child(n, idleDays: 18),
      ], audience: EducatorAudience.teacher);
      expect(recs.first.title, contains('estudyante'));
      expect(recs.first.title, isNot(contains('anak')));
    });

    test('the all-clear card is translated too', () {
      final recs = runFil([_child('Ana')]);
      expect(recs.single.kind, EducatorRecommendationKind.allGood);
      expect(recs.single.title, 'Magpatuloy sa magandang gawa!');
      expect(recs.single.actionLabel, 'Tingnan ang analytics');
    });
  });

  group('actions', () {
    test('every card offers a next step', () {
      final recs = _run([
        _child('Ana', mood: _lowMood(4)),
        _child('Ben', idleDays: 18),
        _child('Cy', accuracy: 0.2, gamesPlayed: 8),
        _child('Dee', streakDays: 9),
        _child('Eli'),
      ]);

      expect(recs, isNotEmpty);
      for (final rec in recs) {
        expect(rec.actionLabel, isNotEmpty, reason: rec.title);
        expect(rec.actionRoute, startsWith('/'), reason: rec.title);
      }
    });

    test('a per-learner action carries that learner id and name', () {
      final recs = _run([_child('Ana Cruz', idleDays: 18)]);
      final rec = recs.single;
      expect(rec.profileId, 'id-Ana Cruz');
      expect(rec.actionRoute, startsWith('/child-alarms/id-Ana Cruz'));
      expect(
        rec.actionRoute,
        contains('name=Ana+Cruz'),
        reason: 'the name is a query component, so it must be encoded',
      );
    });

    test('a tab destination is recognised so the card can go() to it', () {
      // Pushing a live shell branch trips Navigator's duplicate-page-key
      // assertion, and the user gets the global error snackbar instead of
      // navigating. Found on the tablet: "See analytics" did exactly that.
      expect(isEducatorTabRoute('/teacher-analytics'), isTrue);
      expect(isEducatorTabRoute('/multi-dashboard'), isTrue);

      // Drill-downs must stay pushable, query string and all.
      expect(isEducatorTabRoute('/child-alarms/id-Ana?name=Ana'), isFalse);
      expect(isEducatorTabRoute('/progress-timeline/id-Ana?name=Ana'), isFalse);
      expect(isEducatorTabRoute('/parent-teacher-notes/id-Ana?name=Ana'), isFalse);
      expect(isEducatorTabRoute('/flashcards'), isFalse);
    });

    test('every route the generator emits is classifiable', () {
      // The point is not the split itself but that nothing new slips in
      // unclassified: a route that is a tab must be reachable by go(), and one
      // that is not must be safe to push.
      final recs = [
        ..._run([
          _child('Ana', mood: _lowMood(4)),
          _child('Ben', idleDays: 18),
          _child('Cy', accuracy: 0.2, gamesPlayed: 8),
          _child('Dee', streakDays: 9),
          _child('Eli', studyThisWeek: 5, studyLastWeek: 60),
        ]),
        ..._run(const []),
      ];

      for (final rec in recs) {
        final isTab = isEducatorTabRoute(rec.actionRoute);
        // A tab route is always a bare path — a rollup never targets one
        // learner, so it never needs an id segment.
        expect(
          isTab,
          equals(educatorTabPaths.contains(rec.actionRoute)),
          reason: rec.actionRoute,
        );
        if (!isTab) {
          expect(rec.actionRoute, startsWith('/'), reason: rec.actionRoute);
        }
      }
    });

    test('the all-clear card still points somewhere', () {
      final recs = _run([_child('Ana')]);
      expect(recs.single.kind, EducatorRecommendationKind.allGood);
      expect(recs.single.actionRoute, '/teacher-analytics');
    });

    test('an empty roster yields the all-clear, not a crash', () {
      final recs = _run(const []);
      expect(recs, hasLength(1));
      expect(recs.single.kind, EducatorRecommendationKind.allGood);
    });
  });
}
