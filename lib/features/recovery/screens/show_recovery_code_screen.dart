import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/recovery_code_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';

/// Settings entry for **Backup & Recovery**: shows the profile's active
/// recovery code (or invites the user to generate one). Reachable from
/// the Settings screen.
///
/// The code itself is the doc id in `recovery_codes/{code}` — that doc
/// is the canonical proof of possession when restoring on a new device.
/// Generating a new code revokes the previous one.
class ShowRecoveryCodeScreen extends ConsumerStatefulWidget {
  const ShowRecoveryCodeScreen({super.key});

  @override
  ConsumerState<ShowRecoveryCodeScreen> createState() =>
      _ShowRecoveryCodeScreenState();
}

class _ShowRecoveryCodeScreenState
    extends ConsumerState<ShowRecoveryCodeScreen> {
  bool _busy = false;
  String? _newlyGeneratedCode; // shown when freshly generated this session

  Future<void> _generate(String profileId) async {
    setState(() => _busy = true);
    try {
      // Revoke any existing code so only one is active per profile at a
      // time. We ignore "not found" failures — they just mean there was
      // no prior code.
      final existing =
          await RecoveryCodeService.findActiveForProfile(profileId);
      if (existing != null) {
        try {
          await RecoveryCodeService.revoke(existing.code);
        } catch (_) {
          // Best-effort revoke; carry on.
        }
      }
      final code = await RecoveryCodeService.createRecoveryCode(
        profileId: profileId,
      );
      if (!mounted) return;
      setState(() => _newlyGeneratedCode = code);
      ref.invalidate(recoveryCodeProvider(profileId));
      AppSnackBar.success(
        context,
        message: 'Recovery code created. Save it somewhere safe.',
      );
    } on RecoveryCodeException catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: const Text('Backup & Recovery'),
        ),
        body: const Center(
          child: Text('Select a profile first to view its recovery code.'),
        ),
      );
    }

    final codeAsync = ref.watch(recoveryCodeProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Backup & Recovery'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(profileName: profile.name),
              const SizedBox(height: 24),
              codeAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => _ErrorCard(message: err.toString()),
                data: (record) {
                  // Prefer the just-generated plaintext (we don't store
                  // the user-facing dashes anywhere else; reading the
                  // doc gives us back its id which IS the code).
                  final code = _newlyGeneratedCode ?? record?.code;
                  if (code == null) {
                    return _GeneratePrompt(
                      busy: _busy,
                      onGenerate: () => _generate(profile.id),
                    );
                  }
                  return _CodeDisplay(
                    code: code,
                    isFreshlyGenerated: _newlyGeneratedCode != null,
                    busy: _busy,
                    onRegenerate: () => _generate(profile.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String profileName;
  const _Header({required this.profileName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backup & Recovery',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A recovery code lets $profileName restore their profile and '
          'progress on a new device if this one is lost or replaced.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GeneratePrompt extends StatelessWidget {
  final bool busy;
  final VoidCallback onGenerate;
  const _GeneratePrompt({required this.busy, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No recovery code yet',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Generate a one-time code now. Write it down or take a photo — '
            "you'll need it to restore this profile on another device.",
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : onGenerate,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(busy ? 'Generating…' : 'Generate recovery code'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  final String code;
  final bool isFreshlyGenerated;
  final bool busy;
  final VoidCallback onRegenerate;
  const _CodeDisplay({
    required this.code,
    required this.isFreshlyGenerated,
    required this.busy,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.success,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                isFreshlyGenerated ? 'Code created!' : 'Your recovery code',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: AppTypography.headlineMedium.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    AppSnackBar.success(
                      context,
                      message: 'Recovery code copied to clipboard',
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy to clipboard'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save this code somewhere safe. If you lose it AND lose '
                  'access to this device, the profile cannot be recovered.',
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: busy ? null : onRegenerate,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(busy ? 'Regenerating…' : 'Generate a new code'),
        ),
        const SizedBox(height: 4),
        Text(
          'Regenerating revokes the previous code.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
