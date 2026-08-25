import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_summary.dart';

/// [MoodSummary] is what a parent or teacher sees of a learner's wellbeing.
/// It is the only mood data that reaches a caregiver screen, so both what it
/// says and what it deliberately withholds are worth pinning down.

final _now = DateTime(2026, 8, 25, 12);

MoodEntry _entry(
  MoodType mood, {
  required int daysAgo,
  String? note,
}) {
  return MoodEntry(
    id: 'e-${mood.name}-$daysAgo-${note ?? ''}',
    profileId: 'p1',
    mood: mood,
    note: note,
    timestamp: _now.subtract(Duration(days: daysAgo, hours: 1)),
  );
}

void main() {
  group('MoodSummary.fromEntries', () {
    test('an empty history summarises to nothing, not to neutral', () {
      final s = MoodSummary.fromEntries(const [], now: _now);
      expect(s.hasData, isFalse);
      expect(s.dominantMood, isNull);
      expect(s.averageValue, isNull);
      expect(s.needsAttention, isFalse);
    });

    test('entries outside the window are excluded', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.happy, daysAgo: 1),
          _entry(MoodType.sad, daysAgo: 30),
        ],
        now: _now,
      );
      expect(s.entryCount, 1);
      expect(s.dominantMood, MoodType.happy);
    });

    test('reports the most common mood and the latest one separately', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.happy, daysAgo: 4),
          _entry(MoodType.happy, daysAgo: 3),
          _entry(MoodType.tired, daysAgo: 0),
        ],
        now: _now,
      );
      expect(s.dominantMood, MoodType.happy);
      expect(s.latestMood, MoodType.tired, reason: 'most recent, not most common');
      expect(s.entryCount, 3);
    });

    test('a tie breaks toward the harder mood', () {
      // Three good days and three bad ones is not a "mostly happy" week for
      // the person deciding whether to check in on this learner.
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.happy, daysAgo: 5),
          _entry(MoodType.happy, daysAgo: 4),
          _entry(MoodType.happy, daysAgo: 3),
          _entry(MoodType.sad, daysAgo: 2),
          _entry(MoodType.sad, daysAgo: 1),
          _entry(MoodType.sad, daysAgo: 0),
        ],
        now: _now,
      );
      expect(s.dominantMood, MoodType.sad);
    });

    test('averages the numeric values', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.frustrated, daysAgo: 2), // 1
          _entry(MoodType.excited, daysAgo: 1), // 6
        ],
        now: _now,
      );
      expect(s.averageValue, closeTo(3.5, 1e-9));
    });
  });

  group('MoodSummary.needsAttention', () {
    test('three hard days in the week raises it', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.sad, daysAgo: 3),
          _entry(MoodType.frustrated, daysAgo: 2),
          _entry(MoodType.sad, daysAgo: 1),
        ],
        now: _now,
      );
      expect(s.lowCount, 3);
      expect(s.needsAttention, isTrue);
    });

    test('one bad afternoon does not', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.happy, daysAgo: 3),
          _entry(MoodType.sad, daysAgo: 2),
          _entry(MoodType.happy, daysAgo: 1),
        ],
        now: _now,
      );
      expect(s.needsAttention, isFalse);
    });

    test('a single sad check-in is not a sample worth flagging', () {
      final s = MoodSummary.fromEntries(
        [_entry(MoodType.sad, daysAgo: 1)],
        now: _now,
      );
      expect(s.entryCount, 1);
      expect(s.needsAttention, isFalse,
          reason: 'needs at least three check-ins to mean anything');
    });

    test('tired is not treated as a hard day', () {
      // Tired is a normal state at the end of a school day; only sad and
      // frustrated count, or the flag would be permanently on.
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.tired, daysAgo: 3),
          _entry(MoodType.tired, daysAgo: 2),
          _entry(MoodType.tired, daysAgo: 1),
        ],
        now: _now,
      );
      expect(s.lowCount, 0);
      expect(s.needsAttention, isFalse);
    });
  });

  group('what a caregiver is not shown', () {
    test('the summary carries no note text anywhere in it', () {
      final s = MoodSummary.fromEntries(
        [
          _entry(MoodType.sad, daysAgo: 2, note: 'nobody sat with me at lunch'),
          _entry(MoodType.happy, daysAgo: 1, note: 'my sister helped me'),
          _entry(MoodType.happy, daysAgo: 0),
        ],
        now: _now,
      );

      final rendered = [
        s.labelOf(isFilipino: false),
        s.labelOf(isFilipino: true),
      ].join(' ');

      expect(rendered, isNot(contains('lunch')));
      expect(rendered, isNot(contains('sister')));
      // And there is no field on the summary that could carry one.
      expect(s.entryCount, 3);
      expect(s.dominantMood, MoodType.happy);
    });

    test('the roster line is filled in for both languages', () {
      final s = MoodSummary.fromEntries(
        [_entry(MoodType.happy, daysAgo: 1)],
        now: _now,
      );
      expect(s.labelOf(isFilipino: false), 'Mostly Happy');
      expect(s.labelOf(isFilipino: true), contains('Masaya'));

      const empty = MoodSummary.empty;
      expect(empty.labelOf(isFilipino: false), isNotEmpty);
      expect(empty.labelOf(isFilipino: true), isNotEmpty);
    });
  });
}
