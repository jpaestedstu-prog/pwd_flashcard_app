import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../providers/app_providers.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/profile_selection_screen.dart';
import '../features/onboarding/screens/profile_switcher_screen.dart';
import '../features/onboarding/screens/accessibility_setup_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/screens/educator_home_screen.dart';
import '../features/flashcards/screens/deck_list_screen.dart';
import '../features/flashcards/screens/flashcard_viewer_screen.dart';
import '../features/flashcards/screens/create_flashcard_screen.dart';
import '../features/games/screens/game_hub_screen.dart';
import '../features/games/screens/word_match_screen.dart';
import '../features/games/screens/spelling_bee_screen.dart';
import '../features/games/screens/memory_match_screen.dart';
import '../features/games/screens/drag_drop_screen.dart';
import '../features/games/screens/flashcard_quiz_screen.dart';
import '../features/games/screens/pronunciation_screen.dart';
import '../features/games/screens/sentence_builder_screen.dart';
import '../features/games/screens/tracing_screen.dart';
import '../features/games/screens/fsl_practice_hub_screen.dart';
import '../features/games/screens/fsl_sign_to_word_screen.dart';
import '../features/games/screens/fsl_word_to_sign_screen.dart';
import '../features/games/screens/jigsaw_puzzle_screen.dart';
import '../features/games/screens/picture_word_screen.dart';
import '../features/progress/screens/progress_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/dashboard_screen.dart';
import '../features/settings/screens/multi_student_dashboard_screen.dart';
import '../features/flashcards/screens/smart_review_screen.dart';
import '../features/shop/screens/shop_screen.dart';
import '../features/stories/screens/story_list_screen.dart';
import '../features/stories/screens/story_reader_screen.dart';
import '../features/stories/screens/story_quiz_screen.dart';
import '../features/settings/screens/backup_restore_screen.dart';
import '../features/classroom/screens/classroom_dashboard_screen.dart';
import '../features/classroom/screens/classroom_management_screen.dart';
import '../features/classroom/screens/join_class_screen.dart';
import '../features/live_session/screens/live_session_screen.dart';
import '../features/progress/screens/leaderboard_screen.dart';
import '../features/learning_paths/screens/learning_path_list_screen.dart';
import '../features/learning_paths/screens/lesson_screen.dart';
import '../features/progress/screens/detailed_analytics_screen.dart';
import '../features/flashcards/screens/fsl_dictionary_screen.dart';
import '../features/communication_board/screens/communication_board_screen.dart';
import '../features/communication_board/screens/board_template_builder_screen.dart';
import '../features/daily_challenge/screens/daily_challenge_screen.dart';
import '../features/parent/screens/parent_dashboard_screen.dart';
import '../features/reports/screens/weekly_report_screen.dart';
import '../features/progress/screens/adaptive_analytics_screen.dart';
import '../features/games/screens/multiplayer_quiz_screen.dart';
import '../features/accessibility/screens/voice_guided_mode_screen.dart';
import '../features/flashcards/screens/enhanced_create_flashcard_screen.dart';
import '../features/settings/screens/edit_profile_screen.dart';
import '../features/parent/screens/parental_controls_screen.dart';
import '../features/assessment/screens/assessment_hub_screen.dart';
import '../features/assessment/screens/assessment_test_screen.dart';
import '../features/assessment/screens/assessment_summary_screen.dart';
import '../features/assessment/screens/assessment_results_screen.dart';
import '../features/assessment/screens/assessment_builder_screen.dart';
import '../features/assessment/screens/assessment_assign_screen.dart';
import '../features/assessment/screens/assignment_tracking_screen.dart';
import '../features/assessment/models/assessment_models.dart';
import '../features/showcase/screens/showcase_screen.dart';
import '../features/showcase/screens/showcase_detail_screen.dart';
import '../features/showcase/screens/showcase_share_screen.dart';
import '../features/showcase/screens/learning_gain_screen.dart';
import '../features/showcase/models/showcase_models.dart';
import '../features/recommendations/screens/recommendations_screen.dart';
import '../features/mood_tracker/screens/mood_check_in_screen.dart';
import '../features/mood_tracker/screens/mood_history_screen.dart';
import '../features/mood_tracker/screens/mood_insights_screen.dart';
import '../features/stickers/screens/sticker_album_screen.dart';
import '../features/teacher_analytics/screens/teacher_analytics_screen.dart';
import '../features/guided_practice/screens/guided_practice_screen.dart';
import '../features/ai_tutor/screens/ai_tutor_screen.dart';
import '../features/messaging/screens/messaging_screen.dart';
import '../features/peer_collaboration/screens/peer_collaboration_screen.dart';
import '../features/progress/screens/worksheet_screen.dart';
import '../features/notebook/screens/notebook_screen.dart';
import '../features/notebook/screens/note_editor_screen.dart';
import '../features/notebook/models/notebook_models.dart';
import '../features/goals/screens/goals_screen.dart';
import '../features/progress/screens/streak_calendar_screen.dart';
import '../features/progress/screens/certificate_screen.dart';
import '../features/flashcards/screens/hard_words_screen.dart';
import '../features/assessment/screens/quiz_builder_screen.dart';
import '../features/parent/services/parental_controls_service.dart';
import '../features/progress/screens/progress_timeline_screen.dart';
import '../features/teacher_analytics/screens/student_comparison_screen.dart';
import '../features/notifications/screens/alert_settings_screen.dart';
import '../features/reports/screens/research_export_screen.dart';
import '../features/onboarding/screens/student_profile_list_screen.dart';
import '../features/onboarding/screens/student_profile_detail_screen.dart';
import '../features/onboarding/screens/onboarding_tutorial_screen.dart';
import '../features/home/screens/player_home_screen.dart';
import '../features/home/screens/child_home_screen.dart';
import '../features/home_group/screens/join_home_group_screen.dart';
import '../features/home_group/screens/home_group_management_screen.dart';
import '../features/settings/screens/profile_import_export_screen.dart';
import '../features/survey/screens/sus_survey_screen.dart';
import '../features/survey/screens/survey_results_screen.dart';
import '../features/survey/screens/smileyometer_screen.dart';
import '../features/experiment/screens/experiment_setup_screen.dart';
import '../features/gamification/screens/gamification_dashboard_screen.dart';
import '../features/word_of_day/screens/word_of_day_screen.dart';
import '../features/focus_mode/screens/focus_mode_screen.dart';
import '../features/parent_teacher_notes/screens/parent_teacher_notes_screen.dart';
import '../core/services/engagement_tracker.dart';
import 'app_page_transitions.dart';
import 'bottom_nav_shell.dart';

