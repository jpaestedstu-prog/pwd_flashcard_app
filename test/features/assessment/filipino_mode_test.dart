import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/educator_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_assign_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_results_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_summary_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assignment_tracking_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/class_report_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/classroom/widgets/group_management_view.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/research_export_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';
import 'package:pwdpwdpwd/widgets/animated_gradient_background.dart';
import 'package:pwdpwdpwd/widgets/tutorial_overlay.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/features/daily_challenge/screens/daily_challenge_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/fsl_dictionary_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/smart_review_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/hard_words_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/learning_path_list_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/learning_world_screen.dart';
import 'package:pwdpwdpwd/features/object_scan/screens/word_hunt_collection_screen.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/streak_calendar_screen.dart';
import 'package:pwdpwdpwd/features/goals/screens/goals_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/certificate_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/learning_gain_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_share_screen.dart';
import 'package:pwdpwdpwd/features/notebook/screens/notebook_screen.dart';
import 'package:pwdpwdpwd/features/word_of_day/screens/word_of_day_screen.dart';
import 'package:pwdpwdpwd/features/gamification/screens/gamification_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/leaderboard_screen.dart';
import 'package:pwdpwdpwd/features/classroom/screens/join_class_screen.dart';
import 'package:pwdpwdpwd/features/home_group/screens/join_home_group_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/dashboard_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/multi_student_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/classroom/screens/classroom_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/student_profile_list_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/quiz_builder_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_builder_screen.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/board_template_builder_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_template_picker_screen.dart';
import 'package:pwdpwdpwd/features/awareness/screens/pwd_awareness_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/weekly_report_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/worksheet_screen.dart';
import 'package:pwdpwdpwd/features/notifications/screens/alert_settings_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/adaptive_analytics_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/detailed_analytics_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/student_comparison_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/teacher_analytics_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parental_controls_screen.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/backup_restore_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/profile_import_export_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_settings_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/edit_profile_screen.dart';

/// Every screen of the study, built in Filipino, must show no English.
///
/// The Assign screen, the learner's test, its summary and the analytics were
/// English whatever the language setting, and the class and home-group
/// screens built their sentences out of English nouns. The homes every
/// participant lands on, and the learner's Cards, Stories and Progress tabs,
/// were English tile by tile. This sweep builds each of those screens with
/// the Filipino locale and fails on:
///
///  * any English ARB value whose Filipino differs, shown exactly;
///  * any such English sentence of 25+ characters inside a longer label —
///    semantics labels join several strings;
///  * a few English fragments the ARB cannot catch because they carry
///    numbers ("Question 1 of", "Tap to start", " percent").
///
/// Technical terms the Filipino copy keeps on purpose ("Accessibility",
/// "Analytics", "Leaderboard") are identical in both files, so they never
/// count. Seeding is in `setUpAll`; no test here writes to storage.

const _teacher = 'tea-1';
const _learner = 'stu-1';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

late final Set<String> _englishOnly;
late final List<String> _longEnglish;
final Set<String> _vocabulary = {
  for (final card in SeedData.allFlashcards) card.wordEnglish,
};
const _fragments = [
  'Question 1 of',
  'Tap to start',
  ' percent',
  ' questions',
  'Not yet taken',
  'Best: ',
  'assigned to you',
];

Iterable<String> _onScreen(WidgetTester tester) sync* {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText();
    if (s != null) yield s;
  }
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    yield w.text.toPlainText();
  }
  for (final w in tester.widgetList<Semantics>(find.byType(Semantics))) {
    final label = w.properties.label;
    if (label != null) yield label;
  }
  for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    final message = w.message;
    if (message != null) yield message;
  }
  for (final w in tester.widgetList<TextField>(find.byType(TextField))) {
    final hint = w.decoration?.hintText;
    if (hint != null) yield hint;
    final label = w.decoration?.labelText;
    if (label != null) yield label;
  }
}

