import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/classroom.dart';
import '../data/models/home_group.dart';

/// Leaf Firestore stream providers used by aggregate dashboard / roster
/// providers. Watching one of these makes the consumer re-emit whenever
/// the underlying Firestore collection changes.
///
/// Kept here (rather than inlined into each consumer) so that two screens
/// watching the same classroom share one Firestore listener, courtesy of
/// Riverpod's per-family memoisation.
///
/// All providers are `autoDispose` so listeners shut down when no widget
/// is watching them.
///
/// **Offline behavior** (matters for the unplugged tablets): every stream
/// emits the Hive cache first, then the live Firestore snapshots. So a
/// device that's been offline since launch never sits at `loading` — it
/// shows the last-known list immediately, then overlays live updates
/// when the network comes back.

/// Emits the cached value first (synchronously), then the Firestore
/// snapshot stream. Used by every leaf provider below so the unplugged
/// tablets render their last-known roster instantly instead of spinning
/// at `loading` until Firestore's offline cache decides to fire.
Stream<T> _hiveFirstThenStream<T>(
  T cached,
  Stream<T> live,
) async* {
  yield cached;
  yield* live;
}

/// Live list of classrooms owned by a teacher.
///
/// Mirrors the one-shot fetch in `FirestoreRepository.getClassroomsByTeacher`
/// but with a real-time subscription. Falls back to Hive when Firebase
/// isn't configured so single-device demos still render something.
final classroomsByTeacherStreamProvider =
    StreamProvider.family.autoDispose<List<Classroom>, String>(
  (ref, teacherId) {
    if (teacherId.isEmpty) return Stream.value(const <Classroom>[]);
    final cached = HiveService.getClassroomsByTeacher(teacherId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!FirebaseService.isConfigured) {
      // No live source — emit local cache once.
      return Stream.value(cached);
    }
    final live = FirebaseService.db
        .collection('classrooms')
        .where('teacher_id', isEqualTo: teacherId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Classroom.fromJson(Map<String, dynamic>.from(d.data())))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final c in list) {
        // Fire-and-forget Hive write so offline launches stay fresh.
        // ignore: discarded_futures
        HiveService.cacheClassroom(c);
      }
      return list;
    });
    return _hiveFirstThenStream(cached, live);
  },
);

/// Live list of home groups owned by a parent profile.
final homeGroupsByOwnerStreamProvider =
    StreamProvider.family.autoDispose<List<HomeGroup>, String>(
  (ref, ownerProfileId) {
    if (ownerProfileId.isEmpty) return Stream.value(const <HomeGroup>[]);
    final cached = HiveService.getHomeGroupsByOwner(ownerProfileId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!FirebaseService.isConfigured) {
      return Stream.value(cached);
    }
    final live = FirebaseService.db
        .collection('home_groups')
        .where('owner_profile_id', isEqualTo: ownerProfileId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => HomeGroup.fromJson(Map<String, dynamic>.from(d.data())))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final g in list) {
        // ignore: discarded_futures
        HiveService.cacheHomeGroup(g);
      }
      return list;
    });
    return _hiveFirstThenStream(cached, live);
  },
);
