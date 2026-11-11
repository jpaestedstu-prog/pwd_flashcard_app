import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/games/widgets/pause_overlay.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_presentation.dart';
import 'package:pwdpwdpwd/features/mood_tracker/widgets/mood_picker.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/accessibility_quick_sheet.dart';
import 'package:pwdpwdpwd/widgets/achievement_overlay.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

import 'support/all_screens.dart';
import 'support/dpad_reach.dart';
import 'support/real_fonts.dart';

/// The pop-ups the screen sweeps never open — every game's two setup sheets,
/// the pause card, the result card, the achievement card, the accessibility
/// sheet, the mood picker — surveyed as a D-pad and a screen reader meet
/// them, by the screens' own three rules.
///
/// Found on the tablet, out of the sweeps' sight: both setup sheets gave
/// every card two focus stops and a "button" a screen reader could not
/// press, and the timer switch had no name.

typedef _Open = Future<void> Function(BuildContext context);

Future<void> _page(BuildContext context, Widget body) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => Scaffold(body: body)),
    );

final Map<String, _Open> _popups = {
  'difficulty picker': (c) => showDifficultyPicker(c, GameType.wordMatch),
  'difficulty picker, with Auto': (c) => showDifficultyPicker(
    c,
    GameType.wordMatch,
    profileId: 'sweep-profile',
  ),
  'category picker': (c) => showCategoryPicker(c),
  'accessibility quick sheet': (c) => showAccessibilityQuickSheet(c),
  'pause card': (c) => _page(
    c,
    PauseOverlay(onResume: () {}, onRestart: () {}, onQuit: () async {}),
  ),
  'game result': (c) => _page(
    c,
    Center(
      child: GameResultDialog(
        score: 3,
        total: 5,
        starsEarned: 2,
        onPlayAgain: () {},
        onExit: () {},
        onReview: () {},
      ),
    ),
  ),
  'achievement card': (c) => _page(
    c,
    Stack(
      children: [
        AchievementUnlockedOverlay(
          achievements: [Achievements.all.first],
          onDismiss: () {},
        ),
      ],
    ),
  ),
  for (final note in [false, true])
    'mood picker${note ? ', with a note' : ''}': (c) =>
        showModalBottomSheet<void>(
          context: c,
          builder: (_) => SingleChildScrollView(
            child: MoodPicker(
              choices: MoodPresentation.fullChoices,
              showNote: note,
              isFilipino: false,
              onAnswer: (_) {},
            ),
          ),
        ),
};

/// A sheet's dimmed barrier: pressed by a screen reader, dismissed by a
/// D-pad's Back or Escape — never a stop for the arrows.
bool _isBarrier(ReachTarget t) =>
    t.madeBy.contains('Barrier') || t.label == 'Dismiss';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('dpad_popup_sweep');
  });
  tearDownAll(closeSweepBoxes);

  for (final entry in _popups.entries) {
    testWidgets('${entry.key}: every control works for a D-pad and a '
        'screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      const size = Size(686, 1097);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext host;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sweepProfileOverride(UserRole.student)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                host = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      entry.value(host).ignore();
      for (var t = 0; t < 25; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final report = await surveyDpadReach(tester, devicePixelRatio: 1.0);
      final notFocusable =
          report.notFocusable.where((t) => !_isBarrier(t)).toList();
      for (final t in [...notFocusable, ...report.buttonsWithoutPress,
          ...report.focusNotOnNode]) {
        debugPrint('POPUP ${entry.key} | $t');
      }
      debugPrint('POPUP ${entry.key} | ${report.targets.length} targets');
      expect(report.targets, isNotEmpty);
      expect(notFocusable.map((t) => '$t'), isEmpty,
          reason: 'every control takes D-pad focus');
      expect(report.buttonsWithoutPress.map((t) => '$t'), isEmpty,
          reason: 'a screen reader can press every button it announces');
      expect(report.focusNotOnNode.map((t) => '$t'), isEmpty,
          reason: "a control's focus sits on the node a screen reader reads");

      for (var t = 0; t < 30; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      semantics.dispose();
    });
  }
}
