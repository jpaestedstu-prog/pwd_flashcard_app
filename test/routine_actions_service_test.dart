import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/cloud_sync_outcome.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';

/// The routine service's remote actions, end to end against the local mirror.
///
/// Plain `test()`s rather than `testWidgets`: these await real Hive writes,
/// which is safe outside the widget-test fake-async zone and hangs inside it.
/// Firebase is not configured here, so every cloud write reports `localOnly`
/// and the local mirror is the thing checked — which is also exactly what the
/// learner's device decides the lock from.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/routine_actions_service');
    if (!Hive.isBoxOpen('routine_logs')) {
      await Hive.openBox('routine_logs');
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  var serial = 0;
  String newLearner() => 'learner-${serial++}';

  final rose = UserProfile(
    id: 'rose',
    name: 'Rose',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const service = RoutineService();

  test('an educator excuse is kept and reads as excused, with who did it',
      () async {
    final id = newLearner();
    final outcome = await service.excuseStep(
      childProfileId: id,
      day: today,
      stepId: 'brush',
      by: rose,
    );
    expect(outcome, CloudSyncOutcome.localOnly);
    final view = RoutineService.viewFromCache(id, today);
    expect(view.isExcused('brush'), isTrue);
    expect(view.excuse('brush')!.byName, 'Rose');
    expect(view.excuse('brush')!.source, RoutineMarkSource.educator);
  });

  test('an approval counts as done, and taking it back undoes it', () async {
    final id = newLearner();
    await service.approveStep(
      childProfileId: id,
      day: today,
      stepId: 'brush',
      by: rose,
    );
    expect(RoutineService.viewFromCache(id, today).isDone('brush'), isTrue);

    await service.revokeApproval(
      childProfileId: id,
      day: today,
      stepId: 'brush',
      by: rose,
    );
    final after = RoutineService.viewFromCache(id, today);
    expect(after.isDone('brush'), isFalse);
    // The change of mind is kept, not erased.
    expect(
      HiveService.getRoutineDayActions(id, today).approved['brush']!.revokedAt,
      isNotNull,
    );
  });

  test('an educator can take back an excuse granted on the tablet', () async {
    final id = newLearner();
    await service.excuseOnDevice(profileId: id, day: today, stepId: 'brush');
    expect(RoutineService.viewFromCache(id, today).isExcused('brush'), isTrue);
    expect(
      HiveService.getRoutineDayLog(id, today).excused['brush']!.source,
      RoutineMarkSource.learnerDevice,
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.revokeExcuse(
      childProfileId: id,
      day: today,
      stepId: 'brush',
      by: rose,
    );
    expect(RoutineService.viewFromCache(id, today).excuse('brush'), isNull);
  });

  test('starting the day over for a learner clears ticks and excuses', () async {
    final id = newLearner();
    await service.setStepDone(id, today, 'brush', true);
    await service.excuseStep(
      childProfileId: id,
      day: today,
      stepId: 'dress',
      by: rose,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await service.resetDayForLearner(childProfileId: id, day: today, by: rose);

    final view = RoutineService.viewFromCache(id, today);
    expect(view.doneIds, isEmpty);
    expect(view.excusedIds, isEmpty);
    expect(HiveService.getRoutineDayActions(id, today).resetByName, 'Rose');
  });

  test('a tick from before a reset re-ticks when tapped, never un-ticks',
      () async {
    final id = newLearner();
    final earlier = DateTime.now().subtract(const Duration(minutes: 10));
    final resetAt = DateTime.now().subtract(const Duration(minutes: 1));
    await HiveService.saveRoutineDayLog(
      RoutineDayLog.empty(id, today).setDone('brush', true, at: earlier),
    );
    await HiveService.saveRoutineDayActions(
      RoutineDayActions.empty(id, today).withReset(at: resetAt, byName: 'Rose'),
    );
    expect(RoutineService.viewFromCache(id, today).isTicked('brush'), isFalse);

    await service.toggleStep(id, today, 'brush');
    expect(RoutineService.viewFromCache(id, today).isTicked('brush'), isTrue);
  });

  test('the lock sighting is written once and the first one stands', () async {
    final id = newLearner();
    final first = DateTime.now().subtract(const Duration(minutes: 3));
    await service.markLockShown(id, today, 'brush', at: first);
    await service.markLockShown(id, today, 'brush');
    expect(HiveService.getRoutineDayLog(id, today).lockShownAt['brush'], first);
  });
}
