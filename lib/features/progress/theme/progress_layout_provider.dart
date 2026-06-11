import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import 'progress_layout.dart';
import 'progress_layout_registry.dart';

/// The Progress layout template for the **active** profile. Re-resolves
/// automatically when the active profile switches (it watches
/// [profileProvider]), so each learner on a shared tablet keeps their own
/// template. Mirrors `ProgressThemeNotifier`.
class ProgressLayoutNotifier extends Notifier<ProgressLayout> {
  @override
  ProgressLayout build() {
    final profile = ref.watch(profileProvider);
    if (profile == null) return ProgressLayouts.defaultLayout;
    return ProgressLayouts.byId(HiveService.getProgressLayoutId(profile.id));
  }

  /// Persist + apply a template for the active profile.
  Future<void> select(String layoutId) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await HiveService.saveProgressLayoutId(profile.id, layoutId);
    state = ProgressLayouts.byId(layoutId);
  }
}

final progressLayoutProvider =
    NotifierProvider<ProgressLayoutNotifier, ProgressLayout>(
        ProgressLayoutNotifier.new);

/// The Progress layout for an arbitrary profile (used by the child detail
/// sheet, which renders a child who isn't the active profile).
final progressLayoutForProvider =
    Provider.family<ProgressLayout, String>((ref, profileId) {
  return ProgressLayouts.byId(HiveService.getProgressLayoutId(profileId));
});

/// Persist a template for a specific (non-active) profile and refresh its
/// [progressLayoutForProvider]. Used by the combined picker (called from
/// widget code, hence [WidgetRef]).
Future<void> selectProgressLayoutFor(
  WidgetRef ref,
  String profileId,
  String layoutId,
) async {
  await HiveService.saveProgressLayoutId(profileId, layoutId);
  ref.invalidate(progressLayoutForProvider(profileId));
}
