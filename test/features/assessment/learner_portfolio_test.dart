import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/learner_portfolio.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/learner_portfolio_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/portfolio_pdf.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_panel.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';

/// A learner's portfolio: the pure rules, the PDF a parent takes home, and
/// the screen as the learner and as their teacher see it.
///
/// Hive is seeded once in `setUpAll`; the widget tests only read it.

class _Learner extends ProfileNotifier {
  static String id = 'learner-1';

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Ana',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: DisabilityType.hearing,
  );
}

class _Teacher extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'teacher-1',
    name: 'Sir Kevin',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

const _videoQ = AssessmentQuestion(
  id: 'v1',
  questionText: 'Show me the sign for cat.',
  correctAnswer: 'Brushes whiskers',
  choices: [],
  format: QuestionFormat.videoResponse,
);

const _mcQ = AssessmentQuestion(
  id: 'm1',
  questionText: 'Which one says meow?',
  correctAnswer: 'Cat',
  choices: ['Cat', 'Dog'],
);

const _videoAnswer = QuestionAnswer(
  questionId: 'v1',
  givenAnswer: 'shared://ana_take',
  isCorrect: false,
  responseTimeMs: 1,
  needsReview: true,
);

AssessmentResult _result(
  String id, {
  String assessmentId = 'a1',
  AssessmentType type = AssessmentType.custom,
  int score = 1,
  int total = 2,
  List<QuestionAnswer> answers = const [],
  DateTime? at,
  Set<LearnerSupportOption> accommodations = const {},
}) => AssessmentResult(
  id: id,
  assessmentId: assessmentId,
  profileId: 'learner-1',
  type: type,
  score: score,
  totalQuestions: total,
  answers: answers,
  completedAt: at ?? DateTime(2026, 9, 20),
  durationSeconds: 60,
  accommodations: accommodations,
);

AssessmentAssignment _assignment({
  AssessmentFeedback? feedback,
  String assessmentId = 'a1',
}) => AssessmentAssignment(
  id: 'as1',
  assessmentId: assessmentId,
  assessmentTitle: 'Animal signs',
  assignedBy: 'teacher-1',
  studentIds: const ['learner-1'],
  assignedAt: DateTime(2026, 9, 18),
  feedback: {'learner-1': ?feedback},
);

