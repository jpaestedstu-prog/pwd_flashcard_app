import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../../../data/local/hive_service.dart';
import '../models/parent_teacher_note_models.dart';

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
