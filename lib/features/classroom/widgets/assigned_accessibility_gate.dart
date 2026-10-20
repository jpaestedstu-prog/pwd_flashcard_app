import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/assigned_accessibility.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/assigned_accessibility_provider.dart';

/// App-root listener that applies the accessibility a learner's Teacher or
/// Parent set for them in Manage Classes / Home Groups (see
/// [AssignedAccessibility]) on whichever device the learner is signed in.
///
/// Sibling to `MembershipEvictionGate`: the same signal source — the
/// learner's own membership row — read for a different field. Inert for
/// anyone but a Student in a class or a Child in a home group, and where
/// there is no cloud (a change made on this very tablet is applied there and
/// then by the educator's own save).
///
/// Each version is applied once. The learner is told in a line that their
/// settings changed, and by whom — the screen's colours, text size or sounds
/// may have just changed under them — unless it is an educator viewing the
/// learner, who made the change themselves.
class AssignedAccessibilityGate extends ConsumerWidget {
  const AssignedAccessibilityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final rowPath = assignedAccessibilityRowPath(profile);
    if (profile != null && rowPath != null) {
      final assigned =
          ref.watch(assignedAccessibilityProvider(rowPath)).valueOrNull;
      if (assigned != null && isUnappliedAssignment(profile.id, assigned)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _apply(context, ref, profile, assigned),
        );
      }
    }
    return child;
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    AssignedAccessibility assigned,
  ) async {
    try {
      final applied = await applyAssignedAccessibility(
        read: ref.read,
        invalidate: ref.invalidate,
        profileId: profile.id,
        assigned: assigned,
      );
      if (!applied || !context.mounted) return;
      if (ref.read(profileProvider.notifier).isViewingAsStudent) return;
      final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            t.assignedAccessibilityNotice(
              profile.role == UserRole.child ? 'parent' : 'teacher',
            ),
          ),
        ),
      );
    } catch (e, s) {
      ErrorHandler.report(e, s, 'AssignedAccessibilityGate:silent');
    }
  }
}
