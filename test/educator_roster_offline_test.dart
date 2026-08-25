import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Whose learners an educator sees when the network is gone.
///
/// The Firestore-backed roster is the truth online. Offline — or while the
/// fetch is in flight, or after it fails — the app falls back to local Hive,
/// and that fallback used to be "every student or child on this device". On a
/// shared classroom or family tablet that is somebody else's roster: Sir Kevin
/// listed 12 learners offline against 7 online, the extras being another
/// parent's children.
///
/// [localEducatorRoster] scopes the fallback to what local enrolment can
/// actually prove, and returns null only when this educator owns no group at
/// all, so a fresh single-device demo still shows something.
///
/// Plain `test()` — pure Hive reads, no widgets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teacher = 'teacher-1';
  const otherParent = 'parent-9';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('educator_roster_test');
    Hive.init(tempDir.path);
    for (final name in const [
      'profiles',
      'progress',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
    ]) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  (UserProfile, LearningProgress) learner(String id, String name, UserRole r) => (
    UserProfile(id: id, name: name, role: r, createdAt: DateTime(2026)),
    LearningProgress(profileId: id, lastActivityDate: DateTime(2026, 8)),
  );

  final everyoneOnTheTablet = [
    learner('s1', 'My Student', UserRole.student),
    learner('s2', 'Another Class Student', UserRole.student),
    learner('c1', 'My Child', UserRole.child),
    learner('c2', 'Another Family Child', UserRole.child),
  ];

  /// Seeds the classroom boxes directly. Raw JSON in the shape HiveService
  /// reads, so the fixture cannot drift from a save helper's defaults.
  Future<void> giveTeacherAClassWith(List<String> memberIds) async {
    await Hive.box('classrooms').put('class-1', {
      'id': 'class-1',
      'code': 'ABC123',
      'name': 'Grade 3',
      'teacher_id': teacher,
      'created_at': DateTime(2026, 8).toIso8601String(),
      'updated_at': DateTime(2026, 8).toIso8601String(),
    });
    for (final id in memberIds) {
      await Hive.box('classroom_members').put('class-1:$id', {
        'classroom_id': 'class-1',
        'profile_id': id,
        'display_name': id,
        'joined_at': DateTime(2026, 8).toIso8601String(),
      });
    }
  }

  Future<void> giveGroupTo(String ownerId, List<String> memberIds) async {
    await Hive.box('home_groups').put('group-$ownerId', {
      'id': 'group-$ownerId',
      'code': 'XYZ789',
      'name': 'Family',
      'owner_profile_id': ownerId,
      'created_at': DateTime(2026, 8).toIso8601String(),
      'updated_at': DateTime(2026, 8).toIso8601String(),
    });
    for (final id in memberIds) {
      await Hive.box('home_group_members').put('group-$ownerId:$id', {
        'home_group_id': 'group-$ownerId',
        'profile_id': id,
        'display_name': id,
        'joined_at': DateTime(2026, 8).toIso8601String(),
      });
    }
  }

  test('an educator with a class sees only their own members', () async {
    await giveTeacherAClassWith(['s1']);
    await giveGroupTo(otherParent, ['c2']);

    final roster = localEducatorRoster(teacher, everyoneOnTheTablet);

    expect(roster, isNotNull);
    expect(
      roster!.map((r) => r.$1.id),
      ['s1'],
      reason: 'the other three are on this tablet but not in this class',
    );
  });

  test('another family\'s children never leak in', () async {
    await giveTeacherAClassWith(['s1']);
    await giveGroupTo(otherParent, ['c1', 'c2']);

    final ids = localEducatorRoster(
      teacher,
      everyoneOnTheTablet,
    )!.map((r) => r.$1.id).toSet();

    expect(ids.contains('c1'), isFalse);
    expect(ids.contains('c2'), isFalse);
  });

  test('a parent sees their home group members', () async {
    await giveGroupTo(otherParent, ['c1', 'c2']);

    final ids = localEducatorRoster(
      otherParent,
      everyoneOnTheTablet,
    )!.map((r) => r.$1.id).toSet();

    expect(ids, {'c1', 'c2'});
  });

  test('classroom and home group members are unioned', () async {
    // A teacher who is also a parent, or a parent running a study group.
    await giveTeacherAClassWith(['s1', 's2']);
    await giveGroupTo(teacher, ['c1']);

    final ids = localEducatorRoster(
      teacher,
      everyoneOnTheTablet,
    )!.map((r) => r.$1.id).toSet();

    expect(ids, {'s1', 's2', 'c1'});
  });

  test('a member with no local profile is simply absent', () async {
    // A student who joined from their own device: the membership row may not
    // be on this tablet at all, and even if it is there is no profile to show.
    // Under-reporting them is the safer failure — we cannot prove the
    // enrolment offline, and inventing a roster entry is worse.
    await giveTeacherAClassWith(['s1', 'joined-elsewhere']);

    final ids = localEducatorRoster(
      teacher,
      everyoneOnTheTablet,
    )!.map((r) => r.$1.id).toSet();

    expect(ids, {'s1'});
  });

  test('an educator who owns no group gets the demo fallback', () async {
    // Null, not empty: the caller then shows every local learner so a fresh
    // single-device install is not a blank screen.
    expect(localEducatorRoster(teacher, everyoneOnTheTablet), isNull);
  });

  test('an owned but empty class is a real answer, not a fallback', () async {
    // The educator has a class and nobody has joined yet. That is genuinely an
    // empty roster — falling back to every learner on the tablet here is what
    // produced the phantom 12.
    await giveTeacherAClassWith(const []);

    final roster = localEducatorRoster(teacher, everyoneOnTheTablet);

    expect(roster, isNotNull);
    expect(roster, isEmpty);
  });
}
