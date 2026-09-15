import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_wait_report.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_wait_report_section.dart';

/// The educator's weekly report: how long the lock held a learner, and how
/// often an adult stepped in.

DateTime _d(int day, int h, int m) => DateTime(2026, 9, day, h, m);

/// 7:00–7:10, locks.
const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 7,
  minute: 0,
  durationMinutes: 10,
);

Routine get _routine => Routine(
      id: 'r',
      childProfileId: 'ana',
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: const [_brush],
      lockEnabled: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineDayLog _log(int day) => RoutineDayLog.empty('ana', DateTime(2026, 9, day));

RoutineStepMark _rose(DateTime at) => RoutineStepMark(
      at: at,
      byProfileId: 'rose',
      byName: 'Rose',
      source: RoutineMarkSource.educator,
    );

RoutineWaitReport _report({
  List<RoutineDayLog> logs = const [],
  List<RoutineDayActions> actions = const [],
  DateTime? now,
}) =>
    RoutineWaitReport.from(
      profileId: 'ana',
      routines: [_routine],
      logs: logs,
      actions: actions,
      now: now ?? _d(15, 21, 0),
    );

void main() {
  test('a lock that ran its full time counts every minute it was shown', () {
    final log = _log(14)
        .withLockShown('brush', _d(14, 7, 2))
        .setDone('brush', true, at: _d(14, 7, 10));
    final r = _report(logs: [log]);
    expect(r.locksShown, 1);
    expect(r.minutesWaited, 8);
    expect(r.endedEarly, 0);
    expect(r.averageWait, 8);
  });

  test('a device that never showed the lock waited for nothing', () {
    final r = _report(logs: [_log(14).setDone('brush', true, at: _d(14, 7, 10))]);
    expect(r.isEmpty, isTrue);
    expect(r.averageWait, isNull);
  });

  test('an educator ending it early is counted, with their name', () {
    final log = _log(13).withLockShown('brush', _d(13, 7, 0));
    final acts = RoutineDayActions.empty('ana', DateTime(2026, 9, 13))
        .withApproval('brush', _rose(_d(13, 7, 3)));
    final r = _report(logs: [log], actions: [acts]);
    expect(r.endedEarly, 1);
    expect(r.minutesWaited, 3);
    expect(r.endedEarlyBy, {'Rose': 1});
  });

  test('an adult check on the tablet is early, and names nobody', () {
    final log = _log(12)
        .withLockShown('brush', _d(12, 7, 0))
        .setDone('brush', true, at: _d(12, 7, 4));
    final r = _report(logs: [log]);
    expect(r.endedEarly, 1);
    expect(r.endedEarlyBy, {'': 1});
  });

  test('excused and time-added steps are counted separately', () {
    final excusedLog = _log(11).withLockShown('brush', _d(11, 7, 0));
    final excusedActs = RoutineDayActions.empty('ana', DateTime(2026, 9, 11))
        .withExcuse('brush', _rose(_d(11, 7, 5)));
    final longerLog = _log(10)
        .withLockShown('brush', _d(10, 7, 0))
        .setDone('brush', true, at: _d(10, 7, 15));
    final longerActs = RoutineDayActions.empty('ana', DateTime(2026, 9, 10))
        .withAdjustment(
      'brush',
      RoutineStepAdjustment(changedAt: _d(10, 7, 6))
          .withAddedMinutes(5, at: _d(10, 7, 6)),
    );
    final r = _report(
      logs: [excusedLog, longerLog],
      actions: [excusedActs, longerActs],
    );
    expect(r.excused, 1);
    expect(r.addedMinutes, 5);
    expect(r.endedEarly, 0, reason: 'finishing at the moved end is on time');
    // 5 min until the excuse, and 15 min on the day with added time.
    expect(r.minutesWaited, 20);
  });

  test('time spent paused is not time waited', () {
    final log = _log(9)
        .withLockShown('brush', _d(9, 7, 0))
        .setDone('brush', true, at: _d(9, 7, 30));
    final acts = RoutineDayActions.empty('ana', DateTime(2026, 9, 9))
        .withAdjustment(
      'brush',
      RoutineStepAdjustment(changedAt: _d(9, 7, 4))
          .paused(at: _d(9, 7, 4))
          .resumed(at: _d(9, 7, 24)),
    );
    final r = _report(logs: [log], actions: [acts]);
    expect(r.pauses, 1);
    expect(r.minutesWaited, 10);
  });

  test('days outside the last seven are not in it', () {
    final old = _log(1)
        .withLockShown('brush', _d(1, 7, 0))
        .setDone('brush', true, at: _d(1, 7, 10));
    expect(_report(logs: [old]).isEmpty, isTrue);
  });

  test('a still-running lock today counts up to now only', () {
    final log = _log(15).withLockShown('brush', _d(15, 7, 0));
    final r = _report(logs: [log], now: _d(15, 7, 6));
    expect(r.minutesWaited, 6);
  });

  test('a day frozen with its times is scored as it was planned', () {
    // The routine now says 7:00; that day the step was at 9:00 for 20 min.
    final frozen = _log(14)
        .withSchedule([
          RoutineDayStep.of(
            _brush.copyWith(hour: 9, minute: 0, durationMinutes: 20),
            locks: true,
          ),
        ])
        .withLockShown('brush', _d(14, 9, 0))
        .setDone('brush', true, at: _d(14, 9, 20));
    final r = _report(logs: [frozen]);
    expect(r.minutesWaited, 20);
    expect(r.endedEarly, 0);
  });

  test('per step, in words', () {
    final logs = [
      _log(14)
          .withLockShown('brush', _d(14, 7, 0))
          .setDone('brush', true, at: _d(14, 7, 10)),
      _log(13)
          .withLockShown('brush', _d(13, 7, 0))
          .setDone('brush', true, at: _d(13, 7, 2)),
    ];
    final s = _report(logs: logs).steps.single;
    expect(s.locksShown, 2);
    expect(
      RoutineWaitReportSection.stepSentence(s, filipino: false),
      'Locked 2 days · waited 12 min · ended early 1×',
    );
  });

  test('a snapshot keeps its times through json, and an old one reads as '
      'untimed', () {
    final row = RoutineDayStep.of(_brush, locks: true);
    final back = RoutineDayStep.fromJson(row.toJson());
    expect(back.hasTiming, isTrue);
    expect(back.locks, isTrue);
    expect(back.toStep().endsOn(DateTime(2026, 9, 15)), _d(15, 7, 10));
    final old = row.toJson()
      ..remove('hour')
      ..remove('minute')
      ..remove('duration_minutes')
      ..remove('locks');
    expect(RoutineDayStep.fromJson(old).hasTiming, isFalse);
  });
}
