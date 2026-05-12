import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/enums.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/membership_watcher_provider.dart';

/// App-root gate that watches the active learner's classroom /
/// home-group membership and, when the educator deletes it, signs the
/// device out of the profile and routes to the eviction-notice screen.
///
/// Sibling to [LockEnforcerGate] — same shape, different signal source.
/// Mounted above [LockEnforcerGate] in [main.dart] so eviction wins
/// over a time-driven lock screen for an obviously-removed learner.
///
/// Inert for non-learner profiles or learners with no group linkage.
/// On devices where Firebase isn't configured, the underlying watcher
/// provider short-circuits to "membership exists", so single-device
/// demos never spuriously evict.
class MembershipEvictionGate extends ConsumerWidget {
  final Widget child;
  const MembershipEvictionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isLearner = profile != null &&
        (profile.role == UserRole.student ||
            profile.role == UserRole.child) &&
        !profile.isGuestPlayer;

    if (isLearner) {
      // Classroom-side eviction (student profile in a class).
      if (profile.classroomId != null) {
        ref.listen(
          classroomMembershipExistsProvider(profile.id),
          (_, next) {
            if (next.value == false) {
              _evict(
                ref,
                context,
                wasClassroom: true,
                fromKind: 'class',
              );
            }
          },
        );
      }
      // Home-group-side eviction (child profile in a home group).
      if (profile.homeGroupId != null) {
        ref.listen(
          homeGroupMembershipExistsProvider(profile.id),
          (_, next) {
            if (next.value == false) {
              _evict(
                ref,
                context,
                wasClassroom: false,
                fromKind: 'group',
              );
            }
          },
        );
      }
    }

    return child;
  }

  Future<void> _evict(
    WidgetRef ref,
    BuildContext _, {
    required bool wasClassroom,
    required String fromKind,
  }) async {
    // Order matters: clear the linkage + active profile FIRST so that
    // the listeners on the next route don't immediately re-fire (the
    // membership stream will still emit `false`, but profile is null
    // by then and the gate becomes inert).
    await ref.read(profileProvider.notifier).handleEviction(
          wasClassroom: wasClassroom,
        );
    // Resolve the navigator context AFTER the await so we never lean
    // on a possibly-stale local BuildContext across the async gap.
    // The lookup goes through the global root navigator key, which is
    // exactly the documented pattern — the analyzer's
    // use_build_context_synchronously hint here is a known false
    // positive for global-key contexts.
    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null) return;
    // ignore: use_build_context_synchronously
    final loc = GoRouter.of(navCtx).routeInformationProvider.value.uri.path;
    if (loc == '/membership-removed') return;
    // ignore: use_build_context_synchronously
    GoRouter.of(navCtx).go('/membership-removed?from=$fromKind');
  }
}
