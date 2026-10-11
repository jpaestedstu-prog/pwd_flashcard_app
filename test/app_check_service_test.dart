import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/distribution.dart';
import 'package:pwdpwdpwd/core/services/app_check_service.dart';

/// App Check is compiled in but off: Play Integrity and App Attest need paid
/// store accounts, and a website APK can never be attested. These rules keep
/// a website tablet from ever being asked for a token it cannot produce.
void main() {
  test('off unless the build asks for it', () {
    expect(AppCheckService.requested, isFalse);
    for (final d in Distribution.values) {
      expect(
        AppCheckService.shouldActivate(
          requested: false,
          distribution: d,
          debugBuild: false,
        ),
        isFalse,
        reason: d.name,
      );
    }
  });

  test('store builds attest when asked', () {
    for (final d in [Distribution.play, Distribution.appStore]) {
      expect(
        AppCheckService.shouldActivate(
          requested: true,
          distribution: d,
          debugBuild: false,
        ),
        isTrue,
        reason: d.name,
      );
    }
  });

  test('a released website APK never does, even when asked', () {
    expect(
      AppCheckService.shouldActivate(
        requested: true,
        distribution: Distribution.website,
        debugBuild: false,
      ),
      isFalse,
    );
    // A developer's debug build may try the flow with the debug provider.
    expect(
      AppCheckService.shouldActivate(
        requested: true,
        distribution: Distribution.website,
        debugBuild: true,
      ),
      isTrue,
    );
  });
}
