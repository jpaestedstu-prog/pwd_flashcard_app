import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync_outcome.dart';
import 'firebase_service.dart';

/// Files shared between tablets — a teacher's photo or FSL clip reaching a
/// learner's tablet, a learner's signed answer reaching their teacher's —
/// kept in Firestore itself, in pieces.
///
/// **Why Firestore and not a storage bucket.** The project stays on the free
/// Spark plan for good, and Cloud Storage for Firebase now needs the paid
/// Blaze plan for any new bucket. Firestore on Spark is free with hard
/// quotas — 1 GiB stored, 50k reads and 20k writes a day, 10 GiB out a
/// month — and when a quota runs out requests simply fail until it resets:
/// nothing is ever billed. A document holds at most 1 MiB, so a file is
/// stored as a metadata document plus [chunkBytes]-sized `Blob` pieces
/// beneath it, and capped at [maxBytes] so one classroom cannot eat the
/// whole gigabyte.
///
/// A shared file is referred to as `shared://<id>` — the same one-string
/// slot convention as `file://` and `https://`, so a question, instructions
/// or feedback holding one needs no new field.
///
/// Every device keeps what it uploaded or downloaded in its own folder, so a
/// file is fetched once per tablet and then plays offline.
class SharedMediaService {
  const SharedMediaService();

  static const String prefix = 'shared://';
  static const String collection = 'shared_media';

  /// Comfortably under Firestore's 1 MiB document limit, leaving room for the
  /// document name and the index field.
  static const int chunkBytes = 950 * 1024;

  /// The largest file shared. A minute of signing recorded in the app at the
  /// resolution it uses is well under this; a phone's full-quality video is
  /// not, and stays on the tablet it was chosen on.
  static const int maxBytes = 15 * 1024 * 1024;

  /// How long one piece may take to reach the server. Firestore resolves a
  /// write only on the server's acknowledgement, which never comes offline.
  static const Duration chunkTimeout = Duration(seconds: 60);

  static const String _folder = 'shared_media';

  /// Test seams: a backend other than Firestore, and a directory other than
  /// the app's documents.
  static SharedMediaBackend? debugBackend;
  static Future<Directory> Function()? debugDirectory;

  static bool isShared(String value) => value.trim().startsWith(prefix);

  static String idOf(String value) {
    final v = value.trim();
    return v.startsWith(prefix) ? v.substring(prefix.length) : v;
  }

  SharedMediaBackend? get _backend =>
      debugBackend ??
      (FirebaseService.isConfigured ? const FirestoreSharedMediaBackend() : null);

  /// Whether this device can share at all right now (Firebase is set up).
  bool get available => _backend != null;

  /// Downloads already running, so two widgets asking for one file share one
  /// download instead of racing to write the same path.
  static final Map<String, Future<File?>> _inFlight = {};

  Future<Directory> _dir() async {
    final base = debugDirectory != null
        ? await debugDirectory!()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeExt(String ext) {
    final e = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return e.isEmpty || e.length > 5 ? 'bin' : e;
  }

  Future<File> _cacheFile(String id, String ext) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$id.${_safeExt(ext)}');
  }

  /// Uploads [file] and returns its `shared://` value.
  ///
  /// Never throws: the result says what went wrong, so a caller can keep the
  /// file on this tablet and try again later. A failed upload removes the
  /// pieces it managed to write — including ones Firestore queued while
  /// offline, whose deletes are queued behind them.
  Future<SharedUploadResult> upload(
    File file, {
    required String ownerProfileId,
    required String ext,
    void Function(double progress)? onProgress,
  }) async {
    final backend = _backend;
    if (backend == null) return const SharedUploadResult.unavailable();
    final Uint8List bytes;
    try {
      if (!await file.exists()) return const SharedUploadResult.failed();
      if (await file.length() > maxBytes) {
        return const SharedUploadResult.tooLarge();
      }
      bytes = await file.readAsBytes();
    } on Object {
      return const SharedUploadResult.failed();
    }

    final id = const Uuid().v4();
    final count = bytes.isEmpty ? 1 : (bytes.length / chunkBytes).ceil();
    final meta = SharedMediaMeta(
      id: id,
      ownerProfileId: ownerProfileId,
      ext: _safeExt(ext),
      size: bytes.length,
      chunkCount: count,
      sha256: sha256.convert(bytes).toString(),
      ready: false,
    );
    var written = 0;
    try {
      await backend.writeMeta(meta).timeout(chunkTimeout);
      for (var i = 0; i < count; i++) {
        final start = i * chunkBytes;
        final end = (start + chunkBytes).clamp(0, bytes.length);
        await backend
            .writeChunk(id, i, Uint8List.sublistView(bytes, start, end))
            .timeout(chunkTimeout);
        written = i + 1;
        onProgress?.call(written / count);
      }
      await backend.writeMeta(meta.asReady()).timeout(chunkTimeout);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('SharedMediaService.upload failed: $e');
      unawaited(_removeRemote(backend, id, written + 1));
      return SharedUploadResult.failed(isOwnershipRefusalError(e));
    }

    // This device already has the bytes; keep them under the shared id so
    // it never downloads its own upload.
    try {
      await file.copy((await _cacheFile(id, meta.ext)).path);
    } on Object {
      // Only a cache — the next resolve downloads it.
    }
    return SharedUploadResult.shared('$prefix$id');
  }

