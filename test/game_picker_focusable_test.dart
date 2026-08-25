import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

/// Regression cover for the game setup flow being reachable hands-free.
///
/// Both picker sheets are built from custom cards. They were bare
/// `GestureDetector`s, which are invisible to Flutter's focus traversal — the
/// path gaze falls back to on any route that publishes no gaze grid, a modal
/// sheet included. That made the difficulty chooser, the gateway to all ten
/// games, a dead end: nothing to land on and nothing to press.
///
/// `Semantics` + `FocusableActionDetector` gives each card a focus node and
/// `ActivateIntent` handling, which also makes them real buttons to a screen
/// reader.
void main() {
  /// Opens [open] as a modal sheet on a host with the l10n delegates the real
  /// app supplies — the picker copy comes from `AppLocalizations`.
  Future<void> pumpSheet(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    unawaited(open(hostContext));
    await tester.pumpAndSettle();
  }

  /// Walks traversal until [done] reports success, or gives up.
  ///
  /// Bounded rather than open-ended so a genuinely unreachable control fails
  /// the test instead of hanging it.
  Future<bool> traverseUntil(
    WidgetTester tester,
    bool Function() done, {
    int maxSteps = 12,
  }) async {
    for (var i = 0; i < maxSteps; i++) {
      if (GazeFocusDriver.activate()) {
        await tester.pumpAndSettle();
        if (done()) return true;
      }
      if (!GazeFocusDriver.move(TraversalDirection.down) &&
          !GazeFocusDriver.moveFirst()) {
        return false;
      }
      await tester.pumpAndSettle();
      if (done()) return true;
    }
    return false;
  }

  group('difficulty picker', () {
    testWidgets('its cards are focusable controls, not bare tap targets', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        (context) => showDifficultyPicker(context, GameType.wordMatch),
      );

      // Easy / Medium / Hard each carry one.
      expect(
        find.byType(FocusableActionDetector),
        findsAtLeastNWidgets(3),
        reason: 'without these, traversal has nothing to land on',
      );
    });

    testWidgets('traversal can reach and press a difficulty', (tester) async {
      GamePickerResult? picked;
      await pumpSheet(tester, (context) async {
        picked = await showDifficultyPicker(context, GameType.wordMatch);
      });

      final reached = await traverseUntil(tester, () => picked != null);
      expect(
        reached,
        isTrue,
        reason: 'a hands-free learner must be able to start a game',
      );
      expect(picked, isNotNull);
    });
  });

  group('category picker', () {
    testWidgets('its option cards are focusable controls', (tester) async {
      await pumpSheet(tester, (context) => showCategoryPicker(context));

      // "All Categories" plus one per vocabulary category.
      expect(
        find.byType(FocusableActionDetector),
        findsAtLeastNWidgets(2),
        reason: 'the step straight after difficulty must be reachable too',
      );
    });

    testWidgets('a focused option card responds to an activation', (
      tester,
    ) async {
      await pumpSheet(tester, (context) => showCategoryPicker(context));

      expect(GazeFocusDriver.moveFirst(), isTrue);
      await tester.pumpAndSettle();

      // The card is a real control: activating it toggles selection rather
      // than being swallowed, which is what a bare GestureDetector did.
      expect(
        GazeFocusDriver.activate(),
        isTrue,
        reason: 'ActivateIntent must reach the card',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Local `unawaited` so the test file needs no extra import.
void unawaited(Future<void> future) {}
