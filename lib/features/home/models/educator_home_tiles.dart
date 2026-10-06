import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../parent/models/educator_audience.dart';

/// Where a quick action sits on the educator home.
enum EducatorTileSection {
  /// The large tiles under the dashboard button.
  primary,

  /// "More" → Content.
  content,

  /// "More" → Assessments & Progress.
  assessments,

  /// "More" → Research.
  research,
}

typedef EducatorText =
    String Function(AppLocalizations t, EducatorAudience audience);

/// One quick action on the educator home.
///
/// A tile is on BOTH homes — teacher and parent — unless [onlyFor] says
/// otherwise, and saying otherwise takes a [because].
class EducatorHomeTile {
  const EducatorHomeTile({
    required this.id,
    required this.section,
    required this.icon,
    required this.accent,
    required this.label,
    required this.route,
    this.caption,
    this.iconFor,
    this.onlyFor,
    this.because,
    this.showsUnreadMessages = false,
  }) : assert(
         (onlyFor == null) == (because == null),
         'a one-role tile must say why; a shared tile has nothing to explain',
       );

  /// Stable name for tests and the parity audit.
  final String id;
  final EducatorTileSection section;
  final IconData icon;

  /// A different icon per audience, where the destination differs too.
  final IconData Function(EducatorAudience audience)? iconFor;
  final Color accent;
  final EducatorText label;

  /// Shown on the large primary tiles only.
  final EducatorText? caption;
  final String Function(EducatorAudience audience) route;

  /// Null = both homes.
  final EducatorAudience? onlyFor;

  /// Why only [onlyFor] gets this tile.
  final String? because;

  /// Carries the unread-messages badge.
  final bool showsUnreadMessages;

  bool isFor(EducatorAudience audience) =>
      onlyFor == null || onlyFor == audience;
}