  /// The local file behind a `shared://` value, downloading it once if this
  /// tablet does not have it yet. Null when it cannot be had right now.
  Future<File?> resolve(String value) {
    if (!isShared(value)) return Future<File?>.value();
    final id = idOf(value);
    // A block body on purpose: an arrow would return the removed entry —
    // this very future — and `whenComplete` would then wait on itself for
    // ever, hanging every download.
    return _inFlight[id] ??= _resolve(id).whenComplete(() {
      _inFlight.remove(id);
    });
  }

  Future<File?> _resolve(String id) async {
    final Directory dir;
    try {
      dir = await _dir();
    } on Object {
      return null;
    }
    try {
      await for (final entity in dir.list()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('$id.') &&
            !entity.path.endsWith('.part')) {
          return entity;
        }
      }
    } on Object {
      // An unreadable folder is a cache miss.
    }

    final backend = _backend;
    if (backend == null) return null;
    try {
      final meta = await backend.readMeta(id).timeout(chunkTimeout);
      if (meta == null || !meta.ready) return null;
      final builder = BytesBuilder(copy: false);
      for (var i = 0; i < meta.chunkCount; i++) {
        final chunk = await backend.readChunk(id, i).timeout(chunkTimeout);
        if (chunk == null) return null;
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      // A piece missing or out of order would play as noise, or not at all;
      // better to report it missing and let the test screen say so.
      if (bytes.length != meta.size ||
          sha256.convert(bytes).toString() != meta.sha256) {
        return null;
      }
      final dest = await _cacheFile(id, meta.ext);
      final part = File('${dest.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      return await part.rename(dest.path);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('SharedMediaService.resolve failed: $e');
      return null;
    }
  }

  /// Removes every file shared as [ownerProfileId] — for a profile that is
  /// being deleted, whose tests, feedback, routines and video answers go with
  /// it. Returns how many were found.
  ///
  /// Must run while the profile document still exists: the rules let the
  /// profile's own device remove its files. Throws when the list cannot be
  /// read (offline), so a caller can say the cleanup did not happen.
  Future<int> deleteAllOwnedBy(String ownerProfileId) async {
    final backend = _backend;
    if (backend == null || ownerProfileId.isEmpty) return 0;
    final ids = await backend.idsOwnedBy(ownerProfileId).timeout(chunkTimeout);
    for (final id in ids) {
      await delete('$prefix$id');
    }
    return ids.length;
  }

  /// Removes a shared file everywhere this device may: its pieces in the
  /// cloud (the rules let only the device that owns the file's profile do
  /// that) and this tablet's copy. Best effort and silent — a refused or
  /// offline delete leaves a harmless orphan, never an error in front of a
  /// teacher.
  Future<void> delete(String value) async {
    if (!isShared(value)) return;
    final id = idOf(value);
    try {
      final dir = await _dir();
      await for (final entity in dir.list()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith('$id.')) {
          await entity.delete();
        }
      }
    } on Object {
      // Nothing cached here.
    }
    final backend = _backend;
    if (backend == null) return;
    try {
      final meta = await backend.readMeta(id).timeout(chunkTimeout);
      if (meta == null) return;
      await _removeRemote(backend, id, meta.chunkCount);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('SharedMediaService.delete failed: $e');
    }
  }

  /// Pieces first, then the metadata: the rules check a piece's owner
  /// through its metadata document, so that has to go last.
  Future<void> _removeRemote(
    SharedMediaBackend backend,
    String id,
    int chunkCount,
  ) async {
    try {
      for (var i = 0; i < chunkCount; i++) {
        await backend.deleteChunk(id, i).timeout(chunkTimeout);
      }
      await backend.deleteMeta(id).timeout(chunkTimeout);
    } on Object {
      // Queued offline or refused; either way nothing to report.
    }
  }
}

/// What happened to an upload.
class SharedUploadResult {
  /// The `shared://` value, when it worked.
  final String? value;
  final SharedUploadStatus status;

