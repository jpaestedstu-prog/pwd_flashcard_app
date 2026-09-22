import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/recovery_code_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/remote/firestore_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Steps the redemption flow walks through. Surfaced as a progress
/// indicator so the user understands what's happening across the
/// (potentially slow) Firestore round trips.
enum _RedemptionStep {
  idle,
  lookingUp,
  verifying,
  restoring,
  pullingProgress,
  done,
}

/// Onboarding entry for **I have a recovery code** — claims an existing
/// profile from Firestore onto this device.
///
/// The flow:
///  1. User enters their code (any case, with/without dashes).
///  2. We look up `recovery_codes/{normalised}` in Firestore.
///  3. Verify the code's stored hash matches (defence against the (vanishingly
///     unlikely) doc-id-collision case).
///  4. Call [FirestoreRepository.claimProfileWithRecoveryCode] which
///     re-stamps `owner_uid` across all owner-scoped docs.
///  5. Pull the profile's progress, save profile + progress locally.
///  6. Activate the profile and navigate home.
class RecoverProfileScreen extends ConsumerStatefulWidget {
  const RecoverProfileScreen({super.key});

  @override
  ConsumerState<RecoverProfileScreen> createState() =>
      _RecoverProfileScreenState();
}

class _RecoverProfileScreenState extends ConsumerState<RecoverProfileScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _RedemptionStep _step = _RedemptionStep.idle;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _busy =>
      _step != _RedemptionStep.idle && _step != _RedemptionStep.done;

  Future<void> _recover() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final t = _t(context);
    setState(() {
      _step = _RedemptionStep.lookingUp;
      _error = null;
    });

    final input = _codeController.text.trim();

    try {
      final record = await RecoveryCodeService.lookupCode(input);
      if (record == null) {
        _fail(t.rcNotFound);
        return;
      }
      if (record.isUsed) {
        _fail(t.rcAlreadyUsed);
        return;
      }

      setState(() => _step = _RedemptionStep.verifying);
      if (!RecoveryCodeService.verify(input, record)) {
        _fail(t.rcInvalid);
        return;
      }

      setState(() => _step = _RedemptionStep.restoring);
      const repo = FirestoreRepository();
      final recoveredProfile = await repo.claimProfileWithRecoveryCode(
        code: record.code,
        profileId: record.profileId,
        oldOwnerUid: record.profileOwnerUid,
      );

      setState(() => _step = _RedemptionStep.pullingProgress);
      final progress = await repo.getProgress(record.profileId);

      // Save locally first so the rest of the app sees the recovered
      // profile even if the followup `setProfile` cloud write is slow.
      await HiveService.saveProfile(recoveredProfile);
      await HiveService.saveProgress(progress);
      await HiveService.setActiveProfileId(recoveredProfile.id);

      // Surface to the rest of the app via the profile notifier. This
      // also enqueues a re-save, but with the same data we just wrote
      // — idempotent under merge semantics.
      await ref
          .read(profileProvider.notifier)
          .setProfile(recoveredProfile);

      setState(() => _step = _RedemptionStep.done);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: t.rcWelcomeBack(recoveredProfile.name),
      );
      context.go('/home');
    } on RecoveryCodeException catch (e) {
      _fail(e.localizedMessage(t));
    } catch (e) {
      _fail(t.rcRestoreFailed('$e'));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = _RedemptionStep.idle;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_t(context).rcTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const SizedBox(height: 24),
                _CodeField(
                  controller: _codeController,
                  enabled: !_busy,
                  onSubmit: _recover,
                ),
                const SizedBox(height: 8),
                Text(
                  _t(context).rcFormatHint,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: _error!),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _recover,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_rounded),
                  label: Text(_busy
                      ? _stepLabel(_step)
                      : _t(context).rcRestoreMine),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                if (!FirebaseService.isConfigured)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _t(context).rcNoCloud,
                      style: AppTypography.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel(_RedemptionStep step) {
    switch (step) {
      case _RedemptionStep.lookingUp:
        return _t(context).rcLookingUp;
      case _RedemptionStep.verifying:
        return _t(context).rcVerifying;
      case _RedemptionStep.restoring:
        return _t(context).rcRestoring;
      case _RedemptionStep.pullingProgress:
        return _t(context).rcLoadingProgress;
      case _RedemptionStep.done:
        return _t(context).rcDone;
      case _RedemptionStep.idle:
        return _t(context).rcRestoreMine;
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.cloud_sync_rounded,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _t(context).rcWelcome,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _t(context).rcIntro,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      style: AppTypography.headlineSmall.copyWith(
        fontFamily: 'monospace',
        letterSpacing: 3,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'XXXX-XXXX-XX',
        hintStyle: AppTypography.headlineSmall.copyWith(
          fontFamily: 'monospace',
          letterSpacing: 3,
          color: AppColors.textSecondary.withValues(alpha: 0.4),
        ),
        prefixIcon: const Icon(Icons.vpn_key_rounded),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: enabled ? controller.clear : null,
              )
            : null,
      ),
      inputFormatters: [
        // Strip everything except A–Z, 0–9, and dashes. Spaces are handy
        // for users typing on touch keyboards that auto-insert them.
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
        LengthLimitingTextInputFormatter(14), // 10 chars + 2 dashes + slack
      ],
      validator: (value) {
        final input = (value ?? '').trim();
        if (input.isEmpty) return _t(context).rcEnterCode;
        final normalised = RecoveryCodeService.normalise(input);
        if (normalised == null) {
          return _t(context).rcCodeFormat;
        }
        return null;
      },
      onFieldSubmitted: (_) => onSubmit(),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            child: Text(message, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
