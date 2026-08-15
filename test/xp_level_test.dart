import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/xp_level_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/level_up_provider.dart';
import 'package:pwdpwdpwd/widgets/xp_level_bar.dart';

/// The level economy behind the Player Profile and the home XP bar.
///
/// The rule these tests exist to hold is **XP never falls**. Every input to
/// [XpService.calculateXp] must be monotonic, because a learner who loses a
/// level is being punished — and two of the original inputs did exactly that:
/// `streakDays` resets to 1 on a missed day, and `recentScores` is trimmed to
/// the last 20 entries.

LearningProgress _progress({
  String profileId = 'learner',
  int words = 0,
  int stars = 0,
  int streak = 0,
  int bestStreak = 0,
  int games = 0,
  int recentScores = 0,
}) =>
    LearningProgress(
      profileId: profileId,
      wordsLearned: words,
      totalStars: stars,
      streakDays: streak,
      bestStreakDays: bestStreak,
      gamesPlayed: games,
      lastActivityDate: DateTime(2026, 8, 6),
      recentScores: [
        for (var i = 0; i < recentScores; i++)
          GameScore(
            gameType: GameType.wordMatch,
            score: 1,
            total: 1,
            starsEarned: 1,
            date: DateTime(2026, 8, 6),
          ),
      ],
    );

/// Feeds [XpLevelBar] a fixed progress record with no Hive or Firebase behind
/// it, at the given text scale.
Widget _barHarness(LearningProgress progress,
        {bool showNextGoal = false, double textScale = 1.0}) =>
    ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: XpLevelBar(
                progress: progress,
                showNextGoal: showNextGoal,
              ),
            ),
          ),
        ),
      ),
    );

class _FakeProgress extends ProgressNotifier {
  _FakeProgress(this._initial);
  final LearningProgress _initial;

  @override
  LearningProgress build() {
    // ProgressNotifier declares `late String profileId` and real callers set it
    // in build(). ProfileAvatar reaches for it via getEquippedShopItem, so
    // leaving it unset throws a LateError mid-build.
    profileId = _initial.profileId;
    return _initial;
  }

  void emit(LearningProgress next) => state = next;
}

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