  const SharedUploadResult.shared(String this.value)
    : status = SharedUploadStatus.shared;
  const SharedUploadResult.unavailable()
    : value = null,
      status = SharedUploadStatus.unavailable;
  const SharedUploadResult.tooLarge()
    : value = null,
      status = SharedUploadStatus.tooLarge;
  const SharedUploadResult.failed([bool notOwner = false])
    : value = null,
      status = notOwner
          ? SharedUploadStatus.notOwner
          : SharedUploadStatus.failed;

  bool get ok => status == SharedUploadStatus.shared;
}

enum SharedUploadStatus {
  shared,

  /// No cloud on this device (Firebase not set up) — stays on the tablet.
  unavailable,

  /// Over [SharedMediaService.maxBytes] — stays on the tablet.
  tooLarge,

  /// Offline, timed out, or over the free quota for today. Worth retrying.
  failed,

  /// Refused for good: this device no longer owns the profile in the cloud.
  notOwner,
}

/// The metadata document of one shared file.
class SharedMediaMeta {
  final String id;
  final String ownerProfileId;
  final String ext;
  final int size;
  final int chunkCount;
  final String sha256;
  final bool ready;

  const SharedMediaMeta({
    required this.id,
    required this.ownerProfileId,
    required this.ext,
    required this.size,
    required this.chunkCount,
    required this.sha256,
    required this.ready,
  });

  SharedMediaMeta asReady() => SharedMediaMeta(
    id: id,
    ownerProfileId: ownerProfileId,
    ext: ext,
    size: size,
    chunkCount: chunkCount,
    sha256: sha256,
    ready: true,
  );

  Map<String, dynamic> toJson() => {
    'owner_profile_id': ownerProfileId,
    'ext': ext,
    'size': size,
    'chunk_count': chunkCount,
    'sha256': sha256,
    'status': ready ? 'ready' : 'uploading',
  };

  static SharedMediaMeta? tryFromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final size = json['size'];
    final count = json['chunk_count'];
    if (size is! int || count is! int || count < 1) return null;
    return SharedMediaMeta(
      id: id,
      ownerProfileId: json['owner_profile_id']?.toString() ?? '',
      ext: json['ext']?.toString() ?? 'bin',
      size: size,
      chunkCount: count,
      sha256: json['sha256']?.toString() ?? '',
      ready: json['status'] == 'ready',
    );
  }
}

/// Where the pieces actually go. Firestore in the app; a map in tests.
abstract class SharedMediaBackend {
  Future<void> writeMeta(SharedMediaMeta meta);
  Future<void> writeChunk(String id, int index, Uint8List bytes);
  Future<SharedMediaMeta?> readMeta(String id);
  Future<Uint8List?> readChunk(String id, int index);
  Future<void> deleteChunk(String id, int index);
  Future<void> deleteMeta(String id);

  /// The ids of every file shared as [ownerProfileId], from the server.
  Future<List<String>> idsOwnedBy(String ownerProfileId);
}

class FirestoreSharedMediaBackend implements SharedMediaBackend {
  const FirestoreSharedMediaBackend();

  CollectionReference<Map<String, dynamic>> get _media =>
      FirebaseService.db.collection(SharedMediaService.collection);

  DocumentReference<Map<String, dynamic>> _chunk(String id, int index) =>
      _media.doc(id).collection('chunks').doc('$index');

  @override
  Future<void> writeMeta(SharedMediaMeta meta) => _media.doc(meta.id).set({
    ...meta.toJson(),
    'owner_uid': FirebaseService.currentUid,
    'created_at': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) =>
      _chunk(id, index).set({'i': index, 'data': Blob(bytes)});

  @override
  Future<SharedMediaMeta?> readMeta(String id) async {
    final snap = await _media.doc(id).get();
    return SharedMediaMeta.tryFromJson(id, snap.data());
  }

  @override
  Future<Uint8List?> readChunk(String id, int index) async {
    final snap = await _chunk(id, index).get();
    final data = snap.data()?['data'];
    return data is Blob ? data.bytes : null;
  }

  @override
  Future<void> deleteChunk(String id, int index) => _chunk(id, index).delete();

  @override
  Future<void> deleteMeta(String id) => _media.doc(id).delete();

  @override
  Future<List<String>> idsOwnedBy(String ownerProfileId) async {
    // From the server only: a cache that happens to hold none of them must
    // not read as "nothing to clean up".
    final snap = await _media
        .where('owner_profile_id', isEqualTo: ownerProfileId)
        .get(const GetOptions(source: Source.server));
    return [for (final d in snap.docs) d.id];
  }
}
