import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/xp_level_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/leaderboard.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/level_up_celebration_screen.dart';

import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_summary_screen.dart';
import 'package:pwdpwdpwd/features/guided_practice/screens/guided_practice_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/lesson_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/lesson_trail_screen.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/screens/online_race_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/membership_removed_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/student_profile_detail_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/leaderboard_config_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_timeline_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/weekly_report_screen.dart';
import 'package:pwdpwdpwd/features/showcase/models/showcase_models.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/post_join_setup_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_detail_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_quiz_screen.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/multiplayer/screens/local_race_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/role_setup_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_time_limits_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The rest of the uncovered screens: the ones that take constructor arguments.
///
/// Each needs a hand-built value, which is the only reason they sit apart from
/// `uncovered_screens_test.dart`. They are otherwise checked identically — the
/// same layout matrix and the same readability guard.
///
/// `PostJoinSetupScreen` is here too: its `JoinContext` wraps a `Classroom`,
/// which is a plain value object and perfectly buildable — the earlier note
/// that it needed a "live" record was wrong.
class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => _profile;
}

final _profile = UserProfile(
  id: 'args-profile',
  name: 'Test User',
  role: UserRole.student,
  disabilityType: DisabilityType.visual,
  createdAt: DateTime(2026),
);

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/uncovered_screens_args');
    for (final name in const <String>[
      'active_time_logs', 'alerts', 'child_alarms', 'child_time_limits',
      'classroom_members', 'classrooms', 'custom_cards', 'error_logs',
      'friend_directory_cache', 'friend_requests_cache', 'friends_cache',
      'goals', 'home_group_members', 'home_groups', 'leaderboard_config',
      'mood_entries', 'notebook', 'profiles', 'progress', 'sessions',
      'settings', 'sync_queue',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  const devices = <DeviceSize>[
    DeviceSize('7" portrait', Size(600, 960)),
    DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0),
  ];

  final result = AssessmentResult(
    id: 'r1',
    assessmentId: 'a1',
    profileId: _profile.id,
    type: AssessmentType.preTest,
    score: 7,
    totalQuestions: 10,
    answers: const [],
    completedAt: DateTime(2026, 9, 2),
    durationSeconds: 240,
  );

  final showcaseItem = ShowcaseItem(
    id: 's1',
    type: ShowcaseItemType.achievement,
    title: 'First Ten Words',
    description: 'Learned ten new words in a single week.',
    earnedAt: DateTime(2026, 9, 2),
  );

  final room = GameRoom(
    id: 'room-1',
    hostProfileId: _profile.id,
    hostName: 'Test User',
    hostUid: 'uid-1',
    hostAvatarIndex: 0,
    invitedProfileId: 'other-profile',
    mode: MpGameMode.quizRace,
    status: GameRoomStatus.waiting,
    rounds: 5,
    createdAt: DateTime(2026, 9, 2),
    updatedAt: DateTime(2026, 9, 2),
    ownerUid: 'uid-1',
  );

  final classroom = Classroom(
    id: 'class-1',
    code: 'ABC123',
    name: 'Grade 2 - Sampaguita',
    teacherId: 'teacher-1',
    createdAt: DateTime(2026, 9, 2),
    updatedAt: DateTime(2026, 9, 2),
  );

  final assessment = Assessment(
    id: 'a1',
    title: 'Pre-test',
    type: AssessmentType.preTest,
    // A real question, so the screen lays out its normal state rather than an
    // edge case. (The zero-question path is guarded in the screen itself.)
    questions: const [
      AssessmentQuestion(
        id: 'q1',
        questionText: 'What is “Aso” in English?',
        correctAnswer: 'Dog',
        choices: ['Dog', 'Cat', 'Bird', 'Fish'],
      ),
    ],
    createdBy: 'teacher-1',
    createdAt: DateTime(2026, 9, 2),
  );

  final screens = <String, Widget Function()>{
    'AssessmentTestScreen': () => AssessmentTestScreen(assessment: assessment),
    'ChildTimeLimitsScreen': () =>
        const ChildTimeLimitsScreen(childProfileId: 'child-1'),
    'EducatorDashboardScreen': () =>
        const EducatorDashboardScreen(audience: EducatorAudience.teacher),
    'LocalRaceScreen': () => const LocalRaceScreen(mode: MpGameMode.quizRace),
    'RoleSetupScreen': () => const RoleSetupScreen(role: UserRole.teacher),
    'PostJoinSetupScreen': () =>
        PostJoinSetupScreen(joinContext: ClassJoinContext(classroom)),
    // A real seeded story, so the quiz has genuine questions to lay out.
    'StoryQuizScreen': () => const StoryQuizScreen(storyId: 's_a01'),
    'AssessmentSummaryScreen': () => AssessmentSummaryScreen(result: result),
    'ChildAlarmsScreen': () =>
        const ChildAlarmsScreen(childProfileId: 'child-1'),
    'GuidedPracticeScreen': () =>
        const GuidedPracticeScreen(category: FlashcardCategory.animals),
    'LeaderboardConfigScreen': () =>
        const LeaderboardConfigScreen(scope: LeaderboardScope.none()),
    'LessonScreen': () => const LessonScreen(pathId: 'path-1'),
    'LessonTrailScreen': () => const LessonTrailScreen(pathId: 'path-1'),
    'LevelUpCelebrationScreen': () => LevelUpCelebrationScreen(
          newLevel: const PlayerLevel(
            level: 3,
            title: 'Learner',
            emoji: '🌟',
            xpRequired: 300,
          ),
          onDismiss: () {},
          // Its own auto-dismiss timer is 5 s by default, which outlives the
          // test and trips the pending-timer check.
          duration: const Duration(milliseconds: 200),
        ),
    'MembershipRemovedScreen': () =>
        const MembershipRemovedScreen(fromKind: 'classroom'),
    'OnlineRaceScreen': () => OnlineRaceScreen(room: room, asHost: true),
    'ProgressTimelineScreen': () => const ProgressTimelineScreen(
          profileId: 'args-profile',
          profileName: 'Test User',
        ),
    'ReportPreviewScreen': () => ReportPreviewScreen(
          pdfBytes: Uint8List(0),
          title: 'Weekly Report',
          filename: 'weekly-report.pdf',
          shareSubject: 'Weekly progress report',
        ),
    'ShowcaseDetailScreen': () => ShowcaseDetailScreen(item: showcaseItem),
    'StudentProfileDetailScreen': () =>
        StudentProfileDetailScreen(profile: _profile),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} lays out and reads correctly', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        entry.value,
        devices: devices,
        overrides: [profileProvider.overrideWith(_StubProfile.new)],
      );
    });
  }

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // The pass above renders under Flutter's default theme, which is not a theme
  // any learner ever sees. The dyslexia theme adds a 1.6 line height and 0.6
  // letter spacing on top of its own font sizes, so every line is wider *and*
  // taller than what was measured there; high contrast overrides the text
  // theme and outlines every card. Narrow portrait at 1.5x/2.0x only: a theme
  // cannot change glyph widths in a widget test, only the metrics, so it fails
  // first where the column is narrowest and the type largest.
  for (final theme in kLayoutThemes.entries) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} survives the ${theme.key} theme',
          (tester) async {
        await expectScreenNoOverflowAcrossDevices(
          tester,
          entry.value,
          theme: theme.value(),
          devices: kNarrowPortrait,
          textScales: kLargeTextScales,
          overrides: [profileProvider.overrideWith(_StubProfile.new)],
        );
      });
    }
  }
}