/// Names printed on a game controller's own buttons. The gamepad guide says
/// "Start" in Filipino too, because that is the word on the hardware.
const _buttonNames = {'Start', 'Select'};

void _expectNoEnglish(WidgetTester tester, String where) {
  final leaks = <String>{};
  for (final raw in _onScreen(tester)) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    if (_englishOnly.contains(s) &&
        !_vocabulary.contains(s) &&
        !_buttonNames.contains(s)) {
      leaks.add(s);
    }
    for (final f in _fragments) {
      if (s.contains(f)) leaks.add(s);
    }
    for (final e in _longEnglish) {
      if (s.contains(e)) leaks.add(s);
    }
  }
  expect(leaks, isEmpty, reason: '$where shows English in Filipino mode');
}

/// The language *setting* as well as the locale: several screens switch on
/// `settings.locale`, exactly as the app does when a person picks Filipino.
class _FilipinoSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

class _Profile extends ProfileNotifier {
  _Profile(this.profile);
  final UserProfile profile;
  @override
  UserProfile? build() => profile;
}

final _learnerProfile = UserProfile(
  id: _learner,
  name: 'Ana',
  role: UserRole.student,
  createdAt: DateTime(2026),
  disabilityType: DisabilityType.hearing,
  classroomId: 'class-1',
);
final _teacherProfile = UserProfile(
  id: _teacher,
  name: 'Guro',
  role: UserRole.teacher,
  createdAt: DateTime(2026),
);
final _roster = [
  (
    _learnerProfile,
    LearningProgress(profileId: _learner, lastActivityDate: DateTime(2026, 9)),
  ),
];

AssessmentResult _result(String id, String assessmentId, AssessmentType type,
        int score, DateTime at) =>
    AssessmentResult(
      id: id,
      assessmentId: assessmentId,
      profileId: _learner,
      type: type,
      score: score,
      totalQuestions: 4,
      answers: [
        for (var i = 0; i < 4; i++)
          QuestionAnswer(
            questionId: 'q$i',
            givenAnswer: i < score ? 'Aso' : 'False',
            isCorrect: i < score,
            responseTimeMs: 1500,
          ),
      ],
      completedAt: at,
      durationSeconds: 125,
      categoryScores: const {'Animals': 0.5},
    );

/// One of every format the instrument uses, as the generators word them.
final _mixed = Assessment(
  id: 'mixed',
  title: 'Pre-Test — All Categories',
  type: AssessmentType.preTest,
  questions: const [
    AssessmentQuestion(
      id: 'mc',
      questionText: 'What is the Filipino word for “Dog”?',
      correctAnswer: 'Aso',
      choices: ['Aso', 'Pusa', 'Ibon', 'Isda'],
      category: FlashcardCategory.animals,
    ),
    AssessmentQuestion(
      id: 'tf',
      questionText: 'True or False: “Dog” is “Pusa” in Filipino.',
      correctAnswer: 'False',
      choices: ['True', 'False'],
      format: QuestionFormat.trueFalse,
      category: FlashcardCategory.animals,
    ),
    AssessmentQuestion(
      id: 'fill',
      questionText: 'Type the Filipino word for “Cat”:',
      correctAnswer: 'Pusa',
      choices: [],
      format: QuestionFormat.fillInBlank,
      category: FlashcardCategory.animals,
    ),
  ],
  createdBy: _teacher,
  createdAt: DateTime(2026, 9),
);

