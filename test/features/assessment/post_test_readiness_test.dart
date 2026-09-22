import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/models/post_test_readiness.dart';

/// The wait between the two halves of the instrument.
///
/// The post-test card used to unlock the instant a pre-test was submitted, so
/// a learner could sit both in one afternoon and the app would call the
/// difference a learning gain. It is not one: it is short-term recall of the
/// pre-test. Two conditions now have to hold — time on the calendar, and days
/// the learner actually studied — and an educator's assignment overrides both.
void main() {
  /// A pre-test sat at 4pm on 1 September. Every case below measures from it;
  /// the "no pre-test" cases call [PostTestReadiness.evaluate] directly.
  final preTestAt = DateTime(2026, 9, 1, 16);

  PostTestReadiness evaluate({
    List<DateTime> studyDates = const [],
    required DateTime now,
    bool assigned = false,
  }) => PostTestReadiness.evaluate(
    preTestAt: preTestAt,
    studyDates: studyDates,
    now: now,
    assignedByEducator: assigned,
  );

  /// Enough study days to clear the practice bar, on consecutive mornings.
  List<DateTime> studyDays(int count, {int from = 2}) => [
    for (var i = 0; i < count; i++) DateTime(2026, 9, from + i, 9),
  ];

  group('no pre-test', () {
    test('there is nothing to compare against', () {
      final r = PostTestReadiness.evaluate(
        preTestAt: null,
        studyDates: const [],
        now: DateTime(2026, 9, 30),
      );
      expect(r.gate, PostTestGate.noPreTest);
      expect(r.isReady, isFalse);
      expect(r.needsPreTest, isTrue);
      expect(r.lockMessage, 'Complete a Pre-Test first');
    });
  });

  group('the time condition', () {
    test('the same afternoon is not a learning gain', () {
      final r = evaluate(now: DateTime(2026, 9, 1, 17));
      expect(r.gate, PostTestGate.waiting);
      expect(r.daysRemaining, 7);
    });

    test('days are counted on the calendar, not in 24-hour blocks', () {
      // 4pm Monday → 9am Tuesday is one day to a teacher, and 17 hours to a
      // stopwatch. The teacher is the one writing the report.
      final r = evaluate(now: DateTime(2026, 9, 2, 9));
      expect(r.daysRemaining, 6);
    });

    test('a full week clears it', () {
      final r = evaluate(
        studyDates: studyDays(3),
        now: DateTime(2026, 9, 8, 9),
      );
      expect(r.gate, PostTestGate.ready);
      expect(r.isReady, isTrue);
      expect(r.lockMessage, isNull);
    });

    test('a clock that went backwards does not add days', () {
      final r = evaluate(now: DateTime(2026, 8, 20));
      expect(r.daysRemaining, PostTestReadiness.requiredDays);
    });
  });

  group('the practice condition', () {
    test('a week in a drawer is not teaching', () {
      final r = evaluate(now: DateTime(2026, 9, 20));
      expect(r.gate, PostTestGate.waiting);
      expect(r.daysRemaining, 0);
      expect(r.sessionsRemaining, PostTestReadiness.requiredSessions);
    });

    test('two sittings in one afternoon are one day of teaching', () {
      final r = evaluate(
        studyDates: [
          DateTime(2026, 9, 3, 9),
          DateTime(2026, 9, 3, 11),
          DateTime(2026, 9, 3, 15),
        ],
        now: DateTime(2026, 9, 20),
      );
      expect(r.sessionsRemaining, 2);
    });

    test('study before the pre-test does not count towards it', () {
      final r = evaluate(
        studyDates: [
          DateTime(2026, 8, 20, 9),
          DateTime(2026, 8, 25, 9),
          DateTime(2026, 8, 30, 9),
        ],
        now: DateTime(2026, 9, 20),
      );
      expect(r.sessionsRemaining, PostTestReadiness.requiredSessions);
    });

    test('the pre-test day itself is not practice', () {
      // Sitting a test is not studying, and a learner who does both on one
      // afternoon should not get a free day towards the bar.
      final r = evaluate(
        studyDates: [DateTime(2026, 9, 1, 17)],
        now: DateTime(2026, 9, 20),
      );
      expect(r.sessionsRemaining, PostTestReadiness.requiredSessions);
    });

    test('three separate days clear it', () {
      final r = evaluate(
        studyDates: studyDays(3),
        now: DateTime(2026, 9, 20),
      );
      expect(r.gate, PostTestGate.ready);
    });
  });

  group('the educator override', () {
    test('an assigned post-test ends the wait immediately', () {
      final r = evaluate(now: DateTime(2026, 9, 1, 17), assigned: true);
      expect(r.gate, PostTestGate.assigned);
      expect(r.isReady, isTrue);
      expect(r.lockMessage, isNull);
    });

    test('but it cannot conjure a pre-test that does not exist', () {
      final r = PostTestReadiness.evaluate(
        preTestAt: null,
        studyDates: const [],
        now: DateTime(2026, 9, 30),
        assignedByEducator: true,
      );
      expect(r.gate, PostTestGate.noPreTest);
    });
  });

  group('what the learner is told', () {
    test('both conditions outstanding reads as one sentence', () {
      final r = evaluate(now: DateTime(2026, 9, 3));
      expect(r.lockMessage, 'Keep studying — 5 more days and 3 more study days');
    });

    test('a single day is singular', () {
      final r = evaluate(
        studyDates: studyDays(3),
        now: DateTime(2026, 9, 7),
      );
      expect(r.lockMessage, 'Keep studying — 1 more day');
    });

    test('only the practice bar left mentions only practice', () {
      final r = evaluate(
        studyDates: studyDays(2),
        now: DateTime(2026, 9, 20),
      );
      expect(r.lockMessage, 'Keep studying — 1 more study day');
    });
  });

  group('what the educator is told', () {
    test('the three states read differently', () {
      expect(
        evaluate(now: DateTime(2026, 9, 3)).educatorSummary,
        'Pre-test done · post-test suggested after 5 d, 3 study days',
      );
      expect(
        evaluate(
          studyDates: studyDays(3),
          now: DateTime(2026, 9, 9),
        ).educatorSummary,
        'Ready for post-test',
      );
      expect(
        evaluate(now: DateTime(2026, 9, 2), assigned: true).educatorSummary,
        'Post-test assigned',
      );
      expect(
        PostTestReadiness.evaluate(
          preTestAt: null,
          studyDates: const [],
          now: DateTime(2026, 9, 2),
        ).educatorSummary,
        'Pre-test outstanding',
      );
    });
  });
}
