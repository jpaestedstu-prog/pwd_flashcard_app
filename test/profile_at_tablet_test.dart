import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// "View as student" makes the learner the active profile so the dashboard
/// shows their data. It used to count as the learner signing in: their time
/// limit started ticking, the tablet's alarms moved to them, and the
/// teacher's viewing was logged as the learner's study time.
UserProfile _p(String id, UserRole role) =>
    UserProfile(id: id, name: id, role: role, createdAt: DateTime(2026));

class _Notifier extends ProfileNotifier {
  _Notifier({this.viewing = false, this.educator});
  final bool viewing;
  final UserProfile? educator;

  @override
  bool get isViewingAsStudent => viewing;

  @override
  UserProfile? get savedEducatorProfile => educator;
}

void main() {
  final teacher = _p('rose', UserRole.teacher);
  final learner = _p('ana', UserRole.student);

  test('normally the active profile is the one at the tablet', () {
    expect(profileAtTablet(learner, _Notifier()), learner);
    expect(profileAtTablet(teacher, _Notifier()), teacher);
    expect(profileAtTablet(null, _Notifier()), isNull);
  });

  test("viewing a learner's dashboard, the educator is still at the tablet", () {
    expect(
      profileAtTablet(learner, _Notifier(viewing: true, educator: teacher)),
      teacher,
    );
  });

  test('coming back from the dashboard, it is the educator throughout', () {
    expect(
      profileAtTablet(teacher, _Notifier(viewing: true, educator: teacher)),
      teacher,
    );
  });

  test('a view with no saved educator falls back to the active profile', () {
    expect(profileAtTablet(learner, _Notifier(viewing: true)), learner);
  });
}
