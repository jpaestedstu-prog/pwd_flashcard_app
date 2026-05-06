import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/xp_level_service.dart';
import 'app_providers.dart';

/// Tracks the current player level and emits the new [PlayerLevel] when
/// the user crosses a level boundary.
///
/// Widgets can `ref.listen(levelUpProvider, ...)` to react to level changes.
class LevelUpNotifier extends Notifier<PlayerLevel> {
  @override
  PlayerLevel build() {
    final progress = ref.watch(progressProvider);
    return XpService.currentLevel(progress);
  }
}

final levelUpProvider =
    NotifierProvider<LevelUpNotifier, PlayerLevel>(LevelUpNotifier.new);
