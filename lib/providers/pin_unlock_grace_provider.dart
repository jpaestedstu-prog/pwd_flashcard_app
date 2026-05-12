import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_service.dart';

/// Live "until when is the on-device PIN unlock grace active" for one
/// child profile.
///
/// The lock screen writes through this provider after a successful PIN
/// entry so [lockStateProvider] returns `null` for the next 30 minutes
/// without having to round-trip through Firestore. Educator-driven
/// remote unlocks still flow through `child_unlock_overrides`; the two
/// short-circuits in [lockStateProvider] are independent — whichever is
/// active wins.
class PinUnlockGraceNotifier extends FamilyNotifier<DateTime?, String> {
  @override
  DateTime? build(String childProfileId) {
    return HiveService.getPinUnlockGrace(childProfileId);
  }

  /// Grant a grace window starting now. Persists to Hive so the value
  /// survives a process restart.
  Future<void> grant(Duration duration) async {
    final until = DateTime.now().add(duration);
    await HiveService.setPinUnlockGrace(arg, until);
    state = until;
  }

  /// Clear any active grace immediately (used by tests / sign-out).
  Future<void> clear() async {
    await HiveService.clearPinUnlockGrace(arg);
    state = null;
  }
}

final pinUnlockGraceProvider =
    NotifierProvider.family<PinUnlockGraceNotifier, DateTime?, String>(
  PinUnlockGraceNotifier.new,
);
