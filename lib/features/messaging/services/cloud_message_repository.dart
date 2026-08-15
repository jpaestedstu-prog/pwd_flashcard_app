import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../models/messaging_models.dart';

/// Cloud-backed message repository.
///
/// Replaces the previous Hive-only messaging surface with a Firestore
/// `messages/{id}` top-level collection so peers on different devices can
/// actually talk to each other. Hive is kept as a local cache so the
/// inbox renders instantly on cold start and works fully offline.
///
/// **Schema (Firestore):**
/// ```
/// messages/{messageId}
///   id: string (matches doc id)
///   sender_profile_id: string
///   recipient_profile_id: string
///   sender_name: string
///   content: string
///   type: int (MessageType.index)
///   timestamp: ISO 8601 string
///   sender_uid: string (Firebase Auth uid of the writer)
///   is_read: bool
/// ```
///
/// **Offline writes:** Firestore's built-in offline persistence buffers
/// `set()` calls on disk and replays them when connectivity returns —
/// no separate sync queue entry needed. The local Hive cache is updated
/// synchronously so the UI shows the message immediately regardless of
/// the network round-trip.
///
/// **Free-tier compliance:** Stays well within Spark quota for a pilot
/// classroom of ~30 students at ~20 messages/student/day (≈ 12K writes/
/// day vs. the 20K daily limit; reads via stream listeners ≈ 30K/day vs.
/// 50K limit).
class CloudMessageRepository {
  CloudMessageRepository._();

  static final CloudMessageRepository instance = CloudMessageRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('messages');

  /// Send a message. Writes to Firestore (which queues offline) and
  /// updates the local Hive cache immediately so the sender sees their
  /// own message without waiting for the round-trip.
  ///
  /// Idempotent: the doc id is the message's own [LocalMessage.id], so
  /// retries don't duplicate.
  Future<void> sendMessage(LocalMessage message) async {
    // Update local cache first — UI feedback shouldn't wait on cloud.
    await _persistLocally(message);

    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null) return;

