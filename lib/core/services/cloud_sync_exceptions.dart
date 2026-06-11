/// Typed exceptions for cloud-sync failure modes that the educator
/// management screens (Manage Classes, Manage Home Groups) need to map
/// onto user-facing copy.
///
/// Without these typed errors the screen used to render the raw
/// [FirebaseException.toString()] — e.g.
/// `Could not load classes: [cloud_firestore/permission-denied] ...` —
/// which is unactionable for a teacher who doesn't know what
/// "permission-denied" means in the rules.
library;

/// Anonymous Firebase Auth hasn't completed (offline first launch, or
/// Anonymous sign-in is disabled in the Firebase Console). Every
/// Firestore rule starts with `signedIn()`, so without a uid the
/// classroom / home-group reads come back permission-denied.
class CloudAuthMissingException implements Exception {
  final String? underlying;
  const CloudAuthMissingException([this.underlying]);

  @override
  String toString() => 'CloudAuthMissingException: $underlying';
}

/// The local profile carries an `ownerUid` that no longer matches this
/// device's anonymous auth uid. Happens after an uninstall/reinstall or
/// an app-data clear: the Firestore profile doc still belongs to the
/// old uid, so any owner-scoped write would be rejected by the rules.
///
/// The Manage Classes / Manage Home Groups screen offers a
/// "Reset for this device" action that clears the local `ownerUid` and
/// re-runs the claim flow.
class OwnerUidMismatchException implements Exception {
  final String profileId;
  final String? localOwnerUid;
  final String? currentUid;

  const OwnerUidMismatchException({
    required this.profileId,
    required this.localOwnerUid,
    required this.currentUid,
  });

  @override
  String toString() =>
      'OwnerUidMismatchException(profile=$profileId, '
      'local=$localOwnerUid, current=$currentUid)';
}
