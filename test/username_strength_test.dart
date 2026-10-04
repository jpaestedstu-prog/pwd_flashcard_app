import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/security/username_migration.dart';
import 'package:pwdpwdpwd/features/messaging/services/username_generator.dart';

/// Every messaging handle is a public directory entry naming its learner and
/// their disability. Four digits after the name left 10,000 handles per first
/// name — few enough for a stranger to try them all — so since 1.2.3 handles
/// carry six, and older ones are replaced on each owner's tablet.
void main() {
  test('new handles end in six digits', () {
    for (var i = 0; i < 200; i++) {
      final h = UsernameGenerator.generateHandle('Maria');
      expect(h, matches(RegExp(r'^maria-\d{6}$')), reason: h);
    }
  });

  test('the suffix is zero-padded to six digits', () {
    for (var i = 0; i < 500; i++) {
      expect(UsernameGenerator.suffix(), matches(RegExp(r'^\d{6}$')));
    }
  });

  test('four-digit handles are the ones the migration replaces', () {
    expect(UsernameMigration.hasWeakHandle('maria-1947'), isTrue);
    expect(UsernameMigration.hasWeakHandle('user-0042'), isTrue);
  });

  test('six-digit, fallback and missing handles are left alone', () {
    expect(UsernameMigration.hasWeakHandle('maria-194735'), isFalse);
    // The UUID fallback after repeated collisions: eight hex characters.
    expect(UsernameMigration.hasWeakHandle('maria-1a2b3c4d'), isFalse);
    expect(UsernameMigration.hasWeakHandle('maria-12345678'), isFalse);
    expect(UsernameMigration.hasWeakHandle(null), isFalse);
    expect(UsernameMigration.hasWeakHandle(''), isFalse);
  });
}
