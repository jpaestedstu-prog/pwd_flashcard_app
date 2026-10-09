import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/review_reminder_service.dart';
import '../../../core/constants/distribution.dart';
import '../../gamepad/services/gamepad_service.dart';
import '../../../core/services/update_check_service.dart';
import '../../../widgets/update_available_card.dart' show openUpdatePage;
import '../../../data/local/hive_service.dart';
import '../../../data/local/local_repository.dart';
import '../../../navigation/app_router.dart' show rootNavigatorKey;
import '../../../widgets/adult_gate_dialog.dart' show requireAdult;
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/fullscreen_provider.dart';
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

    // Teacher / Parent are monitoring-only roles: they review student progress
    // via the Dashboard, Analytics, and Reports rather than using the learning
    // features themselves. So the learner-focused settings (Learning Modes,
    // game/flashcard Audio, study Reminders, Adaptive Difficulty, Gaze Control,
    // the accessibility setup wizard, and tutorial replays) are hidden for them.
    // Display accessibility (contrast, font size, etc.), language, data/backup,
    // and the monitoring tools below remain available.
    final isMonitor =
        profile?.role == UserRole.teacher || profile?.role == UserRole.parent;

    // Player profiles own their My Day; Students and Children do not, because
    // theirs is set by a Teacher or Parent and can hold the device at each
    // step. A switch that let a supervised learner turn that off would be a
    // switch that unlocks their own lock — see [routineFeatureProvider].
    // A guest Player is excluded: nothing they do is kept past the session,
    // so there is no day for them to plan and no switch worth offering.
    final isPlayer =
        profile?.role == UserRole.player && !(profile?.isGuestPlayer ?? false);

    // Watched (not read) so the switch below tracks the mode even when it is
    // turned off from a collapsed app bar elsewhere in the app.
    final fullscreen = ref.watch(fullscreenModeProvider);

    // Cap the form width on tablets so it doesn't sprawl across the
    // full landscape viewport (1600+ dp). [maxContentWidth] returns
    // `double.infinity` on phones so this is a no-op there.
    final maxWidth = context.maxContentWidth;

    // Nullable on purpose: every string below keeps its English
    // fallback, so a widget test without the delegate still renders.
    final l10n = AppLocalizations.of(context);

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
              _SectionHeader(
                title: AppLocalizations.of(context)?.profile ?? 'Profile',
              ),
              const SizedBox(height: 8),
              Semantics(
                label: (l10n ?? AppLocalizationsEn()).setProfileSemantics(
                  profile?.name ?? (l10n ?? AppLocalizationsEn()).setNoProfile,
                  profile?.role.labelOf(l10n) ??
                      (l10n ?? AppLocalizationsEn()).setUnknownRole,
                ),
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
                                  profile?.profileTypeLabelOf(l10n) ?? '',
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
                            child: Text(AppLocalizations.of(context)?.edit ?? 'Edit'),
                          ),
                          TextButton(
                            onPressed: () => context.push('/profile-switcher'),
                            child: Text(
                              AppLocalizations.of(context)?.switchProfile ??
                                  'Switch',
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showSetPinDialog(context, ref, profile),
                            child: Text(
                              profile?.hasPinProtection == true
                                  ? '🔒 PIN'
                                  : '🔓 ${AppLocalizations.of(context)?.setPin ?? 'Set PIN'}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),

              const SizedBox(height: 28),

              // ─── Accessibility Section ─────────
              _SectionHeader(
                title:
                    AppLocalizations.of(context)?.accessibility ??
                    'Accessibility',
              ),
              const SizedBox(height: 8),

              _SettingsTile(
                icon: Icons.contrast,
                title:
                    AppLocalizations.of(context)?.highContrastMode ??
                    'High Contrast Mode',
                subtitle: l10n?.settingHighContrastDesc ??
                      'Bolder colors & thicker borders',
                onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(
                      highContrastMode: v,
                      darkMode: v ? false : settings.darkMode,
                    ),
                  ))(!(settings.highContrastMode)),
                toggled: settings.highContrastMode,
                trailing: Switch.adaptive(
                  value: settings.highContrastMode,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => settingsNotifier.update(
                    settings.copyWith(
                      highContrastMode: v,
                      darkMode: v ? false : settings.darkMode,
                    ),
                  ),
                ),
              ),

              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                title: AppLocalizations.of(context)?.darkMode ?? 'Dark Mode',
                subtitle: l10n?.settingDarkModeDesc ??
                      'Easier on the eyes in low light',
                onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(
                      darkMode: v,
                      highContrastMode: v ? false : settings.highContrastMode,
                    ),
                  ))(!(settings.darkMode)),
                toggled: settings.darkMode,
                trailing: Switch.adaptive(
                  value: settings.darkMode,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => settingsNotifier.update(
                    settings.copyWith(
                      darkMode: v,
                      highContrastMode: v ? false : settings.highContrastMode,
                    ),
                  ),
                ),
              ),

              // Dyslexia-friendly theme is an exclusive accessibility mode
              // (cream surfaces + Lexend font + extra letter-spacing), so
              // turning it on disables high-contrast and dark mode which
              // would otherwise override its palette.
              _SettingsTile(
                icon: Icons.menu_book_rounded,
                title:
                    AppLocalizations.of(context)?.dyslexiaMode ??
                    'Dyslexia-friendly',
                subtitle: l10n?.settingDyslexiaDesc ??
                      'Cream background, Lexend font, wider letter spacing',
                onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(
                      dyslexiaMode: v,
                      highContrastMode: v ? false : settings.highContrastMode,
                      darkMode: v ? false : settings.darkMode,
                    ),
                  ))(!(settings.dyslexiaMode)),
                toggled: settings.dyslexiaMode,
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
                subtitle: _fontSizeLabel(l10n, settings.fontScale),
                trailing: SizedBox(
                  width: 150,
                  child: Slider(
                    value: settings.fontScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label: '${(settings.fontScale * 100).round()}%',
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(fontScale: v),
                    ),
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
                          settings.fontScale > 0.85 &&
                          settings.fontScale <= 1.05,
                      onTap: () => settingsNotifier.update(
                        settings.copyWith(fontScale: 1.0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SizePresetButton(
                      label: 'L',
                      isActive:
                          settings.fontScale > 1.05 &&
                          settings.fontScale <= 1.25,
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
                title:
                    AppLocalizations.of(context)?.reducedMotion ??
                    'Reduced Motion',
                subtitle: l10n?.settingReducedMotionDesc ??
                      'Minimize animations',
                onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(reducedMotion: v),
                  ))(!(settings.reducedMotion)),
                toggled: settings.reducedMotion,
                trailing: Switch.adaptive(
                  value: settings.reducedMotion,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => settingsNotifier.update(
                    settings.copyWith(reducedMotion: v),
                  ),
                ),
              ),

              _SettingsTile(
                icon: Icons.record_voice_over_rounded,
                title: l10n?.voiceNavigation ?? 'Voice-Guided Navigation',
                subtitle: settings.voiceNavigation
                    ? l10n?.settingVoiceNavOnDesc ??
                      'Announces screens & buttons aloud'
                    : l10n?.settingVoiceNavOffDesc ??
                      'Enable for visually impaired users',
                onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(voiceNavigation: v),
                  ))(!(settings.voiceNavigation)),
                toggled: settings.voiceNavigation,
                trailing: Switch.adaptive(
                  value: settings.voiceNavigation,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => settingsNotifier.update(
                    settings.copyWith(voiceNavigation: v),
                  ),
                ),
              ),

              // The Voice-Guided Mode screen — its own settings plus a spoken
              // tour of the app — had no entry point anywhere, so the people it
              // was built for could not reach it. Shown only once the feature
              // is on, so it does not clutter the list for everyone else.
              if (settings.voiceNavigation)
                _SettingsTile(
                  icon: Icons.headset_mic_rounded,
                  title: _t(context).setVoiceTour,
                  subtitle: _t(context).setVoiceTourSub,
                  onTap: () => context.push('/voice-guided'),
                ),

              if (!isMonitor)
                _SettingsTile(
                  icon: Icons.auto_awesome_rounded,
                  title: l10n?.adaptiveDifficulty ?? 'Adaptive Difficulty',
                  subtitle: settings.adaptiveDifficulty
                      ? l10n?.settingAdaptiveOnDesc ??
                      'Auto-suggests difficulty based on progress'
                      : l10n?.settingAdaptiveOffDesc ??
                      'Manual difficulty selection only',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(adaptiveDifficulty: v),
                    ))(!(settings.adaptiveDifficulty)),
                  toggled: settings.adaptiveDifficulty,
                  trailing: Switch.adaptive(
                    value: settings.adaptiveDifficulty,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(adaptiveDifficulty: v),
                    ),
                  ),
                ),

              // Hands-free control belongs with the other accessibility settings.
              // It used to sit at the bottom of "Data", below Cloud Sync and
              // Backup & Restore — the learners who most need it were the least
              // likely to scroll that far, and nothing about it is a data setting.
              _SettingsTile(
                icon: Icons.remove_red_eye_rounded,
                title: l10n?.settingGazeControlTitle ?? 'Gaze Control (Preview)',
                subtitle: l10n?.settingGazeControlDesc ??
                      'Hands-free: move your head or blink to select',
                onTap: () => context.push('/gaze-settings'),
              ),

              // Bluetooth game controller. Sits next to Gaze Control because
              // it answers the same question — how does a learner who cannot
              // use the touchscreen drive the app — with different hardware.
              // Android only for now: the controller bridge is GamepadBridge.kt.
              if (GamepadService.isSupported)
                _SettingsTile(
                  icon: Icons.sports_esports_rounded,
                  title: l10n?.settingGamepadTitle ?? 'Game Controller',
                  subtitle: l10n?.settingGamepadDesc ??
                        'Navigate by Bluetooth gamepad, with spoken feedback',
                  onTap: () => context.push('/gamepad-settings'),
                ),

              const SizedBox(height: 28),

              // ─── Presentation Section ──────────
              // Educator-only. Fullscreen describes how the *device* is being used
              // right now — propped in front of a class, or mirrored to a TV — so
              // it is the Teacher / Parent setting up the session who turns it on,
              // not the learner. Unlike everything else on this screen it is not
              // persisted: see [fullscreenModeProvider] for why a presentation
              // mode that survived a restart would be a bug, not a feature.
              if (isMonitor) ...[
                _SectionHeader(
                  title: l10n?.settingSectionPresentation ??
                      'Presentation',
                ),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.fullscreen_rounded,
                  title:
                      AppLocalizations.of(context)?.fslFullscreen ??
                      'Fullscreen',
                  subtitle: fullscreen
                      ? l10n?.settingFullscreenOnDesc ??
                      'Nav bar hidden, app bars collapsed — until you turn it off'
                      : l10n?.settingFullscreenOffDesc ??
                      'Hide the nav bar and app bars for class or TV display',
                  onTap: () => ((v) =>
                        ref.read(fullscreenModeProvider.notifier).state = v)(!(fullscreen)),
                  toggled: fullscreen,
                  trailing: Switch.adaptive(
                    value: fullscreen,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) =>
                        ref.read(fullscreenModeProvider.notifier).state = v,
                  ),
                ),

                const SizedBox(height: 28),
              ],

              // ─── Learning Modes Section ────────
              // Learner-only — hidden for Teacher / Parent monitoring profiles.
              if (!isMonitor) ...[
                _SectionHeader(
                  title: l10n?.settingSectionLearningModes ??
                      'Learning Modes',
                ),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.slow_motion_video_rounded,
                  title: l10n?.settingSlowMotionTitle ?? 'Slow-Motion Mode',
                  subtitle: settings.slowMotionEnabled
                      ? l10n?.settingSlowMotionOnDesc ??
                      'Games & flashcards animate at half speed'
                      : l10n?.settingSlowMotionOffDesc ??
                      'Slow gameplay & flashcard animations down',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(slowMotionEnabled: v),
                    ))(!(settings.slowMotionEnabled)),
                  toggled: settings.slowMotionEnabled,
                  trailing: Switch.adaptive(
                    value: settings.slowMotionEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(slowMotionEnabled: v),
                    ),
                  ),
                ),

                _SettingsTile(
                  icon: Icons.support_rounded,
                  title: l10n?.settingLearningAssistTitle ?? 'Learning Assist',
                  subtitle: settings.learningAssistEnabled
                      ? l10n?.settingLearningAssistOnDesc ??
                      'Shows “why” hints and a 50/50 helper in quizzes'
                      : l10n?.settingLearningAssistOffDesc ??
                      'Plain quizzes — no hints or explanations',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(learningAssistEnabled: v),
                    ))(!(settings.learningAssistEnabled)),
                  toggled: settings.learningAssistEnabled,
                  trailing: Switch.adaptive(
                    value: settings.learningAssistEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(learningAssistEnabled: v),
                    ),
                  ),
                ),

                _SettingsTile(
                  icon: Icons.flag_rounded,
                  title: l10n?.settingDailyMissionTitle ?? 'Daily Mission Size',
                  subtitle: l10n?.settingDailyMissionDesc(settings.dailyMissionSize) ??
                      '${settings.dailyMissionSize} words per day',
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.dailyMissionSize.clamp(3, 5).toDouble(),
                      min: 3,
                      max: 5,
                      divisions: 2,
                      label: '${settings.dailyMissionSize}',
                      onChanged: (v) =>
                          settingsNotifier.setDailyMissionSize(v.round()),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],

              // ─── Audio Section ─────────────────
              // Game / flashcard audio — learner-only, hidden for monitoring roles.
              if (!isMonitor) ...[
                _SectionHeader(
                  title: AppLocalizations.of(context)?.audio ?? 'Audio',
                ),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.record_voice_over_rounded,
                  title:
                      AppLocalizations.of(context)?.textToSpeech ??
                      'Text-to-Speech',
                  subtitle: l10n?.settingTtsDesc ??
                      'Hear words spoken aloud',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(ttsEnabled: v),
                    ))(!(settings.ttsEnabled)),
                  toggled: settings.ttsEnabled,
                  trailing: Switch.adaptive(
                    value: settings.ttsEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(ttsEnabled: v),
                    ),
                  ),
                ),

                _SettingsTile(
                  icon: Icons.speed_rounded,
                  title:
                      AppLocalizations.of(context)?.speechSpeed ??
                      'Speech Speed',
                  subtitle: _speedLabel(l10n, settings.ttsSpeed),
                  // Four bucket names spread over eight stops, so the bucket
                  // alone cannot tell a learner their press registered.
                  semanticsValue: _speedSpoken(l10n, settings.ttsSpeed),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.ttsSpeed,
                      min: 0.3,
                      divisions: 7,
                      label: _speedLabel(l10n, settings.ttsSpeed),
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
                  title:
                      AppLocalizations.of(context)?.soundEffects ??
                      'Sound Effects',
                  subtitle: l10n?.settingSoundEffectsDesc ??
                      'Game sounds & feedback',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(soundEffects: v),
                    ))(!(settings.soundEffects)),
                  toggled: settings.soundEffects,
                  trailing: Switch.adaptive(
                    value: settings.soundEffects,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(soundEffects: v),
                    ),
                  ),
                ),

                _SettingsTile(
                  icon: Icons.mic_rounded,
                  title: l10n?.speechToText ?? 'Speech-to-Text',
                  subtitle: settings.speechToText
                      ? l10n?.settingSttOnDesc ??
                      'Voice input enabled in games'
                      : l10n?.settingSttOffDesc ??
                      'Tap to enable voice input for games',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(speechToText: v),
                    ))(!(settings.speechToText)),
                  toggled: settings.speechToText,
                  trailing: Switch.adaptive(
                    value: settings.speechToText,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(speechToText: v),
                    ),
                  ),
                ),

                _SettingsTile(
                  icon: Icons.smart_toy_rounded,
                  title: l10n?.settingCompanionTitle ?? 'AI Companion',
                  subtitle: settings.aiCompanionEnabled
                      ? l10n?.settingCompanionOnDesc ??
                      'Floating buddy — tap it any time for help'
                      : l10n?.settingCompanionOffDesc ??
                      'Turn on your floating learning buddy',
                  onTap: () => ((v) => settingsNotifier.update(
                      settings.copyWith(aiCompanionEnabled: v),
                    ))(!(settings.aiCompanionEnabled)),
                  toggled: settings.aiCompanionEnabled,
                  trailing: Switch.adaptive(
                    value: settings.aiCompanionEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(aiCompanionEnabled: v),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],

              // ─── My Day Section (Player profiles only) ──
              if (isPlayer) ...[
                _SectionHeader(title: l10n?.settingSectionMyDay ?? 'My Day'),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.event_note_rounded,
                  title: l10n?.settingRoutineTitle ?? 'Routine',
                  subtitle: settings.routineEnabled
                      ? l10n?.settingRoutineOnDesc ??
                            'My Day shows on your home — plan your day, '
                                'step by step'
                      : l10n?.settingRoutineOffDesc ??
                            'Turn on My Day to plan your day, step by step',
                  onTap: () => ((v) => settingsNotifier.update(
                    settings.copyWith(routineEnabled: v),
                  ))(!(settings.routineEnabled)),
                  toggled: settings.routineEnabled,
                  trailing: Switch.adaptive(
                    value: settings.routineEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => settingsNotifier.update(
                      settings.copyWith(routineEnabled: v),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],

              // ─── Language Section ──────────────
              _SectionHeader(
                title: AppLocalizations.of(context)?.language ?? 'Language',
              ),
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
              // Study reminders are learner-only — hidden for monitoring roles.
              if (!isMonitor) ...[
                _SectionHeader(
                  title: AppLocalizations.of(context)?.reminders ?? 'Reminders',
                ),
                const SizedBox(height: 8),

                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  title:
                      AppLocalizations.of(context)?.dailyReminder ??
                      'Daily Reminder',
                  subtitle: settings.notificationsEnabled
                      ? _formatTime(
                          settings.reminderHour,
                          settings.reminderMinute,
                        )
                      : _t(context).apOff,
                  onTap: () => ((v) async {
                      if (v) {
                        final granted =
                            await NotificationService.requestPermission();
                        if (!granted) return;
                        settingsNotifier.update(
                          settings.copyWith(notificationsEnabled: true),
                        );
                        await NotificationService.scheduleDailyReminder(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                          filipino: settings.locale == 'fil',
                        );
                      } else {
                        settingsNotifier.update(
                          settings.copyWith(notificationsEnabled: false),
                        );
                        await NotificationService.cancelDailyReminder();
                      }
                    })(!(settings.notificationsEnabled)),
                  toggled: settings.notificationsEnabled,
                  trailing: Switch.adaptive(
                    value: settings.notificationsEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      if (v) {
                        final granted =
                            await NotificationService.requestPermission();
                        if (!granted) return;
                        settingsNotifier.update(
                          settings.copyWith(notificationsEnabled: true),
                        );
                        await NotificationService.scheduleDailyReminder(
                          hour: settings.reminderHour,
                          minute: settings.reminderMinute,
                          filipino: settings.locale == 'fil',
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
                    title:
                        AppLocalizations.of(context)?.reminderTime ??
                        'Reminder Time',
                    subtitle: _formatTime(
                      settings.reminderHour,
                      settings.reminderMinute,
                    ),
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
                          settingsNotifier.updateReminderTime(
                            picked.hour,
                            picked.minute,
                          );
                          await NotificationService.scheduleDailyReminder(
                            hour: picked.hour,
                            minute: picked.minute,
                            filipino: settings.locale == 'fil',
                          );
                        }
                      },
                      child: Text(l10n?.changeLabel ?? 'Change'),
                    ),
                  ),

                // Vocabulary Review Reminder
                if (settings.notificationsEnabled)
                  _SettingsTile(
                    icon: Icons.psychology_rounded,
                    title: l10n?.settingVocabReviewTitle ?? 'Vocab Review Reminder',
                    // Describes the setting, not its state: the switch shows
                    // that visually and `toggled` speaks it. A subtitle of
                    // "Off" made the row read "Vocab Review Reminder. Off.
                    // Off." — every other row in this screen works this way.
                    subtitle: l10n?.settingVocabReviewDesc ??
                      'Reminds you to review weak words',
                    onTap: () => ((v) async {
                        settingsNotifier.update(
                          settings.copyWith(vocabReviewEnabled: v),
                        );
                        if (profile != null) {
                          await ReviewReminderService.scheduleIfNeeded(
                            profileId: profile.id,
                            enabled: v,
                            hour: settings.reminderHour,
                            minute: settings.reminderMinute,
                            filipino: settings.locale == 'fil',
                          );
                        }
                      })(!(settings.vocabReviewEnabled)),
                    toggled: settings.vocabReviewEnabled,
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
                            filipino: settings.locale == 'fil',
                          );
                        }
                      },
                    ),
                  ),

                const SizedBox(height: 28),
              ],

              // ─── Backup & Restore Section ──────
              _SectionHeader(title: l10n?.settingSectionData ?? 'Data'),
              const SizedBox(height: 8),

              // Cloud Sync
              const SyncStatusWidget(),
              const SizedBox(height: 4),

              _SettingsTile(
                icon: Icons.backup_rounded,
                title: l10n?.settingBackupRestoreTitle ?? 'Backup & Restore',
                subtitle: l10n?.settingBackupRestoreDesc ??
                      'Save or restore all app data',
                onTap: () => context.push('/backup'),
              ),

              _SettingsTile(
                icon: Icons.vpn_key_rounded,
                title: l10n?.settingRecoveryCodeTitle ?? 'Cloud Recovery Code',
                subtitle: l10n?.settingRecoveryCodeDesc ??
                      'Restore this profile on a new device',
                onTap: () => context.push('/recovery/show'),
              ),

              if (isMonitor)
                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  title: l10n?.settingCloudAccountTitle ?? 'Backup & Link Account',
                  subtitle: l10n?.settingCloudAccountDesc ??
                      'Sign in with email to restore on any device',
                  onTap: () => context.push('/backup-account'),
                ),

              // "Classroom Mode" (real-time student monitoring + casting) is a
              // teacher/parent tool — hidden for player profiles, which focus on
              // gameplay + PWD-awareness learning.
              if (profile?.isPlayerMode != true)
                _SettingsTile(
                  icon: Icons.cast_for_education_rounded,
                  title: l10n?.classroomMode ?? 'Classroom Mode',
                  subtitle: l10n?.settingClassroomModeDesc ??
                      'Monitor all students in real time',
                  onTap: () => context.push('/classroom'),
                ),

              // Accessibility wizard & gaze input are learner-facing onboarding /
              // input aids — hidden for Teacher / Parent monitoring profiles.
              if (!isMonitor) ...[
                _SettingsTile(
                  icon: Icons.accessibility_new_rounded,
                  title: l10n?.settingAccessibilitySetupTitle ??
                      'Re-run Accessibility Setup',
                  subtitle: l10n?.settingAccessibilitySetupDesc ??
                      'Restart the accessibility wizard',
                  onTap: () => context.push('/accessibility-setup'),
                ),
              ],

              // Profile clean-up is a teacher/parent tool: it can delete any
              // other profile on this device, so learners never see it.
              if (isMonitor)
                _SettingsTile(
                  icon: Icons.manage_accounts_rounded,
                  title: l10n?.settingManageProfilesTitle ?? 'Manage Profiles',
                  subtitle: l10n?.settingManageProfilesDesc ??
                      'Delete profiles saved on this device',
                  onTap: () => context.push('/manage-profiles'),
                ),

              // Every profile saved online can be deleted by its owner, right
              // here: both app stores require it (Apple 5.1.1(v), Google
              // Play's account deletion policy). Manage Profiles only reaches
              // OTHER profiles, so a lone teacher or a player had no way.
              if (canDeleteOwnProfile(
                profile,
                viewingAsStudent:
                    ref.read(profileProvider.notifier).isViewingAsStudent,
              ))
                _SettingsTile(
                  icon: Icons.person_remove_rounded,
                  title: l10n?.deleteMyProfileTitle ?? 'Delete this profile',
                  subtitle: l10n?.deleteMyProfileDesc ??
                      'Remove it and everything saved for it, here and online',
                  onTap: () => _deleteOwnProfile(context, ref),
                ),

              if (isMonitor)
                _SettingsTile(
                  icon: Icons.family_restroom_rounded,
                  title: l10n?.settingChildControlsTitle ?? 'Parental Controls',
                  subtitle: l10n?.settingChildControlsDesc ??
                      'Set time limits & content restrictions',
                  onTap: () => context.push('/parental-controls'),
                ),

              if (isMonitor) const _TelemetryToggle(),

              // Tutorial replays are learner-facing — hidden for monitoring roles.
              if (!isMonitor)
                _SettingsTile(
                  icon: Icons.replay_rounded,
                  title: l10n?.settingReplayTutorialsTitle ?? 'Replay Tutorials',
                  subtitle: l10n?.settingReplayTutorialsDesc ??
                      'Show tutorial guides again on all screens',
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () async {
                      final profile = ref.read(profileProvider);
                      if (profile != null) {
                        await HiveService.resetAllTutorials(profile.id);
                        if (context.mounted) {
                          AppSnackBar.success(
                            context,
                            message:
                                _t(context).setTutorialsReset,
                          );
                        }
                      }
                    },
                  ),
                ),

              const SizedBox(height: 28),

              // ─── About Section ─────────────────
              _SectionHeader(
                title: AppLocalizations.of(context)?.about ?? 'About',
              ),
              const SizedBox(height: 8),

              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title:
                    AppLocalizations.of(context)?.flashLearnPwd ??
                    'FlashLearn PWD',
                subtitle: _aboutLine(
                  l10n,
                  ref.watch(installedVersionProvider).valueOrNull,
                ),
                trailing: const SizedBox.shrink(),
              ),

              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: l10n?.settingPrivacyTitle ?? 'Privacy & data',
                subtitle: l10n?.settingPrivacyDesc ??
                    'What the app saves, where it goes, and how to delete it',
                onTap: () => _openPrivacyPolicy(context, ref),
              ),

              // A website APK has nothing else to tell a tablet that a newer
              // one exists. Store copies are updated by the store, and both
              // stores forbid pointing anywhere else.
              if (Distribution.current.checksWebsiteForUpdates)
                const _UpdateCheckTile(),

              _SettingsTile(
                icon: Icons.school_rounded,
                title: l10n?.settingPurposeTitle ?? 'Purpose',
                subtitle:
                    l10n?.settingPurposeDesc ??
                      'Interactive vocabulary building app for PWD students using flashcards, games, and Filipino Sign Language.',
                trailing: const SizedBox.shrink(),
              ),

              _SettingsTile(
                icon: Icons.diversity_3_rounded,
                title:
                    AppLocalizations.of(context)?.pwdAwarenessTitle ??
                    'PWD Awareness',
                subtitle:
                    AppLocalizations.of(context)?.pwdAwarenessSubtitle ??
                    'Understanding & respecting Persons with Disabilities',
                onTap: () => context.push('/pwd-awareness'),
              ),

              const SizedBox(height: 40),

              // ─── Reset button ──────────────────
              if (canResetAllData(profile))
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showResetDialog(context, ref),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: HCColor.of(context).graphic(AppColors.error),
                    ),
                    label: Text(
                      AppLocalizations.of(context)?.resetAllData ??
                          'Reset All Data',
                      style: TextStyle(color: HCColor.of(context).errorText),
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

  String _fontSizeLabel(AppLocalizations? l10n, double v) {
    if (v <= 0.85) return l10n?.fontSizeSmall ?? 'Small';
    if (v <= 1.05) return l10n?.fontSizeNormal ?? 'Normal';
    if (v <= 1.25) return l10n?.fontSizeLarge ?? 'Large';
    return l10n?.fontSizeExtraLarge ?? 'Extra Large';
  }

  String _speedLabel(AppLocalizations? l10n, double v) {
    if (v <= 0.4) return l10n?.speechSpeedVerySlow ?? 'Very Slow';
    if (v <= 0.6) return l10n?.speechSpeedSlow ?? 'Slow';
    if (v <= 0.8) return l10n?.speechSpeedNormal ?? 'Normal';
    return l10n?.speechSpeedFast ?? 'Fast';
  }

  /// The speed as it is *spoken*: the bucket name plus the exact stop.
  ///
  /// "Slow, 4 of 8" changes on every press, which is what tells a learner
  /// driving by ear that the control answered them — and it matches the
  /// "3 of 42" counting the controller uses everywhere else.
  String _speedSpoken(AppLocalizations? l10n, double v) {
    const stops = 8; // min 0.3 … max 1.0, divisions 7
    final step = (((v - 0.3) / 0.1).round() + 1).clamp(1, stops);
    final label = _speedLabel(l10n, v);
    return l10n?.speechSpeedSpoken(label, step, stops) ??
        '$label, $step of $stops';
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Opens the privacy page in the browser. Leaving the app is a grown-up's
  /// call for a learner (requireAdult lets everyone else straight through).
  Future<void> _openPrivacyPolicy(BuildContext context, WidgetRef ref) async {
    final t = _t(context);
    final allowed = await requireAdult(
      context,
      ref,
      reason: t.settingPrivacyAdultReason,
    );
    if (!allowed || !context.mounted) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(AppConstants.privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppSnackBar.info(
        context,
        message: t.settingPrivacyOpenFailed(AppConstants.privacyPolicyUrl),
      );
    }
  }

  /// Deletes the signed-in profile, on this device and online, then leaves
  /// it. A learner's profile needs a grown-up's yes first.
  Future<void> _deleteOwnProfile(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    final t = _t(context);
    if (profile.role.isEnrollableLearner) {
      final allowed = await requireAdult(
        context,
        ref,
        reason: t.deleteMyProfileAdultReason,
      );
      if (!allowed || !context.mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteMyProfileConfirmTitle(profile.name)),
        content: Text(
          '${t.deleteMyProfileConfirmBody}'
          '${profile.role.isEducator ? t.deleteMyProfileEducatorNote : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: HCColor.of(ctx).fillFor(AppColors.error),
            ),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final done = t.deleteMyProfileDone(profile.name);
    // Off this device first — its online copy follows straight away, or from
    // the sync queue once the device is online (LocalRepository)...
    await const LocalRepository().deleteProfile(profile.id);
    // ...then out of it in one go, as Reset All Data does, so nothing is left
    // showing a profile that no longer exists.
    container.read(profileProvider.notifier).clearProfile();
    container.invalidate(allProfilesWithProgressProvider);
    router.go(HiveService.getProfiles().isEmpty ? '/profile' : '/profile-switcher');
    final root = rootNavigatorKey.currentContext;
    if (root != null && root.mounted) AppSnackBar.info(root, message: done);
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showAnimatedDialog(
      context,
      child: AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.confirmResetTitle ?? 'Reset All Data?',
        ),
        content: Text(
          AppLocalizations.of(context)?.confirmResetMessage ??
              'This erases every profile on this tablet — learners, teachers and parents — with all their progress and settings. It cannot be undone. Online copies are not erased: to remove a profile’s online records too, delete it in Manage Profiles first.',
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
            style: FilledButton.styleFrom(backgroundColor: HCColor.of(context).fillFor(AppColors.error)),
            child: Text(AppLocalizations.of(context)?.reset ?? 'Reset'),
          ),
        ],
      ),
    );
  }
}

