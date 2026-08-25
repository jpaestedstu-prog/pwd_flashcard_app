import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';

/// Which failures are allowed to interrupt someone.
///
/// The global snackbar exists for problems a user can act on. Background
/// mirrors of data that is already saved locally are not that: offline they
/// fail on a timer and put "Operation timed out. Please try again." in front of
/// a teacher who asked for nothing. `ProfileDirectoryService.upsert` republishes
/// the public username entry on *every* profile save, so it fired on a plain
/// sign-in.
///
/// The failure mode of the silent list is a typo — a string no call site ever
/// passes silences nothing while looking handled — so these assert the exact
/// literals the services report with.
void main() {
  group('background mirrors are silent', () {
    test('the messaging directory upsert does not interrupt', () {
      expect(
        ErrorHandler.isSilentSource('ProfileDirectoryService.upsert'),
        isTrue,
      );
    });

    test('the directory cache top-up does not interrupt', () {
      // Its own doc comment promises it "never throws and never blocks the
      // caller" — routing it to the snackbar broke that promise.
      expect(
        ErrorHandler.isSilentSource('ProfileDirectoryService._refreshCache'),
        isTrue,
      );
    });
  });

  group('user-initiated failures still surface', () {
    test('a username search that fails is the user\'s to see', () {
      // Somebody typed a handle and pressed go. Silence here would look like
      // the app ignoring them.
      expect(
        ErrorHandler.isSilentSource('ProfileDirectoryService.lookupByUsername'),
        isFalse,
      );
      expect(
        ErrorHandler.isSilentSource('ProfileDirectoryService.isUsernameTaken'),
        isFalse,
      );
    });

    test('an unknown source is never silenced by accident', () {
      expect(ErrorHandler.isSilentSource('SomeNewService.doThing'), isFalse);
      expect(ErrorHandler.isSilentSource(''), isFalse);
    });
  });
}
