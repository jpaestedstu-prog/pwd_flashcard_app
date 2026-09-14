import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_screen.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_over_other_apps.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/routine_test_doubles.dart';

/// "Display over other apps" — asked for on the learner's own tablet.
///
/// Found on the NDL W09: the builder's row said "set this on the learner's
/// tablet", but a teacher building on their own phone left the tablet with
/// nowhere to do it, and a lock due while another app was open stayed a
/// banner (`no takeover: … overlay=false`). My Day now asks, for the grown-up.

const _title = 'Let the lock appear over other apps';
const _button = 'Allow over other apps';

Routine _locking() => buildTestRoutine().copyWith(lockEnabled: true);

Future<void> _pumpDay(
  WidgetTester tester, {
  required bool? granted,
  UserRole role = UserRole.student,
  List<Routine>? routines,
  String? classroomId = 'routine-test-class',
  Widget home = const RoutineScreen(),
}) async {
  tester.view.physicalSize = const Size(800, 1400) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...routineOverrides(
          role: role,
          routines: routines ?? [_locking()],
          classroomId: classroomId,
        ),
        if (granted != null)
          routineOverOtherAppsGrantedProvider.overrideWith(
            (ref) async => granted,
          ),
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
  await _settle(tester);
}

/// Never `pumpAndSettle`: the gradient backdrop repeats forever.
Future<void> _settle(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 900),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/routine_over_other_apps');
    for (final name in const ['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('My Day on the learner’s tablet', () {
    testWidgets('asks for it when today locks and it is not allowed', (
      tester,
    ) async {
      await _pumpDay(tester, granted: false);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_button), findsOneWidget);
      expect(
        find.textContaining('For the adult who looks after this tablet'),
        findsOneWidget,
      );
      // Spoken to the adult, never to the child.
      expect(find.textContaining('Ask a grown-up'), findsNothing);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says nothing once it is allowed', (tester) async {
      await _pumpDay(tester, granted: true);
      expect(find.text(_title), findsNothing);
      await _unmount(tester);
    });

    testWidgets('says nothing when nothing today can lock', (tester) async {
      await _pumpDay(tester, granted: false, routines: [buildTestRoutine()]);
      expect(find.text(_title), findsNothing);
      await _unmount(tester);
    });

    testWidgets('never asks a Player, who is never locked', (tester) async {
      await _pumpDay(
        tester,
        granted: false,
        role: UserRole.player,
        classroomId: null,
      );
      expect(find.text(_title), findsNothing);
      await _unmount(tester);
    });

    testWidgets('never asks an educator previewing the learner’s day', (
      tester,
    ) async {
      await _pumpDay(
        tester,
        granted: false,
        role: UserRole.teacher,
        home: const RoutineScreen(
          profileId: kTestProfileId,
          displayName: 'Routine Tester',
          readOnly: true,
        ),
      );
      expect(find.text(_title), findsNothing);
      await _unmount(tester);
    });
  });

  group('the builder’s row', () {
    Future<void> pumpRow(WidgetTester tester, bool granted) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routineOverOtherAppsGrantedProvider.overrideWith(
              (ref) async => granted,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RoutineOverOtherAppsRow(filipino: false)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('says when it is not allowed yet, and offers the page', (
      tester,
    ) async {
      await pumpRow(tester, false);
      expect(find.text('Not allowed yet'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Open over other apps'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('says when it is allowed, with nothing left to tap', (
      tester,
    ) async {
      await pumpRow(tester, true);
      expect(find.text('Allowed on this device'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Open over other apps'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
