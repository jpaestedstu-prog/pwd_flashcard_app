import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';

/// Who the Assessment Center is *for*, and whether its tiles go anywhere.
///
/// Two things were wrong at once. The hub gated every educator section on
/// `role == UserRole.teacher`, so a Parent — who enrols children exactly as a
/// teacher enrols students — got a learner page inviting them to sit their own
/// pre-test. And every tile that had only an id to work with pushed a route
/// whose builder read `state.extra as Assessment?`, got null, and rendered a
/// second copy of the hub: all thirteen Category Mastery cards and the
/// educator's own custom assessments were dead taps that looked like nothing
/// had happened.
///
/// `testWidgets` only — no awaited `box.put` in this file, and nothing here
/// taps through to a screen that writes. Seeding happens once in `setUpAll`,
/// outside the fake-async zone. (See test/features/assessment/
/// assignment_loop_test.dart for the persistence half.)

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role, {this.id = 'test-profile'});
  final UserRole _role;
  final String id;

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Test User',
    role: _role,
    createdAt: DateTime(2026),
  );
}

/// The route a tap landed on, plus whether it carried a usable assessment.
class _Landing {
  String? location;
  Assessment? extra;
}

void main() {
  const educatorId = 'educator-1';
  const learnerId = 'learner-1';
  const customId = 'custom-quiz-1';

  final custom = Assessment(
    id: customId,
    title: 'Farm Animals Check',
    type: AssessmentType.custom,
    questions: [
      const AssessmentQuestion(
        id: 'q1',
        questionText: 'What is the Filipino word for "dog"?',
        correctAnswer: 'Aso',
        choices: ['Aso', 'Pusa', 'Ibon', 'Isda'],
        category: FlashcardCategory.animals,
      ),
    ],
    categories: const [FlashcardCategory.animals],
    createdBy: educatorId,
    createdAt: DateTime(2026, 8),
  );

  final assigned = AssessmentAssignment(
    id: 'assignment-1',
    assessmentId: customId,
    assessmentTitle: 'Farm Animals Check',
    assignedBy: educatorId,
    studentIds: const [learnerId],
    assignedAt: DateTime(2026, 8),
    deadline: DateTime(2099, 1, 20),
    instructions: 'Do this before Friday.',
  );

  setUpAll(() async {
    // Self-healing: a suite that once hung leaves a flutter_tester holding
    // `*.lock` in this directory, and every later run fails setUpAll with
    // PathAccessException. The dir is disposable, so start from nothing.
    const cacheDir = './build/test_cache/assessment_hub_roles';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process — Hive will report it plainly below.
    }
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    final box = Hive.box('progress');
    await box.clear();
    // The educator's template, and an assignment of it to the learner. Written
    // as raw JSON under the same keys AssessmentService uses so the seeding
    // never depends on the code under test.
    await box.put('assessments_$educatorId', [custom.toJson()]);
    await box.put('assignments_$educatorId', [assigned.toJson()]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  /// Pumps the hub inside a router that records where a tap sends the user.
  /// Both destinations render a marker rather than the real test screen, so a
  /// tap that falls through to the hub is unmistakable in the tree.
  Future<_Landing> pumpHub(
    WidgetTester tester,
    UserRole role, {
    String profileId = educatorId,
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    final landing = _Landing();
    Widget marker(GoRouterState state) {
      landing
        ..location = state.uri.path
        ..extra = state.extra as Assessment?;
      return const Scaffold(body: Center(child: Text('LANDED')));
    }

    final router = GoRouter(
      initialLocation: '/assessment',
      routes: [
        GoRoute(
          path: '/assessment',
          builder: (_, _) => const AssessmentHubScreen(),
          routes: [
            GoRoute(
              path: 'category/:categoryIndex',
              builder: (_, state) => marker(state),
            ),
            GoRoute(path: 'take/:id', builder: (_, state) => marker(state)),
            GoRoute(
              path: 'builder',
              builder: (_, state) => marker(state),
            ),
            GoRoute(path: 'assign', builder: (_, state) => marker(state)),
            GoRoute(path: 'tracking', builder: (_, state) => marker(state)),
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
            () => _StubProfileNotifier(role, id: profileId),
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
    return landing;
  }

  /// Scrolls [target] into view. The educator sections sit below thirteen
  /// Category Mastery cards in a lazy `CustomScrollView`, so they are not built
  /// — and so not findable — until the list reaches them.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(CustomScrollView),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
  }

  // ─── Role parity ─────────────────────────────────────────

  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('${role.name} gets the educator toolbar', (tester) async {
      await pumpHub(tester, role);

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      expect(
        find.textContaining("Build, assign and track"),
        findsOneWidget,
        reason: 'the header should not tell an educator to measure their own '
            'learning progress',
      );
    });

    testWidgets('${role.name} sees their custom assessments', (tester) async {
      await pumpHub(tester, role);
      await scrollTo(tester, find.text('Farm Animals Check'));

      expect(find.text('✏️ Custom Assessments'), findsOneWidget);
      expect(find.text('Farm Animals Check'), findsOneWidget);
    });
  }

  testWidgets('a learner gets no educator tools', (tester) async {
    await pumpHub(tester, UserRole.student, profileId: learnerId);

    expect(find.text('Create'), findsNothing);
    expect(find.text('Assign'), findsNothing);
    expect(find.text('✏️ Custom Assessments'), findsNothing);
    expect(find.text('Measure your learning progress'), findsOneWidget);
  });

  // ─── The learner's half of the loop ──────────────────────

  testWidgets('a learner sees the work assigned to them', (tester) async {
    await pumpHub(tester, UserRole.student, profileId: learnerId);

    expect(find.text('📌 Assigned to You'), findsOneWidget);
    expect(find.text('Farm Animals Check'), findsOneWidget);
    expect(find.text('Do this before Friday.'), findsOneWidget);
  });

  testWidgets('an unassigned learner sees no assigned section', (tester) async {
    await pumpHub(tester, UserRole.student, profileId: 'somebody-else');

    expect(find.text('📌 Assigned to You'), findsNothing);
  });

  testWidgets('an educator is not shown their own assignments as work', (
    tester,
  ) async {
    // The educator is not in `studentIds`, but assert it explicitly: the
    // section is for work *set for you*, and an educator's hub already carries
    // the tracking view.
    await pumpHub(tester, UserRole.teacher);

    expect(find.text('📌 Assigned to You'), findsNothing);
  });

  testWidgets('opening assigned work carries the educator\'s template', (
    tester,
  ) async {
    final landing = await pumpHub(
      tester,
      UserRole.student,
      profileId: learnerId,
    );

    await tester.tap(find.text('Farm Animals Check'));
    await tester.pumpAndSettle();

    expect(find.text('LANDED'), findsOneWidget);
    expect(landing.location, '/assessment/take/$customId');
    expect(
      landing.extra,
      isNotNull,
      reason: 'without the template the route falls back to the hub, which is '
          'what made every assigned tile a dead tap',
    );
    expect(landing.extra!.id, customId);
    expect(landing.extra!.questions, hasLength(1));
  });

  // ─── The tiles that used to do nothing ───────────────────

  testWidgets('a Category Mastery card starts a real test', (tester) async {
    final landing = await pumpHub(tester, UserRole.student, profileId: learnerId);

    await tester.tap(find.text('Animals').first);
    await tester.pumpAndSettle();

    expect(
      find.text('LANDED'),
      findsOneWidget,
      reason: 'this used to push a second copy of the Assessment Center',
    );
    expect(
      landing.location,
      '/assessment/category/${FlashcardCategory.animals.index}',
    );
    expect(landing.extra, isNotNull);
    expect(landing.extra!.type, AssessmentType.categoryMastery);
    expect(landing.extra!.categories, [FlashcardCategory.animals]);
    expect(landing.extra!.questions, isNotEmpty);
  });

  testWidgets('a custom assessment tile opens that assessment', (tester) async {
    final landing = await pumpHub(tester, UserRole.teacher);
    await scrollTo(tester, find.text('Farm Animals Check'));

    await tester.tap(find.text('Farm Animals Check'));
    await tester.pumpAndSettle();

    expect(find.text('LANDED'), findsOneWidget);
    expect(landing.location, '/assessment/take/$customId');
    expect(landing.extra?.id, customId);
  });

  // ─── Layout of the new rows ──────────────────────────────

  // The educator toolbar is a three-across Row and the assigned-work tiles
  // stack a title, a due line and instructions — both are the shape that
  // bursts at a large font scale on a small phone.
  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('the hub lays out at ${device.label}, ${scale}x text', (
        tester,
      ) async {
        for (final (role, id) in const [
          (UserRole.parent, educatorId),
          (UserRole.student, learnerId),
        ]) {
          await pumpHub(
            tester,
            role,
            profileId: id,
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
            reason:
                '${role.name} hub at ${device.label} ${scale}x: $firstError',
          );
        }
      });
    }
  }

  // ─── The educator toolbar goes somewhere ─────────────────

  for (final action in const {
    'Create': '/assessment/builder',
    'Assign': '/assessment/assign',
    'Track': '/assessment/tracking',
  }.entries) {
    testWidgets('the ${action.key} button opens ${action.value}', (
      tester,
    ) async {
      final landing = await pumpHub(tester, UserRole.parent);

      await tester.tap(find.text(action.key));
      await tester.pumpAndSettle();

      expect(landing.location, action.value);
    });
  }
}