/// Global navigator key so services (e.g. notifications) can navigate
/// without a BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Routes only educators (teacher/parent) may access.
const _educatorOnlyRoutes = [
  '/dashboard',
  '/multi-dashboard',
  '/teacher-analytics',
  '/classroom',
  '/classroom-manage',
  '/parent-dashboard',
  '/home-group-manage',
  '/weekly-reports',
  '/assessment/builder',
  '/assessment/assign',
  '/assessment/tracking',
  '/worksheets',
  '/adaptive-analytics',
  '/parental-controls',
  '/progress-timeline',
  '/student-comparison',
  '/alert-settings',
  '/research-export',
  '/experiment-setup',
  '/parent-teacher-notes',
];

/// Routes only learners (student / child) may access.
const _studentOnlyRoutes = [
  '/shop',
  '/sticker-album',
];

/// Routes the Player (guest) role cannot reach. Player profiles never
/// sync to Firestore, so anything that requires a remote roster, a
/// classroom membership, or another learner's data is off-limits.
const _playerBlockedRoutes = [
  '/dashboard',
  '/multi-dashboard',
  '/teacher-analytics',
  '/classroom',
  '/classroom-manage',
  '/parent-dashboard',
  '/home-group-manage',
  '/weekly-reports',
  '/leaderboard',
  '/messages',
  '/multiplayer-quiz',
  '/live-session',
  '/assessment',
  '/parent-teacher-notes',
  '/research-export',
  '/showcase/share',
];

