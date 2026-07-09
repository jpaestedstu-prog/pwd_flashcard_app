import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/widgets/app_button.dart';
import 'package:pwdpwdpwd/widgets/app_icon_button.dart';
import 'package:pwdpwdpwd/widgets/button_templates.dart';
import 'package:pwdpwdpwd/widgets/shared_widgets.dart';
import 'package:pwdpwdpwd/widgets/square_action_button.dart';

import 'support/device_matrix.dart';

/// Geometric centering regression suite for every shared button primitive.
///
/// For each button type × content variant (text-only, emoji-only,
/// text-and-emoji, icon+text) this renders the button at the app's four Font
/// Size presets — S (0.8), M (1.0), L (1.2), XL (1.5) — and asserts the
/// content's bounding box is centered inside the button both horizontally and
/// vertically. `dart analyze` can't see mis-centering; it only exists at
/// layout time at specific text scales, so it is checked here explicitly.
///
/// The buttons are never tapped, so no Hive write is ever started (see the
/// teardown-hang gotcha documented in test/support notes).

/// The Font Size presets offered by Settings (S / M / L / XL).
const List<double> kFontSizePresets = <double>[0.8, 1.0, 1.2, 1.5];

Rect _union(Iterable<Rect> rects) =>
    rects.reduce((a, b) => a.expandToInclude(b));

