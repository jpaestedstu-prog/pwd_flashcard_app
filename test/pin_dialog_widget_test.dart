import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/security/pin_auth_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Sets up a minimal in-memory Hive with a single PIN-protected profile.
Future<UserProfile> _seedHashedProfile({
  required String pin,
  String id = 'p1',
}) async {
  final salt = PinAuthService.generateSalt();
  final hash = PinAuthService.hashPin(pin, salt);
  final profile = UserProfile(
    id: id,
    name: 'Test',
    role: UserRole.student,
    createdAt: DateTime(2026),
    pinHash: hash,
    pinSalt: salt,
    pinHashAlgorithm: PinAuthService.algorithmId,
  );
  await HiveService.saveProfile(profile);
  return profile;
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/pin_dialog');
    if (!Hive.isBoxOpen('profiles')) await Hive.openBox('profiles');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
  });

  setUp(() async {
    await Hive.box('profiles').clear();
    await Hive.box('settings').clear();
    await Hive.box('progress').clear();
  });

  group('Lockout integration with PinAuthService', () {
    test('after 5 failed attempts, cooldown of 30s applies', () async {
      final p = await _seedHashedProfile(pin: '1234');

      for (var i = 1; i <= 5; i++) {
        final lockedUntil = i >= 5
            ? DateTime.now().add(PinAuthService.cooldownFor(i))
            : null;
        await HiveService.bumpFailedAttempts(p.id, lockedUntil);
      }

      final after = HiveService.getProfileById(p.id)!;
      expect(after.failedAttempts, 5);
      expect(after.lockedUntil, isNotNull);

      final r = PinAuthService.checkLockout(
        after.failedAttempts,
        after.lockedUntil,
        DateTime.now(),
      );
      expect(r.allowed, isFalse);
      expect(r.remaining, isNotNull);
      expect(r.remaining!.inSeconds, lessThanOrEqualTo(30));
    });

    test('clearFailedAttempts resets counter and lockout', () async {
      final p = await _seedHashedProfile(pin: '1234');
      final lockedUntil =
          DateTime.now().add(const Duration(minutes: 15));
      await HiveService.bumpFailedAttempts(p.id, lockedUntil);
      await HiveService.bumpFailedAttempts(p.id, lockedUntil);

      await HiveService.clearFailedAttempts(p.id);

      final after = HiveService.getProfileById(p.id)!;
      expect(after.failedAttempts, 0);
      expect(after.lockedUntil, isNull);
    });
  });

  group('PinCredentialHelper end-to-end via Hive', () {
    // Plain test() rather than testWidgets(): the body only exercises
    // PinAuthService/HiveService and awaits a real Hive write. Under
    // testWidgets's FakeAsync zone those timers never fire and the test
    // hangs until the 10-minute timeout.
    test('saved profile verifies with correct PIN, rejects wrong PIN',
        () async {
      final p = await _seedHashedProfile(pin: '1234');
      final loaded = HiveService.getProfileById(p.id)!;

      expect(
        PinAuthService.verifyPin('1234', loaded.pinSalt!, loaded.pinHash!),
        isTrue,
      );
      expect(
        PinAuthService.verifyPin('9999', loaded.pinSalt!, loaded.pinHash!),
        isFalse,
      );
    });
  });

  test('teacher PIN setup persists recovery code hash + salt', () async {
    final code = PinAuthService.generateRecoveryCode();
    final salt = PinAuthService.generateSalt();
    final hash = PinAuthService.hashRecoveryCode(code, salt);
    final pinSalt = PinAuthService.generateSalt();
    final pinHash = PinAuthService.hashPin('1111', pinSalt);

    final teacher = UserProfile(
      id: 't1',
      name: 'Teacher',
      role: UserRole.teacher,
      createdAt: DateTime(2026),
      pinHash: pinHash,
      pinSalt: pinSalt,
      pinHashAlgorithm: PinAuthService.algorithmId,
      recoveryCodeHash: hash,
      recoveryCodeSalt: salt,
    );
    await HiveService.saveProfile(teacher);

    final loaded = HiveService.getProfileById(teacher.id)!;
    expect(
      PinAuthService.verifyRecoveryCode(
        code,
        loaded.recoveryCodeSalt!,
        loaded.recoveryCodeHash!,
      ),
      isTrue,
    );

    // Lowercase + dashes-stripped variants must still verify.
    expect(
      PinAuthService.verifyRecoveryCode(
        code.toLowerCase(),
        loaded.recoveryCodeSalt!,
        loaded.recoveryCodeHash!,
      ),
      isTrue,
    );
  });
}
