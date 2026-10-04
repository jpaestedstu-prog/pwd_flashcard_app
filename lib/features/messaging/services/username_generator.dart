import 'dart:math';

import 'package:uuid/uuid.dart';

import 'profile_directory_service.dart';

/// Generates the auto-handle used to add friends in messaging.
///
/// The handle is human-shareable (e.g. `maria-194735`) so a learner can
/// tell their friend their username out loud. Six digits, not four: every
/// handle is a public `profile_directory` entry naming its learner (and
/// their disability), and four digits left 10,000 per first name — few
/// enough for a stranger to try them all. A million is not.
///
/// Collisions are resolved by rolling a fresh suffix; the
/// [generateUniqueHandle] entry point
/// retries up to [_maxAttempts] times against the live directory and
/// then falls back to an 8-char UUID suffix that is effectively unique.
class UsernameGenerator {
  UsernameGenerator._();

  static const int _maxAttempts = 5;
  static final Random _rng = Random.secure();
  static const _uuid = Uuid();

  /// Lowercase, hyphenated, alphanumeric-only slug. Empty/punctuation-only
  /// names collapse to the literal `user` so we always have something to
  /// hang the suffix off.
  static String slug(String name) {
    final lower = name.toLowerCase();
    final buf = StringBuffer();
    for (final code in lower.codeUnits) {
      final c = String.fromCharCode(code);
      final isLower = code >= 0x61 && code <= 0x7a;
      final isDigit = code >= 0x30 && code <= 0x39;
      if (isLower || isDigit) {
        buf.write(c);
      }
    }
    final s = buf.toString();
    return s.isEmpty ? 'user' : s;
  }

  /// Random 6-digit suffix as a zero-padded string ("004213").
  static String suffix() => _rng.nextInt(1000000).toString().padLeft(6, '0');

  /// Single attempt — does not check the directory.
  static String generateHandle(String name) =>
      '${slug(name)}-${suffix()}';

  /// Generates a handle and confirms (via [ProfileDirectoryService]) that
  /// no other profile has claimed it. Falls back to a UUID-short suffix
  /// after [_maxAttempts] collisions, which gives a vanishingly small
  /// chance of recollision and lets the create flow always succeed.
  static Future<String> generateUniqueHandle(String name) async {
    final base = slug(name);
    for (var i = 0; i < _maxAttempts; i++) {
      final candidate = '$base-${suffix()}';
      final taken =
          await ProfileDirectoryService.instance.isUsernameTaken(candidate);
      if (!taken) return candidate;
    }
    // Fallback path — 8 hex chars from a fresh UUID. The directory is
    // doc-id-keyed so this stays O(1) and avoids any blocking query.
    final uniq = _uuid.v4().replaceAll('-', '').substring(0, 8);
    return '$base-$uniq';
  }
}
