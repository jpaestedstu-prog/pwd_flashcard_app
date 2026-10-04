import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/providers/today_routine_provider.dart';

/// Whether a profile has My Day, answered from the profile itself. The code
/// reacting to a profile switch used to read routineFeatureProvider, which can
/// still hold the previous profile's answer then: a parent signing in straight
/// after a learner was taken for someone with My Day and took the learner's
/// reminders over (found on the tablet, Mommy after RoutineDeafKid6).
UserProfile _p(UserRole role, {bool guest = false}) => UserProfile(
      id: role.name,
      name: role.name,
      role: role,
      createdAt: DateTime(2026),
      isGuestPlayer: guest,
    );

void main() {
  test('Students and Children always have My Day', () {
    expect(routineFeatureOnFor(_p(UserRole.student), playerRoutineEnabled: false), isTrue);
    expect(routineFeatureOnFor(_p(UserRole.child), playerRoutineEnabled: false), isTrue);
  });

  test('a Player has it when their own setting says so', () {
    expect(routineFeatureOnFor(_p(UserRole.player), playerRoutineEnabled: true), isTrue);
    expect(routineFeatureOnFor(_p(UserRole.player), playerRoutineEnabled: false), isFalse);
  });

  test('educators, guests and nobody never do', () {
    expect(routineFeatureOnFor(_p(UserRole.teacher), playerRoutineEnabled: true), isFalse);
    expect(routineFeatureOnFor(_p(UserRole.parent), playerRoutineEnabled: true), isFalse);
    expect(
      routineFeatureOnFor(_p(UserRole.player, guest: true), playerRoutineEnabled: true),
      isFalse,
    );
    expect(routineFeatureOnFor(null, playerRoutineEnabled: true), isFalse);
  });
}