/// Pumps a learner home on a portrait-tablet surface with a fixed progress
/// record, so the level it renders is known.
Future<void> _pumpHome(
  WidgetTester tester,
  Widget home, {
  required UserRole role,
  required LearningProgress progress,
}) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _StubProfile(role)),
        progressProvider.overrideWith(() => _FakeProgress(progress)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// Unmounts and flushes the mascot's repeating blink timer so `testWidgets`
/// ends with no live timers (mirrors test/gaze_hub_coverage_test.dart).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  group('XP is monotonic', () {
    test('breaking a streak does not cost the XP it already earned', () {
      // A fortnight's streak, then two days off sick: streakDays resets to 1
      // but the high-water mark stands.
      final before =
          _progress(words: 30, stars: 60, streak: 14, bestStreak: 14, games: 20);
      final after =
          _progress(words: 30, stars: 60, streak: 1, bestStreak: 14, games: 20);

      expect(XpService.calculateXp(after),
          greaterThanOrEqualTo(XpService.calculateXp(before)));
      expect(XpService.currentLevel(after).level,
          XpService.currentLevel(before).level,
          reason: 'a missed day must never demote a learner');
    });

    test('game XP keeps growing past the 20-entry recentScores window', () {
      // recentScores is capped at 20 by ProgressNotifier.recordGameResult, so
      // XP must be scored off the lifetime counter instead.
      final at20 = _progress(games: 20, recentScores: 20);
      final at100 = _progress(games: 100, recentScores: 20);

      expect(XpService.calculateXp(at100),
          greaterThan(XpService.calculateXp(at20)));
      expect(
        XpService.calculateXp(at100) - XpService.calculateXp(at20),
        80 * 5,
      );
    });

    test('spending stars in the Shop costs no XP', () {
      final earned = _progress(stars: 100);
      final spent = LearningProgress(
        profileId: 'p1',
        totalStars: 100,
        spentStars: 90,
        lastActivityDate: DateTime(2026, 8, 6),
      );
      expect(XpService.calculateXp(spent), XpService.calculateXp(earned));
    });
  });

  group('legacy records heal without a migration pass', () {
    test('a record written before bestStreakDays existed uses its streak', () {
      final legacy = _progress(streak: 9); // bestStreakDays defaults to 0
      expect(legacy.effectiveBestStreak, 9);
      expect(XpService.calculateXp(legacy), 9 * 15);
    });

    test('a record written before gamesPlayed existed uses recentScores', () {
      final legacy = _progress(recentScores: 12); // gamesPlayed defaults to 0
      expect(legacy.effectiveGamesPlayed, 12);
    });

    test('the healed value never undercounts what is already recorded', () {
      // A stale best (writer bug, or a cloud doc that lost the field) must not
      // drag the learner below their current run.
      final drifted = _progress(streak: 20, bestStreak: 3);
      expect(drifted.effectiveBestStreak, 20);
    });

    test('a cloud-restored record with no local scores keeps its game count',
        () {
      // Firestore stores only the trimmed `recent_scores`, so a profile
      // restored on a new device can have a full lifetime count and an empty
      // window. Sticker milestones and every educator dashboard read this.
      final restored = _progress(games: 43);
      expect(restored.recentScores, isEmpty);
      expect(restored.effectiveGamesPlayed, 43);
    });
  });

  group('level bands', () {
    test('xpIntoLevel / xpLevelSpan describe the same bar as the fraction', () {
      // 115 XP sits in the Level 2 band, which runs 100 -> 300.
      final p = _progress(stars: 50, streak: 1, bestStreak: 1);
      expect(XpService.calculateXp(p), 115);
      expect(XpService.currentLevel(p).level, 2);
      expect(XpService.xpIntoLevel(p), 15);
      expect(XpService.xpLevelSpan(p), 200);
      expect(XpService.xpToNextLevel(p), 185);
      expect(
        XpService.progressToNextLevel(p),
        closeTo(15 / 200, 0.0001),
        reason: 'label numerator/denominator must be the bar fraction',
      );
    });

    test('max level reports no next level and a full bar', () {
      final maxed = _progress(words: 1000);
      expect(XpService.nextLevel(maxed), isNull);
      expect(XpService.xpLevelSpan(maxed), isNull);
      expect(XpService.xpToNextLevel(maxed), isNull);
      expect(XpService.progressToNextLevel(maxed), 1.0);
    });
  });

  group('XpLevelBar', () {
    testWidgets('shows band XP, not lifetime XP, next to the bar',
        (tester) async {
      // 115 total XP over a 7.5%-full bar used to read "115 / 300 XP", which
      // looks like 38%.
      await tester
          .pumpWidget(_barHarness(_progress(stars: 50, streak: 1, bestStreak: 1)));

      expect(find.text('15 / 200 XP'), findsOneWidget);
      expect(find.text('115 / 300 XP'), findsNothing);
      expect(find.text('Lv.2 Explorer'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(15 / 200, 0.0001));
    });

    testWidgets('announces lifetime XP and the next level to screen readers',
        (tester) async {
      await tester
          .pumpWidget(_barHarness(_progress(stars: 50, streak: 1, bestStreak: 1)));

      expect(
        find.bySemanticsLabel(
          'Level 2 Explorer, 115 XP total, 185 XP to level 3 Learner',
        ),
        findsOneWidget,
      );
    });

    testWidgets('showNextGoal names the next level', (tester) async {
      await tester.pumpWidget(_barHarness(
        _progress(stars: 50, streak: 1, bestStreak: 1),
        showNextGoal: true,
      ));

      expect(find.text('185 XP to Lv.3 Learner'), findsOneWidget);
    });

    testWidgets('max level swaps the band readout for a total', (tester) async {
      await tester.pumpWidget(_barHarness(_progress(words: 1000)));

      expect(find.text('10000 XP ✨'), findsOneWidget);
      expect(find.text('Lv.10 Grandmaster'), findsOneWidget);
    });

    // The learners this app targets routinely run at 2x font. See the
    // device/textScale matrices in test/support/.
    for (final size in const [Size(360, 640), Size(600, 1024)]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets(
            'lays out without overflow at ${size.width.toInt()}x'
            '${size.height.toInt()} @ ${scale}x text', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_barHarness(
            _progress(words: 40, stars: 60, streak: 3, bestStreak: 14, games: 30),
            showNextGoal: true,
            textScale: scale,
          ));
          await tester.pump();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('levelUpProvider', () {
    test('a genuine climb by the same learner is a level-up', () {
      final fake = _FakeProgress(_progress(profileId: 'p1'));
      final container = ProviderContainer(
        overrides: [progressProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final celebrated = <int>[];
      container.listen<LevelSnapshot>(levelUpProvider, (previous, next) {
        if (next.isLevelUpFrom(previous)) celebrated.add(next.level.level);
      });
      container.read(levelUpProvider);

      fake.emit(_progress(profileId: 'p1', stars: 100)); // 200 XP -> Lv.2
      // Riverpod rebuilds dependents lazily; reading flushes so the listener
      // runs before the assertion (a widget's frame does this in the app).
      container.read(levelUpProvider);
      expect(celebrated, [2]);
    });

    test('switching to a higher-level profile is NOT a level-up', () {
      // progressProvider watches profileProvider, so a switch replaces the whole
      // record in one emission. Without the profile id this looked identical to
      // levelling up four times in a row.
      final fake = _FakeProgress(_progress(profileId: 'p1'));
      final container = ProviderContainer(
        overrides: [progressProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final celebrated = <int>[];
      container.listen<LevelSnapshot>(levelUpProvider, (previous, next) {
        if (next.isLevelUpFrom(previous)) celebrated.add(next.level.level);
      });
      container.read(levelUpProvider);

      fake.emit(_progress(profileId: 'p2', words: 60, stars: 100, games: 20));
      expect(container.read(levelUpProvider).level.level, greaterThan(1));
      expect(celebrated, isEmpty,
          reason: 'the incoming learner earned that level days ago');
    });

    test('the very first snapshot is not a level-up', () {
      final snapshot = LevelSnapshot(
        profileId: 'p1',
        level: XpService.levels.first,
      );
      expect(snapshot.isLevelUpFrom(null), isFalse);
    });
  });

  group('every learner home surfaces the level', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/xp_level');
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

    // 115 XP -> Lv.2 Explorer, 15 into a 200-wide band.
    final sample = _progress(stars: 50, streak: 1, bestStreak: 1);

    testWidgets('Student / Player-with-Progress home', (tester) async {
      await _pumpHome(tester, const HomeScreen(),
          role: UserRole.student, progress: sample);

      expect(find.byType(XpLevelBar), findsOneWidget);
      expect(find.text('Lv.2 Explorer'), findsOneWidget);
      expect(find.text('15 / 200 XP'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Child home', (tester) async {
      // A Child levels up on the same curve and gets the same celebration, but
      // this home had no level surface at all — the overlay was the only place
      // the level was ever named.
      await _pumpHome(tester, const ChildHomeScreen(),
          role: UserRole.child, progress: sample);

      expect(find.byType(XpLevelBar), findsOneWidget);
      expect(find.text('Lv.2 Explorer'), findsOneWidget);
      expect(find.text('15 / 200 XP'), findsOneWidget);

      await _unmount(tester);
    });
  });
}
