import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../firebase_service.dart';
import '../../utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/classroom_member.dart';
import '../../../data/local/local_repository.dart';
import '../../../data/remote/firestore_repository.dart';
import 'sync_queue_models.dart';
import 'sync_queue_storage.dart';

/// Processes the persistent sync queue, pushing queued operations to
/// Firestore with exponential back-off retry.
///
/// Replaces the legacy full-push approach with surgical, per-operation
/// sync that survives app restarts and transient network failures.
class SyncQueueService {
  final FirestoreRepository _remote;

  /// Maximum number of retries before an operation is considered
  /// permanently failed.
  static const int maxRetries = 5;

  /// Maximum operations to process in a single [processQueue] cycle.
  static const int batchSize = 50;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _processing = false;

  /// Callback invoked whenever the queue status changes so providers
  /// can rebuild.
  void Function(SyncQueueStatus)? onStatusChanged;

  SyncQueueService({required FirestoreRepository remote}) : _remote = remote;

  // ─── Connectivity ─────────────────────────────────────

  /// Begin listening for connectivity changes and auto-drain the queue
  /// when the device comes back online.
  void startListening() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        processQueue();
      }
    });
  }

  /// Stop listening and clean up.
  void dispose() {
    _connectivitySub?.cancel();
  }

  // ─── Queue Processing ─────────────────────────────────

  /// Process up to [batchSize] pending/failed operations sequentially.
  ///
  /// If the queue has overflowed ([SyncQueueStorage.isOverflowing]) a
  /// legacy full-push is attempted instead, and the queue is cleared on
  /// success.
  Future<void> processQueue() async {
    if (_processing) return;
    if (!FirebaseService.isConfigured) return;

    _processing = true;
    _notifyStatus();

    try {
      // If queue is huge, fall back to a full-push
      if (SyncQueueStorage.isOverflowing) {
        await _legacyFullPush();
        await SyncQueueStorage.clearAll();
        _processing = false;
        _notifyStatus();
        return;
      }

      final ops = SyncQueueStorage.getPendingOperations();
      if (ops.isEmpty) {
        _processing = false;
        _notifyStatus();
        return;
      }

      int processed = 0;
      for (final op in ops) {
        if (processed >= batchSize) break;

        // Skip permanently failed ops
        if (op.retryCount >= maxRetries) continue;

        try {
          await _executeOperation(op);
          await SyncQueueStorage.markCompleted(op.id);
        } catch (e, stack) {
          ErrorHandler.report(e, stack, 'SyncQueueService');
          await SyncQueueStorage.markFailed(op.id, e.toString());

          // Exponential back-off: if we hit an error, stop processing
          // this cycle and let the next connectivity event retry.
          break;
        }

        processed++;
      }

      // Housekeeping
      await SyncQueueStorage.clearPermanentlyFailed(maxRetries);
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'SyncQueueService.processQueue');
    } finally {
      _processing = false;
      _notifyStatus();
    }
  }

  /// Manually retry all failed operations (resets their retry count).
  Future<void> retryFailed() async {
    final ops = SyncQueueStorage.getAllOperations();
    for (final op in ops) {
      if (op.status == SyncOperationStatus.failed) {
        op.retryCount = 0;
        op.status = SyncOperationStatus.pending;
        op.lastError = null;
      }
    }
    // Re-save the updated ops
    for (final op in ops.where(
        (o) => o.status == SyncOperationStatus.pending)) {
      await SyncQueueStorage.addOperation(op);
    }
    await processQueue();
  }

  // ─── Operation Dispatch ───────────────────────────────

  /// Public seam for unit tests that want to drive a single operation
  /// through the executor without bringing up Firebase or the queue
  /// storage layer. Production code should use [processQueue].
  @visibleForTesting
  Future<void> executeOperationForTest(SyncOperation op) =>
      _executeOperation(op);

  Future<void> _executeOperation(SyncOperation op) async {
    final payload = op.payload ?? {};

    switch (op.entity) {
      case SyncEntity.profile:
        if (op.type == SyncOperationType.delete) {
          await _remote.deleteProfile(op.entityId);
          return;
        }
        await _remote.saveProfile(_profileFromPayload(payload));

      case SyncEntity.progress:
        await _remote.saveProgress(_progressFromPayload(op.entityId, payload));

      case SyncEntity.achievements:
        final ids = Set<String>.from(
            (payload['achievementIds'] as List?)?.cast<String>() ?? []);
        if (ids.isNotEmpty) {
          await _remote.saveUnlockedAchievements(op.entityId, ids);
        }

      case SyncEntity.purchases:
        final ids = Set<String>.from(
            (payload['itemIds'] as List?)?.cast<String>() ?? []);
        if (ids.isNotEmpty) {
          await _remote.savePurchasedItems(op.entityId, ids);
        }

      case SyncEntity.equippedItem:
        final type = payload['type'] as String? ?? '';
        final itemId = payload['itemId'] as String?;
        await _remote.saveEquippedItem(op.entityId, type, itemId);

      case SyncEntity.customCard:
        if (op.type == SyncOperationType.delete) {
          await _remote.deleteCustomCard(op.entityId);
        } else {
          await _remote.saveCustomCard(_cardFromPayload(payload));
        }

      case SyncEntity.settings:
        await _remote.saveSettings(_settingsFromPayload(payload));

      case SyncEntity.sessionLog:
        await _remote.addSessionLog(op.entityId, payload);

      case SyncEntity.appState:
        // App state ops like tutorial-seen, daily-challenge-date
        final key = payload['key'] as String? ?? '';
        if (key == 'active_profile_id') {
          await _remote.setActiveProfileId(payload['value'] as String);
        } else if (key.startsWith('tutorial_seen_')) {
          final profileId = key.replaceFirst('tutorial_seen_', '');
          await _remote.markTutorialSeen(profileId);
        } else if (key.startsWith('daily_challenge_')) {
          final profileId = key.replaceFirst('daily_challenge_', '');
          await _remote.saveDailyChallengeDate(
              profileId, payload['value'] as String);
        }

      case SyncEntity.classroom:
        if (op.type == SyncOperationType.delete) {
          await _remote.deleteClassroom(op.entityId);
        } else if (op.type == SyncOperationType.create) {
          await _remote.createClassroom(Classroom.fromJson(payload));
        } else {
          await _remote.updateClassroom(Classroom.fromJson(payload));
        }

      case SyncEntity.classroomMember:
        if (op.type == SyncOperationType.delete) {
          final classroomId = payload['classroom_id'] as String? ?? '';
          final profileId = payload['profile_id'] as String? ?? '';
          if (classroomId.isNotEmpty && profileId.isNotEmpty) {
            await _remote.removeMember(classroomId, profileId);
          }
        } else {
          await _remote.addMember(ClassroomMember.fromJson(payload));
        }
    }
  }

  // ─── Payload Deserialisers ────────────────────────────

  UserProfile _profileFromPayload(Map<String, dynamic> p) {
    final gradeLevelIndex = p['gradeLevel'] as int?;
    final rawTags = p['tags'] as List?;
    return UserProfile(
      id: p['id'] as String,
      name: p['name'] as String,
      role: UserRole.values[p['role'] as int? ?? 0],
      avatarIndex: p['avatarIndex'] as int? ?? 0,
      createdAt: DateTime.parse(p['createdAt'] as String),
      disabilityType:
          DisabilityType.values[p['disabilityType'] as int? ?? 0],
      pin: p['pin'] as String?,
      gradeLevel: (gradeLevelIndex != null &&
              gradeLevelIndex >= 0 &&
              gradeLevelIndex < GradeLevel.values.length)
          ? GradeLevel.values[gradeLevelIndex]
          : null,
      section: p['section'] as String?,
      birthDate: p['birthDate'] != null
          ? DateTime.tryParse(p['birthDate'] as String)
          : null,
      tags: rawTags != null
          ? List<String>.from(rawTags.map((e) => e.toString()))
          : const [],
      classroomId: p['classroomId'] as String?,
      isGuestPlayer: p['isGuestPlayer'] as bool? ?? false,
    );
  }

  LearningProgress _progressFromPayload(
      String profileId, Map<String, dynamic> p) {
    final rawScores = p['recentScores'] as List? ?? [];
    final scores = <GameScore>[];
    for (final e in rawScores) {
      try {
        final m = Map<String, dynamic>.from(e as Map);
        scores.add(GameScore(
          gameType: GameType.values[m['gameType'] as int],
          score: m['score'] as int,
          total: m['total'] as int,
          starsEarned: m['starsEarned'] as int,
          date: DateTime.parse(m['date'] as String),
          durationSeconds: m['durationSeconds'] as int?,
        ));
      } catch (_) {
        continue;
      }
    }
    final rawWordIds = p['learnedWordIds'] as List? ?? [];
    return LearningProgress(
      profileId: profileId,
      wordsLearned: p['wordsLearned'] as int? ?? 0,
      learnedWordIds: Set<String>.from(rawWordIds.cast<String>()),
      streakDays: p['streakDays'] as int? ?? 0,
      lastActivityDate:
          DateTime.parse(p['lastActivityDate'] as String),
      totalStars: p['totalStars'] as int? ?? 0,
      spentStars: p['spentStars'] as int? ?? 0,
      categoryProgress: Map<String, double>.from(
          (p['categoryProgress'] as Map?)?.cast<String, double>() ?? {}),
      recentScores: scores,
    );
  }

  Flashcard _cardFromPayload(Map<String, dynamic> p) {
    return Flashcard(
      id: p['id'] as String,
      wordEnglish: p['wordEnglish'] as String,
      wordFilipino: p['wordFilipino'] as String,
      exampleSentence: p['exampleSentence'] as String?,
      imageAsset: p['imageAsset'] as String?,
      category: FlashcardCategory.values[p['category'] as int? ?? 0],
      isCustom: true,
    );
  }

  AppSettings _settingsFromPayload(Map<String, dynamic> p) {
    return AppSettings(
      fontScale: (p['fontScale'] as num?)?.toDouble() ?? 1.0,
      highContrastMode: p['highContrastMode'] as bool? ?? false,
      darkMode: p['darkMode'] as bool? ?? false,
      ttsEnabled: p['ttsEnabled'] as bool? ?? true,
      ttsSpeed: (p['ttsSpeed'] as num?)?.toDouble() ?? 0.5,
      reducedMotion: p['reducedMotion'] as bool? ?? false,
      soundEffects: p['soundEffects'] as bool? ?? true,
      speechToText: p['speechToText'] as bool? ?? false,
      locale: p['locale'] as String? ?? 'en',
      notificationsEnabled: p['notificationsEnabled'] as bool? ?? true,
      reminderHour: p['reminderHour'] as int? ?? 9,
      reminderMinute: p['reminderMinute'] as int? ?? 0,
      voiceNavigation: p['voiceNavigation'] as bool? ?? false,
      adaptiveDifficulty: p['adaptiveDifficulty'] as bool? ?? true,
    );
  }

  // ─── Legacy Full-Push (fallback) ──────────────────────

  /// Pushes ALL local data to Firestore, matching the old SyncService
  /// behaviour.  Used when the queue overflows or as a first-time sync.
  Future<void> _legacyFullPush() async {
    const local = LocalRepository();
    final profiles = await local.getProfiles();
    for (final p in profiles) {
      await _remote.saveProfile(p);
      final progress = await local.getProgress(p.id);
      await _remote.saveProgress(progress);
      final achievements = await local.getUnlockedAchievements(p.id);
      if (achievements.isNotEmpty) {
        await _remote.saveUnlockedAchievements(p.id, achievements);
      }
      final purchases = await local.getPurchasedItems(p.id);
      if (purchases.isNotEmpty) {
        await _remote.savePurchasedItems(p.id, purchases);
      }
    }
    final cards = await local.getCustomCards();
    for (final card in cards) {
      await _remote.saveCustomCard(card);
    }
  }

  // ─── Status Notification ──────────────────────────────

  void _notifyStatus() {
    final status = SyncQueueStorage.getQueueStatus(isSyncing: _processing);
    onStatusChanged?.call(status);
  }
}
