import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../models/friend_models.dart';
import 'profile_directory_service.dart';

/// Telegram-style request -> accept friending. All persistence lives in
/// Firestore (free Spark tier) with Hive mirroring for offline reads.
///
/// **Firestore collections:**
/// ```
/// friend_requests/{fromProfileId}_{toProfileId}
///   from_profile_id, to_profile_id, from_owner_uid,
///   from_display_name, status, created_at, updated_at
///
/// friendships/{minProfileId}_{maxProfileId}
///   profile_a, profile_b, created_at
/// ```
///
/// The composite document ids keep resends idempotent (same id = same
/// doc) and let security rules pin actions to ownership without listing
/// any subcollections.
class FriendService {
  FriendService._();

  static final FriendService instance = FriendService._();

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseService.db.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      FirebaseService.db.collection('friendships');

  // ─── Mutations ────────────────────────────────────────

  /// Resolve [targetUsernameOrId] to a profile id and write a pending
  /// `friend_requests` doc. Throws a [FriendActionException] on every
  /// user-visible failure (not found, self-add, already friends, etc.)
  /// so the UI can surface a precise toast.
  Future<void> sendRequest({
    required UserProfile me,
    required String targetUsernameOrId,
  }) async {
    if (!FirebaseService.isConfigured) {
      throw const FriendActionException(
          'Cloud sync is not configured on this device.');
    }
    final uid = FirebaseService.currentUid;
    if (uid == null) {
      throw const FriendActionException(
          'Sign-in is still warming up. Try again in a moment.');
    }

    final raw = targetUsernameOrId.trim();
    if (raw.isEmpty) {
      throw const FriendActionException('Enter a username or profile ID.');
    }

    // Heuristic: profile ids are UUIDs that contain hyphens AND are
    // longer than the slug suffix (e.g. `maria-1947`). The directory
    // resolves usernames; profile ids are looked up directly.
    DirectoryEntry? target;
    if (_looksLikeUuid(raw)) {
      target = await ProfileDirectoryService.instance.lookupByProfileId(raw);
    } else {
      target = await ProfileDirectoryService.instance.lookupByUsername(raw);
    }
    if (target == null) {
      throw const FriendActionException(
          'No user with that username or ID. Make sure they have opened '
          'Messages on their device at least once.');
    }

    if (target.profileId == me.id) {
      throw const FriendActionException("You can't add yourself.");
    }

    // Already friends? Skip the request and surface a friendly message.
    final friendshipId = Friendship.makeId(me.id, target.profileId);
    DocumentSnapshot<Map<String, dynamic>> existing;
    try {
      existing = await _friendships
          .doc(friendshipId)
          .get()
          .timeout(_firestoreTimeout);
    } catch (e, st) {
      _mapFirestoreError(e, st, 'sendRequest.checkFriendship');
    }
    if (existing.exists) {
      throw const FriendActionException("You're already friends.");
    }

    final requestId = FriendRequest.makeId(me.id, target.profileId);
    final reverseId = FriendRequest.makeId(target.profileId, me.id);

    // If the other person already sent ME a pending request, accept it
    // straight away instead of creating a duplicate from the other side.
    DocumentSnapshot<Map<String, dynamic>> reverse;
    try {
      reverse = await _requests
          .doc(reverseId)
          .get()
          .timeout(_firestoreTimeout);
    } catch (e, st) {
      _mapFirestoreError(e, st, 'sendRequest.checkReverse');
    }
    if (reverse.exists) {
      final r = FriendRequest.fromJson(reverse.data()!);
      if (r.status == FriendRequestStatus.pending) {
        await acceptRequest(myProfileId: me.id, requestId: reverseId);
        return;
      }
    }

    final now = DateTime.now();
    final req = FriendRequest(
      id: requestId,
      fromProfileId: me.id,
      toProfileId: target.profileId,
      fromOwnerUid: uid,
      fromDisplayName: me.name,
      status: FriendRequestStatus.pending,
      createdAt: now,
    );

    try {
      await _requests
          .doc(requestId)
          .set(req.toJson())
          .timeout(_firestoreTimeout);
    } catch (e, st) {
      _mapFirestoreError(e, st, 'sendRequest.write');
    }
  }