/// Every quick action on the educator home, in the order it appears.
///
/// The two homes used to be two hand-written lists, `_buildParentChips` and
/// `_buildTeacherChips`, and they drifted: when the grids were split by role
/// the parent's copy quietly lost the whole Assessments group, and later
/// Worksheets, which was a parent's only way to /worksheets. One list means a
/// new tile reaches both homes by default; leaving one out is a decision
/// written down here, and `educator_home_tiles_test.dart` pins every such
/// decision.
final List<EducatorHomeTile> educatorHomeTiles = [
  // ─── Primary ───────────────────────────────────────
  EducatorHomeTile(
    id: 'allLearners',
    section: EducatorTileSection.primary,
    icon: Icons.people_rounded,
    accent: AppColors.sectionLearning,
    label: (t, a) =>
        a.allLearnersTitleOf(filipino: t.localeName.startsWith('fil')),
    caption: (t, a) => t.eduRosterProgress,
    route: (_) => '/multi-dashboard',
    onlyFor: EducatorAudience.teacher,
    because:
        'a whole-class roster; a parent sees their children on the home '
        'itself and in the Parent Dashboard',
  ),
  EducatorHomeTile(
    id: 'analytics',
    section: EducatorTileSection.primary,
    icon: Icons.analytics_rounded,
    accent: AppColors.sectionCommunication,
    label: (t, a) => t.eduAnalytics,
    caption: (t, a) => t.eduClassInsights,
    route: (_) => '/teacher-analytics',
    onlyFor: EducatorAudience.teacher,
    because:
        'class insights; a parent has the same analytics as a tab in their '
        'bottom bar',
  ),
  EducatorHomeTile(
    id: 'reports',
    section: EducatorTileSection.primary,
    icon: Icons.assessment_rounded,
    accent: AppColors.warning,
    label: (t, a) => t.eduReports,
    caption: (t, a) => t.eduWeeklySummary,
    route: (_) => '/weekly-reports',
  ),
  EducatorHomeTile(
    id: 'parentalControls',
    section: EducatorTileSection.primary,
    icon: Icons.shield_rounded,
    accent: AppColors.sectionAssessment,
    label: (t, a) => t.eduParentalControlsTile,
    caption: (t, a) => t.eduLimitsSafety,
    route: (_) => '/parental-controls',
    onlyFor: EducatorAudience.parent,
    because:
        'screen-time limits and safety for a parent’s own children at home',
  ),
  EducatorHomeTile(
    id: 'classroom',
    section: EducatorTileSection.primary,
    icon: Icons.cast_for_education_rounded,
    accent: AppColors.accent,
    label: (t, a) => t.eduClassroomTile,
    caption: (t, a) => t.eduLiveSession,
    route: (_) => '/classroom',
    onlyFor: EducatorAudience.teacher,
    because: 'a live lesson run for a whole class',
  ),
  EducatorHomeTile(
    id: 'cards',
    section: EducatorTileSection.primary,
    icon: Icons.style_rounded,
    accent: AppColors.info,
    label: (t, a) => t.eduCards,
    caption: (t, a) => t.eduBrowseDecks,
    route: (_) => '/flashcards',
  ),
  EducatorHomeTile(
    id: 'shareCode',
    section: EducatorTileSection.primary,
    icon: Icons.qr_code_2_rounded,
    accent: AppColors.success,
    label: (t, a) => t.eduShareCode,
    caption: (t, a) => a.isParent ? t.eduInviteChild : t.eduInviteStudents,
    // A parent shares a home group's code, a teacher a class's.
    route: (a) => a.isParent ? '/home-group-manage' : '/classroom-manage',
  ),

  // ─── More → Content ────────────────────────────────
  EducatorHomeTile(
    id: 'tvCast',
    section: EducatorTileSection.content,
    icon: Icons.tv_rounded,
    accent: AppColors.primary,
    label: (t, a) => t.eduTvCast,
    route: (_) => '/tv-cast',
  ),
  EducatorHomeTile(
    id: 'worksheets',
    section: EducatorTileSection.content,
    icon: Icons.print_rounded,
    accent: AppColors.sectionWellbeing,
    label: (t, a) => t.eduWorksheets,
    route: (_) => '/worksheets',
  ),
  EducatorHomeTile(
    id: 'messages',
    section: EducatorTileSection.content,
    icon: Icons.message_rounded,
    accent: AppColors.sectionSocial,
    label: (t, a) => t.eduMessages,
    route: (_) => '/messages',
    showsUnreadMessages: true,
  ),
  EducatorHomeTile(
    id: 'notes',
    section: EducatorTileSection.content,
    icon: Icons.sticky_note_2_rounded,
    accent: AppColors.sectionCommunication,
    // Named after whoever is on the other side of the notes.
    label: (t, a) => a.isParent ? t.eduTeacherNotes : t.eduParentNotes,
    route: (_) => '/parent-teacher-notes',
  ),

  // ─── More → Assessments & Progress ─────────────────
  EducatorHomeTile(
    id: 'assessments',
    section: EducatorTileSection.assessments,
    icon: Icons.quiz_rounded,
    accent: AppColors.sectionAssessment,
    label: (t, a) => t.eduAssessments,
    route: (_) => '/assessment',
  ),
  EducatorHomeTile(
    id: 'assignTasks',
    section: EducatorTileSection.assessments,
    icon: Icons.assignment_turned_in_rounded,
    accent: AppColors.success,
    label: (t, a) => t.eduAssignTasks,
    route: (_) => '/assessment/assign',
  ),
  EducatorHomeTile(
    id: 'trackProgress',
    section: EducatorTileSection.assessments,
    icon: Icons.track_changes_rounded,
    accent: AppColors.info,
    label: (t, a) => t.eduTrackProgress,
    route: (_) => '/assessment/tracking',
  ),
  EducatorHomeTile(
    id: 'classReport',
    section: EducatorTileSection.assessments,
    icon: Icons.insights_rounded,
    accent: AppColors.sectionAssessment,
    label: (t, a) => t.eduClassReport,
    route: (_) => '/assessment/class-report',
  ),
  EducatorHomeTile(
    id: 'manageGroups',
    section: EducatorTileSection.assessments,
    icon: Icons.qr_code_2_rounded,
    iconFor: (a) =>
        a.isParent ? Icons.family_restroom_rounded : Icons.qr_code_2_rounded,
    accent: AppColors.sectionCommunication,
    // A teacher manages classes, a parent home groups — never the other's.
    label: (t, a) => a.isParent ? t.eduManageGroups : t.eduManageClasses,
    route: (a) => a.isParent ? '/home-group-manage' : '/classroom-manage',
  ),

  // ─── More → Research ───────────────────────────────
  EducatorHomeTile(
    id: 'experimentSetup',
    section: EducatorTileSection.research,
    icon: Icons.science_rounded,
    accent: AppColors.sectionWellbeing,
    label: (t, a) => t.eduExperimentSetup,
    route: (_) => '/experiment-setup',
    onlyFor: EducatorAudience.teacher,
    because:
        'the study runs no control groups at home, so a parent has nothing '
        'to set up',
  ),
  EducatorHomeTile(
    id: 'susSurvey',
    section: EducatorTileSection.research,
    icon: Icons.poll_rounded,
    accent: AppColors.sectionCommunication,
    label: (t, a) => t.eduSusSurvey,
    route: (_) => '/survey-results',
  ),
  EducatorHomeTile(
    id: 'researchExport',
    section: EducatorTileSection.research,
    icon: Icons.file_download_rounded,
    accent: AppColors.primaryDark,
    label: (t, a) => t.eduResearchExport,
    route: (_) => '/research-export',
  ),
];

/// The tiles one audience sees in one section, in order.
List<EducatorHomeTile> educatorTilesFor(
  EducatorAudience audience,
  EducatorTileSection section,
) => [
  for (final tile in educatorHomeTiles)
    if (tile.section == section && tile.isFor(audience)) tile,
];
