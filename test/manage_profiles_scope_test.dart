import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/student_profile_list_screen.dart';

/// Until "Manage Profiles" existed, **no profile could ever be deleted from
/// inside the app**: the only delete UI lived on an orphan route nothing
/// navigated to, and it listed `isEnrollableLearner` only — so a Teacher or
/// Parent profile had no delete path at any level of the UI.
///
/// A pure list function (rather than pumping the screen) so the two rules that
/// actually carry risk are pinned down without Hive in the loop.

UserProfile _profile(
  String id, {
  required UserRole role,
  bool guest = false,
  DateTime? createdAt,
}) =>
    UserProfile(
      id: id,
      name: id,
      role: role,
      createdAt: createdAt ?? DateTime(2026),
      isGuestPlayer: guest,
    );

void main() {
  group('deviceScopedProfiles', () {
    test('includes educators — the whole point of the screen', () {
      final result = deviceScopedProfiles([
        _profile('teacher', role: UserRole.teacher),
        _profile('parent', role: UserRole.parent),
        _profile('student', role: UserRole.student),
      ], 'someone-else');

      expect(
        result.map((p) => p.id),
        containsAll(<String>['teacher', 'parent', 'student']),
        reason: 'educators were filtered out before, which is exactly why the '
            'test teacher profile could never be removed',
      );
    });

    test('never lists the signed-in profile', () {
      final result = deviceScopedProfiles([
        _profile('active-one', role: UserRole.parent),
        _profile('other', role: UserRole.student),
      ], 'active-one');

      expect(result.map((p) => p.id), ['other']);
      expect(
        result.any((p) => p.id == 'active-one'),
        isFalse,
        reason: 'deleting the profile in use would pull the session out from '
            'under the running app',
      );
    });

    test('omits the guest profile, which the app recreates on demand', () {
      final result = deviceScopedProfiles([
        _profile('guest', role: UserRole.student, guest: true),
        _profile('real', role: UserRole.student),
      ], null);

      expect(result.map((p) => p.id), ['real']);
    });

    test('newest first, so freshly made test profiles surface at the top', () {
      final result = deviceScopedProfiles([
        _profile('older', role: UserRole.student, createdAt: DateTime(2026)),
        _profile('newer', role: UserRole.student, createdAt: DateTime(2026, 8)),
      ], null);

      expect(result.map((p) => p.id), ['newer', 'older']);
    });

    test('a null active id (profile picker) still returns everyone', () {
      final result = deviceScopedProfiles([
        _profile('a', role: UserRole.teacher),
        _profile('b', role: UserRole.student),
      ], null);

      expect(result, hasLength(2));
    });
  });
}
