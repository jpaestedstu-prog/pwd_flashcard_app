import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/voice_navigation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/accessibility_visual_feedback.dart';

/// Full voice-guided navigation mode with a step-by-step guided tour
/// and auto-reading of screen elements.
///
/// This screen lets visually impaired users:
/// 1. Enable/disable voice navigation
/// 2. Take a guided tour of the app
/// 3. Customize voice speed and language
/// 4. Test the voice output
class VoiceGuidedModeScreen extends ConsumerStatefulWidget {
  const VoiceGuidedModeScreen({super.key});

  @override
  ConsumerState<VoiceGuidedModeScreen> createState() =>
      _VoiceGuidedModeScreenState();
}

class _VoiceGuidedModeScreenState
    extends ConsumerState<VoiceGuidedModeScreen> {
  int _tourStep = -1; // -1 = not started
  bool _isSpeaking = false;

  static const _tourSteps = [
    _TourStep(
      title: 'Welcome!',
      description:
          'This guided tour will help you learn how to navigate the app using voice. '
          'Every screen, button, and action will be announced aloud.',
      icon: Icons.record_voice_over_rounded,
      voiceText:
          'Welcome to the voice-guided tour! I will help you learn to navigate the app. '
          'Every screen and button will be announced aloud for you.',
    ),
    _TourStep(
      title: 'Home Screen',
      description:
          'The Home screen is your starting point. It shows daily challenges, '
          'vocabulary categories, and quick-access buttons for games and flashcards.',
      icon: Icons.home_rounded,
      voiceText:
          'The Home screen is your starting point. Here you can find daily challenges, '
          'vocabulary categories, and quick buttons for games and flashcards.',
      route: '/home',
    ),
    _TourStep(
      title: 'Flashcards',
      description:
          'Browse vocabulary decks by category. Tap a deck to study flashcards. '
          'Swipe left or right to navigate between cards.',
      icon: Icons.style_rounded,
      voiceText:
          'In the Flashcards section, you can browse vocabulary decks organized by category. '
          'Tap a deck to study. Swipe left or right to move between cards.',
      route: '/flashcards',
    ),
    _TourStep(
      title: 'Games',
      description:
          'Practice vocabulary through fun games like Word Match, Spelling Bee, '
          'Memory Match, and more. Each game has 3 difficulty levels.',
      icon: Icons.sports_esports_rounded,
      voiceText:
          'The Games section has fun activities like Word Match, Spelling Bee, '
          'Memory Match, and more. Each game offers three difficulty levels: easy, medium, and hard.',
      route: '/games',
    ),
    _TourStep(
      title: 'Progress',
      description:
          'Track your learning journey! See words learned, stars earned, '
          'achievements unlocked, and detailed charts of your improvement.',
      icon: Icons.insights_rounded,
      voiceText:
          'The Progress screen shows your learning journey. You can see words learned, '
          'stars earned, achievements, and charts showing your improvement over time.',
      route: '/progress',
    ),
    _TourStep(
      title: 'Settings',
      description:
          'Customize the app for your needs. Adjust text size, enable high contrast, '
          'change language, and configure voice navigation preferences.',
      icon: Icons.settings_rounded,
      voiceText:
          'In Settings, you can customize the app for your needs. Adjust text size, '
          'enable high contrast mode, change language, and configure voice navigation.',
    ),
    _TourStep(
      title: 'Tour Complete!',
      description:
          'You\'re all set! Voice navigation will announce every screen you visit '
          'and every button you interact with. You can restart this tour anytime '
          'from Settings.',
      icon: Icons.celebration_rounded,
      voiceText:
          'You have completed the guided tour! Voice navigation will now announce '
          'every screen and button for you. You can restart this tour anytime from Settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final voiceNav = ref.watch(voiceNavigationProvider);
    final settings = ref.watch(settingsProvider);
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Go back',
        ),
        title: Text(
          'Voice-Guided Mode',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Main Toggle Card ─────────────────
          _VoiceToggleCard(
            isEnabled: settings.voiceNavigation,
            hc: hc,
            onToggle: () {
              ref.read(settingsProvider.notifier).update(
                settings.copyWith(voiceNavigation: !settings.voiceNavigation),
              );
              if (!settings.voiceNavigation) {
                // Just enabled — announce it
                Future.delayed(const Duration(milliseconds: 300), () {
                  voiceNav.announceAction('Voice navigation is now enabled.');
                });
              }
            },
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // ─── Voice Speed Control ──────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, color: hc.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Voice Speed',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _speedLabel(settings.ttsSpeed),
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: settings.ttsSpeed,
                  min: 0.1,
                  divisions: 9,
                  activeColor: hc.primary,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).updateTtsSpeed(value);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Slow', style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint, fontSize: 10)),
                    Text('Fast', style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Language Selection ────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.translate_rounded, color: hc.secondary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Voice Language',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _LanguageOption(
                      label: 'English',
                      emoji: '🇺🇸',
                      isSelected: settings.locale == 'en',
                      color: hc.info,
                      onTap: () {
                        ref.read(settingsProvider.notifier).updateLocale('en');
                      },
                    ),
                    const SizedBox(width: 12),
                    _LanguageOption(
                      label: 'Filipino',
                      emoji: '🇵🇭',
                      isSelected: settings.locale == 'fil',
                      color: hc.error,
                      onTap: () {
                        ref.read(settingsProvider.notifier).updateLocale('fil');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Test Voice Button ────────────────
          ElevatedButton.icon(
            onPressed: _isSpeaking
                ? null
                : () async {
                    setState(() => _isSpeaking = true);
                    await voiceNav.announceAction(
                      settings.locale == 'fil'
                          ? 'Kumusta! Gumagana ang voice navigation. Narito ako para tulungan ka.'
                          : 'Hello! Voice navigation is working. I am here to help you navigate the app.',
                    );
                    if (mounted) setState(() => _isSpeaking = false);
                  },
            icon: AudioPlayingIndicator(
                isPlaying: _isSpeaking,
                size: 22,
                color: Colors.white,
              ),
            label: Text(_isSpeaking ? 'Speaking...' : 'Test Voice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hc.secondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Guided Tour Section ──────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tour_rounded, color: hc.accent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Guided Tour',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_tourStep >= 0)
                      Text(
                        '${_tourStep + 1}/${_tourSteps.length}',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hc.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a step-by-step tour of the entire app with '
                  'voice narration for each screen.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                if (_tourStep < 0) ...[
                  // Start tour button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startTour,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Tour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hc.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Current tour step
                  _TourStepCard(
                    step: _tourSteps[_tourStep],
                    stepIndex: _tourStep,
                    totalSteps: _tourSteps.length,
                    hc: hc,
                    isSpeaking: _isSpeaking,
                  ),
                  const SizedBox(height: 12),
                  // Tour navigation
                  Row(
                    children: [
                      if (_tourStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousTourStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_tourStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _tourStep < _tourSteps.length - 1
                              ? _nextTourStep
                              : _endTour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hc.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _tourStep < _tourSteps.length - 1
                                ? 'Next'
                                : 'Finish Tour',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // ─── Quick Navigation Announce ─────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.navigation_rounded, color: hc.info, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Screen Announcements',
                      style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap any button below to hear a description of that screen.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickAnnounceChip(route: '/home', label: '🏠 Home', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/flashcards', label: '📚 Flashcards', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/games', label: '🎮 Games', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/progress', label: '📊 Progress', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/stories', label: '📖 Stories', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/shop', label: '⭐ Shop', voiceNav: voiceNav),
                    _QuickAnnounceChip(route: '/settings', label: '⚙️ Settings', voiceNav: voiceNav),
                  ],
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _speedLabel(double speed) {
    if (speed <= 0.25) return 'Very Slow';
    if (speed <= 0.4) return 'Slow';
    if (speed <= 0.6) return 'Normal';
    if (speed <= 0.8) return 'Fast';
    return 'Very Fast';
  }

  void _startTour() {
    final voiceNav = ref.read(voiceNavigationProvider);
    // Temporarily enable voice nav for the tour
    if (!voiceNav.isEnabled) {
      ref.read(settingsProvider.notifier).update(
        ref.read(settingsProvider).copyWith(voiceNavigation: true),
      );
    }
    setState(() => _tourStep = 0);
    _speakCurrentStep();
  }

  void _nextTourStep() {
    if (_tourStep < _tourSteps.length - 1) {
      setState(() => _tourStep++);
      _speakCurrentStep();
    }
  }

  void _previousTourStep() {
    if (_tourStep > 0) {
      setState(() => _tourStep--);
      _speakCurrentStep();
    }
  }

  void _endTour() {
    setState(() => _tourStep = -1);
    final voiceNav = ref.read(voiceNavigationProvider);
    voiceNav.announceAction('Guided tour complete. You\'re all set!');
  }

  Future<void> _speakCurrentStep() async {
    if (_tourStep < 0 || _tourStep >= _tourSteps.length) return;
    final step = _tourSteps[_tourStep];
    final voiceNav = ref.read(voiceNavigationProvider);

    setState(() => _isSpeaking = true);
    await voiceNav.announceAction(step.voiceText);
    if (mounted) setState(() => _isSpeaking = false);
  }
}

// ─── Supporting Widgets ─────────────────────────────────

class _VoiceToggleCard extends StatelessWidget {
  final bool isEnabled;
  final HCColor hc;
  final VoidCallback onToggle;

  const _VoiceToggleCard({
    required this.isEnabled,
    required this.hc,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [hc.primary.withValues(alpha: 0.2), hc.secondary.withValues(alpha: 0.15)]
              : [hc.surfaceLight, hc.surfaceLight],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEnabled ? hc.primary : hc.border,
          width: isEnabled ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEnabled
                  ? hc.primary.withValues(alpha: 0.2)
                  : hc.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded,
              color: isEnabled ? hc.primary : hc.textHint,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Navigation',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEnabled
                      ? 'Active — Screen changes and buttons are announced'
                      : 'Tap the switch to enable voice announcements',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            onChanged: (_) => onToggle(),
            activeTrackColor: hc.primary,
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourStepCard extends StatelessWidget {
  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final HCColor hc;
  final bool isSpeaking;

  const _TourStepCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.hc,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (stepIndex + 1) / totalSteps,
              backgroundColor: hc.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(hc.accent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hc.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: hc.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    if (isSpeaking)
                      Row(
                        children: [
                          AudioPlayingIndicator(
                            isPlaying: true,
                            size: 16,
                            color: hc.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Speaking...',
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.accent,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.description,
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }
}

class _QuickAnnounceChip extends StatelessWidget {
  final String route;
  final String label;
  final VoiceNavigationService voiceNav;

  const _QuickAnnounceChip({
    required this.route,
    required this.label,
    required this.voiceNav,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final info = VoiceNavigationService.describeRoute(route);
        voiceNav.announceScreen(info.name, description: info.description);
      },
      backgroundColor: HCColor.of(context).surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ─── Tour Step Model ────────────────────────────────────

class _TourStep {
  final String title;
  final String description;
  final IconData icon;
  final String voiceText;
  final String? route;

  const _TourStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.voiceText,
    this.route,
  });
}
