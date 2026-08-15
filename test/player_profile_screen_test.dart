import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamification/screens/gamification_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/xp_level_bar.dart';

import 'support/device_matrix.dart';

/// The Player Profile is one of the few screens a learner opens purely for
/// encouragement, so it has to survive every accessibility preset: the theme
/// has to reach it, its labels have to be readable, and a hands-free learner
/// has to be able to operate *and leave* it.

class _StubProfile extends ProfileNotifier {
  _StubProfile(this._role);
  final UserRole _role;
  @override
  UserProfile? build() => UserProfile(
        id: 'learner',
        name: 'Test Learner',
        role: _role,
        createdAt: DateTime(2026),
      );
}

class _FakeProgress extends ProgressNotifier {
  _FakeProgress(this._initial);
  final LearningProgress _initial;
  @override
  LearningProgress build() {
    profileId = _initial.profileId;
    return _initial;
  }
}

/// 30 words, 60 stars, a broken streak with a 14-day best, 43 lifetime games.
/// Deliberately a *legacy-shaped* record too: only 20 entries survive in
/// `recentScores`, so anything reading that list instead of the counter shows
/// 20 and gets caught here.
LearningProgress _sample() => LearningProgress(
      profileId: 'learner',
      wordsLearned: 30,
      totalStars: 60,
      streakDays: 1,
      bestStreakDays: 14,
      gamesPlayed: 43,
      lastActivityDate: DateTime(2026, 8, 6),
      recentScores: [
        for (var i = 0; i < 20; i++)
          GameScore(
            gameType: GameType.wordMatch,
            score: 1,
            total: 1,
            starsEarned: 1,
            date: DateTime(2026, 8, 6),
          ),
      ],
    );

