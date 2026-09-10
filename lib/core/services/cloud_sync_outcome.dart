import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether a mirrored write actually reached Firestore.
///
/// Lives in `core` rather than inside one feature because the distinction it
/// draws is the same everywhere and getting it wrong costs the same
/// everywhere: an educator who is told "saved" assumes their learner has the
/// thing. Assessments were the first surface to need it; Routines are the
/// second, and any future educator→learner write should reach for this rather
/// than inventing a third vocabulary.
///
/// **One profile syncs from one device at a time.** Restoring a profile with
/// its recovery code re-stamps `profiles/{id}.owner_uid` onto the new device,
/// and every rule pins writes to the owning uid — so the device it was
/// restored *away from* keeps working locally but can no longer write to the
/// cloud for that profile. That is the intended design, not a bug to route
/// around; what a service owes the user is honesty about it, which is
/// [CloudSyncOutcome.notOwner].
enum CloudSyncOutcome {
  /// In Hive *and* Firestore; other devices will pick it up.
  synced,

  /// Safely in Hive, but this device is the only one that knows — Firebase is
  /// unconfigured or the network is down. It goes up on the next connected
  /// open, so "not yet" is the honest word for it.
  localOnly,

  /// Refused: this profile is now owned by a different device.
  ///
  /// Separate from [localOnly] because the difference matters to the person
  /// holding the tablet: a local-only row is waiting, and this one is never
  /// going anywhere. Saying "not sent yet" here is a promise that will never
  /// be kept.
  notOwner;

  /// True when the write is never going to reach the cloud on its own.
  bool get needsAttention => this != CloudSyncOutcome.synced;
}

/// Whether Firestore refused a write outright, as opposed to not being
/// reachable.
///
/// Only the rules produce `permission-denied`, and on every owner-scoped
/// collection the only rule that can fail is the owning-uid check — so this
/// is the signal that the active profile has been restored onto another
/// device.
bool isOwnershipRefusalError(Object e) =>
    e is FirebaseException && e.code == 'permission-denied';

/// Classifies a caught write failure.
CloudSyncOutcome outcomeForError(Object e) =>
    isOwnershipRefusalError(e)
        ? CloudSyncOutcome.notOwner
        : CloudSyncOutcome.localOnly;
