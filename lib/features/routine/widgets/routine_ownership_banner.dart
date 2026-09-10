import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/profile_ownership.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';

/// Whether this device can write cloud data for one profile.
///
/// A `FutureProvider.family` rather than a one-shot call so the answer is
/// cached for the session — it is one Firestore read and it does not change
/// while the app is open.
final profileCloudOwnershipProvider =
    FutureProvider.family<ProfileCloudOwnership, String>((ref, profileId) {
  return const ProfileOwnershipService().check(profileId);
});

/// Warns an educator, *before* they build anything, that this device can no
/// longer sync the profile they are signed in as.
///
/// Restoring a profile onto another device moves cloud ownership to it. The
/// device left behind keeps saving to Hive and is refused by the rules, which
/// on this tablet went unnoticed for six weeks — every routine, alarm and
/// assignment written for that educator stayed on the tablet.
///
/// Renders nothing at all unless ownership is *known* to sit elsewhere: a
/// failed read or an unconfigured Firebase must never produce a banner
/// telling someone to go and find another tablet.
class RoutineOwnershipBanner extends ConsumerWidget {
  /// The educator whose cloud ownership decides whether writes land — the
  /// signed-in adult, not the learner being edited.
  final String? educatorProfileId;

  final bool filipino;

  const RoutineOwnershipBanner({
    super.key,
    required this.educatorProfileId,
    required this.filipino,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = educatorProfileId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final ownership = ref.watch(profileCloudOwnershipProvider(id)).valueOrNull;
    if (ownership == null || !ownership.blocksCloudWrites) {
      return const SizedBox.shrink();
    }

    final hc = HCColor.of(context);
    final l = filipino;
    final name = ref.watch(profileProvider)?.name ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppColors.warning.withValues(alpha: 0.18),
          hc.surface,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l
                      ? 'Hindi makakarating sa bata ang mga pagbabago'
                      : "Changes here won't reach your learner",
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l
                      ? 'Na-restore ang profile na "$name" sa ibang device, '
                          'kaya iyon na ang nagpapadala. Puwede ka pa ring '
                          'mag-edit dito, pero mananatili lang ito sa tablet '
                          'na ito. Para maibalik: buksan ang profile sa device '
                          'na may hawak nito, kumuha ng bagong recovery code, '
                          'at i-restore ito rito.'
                      : 'The profile "$name" was restored onto another device, '
                          'so that one now handles syncing. You can still edit '
                          'here, but nothing will leave this tablet. To move it '
                          'back: open the profile on the device that has it, '
                          'generate a new recovery code, and restore it here.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
