import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/avatar_data.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/learning_level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/home_group.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_join_provider.dart';
import '../../../providers/join_code_provider.dart';

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
/// Collects: Name, Avatar (free avatars only), Age / Birth Date, optional
/// 4-digit PIN. On submit, persists the profile + membership via the
/// matching join provider and pushes the accessibility-setup wizard.
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

  String get _roleNoun => _isStudentJoin ? 'Student' : 'Child';

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
      helpText: 'Select birth date',
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
    final role = _isStudentJoin ? UserRole.student : UserRole.child;
    final classroomId =
        ctx is ClassJoinContext ? ctx.classroom.id : null;
    final homeGroupId =
        ctx is HomeGroupJoinContext ? ctx.group.id : null;

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
        const SnackBar(content: Text('Please select a birth date.')),
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
    final classState = ref.watch(joinCodeProvider);
    final homeState = ref.watch(homeGroupJoinProvider);
    final isLoading =
        classState is JoinCodeLoading || homeState is HomeGroupJoinLoading;
    final classFailure =
        classState is JoinCodeFailure ? classState : null;
    final homeFailure =
        homeState is HomeGroupJoinFailure ? homeState : null;
    final failureMessage =
        classFailure?.message ?? homeFailure?.message;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('$_roleNoun Profile'),
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
                  colors: [Color(0xFFF5F0FF), AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : null,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Let's set up your profile",
                    style: AppTypography.displaySmall.copyWith(
                      color:
                          isDark ? colorScheme.primary : AppColors.primaryDark,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    _isStudentJoin
                        ? 'You joined ${(widget.joinContext as ClassJoinContext).classroom.name}.'
                        : 'You joined ${(widget.joinContext as HomeGroupJoinContext).group.name}.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                  const SizedBox(height: 28),

                  // ─── Name ──────────────────────────────
                  Text('Name', style: AppTypography.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: const Icon(Icons.person_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _nameController.clear(),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── Avatar (free only) ────────────────
                  Text(
                    'Choose your avatar',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AvatarData.avatars.asMap().entries.map((entry) {
                      final i = entry.key;
                      final avatar = entry.value;
                      final isSelected = _selectedAvatarIndex == i;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label:
                            '${avatar.label} avatar${isSelected ? ", selected" : ""}',
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedAvatarIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? avatar.color
                                  : avatar.color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: avatar.color
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                avatar.emoji,
                                style: TextStyle(
                                  fontSize: isSelected ? 30 : 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                  const SizedBox(height: 28),

                  // ─── Age / Birth Date ──────────────────
                  Text('Age / Birth Date', style: AppTypography.titleMedium),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickBirthDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        key: ValueKey(_selectedBirthDate),
                        style: AppTypography.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Tap to select birth date',
                          prefixIcon: const Icon(Icons.cake_rounded),
                          suffixIcon: _selectedBirthDate != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Chip(
                                    label: Text(
                                      '${_computedAge ?? "?"} yrs old',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                              : null,
                        ),
                        initialValue: _selectedBirthDate != null
                            ? '${_selectedBirthDate!.month}/${_selectedBirthDate!.day}/${_selectedBirthDate!.year}'
                            : '',
                        validator: (value) {
                          if (_selectedBirthDate == null) {
                            return 'Please select a birth date';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── PIN Lock (optional) ───────────────
                  Text('PIN Protection', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Add a 4-digit PIN to protect this profile',
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enablePin,
                    onChanged: (val) {
                      setState(() {
                        _enablePin = val;
                        if (!val) {
                          _pinController.clear();
                          _pinConfirmController.clear();
                        }
                      });
                    },
                    title: Text(
                      'Enable PIN lock',
                      style: AppTypography.bodyLarge,
                    ),
                    secondary: Icon(
                      _enablePin
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: _enablePin
                          ? AppColors.primary
                          : AppColors.textHint,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_enablePin) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      style: AppTypography.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Enter 4-digit PIN',
                        prefixIcon: Icon(Icons.pin_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (!_enablePin) return null;
                        if (value == null || value.length != 4) {
                          return 'PIN must be exactly 4 digits';
                        }
                        if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                          return 'PIN must contain only digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pinConfirmController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      style: AppTypography.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'Confirm PIN',
                        prefixIcon: Icon(Icons.pin_rounded),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (!_enablePin) return null;
                        if (value != _pinController.text) {
                          return 'PINs do not match';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ─── Failure banner (Firestore write errors) ──
                  if (failureMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        failureMessage,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),

                  // ─── Continue ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _submit,
                        icon: Icon(isLoading
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_forward_rounded),
                        label: Text(
                            isLoading ? 'Saving…' : 'Continue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          textStyle: AppTypography.buttonText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
