import 'package:flutter/material.dart';
import '../../../core/utils/localized_date.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Screen for backing up and restoring all app data.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isCreatingBackup = false;
  bool _isRestoring = false;
  String? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _lastBackupDate = BackupService.getLastBackupDate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/settings'),
        title: Text(_t(context).brTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header illustration
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_done_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _t(context).brKeepSafe,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(context).brIntro,
                  style: AppTypography.bodyMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

          const SizedBox(height: 24),

          // Last backup info
          if (_lastBackupDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(context).brLastBackup(_formatDate(context, _lastBackupDate!)),
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).successText,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),

          // Create Backup button
          _ActionCard(
            icon: Icons.backup_rounded,
            iconColor: AppColors.primary,
            title: _t(context).brCreate,
            subtitle: _t(context).brCreateSub,
            buttonLabel: _isCreatingBackup ? _t(context).brCreating : _t(context).brBackUpNow,
            isLoading: _isCreatingBackup,
            onPressed: _isCreatingBackup ? null : _createBackup,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),

          const SizedBox(height: 16),

          // Restore Backup button
          _ActionCard(
            icon: Icons.restore_rounded,
            iconColor: AppColors.secondary,
            title: _t(context).brRestoreFrom,
            subtitle: _t(context).brRestoreSub,
            buttonLabel: _isRestoring ? _t(context).brRestoring : _t(context).brRestore,
            isLoading: _isRestoring,
            onPressed: _isRestoring ? null : _restoreBackup,
          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

          const SizedBox(height: 32),

          // What's included
          Text(
            _t(context).brIncluded,
            style: AppTypography.labelMedium.copyWith(
              color: HCColor.of(context).textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          _InfoRow(icon: Icons.person_rounded, text: _t(context).brProfiles),
          _InfoRow(icon: Icons.emoji_events_rounded, text: _t(context).brProgress),
          _InfoRow(icon: Icons.star_rounded, text: _t(context).brStars),
          _InfoRow(icon: Icons.style_rounded, text: _t(context).brCustomCards),
          _InfoRow(icon: Icons.settings_rounded, text: _t(context).brSettings),
          _InfoRow(icon: Icons.timeline_rounded, text: _t(context).brAnalytics),
          _InfoRow(icon: Icons.psychology_rounded, text: _t(context).brSpaced),

          const SizedBox(height: 24),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(context).brWarning,
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).readableOver(
                        AppColors.warning,
                        AppColors.warning.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _isCreatingBackup = true);
    try {
      final success = await BackupService.createBackup();
      if (mounted) {
        setState(() {
          _isCreatingBackup = false;
          if (success) {
            _lastBackupDate = BackupService.getLastBackupDate();
          }
        });
        if (success) {
          AppSnackBar.success(context, message: _t(context).brCreated);
        } else {
          AppSnackBar.error(context, message: _t(context).brCreateFailed);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCreatingBackup = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context).brRestoreTitle),
        content: Text(
          _t(context).brRestoreBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(_t(context).brRestore),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final result = await BackupService.restoreBackup();
      if (mounted) {
        setState(() => _isRestoring = false);
        if (result.success) {
          // Refresh providers
          ref.read(settingsProvider.notifier).update(
            ref.read(settingsProvider),
          );

          if (mounted) {
            AppSnackBar.success(
              context,
              message: _restoreMessage(_t(context), result),
            );
            // Navigate to profile selection to pick a profile
            context.go('/profile');
          }
        } else {
          AppSnackBar.error(
            context,
            message: _restoreMessage(_t(context), result),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  String _formatDate(BuildContext context, String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      return '${LocalizedDate.monthDayYear(dt, _t(context))}, '
          '$h:${dt.minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return isoDate;
    }
  }
}

// ─── Action Card Widget ──────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(icon, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: iconColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Row Widget ─────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(text, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

/// [BackupRestoreResult.message] is written in English by the service; this
/// shows it in the reader's language.
String _restoreMessage(AppLocalizations t, BackupRestoreResult r) {
  if (r.success) return t.brRestored;
  final m = r.message;
  if (m == 'No file selected.') return t.brNoFile;
  if (m == 'Could not read file.') return t.brCantRead;
  if (m.startsWith('Error selecting file')) return t.brPickFailed;
  if (m.startsWith('Invalid backup file')) return t.brCorrupt;
  if (m.startsWith('Invalid backup format')) return t.brBadFormat;
  if (m.startsWith('This backup was created with a newer version')) {
    return t.brNewer;
  }
  if (m.startsWith('Invalid backup structure')) return t.brNoData;
  return t.brRestoreFailed;
}
