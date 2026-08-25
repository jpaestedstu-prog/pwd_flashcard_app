import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/custom_quiz_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_assign_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Keeping the Assign list usable as it grows.
///
/// Assigning a quiz mints a fresh assessment every time, so an educator who
/// sets the same quiz weekly accumulates entries with identical titles — seen
/// on a real tablet, where "My Quiz" the recipe sat directly above "My Quiz"
/// the assessment it had just produced.
///
/// Two things fix that: the list is split by *kind*, because a recipe and a
/// fixed test behave differently, and every row carries the date it was made.
///
/// `testWidgets` only — nothing here taps Assign, which writes.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier([this.id = 'educator-1']);
  final String id;

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Educator',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

void main() {
  const educatorId = 'educator-1';

  Assessment saved(String id, String title, DateTime when) => Assessment(
    id: id,
    title: title,
    type: AssessmentType.custom,
    questions: [
      const AssessmentQuestion(
        id: 'q1',
        questionText: 'What is the Filipino word for "dog"?',
        correctAnswer: 'Aso',
        choices: ['Aso', 'Pusa'],
        category: FlashcardCategory.animals,
      ),
    ],
    createdBy: educatorId,
    createdAt: when,
  );

  CustomQuiz recipe(String id, String title, DateTime when) => CustomQuiz(
    id: id,
    title: title,
    flashcardIds: const ['c0', 'c1', 'c2'],
    questionFormats: const [QuestionFormat.multipleChoice],
    createdBy: educatorId,
    createdAt: when,
  );

  setUpAll(() async {
    const cacheDir = './build/test_cache/assign_list_sections';
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
    final box = Hive.box('progress');
    await box.clear();
    // Two sittings of one quiz, plus the recipe that made them — the exact
    // shape that was unreadable before.
    await box.put('assessments_$educatorId', [
      saved('a-old', 'My Quiz', DateTime(2026, 8, 8)).toJson(),
      saved('a-new', 'My Quiz', DateTime(2026, 8, 22)).toJson(),
    ]);
    await box.put('custom_quizzes_$educatorId', [
      recipe('q1', 'My Quiz', DateTime(2026, 8)).toJson(),
    ]);
    // An educator who has never built a quiz.
    await box.put('assessments_educator-2', [
      saved('a-only', 'Colours Check', DateTime(2026, 8, 20)).toJson(),
    ]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpAssign(
    WidgetTester tester, {
    String profileId = educatorId,
  }) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
          allProfilesWithProgressProvider.overrideWithValue([
            (
              UserProfile(
                id: 's1',
                name: 'Student',
                role: UserRole.student,
                createdAt: DateTime(2026),
              ),
              LearningProgress(
                profileId: 's1',
                lastActivityDate: DateTime(2026, 8),
              ),
            ),
          ]),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssessmentAssignScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('recipes and fixed tests are separated', (tester) async {
    await pumpAssign(tester);

    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Saved assessments'), findsOneWidget);
    expect(
      find.text('Makes a fresh test each time you assign it'),
      findsOneWidget,
      reason: 'the two kinds behave differently and the list should say so',
    );
  });

  testWidgets('same-named rows are told apart by date', (tester) async {
    await pumpAssign(tester);

    // Three rows all called "My Quiz"; the date is the only thing separating
    // this week's sitting from last week's.
    expect(find.text('My Quiz'), findsNWidgets(3));
    expect(find.textContaining('22 Aug'), findsOneWidget);
    expect(find.textContaining('8 Aug'), findsOneWidget);
    expect(find.textContaining('1 Aug'), findsOneWidget);
  });

  testWidgets('the newest sitting is listed first', (tester) async {
    await pumpAssign(tester);

    final newest = tester.getTopLeft(find.textContaining('22 Aug')).dy;
    final older = tester.getTopLeft(find.textContaining('8 Aug')).dy;

    expect(
      newest,
      lessThan(older),
      reason: 'the thing just made is the thing most likely wanted',
    );
  });

  testWidgets('a heading never appears above an empty section', (
    tester,
  ) async {
    // An educator who has never built a quiz should not see a "Quizzes" label
    // with nothing under it.
    await pumpAssign(tester, profileId: 'educator-2');

    expect(find.text('Quizzes'), findsNothing);
    expect(find.text('Saved assessments'), findsOneWidget);
    expect(find.text('Colours Check'), findsOneWidget);
  });
}