    try {
      await _col.doc(message.id).set({
        'id': message.id,
        'sender_profile_id': message.senderId,
        'recipient_profile_id': message.recipientId,
        'sender_name': message.senderName,
        'content': message.content,
        'type': message.type.index,
        'timestamp': message.timestamp.toIso8601String(),
        'sender_uid': uid,
        'is_read': message.isRead,
      });
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'CloudMessageRepository.sendMessage');
    }
  }

  /// Mark a received message as read. Updates Firestore (so the sender's
  /// dashboard reflects the read state on their next sync) AND the local
  /// Hive cache.
  Future<void> markAsRead(LocalMessage message) async {
    if (message.isRead) return;
    final updated = message.copyWith(isRead: true);
    await _persistLocally(updated);

    if (!FirebaseService.isConfigured) return;
    try {
      await _col.doc(message.id).update({'is_read': true});
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'CloudMessageRepository.markAsRead');
    }
  }

  /// Mark every message [me] has received in one conversation as read, in a
  /// single batched write.
  ///
  /// Called when a thread is opened (and again while it stays open and new
  /// messages land), which is what turns the inbox badge off. Safe to call
  /// with an already-read list — it filters first and no-ops on an empty
  /// result, so an open thread doesn't re-write on every stream emission.
  Future<void> markConversationRead(
    String myProfileId,
    Iterable<LocalMessage> messages,
  ) async {
    final unread = messages
        .where((m) => m.recipientId == myProfileId && !m.isRead)
        .toList();
    if (unread.isEmpty) return;

    for (final message in unread) {
      await _persistLocally(message.copyWith(isRead: true));
    }

    if (!FirebaseService.isConfigured) return;
    try {
      // Firestore caps a batch at 500 writes; a classroom thread never gets
      // near that, but chunking keeps the promise unconditional.
      for (var i = 0; i < unread.length; i += 400) {
        final slice = unread.skip(i).take(400);
        final batch = FirebaseService.db.batch();
        for (final message in slice) {
          batch.update(_col.doc(message.id), {'is_read': true});
        }
        await batch.commit();
      }
    } catch (e, stack) {
      ErrorHandler.report(
        e,
        stack,
        'CloudMessageRepository.markConversationRead',
      );
    }
  }

  /// Unsend: remove a message the caller wrote. Firestore rules already allow
  /// delete by the owner of `sender_profile_id`, so this needs no rule change.
  ///
  /// The local caches of *both* endpoints are pruned so the sender's thread
  /// updates instantly; the recipient's device drops it on the next snapshot.
  Future<void> deleteMessage(LocalMessage message) async {
    for (final profileId in {message.senderId, message.recipientId}) {
      if (profileId.isEmpty) continue;
      try {
        final cached = await HiveService.getMessages(profileId);
        cached.removeWhere((m) => m.id == message.id);
        await HiveService.saveMessages(profileId, cached);
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('CloudMessageRepository.deleteMessage: $e\n$stack');
        }
      }
    }

    if (!FirebaseService.isConfigured) return;
    try {
      await _col.doc(message.id).delete();
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'CloudMessageRepository.deleteMessage');
    }
  }

  /// Watch all messages for which [profileId] is either the sender or
  /// recipient. Returns a continuously updating list ordered by
  /// timestamp ascending.
  ///
  /// Firestore can't OR two `where` clauses, so we run two listeners and
  /// merge them client-side. Each emission also persists the latest
  /// snapshot to Hive so offline reads after a relaunch return the
  /// freshest data we've seen.
  Stream<List<LocalMessage>> watchMessagesFor(String profileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(const <LocalMessage>[]);
    }

    final sent = _col
        .where('sender_profile_id', isEqualTo: profileId)
        .snapshots();
    final received = _col
        .where('recipient_profile_id', isEqualTo: profileId)
        .snapshots();

    final controller = StreamController<List<LocalMessage>>.broadcast();
    List<LocalMessage> sentBuf = const [];
    List<LocalMessage> recvBuf = const [];
    var emitted = false;

    void emit() {
      // Deduplicate by id (defensive — same message can never appear in
      // both streams, but tests + edge cases keep us honest).
      final byId = <String, LocalMessage>{};
      for (final m in sentBuf) {
        byId[m.id] = m;
      }
      for (final m in recvBuf) {
        byId[m.id] = m;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      controller.add(merged);
      // Persist to Hive so the next cold start has the freshest cache.
      // Fire-and-forget — failures here don't block the stream.
      HiveService.saveMessages(profileId, merged);
      emitted = true;
    }

    final subA = sent.listen(
      (snap) {
        sentBuf = snap.docs.map(_decode).toList();
        emit();
      },
      onError: (e, stack) {
        ErrorHandler.report(e, stack, 'CloudMessageRepository.watch.sent');
        // Surface a best-effort emission so the UI doesn't hang on the
        // initial load when the second listener has data.
        if (!emitted) emit();
      },
    );
    final subB = received.listen(
      (snap) {
        recvBuf = snap.docs.map(_decode).toList();
        emit();
      },
      onError: (e, stack) {
        ErrorHandler.report(e, stack, 'CloudMessageRepository.watch.received');
        if (!emitted) emit();
      },
    );

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };

    return controller.stream;
  }

  /// Fast initial paint helper — read whatever Hive has cached for this
  /// profile. Use this in `initState` to show messages immediately while
  /// the Firestore stream warms up.
  Future<List<LocalMessage>> loadCached(String profileId) {
    return HiveService.getMessages(profileId);
  }

  // ─── Internals ────────────────────────────────────────

  LocalMessage _decode(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final r = doc.data();
    return LocalMessage(
      id: r['id'] as String? ?? doc.id,
      senderId: r['sender_profile_id'] as String? ?? '',
      senderName: r['sender_name'] as String? ?? '',
      recipientId: r['recipient_profile_id'] as String? ?? '',
      content: r['content'] as String? ?? '',
      type:
          MessageType.values[(r['type'] as int? ?? 0).clamp(
            0,
            MessageType.values.length - 1,
          )],
      timestamp:
          DateTime.tryParse(r['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: r['is_read'] as bool? ?? false,
    );
  }

  /// Upsert the message into the per-profile Hive list. Keeps the cache
  /// monotonically growing — Firestore is the source of truth, Hive is
  /// the disposable mirror.
  Future<void> _persistLocally(LocalMessage message) async {
    // We mirror to BOTH endpoints' caches because on the sender's device
    // the conversation thread is keyed by the sender's profile id, and
    // on the recipient's device by theirs. Without this dual-write the
    // sender's "Sent" list wouldn't include the new message until the
    // Firestore stream emits.
    for (final profileId in {message.senderId, message.recipientId}) {
      if (profileId.isEmpty) continue;
      try {
        final cached = await HiveService.getMessages(profileId);
        final idx = cached.indexWhere((m) => m.id == message.id);
        if (idx >= 0) {
          cached[idx] = message;
        } else {
          cached.add(message);
        }
        await HiveService.saveMessages(profileId, cached);
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('CloudMessageRepository._persistLocally: $e\n$stack');
        }
      }
    }
  }
}