void main() {
  setUpAll(() async {
    final en = _arb('lib/l10n/app_en.arb');
    final fil = _arb('lib/l10n/app_fil.arb');
    final english = <String>{};
    en.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      final filipino = fil[key];
      if (filipino is! String || filipino == value) return;
      if (value.contains('{')) return;
      if (!RegExp('[A-Za-z]{3}').hasMatch(value)) return;
      english.add(value.trim());
    });
    _englishOnly = english;
    _longEnglish = [for (final e in english) if (e.length >= 25) e];

    const cacheDir = './build/test_cache/filipino_mode';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(cacheDir);
    for (final name in const [
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
      'active_time_logs',
      'error_logs',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await SyncQueueStorage.init();
    await HiveService.cacheClassroom(
      Classroom(
        id: 'class-1',
        code: 'ABC123',
        name: 'Klase 3',
        teacherId: _teacher,
        accessibility: DisabilityType.hearing,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final pre = AssessmentService.createClassPreTest(educatorId: _teacher);
    final post = AssessmentService.createClassPostTest(pre);
    await AssessmentService.saveAssessment(_teacher, pre);
    await AssessmentService.saveAssessment(_teacher, post);
    await AssessmentService.saveAssignment(
      _teacher,
      AssessmentAssignment(
        id: 'as-post',
        assessmentId: post.id,
        assessmentTitle: post.title,
        assignedBy: _teacher,
        studentIds: const [_learner],
        assignedAt: DateTime(2026, 9, 20),
        deadline: DateTime(2026, 12),
      ),
    );
    await AssessmentService.saveResult(
      _learner,
      _result('r-pre', pre.id, AssessmentType.preTest, 1, DateTime(2026, 9, 2)),
    );
    await AssessmentService.saveResult(
      _learner,
      _result('r-old-post', 'old', AssessmentType.postTest, 3,
          DateTime(2026, 9, 12)),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required UserProfile as,
    Size physical = const Size(1200, 5200),
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/s',
      routes: [
        GoRoute(path: '/s', builder: (_, _) => screen),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, _) => const Scaffold(body: Text('ELSEWHERE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _Profile(as)),
          settingsProvider.overrideWith(_FilipinoSettings.new),
          educatorLearnerRosterProvider.overrideWithValue(_roster),
          hapticServiceProvider.overrideWithValue(
            HapticService(enabled: false),
          ),
          gamificationFeatureProvider(
            GamificationFeature.stars,
          ).overrideWithValue(false),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('fil'),
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  }

  // ─── The learner ────────────────────────────────────────

  testWidgets('the learner’s Assessment Center', (tester) async {
    await pump(tester, const AssessmentHubScreen(), as: _learnerProfile);
    _expectNoEnglish(tester, 'the learner hub');
  });

  testWidgets('a test, before and after answering', (tester) async {
    await pump(
      tester,
      AssessmentTestScreen(
        assessment: _mixed,
        clock: () => DateTime(2026, 9, 10, 9),
        prepareSignClips: (_) async => const [],
      ),
      as: _learnerProfile,
    );
    _expectNoEnglish(tester, 'a question');

    await tester.tap(find.text('Pusa'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    _expectNoEnglish(tester, 'the feedback after answering');
  });

  testWidgets('a True / False item reads Tama / Mali', (tester) async {
    await pump(
      tester,
      AssessmentTestScreen(
        assessment: Assessment(
          id: 'tf-only',
          title: 'x',
          type: AssessmentType.preTest,
          questions: [_mixed.questions[1]],
          createdBy: _teacher,
          createdAt: DateTime(2026, 9),
        ),
        clock: () => DateTime(2026, 9, 10, 9),
      ),
      as: _learnerProfile,
    );
    expect(find.text('Tama'), findsOneWidget);
    expect(find.text('Mali'), findsOneWidget);
    _expectNoEnglish(tester, 'a True / False item');
  });

  testWidgets('a test whose sign videos are missing', (tester) async {
    final withSign = Assessment(
      id: 'sign',
      title: 'x',
      type: AssessmentType.preTest,
      questions: [
        AssessmentService.buildSignQuestion(
          const Flashcard(
            id: 'c1',
            wordEnglish: 'Dog',
            wordFilipino: 'Aso',
            category: FlashcardCategory.animals,
          ),
          const [
            Flashcard(
              id: 'c1',
              wordEnglish: 'Dog',
              wordFilipino: 'Aso',
              category: FlashcardCategory.animals,
            ),
            Flashcard(
              id: 'c2',
              wordEnglish: 'Cat',
              wordFilipino: 'Pusa',
              category: FlashcardCategory.animals,
            ),
          ],
          Random(1),
        ),
      ],
      createdBy: _teacher,
      createdAt: DateTime(2026, 9),
    );
    await pump(
      tester,
      AssessmentTestScreen(
        assessment: withSign,
        clock: () => DateTime(2026, 9, 10, 9),
        prepareSignClips: (ids) async => ids,
      ),
      as: _learnerProfile,
    );
    _expectNoEnglish(tester, 'the missing-video screen');
  });

  testWidgets('the summary after a test', (tester) async {
    await pump(
      tester,
      AssessmentSummaryScreen(
        result: _result('s', 'mixed', AssessmentType.preTest, 2,
            DateTime(2026, 9, 21)),
      ),
      as: _learnerProfile,
    );
    _expectNoEnglish(tester, 'the summary');
  });

  testWidgets('the learner’s analytics', (tester) async {
    await pump(tester, const AssessmentResultsScreen(), as: _learnerProfile);
    _expectNoEnglish(tester, 'the analytics');
  });

  // ─── The teacher ────────────────────────────────────────

  testWidgets('the learner home', (tester) async {
    await pump(tester, const HomeScreen(), as: _learnerProfile);
    _expectNoEnglish(tester, 'the learner home');
    // A new learner meets the tour before anything else. Its steps are
    // content rather than ARB strings, so the sweep cannot see them: check
    // the Filipino tour is the one on screen.
    expect(find.text(homeTutorialStepsFilipino.first.title), findsOneWidget);
    expect(find.text(homeTutorialSteps.first.title), findsNothing);
  });

  // Every other screen a learner can open from Home or a tab, and the
  // monitoring screens a teacher opens during the study. English *words*
  // are the vocabulary being taught, so a string that is exactly a flashcard
  // word ("Friend", "Close") is content, not a leak.
  group('beyond the study screens', () {
    for (final (name, screen) in <(String, Widget)>[
      ('DailyChallengeScreen', const DailyChallengeScreen()),
      ('FslDictionaryScreen', const FslDictionaryScreen()),
      ('SmartReviewScreen', const SmartReviewScreen()),
      ('HardWordsScreen', const HardWordsScreen()),
      ('LearningPathListScreen', const LearningPathListScreen()),
      ('LearningWorldScreen', const LearningWorldScreen()),
      ('WordHuntCollectionScreen', const WordHuntCollectionScreen()),
      ('CommunicationBoardScreen', const CommunicationBoardScreen()),
      ('StreakCalendarScreen', const StreakCalendarScreen()),
      ('GoalsScreen', const GoalsScreen()),
      ('CertificateScreen', const CertificateScreen()),
      ('LearningGainScreen', const LearningGainScreen()),
      ('ShowcaseScreen', const ShowcaseScreen()),
      ('ShowcaseShareScreen', const ShowcaseShareScreen()),
      ('NotebookScreen', const NotebookScreen()),
      ('WordOfDayScreen', const WordOfDayScreen()),
      ('GamificationDashboardScreen', const GamificationDashboardScreen()),
      ('LeaderboardScreen', const LeaderboardScreen()),
      ('JoinClassScreen', const JoinClassScreen()),
      ('JoinHomeGroupScreen', const JoinHomeGroupScreen()),
      ('SettingsScreen', const SettingsScreen()),
    ]) {
      testWidgets(name, (tester) async {
        await pump(tester, screen, as: _learnerProfile);
        _expectNoEnglish(tester, name);
      });
    }
    for (final (name, screen) in <(String, Widget)>[
      ('DashboardScreen', const DashboardScreen()),
      ('MultiStudentDashboardScreen', const MultiStudentDashboardScreen()),
      ('ClassroomDashboardScreen', const ClassroomDashboardScreen()),
      ('StudentProfileListScreen', const StudentProfileListScreen()),
    ]) {
      testWidgets('$name (teacher)', (tester) async {
        await pump(tester, screen, as: _teacherProfile);
        _expectNoEnglish(tester, name);
      });
    }
  });

  // The adults' tools — builders, reports, casting, device settings. The
  // study's teacher and parents run these in Filipino too.
  group('adult tools', () {
    for (final (name, screen) in <(String, Widget)>[
      ('QuizBuilderScreen', const QuizBuilderScreen()),
      ('AssessmentBuilderScreen', const AssessmentBuilderScreen()),
      ('BoardTemplateBuilderScreen', const BoardTemplateBuilderScreen()),
      ('DeckTemplatePickerScreen', const DeckTemplatePickerScreen()),
      ('PwdAwarenessScreen', const PwdAwarenessScreen()),
      ('WeeklyReportScreen', const WeeklyReportScreen()),
      ('WorksheetScreen', const WorksheetScreen()),
      ('AlertSettingsScreen', const AlertSettingsScreen()),
      ('AdaptiveAnalyticsScreen', const AdaptiveAnalyticsScreen()),
      ('DetailedAnalyticsScreen', const DetailedAnalyticsScreen()),
      ('StudentComparisonScreen', const StudentComparisonScreen()),
      ('TeacherAnalyticsScreen', const TeacherAnalyticsScreen()),
      ('ParentalControlsScreen', const ParentalControlsScreen()),
      ('TvCastScreen', const TvCastScreen()),
      ('BackupRestoreScreen', const BackupRestoreScreen()),
      ('ProfileImportExportScreen', const ProfileImportExportScreen()),
      ('GazeSettingsScreen', const GazeSettingsScreen()),
      ('GamepadSettingsScreen', const GamepadSettingsScreen()),
      ('EditProfileScreen', const EditProfileScreen()),
    ]) {
      testWidgets('$name (teacher)', (tester) async {
        await pump(tester, screen, as: _teacherProfile);
        _expectNoEnglish(tester, name);
      });
    }
  });

  // The learner's other tabs — where the study's learning time is spent.
  for (final (name, screen) in <(String, Widget)>[
    ('the Games tab', const GameHubScreen()),
    ('the Cards tab', const DeckListScreen()),
    (
      'a deck of cards',
      const FlashcardViewerScreen(category: FlashcardCategory.animals),
    ),
    ('the Stories tab', const StoryListScreen()),
    ('the Progress tab', const ProgressScreen()),
  ]) {
    testWidgets(name, (tester) async {
      await pump(tester, screen, as: _learnerProfile);
      _expectNoEnglish(tester, name);
    });
  }

  testWidgets('the child home', (tester) async {
    await pump(
      tester,
      const ChildHomeScreen(),
      as: UserProfile(
        id: 'kid-1',
        name: 'Bunso',
        role: UserRole.child,
        createdAt: DateTime(2026),
        homeGroupId: 'home-1',
      ),
    );
    _expectNoEnglish(tester, 'the child home');
  });

  testWidgets('the guest player home', (tester) async {
    await pump(
      tester,
      const PlayerHomeScreen(),
      as: UserProfile(
        id: 'guest-1',
        name: 'Laro',
        role: UserRole.player,
        createdAt: DateTime(2026),
        isGuestPlayer: true,
      ),
    );
    _expectNoEnglish(tester, 'the guest player home');
  });

  for (final parent in [false, true]) {
    testWidgets(parent ? 'the parent home' : 'the teacher home', (
      tester,
    ) async {
      await pump(
        tester,
        const EducatorHomeScreen(),
        as: parent
            ? UserProfile(
                id: 'par-1',
                name: 'Magulang',
                role: UserRole.parent,
                createdAt: DateTime(2026),
              )
            : _teacherProfile,
      );
      _expectNoEnglish(tester, parent ? 'the parent home' : 'the teacher home');
    });
  }

  testWidgets('the teacher’s Assessment Center', (tester) async {
    await pump(tester, const AssessmentHubScreen(), as: _teacherProfile);
    _expectNoEnglish(tester, 'the teacher hub');
  });

  testWidgets('assigning', (tester) async {
    await pump(tester, const AssessmentAssignScreen(), as: _teacherProfile);
    _expectNoEnglish(tester, 'the Assign screen');
  });

  testWidgets('tracking', (tester) async {
    await pump(tester, const AssignmentTrackingScreen(), as: _teacherProfile);
    _expectNoEnglish(tester, 'assignment tracking');
  });

  testWidgets('the Class Report', (tester) async {
    await pump(tester, const ClassReportScreen(), as: _teacherProfile);
    _expectNoEnglish(tester, 'the Class Report');
  });

  testWidgets('the research export', (tester) async {
    await pump(tester, const ResearchExportScreen(), as: _teacherProfile);
    _expectNoEnglish(tester, 'the research export');
  });

  // ─── Longer words, largest font, smallest phone ─────────
  //
  // Filipino runs longer than English — "Panimulang Pagsusulit" against
  // "Pre-Test" — and the layout tests only ever measured English. At 2.0x on
  // a 360×640 phone any fixed-width row shows first.
  group('in Filipino at 2.0x on a small phone', () {
    Future<void> small(WidgetTester tester, Widget screen, UserProfile as) =>
        pump(
          tester,
          screen,
          as: as,
          physical: const Size(360, 640) * 2,
          dpr: 2,
          textScale: 2.0,
        );

    testWidgets('the learner hub', (tester) async {
      await small(tester, const AssessmentHubScreen(), _learnerProfile);
      expect(tester.takeException(), isNull);
    });
    // The Filipino tile names run longer than the English ones they replaced.
    for (final (name, screen, who) in <(String, Widget, UserProfile)>[
      ('the learner home', const HomeScreen(), _learnerProfile),
      (
        'the child home',
        const ChildHomeScreen(),
        UserProfile(
          id: 'kid-1',
          name: 'Bunso',
          role: UserRole.child,
          createdAt: DateTime(2026),
        ),
      ),
      (
        'the guest player home',
        const PlayerHomeScreen(),
        UserProfile(
          id: 'guest-1',
          name: 'Laro',
          role: UserRole.player,
          createdAt: DateTime(2026),
          isGuestPlayer: true,
        ),
      ),
      ('the teacher home', const EducatorHomeScreen(), _teacherProfile),
      ('the Cards tab', const DeckListScreen(), _learnerProfile),
      (
        'a deck of cards',
        const FlashcardViewerScreen(category: FlashcardCategory.animals),
        _learnerProfile,
      ),
      ('the Stories tab', const StoryListScreen(), _learnerProfile),
      ('the Progress tab', const ProgressScreen(), _learnerProfile),
    ]) {
      testWidgets(name, (tester) async {
        await small(tester, screen, who);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('a test', (tester) async {
      await small(
        tester,
        AssessmentTestScreen(
          assessment: _mixed,
          clock: () => DateTime(2026, 9, 10, 9),
          prepareSignClips: (_) async => const [],
        ),
        _learnerProfile,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('the summary', (tester) async {
      await small(
        tester,
        AssessmentSummaryScreen(
          result: _result('s', 'mixed', AssessmentType.preTest, 2,
              DateTime(2026, 9, 21)),
        ),
        _learnerProfile,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('the analytics', (tester) async {
      await small(tester, const AssessmentResultsScreen(), _learnerProfile);
      expect(tester.takeException(), isNull);
    });
    testWidgets('the teacher hub', (tester) async {
      await small(tester, const AssessmentHubScreen(), _teacherProfile);
      expect(tester.takeException(), isNull);
    });
    testWidgets('assigning', (tester) async {
      await small(tester, const AssessmentAssignScreen(), _teacherProfile);
      expect(tester.takeException(), isNull);
    });
    testWidgets('tracking', (tester) async {
      await small(tester, const AssignmentTrackingScreen(), _teacherProfile);
      expect(tester.takeException(), isNull);
    });
    testWidgets('the research export', (tester) async {
      await small(tester, const ResearchExportScreen(), _teacherProfile);
      expect(tester.takeException(), isNull);
    });
    testWidgets('class management', (tester) async {
      await small(
        tester,
        const GroupManagementView(delegate: _Delegate(parent: false)),
        _teacherProfile,
      );
      expect(tester.takeException(), isNull);
    });
  });

  for (final parent in [false, true]) {
    testWidgets(
      parent ? 'managing home groups' : 'managing classes',
      (tester) async {
        await pump(
          tester,
          GroupManagementView(delegate: _Delegate(parent: parent)),
          as: parent
              ? UserProfile(
                  id: 'par-1',
                  name: 'Magulang',
                  role: UserRole.parent,
                  createdAt: DateTime(2026),
                )
              : _teacherProfile,
        );
        _expectNoEnglish(
          tester,
          parent ? 'home group management' : 'class management',
        );
      },
    );
  }
}

class _Delegate extends GroupManagementDelegate {
  const _Delegate({required this.parent});
  final bool parent;

  @override
  String get audience => parent ? 'parent' : 'teacher';
  @override
  String get screenTitle => parent ? 'Home Groups' : 'Manage Classes';
  @override
  String get groupNoun => parent ? 'home group' : 'class';
  @override
  String get groupNounPlural => parent ? 'home groups' : 'classes';
  @override
  String get memberNoun => parent ? 'child' : 'student';
  @override
  String get memberNounPlural => parent ? 'children' : 'students';
  @override
  IconData get groupIcon => Icons.school_rounded;
  @override
  IconData get memberIcon => Icons.people_rounded;
  @override
  String get createHint => '';
  @override
  String get leaderboardKind => parent ? 'homeGroup' : 'classroom';
  @override
  GradientPreset get gradientPreset => GradientPreset.assessment;
  @override
  Color get accent => AppColors.sectionLearning;
  @override
  String get emptyEmoji => '🏫';
  @override
  String get shareBlurb => '';
  @override
  AsyncValue<List<ManagedGroup>> watchGroups(WidgetRef ref) =>
      const AsyncValue.data([
        ManagedGroup(
          id: 'g1',
          code: 'ABC123',
          name: 'Klase 3',
          accessibility: DisabilityType.hearing,
          source: Object(),
        ),
      ]);
  @override
  AsyncValue<List<ManagedMember>> watchMembers(WidgetRef ref, String id) =>
      AsyncValue.data([
        ManagedMember(
          profileId: 'p1',
          displayName: 'Ana',
          joinedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
  @override
  Future<void> refresh(WidgetRef ref) async {}
  @override
  Future<void> createGroup(WidgetRef r, String n, DisabilityType a) async {}
  @override
  Future<void> renameGroup(WidgetRef r, ManagedGroup g, String n) async {}
  @override
  Future<void> setAccessibility(
    WidgetRef r,
    ManagedGroup g,
    DisabilityType a,
  ) async {}
  @override
  Future<void> setAllowRetakes(WidgetRef r, ManagedGroup g, bool a) async {}
  @override
  Future<void> regenerateCode(WidgetRef r, ManagedGroup g) async {}
  @override
  Future<void> deleteGroup(WidgetRef r, ManagedGroup g) async {}
  @override
  Future<void> renameMember(
    WidgetRef r,
    ManagedGroup g,
    String p,
    String d,
  ) async {}
  @override
  Future<void> removeMember(WidgetRef r, ManagedGroup g, String p) async {}
  @override
  Future<void> removeMembers(
    WidgetRef r,
    ManagedGroup g,
    List<String> p,
  ) async {}
}
