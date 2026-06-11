import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../models/multiplayer_models.dart';

const _uuid = Uuid();

/// Cross-device "Play Together" backend.
///
/// All persistence lives in Firestore (free Spark tier) — no Cloud Functions,
/// no composite indexes (invite discovery uses a single-field equality query,
/// matching the deliberate constraint documented in [CloudMessageRepository]).
///
/// **Schema:**
/// ```
/// game_rooms/{roomId}
///   id, host_profile_id, host_name, host_uid, host_avatar_index,
///   guest_profile_id?, guest_name?, guest_avatar_index?,
///   invited_profile_id, mode, status, rounds,
///   questions[], memory_layout[], created_at, updated_at, owner_uid
///
/// game_rooms/{roomId}/players/{profileId}
///   profile_id, name, avatar_index, score, progress, finished,
///   owner_uid, updated_at
/// ```
///
/// Design: the host writes the identical game content into the room; both
/// players race their own copy and write only their own `players/{id}` doc.
/// Both clients watch the room + all player docs for live opponent progress.
/// When both players are `finished`, the winner is computed client-side.
class MultiplayerService {
  MultiplayerService._();

  static final MultiplayerService instance = MultiplayerService._();

  /// Bounded wait for any Firestore round-trip so an unreachable server can't
  /// freeze the lobby.
  static const Duration _timeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _rooms =>
      FirebaseService.db.collection('game_rooms');

  CollectionReference<Map<String, dynamic>> _players(String roomId) =>
      _rooms.doc(roomId).collection('players');

  /// Whether online play is possible right now. The lobby hides the online
  /// section (keeping same-device play) when this is false.
  bool get isOnlineAvailable => FirebaseService.isConfigured;

  // ─── Mutations ────────────────────────────────────────

  /// Host a new online match and invite [invitedProfileId]. Writes the room
  /// doc (status `waiting`) plus the host's own player doc, then returns the
  /// created [GameRoom]. Throws [MpActionException] on user-visible failures.
  Future<GameRoom> createRoom({
    required UserProfile me,
    required MpGameMode mode,
    required String invitedProfileId,
    required int rounds,
    List<MpQuestion> questions = const [],
    List<MemoryCardSpec> memoryLayout = const [],
    List<MpScrambleItem> scrambleItems = const [],
  }) async {
    final uid = _requireUid();
    final now = DateTime.now();
    final room = GameRoom(
      id: _uuid.v4(),
      hostProfileId: me.id,
      hostName: me.name,
      hostUid: uid,
      hostAvatarIndex: me.avatarIndex,
      invitedProfileId: invitedProfileId,
      mode: mode,
      status: GameRoomStatus.waiting,
      rounds: rounds,
      questions: questions,
      memoryLayout: memoryLayout,
      scrambleItems: scrambleItems,
      createdAt: now,
      updatedAt: now,
      ownerUid: uid,
    );

    try {
      await _rooms.doc(room.id).set(room.toJson()).timeout(_timeout);
      await _writePlayer(
        roomId: room.id,
        me: me,
        uid: uid,
        score: 0,
        progress: 0,
        finished: false,
      ).timeout(_timeout);
    } catch (e, st) {
      _mapError(e, st, 'createRoom');
    }
    return room;
  }

  /// Guest accepts an invite: stamps the guest fields, flips the room to
  /// `active`, and writes the guest's player doc.
  Future<void> joinRoom({
    required GameRoom room,
    required UserProfile me,
  }) async {
    final uid = _requireUid();
    if (room.hasGuest && room.guestProfileId != me.id) {
      throw const MpActionException(
          'This game already has another player.');
    }
    try {
      await _rooms.doc(room.id).update({
        'guest_profile_id': me.id,
        'guest_name': me.name,
        'guest_avatar_index': me.avatarIndex,
        'status': GameRoomStatus.active.wire,
        'updated_at': DateTime.now().toIso8601String(),
      }).timeout(_timeout);
      await _writePlayer(
        roomId: room.id,
        me: me,
        uid: uid,
        score: 0,
        progress: 0,
        finished: false,
      ).timeout(_timeout);
    } catch (e, st) {
      _mapError(e, st, 'joinRoom');
    }
  }

  /// Upsert this device's live score/progress. Fire-and-forget friendly —
  /// failures are logged, never thrown, so a flaky network can't interrupt
  /// gameplay.
  Future<void> submitProgress({
    required String roomId,
    required UserProfile me,
    required int score,
    required int progress,
    bool finished = false,
  }) async {
    final uid = FirebaseService.currentUid;
    if (!isOnlineAvailable || uid == null) return;
    try {
      await _writePlayer(
        roomId: roomId,
        me: me,
        uid: uid,
        score: score,
        progress: progress,
        finished: finished,
      );
    } catch (e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.submitProgress');
    }
  }

