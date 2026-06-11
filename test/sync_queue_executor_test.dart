import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_models.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/remote/firestore_repository.dart';

class _MockFirestoreRepo extends Mock implements FirestoreRepository {}

class _FakeUserProfile extends Fake implements UserProfile {}

void main() {
  late _MockFirestoreRepo remote;
  late SyncQueueService svc;

  setUpAll(() {
    registerFallbackValue(_FakeUserProfile());
  });

  setUp(() {
    remote = _MockFirestoreRepo();
    svc = SyncQueueService(remote: remote);
  });

  test('profile delete dispatches to remote.deleteProfile', () async {
    when(() => remote.deleteProfile(any())).thenAnswer((_) async {});

    final op = SyncOperation(
      id: 'op_del',
      type: SyncOperationType.delete,
      entity: SyncEntity.profile,
      entityId: 'profile_42',
      createdAt: DateTime(2026, 5, 5),
    );

    await svc.executeOperationForTest(op);

    verify(() => remote.deleteProfile('profile_42')).called(1);
    verifyNever(() => remote.saveProfile(any()));
  });

  test('profile update still dispatches to remote.saveProfile', () async {
    when(() => remote.saveProfile(any())).thenAnswer((_) async {});

    final op = SyncOperation(
      id: 'op_save',
      type: SyncOperationType.update,
      entity: SyncEntity.profile,
      entityId: 'profile_7',
      payload: {
        'id': 'profile_7',
        'name': 'Alice',
        'role': 0,
        'avatarIndex': 1,
        'createdAt': DateTime(2026, 5, 5).toIso8601String(),
        'disabilityType': 0,
      },
      createdAt: DateTime(2026, 5, 5),
    );

    await svc.executeOperationForTest(op);

    verify(() => remote.saveProfile(any())).called(1);
    verifyNever(() => remote.deleteProfile(any()));
  });
}
