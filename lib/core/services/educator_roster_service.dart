import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';

/// This device's roster in the cloud, `educator_rosters/{uid}`: the learners
/// it teaches or parents, `learners: {profile id: that learner's device
/// uid}`, and `via: {profile id: class or family group}` (this device's own
/// note of where each came from, used to take off those who leave).
///
/// The rules read it to prove many learners in one lookup: an educator's
/// results query names up to 30 learners and a request may make only 10
/// lookups, and an assignment may name every learner in a class. They prove
/// each entry when it is added, so it is added one learner per write, and
/// only when it is missing or names an old device. Learners who left a group
/// this device syncs come off it.
///
/// Best effort: never throws. A refused or offline write is tried again on
/// the next sync; until then the rules check that learner on their own.
class EducatorRosterService {
  const EducatorRosterService();

  static const String collection = 'educator_rosters';
  static const Duration _timeout = Duration(seconds: 8);

  /// The cloud roster as this session last saw it, or null before the
  /// first read (and after a failed one).
  static Map<String, String>? _learners;
  static Map<String, String>? _via;
  static String? _loadedFor;

  /// Roster work runs one task at a time, in order: every write is proven
  /// against the document as the one before it left it.
  static Future<void> _tail = Future.value();

  @visibleForTesting
  static void resetForTest() {
    _learners = null;
    _via = null;
    _loadedFor = null;
    _tail = Future.value();
  }

  FirebaseFirestore get _db => FirebaseService.db;

  /// What one class or family group asks of the roster: [learnerUids]
  /// (profile id → device uid) of the members whose profiles were read are
  /// added where missing or out of date, and anyone the roster has from
  /// [groupId] who is no longer among [memberIds] is taken off (a learner
  /// still in another of this device's groups is added back when that group
  /// syncs). Pure.
  @visibleForTesting
  static ({Map<String, String> add, Set<String> remove}) planGroup({
    required Map<String, String> roster,
    required Map<String, String> via,
    required String groupId,
    required Set<String> memberIds,
    required Map<String, String> learnerUids,
  }) {
    final add = <String, String>{
      for (final e in learnerUids.entries)
        if (memberIds.contains(e.key) && e.value.isNotEmpty && roster[e.key] != e.value)
          e.key: e.value,
    };
    final remove = <String>{
      for (final e in via.entries)
        if (e.value == groupId && !memberIds.contains(e.key)) e.key,
    };
    return (add: add, remove: remove);
  }

  /// Brings the roster in line with the class or family group [groupId].
  /// See [planGroup].
  Future<void> syncGroup({
    required String groupId,
    required Set<String> memberIds,
    required Map<String, String> learnerUids,
  }) => _serial(() async {
    if (!await _load()) return;
    final plan = planGroup(
      roster: _learners!,
      via: _via!,
      groupId: groupId,
      memberIds: memberIds,
      learnerUids: learnerUids,
    );
    for (final e in plan.add.entries) {
      await _add(e.key, e.value, groupId);
    }
    await _remove(plan.remove);
  });

  /// Puts every learner in [learnerUids] on the roster before something
  /// (an assignment) names them; [viaOf] says where each came from. Returns
  /// those of them now on it, with their uids; null when the roster could
  /// not be read (offline, or rules from before 1.4.1).
  Future<Map<String, String>?> ensure(
    Map<String, String> learnerUids, {
    required String Function(String learnerId) viaOf,
  }) async {
    Map<String, String>? onRoster;
    await _serial(() async {
      if (!await _load()) return;
      final have = <String, String>{};
      for (final e in learnerUids.entries) {
        if (e.value.isEmpty) continue;
        if (_learners![e.key] == e.value ||
            await _add(e.key, e.value, viaOf(e.key))) {
          have[e.key] = e.value;
        }
      }
      onRoster = have;
    });
    return onRoster;
  }

  /// Groups being named this session (see [nameThisDevice]).
  static final Set<String> _naming = {};

  /// Names this device on its own class or family group [groupId]
  /// (`teacher_uid` / `owner_uid`, in [field]) when the document names
  /// another or none ([current]): how a learner's device that joins knows
  /// whose roster to join. Classes from before 1.4.1 name none; a teacher
  /// whose profile was restored to a new tablet is named again.
  void nameThisDevice({
    required String collection,
    required String groupId,
    required String field,
    required String? current,
  }) {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty || current == uid) return;
    if (!_naming.add('$collection/$groupId')) return;
    _db
        .collection(collection)
        .doc(groupId)
        .set({field: uid}, SetOptions(merge: true))
        .timeout(_timeout)
        .catchError((Object e) {
          if (kDebugMode) debugPrint('EducatorRosterService: name $groupId: $e');
        })
        .whenComplete(() => _naming.remove('$collection/$groupId'));
  }

  /// Takes [learnerIds] off the roster (a learner removed from a group, or
  /// deleted).
  Future<void> removeAll(Iterable<String> learnerIds) => _serial(() async {
    if (!await _load()) return;
    await _remove(learnerIds.where(_learners!.containsKey).toSet());
  });

  Future<void> _serial(Future<void> Function() task) {
    final next = _tail.then((_) => task()).catchError((Object e) {
      if (kDebugMode) debugPrint('EducatorRosterService: $e');
    });
    _tail = next;
    return next;
  }

  /// Reads the roster once per session (and per device uid).
  Future<bool> _load() async {
    if (!FirebaseService.isConfigured) return false;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty) return false;
    if (_loadedFor == uid && _learners != null) return true;
    try {
      final doc = await _db
          .collection(collection)
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      final data = doc.data() ?? const <String, dynamic>{};
      _learners = _strings(data['learners']);
      _via = _strings(data['via']);
      _loadedFor = uid;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('EducatorRosterService: read: $e');
      _learners = null;
      return false;
    }
  }

  static Map<String, String> _strings(Object? raw) => {
    if (raw is Map)
      for (final e in raw.entries)
        if (e.key is String && e.value is String) e.key as String: e.value as String,
  };

  Future<bool> _add(String learnerId, String learnerUid, String via) async {
    try {
      await _db.collection(collection).doc(_loadedFor).set({
        'learners': {learnerId: learnerUid},
        'via': {learnerId: via},
        'learner': learnerId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(_timeout);
      _learners![learnerId] = learnerUid;
      _via![learnerId] = via;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('EducatorRosterService: add $learnerId: $e');
      return false;
    }
  }

  Future<void> _remove(Set<String> learnerIds) async {
    if (learnerIds.isEmpty) return;
    try {
      await _db.collection(collection).doc(_loadedFor).update({
        for (final id in learnerIds) ...{
          FieldPath(['learners', id]): FieldValue.delete(),
          FieldPath(['via', id]): FieldValue.delete(),
        },
        'learner': learnerIds.first,
        'updated_at': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
      for (final id in learnerIds) {
        _learners!.remove(id);
        _via!.remove(id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EducatorRosterService: remove: $e');
    }
  }
}
