import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_models.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/local/local_repository.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart'
    show canDeleteOwnProfile;

/// Both app stores require that anyone who can make an account in the app can
/// delete it there (Apple 5.1.1(v), Google Play's account deletion policy).
/// Settings now offers "Delete this profile" to every profile saved online,
/// and the online copy's delete can no longer be lost to an offline tablet.

UserProfile _profile(UserRole role, {bool guest = false}) => UserProfile(
      id: 'p-${role.name}',
      name: 'Ana',
      role: role,
      avatarIndex: 0,
      createdAt: DateTime(2026, 10, 9),
      isGuestPlayer: guest,
    );

void main() {
  group('who is offered "Delete this profile"', () {
    test('every role that is saved online', () {
      for (final role in [
        UserRole.player,
        UserRole.student,
        UserRole.child,
        UserRole.teacher,
        UserRole.parent,
      ]) {
        expect(
          canDeleteOwnProfile(_profile(role), viewingAsStudent: false),
          isTrue,
          reason: role.name,
        );
      }
    });

    test('not a Guest Player (never online), not nobody', () {
      expect(
        canDeleteOwnProfile(
          _profile(UserRole.player, guest: true),
          viewingAsStudent: false,
        ),
        isFalse,
      );
      expect(canDeleteOwnProfile(null, viewingAsStudent: false), isFalse);
    });

    test('not an educator previewing a learner — that would delete the learner',
        () {
      expect(
        canDeleteOwnProfile(_profile(UserRole.student), viewingAsStudent: true),
        isFalse,
      );
    });
  });

  group('the online delete waits in the sync queue', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/self_delete_profile');
      await SyncQueueStorage.init();
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <void>[],
      );
    });

    test('queued with its messaging handle when the cloud is not up', () async {
      // Firebase is never configured in unit tests: exactly the offline case.
      await LocalRepository.deleteOnline('ana-id', 'ana-482913');

      final ops = SyncQueueStorage.getPendingOperations()
          .where((o) => o.entityId == 'ana-id')
          .toList();
      expect(ops, hasLength(1));
      expect(ops.single.entity, SyncEntity.profile);
      expect(ops.single.type, SyncOperationType.delete);
      expect(ops.single.payload, {'username': 'ana-482913'});
    });

    test('asking twice keeps one delete', () async {
      await LocalRepository.deleteOnline('ben-id', null);
      await LocalRepository.deleteOnline('ben-id', null);
      final ops = SyncQueueStorage.getPendingOperations()
          .where((o) => o.entityId == 'ben-id');
      expect(ops, hasLength(1));
      expect(ops.single.payload, isEmpty);
    });
  });
}
