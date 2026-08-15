import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/fsl_dictionary_screen.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/widgets/fsl_video_sheet.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// How the FSL Dictionary answers a tap on a word that has no sign recorded.
///
/// 35 of the 177 seed flashcards have no entry in
/// `assets/data/fsl_video_manifest.json` — every one of the 20 Actions verbs
/// among them — so this is a path roughly one word in five takes. It used to
/// answer with a SnackBar, which is the one affordance this screen's audience
/// (Deaf / hard-of-hearing learners) is least likely to catch: a toast that
/// fades while they are still looking at the card reads as a tap that did
/// nothing. Every other FSL surface in the app already uses the shared sheet.
///
/// Kept in its own file rather than alongside the device-matrix tests: those
/// pump the screen 21 times and leave `FslAssetsService`'s manifest future
/// resolved inside a dead fake-async zone, which wedges any later test in the
/// same isolate that drives the screen for real.
/// A learner so the dictionary has somewhere to hang a favourites list — the
/// star is hidden entirely without a profile (educator preview).
class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'learner',
    name: 'Test Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );
}

void main() {
  setUpAll(() async {
    // Wipe first so a tester left over from an earlier hung run can't wedge
    // this suite on a stale `.lock` — see the notes in `hive_service.dart`'s
    // test callers.
    const dir = './build/test_cache/fsl_dictionary_behavior';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
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

  // Time-guarded: the favourites test writes to Hive from inside `testWidgets`,
  // so that `box.put` future is left pending in the dead fake-async zone and an
  // unguarded `deleteFromDisk` waits on it forever (12-minute timeout, tests
  // already green). The store is a throwaway under build/, so giving up on the
  // cleanup is harmless — and `setUpAll` wipes the directory anyway.
  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 5));
    } catch (_) {}
  });

  setUp(() async {
    // Load the manifest here, not inside `testWidgets` — asset reads complete
    // in the real zone and FakeAsync would never advance them.
    FslAssetsService.reset();
    await FslAssetsService.load();
  });
  tearDown(FslAssetsService.reset);

  testWidgets('a word with no sign shows the shared sheet, not a SnackBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FslDictionaryScreen(),
        ),
      ),
    );
    // Bounded pumps: entrance animations plus the availability future.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // "Run" is an Actions verb, and Actions has no FSL clips at all.
    await tester.enterText(find.byType(TextField), 'Run');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Tap the Filipino gloss: it appears only on the card, whereas "Run" is
    // also the text sitting in the search field.
    await tester.tap(find.text('Tumakbo'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.text('No FSL video available yet for "Run".'),
      findsOneWidget,
      reason: 'the persistent sheet every other FSL surface shows',
    );
    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a word card is reachable and pressable hands-free', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FslDictionaryScreen(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.enterText(find.byType(TextField), 'Run');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The dictionary is pushed over the shell, so gaze steers it with Flutter's
    // directional focus traversal. That reaches focusable widgets only — the
    // cards were bare `GestureDetector`s, so a gaze learner could open this
    // screen and then touch nothing on it.
    final cardInk = find.ancestor(
      of: find.text('Tumakbo'),
      matching: find.byType(InkWell),
    );
    expect(cardInk, findsOneWidget, reason: 'the card must be focusable');

    // Focus it the way traversal would…
    final inside = tester.element(
      find.descendant(of: cardInk, matching: find.byType(Column)).first,
    );
    Focus.of(inside).requestFocus();
    await tester.pump();

    // …then press it the way a blink does, through the same driver.
    expect(
      GazeFocusDriver.activate(),
      isTrue,
      reason: 'the focused card must answer ActivateIntent',
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('No FSL video available yet for "Run".'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('starring a word puts it in My Signs, without watching it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith(_StubProfile.new)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FslDictionaryScreen(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.enterText(find.byType(TextField), 'Dog');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('My Signs · 0'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byIcon(Icons.star_rounded), findsWidgets);
    expect(find.text('My Signs · 1'), findsOneWidget);
    expect(HiveService.isFslFavourite('learner', 'Animals', 'Dog'), isTrue);
    // Starring is a bookmark, not progress — it must not open the video or
    // count as a sign watched.
    expect(HiveService.fslUniqueWordsViewed('learner'), 0);
    expect(find.byType(FslVideoSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
