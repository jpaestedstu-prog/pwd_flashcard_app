import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/models.dart';
import '../data/remote/firestore_repository.dart';

/// Resolves one roster member's [UserProfile] for an educator surface.
///
/// The roster rows (`ManagedMember`) carry only an id and a display name,
/// but the Time Limits editor needs the learner's accessibility category
/// to show what the lock will actually do for them and to offer the
/// matching recommended defaults.
///
/// Hive first (instant, offline, and already populated for any learner
/// who has used this device), Firestore second (an educator setting
/// limits from their own device for a learner who joined by code).
/// Returns null when neither has it — callers degrade to "profile
/// unknown" rather than guessing a category.
final managedChildProfileProvider = FutureProvider.family<UserProfile?, String>(
  (ref, profileId) async {
    final cached = HiveService.getProfileById(profileId);
    if (cached != null) return cached;
    if (!FirebaseService.isConfigured) return null;
    try {
      return await const FirestoreRepository().getProfileById(profileId);
    } catch (_) {
      // Offline or permission-denied: the editor still works, it just
      // can't show the per-profile guidance.
      return null;
    }
  },
);
