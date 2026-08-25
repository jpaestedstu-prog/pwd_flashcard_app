import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// What happens to the tablet a profile was restored *away from*.
///
/// Recovering a profile with its code re-stamps `profiles/{id}.owner_uid` to
/// the new device, and every assessment rule pins writes to the owning uid.
/// The first tablet therefore goes read-only for that profile with nothing on
/// screen saying so — found on two real devices, where a delete left the
/// teacher's list, stayed in Firestore, and came back to the other tablet on
/// its next pull.
///
/// The sync itself is not a defect: one profile, one owner, by design — see
/// `docs/multi_device_sync.md`, which also records what a real multi-device
/// model would need. What can be fixed is the lie. A refusal is permanent, so reporting
/// it as "not sent yet, it will upload when syncing is working" tells a
/// teacher to wait for something that is never going to happen.
///
/// No `testWidgets` in this file — it writes to Hive.
void main() {
  const educatorId = 'educator-1';
  const bucket = 'assignments_$educatorId';

  AssessmentAssignment assignment(String id) => AssessmentAssignment(
    id: id,
    assessmentId: 'a1',
    assessmentTitle: 'Animals Check',
    assignedBy: educatorId,
    studentIds: const ['student-1'],
    assignedAt: DateTime(2026, 8),
  );

  setUpAll(() async {
    const cacheDir = './build/test_cache/ownership_transfer';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray flutter_tester — Hive reports it below.
    }
    Hive.init(cacheDir);
    for (final name in const ['progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  setUp(() async => Hive.box('progress').clear());

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  group('isOwnershipRefusal', () {
    test('a rules rejection is a refusal', () {
      expect(
        AssessmentCloudService.isOwnershipRefusal(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ),
        isTrue,
      );
    });

    test('an unreachable server is not', () {
      // This one *is* worth waiting for, and must keep saying so.
      expect(
        AssessmentCloudService.isOwnershipRefusal(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isFalse,
      );
    });

    test('a timeout is not', () {
      // Every remote call is time-boxed, because a Firestore write offline
      // never completes on its own.
      expect(
        AssessmentCloudService.isOwnershipRefusal(
          const TimeoutException$('timed out'),
        ),
        isFalse,
      );
    });
  });

  group('the outcomes stay distinguishable', () {
    test('notOwner is not localOnly', () {
      // The assign screen and the tracking screen both branch on this, and
      // collapsing the two would restore the original wrong message.
      expect(CloudSyncOutcome.notOwner, isNot(CloudSyncOutcome.localOnly));
      expect(CloudSyncOutcome.values, hasLength(3));
    });
  });

  group('AssignmentsNotifier.refresh', () {
    test('picks up rows written behind its back', () async {
      // Hydration writes straight to Hive. The notifier loads once at
      // construction and otherwise only re-reads after its own writes, so
      // without an explicit refresh the "Check for new results" button pulled
      // correctly and changed nothing on screen.
      final notifier = AssignmentsNotifier(educatorId);
      expect(notifier.state, isEmpty);

      await AssessmentService.saveAssignment(educatorId, assignment('as1'));
      expect(
        notifier.state,
        isEmpty,
        reason: 'the stale read this exists to close',
      );

      notifier.refresh();

      expect(notifier.state, hasLength(1));
      notifier.dispose();
    });

    test('drops rows deleted behind its back', () async {
      // The cross-device delete: reconcile removes the row from Hive after a
      // server-sourced pull said the cloud no longer has it.
      await AssessmentService.saveAssignment(educatorId, assignment('as1'));
      final notifier = AssignmentsNotifier(educatorId);
      expect(notifier.state, hasLength(1));

      await AssessmentService.deleteAssignment(educatorId, 'as1');
      notifier.refresh();

      expect(notifier.state, isEmpty);
      notifier.dispose();
    });
  });

  group('a refused delete keeps its tombstone', () {
    test('so the row is not handed back by the next pull', () async {
      // The local delete stands whatever the cloud says — but the tombstone is
      // what stops the very next hydrate merging the surviving cloud row
      // straight back in. Verified on the device where this went wrong.
      await AssessmentService.saveAssignment(educatorId, assignment('as1'));
      await AssessmentService.markDeleted(bucket, 'as1');
      await AssessmentService.deleteAssignment(educatorId, 'as1');

      await AssessmentService.mergeAssignments(educatorId, [assignment('as1')]);

      expect(
        AssessmentService.getAssignments(educatorId),
        isEmpty,
        reason: 'a delete the teacher made must not come back to their own '
            'tablet just because the cloud still has it',
      );
      expect(AssessmentService.getPendingDeletions(bucket), contains('as1'));
    });
  });
}

/// A stand-in for `dart:async`'s TimeoutException without importing it purely
/// for one line — the point is only that it is not a [FirebaseException].
class TimeoutException$ implements Exception {
  const TimeoutException$(this.message);
  final String message;
}
