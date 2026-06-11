import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/learning_level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/role_theme.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/home_group.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_join_provider.dart';
import '../../../providers/join_code_provider.dart';
import '../../../widgets/app_button.dart';
import '../widgets/profile_setup_form.dart';

/// Identifies which join flow led the user to the post-join setup screen.
///
/// Carries the resolved [Classroom] / [HomeGroup] from the code-only step
/// so this screen can build a profile that's already linked to the right
/// container before any Firestore write.
sealed class JoinContext {
  const JoinContext();
}

class ClassJoinContext extends JoinContext {
  final Classroom classroom;
  const ClassJoinContext(this.classroom);
}

class HomeGroupJoinContext extends JoinContext {
  final HomeGroup group;
  const HomeGroupJoinContext(this.group);
}

/// Profile-setup screen shown after a learner successfully validates a
/// class code (Student) or home-group code (Child).
///
/// Collects: Name, Avatar, Age / Birth Date, optional 4-digit PIN — via the
/// shared [ProfileSetupForm]. On submit, persists the profile + membership
/// via the matching join provider and pushes the accessibility-setup wizard.
///
/// If the active profile is in Player Mode, that profile is upgraded
/// in place — same UUID, existing local progress preserved.
class PostJoinSetupScreen extends ConsumerStatefulWidget {
  final JoinContext joinContext;

  const PostJoinSetupScreen({super.key, required this.joinContext});

  @override
  ConsumerState<PostJoinSetupScreen> createState() =>
      _PostJoinSetupScreenState();
}

class _PostJoinSetupScreenState extends ConsumerState<PostJoinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  int _selectedAvatarIndex = 0;
  DateTime? _selectedBirthDate;
  bool _enablePin = false;

  /// True when we're upgrading an existing Player profile into a Student /
  /// Child. We preserve the profile id (and ownerUid) so local progress
  /// and any prior Firestore docs continue to belong to the same user.
  UserProfile? _upgradingFrom;

  bool get _isStudentJoin => widget.joinContext is ClassJoinContext;

  UserRole get _role => _isStudentJoin ? UserRole.student : UserRole.child;

  @override
  void initState() {
    super.initState();
    final active = ref.read(profileProvider);
    if (active != null && active.isPlayerMode) {
      _upgradingFrom = active;
      _nameController.text = active.name;
      _selectedAvatarIndex = active.avatarIndex;
      _selectedBirthDate = active.birthDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

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

  /// Build a fully-populated profile from the form state.
  ///
  /// Honours Player-mode upgrades (same id, role flipped, isGuestPlayer
  /// cleared) and falls back to a fresh UUID otherwise.
  UserProfile _buildProfile() {
    final name = _nameController.text.trim();
    final birth = _selectedBirthDate;
    final level = LearningLevelService.suggestLevelFromBirthDate(birth);
    final ctx = widget.joinContext;
    final role = _role;
    final classroomId = ctx is ClassJoinContext ? ctx.classroom.id : null;
    final homeGroupId = ctx is HomeGroupJoinContext ? ctx.group.id : null;

    final upgrading = _upgradingFrom;
    if (upgrading != null) {
      return upgrading.copyWith(
        name: name,
        role: role,
        avatarIndex: _selectedAvatarIndex,
        isGuestPlayer: false,
        birthDate: () => birth,
        learningLevel: () => level,
        classroomId: () => classroomId,
        homeGroupId: () => homeGroupId,
      );
    }

    return UserProfile(
      id: const Uuid().v4(),
      name: name,
      role: role,
      avatarIndex: _selectedAvatarIndex,
      createdAt: DateTime.now(),
      birthDate: birth,
      learningLevel: level,
      classroomId: classroomId,
      homeGroupId: homeGroupId,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectBirthDate)),
      );
      return;
    }

    var profile = _buildProfile();

    // Apply PIN if requested. Recovery code is null for student/child
    // roles (recovery is via educator override, see PinCredentialHelper).
    if (_enablePin && _pinController.text.length == 4) {
      final result =
          PinCredentialHelper.applyPin(profile, _pinController.text);
      profile = result.profile;
    }

    final ctx = widget.joinContext;
    final ok = switch (ctx) {
      ClassJoinContext() => await ref
          .read(joinCodeProvider.notifier)
          .completeJoin(profile: profile, classroom: ctx.classroom),
      HomeGroupJoinContext() => await ref
          .read(homeGroupJoinProvider.notifier)
          .completeJoin(profile: profile, group: ctx.group),
    };

    if (!ok || !mounted) return;
    // Hand off to the accessibility setup wizard. We deliberately do
    // *not* pass `extra: profile`: completeJoin() has already set the new
    // profile as the active one, so the wizard's non-educator branch
    // applies the accessibility preset to global settings — which is what
    // we want for the learner. Passing extra would steer it into the
    // educator-setup branch and skip the settings update.
    context.go('/accessibility-setup');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final classState = ref.watch(joinCodeProvider);
    final homeState = ref.watch(homeGroupJoinProvider);
    final isLoading =
        classState is JoinCodeLoading || homeState is HomeGroupJoinLoading;
    final classFailure = classState is JoinCodeFailure ? classState : null;
    final homeFailure = homeState is HomeGroupJoinFailure ? homeState : null;
    final failureMessage = classFailure?.message ?? homeFailure?.message;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final roleTheme = RoleTheme.of(_role);

    final joinedName = switch (widget.joinContext) {
      ClassJoinContext(:final classroom) => classroom.name,
      HomeGroupJoinContext(:final group) => group.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setUpProfileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(_isStudentJoin ? '/join-class' : '/join-home-group');
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
                                  l10n.youJoined(joinedName),
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
                        role: _role,
                        nameController: _nameController,
                        selectedAvatarIndex: _selectedAvatarIndex,
                        onAvatarSelected: (i) =>
                            setState(() => _selectedAvatarIndex = i),
                        showBirthDate: true,
                        birthDate: _selectedBirthDate,
                        computedAge: _computedAge,
                        suggestedLevel: LearningLevelService
                            .suggestLevelFromBirthDate(_selectedBirthDate),
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

                      // ─── Failure banner (Firestore write errors) ──
                      if (failureMessage != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            border: Border.all(color: AppColors.error),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            failureMessage,
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.errorDark),
                          ),
                        ),

                      AppButton.primary(
                        label: isLoading ? l10n.saving : l10n.continueButton,
                        icon: isLoading
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_forward_rounded,
                        fullWidth: true,
                        onPressed: isLoading ? null : _submit,
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
