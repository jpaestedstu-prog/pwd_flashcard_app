import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_builder_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Editing a saved custom assessment: the same id and history, the learners'
/// tablets told, and the scores already earned left alone.
///
/// Hive is seeded once in `setUpAll`; the widget tests only read it.

class _Teacher extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'teacher-1',
    name: 'Sir Kevin',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

class _FakeCustom extends StateNotifier<List<Assessment>>
    implements CustomAssessmentsNotifier {
  _FakeCustom(super.initial);

  final List<Assessment> saved = [];

  @override
  String get profileId => 'teacher-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void refresh() {}

  @override
  Future<void> saveAssessment(Assessment assessment) async {
    saved.add(assessment);
    state = [...state.where((a) => a.id != assessment.id), assessment];
  }

  @override
  Future<void> deleteAssessment(String assessmentId) async {}
}

class _FakeAssignments extends StateNotifier<List<AssessmentAssignment>>
    implements AssignmentsNotifier {
  _FakeAssignments(super.initial);

  final List<AssessmentAssignment> saved = [];

  @override
  String get educatorId => 'teacher-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void refresh() {}

  @override
  Future<CloudSyncOutcome> saveAssignment(
    AssessmentAssignment assignment,
  ) async {
    saved.add(assignment);
    state = [...state.where((a) => a.id != assignment.id), assignment];
    return CloudSyncOutcome.synced;
  }

  @override
  Future<CloudSyncOutcome> deleteAssignment(String assignmentId) async =>
      CloudSyncOutcome.synced;
}

const _q1 = AssessmentQuestion(
  id: 'q1',
  questionText: 'Which one says meow?',
  correctAnswer: 'Cat',
  choices: ['Cat', 'Dog'],
);

const _q2 = AssessmentQuestion(
  id: 'q2',
  questionText: 'Which one barks?',
  correctAnswer: 'Dog',
  choices: ['Cat', 'Dog'],
);

final _quiz = Assessment(
  id: 'a1',
  title: 'Animal quiz',
  description: 'Pets at home',
  type: AssessmentType.custom,
  questions: const [_q1, _q2],
  difficulty: GameDifficulty.easy,
  timeLimitMinutes: 12,
  createdBy: 'teacher-1',
  createdAt: DateTime(2026, 9),
);

final _preTest = Assessment(
  id: 'pre1',
  title: 'Pre-Test',
  type: AssessmentType.preTest,
  questions: const [_q1],
  createdBy: 'teacher-1',
  createdAt: DateTime(2026, 9),
);

AssessmentAssignment _assignment() => AssessmentAssignment(
  id: 'as1',
  assessmentId: 'a1',
  assessmentTitle: 'Animal quiz',
  assignedBy: 'teacher-1',
  studentIds: const ['learner-1'],
  assignedAt: DateTime(2026, 9, 2),
  feedback: {
    'learner-1': AssessmentFeedback(
      note: 'Well done',
      updatedAt: DateTime(2026, 9, 3),
    ),
  },
  media: const AssessmentMedia(photo: 'https://example.com/p.png'),
);

