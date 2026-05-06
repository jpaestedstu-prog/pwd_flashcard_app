import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/security/pin_auth_service.dart';

void main() {
  group('PinAuthService.hashPin', () {
    test('produces stable output for same (pin, salt)', () {
      final salt = PinAuthService.generateSalt();
      final a = PinAuthService.hashPin('1234', salt);
      final b = PinAuthService.hashPin('1234', salt);
      expect(a, equals(b));
    });

    test('produces different output for different salts (same pin)', () {
      final s1 = PinAuthService.generateSalt();
      final s2 = PinAuthService.generateSalt();
      final h1 = PinAuthService.hashPin('1234', s1);
      final h2 = PinAuthService.hashPin('1234', s2);
      expect(h1, isNot(equals(h2)));
    });

    test('produces different output for different pins (same salt)', () {
      final salt = PinAuthService.generateSalt();
      final h1 = PinAuthService.hashPin('1234', salt);
      final h2 = PinAuthService.hashPin('1235', salt);
      expect(h1, isNot(equals(h2)));
    });
  });

  group('PinAuthService.verifyPin', () {
    test('returns true for correct PIN', () {
      final salt = PinAuthService.generateSalt();
      final hash = PinAuthService.hashPin('1234', salt);
      expect(PinAuthService.verifyPin('1234', salt, hash), isTrue);
    });

    test('returns false for wrong PIN', () {
      final salt = PinAuthService.generateSalt();
      final hash = PinAuthService.hashPin('1234', salt);
      expect(PinAuthService.verifyPin('9999', salt, hash), isFalse);
    });

    test('returns false when hash is tampered', () {
      final salt = PinAuthService.generateSalt();
      final hash = PinAuthService.hashPin('1234', salt);
      final tampered = '${hash.substring(0, hash.length - 4)}AAAA';
      expect(PinAuthService.verifyPin('1234', salt, tampered), isFalse);
    });

    test('returns false when salt is swapped', () {
      final salt1 = PinAuthService.generateSalt();
      final salt2 = PinAuthService.generateSalt();
      final hash = PinAuthService.hashPin('1234', salt1);
      expect(PinAuthService.verifyPin('1234', salt2, hash), isFalse);
    });
  });

  group('PinAuthService.generateSalt', () {
    test('produces 1000 unique salts', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(PinAuthService.generateSalt());
      }
      expect(seen.length, 1000);
    });
  });

  group('PinAuthService.cooldownFor', () {
    test('matches the documented schedule', () {
      expect(PinAuthService.cooldownFor(0), Duration.zero);
      expect(PinAuthService.cooldownFor(1), Duration.zero);
      expect(PinAuthService.cooldownFor(2), Duration.zero);
      expect(PinAuthService.cooldownFor(3), Duration.zero);
      expect(PinAuthService.cooldownFor(4), Duration.zero);
      expect(PinAuthService.cooldownFor(5), const Duration(seconds: 30));
      expect(PinAuthService.cooldownFor(6), const Duration(minutes: 1));
      expect(PinAuthService.cooldownFor(7), const Duration(minutes: 5));
      expect(PinAuthService.cooldownFor(8), const Duration(minutes: 15));
      expect(PinAuthService.cooldownFor(9), const Duration(hours: 1));
      expect(PinAuthService.cooldownFor(20), const Duration(hours: 1));
    });
  });

  group('PinAuthService.checkLockout', () {
    final now = DateTime(2026, 5, 2, 12);

    test('null lockedUntil → allowed', () {
      final r = PinAuthService.checkLockout(0, null, now);
      expect(r.allowed, isTrue);
      expect(r.remaining, isNull);
    });

    test('lockedUntil in the past → allowed', () {
      final r = PinAuthService.checkLockout(
        5,
        now.subtract(const Duration(seconds: 1)),
        now,
      );
      expect(r.allowed, isTrue);
    });

    test('lockedUntil in the future → not allowed, remaining set', () {
      final r = PinAuthService.checkLockout(
        5,
        now.add(const Duration(seconds: 30)),
        now,
      );
      expect(r.allowed, isFalse);
      expect(r.remaining, const Duration(seconds: 30));
    });

    test('absurdly far future treated as clock skew → allowed', () {
      final r = PinAuthService.checkLockout(
        5,
        now.add(const Duration(days: 365)),
        now,
      );
      expect(r.allowed, isTrue);
    });
  });

  group('PinAuthService.generateRecoveryCode', () {
    test('produces 12 chars in XXXX-XXXX-XX format from safe alphabet', () {
      const allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      for (var i = 0; i < 100; i++) {
        final code = PinAuthService.generateRecoveryCode();
        expect(code.length, 12);
        expect(code[4], '-');
        expect(code[9], '-');
        for (var j = 0; j < code.length; j++) {
          if (j == 4 || j == 9) continue;
          expect(allowed.contains(code[j]), isTrue,
              reason: 'char "${code[j]}" at $j not in safe alphabet');
        }
      }
    });

    test('produces 1000 distinct codes (probabilistic)', () {
      final seen = <String>{};
      for (var i = 0; i < 1000; i++) {
        seen.add(PinAuthService.generateRecoveryCode());
      }
      expect(seen.length, greaterThan(995)); // ~50 bits of entropy
    });
  });

  group('PinAuthService.normaliseRecoveryCode', () {
    test('strips dashes, spaces, and uppercases', () {
      expect(PinAuthService.normaliseRecoveryCode('abcd-1234-ef'),
          'ABCD1234EF');
      expect(PinAuthService.normaliseRecoveryCode('ABCD 1234 EF'),
          'ABCD1234EF');
    });
  });

  group('PinAuthService.verifyRecoveryCode', () {
    test('matches regardless of dashes/case', () {
      final code = PinAuthService.generateRecoveryCode();
      final salt = PinAuthService.generateSalt();
      final hash = PinAuthService.hashRecoveryCode(code, salt);
      expect(PinAuthService.verifyRecoveryCode(code, salt, hash), isTrue);
      expect(
        PinAuthService.verifyRecoveryCode(code.replaceAll('-', ''), salt, hash),
        isTrue,
      );
      expect(
        PinAuthService.verifyRecoveryCode(code.toLowerCase(), salt, hash),
        isTrue,
      );
    });

    test('rejects wrong code', () {
      final code = PinAuthService.generateRecoveryCode();
      final other = PinAuthService.generateRecoveryCode();
      final salt = PinAuthService.generateSalt();
      final hash = PinAuthService.hashRecoveryCode(code, salt);
      expect(PinAuthService.verifyRecoveryCode(other, salt, hash), isFalse);
    });
  });

  group('PinAuthService.algorithmId', () {
    test('is the documented v1 string', () {
      expect(PinAuthService.algorithmId, 'pbkdf2-sha256-100000-v1');
    });
  });
}
