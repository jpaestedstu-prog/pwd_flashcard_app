import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cloud_sync_exceptions.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/local_repository.dart';
import '../../../providers/app_providers.dart';

/// Friendly, user-readable copy for a cloud-sync exception.
///
/// Pure function — no widgets, no context — so it can be reused by
/// inline error renderers (e.g. the Create Class / Home Group dialog)
/// in addition to the full-screen [CloudSyncErrorView]. Keeps the
/// single source of truth for "what does THIS error mean to a teacher
/// or parent" in one place.
///
/// `profileId` is non-null only for [OwnerUidMismatchException]; the
/// caller can offer a "Reset for this device" affordance when present.
({
  IconData icon,
  Color color,
  String title,
  String body,
  String? underlying,
  String? profileId,
}) cloudSyncErrorMessage(Object e) {
  if (e is CloudAuthMissingException) {
    return (
      icon: Icons.cloud_off_rounded,
      color: Colors.orange.shade700,
      title: 'Cloud sign-in not ready',
      body:
          'The app couldn\'t sign in anonymously, so Firestore is rejecting '
          'writes. Common fixes:\n\n'
          '1) Firebase Console → Authentication → Sign-in method → enable '
          'Anonymous.\n'
          '2) Deploy the security rules: '
          '`firebase deploy --only firestore:rules`.\n'
          '3) Connect the device to the internet for one launch so the '
          'sign-in can complete.',
      underlying: e.underlying,
      profileId: null,
    );
  }
  if (e is OwnerUidMismatchException) {
    return (
      icon: Icons.lock_person_rounded,
      color: Colors.red.shade700,
      title: 'Profile locked to another device',
      body:
          'This profile was created on a different device (or before the '
          'app was reinstalled). Tap "Reset for this device" to claim it '
          'for this anonymous sign-in, or sign in on the original device.',
      underlying: 'profile=${e.profileId}',
      profileId: e.profileId,
    );
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') {
      return (
        icon: Icons.gpp_bad_rounded,
        color: Colors.red.shade700,
        title: 'Cloud setup incomplete',
        body:
            'Firestore rejected the request. Run through these steps once, '
            'then try again:\n\n'
            '1) Firebase Console → Authentication → Sign-in method → '
            'enable Anonymous.\n'
            '2) From the project root: '
            '`firebase deploy --only firestore:rules`.\n'
            '3) Pull the device online for at least one launch.',
        underlying: '${e.code}: ${e.message}',
        profileId: null,
      );
    }
    if (e.code == 'unavailable') {
      return (
        icon: Icons.wifi_off_rounded,
        color: Colors.blueGrey.shade700,
        title: 'Offline',
        body:
            'You\'re seeing your last saved data. New changes will sync '
            'when this device is back online.',
        underlying: e.message,
        profileId: null,
      );
    }
  }
  return (
    icon: Icons.error_outline_rounded,
    color: Colors.grey.shade800,
    title: 'Something went wrong',
    body: 'Try again. If this keeps happening, expand the details below '
        'and share them with support.',
    underlying: e.toString(),
    profileId: null,
  );
}

/// Friendly error renderer for the Manage Classes / Manage Home Groups
/// screens. Replaces the raw `Could not load classes: $e` text that used
/// to leak Firestore error codes directly to teachers and parents.
///
/// All error → copy mapping lives in [cloudSyncErrorMessage] so the same
/// strings are reused by inline error renderers (e.g. the Create dialog).
class CloudSyncErrorView extends ConsumerWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const CloudSyncErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = cloudSyncErrorMessage(error);
    return _ErrorScaffold(
      icon: msg.icon,
      color: msg.color,
      title: msg.title,
      body: msg.body,
      underlying: msg.underlying,
      actions: [
        if (msg.profileId != null)
          ResetForThisDeviceButton(
            profileId: msg.profileId!,
            onDone: onRetry,
          ),
        _RetryButton(onRetry: onRetry),
      ],
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? underlying;
  final List<Widget> actions;

  const _ErrorScaffold({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.actions,
    this.underlying,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: actions,
            ),
            if (underlying != null && underlying!.isNotEmpty) ...[
              const SizedBox(height: 24),
              ExpansionTile(
                title: Text(
                  'Details',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      underlying!,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  final Future<void> Function() onRetry;
  const _RetryButton({required this.onRetry});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Best-effort re-init so the retry also recovers from a stale
    // Firebase init / auth state.
    await FirebaseService.retryInit();
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _tap,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: Text(_busy ? 'Retrying…' : 'Retry'),
    );
  }
}

/// Clears the local profile's `ownerUid`, then re-saves it through
/// [LocalRepository.saveProfile] so the current anonymous uid is
/// stamped. Equivalent of running the one-shot
/// [OwnerUidMigration.runIfNeeded] for a single profile, on demand.
///
/// Public so the inline Create-dialog error renderer can offer the
/// same affordance when the create call surfaces an
/// [OwnerUidMismatchException].
class ResetForThisDeviceButton extends ConsumerStatefulWidget {
  final String profileId;
  final Future<void> Function() onDone;

  const ResetForThisDeviceButton({
    super.key,
    required this.profileId,
    required this.onDone,
  });

  @override
  ConsumerState<ResetForThisDeviceButton> createState() =>
      _ResetForThisDeviceButtonState();
}

class _ResetForThisDeviceButtonState
    extends ConsumerState<ResetForThisDeviceButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final profile = HiveService.getProfileById(widget.profileId);
      if (profile == null) return;
      // Drop the stale uid and re-save — [LocalRepository.saveProfile]
      // auto-stamps the current anonymous uid and pushes the merge to
      // Firestore. The rules accept this because the existing remote
      // doc carries either no `owner_uid` (legacy) or the same uid
      // (no-op merge).
      final cleared = profile.copyWith(ownerUid: () => null);
      await const LocalRepository().saveProfile(cleared);
      // Also refresh the active profile state so the screen rebuilds.
      final active = ref.read(profileProvider);
      if (active != null && active.id == widget.profileId) {
        await ref.read(profileProvider.notifier).setProfile(cleared);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile reset for this device.')),
      );
      await widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _tap,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.restart_alt_rounded, size: 18),
      label: const Text('Reset for this device'),
    );
  }
}
