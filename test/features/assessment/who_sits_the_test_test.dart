import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import '../../support/device_matrix.dart';

/// Who sits the pre-test and post-test, and who reads the results.
///
/// The Assessment Center offered the pair to whoever opened it. A Teacher
/// running a class and a Parent running a home group were both invited to sit
/// their own pre-test, and a pre-test taken by a teacher lands under their
/// profile id — in the same store the learning-gain figures are read from.
/// The instrument belongs to the enrolled learners; the educators assign it
/// and read the gain.
///
/// `testWidgets` only in this file, and nothing here taps through to a screen
/// that writes: seeding happens once in `setUpAll`, outside the fake-async
/// zone. (See assignment_loop_test.dart for the persistence half.)

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role, this.id);
  final UserRole _role;
  final String id;

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Test User',
    role: _role,
    createdAt: DateTime(2026),
    isGuestPlayer: _role == UserRole.player,
  );
}

void main() {
  setUpAll(() async {
    const cacheDir = './build/test_cache/who_sits_the_test';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process — Hive reports it plainly below.
    }
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await Hive.box('progress').clear();
    // Two learners on the device so the educator's roster section renders its
    // rows rather than its empty state. Written as raw maps under the same key
    // HiveService uses, so the seeding never depends on the code under test.
    await Hive.box('profiles').put('profiles', [
      for (final (id, name) in const [
        ('roster-1', 'Bernadette Villanueva-Santos'),
        ('roster-2', 'Kim'),
      ])
        {
          'id': id,
          'name': name,
          'role': UserRole.student.index,
          'avatarIndex': 0,
          'createdAt': DateTime(2026).toIso8601String(),
          'disabilityType': DisabilityType.hearing.index,
        },
    ]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpHub(
    WidgetTester tester,
    UserRole role, {
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    final router = GoRouter(
      initialLocation: '/assessment',
      routes: [
        GoRoute(
          path: '/assessment',
          builder: (_, _) => const AssessmentHubScreen(),
          routes: [
            GoRoute(
              path: 'take/:id',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('LANDED'))),
            ),
          ],
        ),
      ],
    );

    tester.view.physicalSize = (device ?? const Size(1200, 1920)) * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            () => _StubProfileNotifier(role, '${role.name}-1'),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    // Entrance animations are staggered up to ~750ms.
    await tester.pump(const Duration(seconds: 1));
  }

  // ─── Educators manage; they do not sit ───────────────────

  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('a ${role.name} is not offered a pre-test', (tester) async {
      await pumpHub(tester, role);

      expect(
        find.text('Pre-Test'),
        findsNothing,
        reason: 'an educator taking the instrument pollutes the very '
            'learning-gain store they are meant to be reading',
      );
      expect(find.text('Post-Test'), findsNothing);
    });

    testWidgets('a ${role.name} gets the roster view instead', (tester) async {
      await pumpHub(tester, role);

      expect(find.text('📊 Pre-Test & Post-Test'), findsOneWidget);
      expect(find.textContaining('Your learners sit these'), findsOneWidget);
    });

    testWidgets('a ${role.name} is not offered mastery tests', (tester) async {
      await pumpHub(tester, role);

      expect(find.text('🏆 Category Mastery Tests'), findsNothing);
      expect(find.text('Animals'), findsNothing);
    });
  }

  // ─── Learners sit it ─────────────────────────────────────

  for (final role in const [UserRole.student, UserRole.child]) {
    testWidgets('a ${role.name} is offered both halves', (tester) async {
      await pumpHub(tester, role);

      expect(find.text('Pre-Test'), findsOneWidget);
      expect(find.text('Post-Test'), findsOneWidget);
      expect(
        find.textContaining('Take a pre-test before studying'),
        findsOneWidget,
      );
    });

    testWidgets('a ${role.name} keeps the mastery tests', (tester) async {
      await pumpHub(tester, role);

      expect(find.text('🏆 Category Mastery Tests'), findsOneWidget);
    });
  }

  testWidgets('a Player keeps mastery tests but not the study pair', (
    tester,
  ) async {
    // A Player has no educator to read a learning gain and is never part of
    // the study, so the pre/post pair is not theirs — but nothing else about
    // their hub changes.
    await pumpHub(tester, UserRole.player);

    expect(find.text('Pre-Test'), findsNothing);
    expect(find.text('Post-Test'), findsNothing);
    expect(find.text('🏆 Category Mastery Tests'), findsOneWidget);
  });

  testWidgets('an educator sees who still owes them each half', (
    tester,
  ) async {
    await pumpHub(tester, UserRole.teacher);

    expect(find.text('Bernadette Villanueva-Santos'), findsOneWidget);
    expect(find.text('Kim'), findsOneWidget);
    // Neither learner has sat anything, so both halves read as outstanding.
    expect(find.text('Pre'), findsNWidgets(2));
    expect(find.text('Post'), findsNWidgets(2));
  });

  // ─── The new rows survive a small screen at a big font ───

  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('the roster rows lay out at ${device.label}, ${scale}x', (
        tester,
      ) async {
        for (final role in const [UserRole.parent, UserRole.child]) {
          await pumpHub(
            tester,
            role,
            device: device.size,
            dpr: device.devicePixelRatio,
            textScale: scale,
          );

          Object? firstError;
          for (
            Object? e = tester.takeException();
            e != null;
            e = tester.takeException()
          ) {
            firstError ??= e;
          }
          expect(
            firstError,
            isNull,
            reason: '${role.name} at ${device.label} ${scale}x: $firstError',
          );
        }
      });
    }
  }
}
