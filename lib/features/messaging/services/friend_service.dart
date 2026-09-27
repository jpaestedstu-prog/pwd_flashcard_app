import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/friend_models.dart';
import 'learner_inbox_assembler.dart' show roleSlugFromIndex;
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

  CollectionReference<Map<String, dynamic>> get _blocks =>
      FirebaseService.db.collection('blocks');

  CollectionReference<Map<String, dynamic>> get _reports =>
      FirebaseService.db.collection('message_reports');

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
        'Cloud sync is not configured on this device.',
      );
    }
    final uid = FirebaseService.currentUid;
    if (uid == null) {
      throw const FriendActionException(
        'Sign-in is still warming up. Try again in a moment.',
      );
    }

    // A Child's friendships need their parent's yes, and the rules refuse
    // one without it — so a Child who is in no family group (and so has no
    // parent in the app to ask) is told that, rather than hitting an error.
    if (isChildWithoutGroup(me)) {
      throw const FriendActionException(
        'A grown-up needs to add you to their family group before you can make friends.',
      );
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
        'Messages on their device at least once.',
      );
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
      reverse = await _requests.doc(reverseId).get().timeout(_firestoreTimeout);
    } catch (e, st) {
      _mapFirestoreError(e, st, 'sendRequest.checkReverse');
    }
    if (reverse.exists) {
      final r = FriendRequest.fromJson(reverse.data()!);
      if (r.status == FriendRequestStatus.pending) {
        await acceptRequest(me: me, requestId: reverseId);
        return;
      }
      if (r.status == FriendRequestStatus.awaitingParent) {
        throw const FriendActionException(
          "You're almost friends — a grown-up still needs to say yes.",
        );
      }
    }

    // A *finished* request from a previous round (accepted, then unfriended
    // or blocked; or rejected/cancelled) still occupies this composite id.
    // Firestore evaluates `set()` on an existing doc against the **update**
    // rule, which only permits `status` and `updated_at` to change — so
    // rewriting it wholesale is denied and re-adding a former friend fails
    // with a bare "couldn't send the request". Clear the stale doc first;
    // the rules let the sender delete their own request, and a re-add is a
    // genuinely new request rather than a mutation of the old one.
    DocumentSnapshot<Map<String, dynamic>>? prior;
    try {
      prior = await _requests.doc(requestId).get().timeout(_firestoreTimeout);
    } catch (e, st) {
      _mapFirestoreError(e, st, 'sendRequest.checkPrior');
    }
    if (prior.exists) {
      final r = FriendRequest.fromJson(prior.data()!);
      if (r.status == FriendRequestStatus.pending) {
        // Already waiting on them — say so rather than silently resending.
        throw const FriendActionException(
          "You already asked them. They haven't answered yet.",
        );
      }
      if (r.status == FriendRequestStatus.awaitingParent) {
        // Deleting it would throw away a parent's yes already given.
        throw const FriendActionException(
          "You're almost friends — a grown-up still needs to say yes.",
        );
      }
      try {
        await _requests.doc(requestId).delete().timeout(_firestoreTimeout);
      } catch (e, st) {
        _mapFirestoreError(e, st, 'sendRequest.clearStale');
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
      // A Child's side waits for their parent: the rules let exactly the
      // owner of this home group approve it.
      fromHomeGroupId: needsParentApproval(me) ? me.homeGroupId : null,
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

  /// Whether [profile]'s friendships need a parent's yes: a Child who has
  /// joined a home group. (A Child with no group has no parent in the app
  /// to ask, and every other role decides for themselves.)
  static bool needsParentApproval(UserProfile profile) =>
      profile.role == UserRole.child &&
      (profile.homeGroupId?.isNotEmpty ?? false);

  /// A Child in no family group: there is no parent in the app who could
  /// approve a friendship, so the rules refuse every one.
  static bool isChildWithoutGroup(UserProfile profile) =>
      profile.role == UserRole.child &&
      !(profile.homeGroupId?.isNotEmpty ?? false);

  /// Recipient accepts a pending request.
  ///
  /// When no parent needs asking, writes the friendships doc and marks the
  /// request `accepted` in a single batch, as before. When a Child is on
  /// either side and their parent has not said yes, the request moves to
  /// `awaiting_parent` instead — the friendship is made once every parent
  /// involved approves (see [finishApproved]).
  Future<AcceptOutcome> acceptRequest({
    required UserProfile me,
    required String requestId,
  }) async {
    if (!FirebaseService.isConfigured) return AcceptOutcome.failed;
    if (isChildWithoutGroup(me)) return AcceptOutcome.needsGroup;
    try {
      final doc = await _requests.doc(requestId).get();
      if (!doc.exists) return AcceptOutcome.failed;
      final r = FriendRequest.fromJson(doc.data()!);
      if (r.status != FriendRequestStatus.pending) return AcceptOutcome.failed;
      if (r.toProfileId != me.id && r.fromProfileId != me.id) {
        // Not addressed to us — refuse silently.
        return AcceptOutcome.failed;
      }

      final toGroup = r.toProfileId == me.id && needsParentApproval(me)
          ? me.homeGroupId
          : r.toHomeGroupId;
      final waits = r.fromNeedsParent ||
          ((toGroup?.isNotEmpty ?? false) && !r.toApproved);
      if (waits) {
        await _requests.doc(requestId).update({
          'status': FriendRequestStatus.awaitingParent.wire,
          'updated_at': DateTime.now().toIso8601String(),
          'to_home_group_id': ?toGroup,
        });
        return AcceptOutcome.awaitingParent;
      }

      await _makeFriends(r);
      return AcceptOutcome.accepted;
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.acceptRequest');
      return AcceptOutcome.failed;
    }
  }

  /// Writes the friendship and marks [r] accepted, in one batch.
  Future<void> _makeFriends(FriendRequest r) async {
    final fid = Friendship.makeId(r.fromProfileId, r.toProfileId);
    final aFirst = r.fromProfileId.compareTo(r.toProfileId) <= 0;
    final friendship = Friendship(
      id: fid,
      profileA: aFirst ? r.fromProfileId : r.toProfileId,
      profileB: aFirst ? r.toProfileId : r.fromProfileId,
      createdAt: DateTime.now(),
    );
    final batch = FirebaseService.db.batch();
    // `request_id` lets the rules check a Child's parent really said yes —
    // the friendship is refused otherwise.
    batch.set(_friendships.doc(fid), {...friendship.toJson(), 'request_id': r.id});
    batch.update(_requests.doc(r.id), {
      'status': FriendRequestStatus.accepted.wire,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await batch.commit();
  }

  /// Makes the friendship for a request every parent has now approved.
  ///
  /// A parent cannot write the friendship themselves (only the two learners'
  /// devices may), so whichever learner's device sees the approval first
  /// finishes it. Both may try; the second finds the friendship already
  /// there and only marks the request done. Never throws.
  Future<void> finishApproved(UserProfile me, FriendRequest r) async {
    if (!FirebaseService.isConfigured || !r.readyToFinish) return;
    if (r.fromProfileId != me.id && r.toProfileId != me.id) return;
    try {
      final fid = Friendship.makeId(r.fromProfileId, r.toProfileId);
      final existing = await _friendships.doc(fid).get();
      if (existing.exists) {
        await _requests.doc(r.id).update({
          'status': FriendRequestStatus.accepted.wire,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _makeFriends(r);
      }
    } catch (e, st) {
      ErrorHandler.report(e, st, 'FriendService.finishApproved:silent');
    }
  }

  /// A parent says yes to their child's side of [r] — whichever side is
  /// theirs ([myGroupIds] are the home groups they own).
  Future<void> approveAsParent(FriendRequest r, Set<String> myGroupIds) async {
    if (!FirebaseService.isConfigured) return;
    final from = r.fromHomeGroupId;
    final to = r.toHomeGroupId;
    _unawaited(
      _requests.doc(r.id).update({
        if (from != null && myGroupIds.contains(from)) 'from_approved': true,
        if (to != null && myGroupIds.contains(to)) 'to_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }),
      'FriendService.approveAsParent',
    );
  }

  /// A parent says no. The request closes for both learners.
  Future<void> declineAsParent(FriendRequest r) async {
    if (!FirebaseService.isConfigured) return;
    _unawaited(
      _requests.doc(r.id).update({
        'status': FriendRequestStatus.parentDeclined.wire,
        'updated_at': DateTime.now().toIso8601String(),
      }),
      'FriendService.declineAsParent',
    );
  }

  /// Requests waiting on a parent who owns [groupIds]: their child asked
  /// someone, or their child said yes to someone. Two single-field queries
  /// (one per side) merged here, so no composite index is needed.
  Stream<List<FriendRequest>> watchApprovals(Set<String> groupIds) {
    if (!FirebaseService.isConfigured || groupIds.isEmpty) {
      return Stream.value(const <FriendRequest>[]);
    }
    // `whereIn` takes at most 30 values; a parent owns a handful of groups.
    final ids = groupIds.take(30).toList();
    final controller = StreamController<List<FriendRequest>>.broadcast();
    var fromSide = <FriendRequest>[];
    var toSide = <FriendRequest>[];
    void emit() {
      final byId = <String, FriendRequest>{
        for (final r in [...fromSide, ...toSide]) r.id: r,
      };
      final open = byId.values.where((r) => r.awaitsParentIn(groupIds)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(open);
    }

    List<FriendRequest> decode(QuerySnapshot<Map<String, dynamic>> snap) =>
        snap.docs.map((d) => FriendRequest.fromJson(d.data())).toList();

    final a = _requests
        .where('from_home_group_id', whereIn: ids)
        .snapshots()
        .listen(
          (snap) {
            fromSide = decode(snap);
            emit();
          },
          onError: (e, st) =>
              ErrorHandler.report(e, st, 'FriendService.watchApprovals'),
        );
    final b = _requests
        .where('to_home_group_id', whereIn: ids)
        .snapshots()
        .listen(
          (snap) {
            toSide = decode(snap);
            emit();
          },
          onError: (e, st) =>
              ErrorHandler.report(e, st, 'FriendService.watchApprovals'),
        );
    controller.onCancel = () async {
      await a.cancel();
      await b.cancel();
    };
    return controller.stream;
  }

  Future<void> rejectRequest(String requestId) async {
    if (!FirebaseService.isConfigured) return;
    _unawaited(
      _requests.doc(requestId).update({
        'status': FriendRequestStatus.rejected.wire,
        'updated_at': DateTime.now().toIso8601String(),
      }),
      'FriendService.rejectRequest',
    );
  }

  /// Sender cancels their own outgoing request.
  Future<void> cancelRequest(String requestId) async {
    if (!FirebaseService.isConfigured) return;
    _unawaited(
      _requests.doc(requestId).update({
        'status': FriendRequestStatus.cancelled.wire,
        'updated_at': DateTime.now().toIso8601String(),
      }),
      'FriendService.cancelRequest',
    );
  }

  /// [quiet] is for the unfriend that rides along with a block: the peer is
  /// often not a friend any more (a history-only thread, a second block after
  /// an unblock), and the rules refuse to delete a friendship doc that does
  /// not exist — which put "Something went wrong" over a block that had in
  /// fact worked.
  Future<void> removeFriend({
    required String myProfileId,
    required String friendProfileId,
    bool quiet = false,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final fid = Friendship.makeId(myProfileId, friendProfileId);
    final doc = _friendships.doc(fid);
    // ignore: discarded_futures
    doc.delete().catchError((Object e, StackTrace st) async {
      // The rules refuse to delete a friendship that is not there, and a
      // friends list paints from the local cache first — so for a moment it
      // can offer "Remove friend" for a friendship the other side (or
      // another tablet) already ended. That is not a failure: the friendship
      // is gone either way. Only a refusal while it still exists is reported.
      if (e is FirebaseException && e.code == 'permission-denied') {
        try {
          final snap = await doc.get(const GetOptions(source: Source.server));
          if (!snap.exists) return;
        } catch (_) {
          // Could not check — report the original refusal below.
        }
      }
      ErrorHandler.report(
        e,
        st,
        quiet ? 'FriendService.blockUnfriend:silent' : 'FriendService.removeFriend',
      );
    });
  }

  /// Hand a Firestore write to the SDK without waiting for the server.
  ///
  /// A write made offline does not complete until the device reconnects, so
  /// awaiting it left the Block / Remove / Report sheet spinning for as long
  /// as a classroom tablet stayed offline. Firestore applies the write to its
  /// local cache at once — every listener (the inbox, the blocked list) sees
  /// it immediately — and delivers it when the network returns.
  static void _unawaited(Future<void> write, String source) {
    // ignore: discarded_futures
    write.catchError((Object e, StackTrace st) {
      ErrorHandler.report(e, st, source);
    });
  }

  /// Mirror a block into the Hive cache straight away, so a relaunch before
  /// the server round-trip still hides the peer.
  Future<void> _cacheBlocked(
    String myProfileId,
    String blockedProfileId, {
    required bool blocked,
  }) async {
    try {
      final ids = HiveService.getBlockedProfiles(myProfileId).toSet();
      if (blocked) {
        ids.add(blockedProfileId);
      } else {
        ids.remove(blockedProfileId);
      }
      await HiveService.saveBlockedProfiles(myProfileId, ids.toList());
    } catch (_) {
      // No cache box (tests) — the Firestore listener still carries it.
    }
  }

  // ─── Blocking & reporting ─────────────────────────────

  /// Doc id for "[blocker] has blocked [blocked]". Directional on purpose —
  /// blocking is one-sided and must not be inferable in reverse.
  static String blockId(String blocker, String blocked) =>
      '${blocker}_$blocked';

  /// Block [blockedProfileId]: drops the friendship (so they leave the inbox
  /// on both sides) and records the block so they can't come back via a new
  /// friend request.
  ///
  /// The block doc is what [watchBlocked] filters the conversation directory
  /// with, so the peer disappears locally even before the friendship delete
  /// round-trips.
  Future<void> blockUser({
    required String myProfileId,
    required String blockedProfileId,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    await _cacheBlocked(myProfileId, blockedProfileId, blocked: true);
    _unawaited(
      _blocks.doc(blockId(myProfileId, blockedProfileId)).set({
        'blocker_profile_id': myProfileId,
        'blocked_profile_id': blockedProfileId,
        'blocker_uid': uid,
        'created_at': DateTime.now().toIso8601String(),
      }),
      'FriendService.blockUser',
    );
    // Unfriending is best-effort and separate: a block must stick even if the
    // friendship delete is denied or the doc never existed.
    await removeFriend(
      myProfileId: myProfileId,
      friendProfileId: blockedProfileId,
      quiet: true,
    );
  }

  Future<void> unblockUser({
    required String myProfileId,
    required String blockedProfileId,
  }) async {
    if (!FirebaseService.isConfigured) return;
    await _cacheBlocked(myProfileId, blockedProfileId, blocked: false);
    _unawaited(
      _blocks.doc(blockId(myProfileId, blockedProfileId)).delete(),
      'FriendService.unblockUser',
    );
  }

  /// Live set of profile ids [profileId] has blocked. Emits the Hive cache
  /// first so a blocked peer never flashes back into the inbox on cold start.
  Stream<Set<String>> watchBlocked(String profileId) {
    final cached = HiveService.getBlockedProfiles(profileId).toSet();
    if (!FirebaseService.isConfigured) return Stream.value(cached);

    final controller = StreamController<Set<String>>.broadcast();
    controller.add(cached);
    final sub = _blocks
        .where('blocker_profile_id', isEqualTo: profileId)
        .snapshots()
        .listen(
          (snap) {
            final ids = snap.docs
                .map((d) => d.data()['blocked_profile_id'] as String? ?? '')
                .where((id) => id.isNotEmpty)
                .toSet();
            // ignore: discarded_futures
            HiveService.saveBlockedProfiles(profileId, ids.toList());
            controller.add(ids);
          },
          onError: (e, st) {
            // Logged for the developer, never surfaced: see the matching entry in
            // ErrorHandler._silentSources. Until the `blocks` rules are deployed
            // this denies on every Messages open, and the Hive cache below still
            // enforces whatever the learner has already blocked.
            ErrorHandler.report(e, st, 'FriendService.watchBlocked:silent');
            if (!controller.isClosed) controller.add(cached);
          },
        );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// File a safeguarding report about [reportedProfileId].
  ///
  /// The report lands in `message_reports` for a grown-up to review. When
  /// [alsoBlock] is true the peer is blocked immediately too, so a child
  /// doesn't have to wait out the review to stop receiving messages.
  ///
  /// **[alsoBlock] must be false for a classroom educator.** Auto-blocking
  /// there would quietly cut the child off from their own teacher — the exact
  /// person the class depends on — and, because the educator relationship
  /// comes from the classroom rather than a friendship, the child could not
  /// undo it from the peer sheet. Reports about an adult are for a grown-up
  /// to act on, not for the app to silently enforce.
  Future<void> reportUser({
    required String myProfileId,
    required String myDisplayName,
    required String reportedProfileId,
    required String reportedDisplayName,
    required String reason,
    required bool alsoBlock,
    String? lastMessageContent,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    _unawaited(
      _reports
          .add({
            'reporter_profile_id': myProfileId,
            'reporter_display_name': myDisplayName,
            'reporter_uid': uid,
            'reported_profile_id': reportedProfileId,
            'reported_display_name': reportedDisplayName,
            'reason': reason,
            'sample_message': ?lastMessageContent,
            'created_at': DateTime.now().toIso8601String(),
          })
          .then((_) {}),
      'FriendService.reportUser',
    );
    if (!alsoBlock) return;
    await blockUser(
      myProfileId: myProfileId,
      blockedProfileId: reportedProfileId,
    );
  }

  /// Classmates (and home-group siblings) [me] could ask to be friends,
  /// already resolved to directory entries so the dialog can offer them by
  /// name with one tap.
  ///
  /// Adding a friend used to mean typing a handle like
  /// `hearingimpairmentstudent-6571` — a real barrier for a seven-year-old,
  /// and a wall for a learner who cannot type at all. The people in the same
  /// class are the friends a child actually has, and the class is also the
  /// safest pool to suggest from: every one of them was let in by a teacher
  /// or parent's code.
  ///
  /// Excludes [me], existing friends, anyone [me] has blocked, and
  /// educators (who are already in the inbox through the class). Best
  /// effort: a failed or offline read returns what it could resolve, never
  /// throws.
  Future<List<DirectoryEntry>> suggestClassmates(UserProfile me) async {
    final ids = <String>{};
    if (FirebaseService.isConfigured) {
      Future<void> collect(
        String collection,
        String field,
        String? groupId,
      ) async {
        if (groupId == null || groupId.isEmpty) return;
        try {
          final snap = await FirebaseService.db
              .collection(collection)
              .where(field, isEqualTo: groupId)
              .get()
              .timeout(_firestoreTimeout);
          for (final doc in snap.docs) {
            final id = doc.data()['profile_id'] as String?;
            if (id != null && id.isNotEmpty) ids.add(id);
          }
        } catch (e, st) {
          ErrorHandler.report(e, st, 'FriendService.suggestClassmates:silent');
        }
      }

      await collect('classroom_members', 'classroom_id', me.classroomId);
      await collect('home_group_members', 'home_group_id', me.homeGroupId);
    }
    ids.remove(me.id);
    if (ids.isEmpty) return const [];

    try {
      ids.removeAll(_cachedFriends(me.id).map((f) => f.otherProfileFor(me.id)));
      ids.removeAll(HiveService.getBlockedProfiles(me.id));
    } catch (_) {
      // No cache box open — suggest from the membership alone; a request to
      // an existing friend is answered with "You're already friends".
    }

    final resolved = await ProfileDirectoryService.instance.lookupMany(ids);
    final out = resolved.values.where((e) {
      final role = roleSlugFromIndex(e.roleIndex);
      return role != 'teacher' && role != 'parent' && e.username.isNotEmpty;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  // ─── Streams ──────────────────────────────────────────

  /// Live list of pending requests [profileId] has **sent** and can still
  /// cancel. Without this the sender had no record that a request existed —
  /// they'd re-send into a "you already asked" void.
  Stream<List<FriendRequest>> watchOutgoingRequests(String profileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(const <FriendRequest>[]);
    }
    final controller = StreamController<List<FriendRequest>>.broadcast();
    // Single-field query, filtered here: an open request is `pending` or
    // `awaiting_parent`, and a two-field query would need a composite index.
    final sub = _requests
        .where('from_profile_id', isEqualTo: profileId)
        .snapshots()
        .listen(
          (snap) {
            final list =
                snap.docs
                    .map((d) => FriendRequest.fromJson(d.data()))
                    .where((r) => r.isOpen)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            controller.add(list);
          },
          onError: (e, st) {
            ErrorHandler.report(e, st, 'FriendService.watchOutgoingRequests');
          },
        );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// Live list of accepted friendships visible to [profileId]. Merges
  /// two `where` queries client-side (Firestore disallows OR on different
  /// fields) and mirrors every emission to the Hive cache so the next
  /// cold start renders instantly.
  Stream<List<Friendship>> watchFriends(String profileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(_cachedFriends(profileId));
    }

    final a = _friendships.where('profile_a', isEqualTo: profileId).snapshots();
    final b = _friendships.where('profile_b', isEqualTo: profileId).snapshots();

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
        profileId,
        merged.map((f) => f.toJson()).toList(),
      );
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
    // Open requests are `pending` (theirs to answer) or `awaiting_parent`
    // (answered; a grown-up still has to say yes) — filtered here so the
    // query stays single-field.
    final live = _requests
        .where('to_profile_id', isEqualTo: profileId)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map((d) => FriendRequest.fromJson(d.data()))
                  .where((r) => r.isOpen)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          // ignore: discarded_futures
          HiveService.saveFriendRequestsCache(
            profileId,
            list.map((r) => r.toJson()).toList(),
          );
          return list;
        });

    final controller = StreamController<List<FriendRequest>>.broadcast();
    controller.add(cached);
    final sub = live.listen(
      controller.add,
      onError: (e, st) {
        ErrorHandler.report(e, st, 'FriendService.watchIncomingRequests');
      },
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // ─── Internals ────────────────────────────────────────

  List<Friendship> _cachedFriends(String profileId) {
    return HiveService.getFriendsCache(
      profileId,
    ).map(Friendship.fromJson).toList();
  }

  List<FriendRequest> _cachedRequests(String profileId) {
    return HiveService.getFriendRequestsCache(
      profileId,
    ).map(FriendRequest.fromJson).toList();
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
        'Network is slow. Check your connection and try again.',
      );
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      throw const FriendActionException(
        "Couldn't reach the friend service. If this keeps happening, "
        'ask your teacher to redeploy the app rules.',
      );
    }
    throw const FriendActionException(
      "Couldn't send the request. Try again in a moment.",
    );
  }
}

/// User-visible failure mode for friend mutations. The message is safe
/// to show in a SnackBar without further translation; localisation can
/// be layered on later.
class FriendActionException implements Exception {
  final String message;
  const FriendActionException(this.message);

  /// [message] in the learner's language.
  String messageOf({required bool filipino}) =>
      filipino ? (_friendErrorFilipino[message] ?? message) : message;

  @override
  String toString() => message;
}

const _friendErrorFilipino = {
  'Cloud sync is not configured on this device.':
      'Hindi naka-set up ang cloud sync sa device na ito.',
  'Sign-in is still warming up. Try again in a moment.':
      'Naghahanda pa ang pag-sign in. Subukan ulit mamaya.',
  'Enter a username or profile ID.': 'Maglagay ng username o profile ID.',
  'No user with that username or ID. Make sure they have opened '
          'Messages on their device at least once.':
      'Walang user na may ganiyang username o ID. Tiyaking nabuksan na nila '
          'ang Mga Mensahe sa kanilang device kahit isang beses.',
  "You can't add yourself.": 'Hindi mo maidadagdag ang sarili mo.',
  "You're already friends.": 'Magkaibigan na kayo.',
  "You already asked them. They haven't answered yet.":
      'Naipadala mo na ang hiling. Hindi pa sila sumasagot.',
  'Network is slow. Check your connection and try again.':
      'Mabagal ang network. Suriin ang koneksyon at subukan ulit.',
  "Couldn't reach the friend service. If this keeps happening, "
          'ask your teacher to redeploy the app rules.':
      'Hindi maabot ang serbisyo ng pakikipagkaibigan. Kung maulit ito, '
          'sabihin sa guro mo.',
  "Couldn't send the request. Try again in a moment.":
      'Hindi maipadala ang hiling. Subukan ulit mamaya.',
  "You're almost friends — a grown-up still needs to say yes.":
      'Halos magkaibigan na kayo — kailangan pang pumayag ng isang nakatatanda.',
  'A grown-up needs to add you to their family group before you can make friends.':
      'Kailangan ka munang idagdag ng isang nakatatanda sa kanilang pamilya bago '
          'ka makipagkaibigan.',
};

/// What happened when a learner said yes to a friend request.
enum AcceptOutcome {
  /// They are friends now.
  accepted,

  /// A Child is involved and their parent has not said yes yet.
  awaitingParent,

  /// Nothing changed (offline, already answered, not theirs).
  failed,

  /// A Child in no family group — no parent in the app can approve.
  needsGroup,
}
