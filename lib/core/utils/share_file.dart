import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// One file the app made, ready to hand over: its name, contents and type.
typedef ShareableFile = ({String name, List<int> bytes, String mimeType});

/// Hands the files the app makes (reports, data exports) to the person: the
/// share sheet on a device, to save to Drive or send by email; in a browser,
/// the browser's own share sheet where there is one, or a download.
///
/// A browser has no temporary folder to write a file into first, and that is
/// what every export did, so every export failed there. Here the browser is
/// handed the bytes instead.
abstract final class ShareFile {
  /// The file as one [ShareableFile], from text (CSV, JSON) in UTF-8.
  static ShareableFile text(String content, {
    required String name,
    required String mimeType,
  }) =>
      (name: name, bytes: utf8.encode(content), mimeType: mimeType);

  /// Shares [files] together, as one share or one download each.
  static Future<void> share(
    List<ShareableFile> files, {
    String? subject,
    String? text,
  }) async {
    if (files.isEmpty) return;
    final named = [
      for (final f in files) (f, safeName(f.name)),
    ];
    if (kIsWeb) {
      await Share.shareXFiles(
        [
          for (final (f, name) in named)
            XFile.fromData(_bytes(f.bytes), name: name, mimeType: f.mimeType),
        ],
        subject: subject,
        text: text,
        fileNameOverrides: [for (final (_, name) in named) name],
      );
      return;
    }
    final tmp = await getTemporaryDirectory();
    final xfiles = <XFile>[];
    for (final (f, name) in named) {
      final file = File('${tmp.path}/$name');
      await file.writeAsBytes(f.bytes, flush: true);
      xfiles.add(XFile(file.path, mimeType: f.mimeType, name: name));
    }
    await Share.shareXFiles(xfiles, subject: subject, text: text);
  }

  /// [name] with the characters a file name cannot hold replaced. A learner
  /// called "Cognitive/Learning Anak" made the report path point into a
  /// folder that does not exist, and the export failed.
  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    return cleaned.trim().isEmpty ? 'FlashLearn' : cleaned.trim();
  }

  static Uint8List _bytes(List<int> bytes) =>
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

/// Reads one file the person picks, whole: on a device from its path, in a
/// browser from the bytes the picker hands over (a browser gives no path).
/// Null when nothing was picked or it could not be read.
abstract final class PickFile {
  static Future<Uint8List?> bytes({List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    if (kIsWeb) return picked.bytes;
    final path = picked.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }
}
