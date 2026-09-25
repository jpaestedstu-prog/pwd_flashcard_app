import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/shared_media_service.dart';
import '../../routine/services/routine_media_store.dart';
import '../models/assessment_media.dart';
import 'assessment_service.dart';

/// What happened when an educator picked a file.
enum MediaPickStatus { added, cancelled, tooLarge, failed }

/// Where photos, GIFs, videos, sounds and FSL clips picked from the device are
/// kept for the assessment module.
///
/// Same reasoning as `RoutineMediaStore`, whose `file://` convention this
/// shares so the one set of renderers understands both: the picker hands back
/// a path in the OS cache, which Android may reclaim at any time, so the file
/// is copied into the app's own documents directory.
///
/// Two differences, both because an assessment is edited in a sheet that can
/// be cancelled:
///
///  * **Every pick gets a new file name.** The routine store names a file
///    after its slot, so re-picking overwrites in place — and an educator who
///    re-picked and then cancelled lost the file the *saved* item still
///    pointed at. Here the old file stays until the edit is saved, and
///    [AssessmentMediaLedger] says which files to let go of on save or cancel.
///  * **Nothing is deleted while anything still refers to it** — see
///    [discardUnreferenced].
class AssessmentMediaStore {
  const AssessmentMediaStore();

  static const String folder = 'assessment_media';

  /// The largest file accepted. A phone video of a signed explanation runs to
  /// tens of megabytes; past this it is almost certainly the wrong file, and
  /// it would sit on a shared classroom tablet for good.
  static const int maxBytes = 200 * 1024 * 1024;

  /// Injected in tests so nothing touches a real directory or picker.
  static Future<Directory> Function()? debugDirectory;
  static Future<String?> Function(AssessmentMediaKind kind)? debugPick;

  static List<String> extensionsFor(AssessmentMediaKind kind) =>
      switch (kind) {
        AssessmentMediaKind.photo => const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        AssessmentMediaKind.gif => const ['gif', 'webp'],
        AssessmentMediaKind.video ||
        AssessmentMediaKind.sign => const ['mp4', 'mov', 'm4v', 'webm', '3gp'],
        AssessmentMediaKind.audio => const ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
      };

