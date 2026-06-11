import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/review_reminder_service.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/animated_dialogs.dart';
import '../../../widgets/app_back_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Cap the form width on tablets so it doesn't sprawl across the
    // full landscape viewport (1600+ dp). [maxContentWidth] returns
    // `double.infinity` on phones so this is a no-op there.
    final maxWidth = context.maxContentWidth;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppLocalizations.of(context)?.settings ?? 'Settings'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
          // ─── Profile Section ───────────────
          _SectionHeader(title: AppLocalizations.of(context)?.profile ?? 'Profile'),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Profile: ${profile?.name ?? 'No profile'}, '
                '${profile?.role.label ?? 'unknown role'}. '
                'Tap switch to change profile.',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HCColor.of(context).surface,
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Avatar + name on the first row; the action buttons sit in a
              // Wrap below so they flow to a second line instead of pushing the
              // row past its width on a narrow tablet / large font scale.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(profile: profile, fontSize: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.name ?? 'No profile',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              profile?.role.label ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: HCColor.of(context).textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/edit-profile'),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/profile-switcher'),
                        child: const Text('Switch'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _showSetPinDialog(context, ref, profile),
                        child: Text(profile?.hasPinProtection == true
                            ? '🔒 PIN'
                            : '🔓 Set PIN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),

          const SizedBox(height: 28),

          // ─── Accessibility Section ─────────
          _SectionHeader(title: AppLocalizations.of(context)?.accessibility ?? 'Accessibility'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.contrast,
            title: AppLocalizations.of(context)?.highContrastMode ?? 'High Contrast Mode',
            subtitle: 'Bolder colors & thicker borders',
            trailing: Switch.adaptive(
              value: settings.highContrastMode,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => settingsNotifier.update(
                settings.copyWith(highContrastMode: v, darkMode: v ? false : settings.darkMode),
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: AppLocalizations.of(context)?.darkMode ?? 'Dark Mode',
            subtitle: 'Easier on the eyes in low light',
            trailing: Switch.adaptive(
              value: settings.darkMode,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => settingsNotifier.update(
                settings.copyWith(darkMode: v, highContrastMode: v ? false : settings.highContrastMode),
              ),
            ),
          ),

          // Dyslexia-friendly theme is an exclusive accessibility mode
          // (cream surfaces + Lexend font + extra letter-spacing), so
          // turning it on disables high-contrast and dark mode which
          // would otherwise override its palette.
          _SettingsTile(
            icon: Icons.menu_book_rounded,
            title: AppLocalizations.of(context)?.dyslexiaMode ?? 'Dyslexia-friendly',
            subtitle: 'Cream background, Lexend font, wider letter spacing',
            trailing: Switch.adaptive(
              value: settings.dyslexiaMode,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => settingsNotifier.update(
                settings.copyWith(
                  dyslexiaMode: v,
                  highContrastMode: v ? false : settings.highContrastMode,
                  darkMode: v ? false : settings.darkMode,
                ),
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.text_fields_rounded,
            title: AppLocalizations.of(context)?.fontSize ?? 'Font Size',
            subtitle: _fontSizeLabel(settings.fontScale),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.fontScale,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                label: '${(settings.fontScale * 100).round()}%',
                onChanged: (v) =>
                    settingsNotifier.update(settings.copyWith(fontScale: v)),
              ),
            ),
          ),

          // Quick size presets
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _SizePresetButton(
                  label: 'S',
                  isActive: settings.fontScale <= 0.85,
                  onTap: () => settingsNotifier.update(
                    settings.copyWith(fontScale: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
                _SizePresetButton(
                  label: 'M',
                  isActive:
                      settings.fontScale > 0.85 && settings.fontScale <= 1.05,
                  onTap: () => settingsNotifier.update(
                    settings.copyWith(fontScale: 1.0),
                  ),
                ),
                const SizedBox(width: 8),
                _SizePresetButton(
                  label: 'L',
                  isActive:
                      settings.fontScale > 1.05 && settings.fontScale <= 1.25,
                  onTap: () => settingsNotifier.update(
                    settings.copyWith(fontScale: 1.2),
                  ),
                ),
                const SizedBox(width: 8),
                _SizePresetButton(
                  label: 'XL',
                  isActive: settings.fontScale > 1.25,
                  onTap: () => settingsNotifier.update(
                    settings.copyWith(fontScale: 1.5),
                  ),
                ),
              ],
            ),
          ),

          _SettingsTile(
            icon: Icons.animation_rounded,
            title: AppLocalizations.of(context)?.reducedMotion ?? 'Reduced Motion',
            subtitle: 'Minimize animations',
            trailing: Switch.adaptive(
              value: settings.reducedMotion,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(reducedMotion: v)),
            ),
          ),

          _SettingsTile(
            icon: Icons.record_voice_over_rounded,
            title: 'Voice-Guided Navigation',
            subtitle: settings.voiceNavigation
                ? 'Announces screens & buttons aloud'
                : 'Enable for visually impaired users',
            trailing: Switch.adaptive(
              value: settings.voiceNavigation,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(voiceNavigation: v)),
            ),
          ),

          _SettingsTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Adaptive Difficulty',
            subtitle: settings.adaptiveDifficulty
                ? 'Auto-suggests difficulty based on progress'
                : 'Manual difficulty selection only',
            trailing: Switch.adaptive(
              value: settings.adaptiveDifficulty,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(adaptiveDifficulty: v)),
            ),
          ),

          const SizedBox(height: 28),

          // ─── Audio Section ─────────────────
          _SectionHeader(title: AppLocalizations.of(context)?.audio ?? 'Audio'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.record_voice_over_rounded,
            title: AppLocalizations.of(context)?.textToSpeech ?? 'Text-to-Speech',
            subtitle: 'Hear words spoken aloud',
            trailing: Switch.adaptive(
              value: settings.ttsEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(ttsEnabled: v)),
            ),
          ),

          _SettingsTile(
            icon: Icons.speed_rounded,
            title: AppLocalizations.of(context)?.speechSpeed ?? 'Speech Speed',
            subtitle: _speedLabel(settings.ttsSpeed),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: settings.ttsSpeed,
                min: 0.3,
                divisions: 7,
                label: _speedLabel(settings.ttsSpeed),
                onChanged: settings.ttsEnabled
                    ? (v) => settingsNotifier.update(
                        settings.copyWith(ttsSpeed: v),
                      )
                    : null,
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.volume_up_rounded,
            title: AppLocalizations.of(context)?.soundEffects ?? 'Sound Effects',
            subtitle: 'Game sounds & feedback',
            trailing: Switch.adaptive(
              value: settings.soundEffects,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(soundEffects: v)),
            ),
          ),

          _SettingsTile(
            icon: Icons.mic_rounded,
            title: 'Speech-to-Text',
            subtitle: settings.speechToText
                ? 'Voice input enabled in games'
                : 'Tap to enable voice input for games',
            trailing: Switch.adaptive(
              value: settings.speechToText,
              activeTrackColor: AppColors.primary,
              onChanged: (v) =>
                  settingsNotifier.update(settings.copyWith(speechToText: v)),
            ),
          ),

          const SizedBox(height: 28),

          // ─── Language Section ──────────────
          _SectionHeader(title: AppLocalizations.of(context)?.language ?? 'Language'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.language_rounded,
            title: AppLocalizations.of(context)?.language ?? 'App Language',
            subtitle: settings.locale == 'fil' ? 'Filipino' : 'English',
            trailing: DropdownButton<String>(
              value: settings.locale,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fil', child: Text('Filipino')),
              ],
              onChanged: (v) {
                if (v != null) {
                  settingsNotifier.updateLocale(v);
                }
              },
            ),
          ),

          const SizedBox(height: 28),

          // ─── Reminders Section ─────────────
          _SectionHeader(title: AppLocalizations.of(context)?.reminders ?? 'Reminders'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.notifications_active_rounded,
            title: AppLocalizations.of(context)?.dailyReminder ?? 'Daily Reminder',
            subtitle: settings.notificationsEnabled
                ? _formatTime(settings.reminderHour, settings.reminderMinute)
                : 'Off',
            trailing: Switch.adaptive(
              value: settings.notificationsEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (v) async {
                if (v) {
                  final granted = await NotificationService.requestPermission();
                  if (!granted) return;
                  settingsNotifier.update(
                    settings.copyWith(notificationsEnabled: true),
                  );
                  await NotificationService.scheduleDailyReminder(
                    hour: settings.reminderHour,
                    minute: settings.reminderMinute,
                  );
                } else {
                  settingsNotifier.update(
                    settings.copyWith(notificationsEnabled: false),
                  );
                  await NotificationService.cancelDailyReminder();
                }
              },
            ),
          ),

          if (settings.notificationsEnabled)
            _SettingsTile(
              icon: Icons.access_time_rounded,
              title: AppLocalizations.of(context)?.reminderTime ?? 'Reminder Time',
              subtitle: _formatTime(settings.reminderHour, settings.reminderMinute),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute,
                    ),
                  );
                  if (picked != null) {
                    settingsNotifier.updateReminderTime(picked.hour, picked.minute);
                    await NotificationService.scheduleDailyReminder(
                      hour: picked.hour,
                      minute: picked.minute,
                    );
                  }
                },
                child: const Text('Change'),
              ),
            ),

          // Vocabulary Review Reminder
          if (settings.notificationsEnabled)
            _SettingsTile(
              icon: Icons.psychology_rounded,
              title: 'Vocab Review Reminder',
              subtitle: settings.vocabReviewEnabled
                  ? 'Reminds you to review weak words'
                  : 'Off',
              trailing: Switch.adaptive(
                value: settings.vocabReviewEnabled,
                activeTrackColor: const Color(0xFF7C4DFF),
                onChanged: (v) async {
                  settingsNotifier.update(
                    settings.copyWith(vocabReviewEnabled: v),
                  );
                  if (profile != null) {
                    await ReviewReminderService.scheduleIfNeeded(
                      profileId: profile.id,
                      enabled: v,
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute,
                    );
                  }
                },
              ),
            ),

          const SizedBox(height: 28),

          // ─── Backup & Restore Section ──────
          const _SectionHeader(title: 'Data'),
          const SizedBox(height: 8),

          // Cloud Sync
          const SyncStatusWidget(),
          const SizedBox(height: 4),

          _SettingsTile(
            icon: Icons.backup_rounded,
            title: 'Backup & Restore',
            subtitle: 'Save or restore all app data',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => context.push('/backup'),
            ),
          ),

          _SettingsTile(
            icon: Icons.vpn_key_rounded,
            title: 'Cloud Recovery Code',
            subtitle: 'Restore this profile on a new device',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => context.push('/recovery/show'),
            ),
          ),

          if (profile?.role == UserRole.teacher || profile?.role == UserRole.parent)
            _SettingsTile(
              icon: Icons.cloud_sync_rounded,
              title: 'Backup & Link Account',
              subtitle: 'Sign in with email to restore on any device',
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: () => context.push('/backup-account'),
              ),
            ),

          _SettingsTile(
            icon: Icons.cast_for_education_rounded,
            title: 'Classroom Mode',
            subtitle: 'Monitor all students in real time',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => context.push('/classroom'),
            ),
          ),

          _SettingsTile(
            icon: Icons.accessibility_new_rounded,
            title: 'Re-run Accessibility Setup',
            subtitle: 'Restart the accessibility wizard',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: () => context.push('/accessibility-setup'),
            ),
          ),

          if (profile?.role == UserRole.teacher || profile?.role == UserRole.parent)
            _SettingsTile(
              icon: Icons.family_restroom_rounded,
              title: 'Parental Controls',
              subtitle: 'Set time limits & content restrictions',
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onPressed: () => context.push('/parental-controls'),
              ),
            ),

          if (profile?.role == UserRole.teacher || profile?.role == UserRole.parent)
            const _TelemetryToggle(),

          _SettingsTile(
            icon: Icons.replay_rounded,
            title: 'Replay Tutorials',
            subtitle: 'Show tutorial guides again on all screens',
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () async {
                final profile = ref.read(profileProvider);
                if (profile != null) {
                  await HiveService.resetAllTutorials(profile.id);
                  if (context.mounted) {
                    AppSnackBar.success(context, message: 'Tutorials will appear again on each screen!');
                  }
                }
              },
            ),
          ),

          const SizedBox(height: 28),

          // ─── About Section ─────────────────
          _SectionHeader(title: AppLocalizations.of(context)?.about ?? 'About'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: AppLocalizations.of(context)?.flashLearnPwd ?? 'FlashLearn PWD',
            subtitle: AppLocalizations.of(context)?.version ?? 'Version 1.0.0 • Thesis Capstone Project',
            trailing: const SizedBox.shrink(),
          ),

          const _SettingsTile(
            icon: Icons.school_rounded,
            title: 'Purpose',
            subtitle:
                'Interactive vocabulary building app for PWD students using flashcards, games, and Filipino Sign Language.',
            trailing: SizedBox.shrink(),
          ),

          const SizedBox(height: 40),

          // ─── Reset button ──────────────────
          Center(
            child: TextButton.icon(
              onPressed: () => _showResetDialog(context, ref),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: Text(
                AppLocalizations.of(context)?.resetAllData ?? 'Reset All Data',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),

          const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _fontSizeLabel(double v) {
    if (v <= 0.85) return 'Small';
    if (v <= 1.05) return 'Normal';
    if (v <= 1.25) return 'Large';
    return 'Extra Large';
  }

  String _speedLabel(double v) {
    if (v <= 0.4) return 'Very Slow';
    if (v <= 0.6) return 'Slow';
    if (v <= 0.8) return 'Normal';
    return 'Fast';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showAnimatedDialog(
      context,
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)?.confirmResetTitle ?? 'Reset All Data?'),
        content: Text(
          AppLocalizations.of(context)?.confirmResetMessage ?? 'This will clear your profile, progress, and all custom flashcards. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear ALL Hive data (profiles, progress, custom cards, settings)
              await HiveService.clearAllData();
              // Reset settings provider to defaults
              ref.read(settingsProvider.notifier).update(const AppSettings());
              // Clear profile provider
              ref.read(profileProvider.notifier).clearProfile();
              if (context.mounted) context.go('/profile');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)?.reset ?? 'Reset'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// PIN Setup Dialog
// ────────────────────────────────────────
Future<void> _showSetPinDialog(
    BuildContext context, WidgetRef ref, UserProfile? profile) async {
  if (profile == null) return;

  final result = await showAnimatedDialog<String?>(
    context,
    child: _SetPinDialog(
      hasExistingPin: profile.hasPinProtection,
    ),
  );

  if (result == null) return; // cancelled

  // result == '' means remove PIN, otherwise set new PIN.
  String? newRecoveryCode;
  UserProfile newProfile;
  if (result.isEmpty) {
    newProfile = PinCredentialHelper.clearPin(profile);
  } else {
    final applied = PinCredentialHelper.applyPin(profile, result);
    newProfile = applied.profile;
    newRecoveryCode = applied.recoveryCode;
  }
  await ref.read(profileProvider.notifier).setProfile(newProfile);

  if (!context.mounted) return;
  AppSnackBar.success(context,
      message: result.isEmpty ? 'PIN removed' : 'PIN set successfully!');
  if (newRecoveryCode != null) {
    final code = newRecoveryCode;
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
}

class _SetPinDialog extends StatefulWidget {
  final bool hasExistingPin;
  const _SetPinDialog({required this.hasExistingPin});

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasExistingPin ? 'Change PIN' : 'Set Profile PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a 4-digit PIN to protect your profile.'),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter PIN',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm PIN',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style:
                    AppTypography.labelSmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
      actions: [
        if (widget.hasExistingPin)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''), // remove PIN
            child: const Text('Remove PIN',
                style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // cancel
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set PIN'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────
// Section Header
// ────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: AppTypography.labelMedium.copyWith(
                color: HCColor.of(context).textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────
// Settings Tile
// ────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HCColor.of(context).border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HCColor.of(context).primaryLight,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HCColor.of(context).primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: HCColor.of(context).primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ────────────────────────────────────────
// Telemetry Opt-In Toggle (Crashlytics + Analytics)
// ────────────────────────────────────────
//
// Default OFF. Parent-gated (only mounted when the active profile is
// teacher / parent — see the conditional in [SettingsScreen.build]).
// When the user toggles this, [AnalyticsService.setOptIn] persists the
// flag in Hive AND flips Firebase's live collection-enabled state so the
// change takes effect without a restart.
//
// Ethics note: Because the user base includes children and PWD users,
// the consent flow is explicit and parent-only. Document this in the
// thesis methodology chapter.
class _TelemetryToggle extends StatefulWidget {
  const _TelemetryToggle();

  @override
  State<_TelemetryToggle> createState() => _TelemetryToggleState();
}

class _TelemetryToggleState extends State<_TelemetryToggle> {
  late bool _enabled = AnalyticsService.isOptIn;

  Future<void> _set(bool value) async {
    setState(() => _enabled = value);
    await AnalyticsService.setOptIn(value);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.insights_rounded,
      title: 'Help improve the app',
      subtitle: _enabled
          ? 'Sending anonymous crash & usage data to the research team'
          : 'Off — no data leaves this device',
      trailing: Switch.adaptive(
        value: _enabled,
        activeTrackColor: AppColors.primary,
        onChanged: _set,
      ),
    );
  }
}

// ────────────────────────────────────────
// Size Preset Button
// ────────────────────────────────────────
class _SizePresetButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SizePresetButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Set font size to $label',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : HCColor.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? AppColors.primary : HCColor.of(context).border,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: isActive ? Colors.white : HCColor.of(context).textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
