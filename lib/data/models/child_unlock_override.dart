import 'enums.dart';

/// A short-lived "grace window" granted to a child profile so the lock
/// screen stops triggering until [unlockedUntil].
///
/// Lives in the Firestore `child_unlock_overrides` collection, keyed by
/// [childProfileId] (one document per child) so the child's device can
/// `.snapshots()` it directly without a query.
///
/// Written by:
///   • The lock screen on PIN / recovery-code success — a 30-minute
///     grace so the child can keep going without the gate immediately
///     re-locking the same condition.
///   • The educator dashboards (Teacher classroom roster, Parent home
///     group roster) when an "Unlock Now" button is tapped — duration
///     picked by the educator (15 / 30 / 60 minutes).
///
/// Consumed by [lockStateProvider]: when [unlockedUntil] is in the
/// future, the provider short-circuits to `null` (no lock).
class ChildUnlockOverride {
  /// Profile id of the child this override applies to.
  final String childProfileId;

  /// Profile id of the educator (parent or teacher) who granted it.
  final String setterProfileId;

  /// Role of the educator — surfaced in the UI ("unlocked by teacher").
  final UserRole setterRole;

  /// Wall-clock moment after which the override no longer applies.
  final DateTime unlockedUntil;

  final DateTime createdAt;

  const ChildUnlockOverride({
    required this.childProfileId,
    required this.setterProfileId,
    required this.setterRole,
    required this.unlockedUntil,
    required this.createdAt,
  });

  /// True if [unlockedUntil] is still in the future relative to [now].
  bool isActiveAt(DateTime now) => unlockedUntil.isAfter(now);

  Map<String, dynamic> toJson() => {
        'child_profile_id': childProfileId,
        'setter_profile_id': setterProfileId,
        'setter_role': setterRole.index,
        'unlocked_until': unlockedUntil.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory ChildUnlockOverride.fromJson(Map<String, dynamic> json) {
    return ChildUnlockOverride(
      childProfileId: json['child_profile_id'] as String,
      setterProfileId: json['setter_profile_id'] as String? ?? '',
      setterRole: UserRole.values[(json['setter_role'] as int?) ?? 0],
      unlockedUntil:
          DateTime.tryParse(json['unlocked_until'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
