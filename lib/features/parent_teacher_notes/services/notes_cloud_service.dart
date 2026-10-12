import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../data/local/hive_service.dart';
import '../models/parent_teacher_note_models.dart';

/// Which of an educator's own classes or home groups [studentId] joined —
/// the proof a `note_readers` doc names. Classes are tried first; null when
/// the learner joined none of them. [exists] answers whether a membership
/// document (`classroom_members/{class}_{learner}` or
/// `home_group_members/{group}_{learner}`) is there.
@visibleForTesting
Future<({String? classroomId, String? homeGroupId})?> findNoteReaderVia({
  required String studentId,
  required Iterable<String> classroomIds,
  required Iterable<String> homeGroupIds,
  required Future<bool> Function(String path) exists,
}) async {
  for (final c in classroomIds) {
    if (await exists('classroom_members/${c}_$studentId')) {
      return (classroomId: c, homeGroupId: null);
    }
  }
  for (final g in homeGroupIds) {
    if (await exists('home_group_members/${g}_$studentId')) {
      return (classroomId: null, homeGroupId: g);
    }
  }
  return null;
}

/// Mirrors parent-teacher notes between Hive and Firestore.
///
/// Cloud path: `parent_teacher_notes/{studentProfileId}/notes/{noteId}`.
/// Hive bucket: `pt_notes_{studentProfileId}` (see [HiveService]).
///
/// Hive is written first so the UI updates immediately and the action
/// survives an offline window. Firestore writes are fire-and-forget; a
/// failure is logged but does not surface to the user. On screen open,
/// [hydrateFromCloud] does a one-shot pull so notes from other devices
/// (e.g. the parent's phone) become visible on this device (e.g. the
/// teacher's tablet).
class ParentTeacherNotesCloudService {
  const ParentTeacherNotesCloudService();

  FirebaseFirestore get _db => FirebaseService.db;

  CollectionReference<Map<String, dynamic>> _col(String studentId) =>
      _db.collection('parent_teacher_notes').doc(studentId).collection('notes');

  Map<String, dynamic> _toFirestore(ParentTeacherNote n, String? authorUid) {
    return {
      ...n.toJson(),
      // Required by the Firestore rule — pinned to writer's auth uid.
      'author_uid': authorUid,
      // Mirror studentProfileId at the doc level too, simplifies any
      // future collectionGroup queries.
      'student_profile_id': n.studentProfileId,
    };
  }

  /// Save a new note locally and to the cloud. Hive is the source of
  /// truth for offline; cloud failures don't block the local write.
  Future<void> saveNote(ParentTeacherNote note) async {
    await HiveService.appendNoteForStudent(note);
    if (!FirebaseService.isConfigured) return;
    try {
      await _col(note.studentProfileId)
          .doc(note.id)
          .set(_toFirestore(note, FirebaseService.currentUid));
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('ParentTeacherNotesCloudService.saveNote failed: $e');
        debugPrint(stack.toString());
      }
    }
  }

  /// Delete a note locally and from the cloud. Local removal succeeds
  /// even if the cloud delete fails (next hydrate will resurrect the
  /// note locally if it's still in the cloud — that's correct behavior:
  /// the rules disallow deleting other people's notes).
  Future<void> deleteNote(String noteId, String studentId) async {
    await HiveService.removeNoteForStudent(noteId, studentId);
    if (!FirebaseService.isConfigured) return;
    try {
      await _col(studentId).doc(noteId).delete();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('ParentTeacherNotesCloudService.deleteNote failed: $e');
        debugPrint(stack.toString());
      }
    }
  }

  /// Files this device as a reader of each learner's notes before it reads
  /// them: `note_readers/{uid}_{studentId}`, naming the class or home group
  /// of [educatorProfileId] that the learner joined.
  ///
  /// The notes are readable by any signed-in user today because no older
  /// release says who it is to the learner. Once every teacher's and
  /// parent's device files these, the rules can let only them (and the
  /// learner) read and write the notes (docs/security.md). Best effort: a
  /// learner with no class or group of this educator's, an offline device,
  /// or rules that do not know the collection yet simply file nothing, and
  /// a filed reader is remembered so it is written once per device.
  Future<void> registerAsReaders({
    required String educatorProfileId,
    required Iterable<String> studentIds,
  }) async {
    if (!FirebaseService.isConfigured) return;
    final uid = FirebaseService.currentUid;
    if (uid == null || uid.isEmpty) return;
    try {
      final classes = HiveService.getClassroomsByTeacher(educatorProfileId)
          .map((c) => c.id)
          .toList();
      final groups = HiveService.getHomeGroupsByOwner(educatorProfileId)
          .map((g) => g.id)
          .toList();
      if (classes.isEmpty && groups.isEmpty) return;
      await Future.wait([
        for (final id in studentIds.toSet())
          _registerAsReader(uid, id, classes, groups),
      ]).timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParentTeacherNotesCloudService.registerAsReaders: $e');
      }
    }
  }

  Future<void> _registerAsReader(
    String uid,
    String studentId,
    List<String> classes,
    List<String> groups,
  ) async {
    final key = 'note_reader::${uid}_$studentId';
    if (HiveService.getSetting(key) == true) return;
    try {
      final via = await findNoteReaderVia(
        studentId: studentId,
        classroomIds: classes,
        homeGroupIds: groups,
        exists: (path) async => (await _db.doc(path).get()).exists,
      );
      if (via == null) return;
      await _db.collection('note_readers').doc('${uid}_$studentId').set({
        'profile_id': studentId,
        'classroom_id': ?via.classroomId,
        'home_group_id': ?via.homeGroupId,
        'updated_at': FieldValue.serverTimestamp(),
      });
      await HiveService.saveSetting(key, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ParentTeacherNotesCloudService: reader $studentId: $e');
      }
    }
  }

  /// One-shot pull of every note for [studentId] from Firestore, written
  /// into Hive as the new local truth. Returns the merged list. Used by
  /// the screen on open / refresh so notes authored on another device
  /// appear here.
  Future<List<ParentTeacherNote>> hydrateFromCloud(String studentId) async {
    if (!FirebaseService.isConfigured) {
      return HiveService.getNotesForStudent(studentId);
    }
    try {
      final snap = await _col(studentId).get();
      final notes = snap.docs
          .map((d) => ParentTeacherNote.fromJson(
                Map<String, dynamic>.from(d.data()),
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await HiveService.replaceNotesForStudent(studentId, notes);
      return notes;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
            'ParentTeacherNotesCloudService.hydrateFromCloud failed: $e');
        debugPrint(stack.toString());
      }
      return HiveService.getNotesForStudent(studentId);
    }
  }
}
