import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_content_policy.dart';
import 'package:pwdpwdpwd/core/accessibility/game_catalog.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// The Games tab is split by accessibility category for the two learner roles
/// that carry one (Student and Child) and combined into a single list for
/// Player profiles. These tests pin both shapes, and the promise that every
/// category is offered exactly ten games.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.role, this.type, {this.guest = false});
  final UserRole role;
  final DisabilityType type;
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: role,
        disabilityType: type,
        isGuestPlayer: guest,
        createdAt: DateTime(2026),
      );
}

/// Gaze on with the tiles reach, so the hub publishes a D-pad cell for every
/// game card it lays out — including cards scrolled off-screen. That makes the
/// published labels an exact, viewport-independent read of the rendered
/// roster, which `find.text` could not give us.
class _GazeTilesOnNotifier extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(
        enabled: true,
        navScope: GazeNavScope.bottomNavAndHomeTiles,
      );
}

Future<List<String>> _pumpHubLabels(
  WidgetTester tester, {
  required UserRole role,
  DisabilityType type = DisabilityType.none,
  bool guest = false,
}) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider
            .overrideWith(() => _StubProfileNotifier(role, type, guest: guest)),
        gazeSettingsProvider.overrideWith(_GazeTilesOnNotifier.new),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameHubScreen(),
      ),
    ),
  );
  await tester.pump();
  return [for (final row in gazeHomeGrid.rows) ...row.map((c) => c.label)];
}

