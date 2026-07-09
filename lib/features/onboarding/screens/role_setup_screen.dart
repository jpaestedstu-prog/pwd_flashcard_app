import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/avatar_data.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/learning_level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/role_theme.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_button.dart';
import '../widgets/profile_setup_form.dart';

/// Profile-setup screen for the three non-join roles: Player, Teacher,
/// Parent. Mirrors the structure of [PostJoinSetupScreen] (used by Student
/// and Child after a join code) so all five roles converge on the same
/// "Name → Avatar → PIN" UX.
///
/// After setup, only **learner** roles (Player) continue to the
/// accessibility wizard. Teachers / Parents are educators — they don't
/// self-classify a disability, so they skip straight to their home /
/// onboarding tutorial. Accessibility for the learners they manage is set
/// per-class in Manage Classes / Home Groups; their own display preferences
/// live in Settings.
///
/// No birth date / grade level — those are student-only.
class RoleSetupScreen extends ConsumerStatefulWidget {
  final UserRole role;

  /// For the Player role only: whether to create a guest (local-only,
  /// never-synced) profile or a progress-keeping one that can be backed up.
  /// Ignored for Teacher / Parent, which are never guest profiles.
  final bool guestPlayer;

  const RoleSetupScreen({
    super.key,
    required this.role,
    this.guestPlayer = true,
  }) : assert(
          role == UserRole.player ||
              role == UserRole.teacher ||
              role == UserRole.parent,
          'RoleSetupScreen is only for player/teacher/parent roles',
        );

  /// True when this setup creates a guest Player profile (no cloud sync).
  bool get isGuestPlayer => role == UserRole.player && guestPlayer;

  @override
  ConsumerState<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends ConsumerState<RoleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  late int _selectedAvatarIndex;
  bool _enablePin = false;
  bool _isSubmitting = false;
  DateTime? _selectedBirthDate;

  /// The "Player (With Progress)" variant behaves like a Student / Child
  /// learner profile: it collects a birth date and derives a learning level
  /// so progress can adapt. The Guest player (and Teacher / Parent) skip this.
  bool get _collectsBirthDate =>
      widget.role == UserRole.player && !widget.guestPlayer;

  int? get _computedAge {
    final dob = _selectedBirthDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _selectedAvatarIndex = AvatarData.defaultIndexForRole(widget.role);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  String _subheader(AppLocalizations l10n) => switch (widget.role) {
        UserRole.player => widget.guestPlayer
            ? l10n.roleSetupPlayerGuest
            : l10n.roleSetupPlayerProgress,
        UserRole.teacher => l10n.roleSetupTeacher,
        UserRole.parent => l10n.roleSetupParent,
        _ => '',
      };

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 7),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: AppLocalizations.of(context)!.selectBirthDate,
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_collectsBirthDate && _selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectBirthDate),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final rawPin = _enablePin && _pinController.text.length == 4
        ? _pinController.text
        : null;

    final birth = _collectsBirthDate ? _selectedBirthDate : null;

    var profile = UserProfile(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      role: widget.role,
      avatarIndex: _selectedAvatarIndex,
      createdAt: DateTime.now(),
      isGuestPlayer: widget.isGuestPlayer,
      birthDate: birth,
      learningLevel: _collectsBirthDate
          ? LearningLevelService.suggestLevelFromBirthDate(birth)
          : null,
    );

    String? recoveryCode;
    if (rawPin != null) {
      final result = PinCredentialHelper.applyPin(profile, rawPin);
      profile = result.profile;
      recoveryCode = result.recoveryCode;
    }

    await ref.read(profileProvider.notifier).setProfile(profile);
    if (!mounted) return;

    if (recoveryCode != null) {
      await _showRecoveryCodeOnce(recoveryCode);
      if (!mounted) return;
    }

    // Educators (Teacher / Parent) don't self-classify a disability, so they
    // skip the learner accessibility wizard — their classes' accessibility is
    // assigned in Manage Classes / Home Groups and their own display prefs
    // live in Settings. Players are independent learners and still self-select.
    if (widget.role.isEducator) {
      final pid = ref.read(profileProvider)?.id ?? '';
      final seen = HiveService.hasSeenTutorial(pid);
      context.go(seen ? '/home' : '/onboarding-tutorial');
    } else {
      context.go('/accessibility-setup');
    }
  }

  Future<void> _showRecoveryCodeOnce(String code) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.recoveryCodeConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final roleTheme = RoleTheme.of(widget.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setUpProfileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  colors: [AppColors.surfaceVariant, AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : null,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.maxContentWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Role-themed header ──────────────────
                      Row(
                        children: [
                          _RoleBadge(roleTheme: roleTheme),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.letsSetUpProfile,
                                  style: AppTypography.displaySmall.copyWith(
                                    color: isDark
                                        ? colorScheme.primary
                                        : AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _subheader(l10n),
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: HCColor.of(context).textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),

                      AppSpacing.gapXl,

                      ProfileSetupForm(
                        role: widget.role,
                        nameController: _nameController,
                        selectedAvatarIndex: _selectedAvatarIndex,
                        onAvatarSelected: (i) =>
                            setState(() => _selectedAvatarIndex = i),
                        showBirthDate: _collectsBirthDate,
                        birthDate: _selectedBirthDate,
                        computedAge: _computedAge,
                        suggestedLevel: _collectsBirthDate
                            ? LearningLevelService.suggestLevelFromBirthDate(
                                _selectedBirthDate)
                            : null,
                        onPickBirthDate: _pickBirthDate,
                        enablePin: _enablePin,
                        onTogglePin: (val) {
                          setState(() {
                            _enablePin = val;
                            if (!val) {
                              _pinController.clear();
                              _pinConfirmController.clear();
                            }
                          });
                        },
                        pinController: _pinController,
                        pinConfirmController: _pinConfirmController,
                      ),

                      AppSpacing.gapXl,

                      AppButton.primary(
                        label: _isSubmitting ? l10n.saving : l10n.letsGo,
                        icon: _isSubmitting
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_forward_rounded,
                        fullWidth: true,
                        onPressed: _isSubmitting ? null : _createProfile,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular role-identity badge using [RoleTheme]'s gradient + Material icon.
/// Material icons are used (not emoji) so the glyph renders on every Android
/// version the app supports.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.roleTheme});

  final RoleTheme roleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: roleTheme.gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: roleTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(roleTheme.icon, color: Colors.white, size: 32),
    );
  }
}
