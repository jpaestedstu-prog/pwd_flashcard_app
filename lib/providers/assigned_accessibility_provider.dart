import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/assigned_accessibility.dart';
import '../core/accessibility/learner_support.dart';
import '../core/services/firebase_service.dart';
import '../data/local/hive_service.dart';
import '../data/local/local_repository.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../features/gamepad/providers/gamepad_settings_provider.dart';
import '../features/gaze_control/providers/gaze_settings_provider.dart';
import 'app_providers.dart';

/// Per-profile Hive key: the [AssignedAccessibility.setAt] this device last
/// applied to that learner, so each version is applied exactly once.
const String kAssignedAccessibilityAppliedKey = 'assignedAccessibilityApplied';

/// The Firestore path of [profile]'s membership row — where their Teacher or
/// Parent sets their accessibility — or null for anyone without one: a
/// Student not in a class, a Child not in a home group, a Player, an
/// educator.
String? assignedAccessibilityRowPath(UserProfile? profile) {
  if (profile == null || profile.isGuestPlayer) return null;
  String? row(String collection, String? groupId) =>
      groupId == null || groupId.isEmpty
          ? null
          : '$collection/${groupId}_${profile.id}';
  return switch (profile.role) {
    UserRole.student => row('classroom_members', profile.classroomId),
    UserRole.child => row('home_group_members', profile.homeGroupId),
    _ => null,
  };
}

/// The accessibility a learner's educator last set, live from the
/// membership row at [rowPath] (see [assignedAccessibilityRowPath]). Null
/// while nothing has been set, and where there is no cloud to ask.
///
/// Read from the device's cache as well as the server: an educator's change
/// made on this very tablet (a shared classroom tablet) arrives straight
/// away, online or not.
final assignedAccessibilityProvider = StreamProvider.autoDispose
    .family<AssignedAccessibility?, String>((ref, rowPath) {
  if (!FirebaseService.isConfigured) return Stream.value(null);
  return FirebaseService.db
      .doc(rowPath)
      .snapshots()
      .map((snap) => AssignedAccessibility.fromRow(snap.data()));
});

/// Whether [assigned] is a version this device has not yet applied to the
/// learner [profileId].
bool isUnappliedAssignment(String profileId, AssignedAccessibility assigned) {
  try {
    return HiveService.getProfileSetting(
          kAssignedAccessibilityAppliedKey,
          profileId: profileId,
        ) !=
        assigned.setAt;
  } catch (_) {
    return false; // Hive not ready: nothing can be applied anyway.
  }
}

/// Versions being applied right now, so two listeners firing together (the
/// row's cache snapshot, then the server's) apply one version once.
final Set<String> _inFlight = {};

/// Applies the accessibility a Teacher or Parent set for the learner
/// [profileId] to that learner's profile **on this device**: their category
/// and supports, the settings that follow from them
/// ([AssignedAccessibility.settingsFrom]) and, when the supports say so,
/// Gaze Control or the game controller.
///
/// Works whether or not the learner is the one signed in — on a shared
/// tablet the educator's own save applies it at once — and refreshes the
/// live copies when they are. Returns false, changing nothing, for a version
/// already applied, a profile not on this device, or one that is not a
/// Student's or a Child's.
///
/// [read] and [invalidate] are a `WidgetRef`'s, a `Ref`'s or a
/// `ProviderContainer`'s.
Future<bool> applyAssignedAccessibility({
  required T Function<T>(ProviderListenable<T> provider) read,
  required void Function(ProviderOrFamily provider) invalidate,
  required String profileId,
  required AssignedAccessibility assigned,
}) async {
  final key = '$profileId@${assigned.setAt}';
  if (_inFlight.contains(key)) return false;
  final UserProfile? stored;
  try {
    stored = HiveService.getProfileById(profileId);
  } catch (_) {
    return false;
  }
  if (stored == null || !stored.role.isEnrollableLearner) return false;
  if (!isUnappliedAssignment(profileId, assigned)) return false;
  _inFlight.add(key);
  try {
    final updated = assigned.appliedTo(stored);
    // Local first: the learner's screens must not wait on the network.
    final saved = await const LocalRepository().saveProfileLocal(updated);
    // Awaited, then re-read: the settings are many keys, written one by one,
    // and a copy rebuilt halfway through would mix old and new.
    await HiveService.saveSettings(
      assigned.settingsFrom(HiveService.getSettings(profileId: profileId)),
      profileId: profileId,
    );
    invalidate(appSettingsForProfileProvider(profileId));
    if (read(profileProvider)?.id == profileId) invalidate(settingsProvider);
    // Rebuilt from storage first: a copy built earlier this session may be
    // older than what the learner has since changed themselves.
    switch (assigned.inputMode) {
      case LearnerSupportOption.inputGaze:
        invalidate(gazeSettingsForProfileProvider(profileId));
        read(gazeSettingsForProfileProvider(profileId).notifier)
            .enableForGazeLearner();
      case LearnerSupportOption.inputSwitch:
        invalidate(gamepadSettingsForProfileProvider(profileId));
        read(gamepadSettingsForProfileProvider(profileId).notifier)
            .setEnabled(true);
      default:
        break;
    }
    await HiveService.saveProfileSetting(
      kAssignedAccessibilityAppliedKey,
      assigned.setAt,
      profileId: profileId,
    );
    read(profileProvider.notifier).refreshFromStore(profileId);
    // The cloud copy of the profile, which the educator's dashboard reads.
    // Never throws, and only ever writes a profile this device owns.
    unawaited(const LocalRepository().publishProfile(saved));
    return true;
  } finally {
    _inFlight.remove(key);
  }
}