/// Renders [builder] centered in the viewport at every Font Size preset and
/// asserts the union of [contents] is centered within [outer] on the
/// requested axes (±[tolerance] logical px for glyph-metric rounding).
Future<void> expectContentCentered(
  WidgetTester tester, {
  required WidgetBuilder builder,
  required Finder Function() outer,
  required List<Finder> Function() contents,
  bool checkHorizontal = true,
  bool checkVertical = true,
  double tolerance = 1.5,
  Size viewport = const Size(800, 1280),
}) async {
  for (final scale in kFontSizePresets) {
    // The production theme matters here: it sets the symmetric button padding
    // that centers Material `.icon` buttons (their bare-Material default
    // padding is asymmetric).
    await pumpResponsive(
      tester,
      Theme(
        data: AppTheme.light,
        child: Center(child: Builder(builder: builder)),
      ),
      size: viewport,
      textScale: scale,
    );
    // Let one-shot entrance animations (fade/scale) reach their resting
    // transform before measuring geometry.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final outerRect = tester.getRect(outer());
    final contentRect =
        _union(contents().map((f) => tester.getRect(f.first)));

    if (checkHorizontal) {
      expect(
        (contentRect.center.dx - outerRect.center.dx).abs(),
        lessThanOrEqualTo(tolerance),
        reason: 'Content not horizontally centered at ${scale}x: '
            'content center ${contentRect.center.dx} vs '
            'button center ${outerRect.center.dx}',
      );
    }
    if (checkVertical) {
      expect(
        (contentRect.center.dy - outerRect.center.dy).abs(),
        lessThanOrEqualTo(tolerance),
        reason: 'Content not vertically centered at ${scale}x: '
            'content center ${contentRect.center.dy} vs '
            'button center ${outerRect.center.dy}',
      );
    }
  }

  // Unmount so repeating tickers (idle pulses etc.) are disposed before the
  // framework's pending-timer teardown check runs.
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  setUpAll(() async {
    // Pressable3D and the shared buttons read reduced-motion / sound settings
    // from the Hive-backed settingsProvider. Settings are per-profile, so
    // settingsProvider also resolves the active profile from 'profiles'.
    Hive.init('./build/test_cache/button_centering');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    if (!Hive.isBoxOpen('profiles')) await Hive.openBox('profiles');
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  group('AppButton', () {
    testWidgets('text-only label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton(label: 'Continue', onPressed: () {}),
        outer: () => find.byType(FilledButton),
        contents: () => [find.text('Continue')],
      );
    });

    testWidgets('emoji-only label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton(label: '🎉', onPressed: () {}),
        outer: () => find.byType(FilledButton),
        contents: () => [find.text('🎉')],
      );
    });

    testWidgets('text-and-emoji label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton(label: '🎉 Play Now', onPressed: () {}),
        outer: () => find.byType(FilledButton),
        contents: () => [find.text('🎉 Play Now')],
      );
    });

    testWidgets('icon + label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton(
          label: 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
        outer: () => find.byType(FilledButton),
        contents: () =>
            [find.byIcon(Icons.play_arrow_rounded), find.text('Play')],
      );
    });

    testWidgets('secondary variant icon + label stays centered',
        (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton.secondary(
          label: 'Cancel',
          icon: Icons.close_rounded,
          onPressed: () {},
        ),
        outer: () => find.byType(OutlinedButton),
        contents: () => [find.byIcon(Icons.close_rounded), find.text('Cancel')],
      );
    });

    testWidgets('tertiary variant label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton.tertiary(label: 'Maybe', onPressed: () {}),
        outer: () => find.byType(FilledButton),
        contents: () => [find.text('Maybe')],
      );
    });

    testWidgets('text variant label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppButton.text(label: 'Skip', onPressed: () {}),
        outer: () => find.byType(TextButton),
        contents: () => [find.text('Skip')],
      );
    });

    testWidgets('fullWidth label stays centered on a narrow phone',
        (tester) async {
      await expectContentCentered(
        tester,
        viewport: const Size(360, 640),
        builder: (_) => SizedBox(
          width: 320,
          child: AppButton(
            label: 'Start Lesson',
            fullWidth: true,
            onPressed: () {},
          ),
        ),
        outer: () => find.byType(FilledButton),
        contents: () => [find.text('Start Lesson')],
      );
    });
  });

  group('AppIconButton', () {
    testWidgets('icon stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AppIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () {},
        ),
        outer: () => find.byType(AppIconButton),
        contents: () => [find.byIcon(Icons.arrow_back_rounded)],
      );
    });
  });

  group('SquareActionButton', () {
    testWidgets('icon and caption stay horizontally centered',
        (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => const SquareActionButton(
          icon: Icons.arrow_forward_rounded,
          label: 'Next',
        ),
        outer: () => find.byType(SquareActionButton),
        contents: () => [find.byIcon(Icons.arrow_forward_rounded)],
        checkVertical: false,
      );
      await expectContentCentered(
        tester,
        builder: (_) => const SquareActionButton(
          icon: Icons.arrow_forward_rounded,
          label: 'Next',
        ),
        outer: () => find.byType(SquareActionButton),
        contents: () => [find.text('Next')],
        checkVertical: false,
      );
    });
  });

  group('FlashcardNavButton', () {
    testWidgets('icon + label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => FlashcardNavButton.next(onPressed: () {}),
        outer: () => find.byType(FlashcardNavButton),
        contents: () =>
            [find.byIcon(Icons.arrow_forward_rounded), find.text('Next')],
      );
    });
  });

  group('GameStartButton', () {
    testWidgets('icon + label stays centered in a fixed-width pill',
        (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => GameStartButton(width: 360, onPressed: () {}),
        outer: () => find.byType(GameStartButton),
        contents: () =>
            [find.byIcon(Icons.play_arrow_rounded), find.text('Start Game')],
      );
    });
  });

  group('RewardFeedbackButton', () {
    testWidgets('icon stays centered in the disc', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => RewardFeedbackButton(onPressed: () {}),
        outer: () => find.byType(RewardFeedbackButton),
        contents: () => [find.byIcon(Icons.star_rounded)],
      );
    });

    testWidgets('labelled variant stays horizontally centered',
        (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) =>
            RewardFeedbackButton.trophy(label: 'Reward', onPressed: () {}),
        outer: () => find.byType(RewardFeedbackButton),
        contents: () =>
            [find.byIcon(Icons.emoji_events_rounded), find.text('Reward')],
        checkVertical: false,
      );
    });
  });

  group('DashboardActionButton', () {
    testWidgets('icon-over-label stays centered', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => DashboardActionButton(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          onPressed: () {},
        ),
        outer: () => find.byType(DashboardActionButton),
        contents: () =>
            [find.byIcon(Icons.bar_chart_rounded), find.text('Reports')],
      );
    });
  });

  group('AnimatedPressButton', () {
    testWidgets('text child stays centered in a fixed box', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AnimatedPressButton(
          width: 300,
          height: 80,
          onPressed: () {},
          child: const Text('Start'),
        ),
        outer: () => find.byType(AnimatedPressButton),
        contents: () => [find.text('Start')],
      );
    });

    testWidgets('emoji child stays centered in a fixed box', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => AnimatedPressButton(
          width: 300,
          height: 80,
          onPressed: () {},
          child: const Text('🎉', style: TextStyle(fontSize: 28)),
        ),
        outer: () => find.byType(AnimatedPressButton),
        contents: () => [find.text('🎉')],
      );
    });

    testWidgets('emoji + text child stays centered in a fixed box',
        (tester) async {
      // Wider fixture than the text-only case: the test (Ahem) font renders
      // every glyph as a full-em square, so a realistic label would overflow
      // a 300px box at 1.5x even though production fonts fit comfortably.
      await expectContentCentered(
        tester,
        builder: (_) => AnimatedPressButton(
          width: 340,
          height: 80,
          onPressed: () {},
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('Play'),
            ],
          ),
        ),
        outer: () => find.byType(AnimatedPressButton),
        contents: () => [find.text('🎉'), find.text('Play')],
      );
    });
  });

  group('EmojiAvatar', () {
    testWidgets('emoji stays centered in the circle', (tester) async {
      await expectContentCentered(
        tester,
        builder: (_) => const EmojiAvatar(emoji: '😊', animate: false),
        outer: () => find.byType(EmojiAvatar),
        contents: () => [find.text('😊')],
      );
    });
  });
}
