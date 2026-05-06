import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/security/pin_auth_service.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// Screen shown when multiple profiles exist on the device.
/// Allows switching between profiles. If a profile has a PIN,
/// the user must enter it before switching.
class ProfileSwitcherScreen extends ConsumerStatefulWidget {
  const ProfileSwitcherScreen({super.key});

  @override
  ConsumerState<ProfileSwitcherScreen> createState() =>
      _ProfileSwitcherScreenState();
}

class _ProfileSwitcherScreenState
    extends ConsumerState<ProfileSwitcherScreen> {
  List<UserProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _loadProfiles() {
    final rawProfiles = HiveService.getProfiles();
    setState(() {
      _profiles = rawProfiles
          .map((data) => HiveService.getProfileById(data['id'] as String))
          .whereType<UserProfile>()
          .toList();
    });
  }

  Future<void> _selectProfile(UserProfile profile) async {
    if (profile.hasPinProtection) {
      final verified = await _showPinDialog(profile);
      if (verified != true) return;
    }

    await ref.read(profileProvider.notifier).setProfile(profile);
    if (mounted) context.go('/home');
  }

  Future<bool?> _showPinDialog(UserProfile profile) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _PinEntryDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hc = HCColor.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFF5F0FF), AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDark ? hc.surface : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                '${AppLocalizations.of(context)!.welcomeBack} 👋',
                style: AppTypography.displayMedium.copyWith(
                  color: hc.primary,
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.chooseYourProfile,
                style: AppTypography.titleLarge.copyWith(
                  color: hc.textSecondary,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    final avatar = AvatarData.getAvatar(profile.avatarIndex);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ProfileCard(
                        profile: profile,
                        avatar: avatar,
                        onTap: () => _selectProfile(profile),
                      ),
                    )
                        .animate()
                        .fadeIn(
                            duration: 400.ms, delay: (200 + index * 80).ms)
                        .slideX(
                            begin: index.isEven ? -0.1 : 0.1, end: 0);
                  },
                ),
              ),
              // Add new profile button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/profile'),
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(AppLocalizations.of(context)!.addNewProfile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: AppTypography.buttonText,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  final AvatarOption avatar;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hc.surface,
              avatar.color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: avatar.color.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: avatar.color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: avatar.color.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatar.color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: avatar.color.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(avatar.emoji,
                    style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.role.label,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  if (profile.role == UserRole.student &&
                      (profile.age != null || profile.gradeLevel != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (profile.age != null)
                            _InfoChip(
                              icon: Icons.cake_rounded,
                              label: '${profile.age} yrs',
                            ),
                          if (profile.age != null &&
                              profile.gradeLevel != null)
                            const SizedBox(width: 8),
                          if (profile.gradeLevel != null)
                            _InfoChip(
                              icon: Icons.school_rounded,
                              label: profile.gradeLevel!.label,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (profile.hasPinProtection)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 20, color: AppColors.warning),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

/// A dialog that asks for a 4-digit PIN to unlock a profile.
///
/// Verification routes through [PinCredentialHelper] (PBKDF2-SHA256 hash +
/// constant-time compare). Failed attempts increment a per-profile counter
/// persisted in Hive, which drives an exponential lockout.
class _PinEntryDialog extends StatefulWidget {
  final UserProfile profile;
  const _PinEntryDialog({required this.profile});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  late UserProfile _profile;
  String _enteredPin = '';
  bool _hasError = false;
  bool _verifying = false;
  Duration? _remainingLockout;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _refreshLockoutFromProfile();
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  void _refreshLockoutFromProfile() {
    final state = PinAuthService.checkLockout(
      _profile.failedAttempts,
      _profile.lockedUntil,
      DateTime.now(),
    );
    setState(() {
      _remainingLockout = state.allowed ? null : state.remaining;
    });
    _lockoutTicker?.cancel();
    if (!state.allowed) {
      _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final r = PinAuthService.checkLockout(
          _profile.failedAttempts,
          _profile.lockedUntil,
          DateTime.now(),
        );
        if (r.allowed) {
          _lockoutTicker?.cancel();
          setState(() => _remainingLockout = null);
        } else {
          setState(() => _remainingLockout = r.remaining);
        }
      });
    }
  }

  bool get _isLocked => _remainingLockout != null;

  Future<void> _addDigit(String digit) async {
    if (_isLocked || _verifying) return;
    if (_enteredPin.length >= 4) return;
    setState(() {
      _hasError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      setState(() => _verifying = true);
      final candidate = _enteredPin;
      final ok = PinCredentialHelper.verify(_profile, candidate);
      if (ok) {
        await HiveService.clearFailedAttempts(_profile.id);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final attempts = _profile.failedAttempts + 1;
      final cooldown = PinAuthService.cooldownFor(attempts);
      final lockedUntil = cooldown == Duration.zero
          ? null
          : DateTime.now().add(cooldown);
      await HiveService.bumpFailedAttempts(_profile.id, lockedUntil);
      if (!mounted) return;

      final refreshed = HiveService.getProfileById(_profile.id) ?? _profile;
      setState(() {
        _profile = refreshed;
        _hasError = true;
        _enteredPin = '';
        _verifying = false;
      });
      HapticFeedback.heavyImpact();
      _refreshLockoutFromProfile();
    }
  }

  void _removeDigit() {
    if (_enteredPin.isEmpty || _isLocked || _verifying) return;
    setState(() {
      _hasError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _onForgotPin() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (_) => _PinRecoveryDialog(profile: _profile),
    );
    if (reset == true && mounted) {
      // PIN was reset by the recovery flow → unlock without re-entry.
      Navigator.of(context).pop(true);
    } else if (mounted) {
      // Refresh in case lockout/attempts changed during recovery.
      final refreshed = HiveService.getProfileById(_profile.id) ?? _profile;
      setState(() => _profile = refreshed);
      _refreshLockoutFromProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showForgot = _profile.failedAttempts >= 3 || _isLocked;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              l10n.enterPin(_profile.name),
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasError
                        ? AppColors.error
                        : filled
                            ? AppColors.primary
                            : AppColors.border,
                  ),
                );
              }),
            ),

            if (_isLocked) ...[
              const SizedBox(height: 12),
              Text(
                l10n.pinLockedTryAgainIn(_formatDuration(_remainingLockout!)),
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ] else if (_hasError) ...[
              const SizedBox(height: 12),
              Text(
                l10n.wrongPin,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],

            const SizedBox(height: 24),

            _buildKeypad(),

            if (showForgot) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _onForgotPin,
                child: Text(l10n.forgotPin),
              ),
            ],

            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final disabled = _isLocked || _verifying;
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 56);
                }
                if (key == '⌫') {
                  return SizedBox(
                    width: 72,
                    height: 56,
                    child: TextButton(
                      onPressed: disabled ? null : _removeDigit,
                      child: Icon(Icons.backspace_rounded,
                          color: HCColor.of(context).textSecondary),
                    ),
                  );
                }
                return SizedBox(
                  width: 72,
                  height: 56,
                  child: TextButton(
                    onPressed: disabled ? null : () => _addDigit(key),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      key,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

String _formatDuration(Duration d) {
  if (d.inHours >= 1) {
    final m = d.inMinutes.remainder(60);
    return '${d.inHours}h ${m}m';
  }
  if (d.inMinutes >= 1) {
    final s = d.inSeconds.remainder(60);
    return '${d.inMinutes}m ${s}s';
  }
  return '${d.inSeconds}s';
}

/// Branches on profile.role to present either the recovery-code entry sheet
/// (teacher/parent) or the educator-override sheet (student). Pops `true` if
/// the PIN was reset successfully — the caller unlocks the profile.
class _PinRecoveryDialog extends ConsumerWidget {
  final UserProfile profile;
  const _PinRecoveryDialog({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = profile.role == UserRole.student;
    if (isStudent) {
      return _EducatorOverrideSheet(student: profile);
    }
    return _RecoveryCodeSheet(profile: profile);
  }
}

class _RecoveryCodeSheet extends StatefulWidget {
  final UserProfile profile;
  const _RecoveryCodeSheet({required this.profile});

  @override
  State<_RecoveryCodeSheet> createState() => _RecoveryCodeSheetState();
}

class _RecoveryCodeSheetState extends State<_RecoveryCodeSheet> {
  final _codeController = TextEditingController();
  final _newPinController = TextEditingController();
  bool _verifyingCode = false;
  bool _codeOk = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() {
      _verifyingCode = true;
      _error = null;
    });
    final ok = PinCredentialHelper.verifyRecoveryCode(
      widget.profile,
      _codeController.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _codeOk = true;
        _verifyingCode = false;
      });
    } else {
      // Failed code attempts share the lockout counter.
      final attempts = widget.profile.failedAttempts + 1;
      final cooldown = PinAuthService.cooldownFor(attempts);
      final lockedUntil =
          cooldown == Duration.zero ? null : DateTime.now().add(cooldown);
      await HiveService.bumpFailedAttempts(widget.profile.id, lockedUntil);
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _error = AppLocalizations.of(context)!.recoveryCodeWrong;
      });
    }
  }

  Future<void> _applyNewPin() async {
    final pin = _newPinController.text.trim();
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    final result = PinCredentialHelper.applyPin(widget.profile, pin);
    await HiveService.saveProfile(result.profile);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    if (result.recoveryCode != null) {
      // Show the new recovery code so the user can record it.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RecoveryCodeRevealDialog(code: result.recoveryCode!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_rounded,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              _codeOk ? l10n.setNewPin : l10n.enterRecoveryCode,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 16),
            if (!_codeOk)
              TextField(
                controller: _codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XX',
                  errorText: _error,
                ),
              )
            else
              TextField(
                controller: _newPinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: _error,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _verifyingCode
                      ? null
                      : (_codeOk ? _applyNewPin : _verifyCode),
                  child: Text(_codeOk ? 'Save' : 'Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EducatorOverrideSheet extends StatefulWidget {
  final UserProfile student;
  const _EducatorOverrideSheet({required this.student});

  @override
  State<_EducatorOverrideSheet> createState() => _EducatorOverrideSheetState();
}

class _EducatorOverrideSheetState extends State<_EducatorOverrideSheet> {
  List<UserProfile> _educators = const [];
  UserProfile? _selected;
  final _pinController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEducators();
  }

  void _loadEducators() {
    final all = HiveService.getAllProfilesWithProgress();
    _educators = all
        .map((t) => t.$1)
        .where((p) =>
            (p.role == UserRole.teacher || p.role == UserRole.parent) &&
            p.hasPinProtection)
        .toList();
    if (_educators.isNotEmpty) _selected = _educators.first;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    final ok = PinCredentialHelper.verify(_selected!, _pinController.text);
    if (!ok) {
      setState(() => _error = AppLocalizations.of(context)!.wrongPin);
      return;
    }
    // Clear the student's PIN — they'll need to set a new one via edit
    // profile (or continue without one).
    final cleared = PinCredentialHelper.clearPin(widget.student);
    await HiveService.saveProfile(cleared);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.supervisor_account_rounded,
                size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(l10n.recoveryViaEducatorTitle,
                style: AppTypography.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.recoveryViaEducatorPrompt(widget.student.name),
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_educators.isEmpty)
              Text(l10n.recoveryNoEducator,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.error),
                  textAlign: TextAlign.center)
            else ...[
              DropdownButton<UserProfile>(
                value: _selected,
                isExpanded: true,
                items: _educators
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} — ${p.role.label}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selected = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '••••',
                  errorText: _error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _educators.isEmpty ? null : _confirm,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One-time, confirm-to-dismiss dialog showing a freshly-generated recovery
/// code. The plaintext is never persisted — only the hash — so this is the
/// user's only chance to record it.
class _RecoveryCodeRevealDialog extends StatelessWidget {
  final String code;
  const _RecoveryCodeRevealDialog({required this.code});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.recoveryCodeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.recoveryCodeSubtitle, style: AppTypography.bodySmall),
          const SizedBox(height: 16),
          SelectableText(
            code,
            style: AppTypography.titleLarge.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.recoveryCodeConfirm),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}