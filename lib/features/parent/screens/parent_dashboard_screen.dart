import 'package:flutter/material.dart';

import 'educator_dashboard_screen.dart';

// The dashboard body is shared with the teacher's surface — see
// [EducatorDashboardScreen]. Re-exported so the widgets that were written
// against this file (e.g. `ParentRecommendationCard`) keep their import.
export 'educator_dashboard_screen.dart'
    show
        EducatorAudience,
        EducatorDashboardScreen,
        ParentRecommendation,
        generateEducatorRecommendations;

/// Parent Dashboard — overview of all children's learning progress.
///
/// Thin role binding over [EducatorDashboardScreen]; the teacher sees the
/// identical surface via `TeacherDashboardScreen`.
class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const EducatorDashboardScreen(audience: EducatorAudience.parent);
}
