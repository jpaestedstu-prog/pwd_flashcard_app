import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/child_alarm.dart';

/// Per-child alarm CRUD against Firestore + Hive cache.
///
/// One Firestore document per alarm under `child_alarms/{alarmId}`.
/// Queries by `child_profile_id` for the child-side stream and by
/// `setter_profile_id` for the parent's "alarms I've set" view. Both
/// fields require a single-field index — Firestore creates these
/// automatically the first time a query is run.
class ChildAlarmService {
  const ChildAlarmService();

  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('child_alarms');

  /// One-shot snapshot of every alarm targeting [childProfileId].
  /// Falls back to the Hive cache when offline.
  Future<List<ChildAlarm>> listForChild(String childProfileId) async {
    if (!FirebaseService.isConfigured) {
      return HiveService.getChildAlarmsForChild(childProfileId);
    }
    final snap = await _col
        .where('child_profile_id', isEqualTo: childProfileId)
        .get();
    final alarms = snap.docs
        .map((d) => ChildAlarm.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort(_byTime);
    for (final a in alarms) {
      await HiveService.cacheChildAlarm(a);
    }
    return alarms;
  }

  /// Live stream — used by the child's device through `AlarmScheduler`
  /// so a new alarm pushed by a parent reschedules within seconds.
  Stream<List<ChildAlarm>> watchForChild(String childProfileId) {
    if (!FirebaseService.isConfigured) {
      return Stream.value(
          HiveService.getChildAlarmsForChild(childProfileId));
    }
    return _col
        .where('child_profile_id', isEqualTo: childProfileId)
        .snapshots()
        .map((snap) {
      final alarms = <ChildAlarm>[];
      for (final d in snap.docs) {
        try {
          final a =
              ChildAlarm.fromJson(Map<String, dynamic>.from(d.data()));
          alarms.add(a);
          HiveService.cacheChildAlarm(a);
        } catch (_) {}
      }
      alarms.sort(_byTime);
      return alarms;
    }).handleError((Object e, StackTrace s) {
      // Route stream errors (transient permission-denied during sign-out,
      // network blips) through the silent diagnostics path so the global
      // "Something went wrong" snackbar never lights up for the child's
      // alarm listener. The parent-side editor still raises real failures
      // inline through `save()` / `delete()`.
      ErrorHandler.report(e, s, 'ChildAlarmStream:silent');
    });
  }

  /// One-shot snapshot of every alarm authored by [setterProfileId].
  /// Used by the educator's "All my alarms" view.
  Future<List<ChildAlarm>> listForSetter(String setterProfileId) async {
    if (!FirebaseService.isConfigured) return const [];
    final snap = await _col
        .where('setter_profile_id', isEqualTo: setterProfileId)
        .get();
    final alarms = snap.docs
        .map((d) => ChildAlarm.fromJson(Map<String, dynamic>.from(d.data())))
        .toList()
      ..sort(_byTime);
    return alarms;
  }

  /// Persist [alarm] (creates if [ChildAlarm.id] is empty, else updates).
  /// Returns the saved value with a final id and timestamps.
  Future<ChildAlarm> save(ChildAlarm alarm) async {
    final isNew = alarm.id.isEmpty;
    final now = DateTime.now();
    final saved = alarm.copyWith(
      id: isNew ? _uuid.v4() : alarm.id,
      createdAt: isNew ? now : alarm.createdAt,
      updatedAt: now,
    );
    await HiveService.cacheChildAlarm(saved);
    if (!FirebaseService.isConfigured) return saved;
    final payload = saved.toJson()
      ..['owner_uid'] = FirebaseService.currentUid;
    try {
      await _col.doc(saved.id).set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw Exception('Could not save alarm (${e.code}): ${e.message}');
    }
    return saved;
  }

  /// Permanently remove [alarmId] from Firestore + Hive.
  Future<void> delete(String alarmId) async {
    await HiveService.deleteChildAlarmLocal(alarmId);
    if (!FirebaseService.isConfigured) return;
    try {
      await _col.doc(alarmId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Could not delete alarm (${e.code}): ${e.message}');
    }
  }

  /// Comparator that sorts alarms by enabled (active first), then time
  /// of day (earliest first), then label.
  static int _byTime(ChildAlarm a, ChildAlarm b) {
    if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
    final aMin = a.hour * 60 + a.minute;
    final bMin = b.hour * 60 + b.minute;
    if (aMin != bMin) return aMin.compareTo(bMin);
    return a.label.compareTo(b.label);
  }
}
