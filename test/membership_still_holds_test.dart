import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/providers/membership_watcher_provider.dart';

/// A learner is signed out of their class or home group only when the
/// SERVER says their membership row is gone.
///
/// The watchers mapped every snapshot to `docs.isNotEmpty`, so an offline
/// launch whose cache lacked the row (a profile set up on another tablet, or
/// a cache that had dropped it) read as "removed by the teacher": the learner
/// was signed out and their class cleared. A cache-only snapshot proves
/// nothing.
void main() {
  test('rows present: still a member, wherever the snapshot came from', () {
    expect(membershipStillHolds(hasRows: true, fromCache: false), isTrue);
    expect(membershipStillHolds(hasRows: true, fromCache: true), isTrue);
  });

  test('no rows from the cache only (offline): NOT a removal', () {
    expect(membershipStillHolds(hasRows: false, fromCache: true), isTrue);
  });

  test('no rows from the server: the educator removed them', () {
    expect(membershipStillHolds(hasRows: false, fromCache: false), isFalse);
  });
}
