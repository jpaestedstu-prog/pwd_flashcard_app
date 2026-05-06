import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PinAuthService {
  static const String algorithmId = 'pbkdf2-sha256-100000-v1';
  static const int _iterations = 100000;
  static const int _derivedKeyLength = 32;
  static const int _saltLengthBytes = 16;

  static const String _recoveryAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final Random _secureRandom = Random.secure();

  static String generateSalt({int bytes = _saltLengthBytes}) {
    final raw = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      raw[i] = _secureRandom.nextInt(256);
    }
    return base64Encode(raw);
  }

  static String hashPin(String pin, String saltB64) {
    final salt = base64Decode(saltB64);
    final derived = _pbkdf2Sha256(
      utf8.encode(pin),
      salt,
      _iterations,
      _derivedKeyLength,
    );
    return base64Encode(derived);
  }

  static bool verifyPin(String pin, String saltB64, String expectedHashB64) {
    final candidate = base64Decode(hashPin(pin, saltB64));
    final expected = base64Decode(expectedHashB64);
    return _constantTimeEquals(candidate, expected);
  }

  /// Generates a 10-character recovery code in `XXXX-XXXX-XX` format using
  /// an unambiguous alphabet (no 0/O/1/I) for easy transcription.
  static String generateRecoveryCode() {
    final buf = StringBuffer();
    for (var i = 0; i < 10; i++) {
      buf.write(_recoveryAlphabet[_secureRandom.nextInt(_recoveryAlphabet.length)]);
    }
    final raw = buf.toString();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 10)}';
  }

  /// Normalises user input (strip dashes, uppercase) before verification so
  /// hyphens and casing don't cause false negatives.
  static String normaliseRecoveryCode(String input) {
    return input.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  }

  static String hashRecoveryCode(String code, String saltB64) {
    return hashPin(normaliseRecoveryCode(code), saltB64);
  }

  static bool verifyRecoveryCode(
    String code,
    String saltB64,
    String expectedHashB64,
  ) {
    return verifyPin(normaliseRecoveryCode(code), saltB64, expectedHashB64);
  }

  /// Cooldown schedule keyed on cumulative failed attempts.
  ///   1–4 fails → no cooldown
  ///   5        → 30s
  ///   6        → 1m
  ///   7        → 5m
  ///   8        → 15m
  ///   9+       → 1h (capped — frustrates real users without
  ///              meaningful security gain on a 4-digit space)
  static Duration cooldownFor(int failedAttempts) {
    if (failedAttempts < 5) return Duration.zero;
    switch (failedAttempts) {
      case 5:
        return const Duration(seconds: 30);
      case 6:
        return const Duration(minutes: 1);
      case 7:
        return const Duration(minutes: 5);
      case 8:
        return const Duration(minutes: 15);
      default:
        return const Duration(hours: 1);
    }
  }

  /// Returns `(allowed, remaining)` — whether entry is permitted right now,
  /// and if not, how long until the lockout ends.
  static ({bool allowed, Duration? remaining}) checkLockout(
    int failedAttempts,
    DateTime? lockedUntil,
    DateTime now,
  ) {
    if (lockedUntil == null) return (allowed: true, remaining: null);
    // Belt-and-suspenders: a clock rolled forward by a corrupted clock skew
    // could leave a profile locked for a year. Cap the clamp at 24h.
    if (lockedUntil.difference(now).inHours.abs() > 24) {
      return (allowed: true, remaining: null);
    }
    if (now.isBefore(lockedUntil)) {
      return (allowed: false, remaining: lockedUntil.difference(now));
    }
    return (allowed: true, remaining: null);
  }

  static Uint8List _pbkdf2Sha256(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final blockSize = sha256.blockSize;
    final blockCount = (keyLength + blockSize - 1) ~/ blockSize;
    final out = BytesBuilder();
    for (var i = 1; i <= blockCount; i++) {
      out.add(_pbkdf2Block(hmac, salt, iterations, i));
    }
    return Uint8List.fromList(out.toBytes().sublist(0, keyLength));
  }

  static Uint8List _pbkdf2Block(
    Hmac hmac,
    List<int> salt,
    int iterations,
    int blockIndex,
  ) {
    final indexBytes = Uint8List(4)
      ..[0] = (blockIndex >> 24) & 0xff
      ..[1] = (blockIndex >> 16) & 0xff
      ..[2] = (blockIndex >> 8) & 0xff
      ..[3] = blockIndex & 0xff;
    var u = Uint8List.fromList(hmac.convert([...salt, ...indexBytes]).bytes);
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
