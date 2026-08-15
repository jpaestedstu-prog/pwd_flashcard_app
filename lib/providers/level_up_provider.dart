import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/xp_level_service.dart';
import 'app_providers.dart';

/// A [PlayerLevel] together with the profile it was computed for.
///
/// The profile id is what makes a level *change* interpretable. `progressProvider`
/// watches `profileProvider`, so switching profiles replaces the whole progress
/// record in one emission — without the id, a switch from a Level 1 learner to a
/// Level 5 one is indistinguishable from that learner levelling up four times,
/// and the shell fired a "LEVEL UP!" celebration for a level nobody had just
/// earned. Compare [profileId] before reacting to [level].
class LevelSnapshot {
  final String profileId;
  final PlayerLevel level;

  const LevelSnapshot({required this.profileId, required this.level});

  /// Whether [other] → this is a genuine climb *by the same learner*, i.e. the
  /// only transition worth celebrating.
  bool isLevelUpFrom(LevelSnapshot? other) =>
      other != null &&
      other.profileId == profileId &&
      level.level > other.level.level;
}

/// Tracks the current player level and emits a new [LevelSnapshot] whenever the
/// level or the active profile changes.
///
/// Widgets can `ref.listen(levelUpProvider, ...)` to react — gate the reaction
/// on [LevelSnapshot.isLevelUpFrom] rather than comparing levels directly.
class LevelUpNotifier extends Notifier<LevelSnapshot> {
  @override
  LevelSnapshot build() {
    final progress = ref.watch(progressProvider);
    return LevelSnapshot(
      profileId: progress.profileId,
      level: XpService.currentLevel(progress),
    );
  }
}

final levelUpProvider = NotifierProvider<LevelUpNotifier, LevelSnapshot>(
  LevelUpNotifier.new,
);
