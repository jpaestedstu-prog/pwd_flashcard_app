import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_models.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';

/// In-memory Hive setup for unit tests.
Future<void> _initHive() async {
  // Use a temp directory for Hive in tests
  Hive.init('./build/test_cache/sync_queue');
  if (!Hive.isBoxOpen('sync_queue')) {
    await Hive.openBox('sync_queue');
  }
}

SyncOperation _makeOp({
  String id = 'op1',
  SyncOperationType type = SyncOperationType.update,
  SyncEntity entity = SyncEntity.profile,
  String entityId = 'profile_1',
  Map<String, dynamic>? payload,
  int retryCount = 0,
  SyncOperationStatus status = SyncOperationStatus.pending,
}) {
  return SyncOperation(
    id: id,
    type: type,
    entity: entity,
    entityId: entityId,
    payload: payload ?? {'name': 'Alice'},
    createdAt: DateTime(2026, 4, 5, 12),
    retryCount: retryCount,
    status: status,
  );
}

void main() {
  setUpAll(() async {
    await _initHive();
  });

  setUp(() async {
    await SyncQueueStorage.init();
    await SyncQueueStorage.clearAll();
  });

  // ─── SyncOperation Serialisation ──────────────────────

  group('SyncOperation serialisation', () {
    test('toJson roundtrip preserves all fields', () {
      final op = _makeOp(
        id: 'abc-123',
        type: SyncOperationType.create,
        entity: SyncEntity.customCard,
        entityId: 'card_42',
        payload: {'wordEnglish': 'Cat', 'wordFilipino': 'Pusa'},
        retryCount: 3,
        status: SyncOperationStatus.failed,
      );
      op.lastError = 'Network timeout';

      final json = op.toJson();
      final restored = SyncOperation.fromJson(json);

      expect(restored.id, 'abc-123');
      expect(restored.type, SyncOperationType.create);
      expect(restored.entity, SyncEntity.customCard);
      expect(restored.entityId, 'card_42');
      expect(restored.payload?['wordEnglish'], 'Cat');
      expect(restored.payload?['wordFilipino'], 'Pusa');
      expect(restored.retryCount, 3);
      expect(restored.status, SyncOperationStatus.failed);
      expect(restored.lastError, 'Network timeout');
      expect(restored.createdAt, op.createdAt);
    });

    test('toJson roundtrip with null payload (delete)', () {
      final op = _makeOp(
        type: SyncOperationType.delete,
      );
      // Force null payload
      final json = op.toJson();
      json['payload'] = null;

      final restored = SyncOperation.fromJson(json);
      expect(restored.type, SyncOperationType.delete);
      expect(restored.payload, isNull);
    });

    test('deduplicationKey combines entity and entityId', () {
      final op = _makeOp(entity: SyncEntity.progress, entityId: 'user_1');
      expect(op.deduplicationKey, 'progress::user_1');
    });
  });

  // ─── SyncQueueStorage ─────────────────────────────────

  group('SyncQueueStorage', () {
    test('addOperation stores and retrieves operation', () async {
      final op = _makeOp();
      await SyncQueueStorage.addOperation(op);

      final pending = SyncQueueStorage.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.id, 'op1');
    });

    test('getPendingOperations returns pending and failed ops sorted by date',
        () async {
      final op1 = SyncOperation(
        id: 'a',
        type: SyncOperationType.update,
        entity: SyncEntity.profile,
        entityId: 'p1',
        payload: {},
        createdAt: DateTime(2026, 4, 5, 10),
      );
      final op2 = SyncOperation(
        id: 'b',
        type: SyncOperationType.update,
        entity: SyncEntity.progress,
        entityId: 'p1',
        payload: {},
        createdAt: DateTime(2026, 4, 5, 9),
        status: SyncOperationStatus.failed,
        retryCount: 1,
      );

      await SyncQueueStorage.addOperation(op1);
      await SyncQueueStorage.addOperation(op2);

      final pending = SyncQueueStorage.getPendingOperations();
      expect(pending, hasLength(2));
      // op2 (9:00) should come before op1 (10:00) — sorted by createdAt
      expect(pending[0].id, 'b');
      expect(pending[1].id, 'a');
    });

    test('markCompleted removes operation from queue', () async {
      final op = _makeOp();
      await SyncQueueStorage.addOperation(op);
      expect(SyncQueueStorage.getPendingOperations(), hasLength(1));

      await SyncQueueStorage.markCompleted('op1');
      expect(SyncQueueStorage.getPendingOperations(), isEmpty);
    });

    test('markFailed increments retryCount and sets error', () async {
      final op = _makeOp();
      await SyncQueueStorage.addOperation(op);

      await SyncQueueStorage.markFailed('op1', 'Connection refused');

      final pending = SyncQueueStorage.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.retryCount, 1);
      expect(pending.first.lastError, 'Connection refused');
      expect(pending.first.status, SyncOperationStatus.failed);
    });

    test('deduplication replaces existing pending op with same entity+id',
        () async {
      final op1 = _makeOp(payload: {'name': 'Alice'});
      await SyncQueueStorage.addOperation(op1);

      // Same entity + entityId, different payload
      final op2 = _makeOp(id: 'op2', payload: {'name': 'Bob'});
      await SyncQueueStorage.addOperation(op2);

      final all = SyncQueueStorage.getAllOperations();
      expect(all, hasLength(1));
      expect(all.first.id, 'op2');
      expect(all.first.payload?['name'], 'Bob');
    });

    test('deduplication replaces failed ops too', () async {
      final op1 = _makeOp(
        status: SyncOperationStatus.failed,
        retryCount: 2,
      );
      await SyncQueueStorage.addOperation(op1);

      final op2 = _makeOp(id: 'op_new', payload: {'name': 'Updated'});
      await SyncQueueStorage.addOperation(op2);

      final all = SyncQueueStorage.getAllOperations();
      expect(all, hasLength(1));
      expect(all.first.id, 'op_new');
      expect(all.first.retryCount, 0);
      expect(all.first.status, SyncOperationStatus.pending);
    });

    test('different entities are NOT deduplicated', () async {
      final profileOp = _makeOp(
        id: 'op_profile',
        entityId: 'user_1',
      );
      final progressOp = _makeOp(
        id: 'op_progress',
        entity: SyncEntity.progress,
        entityId: 'user_1',
      );
      await SyncQueueStorage.addOperation(profileOp);
      await SyncQueueStorage.addOperation(progressOp);

      expect(SyncQueueStorage.getAllOperations(), hasLength(2));
    });

    test('clearAll empties queue', () async {
      await SyncQueueStorage.addOperation(_makeOp(id: 'x'));
      await SyncQueueStorage.addOperation(
          _makeOp(id: 'y', entity: SyncEntity.settings, entityId: 'default'));
      expect(SyncQueueStorage.getAllOperations(), hasLength(2));

      await SyncQueueStorage.clearAll();
      expect(SyncQueueStorage.getAllOperations(), isEmpty);
    });

    test('clearPermanentlyFailed removes ops over max retries', () async {
      final op1 = _makeOp(
        id: 'perm_fail',
        retryCount: 5,
        status: SyncOperationStatus.failed,
      );
      final op2 = _makeOp(
        id: 'recoverable',
        entity: SyncEntity.settings,
        entityId: 'default',
        retryCount: 2,
        status: SyncOperationStatus.failed,
      );
      await SyncQueueStorage.addOperation(op1);
      await SyncQueueStorage.addOperation(op2);

      await SyncQueueStorage.clearPermanentlyFailed(5);

      final remaining = SyncQueueStorage.getAllOperations();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, 'recoverable');
    });

    test('getQueueStatus returns correct counts', () async {
      await SyncQueueStorage.addOperation(_makeOp(id: 'a'));
      await SyncQueueStorage.addOperation(
        _makeOp(
          id: 'b',
          entity: SyncEntity.settings,
          entityId: 'default',
          status: SyncOperationStatus.failed,
          retryCount: 1,
        ),
      );

      final status = SyncQueueStorage.getQueueStatus();
      expect(status.pendingCount, 1);
      expect(status.failedCount, 1);
      expect(status.totalCount, 2);
      expect(status.isSyncing, false);
    });

    test('getQueueStatus with isSyncing flag', () {
      final status = SyncQueueStorage.getQueueStatus(isSyncing: true);
      expect(status.isSyncing, true);
    });
  });

  // ─── SyncQueueStatus ──────────────────────────────────

  group('SyncQueueStatus', () {
    test('hasWork is true when pending > 0', () {
      const status = SyncQueueStatus(pendingCount: 1);
      expect(status.hasWork, true);
    });

    test('hasWork is true when failed > 0', () {
      const status = SyncQueueStatus(failedCount: 1);
      expect(status.hasWork, true);
    });

    test('hasWork is false when both are 0', () {
      const status = SyncQueueStatus();
      expect(status.hasWork, false);
    });

    test('equality works correctly', () {
      final time = DateTime(2026, 4, 5);
      final a = SyncQueueStatus(
        pendingCount: 2,
        failedCount: 1,
        totalCount: 3,
        lastSyncAt: time,
      );
      final b = SyncQueueStatus(
        pendingCount: 2,
        failedCount: 1,
        totalCount: 3,
        lastSyncAt: time,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
