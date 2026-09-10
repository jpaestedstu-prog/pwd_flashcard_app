import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../models/routine_models.dart';

/// Per-learner routine CRUD against Firestore with a Hive mirror.
///
/// One document per routine under `routines/{routineId}`, queried by
/// `child_profile_id` for the learner's own view and by `setter_profile_id`
/// for an educator's "routines I've set" list. Both are single-field indexes,
/// which Firestore creates automatically on first use.
///
/// Deliberately the same shape as `ChildAlarmService` — an educator surface
/// that reads a per-child collection written by whoever owns the setter
/// profile. The differences are the two that matter here:
///
///  * **Every read falls back to the cache**, not just the offline one. A
///    routine is the learner's picture of their day; a spinner where the day
///    should be is a failure state for a child who cannot read an error.
///  * **Completion is written by the learner's device** (see [toggleStep]),
///    so the day log has its own collection with its own rules rather than
///    living inside the routine document, which only educators may write.
/// A saved routine plus whether the save actually reached the cloud.
class RoutineWrite {
  final Routine routine;
  final CloudSyncOutcome outcome;

  const RoutineWrite(this.routine, this.outcome);
}

class RoutineService {
  const RoutineService();

  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.db.collection('routines');

  CollectionReference<Map<String, dynamic>> get _logCol =>
      FirebaseService.db.collection('routine_logs');

  String newId() => _uuid.v4();

  // ─── Routines ─────────────────────────────────────────

