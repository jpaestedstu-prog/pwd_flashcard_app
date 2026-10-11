import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/notifications/services/alert_service.dart';

/// The educator's "streak was broken" alert.
///
/// It asked for a stored streak of 0, which only learners who never had a
/// streak show (streaks switched off for a control group): it never fired for
/// a real broken streak. The stored streak only moves on the next activity, so
/// a broken run still reads as its old length until the learner returns.
LearningProgress _progress({required int streak, required DateTime last}) =>
    LearningProgress(
      profileId: 'learner',
      lastActivityDate: last,
      streakDays: streak,
    );

void main() {
  final last = DateTime(2026, 10, 9, 18);
  String? keyFor(LearningProgress p, DateTime now) =>
      AlertService.streakBrokenAlertKey('learner', p, now: now);

  test('a run of days that was missed raises it', () {
    expect(
      keyFor(_progress(streak: 5, last: last), DateTime(2026, 10, 11, 8)),
      'streakBroken_learner_2026-10-9',
    );
  });

  test('a streak still alive does not', () {
    expect(keyFor(_progress(streak: 5, last: last), DateTime(2026, 10, 10, 20)),
        isNull);
    expect(keyFor(_progress(streak: 5, last: last), DateTime(2026, 10, 9, 22)),
        isNull);
  });

  test('no streak, or a single day, is nothing to report', () {
    final later = DateTime(2026, 10, 14);
    expect(keyFor(_progress(streak: 0, last: last), later), isNull);
    expect(keyFor(_progress(streak: 1, last: last), later), isNull);
  });

  test('one broken run is reported once, however long the learner is away',
      () {
    final p = _progress(streak: 5, last: last);
    expect(keyFor(p, DateTime(2026, 10, 11)), isNotNull);
    expect(keyFor(p, DateTime(2026, 10, 11)), keyFor(p, DateTime(2026, 10, 16)));
  });

  test('a run that ended over a week ago is old news', () {
    final p = _progress(streak: 5, last: last);
    expect(keyFor(p, DateTime(2026, 10, 16)), isNotNull);
    expect(keyFor(p, DateTime(2026, 10, 17)), isNull);
  });
}
