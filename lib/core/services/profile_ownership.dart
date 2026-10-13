import 'package:firebase_core/firebase_core.dart';

import 'firebase_service.dart';

/// Whether *this* device may write cloud data scoped to a profile.
///
/// Every owner-scoped rule in `firestore.rules` funnels through
/// `ownsProfile(profileId)`, which compares `profiles/{id}.owner_uid` to the
/// caller's uid. Restoring a profile with its recovery code moves that field
/// to the new device — deliberately, one profile has one owner — and the
/// device it moved *away from* keeps working locally while every cloud write
/// is refused.
///
/// Nothing used to detect that. The losing device looked healthy: routines,
/// alarms and assignments all saved to Hive and simply never left. This check
/// exists so a surface can say so *before* an educator spends ten minutes
/// building something their learner will never receive.
enum ProfileCloudOwnership {
  /// This device owns the profile; cloud writes will be accepted.
  owned,

  /// The profile's cloud document belongs to a different device. Writes are
  /// refused and will keep being refused until it is restored back here.
  elsewhere,

  /// Not established — Firebase is off, the read failed, or the profile has
  /// never reached the cloud. Deliberately distinct from [elsewhere]: this is
  /// "we don't know", and a surface must not accuse a device on a guess.
  unknown;

  bool get blocksCloudWrites => this == ProfileCloudOwnership.elsewhere;
}

/// Reads `profiles/{profileId}.owner_uid` and compares it to this device.
///
/// The device that lost ownership is the only one that needs to be told.
/// Until 1.4.1 any signed-in device could read the profile and compare;
/// since then the rules let a device read only its own profiles (and its
/// learners' and classmates'), so a refused read of a profile that is in
/// the cloud is itself the answer: it belongs to another device.
class ProfileOwnershipService {
  const ProfileOwnershipService({
    Future<String?> Function(String profileId)? remoteOwnerUid,
    String? Function()? currentUid,
  })  : _remoteOwnerUid = remoteOwnerUid,
        _currentUid = currentUid;

  /// Both seams are injected rather than reached for, so the whole policy is
  /// testable without Firestore or a signed-in session.
  final Future<String?> Function(String profileId)? _remoteOwnerUid;
  final String? Function()? _currentUid;

  Future<String?> _readOwner(String profileId) async {
    final custom = _remoteOwnerUid;
    if (custom != null) return custom(profileId);
    final snap =
        await FirebaseService.db.collection('profiles').doc(profileId).get();
    return snap.data()?['owner_uid'] as String?;
  }

  String? _uid() =>
      _currentUid != null ? _currentUid() : FirebaseService.currentUid;

  Future<ProfileCloudOwnership> check(String profileId) async {
    if (profileId.isEmpty) return ProfileCloudOwnership.unknown;
    if (_remoteOwnerUid == null && !FirebaseService.isConfigured) {
      return ProfileCloudOwnership.unknown;
    }
    final me = _uid();
    if (me == null) return ProfileCloudOwnership.unknown;

    try {
      final owner = await _readOwner(profileId);
      // A missing document, or a null owner, is an unclaimed row rather than
      // someone else's — the rules let this device claim it, so writes are
      // not blocked.
      if (owner == null || owner.isEmpty) return ProfileCloudOwnership.owned;
      return owner == me
          ? ProfileCloudOwnership.owned
          : ProfileCloudOwnership.elsewhere;
    } on FirebaseException catch (e) {
      // A missing profile reads as missing; a refused one exists and is not
      // this device's (see the class comment). Anything else says nothing.
      return e.code == 'permission-denied'
          ? ProfileCloudOwnership.elsewhere
          : ProfileCloudOwnership.unknown;
    } on Object {
      // A failed read says nothing about ownership. Never guess "elsewhere"
      // from a network blip — that would accuse a device of a problem it does
      // not have, and the copy tells the educator to go find another tablet.
      return ProfileCloudOwnership.unknown;
    }
  }
}
