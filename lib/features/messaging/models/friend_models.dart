// Models that back the cross-device friends + directory layer used by
// the messaging inbox. All persisted in Firestore (with Hive caches);
// the JSON keys mirror the Firestore document shape exactly.

/// Status of a friend request between two profiles.
enum FriendRequestStatus { pending, accepted, rejected, cancelled }

extension FriendRequestStatusExt on FriendRequestStatus {
  String get wire {
    switch (this) {
      case FriendRequestStatus.pending:
        return 'pending';
      case FriendRequestStatus.accepted:
        return 'accepted';
      case FriendRequestStatus.rejected:
        return 'rejected';
      case FriendRequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static FriendRequestStatus fromWire(String? s) {
    switch (s) {
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      case 'cancelled':
        return FriendRequestStatus.cancelled;
      case 'pending':
      default:
        return FriendRequestStatus.pending;
    }
  }
}

/// A pending or resolved friend invitation. Doc id is
/// `${fromProfileId}_${toProfileId}` so resending the same request is
/// idempotent at the Firestore level.
class FriendRequest {
  final String id;
  final String fromProfileId;
  final String toProfileId;
  final String fromOwnerUid;
  final String fromDisplayName;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FriendRequest({
    required this.id,
    required this.fromProfileId,
    required this.toProfileId,
    required this.fromOwnerUid,
    required this.fromDisplayName,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  static String makeId(String fromProfileId, String toProfileId) =>
      '${fromProfileId}_$toProfileId';

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_profile_id': fromProfileId,
        'to_profile_id': toProfileId,
        'from_owner_uid': fromOwnerUid,
        'from_display_name': fromDisplayName,
        'status': status.wire,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
        id: j['id'] as String? ?? '',
        fromProfileId: j['from_profile_id'] as String? ?? '',
        toProfileId: j['to_profile_id'] as String? ?? '',
        fromOwnerUid: j['from_owner_uid'] as String? ?? '',
        fromDisplayName: j['from_display_name'] as String? ?? '',
        status: FriendRequestStatusExt.fromWire(j['status'] as String?),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: j['updated_at'] != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );
}

/// Accepted friendship between two profiles. Doc id is the sorted-pair
/// `${minProfileId}_${maxProfileId}` so there is exactly one document
/// per relationship regardless of who initiated it.
class Friendship {
  final String id;
  final String profileA;
  final String profileB;
  final DateTime createdAt;

  const Friendship({
    required this.id,
    required this.profileA,
    required this.profileB,
    required this.createdAt,
  });

  /// Sorted-pair id maker — always returns the same id for any ordering
  /// of (a, b) so the doc is single-source-of-truth.
  static String makeId(String a, String b) {
    final lo = a.compareTo(b) <= 0 ? a : b;
    final hi = a.compareTo(b) <= 0 ? b : a;
    return '${lo}_$hi';
  }

  /// Returns the other party's profile id given mine.
  String otherProfileFor(String myProfileId) =>
      myProfileId == profileA ? profileB : profileA;

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_a': profileA,
        'profile_b': profileB,
        'created_at': createdAt.toIso8601String(),
      };

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
        id: j['id'] as String? ?? '',
        profileA: j['profile_a'] as String? ?? '',
        profileB: j['profile_b'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Public-facing record from `profile_directory/{username}` — the
/// minimum we expose for cross-device lookup. Keep it slim: no PII
/// beyond the display name and role.
class DirectoryEntry {
  final String username;
  final String profileId;
  final String name;
  /// Role index from [UserRole]. Stored as int for forward-compat with
  /// new roles without breaking the directory query.
  final int roleIndex;
  final String ownerUid;
  final DateTime updatedAt;

  const DirectoryEntry({
    required this.username,
    required this.profileId,
    required this.name,
    required this.roleIndex,
    required this.ownerUid,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'profile_id': profileId,
        'name': name,
        'role_index': roleIndex,
        'owner_uid': ownerUid,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DirectoryEntry.fromJson(Map<String, dynamic> j) => DirectoryEntry(
        username: j['username'] as String? ?? '',
        profileId: j['profile_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        roleIndex: (j['role_index'] as int?) ?? 0,
        ownerUid: j['owner_uid'] as String? ?? '',
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
