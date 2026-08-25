import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_scope.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/features/multiplayer/screens/local_race_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// `GameCatalog._motor` offers a Motor Impairment learner Play Together by
/// name, so — exactly like Word Match and Memory Match before it — the screen
/// behind that name has to expose hands-free controls. These pin the wiring
/// onto the pass-and-play race: a learner must be able to start a match, play
/// it, and act on the result without a tap.
///
/// Mirrors `gaze_motor_games_test.dart`: gaze on, no camera in the harness,
/// and the assertions read `GazeScope.actions` rather than driving a face.

class _GazeOn extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

class _Profile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'p1',
        name: 'Motor Student',
        role: UserRole.student,
        disabilityType: DisabilityType.motor,
        createdAt: DateTime(2026, 8, 15),
      );
}

Flashcard _card(String id, String en, String fil) => Flashcard(
      id: id,
      wordEnglish: en,
      wordFilipino: fil,
      category: FlashcardCategory.animals,
    );

final _pool = [
  _card('c1', 'dog', 'aso'),
  _card('c2', 'cat', 'pusa'),
  _card('c3', 'bird', 'ibon'),
  _card('c4', 'fish', 'isda'),
  _card('c5', 'horse', 'kabayo'),
  _card('c6', 'pig', 'baboy'),
];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/race_gaze');
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

  Future<void> pumpRace(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gazeSettingsProvider.overrideWith(_GazeOn.new),
        profileProvider.overrideWith(_Profile.new),
        allFlashcardsProvider.overrideWithValue(_pool),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        // The race's pause overlay reads its copy from AppLocalizations.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LocalRaceScreen(mode: MpGameMode.quizRace),
      ),
    ));
    await tester.pump();
  }

  List<GazeAction> actions(WidgetTester tester) =>
      tester.widget<GazeScope>(find.byType(GazeScope)).actions;

  Set<GazeZone> zones(WidgetTester tester) =>
      actions(tester).map((a) => a.zone).toSet();

  testWidgets('the race is wrapped in a single gaze scope', (tester) async {
    await pumpRace(tester);
    expect(find.byType(GazeScope), findsOneWidget,
        reason: 'two scopes would fight over the one camera');
  });

  testWidgets('setup offers a hands-free Start', (tester) async {
    await pumpRace(tester);
    expect(zones(tester), contains(GazeZone.down));
    expect(actions(tester).single.label, 'Start');
  });

  testWidgets('a whole match is reachable without a tap', (tester) async {
    await pumpRace(tester);

    // Setup → intro.
    actions(tester).single.onSelect();
    await tester.pump();
    expect(actions(tester).single.label, 'Start',
        reason: 'the intro still needs one commit to begin the turn');

    // Intro → playing. Now the cursor actions appear.
    actions(tester).single.onSelect();
    await tester.pump();
    expect(zones(tester), {GazeZone.left, GazeZone.right, GazeZone.down});
    expect(
      actions(tester).map((a) => a.label),
      containsAll(<String>['Prev', 'Next', 'Choose']),
    );

    // The player publishes its targets from `build`, so the *enabled* flags
    // land one frame after the phase flips (the callbacks themselves read the
    // cursor live and work immediately — see the "choosing hands-free" test).
    await tester.pump();
    expect(actions(tester).every((a) => a.enabled), isTrue,
        reason: 'a fresh round has somewhere to go and something to choose');
  });

  testWidgets('the move actions stand down while paused', (tester) async {
    await pumpRace(tester);
    actions(tester).single.onSelect(); // start
    await tester.pump();
    actions(tester).single.onSelect(); // begin turn
    await tester.pump();

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(actions(tester).every((a) => !a.enabled), isTrue,
        reason: 'nothing should move behind the pause overlay');
  });

  testWidgets('choosing hands-free answers the round', (tester) async {
    await pumpRace(tester);
    actions(tester).single.onSelect();
    await tester.pump();
    actions(tester).single.onSelect();
    await tester.pump();
    expect(find.text('1/6'), findsOneWidget);

    final choose =
        actions(tester).firstWhere((a) => a.zone == GazeZone.down);
    choose.onSelect();
    await tester.pump();

    // Motor is self-paced, so the answer stays put and the advance appears.
    expect(find.text('1/6'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    actions(tester).firstWhere((a) => a.zone == GazeZone.down).onSelect();
    await tester.pump();
    expect(find.text('2/6'), findsOneWidget);
  });
}
