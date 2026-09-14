import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/educator_push_service.dart';

/// Where the "needs help" push is sent: one record per educator profile and
/// device, in that device's language.
void main() {
  test('one educator on one device is one stable record', () {
    final a = EducatorPushService.docIdFor('rose', 'token-1');
    expect(EducatorPushService.docIdFor('rose', 'token-1'), a);
    expect(a, startsWith('rose_'));
    expect(EducatorPushService.docIdFor('rose', 'token-2'), isNot(a));
    expect(EducatorPushService.docIdFor('mom', 'token-1'), isNot(a));
    // Tokens are long; the id stays a short, safe path segment.
    expect(a.length, lessThan(60));
    expect(a, isNot(contains('/')));
  });

  test('the record names the educator, the owner and the language', () {
    final record = EducatorPushService.recordFor(
      profileId: 'rose',
      token: 'token-1',
      ownerUid: 'uid-9',
      filipino: true,
    );
    expect(record['profile_id'], 'rose');
    expect(record['token'], 'token-1');
    expect(record['owner_uid'], 'uid-9');
    expect(record['locale'], 'fil');
    expect(
      EducatorPushService.recordFor(
        profileId: 'rose',
        token: 't',
        ownerUid: 'u',
        filipino: false,
      )['locale'],
      'en',
    );
  });
}
