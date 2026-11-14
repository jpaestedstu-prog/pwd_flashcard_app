import '../../../data/models/enums.dart';
import '../../live_session/models/live_session_models.dart';

/// One class (Teacher) or home group (Parent) the educator can cast for.
///
/// The groups are the educator's own: each was created with an accessibility
/// audience ("Hearing Impairment", "Cognitive/Learning", "Multiple
/// Disabilities", …) and every learner who joined with its code belongs to it.
/// That audience is shown next to the name in the picker, so "Hearing Class"
/// and "Hearing Impairment" read as the same thing they are.
class CastGroupOption {
  const CastGroupOption({
    required this.id,
    required this.name,
    required this.kind,
    this.accessibility = DisabilityType.none,
  });

  /// The classroom id or home-group id — also the live session's key.
  final String id;
  final String name;
  final LiveSessionOwnerKind kind;
  final DisabilityType accessibility;

  @override
  bool operator ==(Object other) =>
      other is CastGroupOption &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.accessibility == accessibility;

  @override
  int get hashCode => Object.hash(id, name, kind, accessibility);
}

/// Which of the educator's classes / home groups a TV cast is for.
///
/// Either **all** of them — one combined choice, stored as a flag rather than
/// as a list of ids, so a class created next week is included without anyone
/// having to come back and tick it — or an explicit set of group ids.
///
/// The picker behaves like a row of filter chips:
///   * picking "All" clears the individual picks;
///   * picking one group while "All" is on narrows the cast to that group;
///   * picking further groups adds them;
///   * once every group is picked one by one the selection folds back into
///     "All" ([normalized]), so the two ways of saying "everyone" can never
///     disagree;
///   * un-picking the last group returns to "All" — there is no empty
///     selection, because a cast for nobody has nothing to show.
///
/// Immutable; the notifier persists it per educator profile.
class CastGroupSelection {
  const CastGroupSelection.all() : all = true, ids = const {};

  const CastGroupSelection.only(this.ids) : all = false;

  /// True when the cast is for every class / group the educator has.
  final bool all;

  /// The picked group ids when [all] is false. Ignored when [all] is true.
  final Set<String> ids;

  /// Whether [groupId] is part of this cast.
  bool includes(String groupId) => all || ids.contains(groupId);

  /// The groups in [options] this selection covers, in [options] order.
  ///
  /// Ids that no longer exist (a class deleted since it was picked) are
  /// skipped; if nothing picked survives, the cast falls back to every group
  /// rather than to nobody.
  List<CastGroupOption> resolve(List<CastGroupOption> options) {
    if (all) return List.unmodifiable(options);
    final picked = [
      for (final o in options)
        if (ids.contains(o.id)) o,
    ];
    return List.unmodifiable(picked.isEmpty ? options : picked);
  }

  /// Whether this selection, against [options], means every group.
  bool coversAll(List<CastGroupOption> options) =>
      all || resolve(options).length == options.length;

  /// The same selection with "every group picked one by one" folded into
  /// [all], and picks for groups that no longer exist dropped.
  CastGroupSelection normalized(List<CastGroupOption> options) {
    if (all) return this;
    final live = {
      for (final o in options)
        if (ids.contains(o.id)) o.id,
    };
    if (live.isEmpty || live.length == options.length) {
      return const CastGroupSelection.all();
    }
    return CastGroupSelection.only(live);
  }

  /// The selection after the educator taps [groupId] in the picker.
  CastGroupSelection toggle(String groupId, List<CastGroupOption> options) {
    if (all) {
      // Narrowing from "everyone" to the one group that was tapped.
      return CastGroupSelection.only({groupId}).normalized(options);
    }
    final next = {...ids};
    if (!next.remove(groupId)) next.add(groupId);
    return CastGroupSelection.only(next).normalized(options);
  }

  Map<String, dynamic> toJson() => {
    'all': all,
    if (!all) 'ids': ids.toList()..sort(),
  };

  /// Reads a stored selection. Anything unreadable means "all", the default —
  /// a corrupt preference must never leave a cast showing nobody.
  factory CastGroupSelection.fromJson(Object? json) {
    if (json is! Map) return const CastGroupSelection.all();
    if (json['all'] != false) return const CastGroupSelection.all();
    final raw = json['ids'];
    if (raw is! List) return const CastGroupSelection.all();
    final ids = {
      for (final v in raw)
        if (v is String && v.isNotEmpty) v,
    };
    return ids.isEmpty
        ? const CastGroupSelection.all()
        : CastGroupSelection.only(ids);
  }

  @override
  bool operator ==(Object other) =>
      other is CastGroupSelection &&
      other.all == all &&
      (all ||
          (other.ids.length == ids.length && other.ids.containsAll(ids)));

  @override
  int get hashCode =>
      all ? true.hashCode : Object.hashAllUnordered(ids);

  @override
  String toString() => all ? 'CastGroupSelection.all' : 'CastGroupSelection$ids';
}
