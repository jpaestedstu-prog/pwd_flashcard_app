// Firebase on a real device or simulator, without the UI:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/firebase_smoke_test.dart -d <device>
//
// Proves the platform's Firebase SDKs are linked and configured: the app
// initialises with its own options, signs in anonymously, and makes one
// server round-trip (a read of a document that does not exist, which the
// security rules allow any signed-in user). The anonymous account it made is
// then deleted, so test runs leave nothing behind in the project.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pwdpwdpwd/core/services/firebase_service.dart';
import 'package:pwdpwdpwd/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase connects, signs in and reads', (tester) async {
    await FirebaseService.init(options: DefaultFirebaseOptions.currentPlatform);
    expect(
      FirebaseService.isConfigured,
      isTrue,
      reason: 'Firebase did not start: ${FirebaseService.lastInitError}',
    );

    final credential = await FirebaseAuth.instance.signInAnonymously();
    final user = credential.user;
    expect(user, isNotNull);
    debugPrint('SMOKE signed in anonymously');

    try {
      final probe = await FirebaseFirestore.instance
          .doc('app_state/ci_connectivity_probe')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 30));
      debugPrint('SMOKE server read ok (exists: ${probe.exists})');
    } finally {
      await user!.delete();
      debugPrint('SMOKE anonymous account deleted');
    }
    expect(FirebaseAuth.instance.currentUser, isNull);
  });
}
