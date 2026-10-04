import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';

/// "Reset All Data" erases every profile on the tablet, not just the signed-in
/// one. It used to sit at the foot of every profile's Settings — one mis-tap
/// (or gaze dwell) by a learner on the shared study tablet would have wiped
/// the whole class.
UserProfile _p(UserRole role, {bool guest = false}) => UserProfile(
      id: role.name,
      name: role.name,
      role: role,
      createdAt: DateTime(2026),
      isGuestPlayer: guest,
    );

void main() {
  test('Teachers and Parents can reset the tablet', () {
    expect(canResetAllData(_p(UserRole.teacher)), isTrue);
    expect(canResetAllData(_p(UserRole.parent)), isTrue);
  });

  test('learners, Players, guests and nobody cannot', () {
    expect(canResetAllData(_p(UserRole.student)), isFalse);
    expect(canResetAllData(_p(UserRole.child)), isFalse);
    expect(canResetAllData(_p(UserRole.player)), isFalse);
    expect(canResetAllData(_p(UserRole.player, guest: true)), isFalse);
    expect(canResetAllData(null), isFalse);
  });
}
