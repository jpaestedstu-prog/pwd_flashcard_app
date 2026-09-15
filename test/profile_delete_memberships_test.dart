import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';

/// Deleting a learner removes them from every class and family group this
/// device knows about.
///
/// Found on the NDL W09: two learners deleted on the tablet kept appearing in
/// their teacher's roster ("No routine yet — set one up"), because the rows
/// that put them in the class were never removed — neither the teacher's
/// local copy nor, on this project's rules, the cloud one. The cloud delete is
/// exercised on the device; this covers the local half without a network.
void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/profile_delete_memberships');
    for (final name in const ['classroom_members', 'home_group_members']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  test('every class and family-group row naming the profile goes, and only '
      'those', () async {
    final classes = Hive.box('classroom_members');
    final groups = Hive.box('home_group_members');
    await classes.put('class-1:copykid', {'profile_id': 'copykid'});
    await classes.put('class-2:copykid', {'profile_id': 'copykid'});
    await classes.put('class-1:ana', {'profile_id': 'ana'});
    await groups.put('home-1:copykid', {'profile_id': 'copykid'});
    // Ends in the same letters but is somebody else.
    await groups.put('home-1:notcopykid', {'profile_id': 'notcopykid'});

    await HiveService.removeMembershipsLocal('copykid');

    expect(classes.keys.toSet(), {'class-1:ana'});
    expect(groups.keys.toSet(), {'home-1:notcopykid'});
  });

  test('a profile in no group changes nothing', () async {
    final classes = Hive.box('classroom_members');
    final before = classes.keys.toSet();
    await HiveService.removeMembershipsLocal('nobody');
    expect(classes.keys.toSet(), before);
  });
}
