import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/schedule_ownership.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Alarms and routine reminders belong to the learner who uses the device.
/// Found on the tablet: a child's 1:20 PM alarms vanished while a teacher was
/// signed in, and came back only when the child signed in again.
UserProfile _p(String id, UserRole role, {bool guest = false}) => UserProfile(
      id: id,
      name: id,
      role: role,
      createdAt: DateTime(2026),
      isGuestPlayer: guest,
    );

void main() {
  final ana = _p('ana', UserRole.student);
  final ben = _p('ben', UserRole.child);
  final rose = _p('rose', UserRole.teacher);
  final mom = _p('mom', UserRole.parent);
  final pia = _p('pia', UserRole.player);
  final guest = _p('guest', UserRole.player, guest: true);

  group('child alarms', () {
    test('a learner signing in schedules their alarms', () {
      expect(ScheduleOwnership.forAlarms(ana), ScheduleChange.start);
      expect(ScheduleOwnership.forAlarms(ben), ScheduleChange.start);
    });

    test('an educator, a Player or the profile picker leaves them alone', () {
      for (final p in [rose, mom, pia, guest, null]) {
        expect(ScheduleOwnership.forAlarms(p), ScheduleChange.keep, reason: '$p');
      }
    });
  });

  group('routine reminders', () {
    ScheduleChange change(UserProfile? next, {bool on = false, String? for_}) =>
        ScheduleOwnership.forRoutines(
          next: next,
          featureOn: on,
          scheduledFor: for_,
        );

    test('a profile with My Day on schedules its own', () {
      expect(change(ana, on: true, for_: 'ben'), ScheduleChange.start);
      expect(change(pia, on: true, for_: 'ana'), ScheduleChange.start);
    });

    test("an educator on screen keeps the learner's reminders", () {
      expect(change(rose, for_: 'ana'), ScheduleChange.keep);
      expect(change(mom, for_: 'ana'), ScheduleChange.keep);
    });

    test('the profile picker keeps them', () {
      expect(change(null, for_: 'ana'), ScheduleChange.keep);
    });

    test('a Player turning My Day off stops only their own', () {
      expect(change(pia, for_: 'pia'), ScheduleChange.stop);
      expect(change(pia, for_: 'ana'), ScheduleChange.keep);
    });

    test('a guest with nothing scheduled changes nothing', () {
      expect(change(guest), ScheduleChange.keep);
    });
  });
}
