import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// What the two cards on a learner's Assessment Center are willing to open.
///
/// Two rules meet here, and they are easy to get wrong in combination: both
/// halves of the instrument are the educator's to hand out — a card opens only
/// what was *assigned*, never a test of the learner's own and never by itself
/// after a week — and a finished half stays closed unless the class or home
/// group allows retakes, which none does by default.
///
/// `testWidgets` only, with all seeding in `setUpAll` outside the fake-async
/// zone — an awaited `box.put` from inside a test hangs the file at teardown.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.id, {this.classroomId});
  final String id;
  final String? classroomId;

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: DisabilityType.hearing,
    classroomId: classroomId,
  );
}

void main() {
  /// A pre-test sat "today" relative to the test run, so the wait is live
  /// rather than a fixed date that ages into readiness.
  final now = DateTime.now();

  Map<String, dynamic> preTest(String learner, DateTime at) => AssessmentResult(
    id: 'pre-$learner',
    assessmentId: 'a1',
    profileId: learner,
    type: AssessmentType.preTest,
    score: 4,
    totalQuestions: 10,
    answers: const [],
    completedAt: at,
    durationSeconds: 60,
  ).toJson();

  Map<String, dynamic> postTest(String learner, DateTime at) =>
      AssessmentResult(
        id: 'post-$learner',
        assessmentId: 'a1',
        profileId: learner,
        type: AssessmentType.postTest,
        score: 8,
        totalQuestions: 10,
        answers: const [],
        completedAt: at,
        durationSeconds: 60,
      ).toJson();

  setUpAll(() async {
    const cacheDir = './build/test_cache/hub_gating';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process — Hive reports it plainly below.
    }
    Hive.init(cacheDir);
    for (final name in const [
      'profiles',
      'progress',
      'settings',
      'classrooms',
      'home_groups',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    final progress = Hive.box('progress');
    await progress.clear();

    // Just finished a pre-test — nothing has been taught since.
    await progress.put('assessment_results_fresh', [preTest('fresh', now)]);

    // Pre-test a fortnight ago, with three separate study days after it.
    await progress.put('assessment_results_ready', [
      preTest('ready', now.subtract(const Duration(days: 14))),
    ]);
    await Hive.box('sessions').put('sessions_ready', [
      for (var d = 1; d <= 3; d++)
        {
          'id': 's$d',
          'date': now
              .subtract(Duration(days: 10 - d))
              .toIso8601String(),
          'durationSeconds': 600,
        },
    ]);

    // Both halves done, in a class that has closed the instrument.
    await progress.put('assessment_results_locked', [
      preTest('locked', now.subtract(const Duration(days: 30))),
      postTest('locked', now.subtract(const Duration(days: 2))),
    ]);
    await Hive.box('classrooms').put(
      'class-locked',
      Classroom(
        id: 'class-locked',
        code: 'LOCK01',
        name: 'Measured Class',
        teacherId: 'teacher-1',
        accessibility: DisabilityType.hearing,
        // Locked — the default for every class.
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ).toJson(),
    );
    await Hive.box('classrooms').put(
      'class-open',
      Classroom(
        id: 'class-open',
        code: 'OPEN01',
        name: 'Practice Class',
        teacherId: 'teacher-1',
        accessibility: DisabilityType.hearing,
        allowAssessmentRetakes: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ).toJson(),
    );
    // Same completed pair, but a class that still allows retakes.
    await progress.put('assessment_results_open', [
      preTest('open', now.subtract(const Duration(days: 30))),
      postTest('open', now.subtract(const Duration(days: 2))),
    ]);

    // The class instrument, assigned: a pre-test to one learner, and a
    // post-test to another who has sat their pre-test this afternoon.
    Map<String, dynamic> instrument(String id, AssessmentType type) =>
        Assessment(
          id: id,
          title: type == AssessmentType.preTest
              ? 'Class Pre-Test'
              : 'Class Post-Test',
          type: type,
          questions: const [],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ).toJson();
    Map<String, dynamic> assignment(String id, String to, String what) =>
        AssessmentAssignment(
          id: id,
          assessmentId: what,
          assessmentTitle: what,
          assignedBy: 'teacher-1',
          studentIds: [to],
          assignedAt: DateTime(2026, 9),
        ).toJson();
    await progress.put('assessments_teacher-1', [
      instrument('class-pre', AssessmentType.preTest),
      instrument('class-post', AssessmentType.postTest),
    ]);
    await progress.put('assignments_teacher-1', [
      assignment('as-pre', 'assigned-pre', 'class-pre'),
      assignment('as-post', 'assigned-post', 'class-post'),
    ]);
    await progress.put('assessment_results_assigned-post', [
      preTest('assigned-post', now),
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
    String profileId, {
    String? classroomId,
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
                  const Scaffold(body: Center(child: Text('STARTED'))),
            ),
          ],
        ),
      ],
    );

    tester.view.physicalSize = const Size(1200, 1920) * 1.75;
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            () => _StubProfileNotifier(profileId, classroomId: classroomId),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  // ─── What opens a learner's cards ────────────────────────

  group('the cards open only what was assigned', () {
    const fromEducatorPre = 'Your teacher or parent will give you this test';
    const fromEducatorPost =
        'Your teacher or parent will open this after your lessons';

    testWidgets('with nothing assigned, both cards say who gives them', (
      tester,
    ) async {
      await pumpHub(tester, 'nobody');
      expect(find.text(fromEducatorPre), findsOneWidget);
      expect(find.text('Complete a Pre-Test first'), findsOneWidget);
    });

    testWidgets('and tapping the pre-test starts nothing', (tester) async {
      // A self-started pre-test was a different sample of words from the
      // class's — a learning gain measured against the wrong instrument.
      await pumpHub(tester, 'nobody');
      await tester.tap(find.text('Pre-Test'));
      await tester.pumpAndSettle();
      expect(find.text('STARTED'), findsNothing);
    });

    testWidgets('a pre-test this afternoon does not open the post-test', (
      tester,
    ) async {
      await pumpHub(tester, 'fresh');
      expect(find.text(fromEducatorPost), findsOneWidget);
      expect(find.text('Complete a Pre-Test first'), findsNothing);
    });

    testWidgets('tapping a waiting post-test starts nothing', (tester) async {
      await pumpHub(tester, 'fresh');

      await tester.tap(find.text('Post-Test'));
      await tester.pumpAndSettle();

      expect(find.text('STARTED'), findsNothing);
    });

    testWidgets('a fortnight and three study days no longer open it', (
      tester,
    ) async {
      // It used to unlock by itself after a week — before the teacher had
      // decided the study period was over.
      await pumpHub(tester, 'ready');
      expect(find.text(fromEducatorPost), findsOneWidget);

      await tester.tap(find.text('Post-Test'));
      await tester.pumpAndSettle();
      expect(find.text('STARTED'), findsNothing);
    });

    testWidgets('an assigned pre-test opens from the card', (tester) async {
      await pumpHub(tester, 'assigned-pre');
      expect(find.text(fromEducatorPre), findsNothing);

      await tester.tap(find.text('Pre-Test'));
      await tester.pumpAndSettle();
      expect(find.text('STARTED'), findsOneWidget);
    });

    testWidgets('an assigned post-test opens the same afternoon', (
      tester,
    ) async {
      // The educator's decision is the study period — no wait on top of it.
      await pumpHub(tester, 'assigned-post');
      expect(find.text(fromEducatorPost), findsNothing);

      await tester.tap(find.text('Post-Test'));
      await tester.pumpAndSettle();
      expect(find.text('STARTED'), findsOneWidget);
    });
  });

  // ─── Retakes ─────────────────────────────────────────────

  group('the retake policy', () {
    testWidgets('a closed class locks a half the learner has finished', (
      tester,
    ) async {
      await pumpHub(tester, 'locked', classroomId: 'class-locked');
      expect(
        find.text('Already done — ask your teacher to reopen it'),
        findsNWidgets(2),
        reason: 'both halves are done, so both are closed',
      );
    });

    testWidgets('a locked card cannot be started', (tester) async {
      await pumpHub(tester, 'locked', classroomId: 'class-locked');

      // `.first`: this learner has finished both halves, so "Pre-Test" also
      // appears further down in Recent Results. The card is the one above.
      await tester.tap(find.text('Pre-Test').first);
      await tester.pumpAndSettle();

      expect(find.text('STARTED'), findsNothing);
    });

    testWidgets('a class that allows retakes leaves both halves available', (
      tester,
    ) async {
      await pumpHub(tester, 'open', classroomId: 'class-open');
      expect(
        find.text('Already done — ask your teacher to reopen it'),
        findsNothing,
      );
    });

    testWidgets('a class this device never cached is locked like any other', (
      tester,
    ) async {
      // Locked is the default everywhere, so an offline fresh install cannot
      // reopen a half the class has closed. It never blocks a first sitting:
      // those open from an assignment — see the group above.
      await pumpHub(tester, 'open', classroomId: 'never-synced');
      expect(
        find.text('Already done — ask your teacher to reopen it'),
        findsNWidgets(2),
      );
    });
  });
}
