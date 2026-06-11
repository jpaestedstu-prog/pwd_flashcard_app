import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../security/pin_auth_service.dart';
import 'firebase_service.dart';

/// Why a recovery-code operation failed. Mirrors the [JoinCodeError]
/// shape so call sites can present consistent error UX.
enum RecoveryCodeError {
  /// No recovery code matched the supplied input.
  notFound,

  /// The code is structurally valid and exists, but has already been
  /// redeemed on another device.
  alreadyUsed,

  /// The code's stored hash didn't match the supplied code — most
  /// commonly a transcription typo the alphabet didn't catch.
  invalidCode,

  /// Network error contacting Firestore, or Firebase not configured.
  network,

  /// Could not generate a unique code after the retry budget.
  collision,

  /// Permission denied — usually means the rules have not been
  /// re-deployed since the recovery_codes block was added.
  permissionDenied,

  /// Unexpected error.
  unknown,
}

class RecoveryCodeException implements Exception {
  final RecoveryCodeError error;
  final String message;
  const RecoveryCodeException(this.error, this.message);

  @override
  String toString() => 'RecoveryCodeException($error): $message';
}

/// Metadata about a registered recovery code. The plaintext code itself
/// is never stored — only its hash + salt. The doc id (which IS the
/// hyphenated code, e.g. `MNGO-BERY-7K`) is shown once to the user.
class RecoveryCodeRecord {
  final String code; // doc id (also the human-readable code)
  final String profileId;
  final String profileOwnerUid;
  final String codeHash;
  final String codeSalt;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? redeemedByUid;

  const RecoveryCodeRecord({
    required this.code,
    required this.profileId,
    required this.profileOwnerUid,
    required this.codeHash,
    required this.codeSalt,
    required this.createdAt,
    this.expiresAt,
    this.usedAt,
    this.redeemedByUid,
  });

  bool get isUsed => usedAt != null;

  factory RecoveryCodeRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }

    DateTime? parseTsNullable(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return null;
    }

    return RecoveryCodeRecord(
      code: doc.id,
      profileId: (data['profile_id'] as String?) ?? '',
      profileOwnerUid: (data['profile_owner_uid'] as String?) ?? '',
      codeHash: (data['code_hash'] as String?) ?? '',
      codeSalt: (data['code_salt'] as String?) ?? '',
      createdAt: parseTs(data['created_at']),
      expiresAt: parseTsNullable(data['expires_at']),
      usedAt: parseTsNullable(data['used_at']),
      redeemedByUid: data['redeemed_by_uid'] as String?,
    );
  }
}

/// Generates and manages **device-recovery codes** that let a profile
/// be restored on a new device after the original anon uid is lost.
///
/// Separate from [PinCredentialHelper]'s recovery code, which is for
/// PIN reset only. This service emits a longer, dash-grouped code and
/// persists a `recovery_codes/{code}` doc whose id IS the code itself
/// (O(1) lookup, no `where(...)` query).
class RecoveryCodeService {
  RecoveryCodeService._();

  // Same no-confusables alphabet as [JoinCodeService] / [PinAuthService].
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _groupLength = 4;
  static const int _groupsBeforeTrailer = 2;
  static const int _trailerLength = 2;
  static const int _maxAttempts = 10;
  static const Duration _defaultExpiry = Duration(days: 365);

  static final Random _rng = Random.secure();

  /// Builds a `XXXX-XXXX-XX` formatted code. 10 chars from a 31-symbol
  /// alphabet ≈ 8.2 × 10^14 combinations — collisions are essentially
  /// impossible, but [generateUniqueCode] still verifies.
  static String randomCode() {
    final buf = StringBuffer();
    for (var g = 0; g < _groupsBeforeTrailer; g++) {
      for (var i = 0; i < _groupLength; i++) {
        buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
      }
      buf.write('-');
    }
    for (var i = 0; i < _trailerLength; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }

  /// Normalises user input: strip whitespace/dashes, uppercase, re-insert
  /// dashes in canonical positions. Returns null if the cleaned input is
  /// the wrong length — saves a round trip to Firestore on obvious typos.
  static String? normalise(String input) {
    final cleaned =
        input.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (cleaned.length != _groupLength * _groupsBeforeTrailer + _trailerLength) {
      return null;
    }
    final buf = StringBuffer();
    for (var g = 0; g < _groupsBeforeTrailer; g++) {
      buf.write(cleaned.substring(g * _groupLength, (g + 1) * _groupLength));
      buf.write('-');
    }
    buf.write(cleaned.substring(_groupsBeforeTrailer * _groupLength));
    return buf.toString();
  }

  /// Generate a recovery code whose doc id does not yet exist in
  /// Firestore. Throws [RecoveryCodeException] with [RecoveryCodeError.network]
  /// if Firebase is not configured (the recovery flow is online-only).
  static Future<String> generateUniqueCode() async {
    if (!FirebaseService.isConfigured) {
      throw const RecoveryCodeException(
        RecoveryCodeError.network,
        'Cloud sync is not configured. Recovery codes require Firestore.',
      );
    }
    final db = FirebaseService.db;
    for (var i = 0; i < _maxAttempts; i++) {
      final code = randomCode();
      try {
        final doc = await db.collection('recovery_codes').doc(code).get();
        if (!doc.exists) return code;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw const RecoveryCodeException(
            RecoveryCodeError.permissionDenied,
            "Firestore denied access on /recovery_codes. The deployed "
            'security rules need the recovery_codes block — run '
            '`firebase deploy --only firestore:rules`.',
          );
        }
        throw RecoveryCodeException(
          RecoveryCodeError.network,
          e.message ?? e.code,
        );
      } catch (e) {
        throw RecoveryCodeException(
          RecoveryCodeError.network,
          e.toString(),
        );
      }
    }
    throw const RecoveryCodeException(
      RecoveryCodeError.collision,
      'Could not generate a unique recovery code.',
    );
  }

