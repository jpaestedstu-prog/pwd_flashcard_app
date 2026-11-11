import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider, unlockedAchievementsProvider;

import 'support/all_screens.dart';
import 'support/real_fonts.dart';

/// The badge names at the end of Progress, whole, in the app's own fonts at
/// the largest Font Size (Extra Large, 1.5x) on the tablet.
///
/// Found on the tablet (30 Oct): in Filipino the names split inside a word
/// and were cut short — "Salaman / gkero n…", "Supersta / r", "Nasenyas /
/// an Mo!". The other tests never reached them: the screen-wide checks read
/// what is on screen when a page opens, and the badges are at its end.
class _Filipino extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

bool _isLetter(String c) => RegExp(r'\p{L}', unicode: true).hasMatch(c);

/// Where the lines of [rp] begin, as offsets into its text.
List<int> _lineStarts(RenderParagraph rp, String text) {
  final starts = <int>[];
  double? top;
  for (var i = 0; i < text.length; i++) {
    final boxes = rp.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty) continue;
    if (top == null || boxes.first.top > top + 0.5) {
      if (top != null) starts.add(i);
      top = boxes.first.top;
    }
  }
  return starts;
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('achievement_names');
  });
  tearDownAll(closeSweepBoxes);

  for (final lang in const ['en', 'fil']) {
    testWidgets('$lang: every badge name is whole at Extra Large',
        (tester) async {
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sweepProfileOverride(UserRole.student),
            if (lang == 'fil') settingsProvider.overrideWith(_Filipino.new),
            // One badge earned: with none, the page shows a prompt instead of
            // the badges.
            unlockedAchievementsProvider.overrideWithValue({
              Achievements.all.first.id,
            }),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ProgressScreen(),
          ),
        ),
      );
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // To the badges, at the end of the page.
      final page = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      page.position.jumpTo(page.position.maxScrollExtent);
      for (var t = 0; t < 10; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final names = {
        for (final a in Achievements.all) a.titleOf(filipino: lang == 'fil'),
      };
      final problems = <String>[];
      var seen = 0;
      for (final rp in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      )) {
        final text = rp.text.toPlainText();
        if (!rp.hasSize || !names.contains(text)) continue;
        seen++;
        if (rp.didExceedMaxLines) problems.add('cut short: "$text"');
        for (final at in _lineStarts(rp, text)) {
          if (_isLetter(text[at - 1]) && _isLetter(text[at])) {
            problems.add('split: "${text.substring(0, at)} / '
                '${text.substring(at)}"');
          }
        }
      }
      expect(seen, greaterThan(20), reason: 'the badges were on screen');
      expect(problems, isEmpty, reason: problems.join('\n'));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
