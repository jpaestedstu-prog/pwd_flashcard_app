import 'dart:ui' show SemanticsAction, Tristate;

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
/// Then each card had TWO focus nodes (a FocusableActionDetector under the
/// D-pad's own), so the D-pad stopped on every card twice, and its label sat
/// on a node apart from its press: on the tablet, TalkBack landed on a
/// "button" a double-tap could not press. And the sheet opened with the
/// timer switch first in line, so a remote's first OK toggled Beat the Clock
/// instead of choosing a level.
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

  /// Whether the focused control sits inside [card].
  bool focusedIn(WidgetTester tester, Finder card) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus is FocusScopeNode) return false;
    return tester.getRect(card).contains(focus.rect.center);
  }

  /// [node] is read, pressed and focused as one: a screen reader's
  /// double-tap presses what it lands on, and in a browser the keyboard's
  /// focus is on that same node.
  void expectOneNode(WidgetTester tester, Finder node, String what) {
    expect(node, findsOneWidget, reason: '$what: one node, not two');
    final data = tester.getSemantics(node).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue,
        reason: '$what is pressed where it is read');
    expect(data.flagsCollection.isFocused, isNot(Tristate.none),
        reason: '$what takes focus where it is read');
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
    testWidgets('each card is one node, read and pressed as one', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        (context) => showDifficultyPicker(context, GameType.wordMatch),
      );

      for (final level in ['Easy', 'Medium', 'Hard']) {
        expectOneNode(
          tester,
          find.bySemanticsLabel(RegExp('^$level\\. ')),
          level,
        );
      }
    });

    testWidgets('down steps one card at a time: one stop per card', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        (context) => showDifficultyPicker(context, GameType.wordMatch),
      );
      final easy = find.bySemanticsLabel(RegExp(r'^Easy\. '));
      final medium = find.bySemanticsLabel(RegExp(r'^Medium\. '));
      final hard = find.bySemanticsLabel(RegExp(r'^Hard\. '));

      expect(focusedIn(tester, easy), isTrue);
      for (final next in [medium, hard]) {
        expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
        await tester.pumpAndSettle();
        expect(focusedIn(tester, next), isTrue);
      }
    });

    testWidgets('a D-pad starts on Easy, not the timer: one press plays', (
      tester,
    ) async {
      GamePickerResult? picked;
      await pumpSheet(tester, (context) async {
        picked = await showDifficultyPicker(context, GameType.wordMatch);
      });

      expect(
        focusedIn(tester, find.bySemanticsLabel(RegExp(r'^Easy\. '))),
        isTrue,
        reason: 'the first OK should choose a level',
      );
      expect(GazeFocusDriver.activate(), isTrue);
      await tester.pumpAndSettle();
      expect(picked?.difficulty, GameDifficulty.easy);
      expect(picked?.timedMode, isFalse);
    });

    testWidgets('the timer switch is read by its name', (tester) async {
      await pumpSheet(
        tester,
        (context) => showDifficultyPicker(context, GameType.wordMatch),
      );

      final timer = find.bySemanticsLabel(RegExp('Beat the Clock'));
      expect(timer, findsOneWidget);
      final data = tester.getSemantics(timer).getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isFalse,
          reason: 'one node: the name, the switch and its state');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
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
    testWidgets('each option card is one node, read and pressed as one', (
      tester,
    ) async {
      await pumpSheet(tester, (context) => showCategoryPicker(context));

      final all = find.bySemanticsLabel('All Categories');
      expectOneNode(tester, all, 'All Categories');
      expect(
        tester.getSemantics(all).getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expectOneNode(tester, find.bySemanticsLabel('Animals'), 'Animals');
    });

    testWidgets('a D-pad starts on Start: one press plays every category', (
      tester,
    ) async {
      List<FlashcardCategory>? picked;
      await pumpSheet(tester, (context) async {
        picked = await showCategoryPicker(context);
      });

      expect(GazeFocusDriver.activate(), isTrue);
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'empty means all categories');
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