/// A 1×1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fil = lookupAppLocalizations(const Locale('fil'));

  // ─── The rules ───────────────────────────────────────────

  group('the portfolio', () {
    test('newest first; a result carries the marks on its video answers', () {
      final feedback = AssessmentFeedback(
        note: 'Great signing!',
        updatedAt: DateTime(2026, 9, 22),
        reviews: const {'v1': true},
      );
      final p = LearnerPortfolio.from(
        learnerId: 'learner-1',
        results: [
          _result('old', assessmentId: 'a0', at: DateTime(2026, 9)),
          _result('new', answers: const [_videoAnswer]),
        ],
        feedback: [(assignment: _assignment(), feedback: feedback)],
        titleOf: (r) => r.assessmentId == 'a1' ? 'Animal signs' : null,
      );

      expect(p.entries.map((e) => e.isResult), [false, true, true]);
      expect(p.entries.first.at, DateTime(2026, 9, 22));
      final sitting = p.entries[1];
      expect(sitting.result!.id, 'new');
      expect(sitting.feedback, same(feedback));
      // 1 of 2 marked automatically, plus the video answer marked correct.
      expect(sitting.score, (correct: 2, total: 3, pending: 0));
      expect(p.testsTaken, 2);
      expect(p.videoAnswers, 1);
      expect(p.feedbackCount, 1);
    });

    test('marks alone are not a feedback entry; nothing is not a portfolio', () {
      final p = LearnerPortfolio.from(
        learnerId: 'learner-1',
        results: [
          _result('r', score: 0, total: 0, answers: const [_videoAnswer]),
        ],
        feedback: [
          (
            assignment: _assignment(),
            feedback: AssessmentFeedback(
              updatedAt: DateTime(2026, 9, 22),
              reviews: const {'v1': false},
            ),
          ),
        ],
        titleOf: (_) => null,
      );
      expect(p.entries, hasLength(1));
      expect(p.feedbackCount, 0);
      expect(p.entries.single.score, (correct: 0, total: 1, pending: 0));

      final empty = LearnerPortfolio.from(
        learnerId: 'x',
        results: const [],
        feedback: const [],
        titleOf: (_) => null,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.averageScore, isNull);
    });

    test('an unmarked video-only test is waiting, not 0%, and is left out of '
        'the average', () {
      final p = LearnerPortfolio.from(
        learnerId: 'learner-1',
        results: [
          _result('scored', score: 3, total: 4),
          _result(
            'video',
            score: 0,
            total: 0,
            answers: const [_videoAnswer],
            at: DateTime(2026, 9, 21),
          ),
        ],
        feedback: const [],
        titleOf: (_) => null,
      );
      final video = p.entries.first;
      expect(video.fraction, isNull);
      expect(video.score!.pending, 1);
      expect(p.averageScore, 0.75);
    });

    test('the app names the pre-test in the reader\'s language', () {
      final p = LearnerPortfolio.from(
        learnerId: 'learner-1',
        results: [
          _result('pre', type: AssessmentType.preTest),
          _result('c', at: DateTime(2026, 9, 21)),
        ],
        feedback: const [],
        titleOf: (r) => r.type == AssessmentType.custom ? 'Animal signs' : null,
      );
      final pre = p.entries.last;
      expect(pre.titleOf(en), en.assessPreTest);
      expect(pre.titleOf(fil), fil.assessPreTest);
      expect(fil.assessPreTest, isNot(en.assessPreTest));
      expect(p.entries.first.titleOf(fil), 'Animal signs');
    });
  });

  // ─── The PDF ─────────────────────────────────────────────

  group('the PDF for parents', () {
    late LearnerPortfolio portfolio;

    setUp(() {
      portfolio = LearnerPortfolio.from(
        learnerId: 'learner-1',
        results: [
          _result(
            'r',
            answers: const [_videoAnswer],
            accommodations: const {LearnerSupportOption.extendedTestTime},
          ),
          _result(
            'pre',
            type: AssessmentType.preTest,
            at: DateTime(2026, 9),
          ),
        ],
        feedback: [
          (
            assignment: _assignment(),
            feedback: AssessmentFeedback(
              note: 'Ang galing mo — “pusa” 🐱… keep going →',
              media: const AssessmentMedia(
                photo: 'https://example.com/cat.png',
                sign: 'shared://sign1',
                description: 'A cat washing its face',
              ),
              updatedAt: DateTime(2026, 9, 22),
              reviews: const {'v1': true},
            ),
          ),
        ],
        titleOf: (r) => r.type == AssessmentType.custom ? 'Animal signs' : null,
      );
    });

    tearDown(() {
      PortfolioPdf.debugTheme = null;
      PortfolioPdf.debugLoadPicture = null;
    });

    bool isPdf(Uint8List bytes) =>
        ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-';

    test('builds with the bundled font, in Filipino, emoji and all', () async {
      PortfolioPdf.debugTheme = () async => pw.ThemeData.withFont(
        base: pw.Font.ttf(
          (await File('google_fonts/NotoSans-Regular.ttf').readAsBytes())
              .buffer
              .asByteData(),
        ),
        bold: pw.Font.ttf(
          (await File('google_fonts/NotoSans-Bold.ttf').readAsBytes())
              .buffer
              .asByteData(),
        ),
      );
      PortfolioPdf.debugLoadPicture = (_) async => null;
      // The PDF library prints, rather than throws, when a glyph is missing.
      final printed = <String>[];
      final bytes = await runZoned(
        () => PortfolioPdf.build(
          portfolio,
          learnerName: 'Ana Dela Cruz',
          l10n: fil,
          now: DateTime(2026, 9, 26),
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      expect(isPdf(bytes), isTrue);
      expect(printed.where((l) => l.contains('Unable to find a font')), isEmpty);
      expect(
        PortfolioPdf.fontSafeForTest('Galing! 👍🏽 ⭐ “pusa” → ñ — ok…'),
        'Galing!   “pusa” -> ñ — ok…',
      );
    });

    test('builds without the font too: Helvetica gets plain punctuation', () async {
      PortfolioPdf.debugTheme = () async => null;
      PortfolioPdf.debugLoadPicture = (_) async => null;
      final bytes = await PortfolioPdf.build(
        portfolio,
        learnerName: 'Ana',
        l10n: en,
      );
      expect(isPdf(bytes), isTrue);
      expect(
        PortfolioPdf.latin1SafeForTest('“pusa” — ok… → ñ 🐱'),
        '"pusa" - ok... -> ñ ',
      );
    });

    test('a picture it can reach is embedded; one it cannot read is skipped, '
        'never a failed PDF', () async {
      PortfolioPdf.debugTheme = () async => null;
      final asked = <String>[];

      PortfolioPdf.debugLoadPicture = (value) async {
        asked.add(value);
        return null;
      };
      final without = await PortfolioPdf.build(
        portfolio,
        learnerName: 'Ana',
        l10n: en,
      );
      // Only the photo: a sign video is named, not fetched.
      expect(asked, ['https://example.com/cat.png']);

      PortfolioPdf.debugLoadPicture = (_) async => Uint8List.fromList(_png);
      final withPicture = await PortfolioPdf.build(
        portfolio,
        learnerName: 'Ana',
        l10n: en,
      );
      expect(withPicture.length, greaterThan(without.length));

      PortfolioPdf.debugLoadPicture = (_) async =>
          Uint8List.fromList(utf8.encode('not a picture at all'));
      final broken = await PortfolioPdf.build(
        portfolio,
        learnerName: 'Ana',
        l10n: en,
      );
      expect(isPdf(broken), isTrue);
    });
  });

  // ─── The screen ──────────────────────────────────────────

  group('the screen', () {
    setUpAll(() async {
      const cacheDir = './build/test_cache/learner_portfolio';
      try {
        final dir = Directory(cacheDir);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {
        // Still locked by a stray flutter_tester — Hive reports it below.
      }
      Hive.init(cacheDir);
      for (final name in const ['profiles', 'progress', 'settings']) {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name, compactionStrategy: (_, _) => false);
        }
      }
      await AssessmentService.saveAssessment(
        'teacher-1',
        Assessment(
          id: 'a1',
          title: 'Animal signs',
          type: AssessmentType.custom,
          questions: const [_mcQ, _videoQ],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ),
      );
      await AssessmentService.saveResult(
        'learner-1',
        _result(
          'r1',
          answers: const [
            QuestionAnswer(
              questionId: 'm1',
              givenAnswer: 'Cat',
              isCorrect: true,
              responseTimeMs: 1,
            ),
            _videoAnswer,
          ],
          total: 1,
        ),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        _assignment(
          feedback: AssessmentFeedback(
            note: 'Lovely signing, Ana!',
            media: const AssessmentMedia(photo: 'https://example.com/cat.png'),
            updatedAt: DateTime(2026, 9, 22),
            reviews: const {'v1': true},
          ),
        ),
      );
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <void>[],
      );
    });

    setUp(() {
      AssessmentMediaPanel.debugVideoBuilder =
          (context, value, kind, autoplay) => Text('VIDEO:$value');
      AssessmentMediaCache.debugFetch = (_) async => null;
    });

    tearDown(() {
      AssessmentMediaPanel.debugVideoBuilder = null;
      AssessmentMediaCache.debugFetch = null;
      _Learner.id = 'learner-1';
    });

    Future<void> pump(
      WidgetTester tester, {
      required bool teacher,
      Locale locale = const Locale('en'),
      Size size = const Size(1200, 1920),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              teacher ? _Teacher.new : _Learner.new,
            ),
            learnerAssignmentSyncProvider.overrideWith((ref, id) async => true),
            educatorAssessmentSyncProvider.overrideWith((ref, id) async {}),
            educatorLearnerRosterProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: teacher
                ? const LearnerPortfolioScreen(
                    learnerId: 'learner-1',
                    learnerName: 'Ana',
                  )
                : const LearnerPortfolioScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the learner sees their tests, marks and feedback — and no '
        'PDF button', (tester) async {
      await pump(tester, teacher: false);

      expect(find.text('My portfolio'), findsOneWidget);
      expect(find.text('Tests taken'), findsOneWidget);
      // 1 automatic + the video answer marked correct = 100%.
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Animal signs'), findsOneWidget);
      expect(find.text('Feedback on Animal signs'), findsOneWidget);
      expect(find.text('Lovely signing, Ana!'), findsOneWidget);
      expect(find.text('PDF for parents'), findsNothing);

      await tester.tap(find.text('Watch the video answers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Show me the sign for cat.'), findsOneWidget);
      expect(find.text('Marked correct'), findsOneWidget);
      expect(find.text('VIDEO:shared://ana_take'), findsOneWidget);
    });

    testWidgets('a learner with nothing yet is told what will appear', (
      tester,
    ) async {
      _Learner.id = 'learner-new';
      await pump(tester, teacher: false);
      expect(
        find.text(
          'Nothing here yet. Finished tests and feedback will show up here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the teacher sees the learner\'s, with the PDF for parents', (
      tester,
    ) async {
      await pump(tester, teacher: true);
      expect(find.text('Portfolio'), findsOneWidget);
      expect(
        find.text('Tests, video answers and feedback for Ana'),
        findsOneWidget,
      );
      expect(find.text('PDF for parents'), findsOneWidget);
      expect(find.text('Animal signs'), findsOneWidget);
    });

    testWidgets('in Filipino', (tester) async {
      await pump(tester, teacher: true, locale: const Locale('fil'));
      expect(find.text('Portpolyo'), findsOneWidget);
      expect(find.text('PDF para sa magulang'), findsOneWidget);
      expect(find.text('Natapos na pagsusulit'), findsOneWidget);
    });

    testWidgets('2x text on a small phone does not overflow', (tester) async {
      await pump(
        tester,
        teacher: true,
        locale: const Locale('fil'),
        size: const Size(360, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
