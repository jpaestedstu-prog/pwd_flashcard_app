import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/shared_media_service.dart';
import '../models/routine_models.dart';

/// Where a photo, GIF, video or sound picked from the device is kept.
///
/// The picker hands back a path in the OS cache, which Android is free to
/// reclaim at any time — a routine whose picture silently disappears a week
/// later is worse than one that never had a picture. So the file is copied
/// into the app's own documents directory and the slot stores that path.
///
/// **A picked file starts on this device only.** The step editor then shares
/// it through `SharedMediaService` (Firestore on the free plan — there is no
/// Storage bucket, which would need the paid plan) and swaps the slot to its
/// `shared://` value, which reaches every device. If it cannot be shared yet
/// (offline, over 15 MB) it stays here, and the editor says so plainly rather
/// than letting an educator discover it from a learner's blank screen.
class RoutineMediaStore {
  const RoutineMediaStore();

  static const String _folder = 'routine_media';

  /// Injected in tests so nothing touches a real directory or picker.
  static Future<Directory> Function()? debugDirectory;
  static Future<String?> Function(RoutineMediaKind kind)? debugPick;

  /// Prefix marking a slot value as a file on this device.
  static const String filePrefix = 'file://';

  static bool isDeviceFile(String url) =>
      url.trim().startsWith(filePrefix);

  /// The filesystem path behind a `file://` slot value.
  static String pathOf(String url) {
    final u = url.trim();
    return u.startsWith(filePrefix) ? u.substring(filePrefix.length) : u;
  }

  Future<Directory> _dir() async {
    final base = debugDirectory != null
        ? await debugDirectory!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// File types offered per slot. Deliberately narrow: an educator picking a
  /// 400 MB video for a routine step has made a mistake the picker should
  /// help them avoid.
  static List<String> extensionsFor(RoutineMediaKind kind) => switch (kind) {
        RoutineMediaKind.photo => const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        RoutineMediaKind.gif => const ['gif', 'webp'],
        RoutineMediaKind.video => const ['mp4', 'mov', 'm4v', 'webm'],
        RoutineMediaKind.audio => const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      };

  /// Opens the device picker for [kind] and returns the chosen path, or null
  /// if the educator cancelled.
  Future<String?> pick(RoutineMediaKind kind) async {
    if (debugPick != null) return debugPick!(kind);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionsFor(kind),
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  /// Copies [sourcePath] into app storage for [step]/[kind] and returns the
  /// slot value to save (`file://…`), or null if the copy failed.
  ///
  /// The destination name is derived from the step and slot, so re-picking
  /// replaces the previous file instead of accumulating orphans — a routine
  /// edited a dozen times should not leave a dozen photos on the device.
  Future<String?> adopt({
    required String sourcePath,
    required String stepId,
    required RoutineMediaKind kind,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;
      final ext = _extensionOf(sourcePath, kind);
      final dir = await _dir();
      // A new name for every pick. Overwriting the slot's file used to
      // destroy the SAVED routine's copy the moment an educator re-picked —
      // and then cancelled. What is left over is removed on save or cancel
      // instead (see [RoutineMediaLedger]).
      final dest = File(
        '${dir.path}${Platform.pathSeparator}${stepId}_${kind.name}_'
        '${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await src.copy(dest.path);
      return '$filePrefix${dest.path}';
    } on Object catch (e) {
      if (kDebugMode) debugPrint('RoutineMediaStore.adopt failed: $e');
      return null;
    }
  }

  /// Pick and adopt in one step. Returns the slot value, or null if the
  /// educator cancelled or the copy failed.
  Future<String?> pickAndAdopt({
    required String stepId,
    required RoutineMediaKind kind,
  }) async {
    final picked = await pick(kind);
    if (picked == null) return null;
    return adopt(sourcePath: picked, stepId: stepId, kind: kind);
  }

  /// Deletes the stored file behind [slotValue], if it is one of ours.
  ///
  /// Only ever called for a slot the educator cleared or replaced — never for
  /// a URL, which belongs to whoever hosts it.
  Future<void> discard(String slotValue) async {
    // A shared file is removed from the cloud by the device that shared it;
    // the rules refuse anyone else, quietly.
    if (SharedMediaService.isShared(slotValue)) {
      await const SharedMediaService().delete(slotValue);
      return;
    }
    if (!isDeviceFile(slotValue)) return;
    try {
      final f = File(pathOf(slotValue));
      if (await f.exists()) await f.delete();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('RoutineMediaStore.discard failed: $e');
    }
  }

  static String _extensionOf(String path, RoutineMediaKind kind) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }
    // A picker that returns no extension still has to produce a playable
    // file, so fall back to the ordinary one for the slot.
    return switch (kind) {
      RoutineMediaKind.photo => 'jpg',
      RoutineMediaKind.gif => 'gif',
      RoutineMediaKind.video => 'mp4',
      RoutineMediaKind.audio => 'm4a',
    };
  }
}

/// Every file picked or shared while one routine is open in the builder.
///
/// Nothing is deleted while editing: a step editor that removed the file it
/// replaced deleted one the SAVED routine — and the learner's tablet — still
/// used, the moment the educator then cancelled. The builder settles up once:
/// on save, whatever neither the new routine nor any other routine uses; on
/// leaving without saving, only what was picked this time.
class RoutineMediaLedger {
  final Set<String> _adopted = {};

  void adopted(String value) {
    final v = value.trim();
    if (v.isNotEmpty) _adopted.add(v);
  }

  /// Everything picked or shared during this edit, kept or not.
  Set<String> get adoptedValues => Set.unmodifiable(_adopted);
}
