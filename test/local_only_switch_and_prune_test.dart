import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/local/local_repository.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';

/// Two failures that shared one cause: **treating a refused cloud write as if
/// it had happened.**
///
/// Both were found on a tablet whose educator profile had been restored onto
/// another device, which makes this one read-only in Firestore for that
/// profile — every write comes back `permission-denied`.
///
///  * "View as student" left the educator on their own dashboard, because the
///    switch awaited a profile mirror that was refused.
///  * A routine an educator had just built vanished from the learner's
///    "My Day", because the write was refused and the next snapshot — empty,
///    and *successful* — pruned the only copy.
///
/// Plain `test()` cases with real Hive: these paths are all awaited writes,
/// which must not be driven from `testWidgets` (see the project's Hive-hang
/// notes).
UserProfile _profile(String id, {String? name, UserRole role = UserRole.student}) =>
    UserProfile(
      id: id,
      name: name ?? id,
      role: role,
      createdAt: DateTime(2026),
    );

Routine _routine(String id, String childId) => Routine(
      id: id,
      childProfileId: childId,
      setterProfileId: 'teacher',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: [
        const RoutineStep(id: 's1', activity: RoutineActivity.morningRoutine),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/local_only_switch');
    for (final name in const <String>['profiles', 'routines']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  group('switching profile is a local fact', () {
    test('saveProfileLocal stores and returns the profile without the cloud',
        () async {
      const repo = LocalRepository();
      final stored = await repo.saveProfileLocal(_profile('p-local'));

      expect(stored.id, 'p-local');
      expect(HiveService.getProfileById('p-local')?.name, 'p-local');
    });

    test('it does not mint a messaging handle', () async {
      // Handle minting is up to five live directory reads. Doing it on the
      // switch path is what made switching profile depend on the network —
      // offline it hangs, and under a denying rule set it throws. The handle
      // is publishProfile's job now.
      const repo = LocalRepository();
      final stored = await repo.saveProfileLocal(_profile('p-nohandle'));

      expect(stored.username, isNull);
    });

    test('an existing profile is overwritten, not duplicated', () async {
      const repo = LocalRepository();
      await repo.saveProfileLocal(_profile('p-twice', name: 'First'));
      await repo.saveProfileLocal(_profile('p-twice', name: 'Second'));

      expect(HiveService.getProfileById('p-twice')?.name, 'Second');
      expect(
        HiveService.getProfiles().where((p) => p['id'] == 'p-twice'),
        hasLength(1),
      );
    });
  });

  group('a routine that never reached the cloud is never pruned', () {
    test('an unsynced routine survives an empty snapshot', () async {
      // The exact sequence from the tablet: educator saves (cloud refuses, so
      // the row is cached unsynced), then the learner's stream reports zero
      // documents for that child.
      await HiveService.cacheRoutine(
        _routine('r-refused', 'child-1'),
        cloudSynced: false,
      );
      await HiveService.pruneRoutinesForChild('child-1', const <String>{});

      expect(
        HiveService.getRoutinesForChild('child-1').map((r) => r.id),
        ['r-refused'],
        reason: 'the only copy of the routine must not be deleted',
      );
      expect(HiveService.routineAwaitsCloud('r-refused'), isTrue);
    });

    test('a synced routine absent from the snapshot IS pruned', () async {
      // The behaviour the prune exists for: the educator really did delete it
      // on their own device, so the learner's mirror has to let it go.
      await HiveService.cacheRoutine(
        _routine('r-deleted', 'child-2'),
        cloudSynced: true,
      );
      await HiveService.pruneRoutinesForChild('child-2', const <String>{});

      expect(HiveService.getRoutinesForChild('child-2'), isEmpty);
    });

    test('a routine becomes prunable once its write lands', () async {
      final routine = _routine('r-late', 'child-3');
      await HiveService.cacheRoutine(routine, cloudSynced: false);
      expect(HiveService.routineAwaitsCloud('r-late'), isTrue);

      // The retry succeeds; the cloud now has a copy of its own.
      await HiveService.cacheRoutine(routine, cloudSynced: true);
      expect(HiveService.routineAwaitsCloud('r-late'), isFalse);

      await HiveService.pruneRoutinesForChild('child-3', const <String>{});
      expect(HiveService.getRoutinesForChild('child-3'), isEmpty);
    });

    test('pruning one learner leaves another learner alone', () async {
      await HiveService.cacheRoutine(
        _routine('r-keep', 'child-4'),
        cloudSynced: true,
      );
      await HiveService.cacheRoutine(
        _routine('r-other', 'child-5'),
        cloudSynced: true,
      );
      await HiveService.pruneRoutinesForChild('child-5', const <String>{});

      expect(
        HiveService.getRoutinesForChild('child-4').map((r) => r.id),
        ['r-keep'],
      );
      expect(HiveService.getRoutinesForChild('child-5'), isEmpty);
    });

    test('the sync marker does not leak into the parsed routine', () async {
      await HiveService.cacheRoutine(
        _routine('r-parse', 'child-6'),
        cloudSynced: true,
      );
      final read = HiveService.getRoutinesForChild('child-6').single;

      expect(read.id, 'r-parse');
      expect(read.name, 'Morning');
      expect(read.steps, hasLength(1));
    });
  });
}