  /// Recipient accepts a pending request: writes the friendships doc and
  /// marks the request as `accepted` in a single batch.
  Future<void> acceptRequest({
    required String myProfileId,
    required String requestId,
  }) async {
    if (!FirebaseService.isConfigured) return;
    try {
      final doc = await _requests.doc(requestId).get();
      if (!doc.exists) return;
      final r = FriendRequest.fromJson(doc.data()!);
      if (r.status != FriendRequestStatus.pending) return;
      if (r.toProfileId != myProfileId && r.fromProfileId != myProfileId) {
        // Not addressed to us — refuse silently.
        return;
      }

      final fid = Friendship.makeId(r.fromProfileId, r.toProfileId);
      final friendship = Friendship(
        id: fid,
        profileA:
            r.fromProfileId.compareTo(r.toProfileId) <= 0
                ? r.fromProfileId
                : r.toProfileId,
        profileB:
            r.fromProfileId.compareTo(r.toProfileId) <= 0
                ? r.toProfileId
                : r.fromProfileId,
        createdAt: DateTime.now(),
      );

      final batch = FirebaseService.db.batch();
      batch.set(_friendships.doc(fid), friendship.toJson());
      batch.update(_requests.doc(requestId), {
        'status': FriendRequestStatus.accepted.wire,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await batch.commit();
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.acceptRequest');
    }
  }

  Future<void> rejectRequest(String requestId) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await _requests.doc(requestId).update({
        'status': FriendRequestStatus.rejected.wire,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.rejectRequest');
    }
  }

  /// Sender cancels their own outgoing request.
  Future<void> cancelRequest(String requestId) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await _requests.doc(requestId).update({
        'status': FriendRequestStatus.cancelled.wire,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.cancelRequest');
    }
  }

  Future<void> removeFriend({
    required String myProfileId,
    required String friendProfileId,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final fid = Friendship.makeId(myProfileId, friendProfileId);
    try {
      await _friendships.doc(fid).delete();
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.removeFriend');
    }
  }

  // ─── Streams ──────────────────────────────────────────

  /// Live list of accepted friendships visible to [profileId]. Merges
  /// two `where` queries client-side (Firestore disallows OR on different
  /// fields) and mirrors every emission to the Hive cache so the next
  /// cold start renders instantly.
  Stream<List<Friendship>> watchFriends(String profileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(_cachedFriends(profileId));
    }

    final a = _friendships
        .where('profile_a', isEqualTo: profileId)
        .snapshots();
    final b = _friendships
        .where('profile_b', isEqualTo: profileId)
        .snapshots();

    final controller = StreamController<List<Friendship>>.broadcast();
    List<Friendship> aBuf = const [];
    List<Friendship> bBuf = const [];
    var emitted = false;

    // Seed with the Hive cache so the inbox paints without waiting on
    // the first Firestore snapshot.
    controller.add(_cachedFriends(profileId));

    void emit() {
      final byId = <String, Friendship>{};
      for (final f in aBuf) {
        byId[f.id] = f;
      }
      for (final f in bBuf) {
        byId[f.id] = f;
      }
      final merged = byId.values.toList()
        ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
      controller.add(merged);
      // Fire-and-forget cache write.
      // ignore: discarded_futures
      HiveService.saveFriendsCache(
          profileId, merged.map((f) => f.toJson()).toList());
      emitted = true;
    }

    final subA = a.listen(
      (snap) {
        aBuf = snap.docs.map((d) => Friendship.fromJson(d.data())).toList();
        emit();
      },
      onError: (e, st) {
        ErrorHandler.report(e, st, 'FriendService.watchFriends.a');
        if (!emitted) emit();
      },
    );
    final subB = b.listen(
      (snap) {
        bBuf = snap.docs.map((d) => Friendship.fromJson(d.data())).toList();
        emit();
      },
      onError: (e, st) {
        ErrorHandler.report(e, st, 'FriendService.watchFriends.b');
        if (!emitted) emit();
      },
    );

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };
    return controller.stream;
  }

  /// Live list of incoming pending requests for [profileId].
  Stream<List<FriendRequest>> watchIncomingRequests(String profileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(_cachedRequests(profileId));
    }
    final cached = _cachedRequests(profileId);
    final live = _requests
        .where('to_profile_id', isEqualTo: profileId)
        .where('status', isEqualTo: FriendRequestStatus.pending.wire)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => FriendRequest.fromJson(d.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      // ignore: discarded_futures
      HiveService.saveFriendRequestsCache(
          profileId, list.map((r) => r.toJson()).toList());
      return list;
    });

    final controller = StreamController<List<FriendRequest>>.broadcast();
    controller.add(cached);
    final sub = live.listen(
      controller.add,
      onError: (e, st) {
        ErrorHandler.report(
            e, st, 'FriendService.watchIncomingRequests');
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // ─── Internals ────────────────────────────────────────

  List<Friendship> _cachedFriends(String profileId) {
    return HiveService.getFriendsCache(profileId)
        .map(Friendship.fromJson)
        .toList();
  }

  List<FriendRequest> _cachedRequests(String profileId) {
    return HiveService.getFriendRequestsCache(profileId)
        .map(FriendRequest.fromJson)
        .toList();
  }

  bool _looksLikeUuid(String s) {
    // UUID v4 is 36 chars including hyphens. The slug-suffix usernames
    // are shorter (e.g. `maria-1947` = 10 chars) so this heuristic is
    // safe enough.
    return s.length >= 32 && '-'.allMatches(s).length >= 4;
  }

  /// Bounded wait for any Firestore round-trip in [sendRequest]. Without
  /// this, an unreachable server (offline / firewalled) or an in-flight
  /// rules deployment can leave the dialog hanging indefinitely.
  static const Duration _firestoreTimeout = Duration(seconds: 10);

  /// Translate a raw Firestore failure into a user-facing
  /// [FriendActionException] and always throw. Declared `Never` so the
  /// analyzer treats post-call flow as unreachable — the original
  /// `existing`/`reverse` locals stay non-nullable.
  Never _mapFirestoreError(Object e, StackTrace st, String label) {
    ErrorHandler.report(e, st, 'FriendService.$label');
    if (e is TimeoutException) {
      throw const FriendActionException(
          'Network is slow. Check your connection and try again.');
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      throw const FriendActionException(
          "Couldn't reach the friend service. If this keeps happening, "
          'ask your teacher to redeploy the app rules.');
    }
    throw const FriendActionException(
        "Couldn't send the request. Try again in a moment.");
  }
}

/// User-visible failure mode for friend mutations. The message is safe
/// to show in a SnackBar without further translation; localisation can
/// be layered on later.
class FriendActionException implements Exception {
  final String message;
  const FriendActionException(this.message);

  @override
  String toString() => message;
}
