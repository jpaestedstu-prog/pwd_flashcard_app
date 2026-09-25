import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/core/utils/research_export_rows.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_summary_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_publisher.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_store.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/class_analysis.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_panel.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_sheets.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

/// Answers a learner signs or says on camera, and a person marks.
///
/// The persistence cases are plain `test()`s; the widget cases never write
/// to Hive (results go to a fake notifier).

class _Learner extends ProfileNotifier {
  static DisabilityType type = DisabilityType.hearing;

  @override
  UserProfile? build() => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: type,
  );
}

class _FakeResults extends StateNotifier<List<AssessmentResult>>
    implements AssessmentResultsNotifier {
  _FakeResults() : super([]);

  static final List<AssessmentResult> saved = [];

  @override
  String get profileId => 'learner-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void Function()? get onUploadMissed => null;

  @override
  Future<void> saveResult(AssessmentResult result) async {
    saved.add(result);
    state = [...state, result];
  }

  @override
  void refresh() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryBackend implements SharedMediaBackend {
  final Map<String, SharedMediaMeta> metas = {};
  final Map<String, Uint8List> chunks = {};

  @override
  Future<void> writeMeta(SharedMediaMeta meta) async => metas[meta.id] = meta;
  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async =>
      chunks['$id/$index'] = Uint8List.fromList(bytes);
  @override
  Future<SharedMediaMeta?> readMeta(String id) async => metas[id];
  @override
  Future<Uint8List?> readChunk(String id, int index) async =>
      chunks['$id/$index'];
  @override
  Future<void> deleteChunk(String id, int index) async =>
      chunks.remove('$id/$index');
  @override
  Future<void> deleteMeta(String id) async => metas.remove(id);
}

const _video = AssessmentQuestion(
  id: 'v1',
  questionText: 'Show me the sign for cat.',
  correctAnswer: 'Both hands brush whiskers from the cheeks',
  choices: [],
  format: QuestionFormat.videoResponse,
);

const _mc = AssessmentQuestion(
  id: 'm1',
  questionText: 'Which one says meow?',
  correctAnswer: 'Cat',
  choices: ['Cat', 'Dog'],
);

AssessmentResult _result({
  List<QuestionAnswer> answers = const [],
  int score = 1,
  int total = 1,
}) => AssessmentResult(
  id: 'r1',
  assessmentId: 'a1',
  profileId: 'learner-1',
  type: AssessmentType.custom,
  score: score,
  totalQuestions: total,
  answers: answers,
  completedAt: DateTime(2026, 9, 26),
  durationSeconds: 60,
);

void main() {
  // ─── The rules ───────────────────────────────────────────

  group('the data', () {
    test('a video answer says it needs review; others stay as they were', () {
      const video = QuestionAnswer(
        questionId: 'v1',
        givenAnswer: 'shared://abc',
        isCorrect: false,
        responseTimeMs: 1000,
        needsReview: true,
      );
      expect(QuestionAnswer.fromJson(video.toJson()).needsReview, isTrue);
      const plain = QuestionAnswer(
        questionId: 'm1',
        givenAnswer: 'Cat',
        isCorrect: true,
        responseTimeMs: 1000,
      );
      expect(plain.toJson().containsKey('needsReview'), isFalse);
    });

    test('feedback carries the marks, and marks alone are worth saving', () {
      final fb = AssessmentFeedback(
        updatedAt: DateTime(2026, 9, 26),
        reviews: const {'v1': true, 'v2': false},
      );
      expect(fb.isEmpty, isFalse);
      expect(AssessmentFeedback.tryFromJson(fb.toJson())!.reviews, fb.reviews);
    });

    test('the reviewed score counts marks in, and waiting answers out', () {
      final result = _result(
        answers: const [
          QuestionAnswer(questionId: 'm1', givenAnswer: 'Cat', isCorrect: true, responseTimeMs: 1),
          QuestionAnswer(questionId: 'v1', givenAnswer: 'shared://a', isCorrect: false, responseTimeMs: 1, needsReview: true),
          QuestionAnswer(questionId: 'v2', givenAnswer: 'shared://b', isCorrect: false, responseTimeMs: 1, needsReview: true),
        ],
      );
      final none = result.reviewedWith(null);
      expect((none.correct, none.total, none.pending), (1, 1, 2));
      final some = result.reviewedWith(
        AssessmentFeedback(updatedAt: DateTime(2026), reviews: const {'v1': true}),
      );
      expect((some.correct, some.total, some.pending), (2, 2, 1));
    });

    test('a test of video answers only has no automatic score', () {
      expect(_result(score: 0, total: 0).hasAutoScore, isFalse);
      expect(_result(score: 0, total: 0).percentage, 0);
    });

    test('the class report does not count a waiting answer as wrong', () {
      final results = [
        for (var i = 0; i < 4; i++)
          AssessmentResult(
            id: 'r$i',
            assessmentId: 'a',
            profileId: 'l$i',
            type: AssessmentType.custom,
            score: 1,
            totalQuestions: 1,
            answers: const [
              QuestionAnswer(questionId: 'm1', givenAnswer: 'Cat', isCorrect: true, responseTimeMs: 1),
              QuestionAnswer(questionId: 'v1', givenAnswer: 'shared://x', isCorrect: false, responseTimeMs: 1, needsReview: true),
            ],
            completedAt: DateTime(2026),
            durationSeconds: 1,
          ),
      ];
      final stats = ClassAnalysis.itemStats(results);
      expect(stats.map((s) => s.questionId), ['m1']);
    });

    test('the research export leaves video answers out', () {
      final rows = ResearchExportRows.itemResponseRows(
        studentId: 's',
        groupLabel: 'g',
        results: [
          _result(
            answers: const [
              QuestionAnswer(questionId: 'm1', givenAnswer: 'Cat', isCorrect: true, responseTimeMs: 1),
              QuestionAnswer(questionId: 'v1', givenAnswer: 'shared://x', isCorrect: false, responseTimeMs: 1, needsReview: true),
            ],
          ),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single, contains(',m1,'));
    });
  });

  group('shared once the learner is back online', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('video_answers');
      Hive.init(root.path);
      await Hive.openBox('progress', compactionStrategy: (_, _) => false);
      SharedMediaService.debugBackend = _MemoryBackend();
      SharedMediaService.debugDirectory = () async => root;
      AssessmentMediaStore.debugDirectory = () async => root;
    });

    tearDown(() async {
      SharedMediaService.debugBackend = null;
      SharedMediaService.debugDirectory = null;
      AssessmentMediaStore.debugDirectory = null;
      await Hive.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('a generated test never contains a video answer', () {
      // "Hard" rolls any format — including this one, which the app cannot
      // mark. The study's instrument must stay automatically scored.
      // 40 tests of 15 items: a 1-in-6 roll per item would surface.
      for (var run = 0; run < 40; run++) {
        final test = AssessmentService.generateStandardAssessment(
          profileId: 'p',
          type: AssessmentType.preTest,
          difficulty: GameDifficulty.hard,
        );
        expect(
          test.questions.where((q) => q.format == QuestionFormat.videoResponse),
          isEmpty,
          reason: 'run $run',
        );
      }
    });

    test('an answer recorded offline is shared and its result updated', () async {
      final src = File('${root.path}/take.mp4')..writeAsBytesSync([1, 2, 3]);
      final value = (await const AssessmentMediaStore().adopt(
        sourcePath: src.path,
        ownerKey: 'ans',
        kind: AssessmentMediaKind.video,
      )).value!;
      await AssessmentService.saveResult(
        'learner-1',
        _result(
          score: 0,
          total: 0,
          answers: [
            QuestionAnswer(
              questionId: 'v1',
              givenAnswer: value,
              isCorrect: false,
              responseTimeMs: 1,
              needsReview: true,
            ),
          ],
        ),
      );

      expect(
        await const AssessmentMediaPublisher().publishLearnerAnswers('learner-1'),
        1,
      );
      final results = AssessmentService.getResults('learner-1');
      expect(results, hasLength(1), reason: 'the same sitting, not a second');
      expect(
        SharedMediaService.isShared(results.single.answers.single.givenAnswer),
        isTrue,
      );
    });
  });

  // ─── On screen ───────────────────────────────────────────

  setUp(() {
    AssessmentMediaPanel.debugVideoBuilder = (context, value, kind, autoplay) =>
        Text('VIDEO:$value');
    AssessmentMediaCache.debugFetch = (_) async => null;
    _FakeResults.saved.clear();
  });

  tearDown(() {
    AssessmentMediaPanel.debugVideoBuilder = null;
    AssessmentMediaCache.debugFetch = null;
    _Learner.type = DisabilityType.hearing;
  });

  List<Override> overrides() => [
    profileProvider.overrideWith(_Learner.new),
    hapticServiceProvider.overrideWithValue(HapticService(enabled: false)),
    assessmentResultsProvider.overrideWith((ref) => _FakeResults()),
    gamificationFeatureProvider(
      GamificationFeature.stars,
    ).overrideWithValue(false),
  ];

  Future<void> pumpTest(
    WidgetTester tester,
    List<AssessmentQuestion> questions, {
    List<String> takes = const ['file:///d/assessment_media/take1.mp4'],
  }) async {
    var take = 0;
    final router = GoRouter(
      initialLocation: '/take',
      routes: [
        GoRoute(
          path: '/take',
          builder: (_, _) => AssessmentTestScreen(
            assessment: Assessment(
              id: 'a1',
              title: 'Signs',
              type: AssessmentType.custom,
              questions: questions,
              createdBy: 'teacher-1',
              createdAt: DateTime(2026, 9),
            ),
            clock: () => DateTime(2026, 9, 26, 9),
            prepareSignClips: (_) async => const [],
            prepareMedia: (_) async => const [],
            recordAnswer: (context, prompt) async =>
                takes[(take++).clamp(0, takes.length - 1)],
          ),
        ),
        GoRoute(
          path: '/assessment/summary',
          builder: (_, state) =>
              AssessmentSummaryScreen(result: state.extra! as AssessmentResult),
        ),
      ],
    );
    tester.view.physicalSize = const Size(1200, 3000) * 1.75;
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> settleAndUnmount(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('answering on camera', () {
    testWidgets('a Deaf learner is asked to sign, records, and is told it '
        'went to their teacher', (tester) async {
      _Learner.type = DisabilityType.hearing;
      await pumpTest(tester, const [_video]);
      expect(find.text('Sign your answer to the camera.'), findsOneWidget);

      await tester.tap(find.text('Record your answer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Answer saved — your teacher or parent will watch it.'),
        findsOneWidget,
      );
      expect(find.text('Not quite'), findsNothing,
          reason: 'a video answer is never marked wrong by the app');
      expect(find.text('VIDEO:file:///d/assessment_media/take1.mp4'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
      await settleAndUnmount(tester);
    });

    testWidgets('a learner with low vision is asked to say it', (tester) async {
      _Learner.type = DisabilityType.visual;
      await pumpTest(tester, const [_video]);
      expect(find.text('Say your answer out loud to the camera.'), findsOneWidget);
      await settleAndUnmount(tester);
    });

    testWidgets('recording again replaces the answer, and only marked '
        'questions are scored', (tester) async {
      await pumpTest(
        tester,
        const [_mc, _video],
        takes: const [
          'file:///d/assessment_media/take1.mp4',
          'file:///d/assessment_media/take2.mp4',
        ],
      );
      await tester.tap(find.text('Cat'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Next Question'));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Record your answer'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Record again'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('VIDEO:file:///d/assessment_media/take2.mp4'), findsOneWidget);

      await tester.tap(find.text('Finish Assessment'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final result = _FakeResults.saved.single;
      expect(result.score, 1);
      expect(result.totalQuestions, 1, reason: 'the video item is not scored');
      expect(result.answers, hasLength(2), reason: 'one answer per question');
      expect(result.reviewAnswers.single.givenAnswer,
          'file:///d/assessment_media/take2.mp4');
      expect(find.text('1 answer to review'), findsOneWidget);
      await settleAndUnmount(tester);
    });

    testWidgets('a test of video answers only is "sent", never "0%"', (
      tester,
    ) async {
      await pumpTest(tester, const [_video]);
      await tester.tap(find.text('Record your answer'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Finish Assessment'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Sent to your teacher or parent'), findsWidgets);
      expect(find.text('0%'), findsNothing);
      await settleAndUnmount(tester);
    });
  });

  group('marking', () {
    testWidgets('the teacher marks a video answer and it is sent with the '
        'feedback', (tester) async {
      FeedbackEdit? edit;
      tester.view.physicalSize = const Size(1200, 3000) * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async => edit = await showFeedbackEditor(
                    context,
                    learnerName: 'Ana',
                    assignmentTitle: 'Signs',
                    ownerKey: 'fb',
                    result: _result(
                      score: 0,
                      total: 0,
                      answers: const [
                        QuestionAnswer(
                          questionId: 'v1',
                          givenAnswer: 'shared://ana_take',
                          isCorrect: false,
                          responseTimeMs: 1,
                          needsReview: true,
                        ),
                      ],
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Video answers to check'), findsOneWidget);
      expect(find.text('VIDEO:shared://ana_take'), findsOneWidget);
      expect(find.text('1 answer to review'), findsOneWidget);

      await tester.tap(find.text('Correct'));
      await tester.pump();
      expect(find.text('Score: 100%'), findsOneWidget);

      await tester.ensureVisible(find.text('Send feedback'));
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(edit?.feedback?.reviews, {'v1': true});
    });
  });
}
