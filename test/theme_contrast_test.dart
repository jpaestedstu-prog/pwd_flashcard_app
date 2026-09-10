import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/widgets/app_card.dart';

/// WCAG contrast for the colour pairs the app actually paints.
///
/// This app is built for learners who include the low-vision and dyslexic, so a
/// caption below the 4.5:1 AA floor is a defect rather than a style preference.
/// The light theme shipped two: `textSecondary` at 3.15:1 on the cream
/// background (706 usages — every subtitle and caption in the app) and
/// `textHint` at 1.77:1 (132 usages, on real form labels rather than only
/// disabled controls). The dyslexia theme's hint was 3.36:1.
///
/// Colours are read through `HCColor.of(context)` under each real `ThemeData`,
/// so this checks what renders rather than what the token table says. Comparing
/// raw `AppColors` constants instead would pair light-theme text against
/// high-contrast grounds, which never happens: high contrast swaps both sides.

double _channel(double c) {
  final v = c / 255.0;
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) {
  final r = _channel((c.r * 255).roundToDouble());
  final g = _channel((c.g * 255).roundToDouble());
  final b = _channel((c.b * 255).roundToDouble());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// AA for body text. Large text may use 3.0, but these tokens are used for body
/// copy, so the stricter floor is the right one.
const double kAaBody = 4.5;

void main() {
  // Building a ThemeData reaches ServicesBinding (the fonts), so the binding
  // has to exist before the theme getters are touched — and the map has to be
  // lazy, or it is evaluated at file load, before this line runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
    'high contrast': () => AppTheme.highContrast,
    'dyslexia': () => AppTheme.dyslexia,
  };

  for (final entry in themes.entries) {
    testWidgets('${entry.key} theme meets AA for body text', (tester) async {
      late HCColor hc;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value(),
          home: Builder(
            builder: (context) {
              hc = HCColor.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final grounds = <String, Color>{
        'background': hc.background,
        'surface': hc.surface,
      };
      final texts = <String, Color>{
        'textPrimary': hc.textPrimary,
        'textSecondary': hc.textSecondary,
        'textHint': hc.textHint,
      };

      final failures = <String>[];
      for (final t in texts.entries) {
        for (final g in grounds.entries) {
          final ratio = contrast(t.value, g.value);
          if (ratio < kAaBody) {
            failures.add('${t.key} on ${g.key}: '
                '${ratio.toStringAsFixed(2)}:1 (needs $kAaBody)');
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason: '${entry.key} theme below WCAG AA:\n  ${failures.join('\n  ')}',
      );
    });
  }

  test('the hierarchy still reads: hint is lighter than secondary', () {
    // Raising both to AA is not enough on its own — if the hint ends up darker
    // than the secondary text, the visual ranking inverts and the screen reads
    // wrongly even though every ratio passes.
    final onCream = contrast(AppColors.textSecondary, AppColors.background);
    final hintOnCream = contrast(AppColors.textHint, AppColors.background);
    expect(
      hintOnCream,
      lessThan(onCream),
      reason: 'textHint should stay a shade lighter than textSecondary',
    );
  });

  /// Every theme has to give a card a visible edge — by *something*.
  ///
  /// The three light-ish themes separate the card from the ground with
  /// `softShadow`, and that is legitimate: a shadow is a real boundary even
  /// though its contrast ratio is low by nature, so a 3:1 floor is the wrong
  /// instrument for it. What is never legitimate is an edge drawn by something
  /// invisible, and that is exactly what high contrast shipped: a #1A1A1A card
  /// on a #000000 ground (1.13:1) with a *black* shadow over a black ground,
  /// which composites to the ground exactly and contributes nothing. The card
  /// had no boundary at all, in the one theme built for low vision.
  ///
  /// So the rule below is binary rather than a tuned threshold: a fill or
  /// border may carry the edge if it clears 3:1 (WCAG 1.4.11), or a shadow may
  /// carry it if compositing it over the ground actually changes the ground.
  /// This pumps a real `AppCard` under each real theme and reads the decoration
  /// it resolved, so it tests the rendered edge, not the token table.
  const double kAaNonText = 3.0;

  // Only the shipping configuration is asserted. `AppCard.elevated` defaults
  // to true and no caller in lib/ passes false, so a flat card is a shape the
  // app never renders — and if one ever did, dropping the shadow would be the
  // caller's deliberate choice for a card already sitting on its own ground.
  for (final entry in themes.entries) {
    testWidgets('${entry.key} theme gives a card a visible edge',
        (tester) async {
        final theme = entry.value();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: AppCard(child: Text('card')),
            ),
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(AppCard),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        final ground = theme.scaffoldBackgroundColor;

        final fill = decoration.color;
        final side = decoration.border?.top;
        final shadow = decoration.boxShadow?.firstOrNull;

        final fillRatio = fill == null ? 0.0 : contrast(fill, ground);
        final borderRatio = side == null || side.style == BorderStyle.none
            ? 0.0
            : contrast(side.color, ground);
        final shadowShows =
            shadow != null && Color.alphaBlend(shadow.color, ground) != ground;

        expect(
          fillRatio >= kAaNonText || borderRatio >= kAaNonText || shadowShows,
          isTrue,
          reason: '${entry.key}: a card has no visible boundary '
              '— fill ${fillRatio.toStringAsFixed(2)}:1, border '
              '${borderRatio.toStringAsFixed(2)}:1 (either needs $kAaNonText:1) '
              'and its shadow ${shadow == null ? "is absent" : "vanishes into "
                  "the background"}',
      );
    });
  }

  testWidgets('the high-contrast outline costs a card no layout space',
      (tester) async {
    // The outline is only safe if it is free. `Container` adds
    // `decoration.padding` to its child, and for a border that is the stroke
    // width — so an inside-aligned 2px outline would silently shrink every
    // card's content box by 4px in each axis, under the one theme no overflow
    // test covers and at the 1.4x text scale the Visual Impairment preset
    // sets. Aligning the stroke outside is supposed to zero that out.
    //
    // Two traps sit in the way of measuring this. What is measured has to be
    // the *content box*, not the child: a Text sizes to its glyphs and stays
    // the same width whether or not the box around it shrank, so it reports
    // nothing — a LayoutBuilder reads the constraints the card actually hands
    // down, which is the quantity at risk. And `MaterialApp` wraps the tree in
    // an `AnimatedTheme`, so pumping a second theme into a live tree keeps
    // rendering the first one for the length of the transition; without the
    // settle below, both measurements below are the light theme and the test
    // passes no matter what the border does.
    Future<double> contentWidth(ThemeData theme) async {
      late double width;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AppCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      width = constraints.maxWidth;
                      return const SizedBox(height: 20);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return width;
    }

    expect(
      await contentWidth(AppTheme.highContrast),
      await contentWidth(AppTheme.light),
      reason: 'the high-contrast outline is eating into the card content box',
    );
  });
}
