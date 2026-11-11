import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/achievements.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings, UserProfile;
import 'package:pwdpwdpwd/features/games/widgets/pause_overlay.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart'
    show DailyLoginRewardDialog;
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_presentation.dart';
import 'package:pwdpwdpwd/features/mood_tracker/widgets/mood_picker.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;
import 'package:pwdpwdpwd/widgets/accessibility_quick_sheet.dart';
import 'package:pwdpwdpwd/widgets/achievement_overlay.dart';
import 'package:pwdpwdpwd/widgets/game_widgets.dart';

import 'support/all_screens.dart';
import 'support/contrast.dart' show appSourceOf;
import 'support/drill_down_screens.dart';
import 'support/real_fonts.dart';

/// No text is cut short with "…", and nothing overflows, on any screen or
/// pop-up the app has — at its largest Font Size (1.5x), scrolled top to
/// bottom, with a thirty-letter name, in English and in Filipino, in the
/// light and the dyslexia themes, on the smallest phone upright and on its
/// side and on a small tablet.
///
/// The survey this was made from found 349 cut texts and 22 overflows (3 Nov):
/// top-bar titles cut to "Progreso ni Visual Impairment St…", a greeting
/// that lost the learner's name, field labels and hints ending in "…", and
/// pop-ups running past a phone's edge. All of them were fixed; this keeps
/// them fixed.
const _longName = 'Josefina Maria Dela Cruz-Reyes';

class _LongNameProfile extends ProfileNotifier {
  _LongNameProfile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
        id: 'sweep-profile',
        name: _longName,
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
      );
}

class _Fil extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

typedef _Open = Future<void> Function(BuildContext context);

/// What the current test found.
final _problems = <String>[];

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
        Stack(children: [
          AchievementUnlockedOverlay(
            achievements: [Achievements.all.first],
            onDismiss: () {},
          ),
        ]),
      ),
  'mood picker': (c) => showModalBottomSheet<void>(
        context: c,
        builder: (_) => SingleChildScrollView(
          child: MoodPicker(
            choices: MoodPresentation.fullChoices,
            showNote: true,
            isFilipino: false,
            onAnswer: (_) {},
          ),
        ),
      ),
  'daily reward': (c) => _page(
        c,
        const Center(
          child: DailyLoginRewardDialog(starsEarned: 10, streakDay: 3),
        ),
      ),
};

const _views = [
  ('phoneP', Size(360, 640)),
  ('phoneL', Size(640, 360)),
  ('tabP', Size(600, 960)),
];

void _collect(WidgetTester tester, String tag, Set<String> seen) {
  // Each cut text once, wherever the scroll found it.
  for (final rp in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (!rp.hasSize || rp.size.isEmpty || !rp.didExceedMaxLines) continue;
    final plain = rp.text
        .toPlainText(includeSemanticsLabels: false)
        .replaceAll('\n', ' / ');
    final creator = rp.debugCreator;
    final where = creator is DebugCreator
        ? appSourceOf(creator.element) ?? '?'
        : '?';
    final key = '$plain|$where';
    if (!seen.add(key)) continue;
    _problems.add('cut: "$plain" ($where)');
  }
}

Future<void> _scrollThrough(
  WidgetTester tester,
  String tag,
  Set<String> seen,
) async {
  final scrollables = find
      .byWidgetPredicate(
        (w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) ==
            Axis.vertical,
      )
      .evaluate()
      .toList();
  for (final e in scrollables.take(3)) {
    final state = (e as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final position = state.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      continue;
    }
    final step = position.viewportDimension * 0.8;
    if (step <= 0) continue;
    for (var i = 1; i <= 12; i++) {
      final target = (step * i).clamp(0.0, position.maxScrollExtent);
      if (!e.mounted) break;
      position.jumpTo(target);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      _collect(tester, tag, seen);
      if (target >= position.maxScrollExtent) break;
    }
  }
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('cut_survey');
  });
  tearDownAll(closeSweepBoxes);

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
  };
  final themes = {
    'light': () => AppTheme.light,
    'dyslexia': () => AppTheme.dyslexia,
  };

  for (final lang in const ['en', 'fil']) {
    for (final (vName, size) in _views) {
      for (final theme in themes.entries) {
        final combo = '$lang $vName ${theme.key}';
        Future<void> run(
          WidgetTester tester,
          String name,
          UserRole role,
          Widget home,
          _Open? open,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final old = FlutterError.onError;
          final overflows = <String>{};
          FlutterError.onError = (d) {
            final m = d.exceptionAsString();
            if (m.contains('overflowed')) {
              overflows.add(m.split('\n').first);
            } else if (!m.contains('No GoRouter')) {
              overflows.add('ERROR ${m.split('\n').first}');
            }
          };
          addTearDown(() => FlutterError.onError = old);
          late BuildContext host;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileProvider.overrideWith(() => _LongNameProfile(role)),
                if (lang == 'fil') settingsProvider.overrideWith(_Fil.new),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.value(),
                locale: Locale(lang),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: open == null
                    ? home
                    : Builder(builder: (context) {
                        host = context;
                        return const Scaffold(body: SizedBox.shrink());
                      }),
              ),
            ),
          );
          if (open != null) open(host).ignore();
          final splash = name == 'SplashScreen';
          for (var t = 0; t < (splash ? 20 : 25); t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final tag = '$name | $combo';
          final seen = <String>{};
          _collect(tester, tag, seen);
          if (!splash) await _scrollThrough(tester, tag, seen);
          for (final o in overflows) {
            _problems.add(o);
          }
          final found = [..._problems];
          _problems.clear();
          expect(found, isEmpty, reason: tag);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 6));
        }

        for (final entry in screens.entries) {
          testWidgets('${entry.key} $combo', (tester) async {
            final (build, role) = entry.value;
            await run(tester, entry.key, role, build(), null);
          });
        }
        for (final entry in _popups.entries) {
          testWidgets('popup ${entry.key} $combo', (tester) async {
            await run(tester, 'popup ${entry.key}', UserRole.student,
                const SizedBox(), entry.value);
          });
        }
      }
    }
  }
}
