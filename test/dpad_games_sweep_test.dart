import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/learner_portfolio_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/enhanced_create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/hard_words_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_template_picker_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/drag_drop_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/first_letter_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/flashcard_quiz_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_practice_hub_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_sign_to_word_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_word_to_sign_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/jigsaw_puzzle_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/odd_one_out_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/picture_word_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/pronunciation_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/sentence_builder_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/spelling_bee_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/tracing_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/word_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/yes_or_no_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_calibration_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_control_screen.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/screens/peer_collaboration_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_lock_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_quiz_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_reader_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/all_screens.dart';
import 'support/dpad_reach.dart';
import 'support/real_fonts.dart';

/// The screens a learner drills down into from the hubs — the card viewer,
/// every game, the story reader and its quiz — as a D-pad meets them. None
/// publishes a hub grid, so focus traversal is how gaze and the controller
/// reach what they do not publish themselves, and it is all a keyboard has.
final Map<String, Widget Function()> _drillDown = {
  'FlashcardViewerScreen': () =>
      const FlashcardViewerScreen(category: FlashcardCategory.animals),
  'CreateFlashcardScreen': () => const CreateFlashcardScreen(),
  'DeckTemplatePickerScreen': () => const DeckTemplatePickerScreen(),
  'WordMatchScreen': () => const WordMatchScreen(),
  'SpellingBeeScreen': () => const SpellingBeeScreen(),
  'MemoryMatchScreen': () => const MemoryMatchScreen(),
  'DragDropScreen': () => const DragDropScreen(),
  'FlashcardQuizScreen': () => const FlashcardQuizScreen(),
  'PronunciationScreen': () => const PronunciationScreen(),
  'SentenceBuilderScreen': () => const SentenceBuilderScreen(),
  'TracingScreen': () => const TracingScreen(),
  'PictureWordScreen': () => const PictureWordScreen(),
  'YesOrNoScreen': () => const YesOrNoScreen(),
  'OddOneOutScreen': () => const OddOneOutScreen(),
  'FirstLetterScreen': () => const FirstLetterScreen(),
  'JigsawPuzzleScreen': () => const JigsawPuzzleScreen(),
  'FslPracticeHubScreen': () => const FslPracticeHubScreen(),
  'FslSignToWordScreen': () => const FslSignToWordScreen(),
  'FslWordToSignScreen': () => const FslWordToSignScreen(),
  'StoryReaderScreen': () => const StoryReaderScreen(storyId: 's_a01'),
  'StoryQuizScreen': () => const StoryQuizScreen(storyId: 's_a01'),
  'AssessmentHubScreen': () => const AssessmentHubScreen(),
  'LearnerPortfolioScreen': () => const LearnerPortfolioScreen(),
  'EnhancedCreateFlashcardScreen': () => const EnhancedCreateFlashcardScreen(),
  'HardWordsScreen': () => const HardWordsScreen(),
  'PeerCollaborationScreen': () => const PeerCollaborationScreen(),
  'RoutineScreen': () => const RoutineScreen(),
  'RoutineLockScreen': () => const RoutineLockScreen(),
  'GazeControlScreen': () => const GazeControlScreen(),
  'GazeCalibrationScreen': () => const GazeCalibrationScreen(),
};

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_games_sweep');
  });
  tearDownAll(closeSweepBoxes);

  for (final entry in _drillDown.entries) {
    testWidgets('${entry.key}: every tap target takes D-pad focus',
        (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(686, 1097);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sweepProfileOverride(UserRole.student)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: entry.value(),
          ),
        ),
      );
      for (var t = 0; t < 30; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final report = await surveyDpadReach(tester, devicePixelRatio: 1.0);
      for (final t in report.notFocusable) {
        debugPrint('GAMES ${entry.key} | $t');
      }
      debugPrint('GAMES ${entry.key} | ${report.targets.length} targets, '
          '${report.notFocusable.length} not focusable');
      expect(report.notFocusable.map((t) => '$t'), isEmpty,
          reason: 'every control takes D-pad focus');

      for (var t = 0; t < 30; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      semantics.dispose();
    });
  }
}
