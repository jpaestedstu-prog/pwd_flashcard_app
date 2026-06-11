import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import 'progress_theme.dart';
import 'progress_theme_registry.dart';

/// The Progress skin for the **active** profile. Re-resolves automatically
/// when the active profile switches (it watches [profileProvider]), so each
/// learner on a shared tablet gets their own skin.
class ProgressThemeNotifier extends Notifier<ProgressTheme> {
  @override
  ProgressTheme build() {
    final profile = ref.watch(profileProvider);
    if (profile == null) return ProgressThemes.defaultTheme;
    return ProgressThemes.byId(HiveService.getProgressThemeId(profile.id));
  }

  /// Persist + apply a skin for the active profile.
  Future<void> select(String themeId) async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await HiveService.saveProgressThemeId(profile.id, themeId);
    state = ProgressThemes.byId(themeId);
  }
}

final progressThemeProvider =
    NotifierProvider<ProgressThemeNotifier, ProgressTheme>(
        ProgressThemeNotifier.new);

/// The Progress skin for an arbitrary profile (used by the child detail
/// sheet, which renders a child who isn't the active profile). Reads the
/// child's stored skin; invalidate it after a parent picks a new one.
final progressThemeForProvider =
    Provider.family<ProgressTheme, String>((ref, profileId) {
  return ProgressThemes.byId(HiveService.getProgressThemeId(profileId));
});

/// Persist a skin for a specific (non-active) profile and refresh its
/// [progressThemeForProvider]. Used by the child theme picker (called from
/// widget code, hence [WidgetRef]).
Future<void> selectProgressThemeFor(
  WidgetRef ref,
  String profileId,
  String themeId,
) async {
  await HiveService.saveProgressThemeId(profileId, themeId);
  ref.invalidate(progressThemeForProvider(profileId));
}
