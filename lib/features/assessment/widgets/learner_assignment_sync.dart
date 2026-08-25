import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/assessment_provider.dart';

/// Re-pulls a learner's assigned work when the app comes back to the
/// foreground. Renders nothing.
///
/// [learnerAssignmentSyncProvider] is a `FutureProvider.family`, so it runs
/// once per profile and then caches — which meant a learner sitting on the home
/// screen never saw work assigned to them until they restarted the app. That is
/// exactly the classroom case: the tablet is put down, the teacher assigns, the
/// learner picks it back up.
///
/// Resume is the trigger rather than a poll or a live listener: it costs one
/// read at the moment the learner is actually looking, it needs no extra
/// Firestore listener on a free-tier project, and a tablet that never sleeps
/// still had its pull at launch.
///
/// This widget only *invalidates*; the home screens keep watching the provider
/// themselves. That matters because the "Pending Assignments" banner is chosen
/// by an `if` in the home's own build — the home has to rebuild for new work to
/// appear, so refreshing from a leaf widget would repaint nothing.
class LearnerAssignmentSync extends ConsumerStatefulWidget {
  final String profileId;

  const LearnerAssignmentSync({super.key, required this.profileId});

  @override
  ConsumerState<LearnerAssignmentSync> createState() =>
      _LearnerAssignmentSyncState();
}

class _LearnerAssignmentSyncState extends ConsumerState<LearnerAssignmentSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (widget.profileId.isEmpty) return;
    // Invalidating re-runs the pull; whoever is watching it rebuilds when the
    // new data lands. A no-op without Firebase, like the pull itself.
    ref.invalidate(learnerAssignmentSyncProvider(widget.profileId));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
