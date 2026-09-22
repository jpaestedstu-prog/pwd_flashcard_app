import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/enums.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';

/// A step in the onboarding tutorial.
class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Default tutorial steps for the home screen.
const List<TutorialStep> homeTutorialSteps = [
  TutorialStep(
    title: 'Welcome to FlashLearn! 🎉',
    description:
        'This app helps you learn new English and Filipino vocabulary '
        'through flashcards and fun games. Let\'s take a quick tour!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Flashcard Categories 📚',
    description:
        'Browse 6 vocabulary categories — Animals, Colors & Shapes, '
        'Numbers, Body Parts, Food & Drinks, and Family & Greetings. '
        'Tap any category to start learning!',
    icon: Icons.category_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Fun Games 🎮',
    description:
        'Practice words with 7 different games: Word Match, Spelling Bee, '
        'Memory Match, Drag & Drop, Flashcard Quiz, Pronunciation Practice, '
        'and Sentence Builder. Pick a difficulty and category to play!',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Track Your Progress 📊',
    description:
        'See your streak, stars earned, and words learned on the Progress '
        'tab. Unlock achievement badges as you improve!',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF44336),
  ),
  TutorialStep(
    title: 'Accessibility Settings ♿',
    description:
        'Need bigger text, high contrast, or to turn off animations? '
        'Open Settings (gear icon) to customize everything to your needs.',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'You\'re Ready! 🚀',
    description:
        'Start by tapping a category card below to learn your first words. '
        'Have fun and earn stars!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// [homeTutorialSteps] for a learner who picked Filipino. The first thing a
/// new learner sees, so it cannot be the one English screen in the flow.
const List<TutorialStep> homeTutorialStepsFilipino = [
  TutorialStep(
    title: 'Maligayang pagdating sa FlashLearn! 🎉',
    description:
        'Tinutulungan ka ng app na ito na matuto ng mga bagong salita sa '
        'Ingles at Filipino gamit ang mga flashcard at masasayang laro. '
        'Tara, maglibot tayo sandali!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Mga Kategorya ng Flashcard 📚',
    description:
        'Tingnan ang mga kategorya ng salita — tulad ng Mga Hayop, Mga Kulay '
        'at Hugis, Mga Numero, at Pamilya at Pagbati. '
        'Pindutin ang kahit anong kategorya para magsimulang matuto!',
    icon: Icons.category_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Masasayang Laro 🎮',
    description:
        'Sanayin ang mga salita sa iba’t ibang laro, tulad ng Word Match, '
        'Spelling Bee at Memory Match. Pumili ng hirap at kategorya, '
        'saka maglaro!',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Tingnan ang Iyong Progreso 📊',
    description:
        'Makikita sa tab na Progreso ang iyong sunod-sunod na araw, mga '
        'bituin, at mga salitang natutunan. Makakakuha ka ng mga badge '
        'habang gumagaling ka!',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF44336),
  ),
  TutorialStep(
    title: 'Mga Setting ng Aksesibilidad ♿',
    description:
        'Kailangan mo ba ng mas malaking letra, mataas na contrast, o '
        'walang animation? Buksan ang Mga Setting (icon na gear) para '
        'iayon ang lahat sa iyong pangangailangan.',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'Handa Ka Na! 🚀',
    description:
        'Magsimula sa pagpindot ng isang kategorya sa ibaba para matutunan '
        'ang iyong mga unang salita. Magsaya at mag-ipon ng bituin!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// Tutorial steps for teachers.
const List<TutorialStep> teacherTutorialSteps = [
  TutorialStep(
    title: 'Welcome, Teacher! 📚',
    description:
        'FlashLearn PWD helps your students learn English and Filipino '
        'vocabulary through accessible flashcards and games. '
        'Let\'s show you the teacher tools!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Student Dashboard 📊',
    description:
        'Tap the dashboard icon on your home screen to view detailed '
        'progress for the active student — mastery rates, category '
        'breakdown, weak areas, and recent game scores.',
    icon: Icons.dashboard_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Multi-Student View 👥',
    description:
        'Tap the people icon to see all student profiles at a glance. '
        'Compare progress across students and tap any card for details.',
    icon: Icons.people_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Classroom Monitor 🏫',
    description:
        'Open Classroom View from the dashboard for real-time '
        'monitoring — see which students are active, their current '
        'activity, accuracy, and stars earned. Auto-refreshes every 30s.',
    icon: Icons.class_rounded,
    color: Color(0xFF2196F3),
  ),
  TutorialStep(
    title: 'Export Reports 📄',
    description:
        'Generate PDF or CSV reports from the dashboard. Share progress '
        'with parents, administrators, or keep records for IEP tracking.',
    icon: Icons.file_download_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'You\'re All Set! 🚀',
    description:
        'Explore the flashcard categories and games yourself, then '
        'guide your students through their learning journey!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// [teacherTutorialSteps] in Filipino.
const List<TutorialStep> teacherTutorialStepsFilipino = [
  TutorialStep(
    title: 'Maligayang pagdating, Guro! 📚',
    description:
        'Tinutulungan ng FlashLearn PWD ang iyong mga mag-aaral na matuto ng '
        'mga salitang Ingles at Filipino gamit ang madaling-gamiting '
        'flashcard at laro. Ipakikita namin ang mga gamit para sa guro!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Dashboard ng Mag-aaral 📊',
    description:
        'I-tap ang icon ng dashboard sa home screen para makita ang '
        'detalyadong progreso ng aktibong mag-aaral — kahusayan, hati ayon '
        'sa kategorya, mahihinang bahagi, at mga kamakailang iskor.',
    icon: Icons.dashboard_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Tingnan ang Lahat ng Mag-aaral 👥',
    description:
        'I-tap ang icon ng mga tao para makita ang lahat ng profile ng '
        'mag-aaral. Paghambingin ang progreso at i-tap ang card para sa '
        'detalye.',
    icon: Icons.people_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Pagbantay sa Klase 🏫',
    description:
        'Buksan ang Classroom View mula sa dashboard para makita agad kung '
        'sino ang aktibo, ang kanilang ginagawa, katumpakan, at nakuhang '
        'bituin. Nag-a-update tuwing 30 segundo.',
    icon: Icons.class_rounded,
    color: Color(0xFF2196F3),
  ),
  TutorialStep(
    title: 'Mag-export ng Ulat 📄',
    description:
        'Gumawa ng ulat na PDF o CSV mula sa dashboard. Ibahagi ang '
        'progreso sa mga magulang at administrador, o itago para sa IEP.',
    icon: Icons.file_download_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'Handa Ka Na! 🚀',
    description:
        'Subukan mismo ang mga kategorya ng flashcard at mga laro, saka '
        'gabayan ang iyong mga mag-aaral sa kanilang pag-aaral!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// Tutorial steps for parents.
const List<TutorialStep> parentTutorialSteps = [
  TutorialStep(
    title: 'Welcome, Parent! 👨‍👩‍👧',
    description:
        'FlashLearn PWD is your child\'s bilingual vocabulary app. '
        'Let\'s walk you through how to support their learning!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Progress Dashboard 📊',
    description:
        'Tap the dashboard icon on the home screen to see your child\'s '
        'learning progress — words mastered, games played, strengths '
        'and areas that need practice.',
    icon: Icons.dashboard_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Track Achievements 🏆',
    description:
        'Visit the Progress tab to see streaks, stars, and achievement '
        'badges. Celebrate milestones together to keep motivation high!',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF44336),
  ),
  TutorialStep(
    title: 'Flashcards & Games 🎮',
    description:
        'Browse flashcard categories and educational games with your '
        'child. All content supports Filipino Sign Language (FSL), '
        'text-to-speech, and adjustable accessibility settings.',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Accessibility Settings ♿',
    description:
        'Open Settings to fine-tune text size, contrast, animations, '
        'and audio to match your child\'s needs. Presets are available '
        'for common disability types.',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'Let\'s Get Started! 🚀',
    description:
        'Sit with your child and explore a flashcard category together. '
        'Learning is more fun with family!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// [parentTutorialSteps] in Filipino.
const List<TutorialStep> parentTutorialStepsFilipino = [
  TutorialStep(
    title: 'Maligayang pagdating, Magulang! 👨‍👩‍👧',
    description:
        'Ang FlashLearn PWD ay app ng iyong anak para sa mga salitang Ingles '
        'at Filipino. Ipakikita namin kung paano mo masusuportahan ang '
        'kanyang pag-aaral!',
    icon: Icons.waving_hand_rounded,
    color: AppColors.primary,
  ),
  TutorialStep(
    title: 'Dashboard ng Progreso 📊',
    description:
        'I-tap ang icon ng dashboard sa home screen para makita ang progreso '
        'ng iyong anak — mga natutunang salita, nalarong laro, kalakasan, at '
        'mga bahaging kailangan pang sanayin.',
    icon: Icons.dashboard_rounded,
    color: Color(0xFFFF9800),
  ),
  TutorialStep(
    title: 'Subaybayan ang mga Parangal 🏆',
    description:
        'Pumunta sa Progreso para makita ang sunod-sunod na araw, bituin, at '
        'mga badge. Ipagdiwang nang sama-sama ang bawat tagumpay!',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFF44336),
  ),
  TutorialStep(
    title: 'Mga Flashcard at Laro 🎮',
    description:
        'Tingnan kasama ng iyong anak ang mga kategorya ng flashcard at mga '
        'larong pang-aral. May Filipino Sign Language (FSL), text-to-speech, '
        'at naaayos na setting ng aksesibilidad ang lahat ng nilalaman.',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF4CAF50),
  ),
  TutorialStep(
    title: 'Mga Setting ng Aksesibilidad ♿',
    description:
        'Buksan ang Settings para ayusin ang laki ng letra, contrast, '
        'animation, at audio ayon sa pangangailangan ng iyong anak. May mga '
        'handang preset para sa karaniwang uri ng kapansanan.',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF9C27B0),
  ),
  TutorialStep(
    title: 'Magsimula Na Tayo! 🚀',
    description:
        'Samahan ang iyong anak at subukan ang isang kategorya ng flashcard. '
        'Mas masaya ang pag-aaral kasama ang pamilya!',
    icon: Icons.rocket_launch_rounded,
    color: AppColors.accent,
  ),
];

/// Returns the tutorial steps appropriate for the given [role].
///
/// [filipino] picks the Filipino copy. Only the learner Home mounts the
/// tutorial today (educators land on `EducatorHomeScreen`), but every role
/// has both languages so a new entry point can't bring English back.
List<TutorialStep> tutorialStepsForRole(
  UserRole? role, {
  bool filipino = false,
}) {
  switch (role) {
    case UserRole.teacher:
      return filipino ? teacherTutorialStepsFilipino : teacherTutorialSteps;
    case UserRole.parent:
      return filipino ? parentTutorialStepsFilipino : parentTutorialSteps;
    default:
      return filipino ? homeTutorialStepsFilipino : homeTutorialSteps;
  }
}

/// Full-screen tutorial overlay with step-by-step coaching.
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;

  const TutorialOverlay({
    super.key,
    this.steps = homeTutorialSteps,
    required this.onComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      widget.onComplete();
    }
  }

  void _skip() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    t.skip,
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // ─── Step Content ─────────────────
            Expanded(
              flex: 4,
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.steps.length,
                itemBuilder: (context, index) {
                  final s = widget.steps[index];
                  return _TutorialStepCard(step: s, index: index);
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─── Dot Indicators ───────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.steps.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentStep ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentStep
                        ? step.color
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ─── Action Button ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: step.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: step.color.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    isLast ? '${t.letsGo} 🎉' : t.next,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _TutorialStepCard extends StatelessWidget {
  final TutorialStep step;
  final int index;

  const _TutorialStepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      // Centre the step content when it fits, but let it scroll instead of
      // overflowing when a large accessibility font scale makes it taller than
      // the page (regression: overflowed by a few px at 2.0x on short tablets).
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon in glowing circle
                Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: step.color.withValues(alpha: 0.4),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: step.color.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(step.icon, size: 56, color: step.color),
                    )
                    .animate(key: ValueKey(index))
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 36),

                // Title
                Text(
                      step.title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate(key: ValueKey('title_$index'))
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(begin: 0.15, end: 0),

                const SizedBox(height: 16),

                // Description
                Text(
                      step.description,
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    )
                    .animate(key: ValueKey('desc_$index'))
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