List<Override> _overrides({UserRole role = UserRole.student}) => [
      profileProvider.overrideWith(() => _StubProfile(role)),
      progressProvider.overrideWith(() => _FakeProgress(_sample())),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  ThemeData? theme,
  UserRole role = UserRole.student,
  Size size = const Size(800, 1280),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(role: role),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// Unmounts and drains the mascot's repeating blink timer.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

/// The colour the given text is actually painted in.
Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/player_profile');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('content', () {
    testWidgets('leads with the level and its next goal', (tester) async {
      await _pump(tester, const GamificationDashboardScreen());

      // 30*10 + 60*2 + 14*15 + 43*5 = 845 -> Lv.4 Achiever (600..1000).
      expect(find.byType(XpLevelBar), findsOneWidget);
      expect(find.text('Lv.4 Achiever'), findsOneWidget);
      expect(find.text('245 / 400 XP'), findsOneWidget);
      expect(find.text('155 XP to Lv.5 Scholar'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Games Played is the lifetime count, not the 20-entry window',
        (tester) async {
      await _pump(tester, const GamificationDashboardScreen());

      expect(find.text('43'), findsOneWidget);
      expect(find.text('20'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('a broken streak still shows the personal best', (tester) async {
      await _pump(tester, const GamificationDashboardScreen());

      expect(find.text('Best: 14'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('accessibility themes', () {
    // Every learner preset must reach this screen. It used to render the same
    // pastel-on-white under all of them.
    final themes = <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
      'high contrast': AppTheme.highContrast,
      'dyslexia': AppTheme.dyslexia,
    };

    themes.forEach((name, theme) {
      testWidgets('builds under the $name theme', (tester) async {
        await _pump(tester, const GamificationDashboardScreen(), theme: theme);

        expect(tester.takeException(), isNull);
        expect(find.text('Lv.4 Achiever'), findsOneWidget);

        await _unmount(tester);
      });
    });

    testWidgets('stat accents change with the theme', (tester) async {
      await _pump(tester, const GamificationDashboardScreen());
      final lightStars = _colorOf(tester, '60');
      await _unmount(tester);

      await _pump(tester, const GamificationDashboardScreen(),
          theme: AppTheme.highContrast);
      final hcStars = _colorOf(tester, '60');
      await _unmount(tester);

      expect(lightStars, isNotNull);
      expect(hcStars, isNot(lightStars),
          reason: 'hardcoded Colors.amber ignored the high-contrast preset');
    });

    testWidgets('quick-action labels are theme text, not the accent colour',
        (tester) async {
      // The chips used to paint the label *in* the accent over an 8%-alpha wash
      // of the same accent — "Shop" was orange on almost-white.
      await _pump(tester, const GamificationDashboardScreen());

      final context = tester.element(find.byType(GamificationDashboardScreen));
      final hc = HCColor.of(context);

      for (final label in const ['Leaderboard', 'Shop', 'Progress']) {
        expect(_colorOf(tester, label), hc.textPrimary,
            reason: '$label must use the guaranteed-contrast text colour');
      }

      await _unmount(tester);
    });
  });

  group('hands-free reach', () {
    testWidgets('publishes a gaze cell for every quick action', (tester) async {
      await _pump(tester, const GamificationDashboardScreen());

      final scope = tester.widget<GazeDpadScope>(find.byType(GazeDpadScope));
      final labels = [
        for (final row in scope.rows) ...row.map((c) => c.label),
      ];

      expect(
        labels,
        containsAll(<String>[
          'Leaderboard',
          'Shop',
          'Streak Calendar',
          'Sticker Album',
          'Daily Challenge',
          'Progress',
        ]),
      );

      await _unmount(tester);
    });

    testWidgets('gaze rows mirror the drawn rows', (tester) async {
      // ▲▼ only makes sense if a published row is a row on screen. Both come
      // from the same column count, so a narrow viewport must reshape both.
      await _pump(tester, const GamificationDashboardScreen(),
          size: const Size(360, 900));
      final narrow = tester.widget<GazeDpadScope>(find.byType(GazeDpadScope));
      final narrowWidths = [for (final r in narrow.rows) r.length];
      await _unmount(tester);

      await _pump(tester, const GamificationDashboardScreen(),
          size: const Size(1280, 900));
      final wide = tester.widget<GazeDpadScope>(find.byType(GazeDpadScope));
      final wideWidths = [for (final r in wide.rows) r.length];
      await _unmount(tester);

      expect(narrowWidths.first, lessThanOrEqualTo(wideWidths.first));
      expect(narrowWidths.fold<int>(0, (a, b) => a + b), 6);
      expect(wideWidths.fold<int>(0, (a, b) => a + b), 6);
    });

    testWidgets('offers a hands-free way out', (tester) async {
      // Without an exit row the screen is a room with no door: a learner who
      // cannot touch also cannot reach the app bar's back arrow.
      await _pump(tester, const GamificationDashboardScreen());

      final scope = tester.widget<GazeDpadScope>(find.byType(GazeDpadScope));
      expect(scope.onExit, isNotNull);

      await _unmount(tester);
    });
  });

  group('Child access', () {
    testWidgets('Child home offers a My Player Card tile', (tester) async {
      await _pump(tester, const ChildHomeScreen(), role: UserRole.child);

      // "Rewards & Feelings" is the last section of a lazy CustomScrollView.
      await tester.dragUntilVisible(
        find.text('My Player Card'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );

      expect(find.text('My Player Card'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('layout', () {
    testWidgets('action chips in a row share one width', (tester) async {
      // A Stack hands its non-positioned children *loose* constraints, so the
      // chip used to shrink-wrap its label: "Shop" drew half the width of
      // "Streak Calendar" beside it. Nothing overflowed, so the size matrix
      // could not see it — only measuring can.
      await _pump(tester, const GamificationDashboardScreen(),
          size: const Size(1200, 1600));

      final widths = <double>[];
      for (final label in const ['Leaderboard', 'Shop', 'Streak Calendar']) {
        widths.add(tester
            .getSize(find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                )
                .first)
            .width);
      }

      expect(widths.toSet(), hasLength(1),
          reason: 'chips in one row must be equal width, got $widths');

      await _unmount(tester);
    });

    // "Leaderboard" wrapped to "Leaderboa / rd" when the action grid borrowed
    // the (tighter) stat-tile column width. The worst case is the smallest
    // phone at the largest font, where the grid has to fall to one chip a row.
    for (final (size, scale) in const [
      (Size(1200, 1600), 1.0),
      (Size(360, 640), 2.0),
    ]) {
      testWidgets(
          'chip labels never break mid-word at ${size.width.toInt()}dp '
          '@ ${scale}x text', (tester) async {
        await _pump(tester, const GamificationDashboardScreen(),
            size: size, textScale: scale);

        final rendered = tester.renderObject<RenderBox>(
          find.text('Leaderboard'),
        );
        final oneLine = TextPainter(
          text: TextSpan(
            text: 'Leaderboard',
            style: tester.widget<Text>(find.text('Leaderboard')).style,
          ),
          textScaler: TextScaler.linear(scale),
          textDirection: TextDirection.ltr,
        )..layout();

        expect(rendered.size.width, greaterThanOrEqualTo(oneLine.width - 1),
            reason: 'the chip is narrower than its own single-line label');

        await _unmount(tester);
      });
    }

    // The stat grid used to hardcode "always three across", which at 2x font on
    // a 360dp phone left each tile ~97dp for a title-large number.
    for (final device in kTabletMatrix) {
      for (final scale in kTextScales) {
        testWidgets('no overflow at $device @ ${scale}x text', (tester) async {
          await _pump(
            tester,
            const GamificationDashboardScreen(),
            size: device.size,
            textScale: scale,
          );

          Object? first;
          for (Object? e = tester.takeException();
              e != null;
              e = tester.takeException()) {
            first ??= e;
          }
          expect(first, isNull, reason: 'overflow at $device @ ${scale}x');

          await _unmount(tester);
        });
      }
    }
  });
}
