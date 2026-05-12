import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/classroom.dart';
import '../../data/local/hive_service.dart';
import 'firebase_service.dart';

/// Why a join-code operation failed.
enum JoinCodeError {
  /// No classroom matched the supplied code.
  notFound,

  /// Network error contacting Firestore, or Firebase not configured.
  network,

  /// Could not generate a unique code after the retry budget.
  collision,

  /// Unexpected error.
  unknown,
}

class JoinCodeException implements Exception {
  final JoinCodeError error;
  final String message;
  const JoinCodeException(this.error, this.message);

  @override
  String toString() => 'JoinCodeException($error): $message';
}

/// Generates, validates, and resets classroom join codes.
///
/// Codes are 6 characters from a reduced alphabet that excludes visually
/// ambiguous glyphs: `O 0 I 1 L`. With ~31^6 ≈ 887M combinations,
/// collisions are vanishingly rare, but [generateUniqueCode] still
/// re-rolls if the first pick is already taken.
class JoinCodeService {
  JoinCodeService._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;
  static const int _maxAttempts = 10;

  static final Random _rng = Random.secure();

  /// Pick a random 6-char code (no uniqueness check).
  static String randomCode() {
    final buf = StringBuffer();
    for (var i = 0; i < _codeLength; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }

  /// Pick a random code that doesn't already exist in Firestore.
  ///
  /// Throws [JoinCodeException] with [JoinCodeError.network] if Firestore
  /// is unreachable, or [JoinCodeError.collision] if every attempt landed
  /// on an existing code (statistically impossible — indicates the
  /// collection is corrupted or the alphabet is exhausted).
  static Future<String> generateUniqueCode() async {
    if (!FirebaseService.isConfigured) {
      // Offline-friendly fallback: random codes against the local cache.
      // Realistic only when running the app fully offline (e.g. dev mode).
      for (var i = 0; i < _maxAttempts; i++) {
        final code = randomCode();
        if (HiveService.getCachedClassroomByCode(code) == null) return code;
      }
      throw const JoinCodeException(
          JoinCodeError.collision, 'Could not generate a unique code locally.');
    }

    final db = FirebaseService.db;
    for (var i = 0; i < _maxAttempts; i++) {
      final code = randomCode();
      try {
        final existing = await db
            .collection('classrooms')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) return code;
      } on FirebaseException catch (e) {
        throw JoinCodeException(
            JoinCodeError.network, e.message ?? e.code);
      } catch (e) {
        throw JoinCodeException(JoinCodeError.network, e.toString());
      }
    }
    throw const JoinCodeException(
        JoinCodeError.collision, 'Could not generate a unique code.');
  }

  /// Look up a classroom by its join code.
  ///
  /// Tries Firestore first; falls back to the local cache for the offline
  /// edge case where the teacher device has previously synced this class.
  /// Returns null if the code doesn't match any classroom.
  static Future<Classroom?> findByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    if (FirebaseService.isConfigured) {
      // Firestore rules require a signed-in user to read /classrooms.
      // The startup sign-in can race with a fast tap (or fail silently if
      // Anonymous auth is disabled in the Firebase console), so make sure
      // we have a uid before issuing the query — otherwise we'd surface
      // the read failure as "rules problem" when the real cause is auth.
      final uid = await FirebaseService.ensureSignedIn();
      if (uid == null) {
        throw const JoinCodeException(
          JoinCodeError.network,
          "Couldn't sign in to look up the class code. In the Firebase "
          'console, open Authentication → Sign-in method and enable '
          'Anonymous sign-in, then try again.',
        );
      }

      try {
        final snap = await FirebaseService.db
            .collection('classrooms')
            .where('code', isEqualTo: normalized)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final classroom = Classroom.fromJson(
              Map<String, dynamic>.from(snap.docs.first.data()));
          // Cache locally so subsequent offline lookups work.
          await HiveService.cacheClassroom(classroom);
          return classroom;
        }
        // Code not found remotely — the local cache shouldn't override that.
        return null;
      } on FirebaseException catch (e) {
        // We already confirmed the user is signed in above, so
        // permission-denied here genuinely points at the deployed
        // security rules — surface that and the deploy command.
        if (e.code == 'permission-denied') {
          throw const JoinCodeException(
            JoinCodeError.network,
            'Firestore denied access on /classrooms even though you are '
            'signed in. The deployed security rules need to allow reads '
            'for signed-in users on the classrooms collection. See '
            'firestore.rules and run `firebase deploy --only '
            'firestore:rules`.',
          );
        }
        throw JoinCodeException(
            JoinCodeError.network, e.message ?? e.code);
      } catch (e) {
        // Treat any non-Firebase failure (timeout, DNS, etc.) as network.
        throw JoinCodeException(JoinCodeError.network, e.toString());
      }
    }

    // Firebase not configured — local-only lookup. If the code isn't
    // already cached on this device, the student can never find it,
    // so surface a clear error rather than the misleading "code not found".
    final local = HiveService.getCachedClassroomByCode(normalized);
    if (local != null) return local;
    throw JoinCodeException(
      JoinCodeError.network,
      'Cloud sync isn\'t connected. Class codes from other devices can\'t be '
      'verified. Reason: ${FirebaseService.lastInitError ?? "unknown"}',
    );
  }

  /// Generate a new code for [classroom] and persist the change.
  ///
  /// The classroom's `id` is unchanged so existing memberships survive.
  /// `updated_at` is bumped to the current time.
  static Future<Classroom> regenerateCode(Classroom classroom) async {
    final newCode = await generateUniqueCode();
    final updated = classroom.copyWith(
      code: newCode,
      updatedAt: DateTime.now(),
    );

    if (FirebaseService.isConfigured) {
      try {
        await FirebaseService.db
            .collection('classrooms')
            .doc(updated.id)
            .set({
          'code': updated.code,
          'updated_at': updated.updatedAt.toIso8601String(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        throw JoinCodeException(
            JoinCodeError.network, e.message ?? e.code);
      } catch (e) {
        throw JoinCodeException(JoinCodeError.network, e.toString());
      }
    }

    await HiveService.cacheClassroom(updated);
    return updated;
  }
}
