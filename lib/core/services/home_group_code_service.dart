import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/home_group.dart';
import '../../data/local/hive_service.dart';
import 'firebase_service.dart';
import 'join_code_service.dart';

/// Generates, validates, and resets home-group join codes.
///
/// Mirrors [JoinCodeService] but operates on the `home_groups` collection.
/// Reuses [JoinCodeService.randomCode] so the alphabet (no O/0/I/1/L) and
/// length (6) are guaranteed to match across both code spaces — a child
/// and a student cannot accidentally type a code that resolves on the
/// wrong collection because the lookup paths are separate.
class HomeGroupCodeService {
  HomeGroupCodeService._();

  static const int _maxAttempts = 10;
  static const String _collection = 'home_groups';

  /// Pick a random code that doesn't already exist in Firestore.
  static Future<String> generateUniqueCode() async {
    if (!FirebaseService.isConfigured) {
      // Offline fallback: random codes against the local cache.
      for (var i = 0; i < _maxAttempts; i++) {
        final code = JoinCodeService.randomCode();
        if (HiveService.getCachedHomeGroupByCode(code) == null) return code;
      }
      throw const JoinCodeException(
          JoinCodeError.collision,
          'Could not generate a unique home-group code locally.');
    }

    final db = FirebaseService.db;
    for (var i = 0; i < _maxAttempts; i++) {
      final code = JoinCodeService.randomCode();
      try {
        final existing = await db
            .collection(_collection)
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
        JoinCodeError.collision,
        'Could not generate a unique home-group code.');
  }

  /// Look up a home group by its join code. Mirrors
  /// [JoinCodeService.findByCode] — Firestore first, then local fallback.
  static Future<HomeGroup?> findByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    if (FirebaseService.isConfigured) {
      // Mirror JoinCodeService.findByCode: the home_groups read rule
      // requires a signed-in user, so make sure auth is ready before the
      // query — otherwise the failure surfaces as a misleading "rules"
      // error when the real cause is anonymous auth not being enabled.
      final uid = await FirebaseService.ensureSignedIn();
      if (uid == null) {
        throw const JoinCodeException(
          JoinCodeError.network,
          "Couldn't sign in to look up the group code. In the Firebase "
          'console, open Authentication → Sign-in method and enable '
          'Anonymous sign-in, then try again.',
        );
      }

      try {
        final snap = await FirebaseService.db
            .collection(_collection)
            .where('code', isEqualTo: normalized)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final group = HomeGroup.fromJson(
              Map<String, dynamic>.from(snap.docs.first.data()));
          await HiveService.cacheHomeGroup(group);
          return group;
        }
        return null;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw const JoinCodeException(
            JoinCodeError.network,
            'Firestore denied access on /home_groups even though you are '
            'signed in. The deployed security rules need to allow reads '
            'for signed-in users on the home_groups collection. See '
            'firestore.rules and run `firebase deploy --only '
            'firestore:rules`.',
          );
        }
        throw JoinCodeException(
            JoinCodeError.network, e.message ?? e.code);
      } catch (e) {
        throw JoinCodeException(JoinCodeError.network, e.toString());
      }
    }

    final local = HiveService.getCachedHomeGroupByCode(normalized);
    if (local != null) return local;
    throw JoinCodeException(
      JoinCodeError.network,
      'Cloud sync isn\'t connected. Home-group codes from other devices '
      'can\'t be verified. Reason: ${FirebaseService.lastInitError ?? "unknown"}',
    );
  }

  /// Generate a new code for [group] and persist the change. The id is
  /// preserved so existing memberships survive.
  static Future<HomeGroup> regenerateCode(HomeGroup group) async {
    final newCode = await generateUniqueCode();
    final updated = group.copyWith(
      code: newCode,
      updatedAt: DateTime.now(),
    );

    if (FirebaseService.isConfigured) {
      try {
        await FirebaseService.db
            .collection(_collection)
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

    await HiveService.cacheHomeGroup(updated);
    return updated;
  }
}
