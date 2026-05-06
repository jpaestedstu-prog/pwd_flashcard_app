import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/security/pin_auth_service.dart';
import 'package:pwdpwdpwd/core/security/pin_migration.dart';

Future<void> _initHive(String path) async {
  Hive.init(path);
  if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
  if (!Hive.isBoxOpen('profiles')) await Hive.openBox('profiles');
}

Future<void> _resetHive() async {
  await Hive.deleteBoxFromDisk('settings');
  await Hive.deleteBoxFromDisk('profiles');
  await Hive.openBox('settings');
  await Hive.openBox('profiles');
}

Map<String, dynamic> _legacyProfile({
  required String id,
  String? pin,
  int role = 0, // student
}) {
  return {
    'id': id,
    'name': 'Test $id',
    'role': role,
    'avatarIndex': 0,
    'createdAt': DateTime(2026).toIso8601String(),
    'disabilityType': 0,
    'pin': pin,
    'gradeLevel': null,
    'section': null,
    'birthDate': null,
    'tags': const <String>[],
    'classroomId': null,
    'isGuestPlayer': false,
  };
}

void main() {
  setUpAll(() async {
    await _initHive('./build/test_cache/pin_migration');
  });

  setUp(() async {
    await _resetHive();
  });

  test('migrates a plaintext PIN into salted PBKDF2 hash', () async {
    await Hive.box('profiles').put('profiles', [
      _legacyProfile(id: 'p1', pin: '1234'),
    ]);

    await PinMigration.runIfNeeded();

    final profiles = (Hive.box('profiles').get('profiles') as List)
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final p = profiles.single;

    expect(p['pin'], isNull, reason: 'plaintext should be wiped');
    expect(p['pinHash'], isNotNull);
    expect(p['pinSalt'], isNotNull);
    expect(p['pinHashAlgorithm'], PinAuthService.algorithmId);
    expect(p['failedAttempts'], 0);

    expect(
      PinAuthService.verifyPin(
        '1234',
        p['pinSalt'] as String,
        p['pinHash'] as String,
      ),
      isTrue,
      reason: 'original PIN must still verify post-migration',
    );
  });

  test('is idempotent — running twice produces identical state', () async {
    await Hive.box('profiles').put('profiles', [
      _legacyProfile(id: 'p1', pin: '1234'),
      _legacyProfile(id: 'p2', pin: '9999'),
    ]);

    await PinMigration.runIfNeeded();
    final first = List<Map<String, dynamic>>.from(
      (Hive.box('profiles').get('profiles') as List)
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    await PinMigration.runIfNeeded();
    final second = List<Map<String, dynamic>>.from(
      (Hive.box('profiles').get('profiles') as List)
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    expect(second.length, first.length);
    for (var i = 0; i < first.length; i++) {
      expect(second[i]['pinHash'], first[i]['pinHash']);
      expect(second[i]['pinSalt'], first[i]['pinSalt']);
    }
  });

  test('leaves no-PIN profiles untouched', () async {
    await Hive.box('profiles').put('profiles', [
      _legacyProfile(id: 'p1'),
    ]);

    await PinMigration.runIfNeeded();

    final p = ((Hive.box('profiles').get('profiles') as List).first as Map)
        .cast<String, dynamic>();
    expect(p['pin'], isNull);
    expect(p['pinHash'], isNull);
    expect(p['pinSalt'], isNull);
  });

  test('skips malformed PIN (length != 4) without crashing', () async {
    await Hive.box('profiles').put('profiles', [
      _legacyProfile(id: 'p1', pin: '12'),
    ]);

    await PinMigration.runIfNeeded();

    final p = ((Hive.box('profiles').get('profiles') as List).first as Map)
        .cast<String, dynamic>();
    expect(p['pinHash'], isNull, reason: 'malformed PIN should not be hashed');
    expect(p['pin'], '12', reason: 'left as-is for the user to fix');
  });

  test('sets the migration flag so subsequent runs short-circuit', () async {
    await Hive.box('profiles').put('profiles', [
      _legacyProfile(id: 'p1', pin: '1234'),
    ]);

    await PinMigration.runIfNeeded();

    expect(Hive.box('settings').get('pin_migration_v1_done'), isTrue);
  });

  test('per-profile guard skips already-hashed entries', () async {
    final salt = PinAuthService.generateSalt();
    final hash = PinAuthService.hashPin('5555', salt);
    await Hive.box('profiles').put('profiles', [
      {
        ..._legacyProfile(id: 'p1'),
        'pinHash': hash,
        'pinSalt': salt,
        'pinHashAlgorithm': PinAuthService.algorithmId,
      },
    ]);

    await PinMigration.runIfNeeded();

    final p = ((Hive.box('profiles').get('profiles') as List).first as Map)
        .cast<String, dynamic>();
    expect(p['pinHash'], hash);
    expect(p['pinSalt'], salt);
  });
}
