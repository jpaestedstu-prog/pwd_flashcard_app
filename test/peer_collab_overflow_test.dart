import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_models.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/models/collab_presentation.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/screens/peer_collaboration_screen.dart';
import 'package:pwdpwdpwd/features/peer_collaboration/services/collab_session_store.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// Peer Collab's layout floor, plus a whole session driven end to end.
///
/// The screen is unusually exposed to overflow for two reasons the rest of the
/// app is not: **both** player names are free text (Player 1 is the profile
/// name, Player 2 is typed straight into the picker with no length limit), and
/// the Word Relay blanks are fixed-width boxes sized in raw pixels. So the
/// matrix runs with deliberately long names — that is what a real learner
/// profile ("Cognitive/Learning Student") plus a typed sibling name looks like.
///
/// Every session here is played by **tapping choices**, never by typing, which
/// doubles as the regression test for the promise in [CollabPresentation]: a
/// learner who cannot use a keyboard can still take every turn.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._name, this._type);
  final String _name;
  final DisabilityType _type;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: _name,
        role: UserRole.student,
        disabilityType: _type,
        createdAt: DateTime(2026),
      );
}

// The longest names the real profile roster actually produces. Player 1 is a
// profile name (learner profiles are commonly named for their preset); Player 2
// is typed free-hand on the picker.
const _longPlayer1 = 'Cognitive/Learning Student';
const _longPlayer2 = 'Bernadette Guerrero';
const _profileId = 'test-profile';

List<Override> _profile([DisabilityType type = DisabilityType.none]) => [
      profileProvider.overrideWith(() => _StubProfileNotifier(_longPlayer1, type))
    ];