/// Engagement tracker that acts as a NavigatorObserver.
/// Automatically tracks screen visits and durations for research export.
final engagementTrackerProvider = Provider<EngagementTracker?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null || profile.role != UserRole.student) return null;
  final tracker = EngagementTracker(profileId: profile.id);
  ref.onDispose(() => tracker.flush());
  return tracker;
});

final routerProvider = Provider<GoRouter>((ref) {
  final tracker = ref.read(engagementTrackerProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    observers: [
      ?tracker,
    ],
    redirect: (context, state) {
      final profile = ref.read(profileProvider);
      if (profile == null) return null; // not logged in yet

      final location = state.uri.toString();
      final role = profile.role;

      // When an educator is viewing as a student, allow educator-only routes
      final isViewingAsStudent =
          ref.read(profileProvider.notifier).isViewingAsStudent;

      // Player guard: hard block on anything that needs Firestore reads
      // beyond the player's own session.
      if (role == UserRole.player && !isViewingAsStudent) {
        for (final r in _playerBlockedRoutes) {
          if (location.startsWith(r)) return '/home';
        }
        return null;
      }

      // Child guard: must be enrolled in a home group before reaching
      // the home shell. Allow /splash, /profile, and the join screen
      // through so the child can complete onboarding.
      if (role == UserRole.child && !isViewingAsStudent) {
        if (profile.homeGroupId == null &&
            !location.startsWith('/join-home-group') &&
            !location.startsWith('/splash') &&
            !location.startsWith('/profile') &&
            !location.startsWith('/accessibility-setup') &&
            !location.startsWith('/onboarding-tutorial')) {
          return '/join-home-group';
        }
        for (final route in _educatorOnlyRoutes) {
          if (location.startsWith(route)) return '/home';
        }
        return null;
      }

      if (role == UserRole.student && !isViewingAsStudent) {
        // Block students from educator-only routes
        for (final route in _educatorOnlyRoutes) {
          if (location.startsWith(route)) return '/home';
        }

        // Enforce parental controls for students
        final controls = ParentalControlsService.getControls();
        if (controls.hasAnyRestriction) {
          // Schedule enforcement
          if (controls.scheduleEnabled && !controls.isWithinSchedule) {
            // Allow home but block other routes
            if (!location.startsWith('/home') &&
                !location.startsWith('/splash') &&
                !location.startsWith('/profile')) {
              return '/home';
            }
          }
          // Feature blocking
          if (controls.shopBlocked && location.startsWith('/shop')) {
            return '/home';
          }
          if (controls.multiplayerBlocked &&
              location.startsWith('/multiplayer-quiz')) {
            return '/home';
          }
          if (controls.messagingBlocked &&
              location.startsWith('/messages')) {
            return '/home';
          }
        }
      } else {
        // Block educators from student-only routes
        for (final route in _studentOnlyRoutes) {
          if (location.startsWith(route)) return '/home';
        }
      }
      return null;
    },
    errorBuilder: (context, state) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Friendly illustration circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: Text(
                        '🗺️',
                        style: TextStyle(fontSize: 48),
                        semanticsLabel: 'Lost page illustration',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Oops! Page not found',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'It looks like this page has wandered off.\nLet\'s get you back on track!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    label: 'Go back to home screen',
                    child: FilledButton.icon(
                      onPressed: () => GoRouter.of(context).go('/home'),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Go Home'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Go back to previous page',
                    child: TextButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          GoRouter.of(context).go('/home');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      // Profile Selection
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const ProfileSelectionScreen(),
        ),
      ),
      // Create Student Profile (educator shortcut — skips role selection)
      GoRoute(
        path: '/create-student',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const ProfileSelectionScreen(forceRole: UserRole.student),
        ),
      ),
      // Profile Switcher (multiple profiles on device)
      GoRoute(
        path: '/profile-switcher',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ProfileSwitcherScreen(),
        ),
      ),
      // Student Profile List (view all student profiles)
      GoRoute(
        path: '/student-profiles',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const StudentProfileListScreen(),
        ),
      ),
      // Student Profile Detail (full profile + progress)
      GoRoute(
        path: '/student-profile-detail',
        pageBuilder: (context, state) {
          final profile = state.extra as UserProfile;
          return AppPageTransitions.slideRight(
            key: state.pageKey,
            child: StudentProfileDetailScreen(profile: profile),
          );
        },
      ),
      // Accessibility Setup (after profile creation)
      GoRoute(
        path: '/accessibility-setup',
        pageBuilder: (context, state) {
          final studentProfile = state.extra as UserProfile?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: AccessibilitySetupScreen(studentProfile: studentProfile),
          );
        },
      ),
      // Onboarding Tutorial (first-time walkthrough)
      GoRoute(
        path: '/onboarding-tutorial',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const OnboardingTutorialScreen(),
        ),
      ),
      // Profile Import/Export
      GoRoute(
        path: '/profile-import-export',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ProfileImportExportScreen(),
        ),
      ),
      // Main Shell with Bottom Nav
      ShellRoute(
        builder: (context, state, child) =>
            BottomNavShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) {
              final profileNotifier = ref.read(profileProvider.notifier);
              final profile = ref.read(profileProvider);
              final role = profile?.role;
              final isViewingAsStudent = profileNotifier.isViewingAsStudent;
              // Safety net: if an educator was viewing a student and
              // reaches home without explicit restoration, restore now.
              if (isViewingAsStudent) {
                profileNotifier.restoreEducatorProfile();
              }
              // Educator-as-student preview overrides the role switch.
              if (isViewingAsStudent) {
                return AppPageTransitions.fade(
                  key: state.pageKey,
                  child: const EducatorHomeScreen(),
                );
              }
              final widget = switch (role) {
                UserRole.player => const PlayerHomeScreen(),
                UserRole.child => const ChildHomeScreen(),
                UserRole.teacher ||
                UserRole.parent =>
                  const EducatorHomeScreen(),
                // student or null falls through to the default learner home
                _ => const HomeScreen(),
              };
              return AppPageTransitions.fade(
                key: state.pageKey,
                child: widget,
              );
            },
          ),
          GoRoute(
            path: '/flashcards',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const DeckListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'viewer/:category',
                pageBuilder: (context, state) {
                  final catIndex = int.parse(state.pathParameters['category']!);
                  if (catIndex < 0 || catIndex >= FlashcardCategory.values.length) {
                    return AppPageTransitions.slideRight(
                      key: state.pageKey,
                      child: const DeckListScreen(),
                    );
                  }
                  return AppPageTransitions.slideRight(
                    key: state.pageKey,
                    child: FlashcardViewerScreen(
                      category: FlashcardCategory.values[catIndex],
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'create',
                pageBuilder: (context, state) {
                  final card = state.extra as Flashcard?;
                  return AppPageTransitions.slideUp(
                    key: state.pageKey,
                    child: CreateFlashcardScreen(editCard: card),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/games',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const GameHubScreen(),
            ),
            routes: [
              GoRoute(
                path: 'word-match',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: WordMatchScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'spelling-bee',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: SpellingBeeScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'memory-match',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: MemoryMatchScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'drag-drop',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: DragDropScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'flashcard-quiz',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: FlashcardQuizScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'pronunciation',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: PronunciationScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'sentence-builder',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: SentenceBuilderScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'tracing',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: TracingScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'jigsaw-puzzle',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: JigsawPuzzleScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'picture-word',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: PictureWordScreen(
                    difficulty: _parseDifficulty(state),
                    categories: _parseCategories(state),
                    timedMode: _parseTimedMode(state),
                  ),
                ),
              ),
              GoRoute(
                path: 'fsl-practice',
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: const FslPracticeHubScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'sign-to-word',
                    pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                      key: state.pageKey,
                      child: FslSignToWordScreen(
                        categories: _parseCategories(state),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'word-to-sign',
                    pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                      key: state.pageKey,
                      child: FslWordToSignScreen(
                        categories: _parseCategories(state),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const ProgressScreen(),
            ),
          ),
          GoRoute(
            path: '/stories',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const StoryListScreen(),
            ),
            routes: [
              // Story Reader (full screen via root navigator)
              GoRoute(
                path: 'read/:storyId',
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => AppPageTransitions.slideRight(
                  key: state.pageKey,
                  child: StoryReaderScreen(
                    storyId: state.pathParameters['storyId']!,
                  ),
                ),
              ),
              // Story Quiz (full screen via root navigator)
              GoRoute(
                path: 'quiz/:storyId',
                parentNavigatorKey: rootNavigatorKey,
                pageBuilder: (context, state) => AppPageTransitions.scaleUp(
                  key: state.pageKey,
                  child: StoryQuizScreen(
                    storyId: state.pathParameters['storyId']!,
                  ),
                ),
              ),
            ],
          ),
          // ─── Educator tab routes (inside shell for bottom nav) ──
          GoRoute(
            path: '/multi-dashboard',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const MultiStudentDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher-analytics',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const TeacherAnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: '/weekly-reports',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const WeeklyReportScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
      // Parent / Teacher Dashboard (full screen, not in shell)
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const DashboardScreen(),
        ),
      ),
      // Smart Review (spaced repetition)
      GoRoute(
        path: '/smart-review',
        pageBuilder: (context, state) => AppPageTransitions.scaleUp(
          key: state.pageKey,
          child: const SmartReviewScreen(),
        ),
      ),
      // Star Shop
      GoRoute(
        path: '/shop',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const ShopScreen(),
        ),
      ),
      // Backup & Restore
      GoRoute(
        path: '/backup',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const BackupRestoreScreen(),
        ),
      ),
      // Edit Profile
      GoRoute(
        path: '/edit-profile',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      // Parental Controls
      GoRoute(
        path: '/parental-controls',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ParentalControlsScreen(),
        ),
      ),
      // Classroom Mode (real-time teacher view)
      GoRoute(
        path: '/classroom',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const ClassroomDashboardScreen(),
        ),
      ),
      // Classroom Management (teacher-only: list classes, join code, members)
      GoRoute(
        path: '/classroom-manage',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const ClassroomManagementScreen(),
        ),
      ),
      // Live classroom session (real-time push from teacher to students)
      GoRoute(
        path: '/live-session',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const LiveSessionScreen(),
        ),
      ),
      // Join Class by code (student-side, no auth required)
      GoRoute(
        path: '/join-class',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const JoinClassScreen(),
        ),
      ),
      // Join Home Group by code (child-side, no auth required)
      GoRoute(
        path: '/join-home-group',
        pageBuilder: (context, state) => AppPageTransitions.fade(
          key: state.pageKey,
          child: const JoinHomeGroupScreen(),
        ),
      ),
      // Home Group Management (parent-only: list groups, codes, members)
      GoRoute(
        path: '/home-group-manage',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const HomeGroupManagementScreen(),
        ),
      ),
      // Leaderboard
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (context, state) => AppPageTransitions.slideFromBottom(
          key: state.pageKey,
          child: const LeaderboardScreen(),
        ),
      ),
      // Learning Paths
      GoRoute(
        path: '/learning-paths',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const LearningPathListScreen(),
        ),
      ),
      GoRoute(
        path: '/learning-paths/:pathId',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: LessonScreen(
            pathId: state.pathParameters['pathId']!,
          ),
        ),
      ),
      // Flashcard viewer launched from a learning-path step (full-screen,
      // outside the ShellRoute so no bottom nav is shown).
      GoRoute(
        path: '/learning-path-viewer/:category',
        pageBuilder: (context, state) {
          final catIndex = int.parse(state.pathParameters['category']!);
          if (catIndex < 0 || catIndex >= FlashcardCategory.values.length) {
            return AppPageTransitions.slideRight(
              key: state.pageKey,
              child: const DeckListScreen(),
            );
          }
          final pathId = state.uri.queryParameters['pathId'];
          final stepIndex = int.tryParse(
              state.uri.queryParameters['stepIndex'] ?? '');
          final totalSteps = int.tryParse(
              state.uri.queryParameters['totalSteps'] ?? '');
          return AppPageTransitions.slideRight(
            key: state.pageKey,
            child: FlashcardViewerScreen(
              category: FlashcardCategory.values[catIndex],
              learningPathId: pathId,
              learningStepIndex: stepIndex,
              learningTotalSteps: totalSteps,
            ),
          );
        },
      ),
      // Detailed Analytics
      GoRoute(
        path: '/analytics',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const DetailedAnalyticsScreen(),
        ),
      ),
      // FSL Dictionary
      GoRoute(
        path: '/fsl-dictionary',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const FslDictionaryScreen(),
        ),
      ),
      // Communication Board (AAC)
      GoRoute(
        path: '/communication-board',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const CommunicationBoardScreen(),
        ),
      ),
      // Communication Board Template Builder
      GoRoute(
        path: '/communication-board/builder',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const BoardTemplateBuilderScreen(),
        ),
      ),
      // Daily Challenge (full screen)
      GoRoute(
        path: '/daily-challenge',
        pageBuilder: (context, state) => AppPageTransitions.scaleUp(
          key: state.pageKey,
          child: const DailyChallengeScreen(),
        ),
      ),
      // Parent Dashboard
      GoRoute(
        path: '/parent-dashboard',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ParentDashboardScreen(),
        ),
      ),
      // Adaptive Analytics Dashboard
      GoRoute(
        path: '/adaptive-analytics',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const AdaptiveAnalyticsScreen(),
        ),
      ),
      // Multiplayer Quiz
      GoRoute(
        path: '/multiplayer-quiz',
        pageBuilder: (context, state) => AppPageTransitions.scaleUp(
          key: state.pageKey,
          child: const MultiplayerQuizScreen(),
        ),
      ),
      // Voice-Guided Mode
      GoRoute(
        path: '/voice-guided',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const VoiceGuidedModeScreen(),
        ),
      ),
      // Enhanced Flashcard Creator
      GoRoute(
        path: '/create-flashcard-enhanced',
        pageBuilder: (context, state) {
          final card = state.extra as Flashcard?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: EnhancedCreateFlashcardScreen(editCard: card),
          );
        },
      ),
      // ─── Assessment Module ──────────────────────────
      GoRoute(
        path: '/assessment',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const AssessmentHubScreen(),
        ),
      ),
      GoRoute(
        path: '/assessment/take/:id',
        pageBuilder: (context, state) {
          final assessment = state.extra as Assessment?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: assessment == null
                ? const AssessmentHubScreen()
                : AssessmentTestScreen(assessment: assessment),
          );
        },
      ),
      GoRoute(
        path: '/assessment/summary',
        pageBuilder: (context, state) {
          final result = state.extra as AssessmentResult?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: result == null
                ? const AssessmentResultsScreen()
                : AssessmentSummaryScreen(result: result),
          );
        },
      ),
      GoRoute(
        path: '/assessment/results',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const AssessmentResultsScreen(),
        ),
      ),
      GoRoute(
        path: '/assessment/builder',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const AssessmentBuilderScreen(),
        ),
      ),
      GoRoute(
        path: '/assessment/assign',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const AssessmentAssignScreen(),
        ),
      ),
      GoRoute(
        path: '/assessment/tracking',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const AssignmentTrackingScreen(),
        ),
      ),
      GoRoute(
        path: '/assessment/category/:categoryIndex',
        pageBuilder: (context, state) {
          final assessment = state.extra as Assessment?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: assessment == null
                ? const AssessmentHubScreen()
                : AssessmentTestScreen(assessment: assessment),
          );
        },
      ),
      // ─── Showcase / Portfolio ────────────────────────
      GoRoute(
        path: '/showcase',
        pageBuilder: (context, state) => AppPageTransitions.slideFromBottom(
          key: state.pageKey,
          child: const ShowcaseScreen(),
        ),
      ),
      GoRoute(
        path: '/showcase/detail',
        pageBuilder: (context, state) {
          final item = state.extra as ShowcaseItem?;
          return AppPageTransitions.slideRight(
            key: state.pageKey,
            child: item == null
                ? const ShowcaseScreen()
                : ShowcaseDetailScreen(item: item),
          );
        },
      ),
      GoRoute(
        path: '/showcase/share',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const ShowcaseShareScreen(),
        ),
      ),
      // ─── Learning Gain Dashboard ────────────────────
      GoRoute(
        path: '/learning-gain',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const LearningGainScreen(),
        ),
      ),
      // ─── Smart Recommendations ──────────────────────
      GoRoute(
        path: '/recommendations',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const RecommendationsScreen(),
        ),
      ),
      // ─── Mood Tracker ──────────────────────────────
      GoRoute(
        path: '/mood-check-in',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const MoodCheckInScreen(),
        ),
      ),
      GoRoute(
        path: '/mood-history',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const MoodHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/mood-insights',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const MoodInsightsScreen(),
        ),
      ),
      // ─── Sticker Album ──────────────────────────────
      GoRoute(
        path: '/sticker-album',
        pageBuilder: (context, state) => AppPageTransitions.slideFromBottom(
          key: state.pageKey,
          child: const StickerAlbumScreen(),
        ),
      ),
      // ─── Guided Practice ────────────────────────────
      GoRoute(
        path: '/guided-practice',
        pageBuilder: (context, state) {
          final categoryIndex =
              int.tryParse(state.uri.queryParameters['category'] ?? '');
          final category = categoryIndex != null &&
                  categoryIndex >= 0 &&
                  categoryIndex < FlashcardCategory.values.length
              ? FlashcardCategory.values[categoryIndex]
              : FlashcardCategory.values.first;
          return AppPageTransitions.scaleUp(
            key: state.pageKey,
            child: GuidedPracticeScreen(category: category),
          );
        },
      ),
      // ─── AI Tutor ──────────────────────────────────
      GoRoute(
        path: '/ai-tutor',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const AiTutorScreen(),
        ),
      ),
      // ─── Messaging ─────────────────────────────────
      GoRoute(
        path: '/messages',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const MessagingScreen(),
        ),
      ),
      // ─── Peer Collaboration ─────────────────────────
      GoRoute(
        path: '/peer-collab',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const PeerCollaborationScreen(),
        ),
      ),
      // ─── Printable Worksheets ────────────────────────
      GoRoute(
        path: '/worksheets',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const WorksheetScreen(),
        ),
      ),
      // ─── Notebook (Study Journal) ────────────────────
      GoRoute(
        path: '/notebook',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const NotebookScreen(),
        ),
      ),
      GoRoute(
        path: '/notebook/editor',
        pageBuilder: (context, state) {
          final note = state.extra as NoteEntry?;
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: NoteEditorScreen(existingNote: note),
          );
        },
      ),
      // ─── Goals ───────────────────────────────────────
      GoRoute(
        path: '/goals',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const GoalsScreen(),
        ),
      ),
      // ─── Streak Calendar ─────────────────────────────
      GoRoute(
        path: '/streak-calendar',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const StreakCalendarScreen(),
        ),
      ),
      // ─── Certificates ────────────────────────────────
      GoRoute(
        path: '/certificates',
        pageBuilder: (context, state) => AppPageTransitions.slideFromBottom(
          key: state.pageKey,
          child: const CertificateScreen(),
        ),
      ),
      // ─── Hard Words Review ───────────────────────────
      GoRoute(
        path: '/hard-words',
        pageBuilder: (context, state) => AppPageTransitions.scaleUp(
          key: state.pageKey,
          child: const HardWordsScreen(),
        ),
      ),
      // ─── Custom Quiz Builder ─────────────────────────
      GoRoute(
        path: '/quiz-builder',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const QuizBuilderScreen(),
        ),
      ),
      // ─── Progress Timeline (educator only) ────────────
      GoRoute(
        path: '/progress-timeline/:profileId',
        pageBuilder: (context, state) {
          final profileId = state.pathParameters['profileId'] ?? '';
          final name = state.uri.queryParameters['name'] ?? 'Student';
          return AppPageTransitions.slideRight(
            key: state.pageKey,
            child: ProgressTimelineScreen(
              profileId: profileId,
              profileName: name,
            ),
          );
        },
      ),
      // ─── Student Comparison (teacher only) ─────────────
      GoRoute(
        path: '/student-comparison',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const StudentComparisonScreen(),
        ),
      ),
      // ─── Alert Settings (educator only) ────────────────
      GoRoute(
        path: '/alert-settings',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const AlertSettingsScreen(),
        ),
      ),
      // ─── Research Data Export (educator only) ──────────
      GoRoute(
        path: '/research-export',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ResearchExportScreen(),
        ),
      ),
      // ─── SUS Usability Survey ──────────────────────────
      GoRoute(
        path: '/sus-survey',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SusSurveyScreen(),
        ),
      ),
      // ─── Student Smileyometer (learner feedback) ───────
      GoRoute(
        path: '/smileyometer',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SmileyometerScreen(),
        ),
      ),
      GoRoute(
        path: '/survey-results',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const SurveyResultsScreen(),
        ),
      ),
      // ─── Experiment Mode (educator only) ───────────────
      GoRoute(
        path: '/experiment-setup',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const ExperimentSetupScreen(),
        ),
      ),
      // ─── Word of the Day ─────────────────────────────
      GoRoute(
        path: '/word-of-day',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const WordOfDayScreen(),
        ),
      ),
      // ─── Focus Mode ─────────────────────────────────
      GoRoute(
        path: '/focus-mode',
        pageBuilder: (context, state) => AppPageTransitions.blurFade(
          key: state.pageKey,
          child: const FocusModeScreen(),
        ),
      ),
      // ─── Parent-Teacher Notes ────────────────────────
      GoRoute(
        path: '/parent-teacher-notes',
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          key: state.pageKey,
          child: const ParentTeacherNotesScreen(),
        ),
      ),
      // ─── Gamification Dashboard (student) ──────────────
      GoRoute(
        path: '/gamification-dashboard',
        pageBuilder: (context, state) => AppPageTransitions.slideFromBottom(
          key: state.pageKey,
          child: const GamificationDashboardScreen(),
        ),
      ),
    ],
  );
});

/// Parses difficulty from the query parameter, defaulting to medium.
GameDifficulty _parseDifficulty(GoRouterState state) {
  final raw = state.uri.queryParameters['difficulty'];
  return GameDifficulty.values.where((d) => d.name == raw).firstOrNull ??
      GameDifficulty.medium;
}

/// Parses categories from the query parameter.
/// Returns empty list when "All Categories" was chosen (or param absent).
List<FlashcardCategory> _parseCategories(GoRouterState state) {
  final raw = state.uri.queryParameters['categories'];
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((s) => int.tryParse(s))
      .where((i) => i != null && i >= 0 && i < FlashcardCategory.values.length)
      .map((i) => FlashcardCategory.values[i!])
      .toList();
}

/// Parses timed mode from the query parameter.
bool _parseTimedMode(GoRouterState state) {
  return state.uri.queryParameters['timed'] == 'true';
}
