import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart';
import '../models/routine_day_state.dart';
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

  /// Educator-written actions on a learner's day. Separate from `routine_logs`
  /// because the rules let only the learner's own device write their log.
  CollectionReference<Map<String, dynamic>> get _actionsCol =>
      FirebaseService.db.collection('routine_actions');

  String newId() => _uuid.v4();

  /// Learner ids whose cached routines this device just changed itself.
  ///
  /// [watchForChild] re-emits from the cache on each, because a snapshot is
  /// not guaranteed to follow a local write: deleting a routine the cloud
  /// never had (an educator whose profile was restored elsewhere, or one who
  /// was offline when they made it) changes nothing in Firestore, so the
  /// deleted routine stayed on the dashboard and on the learner's My Day
  /// until the app was restarted.
  static final StreamController<String> _localChanges =
      StreamController<String>.broadcast();

  static void _changedLocally(String childProfileId) {
    if (childProfileId.isNotEmpty) _localChanges.add(childProfileId);
  }

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
      final routines = <Routine>[];
      for (final d in snap.docs) {
        final r = Routine.fromJson(Map<String, dynamic>.from(d.data()));
        routines.add(r);
        await HiveService.mirrorRoutineFromCloud(
          r,
          pending: d.metadata.hasPendingWrites,
        );
      }
      await HiveService.pruneRoutinesForChild(
        childProfileId,
        routines.map((r) => r.id).toSet(),
      );
      // The cache, not the snapshot: it is the snapshot plus anything written
      // here that has not reached the cloud yet (see
      // [HiveService.pruneRoutinesForChild]). Returning the raw snapshot
      // would hide a routine the educator just saved offline.
      return _sorted(HiveService.getRoutinesForChild(childProfileId));
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
    StreamSubscription<String>? local;

    controller.onListen = () {
      local = _localChanges.stream
          .where((id) => id == childProfileId)
          .listen((_) {
        if (!controller.isClosed) {
          controller.add(_sorted(
            HiveService.getRoutinesForChild(childProfileId),
          ));
        }
      });
      sub = _col
          .where('child_profile_id', isEqualTo: childProfileId)
          // Metadata changes too: the server accepting a write made in an
          // earlier session arrives as nothing *but* a metadata change, and
          // without it the cached copy would stay "not synced" for good — so a
          // later delete from another device could never prune it.
          .snapshots(includeMetadataChanges: true)
          .listen(
        (snap) async {
          final routines = <Routine>[];
          for (final d in snap.docs) {
            try {
              final r = Routine.fromJson(Map<String, dynamic>.from(d.data()));
              routines.add(r);
              // Awaited: the emit below reads the cache back, and a
              // fire-and-forget put is not visible to a read on the same
              // frame.
              //
              // A document with pending writes is this device's own save
              // echoed back before the server has ruled on it. Marking it
              // synced was what lost routines: when the server then refused
              // the write (an educator whose profile was restored onto another
              // device), the next snapshot left it out and the prune below
              // deleted the only copy — the routine vanished from the manager
              // seconds after it was made, and never reached the learner on
              // this same tablet.
              await HiveService.mirrorRoutineFromCloud(
                r,
                pending: d.metadata.hasPendingWrites,
              );
            } catch (_) {}
          }
          await HiveService.pruneRoutinesForChild(
            childProfileId,
            routines.map((r) => r.id).toSet(),
          );
          if (!controller.isClosed) {
            // The cache is the snapshot *plus* any routine written here whose
            // cloud write has not landed, which is what the learner must see.
            controller.add(_sorted(
              HiveService.getRoutinesForChild(childProfileId),
            ));
          }
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
      await local?.cancel();
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
    final saved = stampAddedSteps(routine, isNew: isNew, now: now).copyWith(
      id: isNew ? _uuid.v4() : routine.id,
      createdAt: isNew ? now : routine.createdAt,
      updatedAt: now,
    );
    // Cached as *not* synced first. Everything below can fail, and until one
    // of them succeeds this device holds the only copy — which is what stops
    // the next snapshot from pruning it away.
    await HiveService.cacheRoutine(saved, cloudSynced: false);
    _changedLocally(saved.childProfileId);
    if (!FirebaseService.isConfigured) {
      return RoutineWrite(saved, CloudSyncOutcome.localOnly);
    }
    final payload = saved.toJson()..['owner_uid'] = FirebaseService.currentUid;
    try {
      await _col.doc(saved.id).set(payload, SetOptions(merge: true));
      await HiveService.cacheRoutine(saved, cloudSynced: true);
      return RoutineWrite(saved, CloudSyncOutcome.synced);
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineSave:silent');
      return RoutineWrite(saved, outcomeForError(e));
    }
  }

  /// Gives every step this save puts on the schedule for the first time its
  /// [RoutineStep.addedAt], and keeps the stamp of every step the cached copy
  /// already had, whatever the draft says.
  ///
  /// Stamped here, at save, rather than when the step is added in the
  /// builder: a step only reaches the learner when the routine is saved, and
  /// an educator can leave the builder open for a while in between.
  ///
  /// An existing routine this device has no cached copy of is left alone: with
  /// nothing to compare against, every step would look new, and stamping them
  /// all would take today's already-run steps off the learner's day.
  static Routine stampAddedSteps(
    Routine routine, {
    required bool isNew,
    required DateTime now,
  }) {
    final Routine? before =
        isNew ? null : HiveService.getCachedRoutine(routine.id);
    if (!isNew && before == null) return routine;
    final known = <String, RoutineStep>{
      for (final s in before?.steps ?? const <RoutineStep>[]) s.id: s,
    };
    return routine.copyWith(
      steps: [
        for (final s in routine.steps)
          if (!known.containsKey(s.id))
            s.copyWith(addedAt: now)
          else if (known[s.id]!.addedAt != null)
            s.copyWith(addedAt: known[s.id]!.addedAt)
          else
            s,
      ],
    );
  }

  /// Permanently remove [routineId] from Firestore + Hive.
  ///
  /// A [CloudSyncOutcome.notOwner] delete is the one that bites hardest: the
  /// row vanishes from the educator's list, survives in Firestore, and comes
  /// back on the device that owns the profile. Saying so is the whole point.
  Future<CloudSyncOutcome> delete(String routineId) async {
    final childProfileId = HiveService.routineChildOf(routineId);
    await HiveService.deleteRoutineLocal(routineId);
    if (childProfileId != null) _changedLocally(childProfileId);
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

  /// The steps [routines] schedule for [day], in the order a learner sees them.
  static List<RoutineDayStep> scheduleFor(
    List<Routine> routines,
    DateTime day,
  ) {
    final out = <RoutineDayStep>[];
    for (final r in routines) {
      if (!r.enabled || !r.runsOn(day)) continue;
      final locking = {for (final s in r.lockingStepsOn(day)) s.id};
      for (final step in r.stepsOn(day)) {
        out.add(RoutineDayStep.of(step, locks: locking.contains(step.id)));
      }
    }
    return out;
  }

  /// Freezes what [routines] scheduled for [day] into that day's log.
  ///
  /// Called whenever the learner's device *observes* a day — when their own
  /// routine screen opens, and on every tick. Without this, history is scored
  /// against the routine as it is today, so editing a routine silently
  /// re-writes the past: a learner who finished four of four last Tuesday is
  /// shown as four of six once two steps are added.
  ///
  /// Cheap and idempotent: the write is skipped unless the schedule actually
  /// differs from what is already frozen, so re-opening the day all afternoon
  /// costs one comparison.
  ///
  /// Only ever records the day the device is *living through* — it never
  /// backfills earlier days, because a device that was switched off genuinely
  /// does not know what was scheduled then, and inventing it would be worse
  /// than admitting it. Unobserved days stay estimated, and the history screen
  /// says which are which.
  Future<RoutineDayLog> recordSchedule(
    String profileId,
    DateTime day,
    List<Routine> routines,
  ) async {
    final current = HiveService.getRoutineDayLog(profileId, day);
    final schedule = scheduleFor(routines, day);
    // An unrecorded day is always written, even when the schedule is empty:
    // "the device saw today and nothing was scheduled" is a real answer and
    // the whole reason a rest day can be known rather than guessed.
    if (current.hasSnapshot && _sameSchedule(current.scheduled, schedule)) {
      return current;
    }

    final next = current.withSchedule(schedule);
    await HiveService.saveRoutineDayLog(next);
    if (!FirebaseService.isConfigured) return next;
    try {
      await _logCol.doc(next.key).set(
            next.toJson()
              ..['owner_uid'] = FirebaseService.currentUid
              ..['profile_id'] = profileId,
            SetOptions(merge: true),
          );
    } on Object catch (e, s) {
      // The local freeze already happened, so history is correct on this
      // device regardless; this is only the mirror.
      ErrorHandler.report(e, s, 'RoutineRecordSchedule:silent');
    }
    return next;
  }

  static bool _sameSchedule(List<RoutineDayStep> a, List<RoutineDayStep> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].activity != b[i].activity ||
          a[i].title != b[i].title ||
          a[i].titleFilipino != b[i].titleFilipino ||
          a[i].emoji != b[i].emoji ||
          // A retimed or re-locked step is a different plan for the day, and
          // a snapshot frozen before times were recorded gets them now.
          a[i].hasTiming != b[i].hasTiming ||
          a[i].hour != b[i].hour ||
          a[i].minute != b[i].minute ||
          a[i].durationMinutes != b[i].durationMinutes ||
          a[i].locks != b[i].locks) {
        return false;
      }
    }
    return true;
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
  ) {
    // Decided from the learner's own tick as it stands *after* any reset an
    // educator made elsewhere: a stale pre-reset tick must re-tick, not
    // un-tick, when the learner taps it.
    final view = viewFromCache(profileId, day);
    return setStepDone(profileId, day, stepId, !view.isTicked(stepId));
  }

  /// Marks [stepId] done or not done for [profileId] on [day].
  Future<RoutineDayLog> setStepDone(
    String profileId,
    DateTime day,
    String stepId,
    bool done,
  ) async {
    final next = HiveService.getRoutineDayLog(profileId, day)
        .setDone(stepId, done);
    await HiveService.saveRoutineDayLog(next);
    // The learner is deliberately never told if this fails: a child who ticked
    // their teeth off has done the thing, and whose tablet owns the cloud copy
    // is not their problem. The educator's side surfaces it instead.
    await _pushLog(next, 'RoutineToggle:silent');
    return next;
  }

  /// Records every step of [steps] whose time is over as finished, each
  /// stamped with the moment its time ended — one write however many ended.
  ///
  /// A Student or Child does not tick their own steps: a step is finished when
  /// its time ends, or when an adult finishes it early. This is where "its
  /// time ended" becomes a fact in the learner's own day log, so the educator's
  /// dashboard, the history, the streak and the reminders read it exactly like
  /// any other finished step. Idempotent — a step already finished, or excused
  /// by an adult, is left alone — and it writes nothing when nothing ended.
  /// Returns the new log, or null when there was nothing to record.
  Future<RoutineDayLog?> finishEndedSteps(
    String profileId,
    DateTime day,
    List<RoutineStep> steps, {
    required DateTime now,
  }) async {
    final view = viewFromCache(profileId, day);
    var next = HiveService.getRoutineDayLog(profileId, day);
    var changed = false;
    for (final s in steps) {
      // A paused step's clock is stopped: it cannot run out.
      if (view.isPaused(s.id)) continue;
      final planned = s.endsOn(day);
      final moved = view.adjustment(s.id);
      final end = planned == null || moved == null
          ? planned
          : planned.add(moved.shiftAt(now));
      if (end == null || now.isBefore(end)) continue;
      if (view.isSettled(s.id) || next.isDone(s.id)) continue;
      next = next.setDone(s.id, true, at: end);
      changed = true;
    }
    if (!changed) return null;
    await HiveService.saveRoutineDayLog(next);
    await _pushLog(next, 'RoutineToggle:silent');
    return next;
  }

  /// The day as this device's cache knows it — the learner's log joined with
  /// any educator actions. What every write here decides from.
  static RoutineDayView viewFromCache(String profileId, DateTime day) =>
      RoutineDayView.of(
        profileId: profileId,
        day: day,
        log: HiveService.getRoutineDayLog(profileId, day),
        actions: _cachedActions(profileId, day),
      );

  static RoutineDayActions _cachedActions(String profileId, DateTime day) {
    try {
      return HiveService.getRoutineDayActions(profileId, day);
    } catch (_) {
      return RoutineDayActions.empty(profileId, day);
    }
  }

  /// Mirrors [log] to Firestore, reporting (quietly) rather than throwing: the
  /// local write has already happened, so a failure here is a sync gap, not a
  /// lost tick.
  Future<void> _pushLog(RoutineDayLog log, String silentSource) async {
    if (!FirebaseService.isConfigured) return;
    try {
      await _logCol.doc(log.key).set(
            log.toJson()
              ..['owner_uid'] = FirebaseService.currentUid
              ..['profile_id'] = log.profileId,
            SetOptions(merge: true),
          );
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, silentSource);
    }
  }

  /// Clears every tick for [profileId] on [day] — the educator's "start this
  /// day over" action, used when a routine is rebuilt mid-day.
  Future<RoutineDayLog> resetDay(String profileId, DateTime day) async {
    // Clears the ticks but **keeps the frozen schedule**: "start today over"
    // means the learner does the day again, not that the day never had a
    // routine. It also stamps the reset, which is what stops a copy of this
    // day on another device from carrying the old ticks back in on a merge.
    final cleared = HiveService.getRoutineDayLog(profileId, day)
        .resetAll(at: DateTime.now());
    await HiveService.saveRoutineDayLog(cleared);
    if (!FirebaseService.isConfigured) return cleared;
    try {
      await _logCol.doc(cleared.key).set(
            cleared.toJson()
              ..['owner_uid'] = FirebaseService.currentUid
              ..['profile_id'] = profileId,
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
  RoutineDayLog _mergeLogs(RoutineDayLog local, RoutineDayLog remote) =>
      RoutineDayLog.merge(local, remote);

  // ─── Lock records (the learner's own device) ─────────

  static RoutineStepMark _markBy(
    UserProfile? by,
    RoutineMarkSource source,
    DateTime at,
  ) =>
      RoutineStepMark(
        at: at,
        byProfileId: by?.id ?? '',
        byName: by?.name ?? '',
        byRole: by?.role,
        source: source,
      );

  /// Excuses [stepId] from the learner's device, after the adult gate.
  ///
  /// Written into the learner's own log — which that device may write — so the
  /// educator sees it, with its time, even though nobody identified themselves
  /// to a maths question.
  Future<RoutineDayLog> excuseOnDevice({
    required String profileId,
    required DateTime day,
    required String stepId,
    UserProfile? by,
  }) async {
    final next = HiveService.getRoutineDayLog(profileId, day).withExcuse(
      stepId,
      _markBy(by, RoutineMarkSource.learnerDevice, DateTime.now()),
    );
    await HiveService.saveRoutineDayLog(next);
    await _pushLog(next, 'RoutineLockRecord:silent');
    return next;
  }

  /// Records that the lock for [stepId] appeared. Only the first sighting is
  /// written, so calling this on every build of the lock screen costs nothing.
  Future<void> markLockShown(
    String profileId,
    DateTime day,
    String stepId, {
    DateTime? at,
  }) async {
    final current = HiveService.getRoutineDayLog(profileId, day);
    final next = current.withLockShown(stepId, at ?? DateTime.now());
    if (identical(next, current)) return;
    await HiveService.saveRoutineDayLog(next);
    await _pushLog(next, 'RoutineLockRecord:silent');
  }

  /// Records that [stepId] has waited long enough to need help. First only.
  Future<void> markEscalated(
    String profileId,
    DateTime day,
    String stepId, {
    DateTime? at,
  }) async {
    final current = HiveService.getRoutineDayLog(profileId, day);
    final next = current.withEscalated(stepId, at ?? DateTime.now());
    if (identical(next, current)) return;
    await HiveService.saveRoutineDayLog(next);
    await _pushLog(next, 'RoutineLockRecord:silent');
  }

  // ─── Educator actions (a Teacher's or Parent's device) ─

  /// Live educator actions on [childProfileId]'s [day], cache-seeded.
  ///
  /// Watched by the learner's device — it is what lifts a lock the moment an
  /// educator taps "Mark done" across the room — and by the educator's own
  /// dashboard.
  Stream<RoutineDayActions> watchDayActions(
    String childProfileId,
    DateTime day,
  ) {
    final local = _cachedActions(childProfileId, day);
    if (!FirebaseService.isConfigured) return Stream.value(local);

    final controller = StreamController<RoutineDayActions>();
    controller.add(local);
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
    controller.onListen = () {
      sub = _actionsCol.doc(dayKeyFor(childProfileId, day)).snapshots().listen(
        (doc) async {
          final data = doc.data();
          if (data == null) return;
          try {
            final remote =
                RoutineDayActions.fromJson(Map<String, dynamic>.from(data));
            final merged = RoutineDayActions.merge(
              _cachedActions(childProfileId, day),
              remote,
            );
            await HiveService.saveRoutineDayActions(merged);
            await _applyActionsReset(childProfileId, day, merged);
            if (!controller.isClosed) controller.add(merged);
          } catch (e, s) {
            ErrorHandler.report(e, s, 'RoutineActionsStream:silent');
          }
        },
        onError: (Object e, StackTrace s) {
          ErrorHandler.report(e, s, 'RoutineActionsStream:silent');
        },
      );
    };
    controller.onCancel = () async {
      await sub?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  /// An educator started the day over from their own device: bring this
  /// device's copy of the learner's log into line, so every write made here
  /// from now on decides from the day as it now is.
  Future<void> _applyActionsReset(
    String profileId,
    DateTime day,
    RoutineDayActions actions,
  ) async {
    final reset = actions.resetAt;
    if (reset == null) return;
    final log = HiveService.getRoutineDayLog(profileId, day);
    final current = log.resetAt;
    if (current != null && !reset.isAfter(current)) return;
    final next = log.applyReset(reset);
    await HiveService.saveRoutineDayLog(next);
    await _pushLog(next, 'RoutineLockRecord:silent');
  }

  /// Saves [next] locally and writes only [delta] to the cloud.
  ///
  /// Only the changed step goes up, never the whole document: an educator
  /// whose copy is a minute stale must not overwrite what a second educator
  /// just did to a different step.
  Future<CloudSyncOutcome> _writeActions(
    RoutineDayActions next,
    Map<String, dynamic> delta,
    UserProfile by,
  ) async {
    await HiveService.saveRoutineDayActions(next);
    if (!FirebaseService.isConfigured) return CloudSyncOutcome.localOnly;
    try {
      await _actionsCol.doc(next.key).set(
        {
          'child_profile_id': next.childProfileId,
          'day': dayStampOf(next.day),
          'updated_at': next.updatedAt.toIso8601String(),
          'setter_profile_id': by.id,
          'owner_uid': FirebaseService.currentUid,
          ...delta,
        },
        SetOptions(merge: true),
      );
      return CloudSyncOutcome.synced;
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineActions:silent');
      return outcomeForError(e);
    }
  }

  /// Excuses [stepId] for today, from an educator's device.
  Future<CloudSyncOutcome> excuseStep({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
  }) {
    final mark = _markBy(by, RoutineMarkSource.educator, DateTime.now());
    final next = _cachedActions(childProfileId, day).withExcuse(stepId, mark);
    return _writeActions(next, {
      'excused': {stepId: mark.toJson()},
    }, by);
  }

  /// Marks [stepId] done on the learner's behalf.
  Future<CloudSyncOutcome> approveStep({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
  }) {
    final mark = _markBy(by, RoutineMarkSource.educator, DateTime.now());
    final next = _cachedActions(childProfileId, day).withApproval(stepId, mark);
    return _writeActions(next, {
      'approved': {stepId: mark.toJson()},
    }, by);
  }

  /// The adjustment on [stepId] as this device knows it, or a fresh one.
  static RoutineStepAdjustment _adjustmentOf(
    String childProfileId,
    DateTime day,
    String stepId,
    DateTime at,
  ) =>
      viewFromCache(childProfileId, day).adjustment(stepId) ??
      RoutineStepAdjustment(changedAt: at);

  Future<CloudSyncOutcome> _writeAdjustment(
    String childProfileId,
    DateTime day,
    String stepId,
    RoutineStepAdjustment next,
    UserProfile by,
  ) {
    final actions =
        _cachedActions(childProfileId, day).withAdjustment(stepId, next);
    return _writeActions(actions, {
      'adjustments': {stepId: next.toJson()},
    }, by);
  }

  /// Stops [stepId]'s clock from an educator's device: the lock lifts, and
  /// the time left is kept for when they resume it.
  Future<CloudSyncOutcome> pauseStep({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final next = _adjustmentOf(childProfileId, day, stepId, when)
        .paused(at: when, byProfileId: by.id, byName: by.name);
    return _writeAdjustment(childProfileId, day, stepId, next, by);
  }

  /// Starts a paused step's clock again: the lock comes back for the time it
  /// had left.
  Future<CloudSyncOutcome> resumeStep({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final next = _adjustmentOf(childProfileId, day, stepId, when)
        .resumed(at: when, byProfileId: by.id, byName: by.name);
    return _writeAdjustment(childProfileId, day, stepId, next, by);
  }

  /// Gives [stepId] [minutes] more before its time ends.
  Future<CloudSyncOutcome> addStepTime({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required int minutes,
    required UserProfile by,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final next = _adjustmentOf(childProfileId, day, stepId, when)
        .withAddedMinutes(
      minutes,
      at: when,
      byProfileId: by.id,
      byName: by.name,
    );
    return _writeAdjustment(childProfileId, day, stepId, next, by);
  }

  /// Takes back the standing excuse on [stepId], wherever it was granted.
  ///
  /// Written as a newer, revoked copy of that excuse into the educator's
  /// document, which outranks a tablet's excuse in [RoutineDayView] — the
  /// educator cannot write the tablet's log, and does not need to.
  Future<CloudSyncOutcome> revokeExcuse({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
  }) async {
    final standing = viewFromCache(childProfileId, day).excuse(stepId);
    if (standing == null) return CloudSyncOutcome.synced;
    final revoked = standing.revoke(at: DateTime.now(), byName: by.name);
    final next =
        _cachedActions(childProfileId, day).withExcuse(stepId, revoked);
    return _writeActions(next, {
      'excused': {stepId: revoked.toJson()},
    }, by);
  }

  /// Takes back an educator's "mark done".
  Future<CloudSyncOutcome> revokeApproval({
    required String childProfileId,
    required DateTime day,
    required String stepId,
    required UserProfile by,
  }) async {
    final standing = viewFromCache(childProfileId, day).approval(stepId);
    if (standing == null) return CloudSyncOutcome.synced;
    final revoked = standing.revoke(at: DateTime.now(), byName: by.name);
    final next =
        _cachedActions(childProfileId, day).withApproval(stepId, revoked);
    return _writeActions(next, {
      'approved': {stepId: revoked.toJson()},
    }, by);
  }

  /// The educator's "start today over", made to reach the learner's device.
  ///
  /// The reset goes into the educator's own document, which the learner's
  /// device watches; the local log is reset as well, which is all it takes on
  /// a shared family tablet where both profiles live on one device.
  Future<CloudSyncOutcome> resetDayForLearner({
    required String childProfileId,
    required DateTime day,
    required UserProfile by,
  }) async {
    final at = DateTime.now();
    final next = _cachedActions(childProfileId, day)
        .withReset(at: at, byName: by.name);
    final outcome = await _writeActions(next, {
      'reset_at': at.toIso8601String(),
      'reset_by_name': by.name,
    }, by);
    await resetDay(childProfileId, day);
    return outcome;
  }

  /// Pulls the last [days] days of [profileId]'s logs and educator actions
  /// into the local mirror.
  ///
  /// The learner's device lived through its own days; an educator's device
  /// did not, and without this its history screen could only show the days it
  /// happened to have open. Single-field queries, so no composite index.
  Future<void> fetchRecentDays(String profileId, {int days = 14}) async {
    if (!FirebaseService.isConfigured) return;
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days));
    try {
      final logs =
          await _logCol.where('profile_id', isEqualTo: profileId).get();
      for (final doc in logs.docs) {
        final remote =
            RoutineDayLog.fromJson(Map<String, dynamic>.from(doc.data()));
        if (remote.day.isBefore(cutoff)) continue;
        await HiveService.saveRoutineDayLog(RoutineDayLog.merge(
          HiveService.getRoutineDayLog(profileId, remote.day),
          remote,
        ));
      }
      final acts = await _actionsCol
          .where('child_profile_id', isEqualTo: profileId)
          .get();
      for (final doc in acts.docs) {
        final remote =
            RoutineDayActions.fromJson(Map<String, dynamic>.from(doc.data()));
        if (remote.day.isBefore(cutoff)) continue;
        await HiveService.saveRoutineDayActions(RoutineDayActions.merge(
          _cachedActions(profileId, remote.day),
          remote,
        ));
      }
    } on Object catch (e, s) {
      ErrorHandler.report(e, s, 'RoutineRecentDays:silent');
    }
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