  /// One-shot snapshot of every routine for [childProfileId], cache-first on
  /// failure.
  Future<List<Routine>> listForChild(String childProfileId) async {
    if (!FirebaseService.isConfigured) {
      return _sorted(HiveService.getRoutinesForChild(childProfileId));
    }
    try {
      final snap =
          await _col.where('child_profile_id', isEqualTo: childProfileId).get();
      final routines = snap.docs
          .map((d) => Routine.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();
      for (final r in routines) {
        await HiveService.cacheRoutine(r);
      }
      await HiveService.pruneRoutinesForChild(
        childProfileId,
        routines.map((r) => r.id).toSet(),
      );
      return _sorted(routines);
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineList:silent');
      return _sorted(HiveService.getRoutinesForChild(childProfileId));
    }
  }

  /// Live stream of every routine for [childProfileId].
  ///
  /// Seeded with the Hive mirror so the first frame has the learner's day on
  /// it, then replaced by Firestore. Stream errors are reported silently and
  /// the cache is re-emitted: a transient permission-denied during a profile
  /// switch must not blank a child's schedule or light the global
  /// "Something went wrong" snackbar.
  Stream<List<Routine>> watchForChild(String childProfileId) {
    final cached = _sorted(HiveService.getRoutinesForChild(childProfileId));
    if (!FirebaseService.isConfigured) return Stream.value(cached);

    final controller = StreamController<List<Routine>>();
    controller.add(cached);
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      sub = _col
          .where('child_profile_id', isEqualTo: childProfileId)
          .snapshots()
          .listen(
        (snap) {
          final routines = <Routine>[];
          for (final d in snap.docs) {
            try {
              final r = Routine.fromJson(Map<String, dynamic>.from(d.data()));
              routines.add(r);
              HiveService.cacheRoutine(r);
            } catch (_) {}
          }
          HiveService.pruneRoutinesForChild(
            childProfileId,
            routines.map((r) => r.id).toSet(),
          );
          if (!controller.isClosed) controller.add(_sorted(routines));
        },
        onError: (Object e, StackTrace s) {
          ErrorHandler.report(e, s, 'RoutineStream:silent');
          if (!controller.isClosed) {
            controller.add(_sorted(
              HiveService.getRoutinesForChild(childProfileId),
            ));
          }
        },
      );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  /// Every routine authored by [setterProfileId], for an educator's overview.
  Future<List<Routine>> listForSetter(String setterProfileId) async {
    if (!FirebaseService.isConfigured) return const [];
    try {
      final snap = await _col
          .where('setter_profile_id', isEqualTo: setterProfileId)
          .get();
      return _sorted(
        snap.docs
            .map((d) => Routine.fromJson(Map<String, dynamic>.from(d.data())))
            .toList(),
      );
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineSetterList:silent');
      return const [];
    }
  }

  /// Persist [routine] (creates when [Routine.id] is empty, else updates).
  ///
  /// The local mirror is written **first and unconditionally**, so an educator
  /// editing a routine on a classroom's flaky Wi-Fi still sees their change,
  /// and the learner's device on the same account picks it up from the cache.
  ///
  /// Returns the saved value *and* whether it actually reached the cloud.
  /// This used to throw on a rule rejection, which the UI turned into the
  /// global "Something went wrong" snackbar — the worst possible answer,
  /// because the two failures underneath it need opposite responses from the
  /// educator. A [CloudSyncOutcome.localOnly] routine is on its way; a
  /// [CloudSyncOutcome.notOwner] routine will never reach the learner's
  /// device until the profile is restored back here, and telling someone to
  /// check their wifi in that case sends them the wrong way for good.
  Future<RoutineWrite> save(Routine routine) async {
    final isNew = routine.id.isEmpty;
    final now = DateTime.now();
    final saved = routine.copyWith(
      id: isNew ? _uuid.v4() : routine.id,
      createdAt: isNew ? now : routine.createdAt,
      updatedAt: now,
    );
    await HiveService.cacheRoutine(saved);
    if (!FirebaseService.isConfigured) {
      return RoutineWrite(saved, CloudSyncOutcome.localOnly);
    }
    final payload = saved.toJson()..['owner_uid'] = FirebaseService.currentUid;
    try {
      await _col.doc(saved.id).set(payload, SetOptions(merge: true));
      return RoutineWrite(saved, CloudSyncOutcome.synced);
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineSave:silent');
      return RoutineWrite(saved, outcomeForError(e));
    }
  }

  /// Permanently remove [routineId] from Firestore + Hive.
  ///
  /// A [CloudSyncOutcome.notOwner] delete is the one that bites hardest: the
  /// row vanishes from the educator's list, survives in Firestore, and comes
  /// back on the device that owns the profile. Saying so is the whole point.
  Future<CloudSyncOutcome> delete(String routineId) async {
    await HiveService.deleteRoutineLocal(routineId);
    if (!FirebaseService.isConfigured) return CloudSyncOutcome.localOnly;
    try {
      await _col.doc(routineId).delete();
      return CloudSyncOutcome.synced;
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineDelete:silent');
      return outcomeForError(e);
    }
  }

  // ─── Day logs (completion) ────────────────────────────

  /// Today's (or [day]'s) completion for [profileId].
  ///
  /// Local first, then Firestore merged in: the learner's own device is the
  /// authority on what they ticked, and a cloud read that fails must never
  /// erase a tick made offline.
  Future<RoutineDayLog> dayLog(String profileId, DateTime day) async {
    final local = HiveService.getRoutineDayLog(profileId, day);
    if (!FirebaseService.isConfigured) return local;
    try {
      final doc = await _logCol.doc(dayKeyFor(profileId, day)).get();
      final data = doc.data();
      if (data == null) return local;
      final remote = RoutineDayLog.fromJson(Map<String, dynamic>.from(data));
      final merged = _mergeLogs(local, remote);
      await HiveService.saveRoutineDayLog(merged);
      return merged;
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineDayLog:silent');
      return local;
    }
  }

  /// Live day log for [profileId] on [day] — what an educator watches to see
  /// a learner tick their morning off in real time.
  Stream<RoutineDayLog> watchDayLog(String profileId, DateTime day) {
    final local = HiveService.getRoutineDayLog(profileId, day);
    if (!FirebaseService.isConfigured) return Stream.value(local);
    final controller = StreamController<RoutineDayLog>();
    controller.add(local);
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    controller.onListen = () {
      sub = _logCol.doc(dayKeyFor(profileId, day)).snapshots().listen(
        (doc) {
          final data = doc.data();
          if (data == null) return;
          try {
            final remote =
                RoutineDayLog.fromJson(Map<String, dynamic>.from(data));
            final merged = _mergeLogs(
              HiveService.getRoutineDayLog(profileId, day),
              remote,
            );
            HiveService.saveRoutineDayLog(merged);
            if (!controller.isClosed) controller.add(merged);
          } catch (_) {}
        },
        onError: (Object e, StackTrace s) {
          ErrorHandler.report(e, s, 'RoutineDayLogStream:silent');
        },
      );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  /// Tick [stepId] on or off for [profileId] on [day] and return the new log.
  ///
  /// Writes locally first so the checkmark lands on the next frame whatever
  /// the network is doing — a child tapping "done" and watching nothing
  /// happen is the failure this feature can least afford.
  Future<RoutineDayLog> toggleStep(
    String profileId,
    DateTime day,
    String stepId,
  ) async {
    final current = HiveService.getRoutineDayLog(profileId, day);
    final next = current.toggle(stepId);
    await HiveService.saveRoutineDayLog(next);
    if (!FirebaseService.isConfigured) return next;
    final payload = next.toJson()
      ..['owner_uid'] = FirebaseService.currentUid
      ..['profile_id'] = profileId;
    try {
      await _logCol
          .doc(next.key)
          .set(payload, SetOptions(merge: true));
    } on Object catch (e, s) {
      // The local write already succeeded, so this is a sync failure, not a
      // lost tick — report it quietly and let the next write catch up. The
      // learner is deliberately never told: a child who ticked their teeth
      // off has done the thing, and whose tablet owns the cloud copy is not
      // their problem. The educator's side surfaces it instead.
      ErrorHandler.report(e, s, 'RoutineToggle:silent');
    }
    return next;
  }

  /// Clears every tick for [profileId] on [day] — the educator's "start this
  /// day over" action, used when a routine is rebuilt mid-day.
  Future<RoutineDayLog> resetDay(String profileId, DateTime day) async {
    final cleared = RoutineDayLog(
      profileId: profileId,
      day: DateTime(day.year, day.month, day.day),
      updatedAt: DateTime.now(),
    );
    await HiveService.saveRoutineDayLog(cleared);
    if (!FirebaseService.isConfigured) return cleared;
    try {
      await _logCol.doc(cleared.key).set(
            cleared.toJson()..['owner_uid'] = FirebaseService.currentUid,
          );
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineResetDay:silent');
    }
    return cleared;
  }

  /// Union of the two logs' ticks.
  ///
  /// A tick is only ever *added* by a learner, so the union is the honest
  /// merge: last-write-wins would let a stale cloud copy un-tick a step the
  /// child completed on this device seconds ago. Un-ticking across devices is
  /// therefore not supported, which is the right trade — see the note in
  /// `progress-durability`: nothing a learner earns is taken away.
  RoutineDayLog _mergeLogs(RoutineDayLog local, RoutineDayLog remote) {
    return RoutineDayLog(
      profileId: local.profileId.isEmpty ? remote.profileId : local.profileId,
      day: local.day,
      completedStepIds: {
        ...local.completedStepIds,
        ...remote.completedStepIds,
      },
      updatedAt:
          local.updatedAt.isAfter(remote.updatedAt) ? local.updatedAt : remote.updatedAt,
    );
  }

  /// Enabled routines first, then by the earliest step's time, then by name —
  /// so an educator's list and a learner's day agree on order.
  static List<Routine> _sorted(List<Routine> routines) {
    final list = List<Routine>.from(routines);
    list.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      final am = _firstMinute(a);
      final bm = _firstMinute(b);
      if (am != bm) return am.compareTo(bm);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Minutes-of-day of a routine's earliest scheduled step. A routine with no
  /// clock times at all sorts last rather than first — it is a checklist, not
  /// a timetable, and putting it at 00:00 would push the real morning down.
  static int _firstMinute(Routine r) {
    var best = 24 * 60 + 1;
    for (final s in r.orderedSteps) {
      final m = s.minutesOfDay;
      if (m != null && m < best) best = m;
    }
    return best;
  }
}
