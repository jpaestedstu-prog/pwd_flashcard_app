import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/sync_queue/sync_queue_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/app_providers.dart';

/// Tracks the current sync state for UI display.
enum SyncStatus { idle, syncing, success, error, offline }

/// A global [Notifier] that drives [SyncStatusWidget].
class SyncStatusNotifier extends Notifier<SyncStatus> {
  SyncService? _syncService;
  Timer? _resetTimer;
  bool _disposed = false;

  @override
  SyncStatus build() {
    _syncService = ref.watch(syncServiceProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _resetTimer?.cancel();
    });
    return SyncStatus.idle;
  }

  /// Trigger a manual sync and update state accordingly.
  Future<void> sync() async {
    final service = _syncService;
    if (service == null || !FirebaseService.isConfigured) {
      state = SyncStatus.offline;
      _autoReset();
      return;
    }

    state = SyncStatus.syncing;
    try {
      await service.syncNow();
      if (!_disposed) state = SyncStatus.success;
    } catch (_) {
      if (!_disposed) state = SyncStatus.error;
    }
    _autoReset();
  }

  void _autoReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) state = SyncStatus.idle;
    });
  }
}

/// Provider for the sync notifier. Depends on [syncServiceProvider].
final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

/// Provider that exposes the app's [SyncService] instance.
/// Returns null when Firebase is not configured.
final syncServiceProvider = Provider<SyncService?>((ref) {
  // The SyncService is created in main.dart; this provider
  // lets widgets trigger manual syncs.
  // When Firebase is not configured, we return null.
  if (!FirebaseService.isConfigured) return null;
  return null; // replaced at app startup via ProviderScope override
});

/// A compact widget that shows the current sync status with queue details
/// and allows the user to trigger a manual sync or retry failed ops.
class SyncStatusWidget extends ConsumerWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final queueStatus = ref.watch(syncQueueStatusProvider);

    if (!FirebaseService.isConfigured) {
      return _buildTile(context,
        icon: Icons.cloud_off_rounded,
        label: 'Cloud Sync',
        subtitle: 'Not configured',
        iconColor: AppColors.textHint,
      );
    }

    // Show queue-aware status
    if (queueStatus.isSyncing) {
      return _buildTile(context,
        icon: Icons.cloud_sync_rounded,
        label: 'Syncingâ€¦',
        subtitle: _pendingSubtitle(queueStatus),
        iconColor: AppColors.info,
        trailing: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (queueStatus.failedCount > 0) {
      return _buildTile(context,
        icon: Icons.cloud_off_rounded,
        label: 'Sync Issue',
        subtitle:
            '${queueStatus.failedCount} failed â€” tap to retry',
        iconColor: AppColors.error,
        onTap: () => ref.read(syncQueueStatusProvider.notifier).retryFailed(),
      );
    }

    if (queueStatus.pendingCount > 0) {
      return _buildTile(context,
        icon: Icons.cloud_upload_rounded,
        label: 'Pending Sync',
        subtitle:
            '${queueStatus.pendingCount} change${queueStatus.pendingCount == 1 ? '' : 's'} waiting',
        iconColor: AppColors.warning,
        onTap: () => ref.read(syncQueueStatusProvider.notifier).sync(),
      );
    }

    // Fall through to legacy status for idle/success/error/offline
    switch (status) {
      case SyncStatus.idle:
        return _buildTile(context,
          icon: Icons.cloud_done_rounded,
          label: 'Cloud Sync',
          subtitle: _lastSyncSubtitle(queueStatus),
          iconColor: AppColors.secondary,
          onTap: () => ref.read(syncStatusProvider.notifier).sync(),
        );
      case SyncStatus.syncing:
        return _buildTile(context,
          icon: Icons.cloud_sync_rounded,
          label: 'Syncingâ€¦',
          subtitle: 'Uploading data',
          iconColor: AppColors.info,
          trailing: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SyncStatus.success:
        return _buildTile(context,
          icon: Icons.cloud_done_rounded,
          label: 'Synced!',
          subtitle: 'All data uploaded',
          iconColor: AppColors.success,
        );
      case SyncStatus.error:
        return _buildTile(context,
          icon: Icons.cloud_off_rounded,
          label: 'Sync Failed',
          subtitle: 'Tap to retry',
          iconColor: AppColors.error,
          onTap: () => ref.read(syncStatusProvider.notifier).sync(),
        );
      case SyncStatus.offline:
        return _buildTile(context,
          icon: Icons.cloud_off_rounded,
          label: 'Offline',
          subtitle: 'Will sync when online',
          iconColor: AppColors.textHint,
        );
    }
  }

  String _pendingSubtitle(SyncQueueStatus q) {
    if (q.pendingCount > 0) {
      return 'Uploading ${q.pendingCount} change${q.pendingCount == 1 ? '' : 's'}';
    }
    return 'Uploading data';
  }

  String _lastSyncSubtitle(SyncQueueStatus q) {
    if (q.lastSyncAt != null) {
      final diff = DateTime.now().difference(q.lastSyncAt!);
      if (diff.inMinutes < 1) return 'Synced just now';
      if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
      return 'Synced ${diff.inDays}d ago';
    }
    return 'Tap to sync now';
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final hc = HCColor.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(
        label,
        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(
          color: hc.textSecondary,
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.sync_rounded, color: hc.textSecondary)
              : null),
      onTap: onTap,
    );
  }
}