/// Whether [profile] may reset the whole tablet: a Teacher or a Parent only.
/// Reset erases EVERY profile on the device, not just the signed-in one, so
/// on a shared study tablet a learner — one mis-tap, or a gaze dwell — must
/// never reach it. (It used to show for every profile.)
bool canResetAllData(UserProfile? profile) =>
    profile?.role == UserRole.teacher || profile?.role == UserRole.parent;

/// Whether "Delete this profile" is offered: to every profile that exists
/// online — a Guest Player never did — and never to an educator who is only
/// previewing a learner (that would delete the learner).
bool canDeleteOwnProfile(UserProfile? profile, {required bool viewingAsStudent}) =>
    profile != null && !profile.isGuestPlayer && !viewingAsStudent;

// ────────────────────────────────────────
// PIN Setup Dialog
// ────────────────────────────────────────
Future<void> _showSetPinDialog(
  BuildContext context,
  WidgetRef ref,
  UserProfile? profile,
) async {
  if (profile == null) return;

  final result = await showAnimatedDialog<String?>(
    context,
    child: _SetPinDialog(hasExistingPin: profile.hasPinProtection),
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
  AppSnackBar.success(
    context,
    message: result.isEmpty ? _t(context).setPinRemoved : _t(context).setPinSet,
  );
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
      setState(() => _error = _t(context).psPinLength);
      return;
    }
    if (pin != confirm) {
      setState(() => _error = _t(context).epPinMismatch);
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.hasExistingPin
            ? (AppLocalizations.of(context)?.changePinTitle ?? 'Change PIN')
            : (AppLocalizations.of(context)?.setProfilePinTitle ??
                'Set Profile PIN'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)?.pinPrompt ??
                'Choose a 4-digit PIN to protect your profile.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _t(context).setEnterPin,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _t(context).epConfirmPin,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: AppTypography.labelSmall.copyWith(
                  color: HCColor.of(context).errorText,
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (widget.hasExistingPin)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''), // remove PIN
            child: Text(
              _t(context).epRemovePin,
              style: TextStyle(color: HCColor.of(context).errorText),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // cancel
          child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(AppLocalizations.of(context)?.setPin ?? 'Set PIN')),
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

/// "Version 1.3.0 • Thesis Capstone Project" — the installed version, or just
/// the project line until it is known.
String _aboutLine(AppLocalizations? l10n, String? version) {
  if (version == null || version.isEmpty) return 'Thesis Capstone Project';
  return l10n?.aboutVersionLine(version) ??
      'Version $version • Thesis Capstone Project';
}

// ────────────────────────────────────────
// Settings Tile
// ────────────────────────────────────────
/// "Check for updates": what the website's `version.json` says, and the way to
/// the download page when a newer APK is there.
class _UpdateCheckTile extends ConsumerStatefulWidget {
  const _UpdateCheckTile();

  @override
  ConsumerState<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends ConsumerState<_UpdateCheckTile> {
  /// Null until the first answer arrives.
  UpdateStatus? _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // The once-a-day answer, so the row says something useful on open.
    ref.read(updateStatusProvider.future).then((status) {
      if (mounted) setState(() => _status = status);
    }, onError: (_) {});
  }

  Future<void> _onTap() async {
    final status = _status;
    if (status is UpdateAvailable) {
      await openUpdatePage(context, status.release);
      return;
    }
    setState(() => _checking = true);
    final result = await ref
        .read(updateCheckServiceProvider)
        .check(force: true);
    if (!mounted) return;
    ref.invalidate(updateStatusProvider);
    setState(() {
      _status = result;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final subtitle = _checking
        ? l10n.updateCheckChecking
        : switch (_status) {
            UpdateAvailable(:final release) =>
              l10n.updateCheckAvailable(release.version),
            UpToDate(:final installedVersion) =>
              l10n.updateCheckLatest(installedVersion),
            UpdateUnknown() => l10n.updateCheckUnknown,
            null => l10n.updateCheckTap,
          };
    return _SettingsTile(
      icon: Icons.system_update_rounded,
      title: l10n.updateCheckTitle,
      subtitle: subtitle,
      onTap: _checking ? null : _onTap,
      trailing: _checking
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// The row's own action. When given, the **whole row** is tappable and the
  /// trailing chevron is drawn automatically.
  ///
  /// Previously every row's only target was that chevron — a ~40 px square at
  /// the far right of a full-width row. That is a poor target for a learner
  /// with a motor impairment, and for a controller it meant focus landed on a
  /// bare `IconButton` containing nothing but an icon, so the row announced
  /// itself as "Unnamed item".
  final VoidCallback? onTap;

  /// A custom trailing control (a switch, a value chip). Rows that have one
  /// are not themselves tappable — the control is the thing to operate.
  final Widget? trailing;

  /// What the *spoken* label should say instead of [subtitle].
  ///
  /// Exists for sliders whose visible subtitle is a coarse bucket ("Slow")
  /// covering several stops. On screen that reads cleanly, because the thumb
  /// shows the rest; spoken, two presses in a row that both say "Slow" sound
  /// like the second one did nothing. This carries the exact position instead,
  /// without cluttering what a sighted learner sees.
  final String? semanticsValue;

  /// Current state of the row's switch, when it has one.
  ///
  /// A sighted learner reads a switch at a glance; spoken, the row said only
  /// "Sound Effects. Game sounds & feedback" both before and after a press, so
  /// a learner using the controller had no way to tell what they had just
  /// turned on or off — the one thing they needed to hear.
  final bool? toggled;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.semanticsValue,
    this.toggled,
  }) : assert(
          onTap != null || trailing != null,
          'a settings row needs either an action or a control',
        );

  @override
  Widget build(BuildContext context) {
    // One label for the whole row, so a controller (and a screen reader) says
    // "Game Controller. Navigate by Bluetooth gamepad…" rather than naming the
    // icon button it happened to focus.
    return Semantics(
      container: true,
      button: onTap != null,
      label: _spokenLabel(context),
      toggled: toggled,
      excludeSemantics: true,
      child: _wrapTap(context, _row(context)),
    );
  }

  /// What the row says out loud: name, then state, then detail.
  ///
  /// State comes second because it is the part that changes — a learner
  /// stepping down a column of switches hears the names go by, and the word
  /// right after the name is the answer to "is this one on?".
  String _spokenLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = semanticsValue ?? subtitle;
    if (toggled == null) return '$title. $detail';
    final state =
        toggled! ? (l10n?.settingOn ?? 'On') : (l10n?.settingOff ?? 'Off');
    // A subtitle that is *itself* the state would be read twice ("Off. Off").
    // Call sites are meant to describe the setting and leave the state to
    // `toggled`; this keeps a slip from reaching the learner's ear.
    if (detail.trim().toLowerCase() == state.toLowerCase()) {
      return '$title. $state';
    }
    return '$title. $state. $detail';
  }

  Widget _wrapTap(BuildContext context, Widget child) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        // The label repeated *inside* the tappable area, not only on the
        // wrapper above it. Focus lands on this InkWell, and a controller
        // looking for its name searches downwards first — where it would
        // otherwise hit the title `Text` and stop, announcing "Sound Effects"
        // with neither the state nor the detail. The outer `Semantics` still
        // owns what a screen reader reads; this copy is what the controller
        // finds. `excludeSemantics` above keeps it out of the a11y tree.
        child: Semantics(label: _spokenLabel(context), child: child),
      ),
    );
  }

  Widget _row(BuildContext context) {
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
          // When the row itself is the control, the trailing switch must not
          // *also* take focus. A Switch is focusable by default and wins the
          // traversal order, so focus landed inside its internals — a subtree
          // with no text — and the row announced "Unnamed item" even though it
          // carried a perfectly good label. One focusable per row: the row.
          if (trailing != null)
            onTap == null
                // No row action means the trailing widget *is* the control —
                // a slider, a dropdown. Focus lands deep inside it, far below
                // the row's own label, so repeat the label right here where
                // the focused node can actually find it.
                ? Semantics(
                    container: true,
                    label: _spokenLabel(context),
                    child: trailing!,
                  )
                : ExcludeFocus(child: trailing!)
          else
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: HCColor.of(context).textSecondary,
            ),
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
    final l10n = AppLocalizations.of(context);
    return _SettingsTile(
      icon: Icons.insights_rounded,
      title: l10n?.settingResearchDataTitle ?? 'Help improve the app',
      subtitle: _enabled
          ? l10n?.settingResearchDataOnDesc ??
                      'Sending anonymous crash & usage data to the research team'
          : l10n?.settingResearchDataOffDesc ??
                      'Off — no usage statistics or crash reports are sent',
      onTap: () => (_set)(!(_enabled)),
      toggled: _enabled,
      // The visible subtitle already leads with "Off —"; spoken after the
      // state word that would stutter ("Off. Off — no data…").
      semanticsValue: _enabled
          ? l10n?.settingResearchDataOnDesc ??
                      'Sending anonymous crash & usage data to the research team'
          : _t(context).setNoDataLeaves,
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
          label: AppLocalizations.of(context)?.setFontSizeTo(label) ??
              'Set font size to $label',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? HCColor.of(context).primary
                  : HCColor.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : HCColor.of(context).border,
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
                color: isActive
                    ? HCColor.of(context).textOnPrimary
                    : HCColor.of(context).textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
