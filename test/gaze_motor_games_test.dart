import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/games/screens/memory_match_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/pronunciation_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/sentence_builder_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/spelling_bee_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/word_match_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_scope.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// `GameCatalog._motor` offers a Motor Impairment learner ten games *by name*,
/// so each of them has to be playable without tapping. Word Match and Memory
/// Match were two of the six that were not: they had no gaze wiring at all, so
/// a learner could open a game chosen for their disability and then not play
/// it. These pin the hands-free controls onto both.

/// Gaze on, but no camera in the harness — the screens build their
/// `GazeScope` unconditionally, so the wiring is inspectable either way.
class _GazeOn extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

class _GazeOff extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings();
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/gaze_motor_games');
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
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  Future<List<GazeAction>> actionsFor(
    WidgetTester tester,
    Widget screen, {
    bool gazeOn = true,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gazeSettingsProvider.overrideWith(gazeOn ? _GazeOn.new : _GazeOff.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pump();
    return tester.widget<GazeScope>(find.byType(GazeScope)).actions;
  }

  group('Word Match is playable hands-free', () {
    testWidgets('offers move-left, move-right and choose', (tester) async {
      final actions = await actionsFor(
        tester,
        const WordMatchScreen(difficulty: GameDifficulty.hard),
      );

      expect(actions.map((a) => a.zone),
          containsAll([GazeZone.left, GazeZone.right, GazeZone.down]));
      final choose =
          actions.firstWhere((a) => a.zone == GazeZone.down);
      expect(choose.label, 'Choose');
      // Every control is live on a fresh, unanswered round.
      expect(actions.every((a) => a.enabled), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('is a pure pass-through when Gaze Control is off',
        (tester) async {
      final actions = await actionsFor(
        tester,
        const WordMatchScreen(difficulty: GameDifficulty.hard),
        gazeOn: false,
      );
      // The scope is still in the tree (it is inert, not conditional), and the
      // screen renders normally.
      expect(actions, isNotEmpty);
      expect(find.byType(WordMatchScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Sentence Builder is playable hands-free', () {
    testWidgets('offers move-left, move-right and choose', (tester) async {
      final actions = await actionsFor(
        tester,
        const SentenceBuilderScreen(difficulty: GameDifficulty.hard),
      );

      expect(actions.map((a) => a.zone),
          containsAll([GazeZone.left, GazeZone.right, GazeZone.down]));
      expect(actions.firstWhere((a) => a.zone == GazeZone.down).label,
          'Choose');
      expect(actions.every((a) => a.enabled), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Memory Match is playable hands-free', () {
    testWidgets('offers move-left, move-right and flip', (tester) async {
      final actions = await actionsFor(
        tester,
        const MemoryMatchScreen(difficulty: GameDifficulty.hard),
      );

      expect(actions.map((a) => a.zone),
          containsAll([GazeZone.left, GazeZone.right, GazeZone.down]));
      final flip = actions.firstWhere((a) => a.zone == GazeZone.down);
      expect(flip.label, 'Flip');
      expect(actions.every((a) => a.enabled), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Pronunciation is playable hands-free', () {
    testWidgets('offers the tapped-answer fallback plus hear-it',
        (tester) async {
      final actions = await actionsFor(
        tester,
        const PronunciationScreen(difficulty: GameDifficulty.hard),
      );

      // Speaking is the headline interaction, but a motor disability can
      // affect speech too — the multiple-choice fallback must be reachable.
      expect(actions.firstWhere((a) => a.zone == GazeZone.down).label,
          'Choose');
      expect(actions.firstWhere((a) => a.zone == GazeZone.up).label, 'Hear it');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Spelling Bee is playable hands-free', () {
    testWidgets('offers place and undo over the letter bank', (tester) async {
      final actions = await actionsFor(
        tester,
        const SpellingBeeScreen(difficulty: GameDifficulty.hard),
      );

      expect(actions.firstWhere((a) => a.zone == GazeZone.down).label, 'Place');
      final undo = actions.firstWhere((a) => a.zone == GazeZone.up);
      expect(undo.label, 'Undo');
      // Nothing placed yet, so there is nothing to take back.
      expect(undo.enabled, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