/// Unmounts and flushes the mascot's repeating blink timer so the test ends
/// with no live timers.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  group('GameCatalog rosters', () {
    test('every accessibility category is offered exactly ten games', () {
      for (final type in DisabilityType.values) {
        expect(
          GameCatalog.forCategory(type).length,
          GameCatalog.gamesPerCategory,
          reason: '${type.profileTypeLabel} must offer ten games',
        );
      }
    });

    test('no roster repeats a game', () {
      for (final type in DisabilityType.values) {
        final roster = GameCatalog.forCategory(type);
        expect(
          roster.toSet().length,
          roster.length,
          reason: '${type.profileTypeLabel} lists a game twice',
        );
      }
    });

    test('no roster offers Story Quiz — it lives in the Stories tab', () {
      for (final type in DisabilityType.values) {
        expect(
          GameCatalog.forCategory(type),
          isNot(contains(GameType.storyQuiz)),
          reason: '${type.profileTypeLabel} must not list Story Quiz',
        );
      }
      expect(GameCatalog.combined, isNot(contains(GameType.storyQuiz)));
    });

    test('rosters never contradict AccessibilityContentPolicy', () {
      // The policy still governs FSL and audio surfaces elsewhere in the app
      // (the Cards FSL button, Stories' "Watch in FSL"). If the two ever
      // disagree a learner would be shown a game the rest of the app hides.
      for (final type in DisabilityType.values) {
        final roster = GameCatalog.forCategory(type);
        final policy = AccessibilityContentPolicy.forType(type);
        if (!policy.showFsl) {
          expect(
            roster,
            isNot(contains(GameType.fslPractice)),
            reason: '${type.profileTypeLabel} hides FSL elsewhere',
          );
        }
        if (!policy.showAudioGame) {
          expect(
            roster,
            isNot(contains(GameType.pronunciation)),
            reason: '${type.profileTypeLabel} hides audio-only content',
          );
        }
      }
    });

    test('the categories are meaningfully different from one another', () {
      // The whole point of splitting by category: no two categories may be
      // handed the identical roster, or the split tells the learner nothing.
      final seen = <DisabilityType, Set<GameType>>{
        for (final t in DisabilityType.values)
          t: GameCatalog.forCategory(t).toSet(),
      };
      for (final a in DisabilityType.values) {
        for (final b in DisabilityType.values) {
          if (a == b) continue;
          expect(
            setEquals(seen[a], seen[b]),
            isFalse,
            reason: '${a.profileTypeLabel} and ${b.profileTypeLabel} '
                'have identical rosters',
          );
        }
      }
    });

    test('the combined list holds every hub game, including the new ones', () {
      expect(
        GameCatalog.combined.length,
        GameType.values.length - 1, // every game bar Story Quiz
      );
      expect(
        GameCatalog.combined,
        containsAll(<GameType>[
          GameType.yesOrNo,
          GameType.oddOneOut,
          GameType.firstLetter,
        ]),
      );
    });

    test('every game in the catalog is reachable from some roster', () {
      final rostered = {
        for (final t in DisabilityType.values) ...GameCatalog.forCategory(t),
      };
      expect(
        rostered,
        containsAll(GameCatalog.combined),
        reason: 'a game no category offers can only be found in Player mode',
      );
    });

    test('only Student and Child get a category-split list', () {
      expect(GameCatalog.isCategorised(UserRole.student), isTrue);
      expect(GameCatalog.isCategorised(UserRole.child), isTrue);
      expect(GameCatalog.isCategorised(UserRole.player), isFalse);
      expect(GameCatalog.isCategorised(UserRole.teacher), isFalse);
      expect(GameCatalog.isCategorised(UserRole.parent), isFalse);
      expect(GameCatalog.isCategorised(null), isFalse);
    });
  });

  group('gameHubCatalogProvider', () {
    ProviderContainer containerFor(
      UserRole role,
      DisabilityType type, {
      bool guest = false,
    }) {
      final c = ProviderContainer(overrides: <Override>[
        profileProvider
            .overrideWith(() => _StubProfileNotifier(role, type, guest: guest)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('Student and Child get their own category roster, headed', () {
      for (final role in [UserRole.student, UserRole.child]) {
        for (final type in DisabilityType.values) {
          final catalog =
              containerFor(role, type).read(gameHubCatalogProvider);
          expect(catalog.isCategorised, isTrue);
          expect(catalog.category, type);
          expect(catalog.games, GameCatalog.forCategory(type));
          expect(catalog.games.length, GameCatalog.gamesPerCategory);
        }
      }
    });

    test('both kinds of Player get one combined, unheaded list', () {
      for (final guest in [true, false]) {
        final catalog = containerFor(
          UserRole.player,
          DisabilityType.none,
          guest: guest,
        ).read(gameHubCatalogProvider);
        expect(catalog.isCategorised, isFalse);
        expect(catalog.category, isNull);
        expect(catalog.games, GameCatalog.combined);
      }
    });

    test('a Player carrying a disability type still gets the full list', () {
      // Player Mode has no accessibility category of its own; a stale value on
      // the profile must not quietly re-split their list.
      final catalog = containerFor(UserRole.player, DisabilityType.hearing)
          .read(gameHubCatalogProvider);
      expect(catalog.isCategorised, isFalse);
      expect(catalog.games, GameCatalog.combined);
    });

    test('educators previewing the hub see every game', () {
      for (final role in [UserRole.teacher, UserRole.parent]) {
        final catalog =
            containerFor(role, DisabilityType.none).read(gameHubCatalogProvider);
        expect(catalog.isCategorised, isFalse);
        expect(catalog.games, GameCatalog.combined);
      }
    });
  });

  group('GameHubScreen renders the right list', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/game_catalog');
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

    setUp(() => gazeHomeGrid.clearGrid());

    for (final role in [UserRole.student, UserRole.child]) {
      for (final type in DisabilityType.values) {
        testWidgets(
          '${role.label} / ${type.profileTypeLabel} shows its ten games',
          (tester) async {
            final labels = await _pumpHubLabels(
              tester,
              role: role,
              type: type,
            );
            final expected = GameCatalog.forCategory(type)
                .map((g) => g.label)
                .toList();

            // Play Together heads the hub, then the roster in order.
            expect(labels.first, 'Play Together');
            expect(labels.sublist(1), expected);

            // The heading names the category, so two learners on different
            // categories can tell their Games tabs apart.
            expect(
              find.text(type.profileTypeLabel.toUpperCase()),
              findsOneWidget,
            );
            expect(find.text('10 games picked for you'), findsOneWidget);

            await _unmount(tester);
          },
        );
      }
    }

    testWidgets('Guest Player sees one combined list with no heading',
        (tester) async {
      final labels = await _pumpHubLabels(
        tester,
        role: UserRole.player,
        guest: true,
      );
      expect(labels.first, 'Play Together');
      expect(
        labels.sublist(1),
        GameCatalog.combined.map((g) => g.label).toList(),
      );
      for (final type in DisabilityType.values) {
        expect(find.text(type.profileTypeLabel.toUpperCase()), findsNothing);
      }
      expect(find.text('10 games picked for you'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('Player with progress sees the same combined list',
        (tester) async {
      final labels = await _pumpHubLabels(tester, role: UserRole.player);
      expect(
        labels.sublist(1),
        GameCatalog.combined.map((g) => g.label).toList(),
      );
      expect(find.text('10 games picked for you'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('a Deaf learner is never shown the audio-only game',
        (tester) async {
      final labels = await _pumpHubLabels(
        tester,
        role: UserRole.student,
        type: DisabilityType.hearing,
      );
      expect(labels, isNot(contains(GameType.pronunciation.label)));
      expect(labels, contains(GameType.fslPractice.label));

      await _unmount(tester);
    });

    testWidgets('a blind / low-vision learner is never shown FSL video',
        (tester) async {
      final labels = await _pumpHubLabels(
        tester,
        role: UserRole.student,
        type: DisabilityType.visual,
      );
      expect(labels, isNot(contains(GameType.fslPractice.label)));
      expect(labels, contains(GameType.pronunciation.label));

      await _unmount(tester);
    });

    testWidgets('a motor-impaired learner gets no drag, swipe or trace game',
        (tester) async {
      final labels = await _pumpHubLabels(
        tester,
        role: UserRole.student,
        type: DisabilityType.motor,
      );
      for (final g in [
        GameType.dragAndDrop,
        GameType.tracing,
        GameType.jigsawPuzzle,
        GameType.flashcardQuiz,
      ]) {
        expect(labels, isNot(contains(g.label)), reason: '${g.label} needs a '
            'gesture this learner may not be able to make');
      }

      await _unmount(tester);
    });
  });
}
