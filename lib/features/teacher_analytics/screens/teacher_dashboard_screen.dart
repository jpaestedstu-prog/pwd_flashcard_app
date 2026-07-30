import 'package:flutter/material.dart';

import '../../parent/screens/educator_dashboard_screen.dart';

/// Teacher Dashboard — overview of every student on the teacher's roster.
///
/// Thin role binding over [EducatorDashboardScreen], the same surface the
/// parent sees as `ParentDashboardScreen`: class-wide totals, per-student
/// cards with accuracy rings and weekly trends, the weekly study chart, and
/// the recommendation feed. Keeping one implementation is what stops the two
/// educator roles from drifting apart.
class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const EducatorDashboardScreen(audience: EducatorAudience.teacher);
}
