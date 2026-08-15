import '../../data/models/child_time_limit.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'guardian_address.dart';

/// Who the child is being asked to hand the device to, and how to address
/// them.
///
/// Extracted so the lock screen and the "nearly time" warning cannot drift
/// apart: a learner warned to hand the tablet to "Teacher Kevin" must not
/// then be locked with a screen that says "Sir".
class HandoffTarget {
  /// The name or honorific to use in the message.
  final String address;

  /// Whose rule this is. Chooses "give" vs "return" in the wording.
  final UserRole setterRole;

  /// Which artwork to show, or null when the educator's avatar isn't one of
  /// the four gendered ones.
  ///
  /// Deliberately independent of [address]: an educator who calls themselves
  /// "Teacher Ana" still has a Female-Teacher avatar, so the child sees the
  /// Ma'am picture *and* reads her name. The picture answers "who?" for a
  /// learner who cannot read the name.
  final HandoffFigure? figure;

  const HandoffTarget({
    required this.address,
    required this.setterRole,
    this.figure,
  });

  /// Resolves the target from whatever the child's device actually knows.
  ///
  /// Order, most to least authoritative:
  ///   1. The educator's free-text preferred name on the limit document.
  ///   2. The honorific stamped on that document at save time.
  ///   3. A live derivation from the single linked educator's avatar —
  ///      covers documents written before the hand-off feature existed.
  ///   4. A generic fallback.
  ///
  /// [alarmSetterRole] is the role from an `AlarmTriggered` lock reason; it
  /// only matters when no limit document exists, which is possible when an
  /// alarm is the only rule configured.
  static HandoffTarget resolve({
    required ChildTimeLimit? limit,
    required List<UserProfile> educators,
    required bool filipino,
    UserRole? alarmSetterRole,
  }) {
    final role = _setterRole(
      limit: limit,
      educators: educators,
      alarmSetterRole: alarmSetterRole,
    );

    var stamped = limit?.guardianHonorific ?? '';
    // The live educator profile is the better source for the *picture*
    // when it's available, because the avatar is unambiguous while a
    // stamped string has been through two serialisation hops.
    HandoffFigure? figure;
    if (educators.length == 1) {
      final ed = educators.first;
      figure = GuardianAddress.figureFor(
        role: ed.role,
        avatarIndex: ed.avatarIndex,
      );
      if (stamped.isEmpty) {
        stamped = filipino
            ? GuardianAddress.honorificForFilipino(
                role: ed.role,
                avatarIndex: ed.avatarIndex,
              )
            : GuardianAddress.honorificFor(
                role: ed.role,
                avatarIndex: ed.avatarIndex,
              );
      }
    }
    figure ??= GuardianAddress.figureFromHonorific(stamped);

    return HandoffTarget(
      address: GuardianAddress.resolve(
        preferredName: limit?.guardianPreferredName ?? '',
        stampedHonorific: stamped,
        role: role,
      ),
      setterRole: role,
      figure: figure,
    );
  }

  static UserRole _setterRole({
    required ChildTimeLimit? limit,
    required List<UserProfile> educators,
    required UserRole? alarmSetterRole,
  }) {
    if (limit != null && limit.setterProfileId.isNotEmpty) {
      return limit.setterRole;
    }
    if (alarmSetterRole != null) return alarmSetterRole;
    if (educators.length == 1) return educators.first.role;
    return UserRole.parent;
  }
}
