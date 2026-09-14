import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../features/routine/services/routine_reminder_scheduler.dart';
import '../utils/error_handler.dart';
import 'firebase_service.dart';

/// Registers this device for the educator's "needs help" alert.
///
/// The dashboard's own alert only fires while the dashboard is open. The
/// `routineHelpPush` Cloud Function reaches an educator with the app closed by
/// sending to the `push_tokens` recorded here — one per educator profile signed
/// in on this device, carrying the device's language so the alert reads in it.
class EducatorPushService {
  EducatorPushService._();

  static StreamSubscription<String>? _refreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Document id for one educator profile on one device — stable, so
  /// registering again overwrites rather than piling up.
  static String docIdFor(String profileId, String token) =>
      '${profileId}_${sha1.convert(utf8.encode(token))}';

  /// What is stored for the Cloud Function. Pure, so it is tested.
  static Map<String, Object?> recordFor({
    required String profileId,
    required String token,
    required String? ownerUid,
    required bool filipino,
  }) =>
      {
        'token': token,
        'profile_id': profileId,
        'owner_uid': ownerUid,
        'locale': filipino ? 'fil' : 'en',
        'platform': defaultTargetPlatform.name,
      };

  /// Records this device for [educator]. Best-effort: without it the
  /// dashboard's in-app alert still works.
  static Future<void> register(
    UserProfile educator, {
    required bool filipino,
  }) async {
    if (kIsWeb || !FirebaseService.isConfigured) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _save(educator.id, token, filipino);
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(
        (t) => unawaited(_save(educator.id, t, filipino)),
      );
      _foregroundSub ??= FirebaseMessaging.onMessage.listen(_showInApp);
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'EducatorPush:silent');
    }
  }

  static Future<void> _save(String profileId, String token, bool filipino) async {
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    try {
      await FirebaseService.db
          .collection('push_tokens')
          .doc(docIdFor(profileId, token))
          .set({
        ...recordFor(
          profileId: profileId,
          token: token,
          ownerUid: uid,
          filipino: filipino,
        ),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'EducatorPush:silent');
    }
  }

  /// Android shows a push by itself only while the app is in the background.
  /// In front, it is handed to the app, which posts it exactly as the
  /// dashboard does — the same key, so the two replace each other instead of
  /// doubling up.
  static void _showInApp(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'routine_help') return;
    unawaited(
      RoutineReminderScheduler.showHelpAlert(
        key: (data['key'] as String?) ?? '',
        title: (data['title'] as String?) ?? message.notification?.title ?? '',
        body: (data['body'] as String?) ?? message.notification?.body ?? '',
      ),
    );
  }
}
