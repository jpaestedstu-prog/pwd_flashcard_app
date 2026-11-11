import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/parental_controls.dart';
import 'parental_controls_service.dart';

/// What the device's Parental Controls take away from a learner.
///
/// The Parental Controls screen saved a daily time limit, blocked games and
/// blocked categories, and nothing in the app ever read them: a parent who
/// blocked a game saw it ticked, and the child went on playing it. (The
/// schedule and the shop, multiplayer and messaging blocks were always
/// enforced, by the router.) A button crawl and a look at who reads each field
/// found it, 4 Nov 2026.
///
/// Educators are not restricted: a Teacher or Parent sees every deck, to
/// assign it. With nothing blocked every call here returns its input as it
/// was, so a device without controls behaves exactly as before.
abstract final class LearnerRestrictions {
  /// The controls, or none when they cannot be read: failing open, as the
  /// router does. The settings box is closed in many widget tests and for a
  /// moment at startup.
  static ParentalControls get controls {
    try {
      return ParentalControlsService.getControls();
    } catch (_) {
      return const ParentalControls();
    }
  }

  static bool _applies(UserRole? role) =>
      role != UserRole.teacher && role != UserRole.parent;

  /// The games [role] may not open.
  static Set<GameType> blockedGames(UserRole? role) =>
      _applies(role) ? controls.blockedGames : const {};

  /// The card categories hidden from [role].
  static Set<FlashcardCategory> blockedCategories(UserRole? role) =>
      _applies(role) ? controls.blockedCategories : const {};

  /// [games] without the ones blocked for [role].
  static List<GameType> visibleGames(List<GameType> games, UserRole? role) {
    final blocked = blockedGames(role);
    if (blocked.isEmpty) return games;
    return [
      for (final game in games)
        if (!blocked.contains(game)) game,
    ];
  }

  /// The categories to offer [role], in their usual order.
  static List<FlashcardCategory> categoriesFor(UserRole? role) {
    final blocked = blockedCategories(role);
    if (blocked.isEmpty) return FlashcardCategory.values;
    return [
      for (final category in FlashcardCategory.values)
        if (!blocked.contains(category)) category,
    ];
  }

  /// The categories to offer whoever is playing: a game's picker and its word
  /// pool, which have no profile at hand. Only learners play.
  static List<FlashcardCategory> get playableCategories =>
      categoriesFor(UserRole.student);

  /// [cards] without those in a blocked category, for what picks words by
  /// itself: the daily word, the AI Tutor, the dictionary.
  static List<Flashcard> visibleCards(List<Flashcard> cards) {
    final blocked = controls.blockedCategories;
    if (blocked.isEmpty) return cards;
    final left = [
      for (final card in cards)
        if (!blocked.contains(card.category)) card,
    ];
    return left.isEmpty ? cards : left;
  }

  /// The categories a game plays with: [requested] (empty means all) less the
  /// blocked ones. Empty still means "all" when nothing is blocked, so a game
  /// starts as it always has; a saved choice of a category blocked since does
  /// not bring it back.
  static List<FlashcardCategory> gameCategories(
    List<FlashcardCategory> requested,
  ) {
    final blocked = controls.blockedCategories;
    if (blocked.isEmpty) return requested;
    final base = requested.isEmpty ? FlashcardCategory.values : requested;
    final left = [
      for (final category in base)
        if (!blocked.contains(category)) category,
    ];
    return left.isEmpty ? playableCategories : left;
  }

  /// The limit a supervised learner plays under: their own, if an educator set
  /// one, or else the device's from Parental Controls. [ChildTimeLimit] is
  /// what the lock reads, so the device's limit locks, warns and hands over
  /// to an adult exactly as a learner's own does.
  static ChildTimeLimit? limitFor(
    ChildTimeLimit? own, {
    required String childProfileId,
    required bool supervised,
  }) {
    if (!supervised || (own != null && own.dailyLimitEnabled)) return own;
    final device = controls;
    if (!device.timeLimitEnabled) return own;
    final base = own ??
        ChildTimeLimit(
          childProfileId: childProfileId,
          setterProfileId: '',
          setterRole: UserRole.parent,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
    return base.copyWith(
      dailyLimitEnabled: true,
      dailyLimitMinutes: device.effectiveDailyMinutes,
    );
  }
}

/// Changes whenever the controls are saved, for what shows what they hide:
/// watch it and read [LearnerRestrictions] after.
final parentalControlsRevisionProvider = Provider<int>((ref) {
  final revision = ParentalControlsService.revision;
  void changed() => ref.invalidateSelf();
  revision.addListener(changed);
  ref.onDispose(() => revision.removeListener(changed));
  return revision.value;
});
