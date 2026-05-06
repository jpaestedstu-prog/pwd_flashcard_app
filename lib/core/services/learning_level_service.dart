import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/local/hive_service.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'adaptive_difficulty_service.dart';
import 'firebase_service.dart';

/// Adaptive learning-level engine.
///
/// Initial level is suggested from age at onboarding. The system can then
/// auto-promote a learner who consistently performs above 80 % accuracy
/// across at least 20 sessions in a 30-day window — unless a teacher or
/// parent has applied an explicit override (in which case auto-promote
/// stays paused until the override is cleared).
class LearningLevelService {
  LearningLevelService._();

  /// Minimum sessions logged before the auto-promote logic triggers.
  static const int _promoteSessionThreshold = 20;

  /// Rolling window in days that the promote check considers.
  static const int _promoteRollingWindowDays = 30;

  /// Accuracy threshold (0..1) above which we'll auto-promote.
  static const double _promoteAccuracyThreshold = 0.80;

  /// Map age (in years) → [LearningLevel] for first-time onboarding.
  static LearningLevel suggestLevelFromAge(int years) {
    if (years <= 6) return LearningLevel.beginner;
    if (years <= 9) return LearningLevel.elementary;
    if (years <= 12) return LearningLevel.intermediate;
    return LearningLevel.advanced;
  }

  /// Convenience: derive a level from an optional birth date. Returns
  /// [LearningLevel.beginner] when the birth date is missing.
  static LearningLevel suggestLevelFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return LearningLevel.beginner;
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return suggestLevelFromAge(years);
  }

  /// Considers promoting [profileId] one notch up. No-op when:
  /// - profile is missing or not a learner role,
  /// - already at [LearningLevel.advanced],
  /// - currently held by an educator override,
  /// - not enough sessions recorded yet,
  /// - rolling accuracy below threshold.
  ///
  /// Persists to Hive (and Firestore, when configured) on a real bump.
  /// Returns the resulting level (unchanged or promoted) for callers that
  /// want to surface a "level up" toast.
  static Future<LearningLevel?> maybePromote(String profileId) async {
    final profile = HiveService.getProfileById(profileId);
    if (profile == null) return null;
    if (!profile.role.isLearner) return null;
    if (profile.hasLearningLevelOverride) return profile.learningLevel;

    final current = profile.effectiveLearningLevel;
    if (current == LearningLevel.advanced) return current;

    final history = AdaptiveDifficultyService.getHistory(profileId);
    if (history.length < _promoteSessionThreshold) return current;

    final cutoff = DateTime.now()
        .subtract(const Duration(days: _promoteRollingWindowDays));
    final recent =
        history.where((h) => h.timestamp.isAfter(cutoff)).toList();
    if (recent.length < _promoteSessionThreshold) return current;

    final avgAccuracy =
        recent.map((e) => e.accuracy).reduce((a, b) => a + b) /
            recent.length;
    if (avgAccuracy < _promoteAccuracyThreshold) return current;

    final next = _nextLevel(current);
    if (next == current) return current;

    final updated = profile.copyWith(
      learningLevel: () => next,
    );
    await HiveService.saveProfile(updated);
    await _mirrorToFirestore(updated);
    return next;
  }

  /// Apply a manual override from a teacher or parent. The override
  /// suspends auto-promote until [clearOverride] is called.
  static Future<UserProfile?> applyOverride({
    required String profileId,
    required LearningLevel level,
    required String overriddenByUid,
  }) async {
    final profile = HiveService.getProfileById(profileId);
    if (profile == null) return null;

    final updated = profile.copyWith(
      learningLevel: () => level,
      learningLevelOverriddenBy: () => overriddenByUid,
      learningLevelOverriddenAt: () => DateTime.now(),
    );
    await HiveService.saveProfile(updated);
    await _mirrorToFirestore(updated);
    return updated;
  }

  /// Clear an override and re-enable adaptive promote/demote for [profileId].
  static Future<UserProfile?> clearOverride(String profileId) async {
    final profile = HiveService.getProfileById(profileId);
    if (profile == null) return null;

    final updated = profile.copyWith(
      learningLevelOverriddenBy: () => null,
      learningLevelOverriddenAt: () => null,
    );
    await HiveService.saveProfile(updated);
    await _mirrorToFirestore(updated);
    return updated;
  }

  static LearningLevel _nextLevel(LearningLevel current) => switch (current) {
        LearningLevel.beginner => LearningLevel.elementary,
        LearningLevel.elementary => LearningLevel.intermediate,
        LearningLevel.intermediate => LearningLevel.advanced,
        LearningLevel.advanced => LearningLevel.advanced,
      };

  /// Best-effort mirror to Firestore. Silent on failure — the local Hive
  /// copy is authoritative offline, and the next sync will pick this up.
  static Future<void> _mirrorToFirestore(UserProfile profile) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await FirebaseService.db
          .collection('profiles')
          .doc(profile.id)
          .set({
        'learning_level': profile.learningLevel?.index,
        'learning_level_overridden_by': profile.learningLevelOverriddenBy,
        'learning_level_overridden_at':
            profile.learningLevelOverriddenAt?.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Swallow — sync queue / next reconnect will reconcile.
    }
  }
}