  /// Mark this device's player as finished with its final [score].
  Future<void> finishMatch({
    required String roomId,
    required UserProfile me,
    required int score,
    required int progress,
  }) =>
      submitProgress(
        roomId: roomId,
        me: me,
        score: score,
        progress: progress,
        finished: true,
      );

  /// Flag the room as cancelled so the other player is notified. Callable by
  /// either participant. Best-effort — the room may already have been deleted
  /// (e.g. the host purged it after the match, or the opponent left first), in
  /// which case the update is a harmless no-op rather than an error.
  Future<void> cancelRoom(String roomId) async {
    if (!isOnlineAvailable) return;
    try {
      await _rooms.doc(roomId).update({
        'status': GameRoomStatus.cancelled.wire,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e, st) {
      // 'not-found' (doc already deleted) and 'permission-denied' (rule can't
      // evaluate a missing doc) are expected when the room is already gone.
      // Don't surface these — cancellation is best-effort cleanup.
      if (e.code != 'not-found' && e.code != 'permission-denied') {
        ErrorHandler.report(e, st, 'MultiplayerService.cancelRoom');
      }
    } catch (e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.cancelRoom');
    }
  }

  /// Host-only cleanup: delete the player docs then the room doc so finished /
  /// abandoned rooms don't accumulate. Best-effort.
  Future<void> purgeRoom(String roomId) async {
    if (!isOnlineAvailable) return;
    try {
      final players = await _players(roomId).get();
      for (final d in players.docs) {
        await d.reference.delete();
      }
      await _rooms.doc(roomId).delete();
    } catch (e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.purgeRoom');
    }
  }

  // ─── Streams ──────────────────────────────────────────

  /// Live list of pending game invites addressed to [profileId]. Uses a
  /// single-field equality query (no composite index) and filters to
  /// `waiting` rooms client-side.
  Stream<List<GameRoom>> watchIncomingInvites(String profileId) {
    if (!isOnlineAvailable) {
      return Stream.value(const <GameRoom>[]);
    }
    final controller = StreamController<List<GameRoom>>.broadcast();
    final sub = _rooms
        .where('invited_profile_id', isEqualTo: profileId)
        .snapshots()
        .listen((snap) {
      final rooms = snap.docs
          .map((d) => GameRoom.fromJson(d.data()))
          .where((r) => r.status == GameRoomStatus.waiting)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(rooms);
    }, onError: (e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.watchIncomingInvites');
      if (!controller.isClosed) controller.add(const []);
    });
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// Live view of a single room (null when the doc is gone).
  Stream<GameRoom?> watchRoom(String roomId) {
    if (!isOnlineAvailable) return Stream.value(null);
    return _rooms.doc(roomId).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : GameRoom.fromJson(data);
    }).handleError((e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.watchRoom');
    });
  }

  /// Live list of player states in a room (both racers).
  Stream<List<MpPlayerState>> watchPlayers(String roomId) {
    if (!isOnlineAvailable) return Stream.value(const <MpPlayerState>[]);
    return _players(roomId).snapshots().map((snap) {
      return snap.docs.map((d) => MpPlayerState.fromJson(d.data())).toList();
    }).handleError((e, st) {
      ErrorHandler.report(e, st, 'MultiplayerService.watchPlayers');
    });
  }

  // ─── Internals ────────────────────────────────────────

  Future<void> _writePlayer({
    required String roomId,
    required UserProfile me,
    required String uid,
    required int score,
    required int progress,
    required bool finished,
  }) {
    final state = MpPlayerState(
      profileId: me.id,
      name: me.name,
      avatarIndex: me.avatarIndex,
      score: score,
      progress: progress,
      finished: finished,
      ownerUid: uid,
      updatedAt: DateTime.now(),
    );
    return _players(roomId)
        .doc(me.id)
        .set(state.toJson(), SetOptions(merge: true));
  }

  String _requireUid() {
    if (!isOnlineAvailable) {
      throw const MpActionException(
          'Online play needs an internet connection.');
    }
    final uid = FirebaseService.currentUid;
    if (uid == null) {
      throw const MpActionException(
          'Sign-in is still warming up. Try again in a moment.');
    }
    return uid;
  }

  /// Translate a raw Firestore failure into a user-facing [MpActionException]
  /// and always throw. Declared `Never` so the analyzer treats post-call flow
  /// as unreachable.
  Never _mapError(Object e, StackTrace st, String label) {
    ErrorHandler.report(e, st, 'MultiplayerService.$label');
    if (e is MpActionException) throw e;
    if (e is TimeoutException) {
      throw const MpActionException(
          'Network is slow. Check your connection and try again.');
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      throw const MpActionException(
          "Couldn't reach the game service. If this keeps happening, ask "
          'your teacher to redeploy the app rules.');
    }
    throw const MpActionException(
        "Couldn't start the game. Try again in a moment.");
  }
}

/// User-visible failure for multiplayer mutations. Safe to show in a SnackBar.
class MpActionException implements Exception {
  final String message;
  const MpActionException(this.message);

  @override
  String toString() => message;
}
