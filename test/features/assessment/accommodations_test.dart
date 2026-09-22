import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

/// Test accommodations carried by the learner's profile.
///
/// Both are applied when the assessment is *presented*, never when it is
/// stored: one instrument serves the whole class, and the educator's item
/// analysis still lines up across learners who sat it under different
/// accommodations.
///
/// No Hive in this file — the result notifier is faked in memory, mirroring
/// assessment_time_limit_test.dart, so the finish path never writes.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.supports);
  final Set<LearnerSupportOption> supports;

  @override
  UserProfile? build() => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: DisabilityType.cognitive,
    supportOptions: supports,
  );
}

class _FakeResults extends StateNotifier<List<AssessmentResult>>
    implements AssessmentResultsNotifier {
  _FakeResults() : super([]);

  @override
  String get profileId => 'learner-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void Function()? get onUploadMissed => null;

  @override
  Future<void> saveResult(AssessmentResult result) async {
    state = [...state, result];
  }

  @override
  void refresh() {}

  @override
  List<AssessmentResult> getByType(AssessmentType type) =>
      state.where((r) => r.type == type).toList();

  @override
  AssessmentResult? get latestPreTest => null;

  @override
  AssessmentResult? get latestPostTest => null;

  @override
  LearningGainReport? get learningGainReport => null;

  @override
  bool get hasPreTest => false;

  @override
  bool get hasPostTest => false;
}

void main() {
  Assessment quiz({int? timeLimitMinutes, int questions = 3}) => Assessment(
    id: 'accommodated-1',
    title: 'Timed Check',
    type: AssessmentType.custom,
    timeLimitMinutes: timeLimitMinutes,
    questions: [
      for (var i = 0; i < questions; i++)
        AssessmentQuestion(
          id: 'q$i',
          questionText: 'Question $i — what is the Filipino word for "dog"?',
          correctAnswer: 'Aso',
          choices: const ['Aso', 'Pusa', 'Ibon', 'Isda'],
          category: FlashcardCategory.animals,
        ),
    ],
    categories: const [FlashcardCategory.animals],
    createdBy: 'educator-1',
    createdAt: DateTime(2026, 8),
  );

  late DateTime fakeNow;

  Future<void> pumpQuiz(
    WidgetTester tester,
    Assessment assessment,
    Set<LearnerSupportOption> supports,
  ) async {
    fakeNow = DateTime(2026, 8, 22, 9);

    final router = GoRouter(
      initialLocation: '/take',
      routes: [
        GoRoute(
          path: '/take',
          builder: (_, _) => AssessmentTestScreen(
            assessment: assessment,
            clock: () => fakeNow,
          ),
        ),
        GoRoute(
          path: '/assessment/summary',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('SUMMARY'))),
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
          profileProvider.overrideWith(() => _StubProfileNotifier(supports)),
          hapticServiceProvider.overrideWithValue(
            HapticService(enabled: false),
          ),
          assessmentResultsProvider.overrideWith((ref) => _FakeResults()),
          gamificationFeatureProvider(
            GamificationFeature.stars,
          ).overrideWithValue(false),
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
    // Two frames: flutter_animate queues a zero-duration timer while it mounts,
    // and a test that disposes the tree before that timer has run trips the
    // binding's "a Timer is still pending" assert.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Advances the injected clock and the fake-async clock together so the
  /// periodic tick sees time actually pass.
  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  // ─── Extra time ──────────────────────────────────────────

  group('extra time on tests', () {
    testWidgets('a 10-minute test starts at 15:00 for this learner', (
      tester,
    ) async {
      await pumpQuiz(tester, quiz(timeLimitMinutes: 10), const {
        LearnerSupportOption.extendedTestTime,
      });

      expect(find.text('15:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without the accommodation it still starts at 10:00', (
      tester,
    ) async {
      await pumpQuiz(tester, quiz(timeLimitMinutes: 10), const {});

      expect(find.text('10:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the extended clock is honoured past the original limit', (
      tester,
    ) async {
      await pumpQuiz(tester, quiz(timeLimitMinutes: 1), const {
        LearnerSupportOption.extendedTestTime,
      });

      // One minute, extended by half and rounded up, is two. At 70 seconds
      // the learner is past the educator's limit and still working; before
      // this they were submitted at 60.
      await tick(tester, 70);
      expect(find.text('SUMMARY'), findsNothing);

      await tick(tester, 55);
      await tester.pumpAndSettle();
      expect(find.text('SUMMARY'), findsOneWidget);
    });

    testWidgets('an untimed test gains no clock', (tester) async {
      await pumpQuiz(tester, quiz(), const {
        LearnerSupportOption.extendedTestTime,
      });

      // No countdown chip at all — the accommodation lengthens a limit, it
      // never imposes one.
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ─── Fewer answer choices ────────────────────────────────

  group('fewer answer choices', () {
    test('keeps the correct answer and narrows to two', () {
      final narrowed = AssessmentService.limitChoices(
        quiz().questions,
        2,
        random: Random(7),
      );
      for (final q in narrowed) {
        expect(q.choices, hasLength(2));
        expect(q.choices, contains(q.correctAnswer));
      }
    });

    test('leaves non-multiple-choice items alone', () {
      const fill = AssessmentQuestion(
        id: 'f1',
        questionText: 'The Filipino word for dog is ___',
        correctAnswer: 'Aso',
        choices: [],
        format: QuestionFormat.fillInBlank,
      );
      const trueFalse = AssessmentQuestion(
        id: 't1',
        questionText: 'Aso means dog.',
        correctAnswer: 'True',
        choices: ['True', 'False'],
        format: QuestionFormat.trueFalse,
      );

      final out = AssessmentService.limitChoices([fill, trueFalse], 2);
      expect(out[0].choices, isEmpty);
      expect(out[1].choices, ['True', 'False']);
    });

    test('an item already short enough is untouched', () {
      const q = AssessmentQuestion(
        id: 'q1',
        questionText: 'Pick one',
        correctAnswer: 'Aso',
        choices: ['Aso', 'Pusa'],
      );
      expect(AssessmentService.limitChoices([q], 2).single.choices, [
        'Aso',
        'Pusa',
      ]);
    });

    test('question ids survive, so pre/post items still pair up', () {
      final narrowed = AssessmentService.limitChoices(quiz().questions, 2);
      expect(
        narrowed.map((q) => q.id),
        quiz().questions.map((q) => q.id),
      );
    });

    testWidgets('the learner is shown two choices, not four', (tester) async {
      await pumpQuiz(tester, quiz(), const {
        LearnerSupportOption.fewerChoices,
      });

      // "Aso" is always kept; exactly one of the three distractors joins it.
      expect(find.text('Aso'), findsOneWidget);
      final shown = ['Pusa', 'Ibon', 'Isda']
          .where((c) => find.text(c).evaluate().isNotEmpty)
          .length;
      expect(shown, 1);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without the accommodation all four are shown', (tester) async {
      await pumpQuiz(tester, quiz(), const {});

      for (final choice in const ['Aso', 'Pusa', 'Ibon', 'Isda']) {
        expect(find.text(choice), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
