import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

import 'support/device_matrix.dart';

/// The assessment time limit.
///
/// `Assessment.timeLimitMinutes` was written by the builder's slider, by the
/// quiz builder, and by the hard-difficulty generator — and read by nothing at
/// all. A teacher setting "10 min" was setting a field, not a limit.
///
/// No Hive in this file: the result notifier is faked in memory, so the finish
/// path can be exercised without a `box.put` from inside the fake-async zone.

class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );
}

/// In-memory stand-in for [AssessmentResultsNotifier] — collects what would
/// have been persisted so a test can assert the submission without touching a
/// box.
class _FakeResults extends StateNotifier<List<AssessmentResult>>
    implements AssessmentResultsNotifier {
  _FakeResults() : super([]);

  @override
  String get profileId => 'learner-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

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
    id: 'timed-1',
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

  late _FakeResults results;
  late List<String> visited;
  late DateTime fakeNow;

  Future<void> pumpQuiz(
    WidgetTester tester,
    Assessment assessment, {
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    results = _FakeResults();
    visited = [];
    fakeNow = DateTime(2026, 8, 22, 9);

    final router = GoRouter(
      initialLocation: '/take',
      routes: [
        GoRoute(
          path: '/take',
          builder: (_, _) =>
              AssessmentTestScreen(assessment: assessment, clock: () => fakeNow),
        ),
        GoRoute(
          path: '/assessment/summary',
          builder: (_, state) {
            visited.add(state.uri.path);
            return const Scaffold(body: Center(child: Text('SUMMARY')));
          },
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
          profileProvider.overrideWith(_StubProfileNotifier.new),
          // Answering reads the haptic service, which is settings-box backed;
          // this file deliberately opens no boxes.
          hapticServiceProvider.overrideWithValue(
            HapticService(enabled: false),
          ),
          assessmentResultsProvider.overrideWith((ref) => results),
          // Keep the star award (a progress write) out of this file.
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Advances the injected clock and the fake-async clock together, one second
  /// at a time, so the periodic tick sees time actually pass.
  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('an untimed assessment shows no clock', (tester) async {
    await pumpQuiz(tester, quiz());

    expect(find.byIcon(Icons.schedule_rounded), findsNothing);

    await tick(tester, 300);
    expect(find.text('SUMMARY'), findsNothing);
    expect(results.state, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a timed assessment counts down', (tester) async {
    await pumpQuiz(tester, quiz(timeLimitMinutes: 2));

    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);

    await tick(tester, 1);
    expect(find.text('1:59'), findsOneWidget);

    await tick(tester, 59);
    expect(find.text('1:00'), findsOneWidget);

    await tick(tester, 59);
    expect(find.text('0:01'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('running out of time submits what was answered', (tester) async {
    await pumpQuiz(tester, quiz(timeLimitMinutes: 1));

    // Answer the first question correctly, then let the clock run out with two
    // questions still unseen.
    await tester.tap(find.text('Aso').first);
    await tester.pump();

    await tick(tester, 61);
    await tester.pumpAndSettle();

    expect(find.text('SUMMARY'), findsOneWidget);
    expect(visited, ['/assessment/summary']);
    expect(results.state, hasLength(1));
    final result = results.state.single;
    expect(result.score, 1);
    expect(
      result.totalQuestions,
      3,
      reason: 'unreached questions still count against a timed test',
    );
  });

  testWidgets('the clock cannot submit a second time', (tester) async {
    await pumpQuiz(tester, quiz(timeLimitMinutes: 1, questions: 1));

    // Finish the single question normally, well inside the limit...
    await tester.tap(find.text('Aso').first);
    await tester.pump();
    await tester.tap(find.textContaining('Finish'));
    await tester.pumpAndSettle();

    expect(results.state, hasLength(1));

    // ...then push past the deadline. The timer must not fire a second save.
    await tick(tester, 61);
    await tester.pumpAndSettle();

    expect(
      results.state,
      hasLength(1),
      reason: 'a duplicate result would double-count in the learner\'s history '
          'and in the educator\'s tracking view',
    );
  });

  // The countdown shares the progress row; at 2.0x text on a 360-wide phone
  // that row is the one most likely to burst.
  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('a timed quiz lays out at ${device.label}, ${scale}x text', (
        tester,
      ) async {
        await pumpQuiz(
          tester,
          quiz(timeLimitMinutes: 10),
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
          reason: 'timed quiz at ${device.label} ${scale}x: $firstError',
        );
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

        // A timed quiz keeps a live `Timer.periodic` and the choice cards keep
        // entrance-animation timers, including a zero-duration one created in
        // initState. Let those fire, then unmount here in the body — the
        // binding checks for pending timers before tearDowns run.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