/// Mounts the screen at [device] × [scale] and returns once the entrance
/// animations have settled.
Future<void> _pumpScreen(
  WidgetTester tester,
  DeviceSize device,
  double scale, {
  DisabilityType type = DisabilityType.none,
  String locale = 'en',
}) async {
  // Unmount first: pumping the same widget type again reuses the existing
  // State, so without this the second device in a loop would still be sitting
  // in the session the first one started.
  await tester.pumpWidget(const SizedBox.shrink());

  tester.view.physicalSize = device.size * device.devicePixelRatio;
  tester.view.devicePixelRatio = device.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _profile(type),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Required now the screen reads its copy from AppLocalizations: without
        // the delegates `AppLocalizations.of(context)!` throws "Null check
        // operator used on a null value", which in an overflow matrix reads as
        // a layout failure and sends you hunting in the wrong place.
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const PeerCollaborationScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Names Player 2 and opens [activity]'s live session.
Future<void> _startActivity(WidgetTester tester, String activity) async {
  await tester.enterText(find.byType(TextField).first, _longPlayer2);
  await tester.pump();
  final card = find
      .ancestor(of: find.text(activity), matching: find.byType(InkWell))
      .first;
  await tester.scrollUntilVisible(card, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(card, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Takes one turn by tapping the first offered choice. Returns false when there
/// is nothing left to tap.
Future<bool> _tapAChoice(WidgetTester tester) async {
  final choice = find.byKey(const ValueKey('collabChoice0'));
  if (choice.evaluate().isEmpty) return false;
  await tester.tap(choice, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return true;
}

/// Drains every queued layout exception — an overflowing box re-reports each
/// frame — and fails with the first one.
void _expectNoOverflow(WidgetTester tester, String reason) {
  Object? firstError;
  for (Object? e = tester.takeException();
      e != null;
      e = tester.takeException()) {
    firstError ??= e;
  }
  expect(firstError, isNull, reason: '$reason:\n$firstError');
}

/// Asserts [finder]'s single match is painted inside the viewport.
///
/// [_expectNoOverflow] on its own is **not** enough here, and that is the whole
/// reason this helper exists: an unflexed `Row` child can be laid out entirely
/// past the right edge and painted there without the render tree ever throwing
/// a RenderFlex overflow the test framework can catch. On the tablet that
/// looked like a finish card whose second player — name *and* score — simply
/// was not on screen, under a live 223px overflow stripe. Geometry catches it;
/// exceptions did not.
void _expectOnScreen(WidgetTester tester, Finder finder, String reason) {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect = tester.getRect(finder);
  expect(
    rect.left >= -0.5 && rect.right <= screen.width + 0.5,
    isTrue,
    reason: '$reason: painted at $rect, outside a ${screen.width}px viewport',
  );
}

/// Mounts the screen **pushed onto a route**, so there is something for Back to
/// pop and the AppBar grows a back button. The matrix helper mounts it as
/// `home:`, where neither is true.
Future<void> _pumpPushed(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = const Size(800 * 2, 1280 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _profile(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PeerCollaborationScreen(),
                  ),
                ),
                child: const Text('open collab'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open collab'));
  await tester.pumpAndSettle();
}

/// Re-enter the screen from the host page — a fresh `initState`, which is when
/// a saved session is looked up.
Future<void> _reopen(WidgetTester tester) async {
  await tester.tap(find.text('open collab'));
  await tester.pumpAndSettle();
}

/// Leave through the system Back button, confirming when the screen asks.
Future<void> _leaveViaBack(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  if (find.text('Leave').evaluate().isNotEmpty) {
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
  }
}

/// Signal that the learner pressed Home and then came back.
///
/// Two things this has to get right. The lifecycle is a **state machine** —
/// `paused` may only be reached through `inactive`, and only `inactive` leads
/// back to `resumed`; jumping straight between them trips a framework
/// assertion. And the `resumed` half matters as much as the `paused` half:
/// while the binding believes the app is backgrounded it will not settle a
/// route transition, so a later `pageBack()` reports that it popped and then
/// leaves the old screen sitting on the tree.
Future<void> _background(WidgetTester tester) async {
  // The real order Android drives, and the only one the framework's assertions
  // accept: resumed → inactive → hidden → paused, and back out again.
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    await _setLifecycle(tester, state);
  }
}

Future<void> _setLifecycle(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/peer_collab');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      // allFlashcardsProvider merges the seed deck with the learner's own
      // cards, so the rounds cannot be built without this box.
      'custom_cards',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  setUp(() => CollabSessionStore.clear(_profileId));

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  testWidgets('activity picker survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const PeerCollaborationScreen(),
      overrides: _profile(),
    );
  });

  // The picker is only the first frame. Every activity has its own live layout
  // — a wrapped letter-blank row, a describe/guess card, a story feed — that
  // the first-frame matrix never reaches, and all four share the turn banner
  // that the players' names are interpolated into.
  for (final activity in const <String>[
    'Word Relay',
    'Picture Guess',
    'Sign Challenge',
    'Story Builder',
  ]) {
    testWidgets('$activity survives the device matrix', (tester) async {
      for (final device in kTabletMatrix) {
        for (final scale in kTextScales) {
          await _pumpScreen(tester, device, scale);
          await _startActivity(tester, activity);
          _expectNoOverflow(
              tester, '$activity overflowed at $device, textScale ${scale}x');
          _expectOnScreen(
            tester,
            find.textContaining(_longPlayer1).first,
            '$activity turn banner at $device, textScale ${scale}x',
          );
          expect(find.byKey(const ValueKey('collabChoice0')), findsOneWidget,
              reason: '$activity must be answerable by tapping');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // The finish card puts both names side by side in one row, so it is the other
  // place two long names meet.
  testWidgets('completion card survives the device matrix', (tester) async {
    for (final device in kTabletMatrix) {
      for (final scale in kTextScales) {
        await _pumpScreen(tester, device, scale);
        await _startActivity(tester, 'Story Builder');

        // Tap-only, and bounded: five rounds of two turns, plus slack.
        var taps = 0;
        while (find.text('Great teamwork!').evaluate().isEmpty && taps < 40) {
          if (!await _tapAChoice(tester)) break;
          taps++;
        }
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Great teamwork!'), findsOneWidget,
            reason: 'tapping alone should finish a session at $device');
        _expectNoOverflow(tester,
            'Completion card overflowed at $device, textScale ${scale}x');
        // Both players have to still be *on* the finish card.
        for (final name in const [_longPlayer1, _longPlayer2]) {
          _expectOnScreen(
            tester,
            find.text(name),
            'Finish card "$name" at $device, textScale ${scale}x',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Each accessibility category gets a different roster, choice count, target
  // size and (for some) no keyboard at all — so each is a different layout.
  group('every accessibility category lays out and plays', () {
    for (final type in DisabilityType.values) {
      testWidgets('$type', (tester) async {
        final presentation =
            CollabPresentation.forProfile(type, const AppSettings());

        for (final activity in presentation.activities) {
          const device =
              DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0);
          await _pumpScreen(tester, device, 2.0, type: type);
          await _startActivity(tester, activity.label);

          _expectNoOverflow(
              tester, '$type / ${activity.label} at 360x640 @ 2.0x');

          // The promise: no keyboard needed, ever.
          expect(find.byKey(const ValueKey('collabChoice0')), findsOneWidget,
              reason: '$type / ${activity.label} needs a tap target');
          if (!presentation.allowFreeText) {
            expect(find.byType(TextField), findsNothing,
                reason: '$type is not offered a keyboard mid-session');
          }

          // And a full session finishes on taps alone.
          var taps = 0;
          while (find.text('Great teamwork!').evaluate().isEmpty && taps < 60) {
            if (!await _tapAChoice(tester)) break;
            taps++;
          }
          expect(find.text('Great teamwork!'), findsOneWidget,
              reason: '$type could not finish ${activity.label} by tapping');
          _expectNoOverflow(
              tester, '$type / ${activity.label} finish card');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('the written clue', () {
    /// Opens Picture Guess and returns with the describer on screen.
    Future<void> openCluePhase(WidgetTester tester) async {
      const device = DeviceSize('10" portrait', Size(800, 1280));
      await _pumpScreen(tester, device, 1.0);
      await _startActivity(tester, 'Picture Guess');
      expect(find.textContaining('describe the word for'), findsOneWidget);
    }

    const passLabel = 'Or show it — pass to $_longPlayer2';

    testWidgets('the describer is offered ready-made clues and a pass',
        (tester) async {
      await openCluePhase(tester);

      // Written clues, all true of the card and none of them naming it.
      expect(find.textContaining('Category:'), findsOneWidget);
      expect(find.textContaining('It starts with'), findsOneWidget);
      expect(find.textContaining('It has'), findsOneWidget);
      // ...and showing or signing it instead is still one tap.
      expect(find.text(passLabel), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a tapped clue is what the guesser reads', (tester) async {
      await openCluePhase(tester);

      // Read the clue off the button we are about to press, rather than
      // assuming which of the three the bank puts first.
      final clue = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('collabChoice0')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      await _tapAChoice(tester);

      expect(find.textContaining('guess the word'), findsOneWidget);
      expect(find.text('Clue:'), findsOneWidget);
      expect(find.text(clue), findsOneWidget,
          reason: 'the clue their partner left is on screen');
      expect(find.text('???'), findsOneWidget,
          reason: 'and the word itself still is not');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a typed clue reaches the guesser too', (tester) async {
      await openCluePhase(tester);

      await tester.enterText(
          find.byType(TextField).first, 'it is very cold');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Clue:'), findsOneWidget);
      expect(find.text('it is very cold'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('showing or signing it leaves no written clue',
        (tester) async {
      await openCluePhase(tester);

      await tester.tap(find.text(passLabel));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Now the guesser is looking at the screen. They must see "???" and their
      // options — not the button their partner happened to press.
      expect(find.text('???'), findsOneWidget);
      expect(find.text(passLabel), findsNothing,
          reason: 'the pass label is not a hint');
      expect(find.textContaining('Clue:'), findsNothing,
          reason: 'nothing was written down to show');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a ready-made clue is always true of the word', (tester) async {
      // A wiring check: the chips must describe the card actually on screen.
      // Cards are dealt at random, so this samples rather than proves — the
      // arithmetic itself is pinned deterministically by `CollabClueFacts` in
      // collab_rules_test.dart, which is where the "Partly Cloudy has thirteen
      // letters" bug is actually guarded.
      for (var attempt = 0; attempt < 12; attempt++) {
        await openCluePhase(tester);

        // The describer sees the answer in caps; the chips describe it.
        final word = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .firstWhere((t) => t == t.toUpperCase() && RegExp(r'[A-Z]').hasMatch(t));

        final lengthClue = tester
            .widgetList<Text>(find.textContaining('It has'))
            .map((t) => t.data!)
            .first;
        final claimed =
            int.parse(RegExp(r'(\d+)').firstMatch(lengthClue)!.group(1)!);
        expect(claimed, word.replaceAll(RegExp(r'\s'), '').length,
            reason: '"$lengthClue" is not true of "$word"');

        final firstLetterClue = tester
            .widgetList<Text>(find.textContaining('It starts with'))
            .map((t) => t.data!)
            .first;
        expect(firstLetterClue, contains(word[0]),
            reason: '"$firstLetterClue" is not true of "$word"');

        expect(lengthClue.toUpperCase(), isNot(contains(word)),
            reason: 'a clue must not name the word');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a keyboard-free learner can still write one', (tester) async {
      // The whole reason the bank exists: writing a clue used to need typing,
      // which is exactly what this profile does not have.
      const device = DeviceSize('10" portrait', Size(800, 1280));
      await _pumpScreen(tester, device, 1.0, type: DisabilityType.motor);
      await _startActivity(tester, 'Picture Guess');

      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('collabChoice0')), findsOneWidget);
      expect(find.textContaining('It has'), findsOneWidget);

      await _tapAChoice(tester);
      expect(find.text('Clue:'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('leaving mid-session', () {
    testWidgets('Back asks first, and Keep playing stays put', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Story Builder');
      await _tapAChoice(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Two children mid-round should not lose their place to a stray Back.
      expect(find.text('Leave this activity?'), findsOneWidget);

      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this activity?'), findsNothing);
      expect(find.byKey(const ValueKey('collabChoice0')), findsOneWidget,
          reason: 'still in the session');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Leave pops the screen', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Story Builder');
      await _tapAChoice(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('open collab'), findsOneWidget,
          reason: 'back on the host page');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a finished session leaves without asking', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Story Builder');

      var taps = 0;
      while (find.text('Great teamwork!').evaluate().isEmpty && taps < 40) {
        if (!await _tapAChoice(tester)) break;
        taps++;
      }
      expect(find.text('Great teamwork!'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Leave this activity?'), findsNothing,
          reason: 'there is nothing left to lose');
      expect(find.text('open collab'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('carrying on later', () {
    testWidgets('backgrounding saves the place', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Picture Guess');
      // Clue, then a guess: enough that round 1 is behind them.
      await _tapAChoice(tester);
      await _tapAChoice(tester);
      expect(find.textContaining('Round 2 of'), findsOneWidget);

      expect(CollabSessionStore.read(_profileId), isNull,
          reason: 'nothing is written while they are still playing');

      // A permission sheet or the app switcher passing over the screen is not
      // leaving, so `inactive` on its own must not write anything.
      await _setLifecycle(tester, AppLifecycleState.inactive);
      expect(CollabSessionStore.read(_profileId), isNull,
          reason: 'inactive is not leaving');

      // Pressing Home is how a young learner actually leaves.
      await _setLifecycle(tester, AppLifecycleState.hidden);
      await _setLifecycle(tester, AppLifecycleState.paused);

      final saved = CollabSessionStore.read(_profileId);
      expect(saved, isNotNull);
      expect(saved!.roundNumber, 2);
      expect(saved.activityType, CollabActivityType.pictureGuess);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the saved place is offered back, and carries on',
        (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Picture Guess');
      await _tapAChoice(tester);
      await _tapAChoice(tester);
      await _leaveViaBack(tester);

      await _reopen(tester);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Continue where you left off?'), findsOneWidget);
      expect(find.textContaining('Round 2 of'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Straight back into the same round, not a fresh deal at round one.
      expect(find.textContaining('Round 2 of'), findsOneWidget);
      expect(find.text('Continue where you left off?'), findsNothing);
      expect(find.byKey(const ValueKey('collabChoice0')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Start Over drops the snapshot for good', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Picture Guess');
      await _tapAChoice(tester);
      await _tapAChoice(tester);
      await _leaveViaBack(tester);

      await _reopen(tester);
      await tester.tap(find.text('Start Over'));
      await tester.pumpAndSettle();
      expect(find.text('Continue where you left off?'), findsNothing);
      expect(CollabSessionStore.read(_profileId), isNull);

      await _leaveViaBack(tester);
      await _reopen(tester);
      expect(find.text('Continue where you left off?'), findsNothing,
          reason: 'and it stays gone next time too');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a finished session leaves nothing to resume', (tester) async {
      await _pumpPushed(tester);
      await _startActivity(tester, 'Story Builder');

      var taps = 0;
      while (find.text('Great teamwork!').evaluate().isEmpty && taps < 40) {
        if (!await _tapAChoice(tester)) break;
        taps++;
      }
      expect(find.text('Great teamwork!'), findsOneWidget);

      await _background(tester);
      expect(CollabSessionStore.read(_profileId), isNull);

      await _leaveViaBack(tester);
      await _reopen(tester);
      expect(find.text('Continue where you left off?'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('Play Again keeps the name the player can see', (tester) async {
    const device =
        DeviceSize('10" portrait', Size(800, 1280));
    await _pumpScreen(tester, device, 1.0);
    await _startActivity(tester, 'Story Builder');

    var taps = 0;
    while (find.text('Great teamwork!').evaluate().isEmpty && taps < 40) {
      if (!await _tapAChoice(tester)) break;
      taps++;
    }
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The field used to blank itself while the state kept the old name, so the
    // next session silently started with a name nobody could see.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      _longPlayer2,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