void main() {
  // ─── The data ────────────────────────────────────────────

  group('the data', () {
    test('an assessment remembers when it was edited; an old one reads as '
        'never edited', () {
      final edited = Assessment.fromJson({
        ..._quiz.toJson(),
        'updatedAt': DateTime(2026, 9, 20).toIso8601String(),
      });
      expect(edited.updatedAt, DateTime(2026, 9, 20));
      expect(edited.createdAt, DateTime(2026, 9));
      expect(edited.withQuestions(const [_q1]).updatedAt, edited.updatedAt);

      expect(_quiz.toJson().containsKey('updatedAt'), isFalse);
      expect(Assessment.fromJson(_quiz.toJson()).updatedAt, isNull);
    });

    test('an edit stamps the assignment and renames it; feedback and media '
        'stay', () {
      final a = _assignment();
      final at = DateTime(2026, 9, 20, 10);
      final edited = a.withEditedAssessment(title: 'Animals', editedAt: at);
      expect(edited.assessmentTitle, 'Animals');
      expect(edited.assessmentEditedAt, at);
      expect(edited.feedbackFor('learner-1')?.note, 'Well done');
      expect(edited.media.photo, 'https://example.com/p.png');

      final back = AssessmentAssignment.fromJson(edited.toJson());
      expect(back.assessmentEditedAt, at);
      // Later copies keep the stamp.
      expect(back.withMedia(AssessmentMedia.none).assessmentEditedAt, at);
      expect(back.withFeedback('learner-1', null).assessmentEditedAt, at);
      // An assignment saved before this existed.
      expect(AssessmentAssignment.fromJson(a.toJson()).assessmentEditedAt, isNull);
    });

    test('the stamp changes the revision a learner tablet watches, so it '
        'fetches the new version', () {
      final a = _assignment();
      final edited = a.withEditedAssessment(
        title: a.assessmentTitle,
        editedAt: DateTime(2026, 9, 20),
      );
      expect(
        AssessmentCloudService.revisionKey(a, 'learner-1'),
        isNot(AssessmentCloudService.revisionKey(edited, 'learner-1')),
      );
    });
  });

  // ─── The editor ──────────────────────────────────────────

  group('editing in the builder', () {
    setUpAll(() async {
      const cacheDir = './build/test_cache/assessment_edit';
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
      await AssessmentService.saveResult(
        'learner-1',
        AssessmentResult(
          id: 'r1',
          assessmentId: 'a1',
          profileId: 'learner-1',
          type: AssessmentType.custom,
          score: 2,
          totalQuestions: 2,
          answers: const [],
          completedAt: DateTime(2026, 9, 5),
          durationSeconds: 60,
        ),
      );
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <void>[],
      );
    });

    test('who has already sat an assessment', () {
      expect(AssessmentService.learnersWhoTook('a1'), {'learner-1'});
      expect(AssessmentService.learnersWhoTook('nope'), isEmpty);
    });

    late _FakeCustom custom;
    late _FakeAssignments assignments;

    Future<void> openEditor(WidgetTester tester, String editId) async {
      custom = _FakeCustom([_quiz, _preTest]);
      assignments = _FakeAssignments([_assignment()]);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push(
                    '/assessment/builder?edit=$editId',
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/assessment/builder',
            builder: (_, state) => AssessmentBuilderScreen(
              editId: state.uri.queryParameters['edit'],
            ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1200, 2400) * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_Teacher.new),
            customAssessmentsProvider.overrideWith((ref) => custom),
            assignmentsProvider.overrideWith((ref) => assignments),
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
      await tester.pump();
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> unmount(WidgetTester tester) async {
      // The create-mode empty state animates for ever; step the clock out.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('opens with everything already saved, and says who has sat it', (
      tester,
    ) async {
      await openEditor(tester, 'a1');
      expect(find.text('Edit Assessment'), findsOneWidget);
      expect(find.text('Animal quiz'), findsOneWidget);
      expect(find.text('Pets at home'), findsOneWidget);
      expect(find.text('Questions (2)'), findsOneWidget);
      expect(find.text('Which one barks?'), findsOneWidget);
      expect(find.text('12 min'), findsWidgets);
      expect(
        find.textContaining('1 learner has already taken this.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('saving keeps the id and history and tells the assignment', (
      tester,
    ) async {
      await openEditor(tester, 'a1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Animal quiz'), 'Animals');
      // Drop the second question.
      await tester.tap(find.byTooltip('Delete').last);
      await tester.pump();
      expect(find.text('Questions (1)'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final saved = custom.saved.single;
      expect(saved.id, 'a1');
      expect(saved.title, 'Animals');
      expect(saved.createdAt, DateTime(2026, 9));
      expect(saved.createdBy, 'teacher-1');
      expect(saved.updatedAt, isNotNull);
      expect(saved.description, 'Pets at home');
      expect(saved.timeLimitMinutes, 12);
      expect(saved.questions.map((q) => q.id), ['q1']);

      final sent = assignments.saved.single;
      expect(sent.id, 'as1');
      expect(sent.assessmentTitle, 'Animals');
      expect(sent.assessmentEditedAt, saved.updatedAt);
      expect(sent.feedbackFor('learner-1')?.note, 'Well done');

      expect(
        find.text(
          'Changes to “Animals” saved and sent to the tablets it is assigned to',
        ),
        findsOneWidget,
      );
      expect(find.text('OPEN'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('closing a question sheet does not hand the keyboard back to '
        'the title', (tester) async {
      await openEditor(tester, 'a1');
      final title = find.widgetWithText(TextFormField, 'Animal quiz');
      await tester.tap(title);
      await tester.pump();
      EditableText field() => tester.widget<EditableText>(
        find.descendant(of: title, matching: find.byType(EditableText)),
      );
      expect(field().focusNode.hasFocus, isTrue);

      await tester.tap(find.byTooltip('Edit Question').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Update Question'));
      await tester.tap(find.text('Update Question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Update Question'), findsNothing);
      // Found on a tablet: the sheet returned focus to the title, and the
      // keyboard sprang up over the list just added to.
      expect(field().focusNode.hasFocus, isFalse);
      await unmount(tester);
    });

    testWidgets('closing with nothing changed just closes; with a change it '
        'asks first', (tester) async {
      await openEditor(tester, 'a1');
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Discard your changes?'), findsNothing);
      expect(find.text('OPEN'), findsOneWidget);

      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.enterText(find.widgetWithText(TextFormField, 'Animal quiz'), 'Changed');
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.text('The saved assessment stays as it was.'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(custom.saved, isEmpty);
      expect(find.text('OPEN'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an id that is not one of theirs builds a new one, and says '
        'why', (tester) async {
      await openEditor(tester, 'gone');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Create Assessment'), findsOneWidget);
      expect(
        find.text('That assessment could not be found. It may have been deleted.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('the study\'s pre-test is never opened for editing', (
      tester,
    ) async {
      await openEditor(tester, 'pre1');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Create Assessment'), findsOneWidget);
      expect(find.text('Edit Assessment'), findsNothing);
      await unmount(tester);
    });
  });
}
