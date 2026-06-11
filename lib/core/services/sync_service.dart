import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/repository.dart';
import '../../data/local/local_repository.dart';
import '../../data/remote/firestore_repository.dart';
import 'firebase_service.dart';
import '../utils/error_handler.dart';
import 'sync_queue/sync_queue_service.dart';
import 'sync_queue/sync_queue_storage.dart';

/// Offline-first sync service.
///
/// Writes always go to Hive first (via [LocalRepository]).
/// When connectivity is detected and Firebase is configured,
/// it drains the persistent [SyncQueueService] queue to the remote
/// backend.  If the queue is empty (e.g. first launch) it falls back
/// to the legacy full-push of all local data.
///
/// This is a *simple* last-write-wins strategy suitable for a
/// single-device-per-profile app like a classroom flashcard app.
class SyncService {
  final DataRepository _local;
  final DataRepository? _remote;

  /// The queue-based sync engine (preferred path).
  SyncQueueService? _queueService;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;

  SyncService({
    required DataRepository local,
    DataRepository? remote,
  })  : _local = local,
        _remote = remote {
    // Wire up the queue service if a remote FirestoreRepository is available.
    if (_remote is FirestoreRepository) {
      _queueService = SyncQueueService(
        remote: _remote,
      );
    }
  }

  /// Expose the underlying queue service for provider wiring.
  SyncQueueService? get queueService => _queueService;

  /// Start listening for connectivity changes and sync when online.
  void startListening() {
    if (_remote == null) return;

    // Prefer queue-based listening
    if (_queueService != null) {
      _queueService!.startListening();
      return;
    }

    // Legacy listener (no queue service available)
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        syncNow();
      }
    });
  }

  /// Manually trigger a sync.
  ///
  /// If the queue has pending operations they are processed first.
  /// Otherwise falls back to the legacy full-push.
  Future<void> syncNow() async {
    // Prefer queue-based sync
    if (_queueService != null) {
      final pending = SyncQueueStorage.getPendingOperations();
      if (pending.isNotEmpty) {
        await _queueService!.processQueue();
        return;
      }
    }

    // Legacy full-push (first-time sync or queue service unavailable)
    await _legacySync();
  }

  /// Legacy full-push: pushes all local data to remote.
  Future<void> _legacySync() async {
    final remote = _remote;
    if (remote == null || _syncing) return;
    _syncing = true;

    try {
      // 1. Push all profiles
      final profiles = await _local.getProfiles();
      for (final p in profiles) {
        await remote.saveProfile(p);

        // 2. Push progress for each profile
        final progress = await _local.getProgress(p.id);
        await remote.saveProgress(progress);

        // 3. Push achievements
        final achievements = await _local.getUnlockedAchievements(p.id);
        if (achievements.isNotEmpty) {
          await remote.saveUnlockedAchievements(p.id, achievements);
        }

        // 4. Push purchases
        final purchases = await _local.getPurchasedItems(p.id);
        if (purchases.isNotEmpty) {
          await remote.savePurchasedItems(p.id, purchases);
        }
      }

      // 5. Push custom cards
      final cards = await _local.getCustomCards();
      for (final card in cards) {
        await remote.saveCustomCard(card);
      }

      // After a successful full-push, clear the queue so future
      // syncs use incremental queue operations.
      await SyncQueueStorage.clearAll();
    } catch (e, stack) {
      // Data stays safe in Hive. Log the error for diagnostics.
      ErrorHandler.report(e, stack, 'SyncService');
    } finally {
      _syncing = false;
    }
  }

  /// Pull all owner-scoped data for the currently signed-in uid back into
  /// local Hive. Used by the linked-account sign-in flow on a fresh
  /// install: after [FirebaseService.signInWithEmail] succeeds, the uid
  /// switches to the linked account's uid and Hive is empty — this method
  /// repopulates profiles, progress, achievements, purchases, and custom
  /// cards from the Firestore documents stamped with that uid.
  ///
  /// Returns the number of profiles restored (0 on offline failure or
  /// when there is no remote backup for this uid). Errors are logged via
  /// [ErrorHandler] but never thrown — the caller should surface a
  /// friendly message based on the return value.
  Future<int> rehydrateFromCloud() async {
    final remote = _remote;
    if (remote is! FirestoreRepository) return 0;
    final uid = FirebaseService.currentUid;
    if (uid == null) return 0;

    try {
      final profiles = await remote.getProfilesForOwner(uid);
      if (profiles.isEmpty) return 0;

      for (final p in profiles) {
        await _local.saveProfile(p);

        final progress = await remote.getProgress(p.id);
        await _local.saveProgress(progress);

        final achievements = await remote.getUnlockedAchievements(p.id);
        if (achievements.isNotEmpty) {
          await _local.saveUnlockedAchievements(p.id, achievements);
        }

        final purchases = await remote.getPurchasedItems(p.id);
        if (purchases.isNotEmpty) {
          await _local.savePurchasedItems(p.id, purchases);
        }
      }

      // Custom cards aren't scoped per-profile in the query; pull every
      // card stamped with this uid in one shot.
      final cards = await remote.getCustomCards();
      for (final card in cards) {
        await _local.saveCustomCard(card);
      }

      // After rehydration the local store matches the cloud — clear any
      // residual queue entries from the pre-link anonymous session so we
      // don't re-push stale ops to the new uid's namespace.
      await SyncQueueStorage.clearAll();

      return profiles.length;
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'SyncService.rehydrateFromCloud');
      return 0;
    }
  }

  /// Stop listening.
  void dispose() {
    _connectivitySub?.cancel();
    _queueService?.dispose();
  }
}
