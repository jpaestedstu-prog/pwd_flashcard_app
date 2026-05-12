import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/learning_level_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/local_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';

/// Suggests a [GradeLevel] based on the student's age.
GradeLevel? suggestGradeLevelFromAge(int age) {
  if (age <= 5) return GradeLevel.kinder;
  if (age == 6) return GradeLevel.grade1;
  if (age == 7) return GradeLevel.grade2;
  if (age == 8) return GradeLevel.grade3;
  if (age == 9) return GradeLevel.grade4;
  if (age == 10) return GradeLevel.grade5;
  if (age == 11) return GradeLevel.grade6;
  if (age >= 12 && age <= 17) return GradeLevel.highSchool;
  if (age >= 18) return GradeLevel.college;
  return null;
}

/// Top-level entry choices on the role-picker screen.
///
/// - `player`: casual guest mode. Local-only, never syncs to Firestore.
/// - `joinClass`: school-linked Student. Routes to [JoinClassScreen].
/// - `joinHomeGroup`: family-linked Child. Routes to [JoinHomeGroupScreen].
/// - `teacher` / `parent`: educator roles, set a PIN, manage learners.
enum _EntryChoice { player, joinClass, joinHomeGroup, teacher, parent }

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  /// When non-null, the role selection step is skipped and
  /// the profile is created with this role directly.
  final UserRole? forceRole;

  const ProfileSelectionScreen({super.key, this.forceRole});

  @override
  ConsumerState<ProfileSelectionScreen> createState() =>
      _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState
    extends ConsumerState<ProfileSelectionScreen> {
  UserRole? _selectedRole;
  _EntryChoice? _selectedChoice;
  int _selectedAvatarIndex = 0;
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedBirthDate;
  GradeLevel? _selectedGradeLevel;
  bool _gradeLevelAutoSuggested = false;
  bool _enablePin = false;
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();

  /// True when an educator is creating a student profile.
  bool get _isEducatorCreatingStudent => widget.forceRole == UserRole.student;

  /// True when the selected role is student (student profile needs age & level).
  bool get _isStudentProfile =>
      _selectedRole == UserRole.student;

  /// True when the active choice is Player Mode (untracked, no classroom).
  bool get _isPlayerMode => _selectedChoice == _EntryChoice.player;

  @override
  void initState() {
    super.initState();
    if (widget.forceRole != null) {
      _selectedRole = widget.forceRole;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  /// Computes age from [_selectedBirthDate].
  int? get _computedAge {
    if (_selectedBirthDate == null) return null;
    final now = DateTime.now();
    int years = now.year - _selectedBirthDate!.year;
    if (now.month < _selectedBirthDate!.month ||
        (now.month == _selectedBirthDate!.month &&
            now.day < _selectedBirthDate!.day)) {
      years--;
    }
    return years;
  }

  void _onBirthDateChanged(DateTime? date) {
    setState(() {
      _selectedBirthDate = date;
      // Auto-suggest grade level when age changes
      final age = _computedAge;
      if (age != null) {
        final suggested = suggestGradeLevelFromAge(age);
        if (suggested != null) {
          _selectedGradeLevel = suggested;
          _gradeLevelAutoSuggested = true;
        }
      }
    });
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
      _onBirthDateChanged(picked);
    }
  }

  Future<void> _createProfile() async {
    if (_selectedRole == null) return;
    if (!_formKey.currentState!.validate()) return;

    final rawPin = _enablePin && _pinController.text.length == 4
        ? _pinController.text
        : null;

    final birth = _isStudentProfile ? _selectedBirthDate : null;
    var profile = UserProfile(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      role: _selectedRole!,
      avatarIndex: _selectedAvatarIndex,
      createdAt: DateTime.now(),
      birthDate: birth,
      gradeLevel: _isStudentProfile ? _selectedGradeLevel : null,
      isGuestPlayer: _isPlayerMode,
      // Learners get an initial learning level derived from age (or
      // beginner when no birthdate is set). Educators don't carry one.
      learningLevel: _selectedRole!.isLearner
          ? LearningLevelService.suggestLevelFromBirthDate(birth)
          : null,
    );

    String? recoveryCode;
    if (rawPin != null) {
      final result = PinCredentialHelper.applyPin(profile, rawPin);
      profile = result.profile;
      recoveryCode = result.recoveryCode;
    }

    if (_isEducatorCreatingStudent) {
      // Save the student profile without switching the active profile.
      // The educator stays logged in. Route through LocalRepository so
      // the new student profile reaches Firestore with `owner_uid`
      // stamped — required by the new strict rules for any subsequent
      // cloud read/write of this profile (progress, classroom join, etc.).
      await const LocalRepository().saveProfile(profile);
      // Initialise empty progress so the student appears in dashboards.
      await HiveService.saveProgress(LearningProgress(
        profileId: profile.id,
        lastActivityDate: DateTime.now(),
      ));
      if (!mounted) return;
      // Invalidate providers so dashboards pick up the new student.
      ref.invalidate(allProfilesWithProgressProvider);
      if (recoveryCode != null) {
        await _showRecoveryCodeOnce(recoveryCode);
        if (!mounted) return;
      }
      // Navigate to accessibility setup for this student.
      context.push('/accessibility-setup', extra: profile);
      return;
    }

    await ref.read(profileProvider.notifier).setProfile(profile);
    if (!mounted) return;
    if (recoveryCode != null) {
      await _showRecoveryCodeOnce(recoveryCode);
      if (!mounted) return;
    }
    // Skip accessibility setup for educator roles (parent/teacher)
    if (_selectedRole == UserRole.teacher || _selectedRole == UserRole.parent) {
      context.go('/home');
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

  /// Handle a top-level entry-card tap.
  ///
  /// `joinClass` routes to the dedicated /join-class screen so the student
  /// only has to enter a code + name. The other choices reveal the
  /// existing profile-creation form below.
  void _onChoiceTapped(_EntryChoice choice) {
    if (choice == _EntryChoice.joinClass) {
      context.go('/join-class');
      return;
    }
    if (choice == _EntryChoice.joinHomeGroup) {
      context.go('/join-home-group');
      return;
    }
    setState(() {
      _selectedChoice = choice;
      _selectedRole = switch (choice) {
        _EntryChoice.player => UserRole.player,
        _EntryChoice.joinClass => UserRole.student,
        _EntryChoice.joinHomeGroup => UserRole.child,
        _EntryChoice.teacher => UserRole.teacher,
        _EntryChoice.parent => UserRole.parent,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
          color: isDark ? Theme.of(context).scaffoldBackgroundColor : null,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // ─── Title ──────────────────────────────
                Text(
                      _isEducatorCreatingStudent
                          ? 'Add Student'
                          : AppLocalizations.of(context)!.welcome,
                      style: AppTypography.displayMedium.copyWith(
                        color: isDark ? colorScheme.primary : AppColors.primaryDark,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  _isEducatorCreatingStudent
                      ? 'Create a student profile to track progress'
                      : AppLocalizations.of(context)!.whoAreYou,
                  style: AppTypography.titleLarge.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                const SizedBox(height: 40),

                // ─── Entry Choice Cards (hidden when forceRole is set) ──
                if (widget.forceRole == null)
                  ..._EntryChoice.values.asMap().entries.map((entry) {
                    final index = entry.key;
                    final choice = entry.value;
                    final isSelected = _selectedChoice == choice;

                    return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ChoiceCard(
                            choice: choice,
                            isSelected: isSelected,
                            onTap: () => _onChoiceTapped(choice),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: (300 + index * 100).ms)
                        .slideX(begin: index.isEven ? -0.15 : 0.15, end: 0);
                  }),

                const SizedBox(height: 32),

                // ─── Profile Form ─────────────────────────
                if (_selectedRole != null)
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Name Input ──────────────
                        Text(
                          AppLocalizations.of(context)!.whatsYourName,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          style: AppTypography.bodyLarge,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.enterYourName,
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
                          onFieldSubmitted: (_) => _createProfile(),
                        ),

                        // ─── Age & Grade Level (students only) ──
                        if (_isStudentProfile) ...[
                          const SizedBox(height: 28),

                          // ─── Birth Date Picker ──────
                          Text(
                            'Age / Birth Date',
                            style: AppTypography.titleMedium,
                          ),
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
                                            backgroundColor:
                                                AppColors.primary.withValues(alpha: 0.1),
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

                          // ─── Grade Level Picker ──────
                          Text(
                            'Learning Level',
                            style: AppTypography.titleMedium,
                          ),
                          if (_gradeLevelAutoSuggested &&
                              _selectedGradeLevel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '✨ Suggested based on age: ${_selectedGradeLevel!.label}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.success,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<GradeLevel>(
                            initialValue: _selectedGradeLevel,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.school_rounded),
                              hintText: 'Select learning level',
                            ),
                            items: GradeLevel.values.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(level.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGradeLevel = value;
                                _gradeLevelAutoSuggested = false;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a learning level';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ─── Avatar Picker ──────────────
                        Text(
                          AppLocalizations.of(context)!.chooseYourAvatar,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AvatarData.avatars.asMap().entries.map((
                            entry,
                          ) {
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
                                              color: avatar.color.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                            BoxShadow(
                                              color: avatar.color.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 20,
                                              spreadRadius: 2,
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

                        // ─── PIN Protection (optional) ──────
                        Text(
                          'PIN Protection',
                          style: AppTypography.titleMedium,
                        ),
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

                        const SizedBox(height: 28),

                        // ─── Continue Button ──────────────
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
                              onPressed: _createProfile,
                              icon: Icon(_isEducatorCreatingStudent
                                  ? Icons.person_add_rounded
                                  : Icons.arrow_forward_rounded),
                              label: Text(_isEducatorCreatingStudent
                                  ? 'Create Student'
                                  : AppLocalizations.of(context)!.letsGo),
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
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final _EntryChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  String get _emoji => switch (choice) {
        _EntryChoice.player => '🎮',
        _EntryChoice.joinClass => '🎓',
        _EntryChoice.joinHomeGroup => '🧒',
        _EntryChoice.teacher => '👩‍🏫',
        _EntryChoice.parent => '👨‍👩‍👧',
      };

  String get _label => switch (choice) {
        _EntryChoice.player => 'Player',
        _EntryChoice.joinClass => 'Student',
        _EntryChoice.joinHomeGroup => 'Child',
        _EntryChoice.teacher => 'Teacher',
        _EntryChoice.parent => 'Parent',
      };

  String get _subtitle => switch (choice) {
        _EntryChoice.player => 'Just play — no progress saved',
        _EntryChoice.joinClass => 'Join with a class code',
        _EntryChoice.joinHomeGroup => 'Join with a home-group code',
        _EntryChoice.teacher => 'I want to help',
        _EntryChoice.parent => 'I want to support',
      };

  (Color, Color) get _colors => switch (choice) {
        _EntryChoice.player =>
          (const Color(0xFF7E57C2), const Color(0xFF9575CD)),
        _EntryChoice.joinClass => (AppColors.primary, AppColors.secondary),
        _EntryChoice.joinHomeGroup =>
          (const Color(0xFF26A69A), const Color(0xFF4DB6AC)),
        _EntryChoice.teacher =>
          (AppColors.secondary, const Color(0xFF4DB6AC)),
        _EntryChoice.parent =>
          (AppColors.accent, const Color(0xFFFF8A65)),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$_label option${isSelected ? ", selected" : ""}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [colors.$1, colors.$2]
                  : [HCColor.of(context).surface, HCColor.of(context).surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? colors.$1
                  : AppColors.primary.withValues(alpha: 0.15),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.$1.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : colors.$1.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          colors.$1.withValues(alpha: isSelected ? 0.3 : 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: AppTypography.titleLarge.copyWith(
                        color: isSelected
                            ? Colors.white
                            : HCColor.of(context).textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: isSelected
                      ? colors.$1
                      : HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
