import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'pin_auth_service.dart';

/// Bundles a profile with the side-channel data that must be shown to the
/// user exactly once (the plaintext recovery code). Callers that ignore
/// [recoveryCode] are silently dropping the user's only chance to record it.
class PinApplyResult {
  final UserProfile profile;
  final String? recoveryCode;
  const PinApplyResult({required this.profile, this.recoveryCode});
}

/// Centralises PIN credential management. Every place that used to write
/// `profile.pin = "1234"` should route through here so no plaintext is ever
/// persisted again.
class PinCredentialHelper {
  /// Applies a new PIN to a profile. For teacher/parent roles, generates a
  /// fresh recovery code, hashes it, and returns the plaintext in the
  /// result so the caller can show it once. For students, recovery is via
  /// educator override — no code is generated.
  static PinApplyResult applyPin(UserProfile profile, String pin) {
    final salt = PinAuthService.generateSalt();
    final hash = PinAuthService.hashPin(pin, salt);

    String? recoveryCode;
    String? recoveryCodeHash;
    String? recoveryCodeSalt;
    if (profile.role == UserRole.teacher || profile.role == UserRole.parent) {
      recoveryCode = PinAuthService.generateRecoveryCode();
      recoveryCodeSalt = PinAuthService.generateSalt();
      recoveryCodeHash = PinAuthService.hashRecoveryCode(
        recoveryCode,
        recoveryCodeSalt,
      );
    }

    final updated = profile.copyWith(
      pin: () => null,
      pinHash: () => hash,
      pinSalt: () => salt,
      pinHashAlgorithm: () => PinAuthService.algorithmId,
      failedAttempts: 0,
      lockedUntil: () => null,
      recoveryCodeHash: () => recoveryCodeHash,
      recoveryCodeSalt: () => recoveryCodeSalt,
    );
    return PinApplyResult(profile: updated, recoveryCode: recoveryCode);
  }

  /// Removes PIN protection entirely, clearing every security field.
  static UserProfile clearPin(UserProfile profile) {
    return profile.copyWith(
      pin: () => null,
      pinHash: () => null,
      pinSalt: () => null,
      pinHashAlgorithm: () => null,
      failedAttempts: 0,
      lockedUntil: () => null,
      recoveryCodeHash: () => null,
      recoveryCodeSalt: () => null,
    );
  }

  /// Verifies a PIN against the profile's stored hash. Falls through to a
  /// constant-false answer for legacy unmigrated profiles (which shouldn't
  /// reach this codepath in normal flow — migration runs at startup).
  static bool verify(UserProfile profile, String pin) {
    final hash = profile.pinHash;
    final salt = profile.pinSalt;
    if (hash == null || salt == null) {
      // Defence-in-depth: if migration somehow didn't run, fall back to
      // plaintext so the user is not locked out — but never persist this.
      if (profile.pin != null) return profile.pin == pin;
      return false;
    }
    return PinAuthService.verifyPin(pin, salt, hash);
  }

  static bool verifyRecoveryCode(UserProfile profile, String code) {
    final hash = profile.recoveryCodeHash;
    final salt = profile.recoveryCodeSalt;
    if (hash == null || salt == null) return false;
    return PinAuthService.verifyRecoveryCode(code, salt, hash);
  }
}
