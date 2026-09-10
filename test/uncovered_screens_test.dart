import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/features/accessibility/screens/voice_guided_mode_screen.dart';
import 'package:pwdpwdpwd/features/ai_tutor/screens/ai_tutor_screen.dart';
import 'package:pwdpwdpwd/features/account/screens/backup_account_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_assign_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assignment_tracking_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/quiz_builder_screen.dart';
import 'package:pwdpwdpwd/features/fsl_interpreter/screens/sign_it_screen.dart';
import 'package:pwdpwdpwd/features/gamification/screens/gamification_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/messaging/screens/messaging_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/profile_selection_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/time_up_lock_screen.dart';
import 'package:pwdpwdpwd/features/shop/screens/shop_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_builder_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_results_screen.dart';
import 'package:pwdpwdpwd/features/awareness/screens/pwd_awareness_screen.dart';
import 'package:pwdpwdpwd/features/classroom/screens/classroom_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/classroom/screens/join_class_screen.dart';
import 'package:pwdpwdpwd/features/daily_challenge/screens/daily_challenge_screen.dart';
import 'package:pwdpwdpwd/features/experiment/screens/experiment_setup_screen.dart';
import 'package:pwdpwdpwd/features/focus_mode/screens/focus_mode_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_practice_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_sign_to_word_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/fsl_word_to_sign_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/multiplayer_quiz_screen.dart';
import 'package:pwdpwdpwd/features/home_group/screens/join_home_group_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/learning_path_list_screen.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/learning_world_screen.dart';
import 'package:pwdpwdpwd/features/live_session/screens/live_session_screen.dart';
import 'package:pwdpwdpwd/features/multiplayer/screens/multiplayer_lobby_screen.dart';
import 'package:pwdpwdpwd/features/notifications/screens/alert_settings_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/accessibility_setup_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/splash_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/onboarding_tutorial_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/profile_switcher_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/student_profile_list_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/welcome_intro_screen.dart';
import 'package:pwdpwdpwd/features/parent_teacher_notes/screens/parent_teacher_notes_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/leaderboard_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/worksheet_screen.dart';
import 'package:pwdpwdpwd/features/recommendations/screens/recommendations_screen.dart';
import 'package:pwdpwdpwd/features/recovery/screens/recover_profile_screen.dart';
import 'package:pwdpwdpwd/features/recovery/screens/show_recovery_code_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/export_report_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/research_export_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/backup_restore_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/dashboard_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/edit_profile_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/multi_student_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/profile_import_export_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/learning_gain_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_screen.dart';
import 'package:pwdpwdpwd/features/showcase/screens/showcase_share_screen.dart';
import 'package:pwdpwdpwd/features/survey/screens/smileyometer_screen.dart';
import 'package:pwdpwdpwd/features/survey/screens/survey_results_screen.dart';
import 'package:pwdpwdpwd/features/survey/screens/sus_survey_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/student_comparison_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/teacher_analytics_screen.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/features/word_of_day/screens/word_of_day_screen.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// Layout + readability matrix for the screens **no other suite mounts**.
///
/// The overflow suites cover 57 screens; the app has 138 screen classes. These
/// are the rest of the no-argument ones — settings and account flows, the survey
/// and showcase screens, the multiplayer and cast screens, the learning-path
/// screens. They had never been rendered in a test at any size, so this is
/// their first layout coverage as well as their first readability coverage.
///
/// `BackupAccountScreen` is here now rather than excluded. It used to throw
/// `[core/no-app]` on mount, which looked like "needs Firebase" and was really
/// a missing guard: `FirebaseService.hasLinkedAccount` reached for
/// `FirebaseAuth.instance` without checking `isConfigured`, the way its
/// neighbour `currentUid` does. Guarding it fixed a real crash — a failed
/// Firebase init took the screen down instead of showing "not linked" — and
/// made the screen testable as a side effect.
///
/// Screens that take constructor arguments live in
/// `uncovered_screens_args_test.dart`.
class _StubProfile extends ProfileNotifier {
  _StubProfile(this.role);

  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
        id: 'uncovered-profile',
        name: 'Test User',
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
      );
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/uncovered_screens');
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

  /// Two viewports rather than the full seven: these screens are new to testing,
  /// and the tablet the app ships on plus the narrowest phone it supports are
  /// what decide whether a long word fits.
  const devices = <DeviceSize>[
    DeviceSize('7" portrait', Size(600, 960)),
    DeviceSize('phone portrait', Size(360, 640), devicePixelRatio: 3.0),
  ];

  final screens = <String, Widget Function()>{
    'AccessibilitySetupScreen': () => const AccessibilitySetupScreen(),
    'BackupAccountScreen': () => const BackupAccountScreen(),
    'AssessmentAssignScreen': () => const AssessmentAssignScreen(),
    'AssignmentTrackingScreen': () => const AssignmentTrackingScreen(),
    'GamificationDashboardScreen': () => const GamificationDashboardScreen(),
    'MessagingScreen': () => const MessagingScreen(),
    'ProfileSelectionScreen': () => const ProfileSelectionScreen(),
    'QuizBuilderScreen': () => const QuizBuilderScreen(),
    'ShopScreen': () => const ShopScreen(),
    'SignItScreen': () => const SignItScreen(),
    'TimeUpLockScreen': () => const TimeUpLockScreen(),
    'SplashScreen': () => const SplashScreen(),
    'AiTutorScreen': () => const AiTutorScreen(),
    'AlertSettingsScreen': () => const AlertSettingsScreen(),
    'AssessmentBuilderScreen': () => const AssessmentBuilderScreen(),
    'AssessmentResultsScreen': () => const AssessmentResultsScreen(),
    'BackupRestoreScreen': () => const BackupRestoreScreen(),
    'ClassroomDashboardScreen': () => const ClassroomDashboardScreen(),
    'DailyChallengeScreen': () => const DailyChallengeScreen(),
    'DashboardScreen': () => const DashboardScreen(),
    'EditProfileScreen': () => const EditProfileScreen(),
    'ExperimentSetupScreen': () => const ExperimentSetupScreen(),
    'ExportReportScreen': () => const ExportReportScreen(),
    'FocusModeScreen': () => const FocusModeScreen(),
    'FslSignToWordScreen': () => const FslSignToWordScreen(),
    'FslWordToSignScreen': () => const FslWordToSignScreen(),
    'GamepadPracticeScreen': () => const GamepadPracticeScreen(),
    'GamepadSettingsScreen': () => const GamepadSettingsScreen(),
    'JoinClassScreen': () => const JoinClassScreen(),
    'JoinHomeGroupScreen': () => const JoinHomeGroupScreen(),
    'LeaderboardScreen': () => const LeaderboardScreen(),
    'LearningGainScreen': () => const LearningGainScreen(),
    'LearningPathListScreen': () => const LearningPathListScreen(),
    'LearningWorldScreen': () => const LearningWorldScreen(),
    'LiveSessionScreen': () => const LiveSessionScreen(),
    'MultiStudentDashboardScreen': () => const MultiStudentDashboardScreen(),
    'MultiplayerLobbyScreen': () => const MultiplayerLobbyScreen(),
    'MultiplayerQuizScreen': () => const MultiplayerQuizScreen(),
    'OnboardingTutorialScreen': () => const OnboardingTutorialScreen(),
    'ParentTeacherNotesScreen': () => const ParentTeacherNotesScreen(),
    'ProfileImportExportScreen': () => const ProfileImportExportScreen(),
    'ProfileSwitcherScreen': () => const ProfileSwitcherScreen(),
    'PwdAwarenessScreen': () => const PwdAwarenessScreen(),
    'RecommendationsScreen': () => const RecommendationsScreen(),
    'RecoverProfileScreen': () => const RecoverProfileScreen(),
    'ResearchExportScreen': () => const ResearchExportScreen(),
    'ShowRecoveryCodeScreen': () => const ShowRecoveryCodeScreen(),
    'ShowcaseScreen': () => const ShowcaseScreen(),
    'ShowcaseShareScreen': () => const ShowcaseShareScreen(),
    'SmileyometerScreen': () => const SmileyometerScreen(),
    'StudentComparisonScreen': () => const StudentComparisonScreen(),
    'StudentProfileListScreen': () => const StudentProfileListScreen(),
    'SurveyResultsScreen': () => const SurveyResultsScreen(),
    'SusSurveyScreen': () => const SusSurveyScreen(),
    'TeacherAnalyticsScreen': () => const TeacherAnalyticsScreen(),
    'TvCastScreen': () => const TvCastScreen(),
    'VoiceGuidedModeScreen': () => const VoiceGuidedModeScreen(),
    'WelcomeIntroScreen': () => const WelcomeIntroScreen(),
    'WordOfDayScreen': () => const WordOfDayScreen(),
    'WorksheetScreen': () => const WorksheetScreen(),
  };

  /// Screens whose own `Future.delayed` work outlasts the default settle.
  const slowToSettle = <String, Duration>{
    // Queues its next lesson card 1.8 s after answering.
    'AiTutorScreen': Duration(seconds: 3),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} lays out and reads correctly', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        entry.value,
        devices: devices,
        overrides: [
          profileProvider.overrideWith(() => _StubProfile(UserRole.student)),
        ],
        settle: slowToSettle[entry.key] ?? const Duration(seconds: 1),
      );
    });
  }

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // Everything above renders under Flutter's default theme, which is not a
  // theme any learner ever sees. The dyslexia theme sets a 1.6 line height and
  // 0.6 letter spacing on top of its own font sizes, so every line is wider
  // *and* taller than what the pass above measured — the combination a learner
  // gets by turning on the two settings this app exists to offer.
  //
  // Kept to the narrow portrait sizes at 1.5x/2.0x rather than the full matrix:
  // a theme cannot change glyph widths in a widget test, only the metrics, so
  // it fails first where the column is narrowest and the type largest. Running
  // the whole matrix again per theme would quadruple the file for coverage of
  // combinations that cannot fail independently.
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
          overrides: [
            profileProvider.overrideWith(() => _StubProfile(UserRole.student)),
          ],
          settle: slowToSettle[entry.key] ?? const Duration(seconds: 1),
        );
      });
    }
  }
}
