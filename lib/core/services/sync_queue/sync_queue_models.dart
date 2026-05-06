/// Models for the persistent offline sync queue.
///
/// Every local write that needs to be replicated to Firestore is captured
/// as a [SyncOperation] and persisted in a dedicated Hive box so that it
/// survives app restarts.
library;

/// The kind of mutation recorded.
enum SyncOperationType { create, update, delete }

/// Which domain entity was mutated.
enum SyncEntity {
  profile,
  progress,
  achievements,
  purchases,
  equippedItem,
  customCard,
  settings,
  sessionLog,
  appState,
  classroom,
  classroomMember,
}

/// Processing state of a queued operation.
enum SyncOperationStatus { pending, inProgress, failed, completed }

/// A single queued sync operation persisted in Hive.
class SyncOperation {
  final String id;
  final SyncOperationType type;
  final SyncEntity entity;

  /// The primary key of the affected record (e.g. profile ID, card ID).
  final String entityId;

  /// Serialised payload to send to Firestore.  Null for deletes.
  final Map<String, dynamic>? payload;

  final DateTime createdAt;
  int retryCount;
  SyncOperationStatus status;
  String? lastError;

  SyncOperation({
    required this.id,
    required this.type,
    required this.entity,
    required this.entityId,
    this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncOperationStatus.pending,
    this.lastError,
  });

  /// A composite key used for deduplication: same entity + entityId means
  /// only the most recent operation matters (last-write-wins).
  String get deduplicationKey => '${entity.name}::$entityId';

  // ─── Serialisation ────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'entity': entity.index,
        'entityId': entityId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'status': status.index,
        'lastError': lastError,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values[json['type'] as int],
      entity: SyncEntity.values[json['entity'] as int],
      entityId: json['entityId'] as String,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: SyncOperationStatus
          .values[json['status'] as int? ?? 0],
      lastError: json['lastError'] as String?,
    );
  }
}

/// Snapshot of the sync queue state exposed to the UI layer.
class SyncQueueStatus {
  final int pendingCount;
  final int failedCount;
  final int totalCount;
  final DateTime? lastSyncAt;
  final bool isSyncing;

  const SyncQueueStatus({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.totalCount = 0,
    this.lastSyncAt,
    this.isSyncing = false,
  });

  bool get hasWork => pendingCount > 0 || failedCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueStatus &&
          pendingCount == other.pendingCount &&
          failedCount == other.failedCount &&
          totalCount == other.totalCount &&
          lastSyncAt == other.lastSyncAt &&
          isSyncing == other.isSyncing;

  @override
  int get hashCode => Object.hash(
        pendingCount,
        failedCount,
        totalCount,
        lastSyncAt,
        isSyncing,
      );
}
