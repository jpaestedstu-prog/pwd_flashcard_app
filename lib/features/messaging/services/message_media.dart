import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/shared_media_service.dart';
import '../models/messaging_models.dart';

/// The limits on photos and sign videos in Messages — what keeps them inside
/// the free Spark plan for good.
///
/// The files go through [SharedMediaService] (Firestore pieces, no Cloud
/// Storage), and the free plan holds 1 GiB in total, shared with every
/// assessment picture and routine clip. So message media is small, capped,
/// and temporary:
///
///   * a video is at most [maxVideo] long (about 1.25 MB at the capture
///     screen's 1 Mbit/s); a photo is the camera's medium size;
///   * one profile sends at most [dailyLimit] of them a day;
///   * each is deleted after [retention] by the sender's own tablet
///     ([MessageMediaRetention]) — the message stays, saying the picture
///     has expired.
///
/// Even a class of 30 each sending five 10-second clips every single day
/// would hold about 1.3 GB at the peak of the week; real use (a few a week)
/// is a few megabytes. And on the Spark plan an over-quota write is refused,
/// never billed — there is no billing account to charge.
class MessageMedia {
  const MessageMedia._();

  static const Duration maxVideo = Duration(seconds: 10);
  static const int dailyLimit = 5;
  static const Duration retention = Duration(days: 7);

  /// How many photos and videos [profileId] has sent today.
  static int sentToday(
    Iterable<LocalMessage> messages,
    String profileId, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return messages
        .where(
          (m) =>
              m.isMedia &&
              m.senderId == profileId &&
              m.timestamp.year == t.year &&
              m.timestamp.month == t.month &&
              m.timestamp.day == t.day,
        )
        .length;
  }

  /// Whether [profileId] may send another photo or video today.
  static bool canSendMore(
    Iterable<LocalMessage> messages,
    String profileId, {
    DateTime? now,
  }) => sentToday(messages, profileId, now: now) < dailyLimit;

  /// The message is older than [retention], so its file is gone (or about
  /// to be) — say so rather than "could not load".
  static bool isExpired(LocalMessage message, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(message.timestamp) > retention;
}

/// Deletes this profile's own message photos and videos once they are older
/// than [MessageMedia.retention].
///
/// Runs on the sender's tablet (the rules let only the file's owner delete
/// it), at most once per profile per app session. Never throws; offline it
/// simply does nothing until next time.
class MessageMediaRetention {
  const MessageMediaRetention();

  static final Set<String> _ranFor = {};

  /// Test seam: the files [ownerProfileId] shared, with when and what for.
  @visibleForTesting
  static Future<List<({String id, DateTime? createdAt, String? purpose})>>
  Function(String ownerProfileId)?
  debugOwned;

  @visibleForTesting
  static void resetForTesting() => _ranFor.clear();

  /// Returns how many files it deleted.
  Future<int> run(String profileId, {DateTime? now}) async {
    if (profileId.isEmpty || !_ranFor.add(profileId)) return 0;
    if (!FirebaseService.isConfigured && debugOwned == null) return 0;
    try {
      final owned = await (debugOwned ?? _owned)(profileId);
      final cutoff = (now ?? DateTime.now()).subtract(MessageMedia.retention);
      var removed = 0;
      for (final o in owned) {
        if (o.purpose != SharedMediaMeta.purposeMessage) continue;
        final created = o.createdAt;
        if (created == null || !created.isBefore(cutoff)) continue;
        await const SharedMediaService().delete(
          '${SharedMediaService.prefix}${o.id}',
        );
        removed++;
      }
      return removed;
    } on Object catch (e) {
      if (kDebugMode) debugPrint('MessageMediaRetention skipped: $e');
      // Let a later open try again.
      _ranFor.remove(profileId);
      return 0;
    }
  }

  static Future<List<({String id, DateTime? createdAt, String? purpose})>>
  _owned(String ownerProfileId) async {
    final snap = await FirebaseService.db
        .collection(SharedMediaService.collection)
        .where('owner_profile_id', isEqualTo: ownerProfileId)
        .get(const GetOptions(source: Source.server));
    return [
      for (final d in snap.docs)
        (
          id: d.id,
          createdAt: (d.data()['created_at'] as Timestamp?)?.toDate(),
          purpose: d.data()['purpose'] as String?,
        ),
    ];
  }
}
