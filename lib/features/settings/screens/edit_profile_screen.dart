import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/accessibility_presets.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/shop_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';

/// Screen for editing an existing user profile (name, avatar, disability type).
///
/// Changing the disability type offers to re-apply accessibility presets.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _sectionController;
  late TextEditingController _tagController;
  late int _selectedAvatar;
  late DisabilityType _selectedDisability;
  late GradeLevel? _selectedGradeLevel;
  late DateTime? _selectedBirthDate;
  late List<String> _tags;
  bool _hasChanged = false;

  // Premium avatar selection (null = using free avatar)
  String? _selectedPremiumAvatarId;
  String? _originalPremiumAvatarId;

  // PIN management
  bool _hasPinOriginal = false;
  bool _enablePin = false;
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  bool _removingPin = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile?.name ?? '');
    _sectionController = TextEditingController(text: profile?.section ?? '');
    _tagController = TextEditingController();
    _selectedAvatar = profile?.avatarIndex ?? 0;
    _selectedDisability = profile?.disabilityType ?? DisabilityType.none;
    _selectedGradeLevel = profile?.gradeLevel;
    _selectedBirthDate = profile?.birthDate;
    _tags = List<String>.from(profile?.tags ?? []);
    _hasPinOriginal = profile?.hasPinProtection ?? false;
    _enablePin = _hasPinOriginal;
    // Check if a premium avatar is currently equipped
    final progressN = ref.read(progressProvider.notifier);
    _selectedPremiumAvatarId = progressN.getEquippedItemId(ShopItemType.avatar);
    _originalPremiumAvatarId = _selectedPremiumAvatarId;
    _nameController.addListener(_onChanged);
    _sectionController.addListener(_onChanged);
  }

  void _onChanged() {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final changed = _nameController.text.trim() != profile.name ||
        _selectedAvatar != profile.avatarIndex ||
        _selectedDisability != profile.disabilityType ||
        _selectedGradeLevel != profile.gradeLevel ||
        _sectionController.text.trim() != (profile.section ?? '') ||
        _selectedBirthDate != profile.birthDate ||
        !_listEquals(_tags, profile.tags) ||
        _enablePin != _hasPinOriginal ||
        _removingPin ||
        _selectedPremiumAvatarId != _originalPremiumAvatarId ||
        (_enablePin && !_hasPinOriginal && _pinController.text.length == 4);
    if (changed != _hasChanged) setState(() => _hasChanged = changed);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagController.clear();
    _onChanged();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _tagController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.warning(context, message: 'Please enter a name');
      return;
    }

    final profile = ref.read(profileProvider);
    if (profile == null) return;

    // Validate PIN if setting a new one
    if (_enablePin && !_hasPinOriginal) {
      if (_pinController.text.length != 4 ||
          !RegExp(r'^\d{4}$').hasMatch(_pinController.text)) {
        AppSnackBar.error(context, message: 'PIN must be exactly 4 digits');
        return;
      }
      if (_pinController.text != _pinConfirmController.text) {
        AppSnackBar.error(context, message: 'PINs do not match');
        return;
      }
    }

    final disabilityChanged = _selectedDisability != profile.disabilityType;

    // Update non-PIN fields first.
    final sectionText = _sectionController.text.trim();
    var updated = profile.copyWith(
      name: name,
      avatarIndex: _selectedAvatar,
      disabilityType: _selectedDisability,
      gradeLevel: () => _selectedGradeLevel,
      section: () => sectionText.isNotEmpty ? sectionText : null,
      birthDate: () => _selectedBirthDate,
      tags: _tags,
    );

    // Apply PIN changes via the credential helper so plaintext is never
    // persisted. Three states: remove, add (with hashing), or unchanged.
    String? newRecoveryCode;
    if (_removingPin || (!_enablePin && _hasPinOriginal)) {
      updated = PinCredentialHelper.clearPin(updated);
    } else if (_enablePin &&
        !_hasPinOriginal &&
        _pinController.text.length == 4) {
      final result =
          PinCredentialHelper.applyPin(updated, _pinController.text);
      updated = result.profile;
      newRecoveryCode = result.recoveryCode;
    }

    await ref.read(profileProvider.notifier).setProfile(updated);
    if (newRecoveryCode != null && mounted) {
      await _showRecoveryCodeOnce(newRecoveryCode);
    }

    // Equip/unequip premium avatar
    final progressNotifier = ref.read(progressProvider.notifier);
    if (_selectedPremiumAvatarId != _originalPremiumAvatarId) {
      if (_selectedPremiumAvatarId != null) {
        progressNotifier.equipItem(_selectedPremiumAvatarId!, ShopItemType.avatar);
      } else {
        progressNotifier.unequipItem(ShopItemType.avatar);
      }
    }

    // If disability type changed, offer to re-apply presets
    if (disabilityChanged &&
        _selectedDisability != DisabilityType.none &&
        mounted) {
      final apply = await _showPresetDialog();
      if (apply == true) {
        final current = ref.read(settingsProvider);
        final preset =
            AccessibilityPresets.presetFor(_selectedDisability, current: current);
        ref.read(settingsProvider.notifier).update(preset);
      }
    }

    if (mounted) {
      AppSnackBar.success(context, message: 'Profile updated! \u2705');
      context.pop();
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

  Future<bool?> _showPresetDialog() {
    final changes = AccessibilityPresets.changeSummary(_selectedDisability);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Accessibility Presets?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your disability type changed to "${_selectedDisability.label}". '
              'Would you like to auto-configure accessibility settings?',
              style: AppTypography.bodyMedium,
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...changes.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('${c.name}: ',
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(c.value, style: AppTypography.bodySmall),
                      ],
                    ),
                  )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply Presets'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final hc = HCColor.of(context);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: RichEmptyState(
          emoji: '👤',
          title: 'No Profile Selected',
          description: 'Please select a profile to edit.',
          actionLabel: 'Go Back',
          actionIcon: Icons.arrow_back_rounded,
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _hasChanged ? _save : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Avatar Selection ─────────────
          Center(
            child: Column(
              children: [
                Builder(builder: (_) {
                  final premiumItem = _selectedPremiumAvatarId != null
                      ? ShopData.findById(_selectedPremiumAvatarId!)
                      : null;
                  final emoji = premiumItem?.emoji ??
                      AvatarData.getAvatar(_selectedAvatar).emoji;
                  final color = premiumItem?.color ??
                      AvatarData.getAvatar(_selectedAvatar).color;
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  );
                }).animate().scale(duration: 300.ms, curve: Curves.easeOut),
                const SizedBox(height: 8),
                Text(
                  'Tap below to change avatar',
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Avatar grid
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: AvatarData.avatarsForRole(ref.read(profileProvider)?.role)
                .map((entry) {
              final i = entry.$1;
              final av = entry.$2;
              final isSelected =
                  i == _selectedAvatar && _selectedPremiumAvatarId == null;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatar = i;
                    _selectedPremiumAvatarId = null;
                  });
                  _onChanged();
                },
                child: Semantics(
                  label: '${av.label} avatar${isSelected ? ', selected' : ''}',
                  button: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: context.scaleIcon(56),
                    height: context.scaleIcon(56),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? av.color.withValues(alpha: 0.3)
                          : hc.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? av.color : Colors.transparent,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(av.emoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ─── Premium Avatars ──────────────
          Text('Premium Avatars',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Earn stars in games to unlock special avatars!',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final progressN = ref.read(progressProvider.notifier);
            final premiumAvatars =
                ShopData.byType(ShopItemType.avatar);
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: premiumAvatars.map((item) {
                final owned = progressN.hasPurchased(item.id);
                final isSelected =
                    _selectedPremiumAvatarId == item.id;
                return GestureDetector(
                  onTap: owned
                      ? () {
                          setState(() {
                            _selectedPremiumAvatarId = isSelected
                                ? null
                                : item.id;
                          });
                          _onChanged();
                        }
                      : () {
                          AppSnackBar.info(
                            context,
                            message: '${item.emoji} ${item.name} costs ${item.cost} \u2b50 \u2014 visit the Star Shop!',
                          );
                        },
                  child: Semantics(
                    label:
                        '${item.name} premium avatar${owned ? (isSelected ? ", selected" : ", owned") : ", locked, ${item.cost} stars"}',
                    button: true,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: context.scaleIcon(56),
                      height: context.scaleIcon(56),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withValues(alpha: 0.4)
                            : owned
                                ? item.color.withValues(alpha: 0.15)
                                : hc.surface.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? item.color
                              : owned
                                  ? item.color.withValues(alpha: 0.4)
                                  : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            item.emoji,
                            style: TextStyle(
                              fontSize: 28,
                              color: owned
                                  ? null
                                  : Colors.grey,
                            ),
                          ),
                          if (!owned)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.cost}⭐',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),

          const SizedBox(height: 28),

          // ─── Name Field ───────────────────
          Text('Name',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: hc.surface,
            ),
            maxLength: 30,
          ),

          const SizedBox(height: 20),

          // ─── Grade Level ──────────────────
          Text('Grade Level',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<GradeLevel?>(
            initialValue: _selectedGradeLevel,
            decoration: InputDecoration(
              hintText: 'Select grade level',
              prefixIcon: const Icon(Icons.school_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: hc.surface,
            ),
            items: [
              const DropdownMenuItem<GradeLevel?>(
                child: Text('Not set'),
              ),
              ...GradeLevel.values.map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g.label),
                  )),
            ],
            onChanged: (value) {
              setState(() => _selectedGradeLevel = value);
              _onChanged();
            },
          ),

          const SizedBox(height: 20),

          // ─── Section ──────────────────────
          Text('Section / Class',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _sectionController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g., Section A, Rose',
              prefixIcon: const Icon(Icons.group_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: hc.surface,
            ),
            maxLength: 30,
          ),

          const SizedBox(height: 20),

          // ─── Birth Date ───────────────────
          Text('Birth Date',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedBirthDate ?? DateTime(2015),
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedBirthDate = picked);
                _onChanged();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hc.textSecondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: hc.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    _selectedBirthDate != null
                        ? '${_selectedBirthDate!.month}/${_selectedBirthDate!.day}/${_selectedBirthDate!.year}'
                        : 'Not set',
                    style: AppTypography.bodyMedium.copyWith(
                      color: _selectedBirthDate != null
                          ? hc.textPrimary
                          : hc.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedBirthDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedBirthDate = null);
                        _onChanged();
                      },
                      child: Icon(Icons.clear_rounded,
                          size: 20, color: hc.textSecondary),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ─── Tags ─────────────────────────
          Text('Tags',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Add custom labels to organize students',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    prefixIcon: const Icon(Icons.label_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: hc.surface,
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addTag,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _tags
                  .map((tag) => Chip(
                        label: Text(tag),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () {
                          setState(() => _tags.remove(tag));
                          _onChanged();
                        },
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),

          // ─── Disability Type ──────────────
          Text('Accessibility Profile',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Changing this will offer to auto-configure accessibility settings',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          ...DisabilityType.values.map((dt) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _DisabilityTile(
                  type: dt,
                  isSelected: dt == _selectedDisability,
                  onTap: () {
                    setState(() => _selectedDisability = dt);
                    _onChanged();
                  },
                ),
              )),

          const SizedBox(height: 20),

          // ─── PIN Protection ───────────────
          Text('PIN Protection',
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _hasPinOriginal
                ? 'This profile is PIN-protected'
                : 'Add a 4-digit PIN to protect this profile',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_hasPinOriginal && !_removingPin)
            // Show option to remove existing PIN
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _removingPin = true);
                _onChanged();
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Remove PIN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            )
          else if (_removingPin)
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18,
                    color: AppColors.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('PIN will be removed when you save'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _removingPin = false);
                    _onChanged();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            )
          else ...[
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
                _onChanged();
              },
              title: Text('Enable PIN lock',
                  style: AppTypography.bodyMedium),
              secondary: Icon(
                _enablePin
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                color: _enablePin ? hc.primary : hc.textHint,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            if (_enablePin) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                  prefixIcon: const Icon(Icons.pin_rounded),
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: hc.surface,
                ),
                onChanged: (_) => _onChanged(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinConfirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm PIN',
                  prefixIcon: const Icon(Icons.pin_rounded),
                  counterText: '',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: hc.surface,
                ),
                onChanged: (_) => _onChanged(),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // ─── Role Display (read-only) ─────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  profile.role.icon,
                  color: hc.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role',
                          style: AppTypography.labelSmall
                              .copyWith(color: hc.textSecondary)),
                      Text(profile.role.label,
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text('Cannot be changed',
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DisabilityTile extends StatelessWidget {
  final DisabilityType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _DisabilityTile({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: '${type.label}${isSelected ? ', selected' : ''}',
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? type.color.withValues(alpha: 0.12)
                : hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? type.color : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(type.description,
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: type.color),
            ],
          ),
        ),
      ),
    );
  }
}
