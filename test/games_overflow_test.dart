import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/widgets/game_review_sheet.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';
import 'package:pwdpwdpwd/widgets/animated_score_reveal.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the shared **game** surfaces — the end-of-
/// round result dialog, the live score/timer/star widgets, and the difficulty,
/// category and word-review bottom sheets every game launches.
///
/// The pure widgets go through [expectNoOverflowAcrossDevices]; the modal
/// sheets (which can only be reached via their public `show…` helpers and
/// therefore need a real `Navigator`) go through [_expectSheetNoOverflow],
/// which opens the sheet at a handful of deliberately punishing viewports
/// (short phone landscape, narrow 7" portrait) at the maximum font scale —
/// exactly where a non-scrolling sheet body bursts its height.

void _noop() {}

/// The tight viewports a launched bottom sheet must still survive. A sheet is
/// height-capped to a fraction of the viewport, so a *short* viewport (landscape
/// phone) at the largest font scale is the worst case for vertical overflow.
const _sheetViewports = <DeviceSize>[
  DeviceSize('phone landscape', Size(640, 360), devicePixelRatio: 3.0),
  DeviceSize('7" landscape', Size(960, 600)),
  DeviceSize('7" portrait', Size(600, 960)),
  DeviceSize('10" portrait', Size(800, 1280)),
];

/// Opens a modal sheet via [open] at every [_sheetViewports] × [kTextScales]
/// combination and asserts it lays out without an overflow / layout exception.
Future<void> _expectSheetNoOverflow(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open, {
  List<DeviceSize> viewports = _sheetViewports,
  List<double> textScales = kTextScales,
}) async {
  for (final device in viewports) {
    for (final scale in textScales) {
      tester.view.physicalSize = device.size * device.devicePixelRatio;
      tester.view.devicePixelRatio = device.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      // Fire-and-forget: the future completes when the sheet is dismissed.
      unawaited(open(hostContext));
      await tester.pumpAndSettle();

      // Drain every exception raised while the sheet was on screen — an
      // overflowing body re-reports each frame, so check them all.
      Object? firstError;
      for (Object? e = tester.takeException();
          e != null;
          e = tester.takeException()) {
        firstError ??= e;
      }
      expect(
        firstError,
        isNull,
        reason: 'Sheet overflow at $device, textScale ${scale}x:\n$firstError',
      );

      // Dismiss and settle so timers/animation controllers are disposed before
      // the next combination reuses the tester.
      Navigator.of(hostContext).pop();
      await tester.pumpAndSettle();
    }
  }

  await tester.pumpWidget(const SizedBox.shrink());
}

List<GameReviewItem> _reviewItems() => [
      const GameReviewItem(
        wordEnglish: 'Grandmother',
        wordFilipino: 'Lola',
        category: FlashcardCategory.familyAndGreetings,
        isCorrect: true,
      ),
      // A wrong answer with a deliberately long user response — the classic
      // place the "Your answer:" row overflows horizontally on a narrow tablet.
      const GameReviewItem(
        wordEnglish: 'Congratulations',
        wordFilipino: 'Maligayang bati',
        category: FlashcardCategory.familyAndGreetings,
        isCorrect: false,
        userAnswer: 'a very long wrong answer that should never overflow',
      ),
    ];

void main() {
  // ─── Pure widgets (no Navigator needed) ──────────────────────────

  testWidgets('GameResultDialog (perfect score) survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const GameResultDialog(
        score: 9999,
        total: 9999,
        starsEarned: 3,
        onPlayAgain: _noop,
        onExit: _noop,
        onReview: _noop,
      ),
      // The reveal staggers entrance effects up to ~1.8s; settle past that so
      // its one-shot timers fire before the harness unmounts the tree.
      settleDuration: const Duration(seconds: 2),
    );
  });

  testWidgets('GameResultDialog (keep-practicing tier) survives the matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const GameResultDialog(
        score: 1,
        total: 20,
        starsEarned: 0,
        onPlayAgain: _noop,
        onExit: _noop,
      ),
      settleDuration: const Duration(seconds: 2),
    );
  });

  testWidgets('AnimatedScoreReveal survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const AnimatedScoreReveal(
        score: 7,
        total: 10,
        rating: 2,
        starsEarned: 2,
        onPlayAgain: _noop,
        onExit: _noop,
        onReview: _noop,
      ),
      settleDuration: const Duration(seconds: 2),
    );
  });

  testWidgets('AnimatedScoreDisplay survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: AnimatedScoreDisplay(score: 9999, total: 9999),
      ),
    );
  });

  testWidgets('GameTimerWidget survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const GameTimerWidget(remainingSeconds: 999, totalSeconds: 999),
    );
  });

  testWidgets('StarRating survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: StarRating(stars: 2),
      ),
    );
  });

  // ─── Modal sheets (need a Navigator) ─────────────────────────────

  testWidgets('Difficulty picker sheet never overflows', (tester) async {
    await _expectSheetNoOverflow(
      tester,
      (context) => showDifficultyPicker(context, GameType.wordMatch),
    );
  });

  testWidgets('Category picker sheet never overflows', (tester) async {
    await _expectSheetNoOverflow(
      tester,
      (context) => showCategoryPicker(context),
    );
  });

  testWidgets('Game review sheet (long wrong answer) never overflows',
      (tester) async {
    await _expectSheetNoOverflow(
      tester,
      (context) => showGameReview(
        context,
        items: _reviewItems(),
        gameTitle: 'Word Match',
      ),
    );
  });
}