  Future<Directory> _dir() async {
    final base = debugDirectory != null
        ? await debugDirectory!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Opens the device picker for [kind]. Null when the educator cancelled.
  Future<String?> pick(AssessmentMediaKind kind) async {
    if (debugPick != null) return debugPick!(kind);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionsFor(kind),
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  /// Copies [sourcePath] into app storage and returns the slot value to save
  /// (`file://…`).
  Future<({MediaPickStatus status, String? value})> adopt({
    required String sourcePath,
    required String ownerKey,
    required AssessmentMediaKind kind,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) {
        return (status: MediaPickStatus.failed, value: null);
      }
      if (await src.length() > maxBytes) {
        return (status: MediaPickStatus.tooLarge, value: null);
      }
      final dir = await _dir();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final dest = File(
        '${dir.path}${Platform.pathSeparator}'
        '${_safe(ownerKey)}_${kind.name}_$stamp.${_extensionOf(sourcePath, kind)}',
      );
      await src.copy(dest.path);
      return (
        status: MediaPickStatus.added,
        value: '${RoutineMediaStore.filePrefix}${dest.path}',
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('AssessmentMediaStore.adopt failed: $e');
      return (status: MediaPickStatus.failed, value: null);
    }
  }

  /// Adopts something the in-app camera just captured and removes the
  /// camera's own temporary copy, which would otherwise sit in the cache.
  Future<({MediaPickStatus status, String? value})> adoptCaptured({
    required String capturedPath,
    required String ownerKey,
    required AssessmentMediaKind kind,
  }) async {
    final result = await adopt(
      sourcePath: capturedPath,
      ownerKey: ownerKey,
      kind: kind,
    );
    try {
      final temp = File(capturedPath);
      if (await temp.exists()) await temp.delete();
    } on Object {
      // The OS reclaims its cache anyway.
    }
    return result;
  }

  /// Pick and adopt in one step.
  Future<({MediaPickStatus status, String? value})> pickAndAdopt({
    required String ownerKey,
    required AssessmentMediaKind kind,
  }) async {
    final String? picked;
    try {
      picked = await pick(kind);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('AssessmentMediaStore.pick failed: $e');
      return (status: MediaPickStatus.failed, value: null);
    }
    if (picked == null) return (status: MediaPickStatus.cancelled, value: null);
    return adopt(sourcePath: picked, ownerKey: ownerKey, kind: kind);
  }

  /// Shares a picked file with every device and returns its `shared://`
  /// value, deleting the staging copy it no longer needs.
  ///
  /// Anything that is not one of this store's own files comes back
  /// unchanged. So does a file that cannot be shared right now — offline,
  /// over the free quota for today, or too big — and [status] says which, so
  /// the editor can tell the educator it is still on this tablet only.
  Future<({SharedUploadStatus status, String value})> share(
    String value, {
    required String ownerProfileId,
    void Function(double progress)? onProgress,
  }) async {
    if (!isOwnFile(value) || ownerProfileId.isEmpty) {
      return (status: SharedUploadStatus.unavailable, value: value);
    }
    final path = RoutineMediaStore.pathOf(value);
    final dot = path.lastIndexOf('.');
    final result = await const SharedMediaService().upload(
      File(path),
      ownerProfileId: ownerProfileId,
      ext: dot == -1 ? 'bin' : path.substring(dot + 1),
      onProgress: onProgress,
    );
    if (!result.ok) return (status: result.status, value: value);
    await discard([value]);
    return (status: SharedUploadStatus.shared, value: result.value!);
  }

  /// Every stored media value in [media] shared, where it can be. Values that
  /// cannot be shared yet stay as they were.
  Future<AssessmentMedia> shareAll(
    AssessmentMedia media, {
    required String ownerProfileId,
  }) async {
    var out = media;
    for (final kind in AssessmentMediaKind.values) {
      final value = media.urlFor(kind);
      if (!isOwnFile(value)) continue;
      final shared = await share(value, ownerProfileId: ownerProfileId);
      if (shared.status == SharedUploadStatus.shared) {
        out = out.withSlot(kind, shared.value);
      }
    }
    return out;
  }

  /// Deletes the file behind each value, if it is one of this store's own —
  /// and a shared file everywhere this device is allowed to.
  ///
  /// Anything outside [folder] is left alone: a `file://` value is only ever
  /// written by [adopt], but a value can also arrive from sync or be typed in,
  /// and this must never become a way to delete an arbitrary file. A shared
  /// file can only be deleted in the cloud by the device that shared it; the
  /// rules refuse anyone else, quietly.
  Future<void> discard(Iterable<String> values) async {
    for (final value in values) {
      if (SharedMediaService.isShared(value)) {
        await const SharedMediaService().delete(value);
        continue;
      }
      if (!isOwnFile(value)) continue;
      try {
        final f = File(RoutineMediaStore.pathOf(value));
        if (await f.exists()) await f.delete();
      } on Object catch (e) {
        if (kDebugMode) debugPrint('AssessmentMediaStore.discard failed: $e');
      }
    }
  }

  /// Deletes those of [candidates] that no stored assessment or assignment
  /// refers to any more.
  ///
  /// [referenced] defaults to a scan of the progress box; a test seam.
  Future<void> discardUnreferenced(
    Iterable<String> candidates, {
    Set<String>? referenced,
  }) async {
    final inUse = referenced ?? AssessmentService.referencedMediaValues();
    await discard(candidates.where((c) => !inUse.contains(c.trim())));
  }

  /// A `file://` value inside this store's folder.
  static bool isOwnFile(String value) {
    if (!RoutineMediaStore.isDeviceFile(value)) return false;
    final path = RoutineMediaStore.pathOf(value).replaceAll('\\', '/');
    return path.contains('/$folder/');
  }

  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static String _extensionOf(String path, AssessmentMediaKind kind) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final ext = path.substring(dot + 1).toLowerCase();
      if (ext.isNotEmpty && ext.length <= 5 && !ext.contains('/')) return ext;
    }
    return switch (kind) {
      AssessmentMediaKind.photo => 'jpg',
      AssessmentMediaKind.gif => 'gif',
      AssessmentMediaKind.video || AssessmentMediaKind.sign => 'mp4',
      AssessmentMediaKind.audio => 'm4a',
    };
  }
}

/// Which picked files an edit is responsible for.
///
/// An editor adopts a file the moment it is picked, before anything is saved.
/// If the educator then cancels, that file belongs to nothing; if they save,
/// the file it replaced belongs to nothing. This keeps the two lists, so a
/// cancelled sheet does not leave a 50 MB video behind on a shared tablet —
/// and a saved one does not delete a file it still uses.
class AssessmentMediaLedger {
  /// The media as it was when the edit began.
  final AssessmentMedia initial;
  final Set<String> _adopted = {};

  AssessmentMediaLedger([this.initial = AssessmentMedia.none]);

  void adopted(String value) => _adopted.add(value.trim());

  /// Files to delete once [saved] has been stored.
  Set<String> toDiscardOnSave(AssessmentMedia saved) => {
    ...initial.storedValues,
    ..._adopted,
  }.difference(saved.storedValues);

  /// Files to delete when the edit is abandoned.
  Set<String> toDiscardOnCancel() => _adopted.difference(initial.storedValues);
}
