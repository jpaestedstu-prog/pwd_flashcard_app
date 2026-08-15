import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/xp_level_bar.dart';

/// What the Progress tab shows, for each of the profile families that share it
/// — Player (With Progress), Student, and Child, across every accessibility
/// category.
///
/// The device matrix in `feature_screens_overflow_test` pumps a single frame,
/// which is *before* the staggered entrance animations reveal the lower
/// sections — so it cannot see either their content or their layout. These
/// tests pump past the stagger and then measure, per [[overflow-test-matrix]].
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role, this._type, {this.guest = false});
  final UserRole _role;
  final DisabilityType _type;
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
    id: 'test-profile',
    name: 'Test User',
    role: _role,
    disabilityType: _type,
    isGuestPlayer: guest,
    createdAt: DateTime(2026),
  );
}

class _StubProgressNotifier extends ProgressNotifier {
  _StubProgressNotifier(this._progress);
  final LearningProgress _progress;

  @override
  LearningProgress build() => _progress;
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Flexes whose children need more main-axis room than they were given.
///
/// Measured rather than read off `takeException()`: Flutter reports a
/// RenderFlex overflow from `paint()`, and a section still behind a
/// `flutter_animate` fade is laid out but never painted, so it overflows in
/// total silence.
List<String> _overflowingFlexes(WidgetTester tester) {
  final offenders = <String>[];
  for (final node in tester.allRenderObjects.whereType<RenderFlex>()) {
    if (!node.hasSize || node.debugNeedsLayout) continue;
    final vertical = node.direction == Axis.vertical;
    final available = vertical
        ? node.constraints.maxHeight
        : node.constraints.maxWidth;
    if (!available.isFinite) continue;

    var needed = 0.0;
    for (
      RenderBox? child = node.firstChild;
      child != null;
      child = node.childAfter(child)
    ) {
      needed += vertical ? child.size.height : child.size.width;
    }
    if (needed - available > 0.5) {
      offenders.add(
        '  ${vertical ? "Column" : "Row"} needs ${needed.toStringAsFixed(1)} px '
        'in ${available.toStringAsFixed(1)} px',
      );
    }
  }
  return offenders;
}

void main() {
  /// A learner far enough along that every section has something to draw.
  LearningProgress busyLearner() => LearningProgress(
    profileId: 'test-profile',
    lastActivityDate: DateTime.now(),
    wordsLearned: 40,
    streakDays: 2,
    bestStreakDays: 21,
    totalStars: 64,
    spentStars: 20,
    gamesPlayed: 37,
    playedGameTypes: const {
      GameType.wordMatch,
      GameType.memoryMatch,
      GameType.yesOrNo,
    },
    completedStoryIds: const {'s1', 's2', 's3'},
    storyBestStars: const {'s1': 3, 's2': 2, 's3': 3},
    signedWordKeys: const {'a', 'b', 'c'},
    canSignKeys: const {'a', 'b'},
    everConfirmedSignKeys: const {'a'},
    recentScores: [
      GameScore(
        gameType: GameType.wordMatch,
        score: 4,
        total: 5,
        starsEarned: 2,
        date: DateTime.now(),
      ),
    ],
  );

  setUpAll(() async {
    Hive.init('./build/test_cache/progress_screen');
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
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpProgress(
    WidgetTester tester, {
    required UserRole role,
    DisabilityType type = DisabilityType.none,
    bool guest = false,
    LearningProgress? progress,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    String locale = 'en',
    AppSettings? settings,
  }) async {
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            () => _StubProfileNotifier(role, type, guest: guest),
          ),
          progressProvider.overrideWith(
            () => _StubProgressNotifier(progress ?? busyLearner()),
          ),
          // The real profile of this type would carry its accessibility
          // preset, so the policy sees what a real learner's would.
          settingsProvider.overrideWith(
            () => _StubSettingsNotifier(
              settings ?? AccessibilityPresets.presetFor(type),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ProgressScreen(),
        ),
      ),
    );
    // Past every staggered `delay:` so the lower sections are actually built.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets flutter_animate's one-shot entrance timers fire.
  ///
  /// Scrolling builds fresh sliver children, and each `.animate()` starts a
  /// timer in `initState`, so a test that scrolls and then ends trips the
  /// "Timer is still pending after the widget tree was disposed" invariant
  /// even though nothing is wrong with the screen.
  Future<void> flushEntranceTimers(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls down until [target] is on screen, flushing the entrance
  /// animations of everything built on the way.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 15 && target.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -300),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    await flushEntranceTimers(tester);
  }

  /// Scrolls the whole screen so lazily-built slivers are laid out, measuring
  /// as it goes.
  Future<void> expectNoOverflowWhileScrolling(
    WidgetTester tester,
    String label,
  ) async {
    for (var i = 0; i < 12; i++) {
      expect(
        _overflowingFlexes(tester),
        isEmpty,
        reason: '$label overflows after ${i * 400} px of scroll',
      );
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    await flushEntranceTimers(tester);
  }

  group('the level reaches the tab named Progress', () {
    testWidgets('Student sees their level', (tester) async {
      await pumpProgress(tester, role: UserRole.student);
      expect(find.byType(XpLevelBar), findsOneWidget);
    });

    testWidgets('Player (With Progress) sees their level', (tester) async {
      await pumpProgress(tester, role: UserRole.player);
      expect(find.byType(XpLevelBar), findsOneWidget);
    });

    testWidgets('Child sees their level', (tester) async {
      await pumpProgress(tester, role: UserRole.child);
      expect(find.byType(XpLevelBar), findsOneWidget);
    });
  });

  group('records that cannot be taken away are shown', () {
    testWidgets('the best streak appears once the current run falls behind', (
      tester,
    ) async {
      await pumpProgress(tester, role: UserRole.student);
      expect(find.text('best 21'), findsOneWidget);
    });

    testWidgets('an unbroken streak does not repeat itself', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        progress: LearningProgress(
          profileId: 'test-profile',
          lastActivityDate: DateTime.now(),
          streakDays: 5,
          bestStreakDays: 5,
        ),
      );
      expect(find.text('days'), findsOneWidget);
      expect(find.textContaining('best'), findsNothing);
    });

    testWidgets('spendable stars are named apart from lifetime stars', (
      tester,
    ) async {
      await pumpProgress(tester, role: UserRole.student);
      // 64 earned, 20 spent.
      expect(find.text('64'), findsOneWidget);
      expect(find.text('44 left'), findsOneWidget);
    });

    testWidgets('lifetime games are shown, not just the last ten', (
      tester,
    ) async {
      await pumpProgress(tester, role: UserRole.student);
      expect(find.text('37'), findsOneWidget);
    });
  });

  group('reading progress has a home', () {
    testWidgets('stories read and 3-star quizzes are shown', (tester) async {
      await pumpProgress(tester, role: UserRole.student);
      await scrollTo(tester, find.text('Stories read'));

      expect(find.text('Stories read'), findsOneWidget);
      expect(find.text('3-star quizzes'), findsOneWidget);
      // 3 stories finished, 2 of them at 3 stars.
      expect(find.text('3'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });
  });

  group('sign progress follows the accessibility content policy', () {
    testWidgets('a Deaf learner sees what they can produce, not just watch', (
      tester,
    ) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.hearing,
      );
      await scrollTo(tester, find.text('I can sign'));

      expect(find.text('I can sign'), findsOneWidget);
      expect(find.text('Teacher confirmed'), findsOneWidget);
    });

    for (final type in const [
      DisabilityType.visual,
      DisabilityType.cognitive,
    ]) {
      testWidgets('${type.name} learners are not shown a sign section', (
        tester,
      ) async {
        await pumpProgress(tester, role: UserRole.student, type: type);
        for (var i = 0; i < 10; i++) {
          expect(find.text('Sign Language'), findsNothing);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
            warnIfMissed: false,
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        await flushEntranceTimers(tester);
      });
    }
  });

  group('the page adapts to the learner', () {
    testWidgets('a cognitive learner gets the short page', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.cognitive,
      );

      // Scroll the whole page; none of the long-form sections appear.
      for (var i = 0; i < 12; i++) {
        expect(find.text('Star Collection'), findsNothing);
        expect(find.text('This Week'), findsNothing);
        expect(find.text('Detailed Analytics'), findsNothing);
        expect(find.text('Learning Insights'), findsNothing);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await flushEntranceTimers(tester);
    });

    testWidgets('a learner on the full page gets all of it', (tester) async {
      await pumpProgress(tester, role: UserRole.student);
      await scrollTo(tester, find.text('Star Collection'));
      expect(find.text('Star Collection'), findsOneWidget);
    });

    testWidgets('the short page counts badges instead of greying them out', (
      tester,
    ) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.cognitive,
      );
      await scrollTo(tester, find.textContaining('earned'));
      expect(find.textContaining('earned'), findsOneWidget);
    });

    testWidgets('a Deaf learner sees signing before reading', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.hearing,
      );
      await scrollTo(tester, find.text('Stories read'));

      final signY = tester.getTopLeft(find.text('I can sign')).dy;
      final readY = tester.getTopLeft(find.text('Stories read')).dy;
      expect(
        signY,
        lessThan(readY),
        reason: 'sign production is the headline for a Deaf learner',
      );
    });

    testWidgets('reading leads for everyone else', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.motor,
      );
      await scrollTo(tester, find.text('I can sign'));

      final signY = tester.getTopLeft(find.text('I can sign')).dy;
      final readY = tester.getTopLeft(find.text('Stories read')).dy;
      expect(readY, lessThan(signY));
    });
  });

  group('the spoken summary', () {
    testWidgets('is offered to a low-vision learner', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.visual,
      );
      expect(find.text('Hear my progress'), findsOneWidget);
    });

    testWidgets('is not offered to a Deaf learner', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.hearing,
      );
      expect(find.text('Hear my progress'), findsNothing);
    });

    testWidgets('tapping it does not throw', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.student,
        type: DisabilityType.visual,
      );
      await tester.tap(find.text('Hear my progress'));
      await tester.pump();
      await flushEntranceTimers(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('This Week', () {
    testWidgets('says so in words when the week is empty', (tester) async {
      await pumpProgress(tester, role: UserRole.student);
      await scrollTo(tester, find.text('This Week'));
      // The stub learner has no ledger rows, so the section must not show
      // four zeros — that reads as failure rather than "not yet".
      expect(find.textContaining('Nothing yet this week'), findsOneWidget);
    });

    testWidgets('is reachable for a Player with progress', (tester) async {
      await pumpProgress(tester, role: UserRole.player);
      await scrollTo(tester, find.text('This Week'));
      expect(find.text('This Week'), findsOneWidget);
    });
  });

  group('Learning Insights', () {
    testWidgets('has a button at last', (tester) async {
      await pumpProgress(tester, role: UserRole.student);
      await scrollTo(tester, find.text('Learning Insights'));
      expect(find.text('Learning Insights'), findsOneWidget);
    });

    testWidgets('is not offered to a Player', (tester) async {
      await pumpProgress(tester, role: UserRole.player);
      for (var i = 0; i < 10; i++) {
        expect(find.text('Learning Insights'), findsNothing);
        expect(find.text('Detailed Analytics'), findsNothing);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await flushEntranceTimers(tester);
    });
  });

  group('localization', () {
    testWidgets('the tab renders in Filipino', (tester) async {
      await pumpProgress(tester, role: UserRole.student, locale: 'fil');
      expect(find.text('Sunod-sunod'), findsOneWidget); // Streak
      expect(find.text('Mga Laro'), findsOneWidget); // Games
      expect(find.text('Kabihasaan'), findsOneWidget); // Mastery
      expect(find.textContaining('Progreso ni'), findsOneWidget);
    });

    testWidgets('the sections below the fold are translated too', (
      tester,
    ) async {
      await pumpProgress(tester, role: UserRole.student, locale: 'fil');
      await scrollTo(tester, find.text('Pagbasa'));
      expect(find.text('Pagbasa'), findsOneWidget); // Reading
      expect(find.text('Nabasang kuwento'), findsOneWidget); // Stories read
    });
  });

  group('reduced motion', () {
    testWidgets('shows the whole page on the first frame', (tester) async {
      // With motion off the staggered delays collapse to zero, so nothing is
      // waiting behind an animation to appear.
      await pumpProgress(
        tester,
        role: UserRole.student,
        settings: const AppSettings(reducedMotion: true),
      );
      expect(find.byType(XpLevelBar), findsOneWidget);
    });
  });

  group('the new sections lay out on the worst case', () {
    // 2.0x font on a 360x640 phone is where the app's large-accessibility-font
    // layouts break first.
    for (final type in DisabilityType.values) {
      testWidgets('${type.name} student at 360x640 @ 2.0x', (tester) async {
        await pumpProgress(
          tester,
          role: UserRole.student,
          type: type,
          size: const Size(360, 640),
          textScale: 2.0,
        );
        await expectNoOverflowWhileScrolling(tester, '${type.name} student');
      });
    }

    testWidgets('Player (With Progress) at 360x640 @ 2.0x', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.player,
        size: const Size(360, 640),
        textScale: 2.0,
      );
      await expectNoOverflowWhileScrolling(tester, 'player');
    });

    testWidgets('Child at 360x640 @ 2.0x', (tester) async {
      await pumpProgress(
        tester,
        role: UserRole.child,
        size: const Size(360, 640),
        textScale: 2.0,
      );
      await expectNoOverflowWhileScrolling(tester, 'child');
    });
  });
}
