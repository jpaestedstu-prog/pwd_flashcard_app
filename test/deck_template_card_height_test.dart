import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/data/deck_template_seed_data.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_template_picker_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// Deck templates: each card is as tall as its words and buttons.
///
/// The grid works the row height out ahead of the layout. It guessed with a
/// measurement of its own whether the two buttons would stack, and the row of
/// buttons decided otherwise: on a phone held sideways (640 x 360) in Filipino
/// at normal text the buttons stacked in a card sized for one row of them. The
/// description was squeezed to nothing and the card overflowed by 4 (the
/// layout matrix, 10 Nov). Every size, text size, language and two themes
/// (the dyslexia theme spaces its letters out): no overflow, and every
/// description shown whole.
class _Language extends SettingsNotifier {
  _Language(this.locale);
  final String locale;

  @override
  AppSettings build() => AppSettings(locale: locale);
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('deck_template_card_height');
  });

  const sizes = <String, Size>{
    'phone': Size(360, 640),
    'phone sideways': Size(640, 360),
    'wide phone sideways': Size(914, 411),
    '7-inch tablet': Size(600, 960),
    'Honor': Size(686, 1097),
    'Honor sideways': Size(1097, 608),
  };
  const scales = [0.85, 1.0, 1.15, 1.3, 1.5];

  // Built inside each test: a theme loads its fonts, which needs the binding.
  for (final (themeName, theme) in [
    ('light', () => AppTheme.light),
    ('dyslexia', () => AppTheme.dyslexia),
  ]) {
    for (final language in const ['fil', 'en']) {
      testWidgets('$themeName, $language: every card holds its words',
          (tester) async {
        final filipino = language == 'fil';
        final descriptions = {
          for (final t in DeckTemplateSeedData.all)
            t.descriptionOf(filipino: filipino),
        };
        final problems = <String>[];
        for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
          for (final scale in scales) {
            if (themeName == 'dyslexia' && scale != 1.0 && scale != 1.5) {
              continue;
            }
            final at = '$sizeName at ${scale}x';
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            final errors = <String>[];
            final old = FlutterError.onError;
            FlutterError.onError =
                (d) => errors.add(d.exceptionAsString().split('\n').first);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(ProviderScope(
              overrides: [
                sweepProfileOverride(UserRole.student),
                settingsProvider.overrideWith(() => _Language(language)),
              ],
              child: MaterialApp(
                theme: theme(),
                locale: Locale(language),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const DeckTemplatePickerScreen(),
              ),
            ));
            for (var t = 0; t < 15; t++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            FlutterError.onError = old;
            for (final e in errors) {
              problems.add('$at: $e');
            }
            // Every description on screen (and built below it) at its full
            // height: a paragraph given less than its lines is cut.
            var seen = 0;
            for (final e in find.byType(RichText).evaluate()) {
              final paragraph = e.renderObject;
              if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
              final text = paragraph.text.toPlainText();
              if (!descriptions.contains(text)) continue;
              seen++;
              final needs =
                  paragraph.getMinIntrinsicHeight(paragraph.size.width);
              if (paragraph.size.height + 0.5 < needs) {
                problems.add('$at: "${text.substring(0, 24)}…" gets '
                    '${paragraph.size.height.toStringAsFixed(1)} of '
                    '${needs.toStringAsFixed(1)}');
              }
            }
            if (seen == 0) problems.add('$at: no description built');
          }
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(problems, isEmpty);
      });
    }
  }
}