  /// Register a brand-new recovery code for [profileId].
  ///
  /// Returns the plaintext code so the caller can show it to the user
  /// exactly once. The code is also re-displayable later via
  /// [findActiveForProfile] (which returns only metadata — the plaintext
  /// is preserved in the doc id, so the showing screen can reuse it).
  static Future<String> createRecoveryCode({
    required String profileId,
    Duration? validFor,
  }) async {
    if (!FirebaseService.isConfigured) {
      throw const RecoveryCodeException(
        RecoveryCodeError.network,
        'Cloud sync is not configured. Connect to the internet to '
        'create a recovery code.',
      );
    }
    final uid = await FirebaseService.ensureSignedIn();
    if (uid == null) {
      throw const RecoveryCodeException(
        RecoveryCodeError.network,
        "Couldn't sign in to create the recovery code. Make sure "
        'Anonymous sign-in is enabled in the Firebase console.',
      );
    }

    final code = await generateUniqueCode();
    final salt = PinAuthService.generateSalt();
    final hash = PinAuthService.hashPin(code, salt);

    final now = DateTime.now();
    final expires = now.add(validFor ?? _defaultExpiry);

    try {
      await FirebaseService.db.collection('recovery_codes').doc(code).set({
        'profile_id': profileId,
        'profile_owner_uid': uid,
        'code_hash': hash,
        'code_salt': salt,
        'created_at': Timestamp.fromDate(now),
        'expires_at': Timestamp.fromDate(expires),
        'used_at': null,
        'redeemed_by_uid': null,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const RecoveryCodeException(
          RecoveryCodeError.permissionDenied,
          'Firestore denied access on /recovery_codes. The deployed '
          'rules need to be refreshed — run '
          '`firebase deploy --only firestore:rules`.',
        );
      }
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.message ?? e.code,
      );
    } catch (e) {
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.toString(),
      );
    }
    return code;
  }

  /// Find the latest unused recovery code for [profileId], if any.
  /// Returns null when no code has been issued yet.
  static Future<RecoveryCodeRecord?> findActiveForProfile(
    String profileId,
  ) async {
    if (!FirebaseService.isConfigured) return null;
    try {
      final snap = await FirebaseService.db
          .collection('recovery_codes')
          .where('profile_id', isEqualTo: profileId)
          .where('used_at', isNull: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return RecoveryCodeRecord.fromDoc(snap.docs.first);
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Look up a code by its doc id (i.e. the code itself), normalised.
  ///
  /// Returns null when the code is structurally invalid (wrong length)
  /// or doesn't exist. Throws on permission / network failures so the UI
  /// can distinguish "code wrong" from "we couldn't ask Firestore".
  static Future<RecoveryCodeRecord?> lookupCode(String input) async {
    if (!FirebaseService.isConfigured) {
      throw const RecoveryCodeException(
        RecoveryCodeError.network,
        'Cloud sync is not configured. Connect to the internet to '
        'recover a profile.',
      );
    }
    final normalised = normalise(input);
    if (normalised == null) return null;

    final uid = await FirebaseService.ensureSignedIn();
    if (uid == null) {
      throw const RecoveryCodeException(
        RecoveryCodeError.network,
        "Couldn't sign in to look up the recovery code. Make sure "
        'Anonymous sign-in is enabled in the Firebase console.',
      );
    }

    try {
      final doc = await FirebaseService.db
          .collection('recovery_codes')
          .doc(normalised)
          .get();
      if (!doc.exists) return null;
      return RecoveryCodeRecord.fromDoc(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const RecoveryCodeException(
          RecoveryCodeError.permissionDenied,
          'Firestore denied access on /recovery_codes. The deployed '
          'rules need to be refreshed — run '
          '`firebase deploy --only firestore:rules`.',
        );
      }
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.message ?? e.code,
      );
    } catch (e) {
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.toString(),
      );
    }
  }

  /// Verify that the supplied [code] matches the [record]'s stored hash.
  /// Doc-id equality alone is not enough — a (vanishingly rare) doc-id
  /// collision shouldn't let an attacker claim an unrelated profile.
  static bool verify(String code, RecoveryCodeRecord record) {
    final normalised = normalise(code);
    if (normalised == null) return false;
    return PinAuthService.verifyPin(
      normalised,
      record.codeSalt,
      record.codeHash,
    );
  }

  /// Delete a code, revoking it. Idempotent — succeeds if the doc is
  /// already gone.
  static Future<void> revoke(String code) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await FirebaseService.db
          .collection('recovery_codes')
          .doc(code)
          .delete();
    } on FirebaseException catch (e) {
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.message ?? e.code,
      );
    } catch (e) {
      throw RecoveryCodeException(
        RecoveryCodeError.network,
        e.toString(),
      );
    }
  }
}
