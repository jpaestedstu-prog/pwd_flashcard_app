import 'package:hive_flutter/hive_flutter.dart';
import 'sync_queue_models.dart';

/// Persistent Hive-backed storage for the sync operation queue.
///
/// Operations are stored as JSON maps inside a dedicated `sync_queue` box.
/// The storage automatically deduplicates by (entity, entityId) so that
/// ten offline edits to the same profile collapse into a single queued op.
class SyncQueueStorage {
  static const String _boxName = 'sync_queue';
  static const String _opsKey = 'operations';
  static const String _lastSyncKey = 'last_sync_at';

  /// Maximum number of queued operations before we recommend a full push.
  static const int maxQueueSize = 500;

  static Box? _box;

  /// Open the Hive box.  Call during [HiveService.init].
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _safeBox {
    assert(_box != null, 'SyncQueueStorage.init() was not called');
    return _box!;
  }

  // ─── Write ────────────────────────────────────────────

  /// Enqueue an operation.  If an existing *pending* operation with the
  /// same [SyncOperation.deduplicationKey] exists it is **replaced** so
  /// only the latest payload is sent.
  static Future<void> addOperation(SyncOperation op) async {
    final ops = _readOps();

    // Deduplicate: remove any pending/failed op with same entity+entityId
    ops.removeWhere((o) =>
        o.deduplicationKey == op.deduplicationKey &&
        (o.status == SyncOperationStatus.pending ||
            o.status == SyncOperationStatus.failed));

    ops.add(op);

    // Enforce size cap — oldest completed ops are removed first
    if (ops.length > maxQueueSize) {
      ops.removeWhere((o) => o.status == SyncOperationStatus.completed);
    }

    await _writeOps(ops);
  }

  /// Mark an operation as successfully synced and remove it from the queue.
  static Future<void> markCompleted(String opId) async {
    final ops = _readOps();
    ops.removeWhere((o) => o.id == opId);
    await _writeOps(ops);
    await _safeBox.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Increment retry count and record the error message.
  static Future<void> markFailed(String opId, String error) async {
    final ops = _readOps();
    final idx = ops.indexWhere((o) => o.id == opId);
    if (idx == -1) return;
    ops[idx].retryCount++;
    ops[idx].lastError = error;
    ops[idx].status = SyncOperationStatus.failed;
    await _writeOps(ops);
  }

  /// Remove all completed operations (housekeeping).
  static Future<void> clearCompleted() async {
    final ops = _readOps();
    ops.removeWhere((o) => o.status == SyncOperationStatus.completed);
    await _writeOps(ops);
  }

  /// Remove permanently failed operations (retryCount >= maxRetries).
  static Future<void> clearPermanentlyFailed(int maxRetries) async {
    final ops = _readOps();
    ops.removeWhere((o) =>
        o.status == SyncOperationStatus.failed &&
        o.retryCount >= maxRetries);
    await _writeOps(ops);
  }

  /// Clear the entire queue (e.g. after a successful full-push sync).
  static Future<void> clearAll() async {
    await _safeBox.put(_opsKey, <dynamic>[]);
  }

  // ─── Read ─────────────────────────────────────────────

  /// Return all pending or failed operations ordered by creation time.
  static List<SyncOperation> getPendingOperations() {
    return _readOps()
        .where((o) =>
            o.status == SyncOperationStatus.pending ||
            o.status == SyncOperationStatus.failed)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Return all operations regardless of status.
  static List<SyncOperation> getAllOperations() => _readOps();

  /// Quick summary for the UI.
  static SyncQueueStatus getQueueStatus({bool isSyncing = false}) {
    final ops = _readOps();
    final pending =
        ops.where((o) => o.status == SyncOperationStatus.pending).length;
    final failed =
        ops.where((o) => o.status == SyncOperationStatus.failed).length;
    final lastSync = _safeBox.get(_lastSyncKey) as String?;
    return SyncQueueStatus(
      pendingCount: pending,
      failedCount: failed,
      totalCount: ops.length,
      lastSyncAt: lastSync != null ? DateTime.tryParse(lastSync) : null,
      isSyncing: isSyncing,
    );
  }

  /// Whether the queue has grown beyond [maxQueueSize] and a full-push
  /// is recommended instead of incremental sync.
  static bool get isOverflowing => _readOps().length >= maxQueueSize;

  // ─── Internal ─────────────────────────────────────────

  static List<SyncOperation> _readOps() {
    final raw = _safeBox.get(_opsKey, defaultValue: <dynamic>[]);
    final list = <SyncOperation>[];
    for (final entry in (raw as List)) {
      try {
        list.add(
          SyncOperation.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return list;
  }

  static Future<void> _writeOps(List<SyncOperation> ops) async {
    await _safeBox.put(_opsKey, ops.map((o) => o.toJson()).toList());
  }
}
