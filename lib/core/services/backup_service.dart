import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/error_handler.dart';

/// Handles full app data backup and restore.
///
/// Backup file format: gzip-compressed JSON containing all Hive box data,
/// a version number for future migration, and a creation timestamp.
/// File extension: `.flashlearn`
class BackupService {
  BackupService._();

  static const int _backupVersion = 1;

  static const List<String> _boxNames = [
    'profiles',
    'settings',
    'progress',
    'custom_cards',
    'sessions',
  ];

  // ─── Create Backup ──────────────────────────────────

  /// Generates a backup of all app data and opens the share sheet.
  /// Returns `true` if the backup was created successfully.
  static Future<bool> createBackup() async {
    try {
      final backupData = <String, dynamic>{
        'version': _backupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'appName': 'FlashLearn PWD',
        'boxes': <String, dynamic>{},
      };

      // Read all Hive box data
      for (final boxName in _boxNames) {
        final box = Hive.box(boxName);
        final boxData = <String, dynamic>{};
        for (final key in box.keys) {
          final value = box.get(key);
          boxData[key.toString()] = _serializeValue(value);
        }
        (backupData['boxes'] as Map<String, dynamic>)[boxName] = boxData;
      }

      // Convert to JSON and compress
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final compressed = gzip.encode(utf8.encode(jsonString));

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/flashlearn_backup_$timestamp.flashlearn');
      await file.writeAsBytes(compressed);

      // Share via platform share sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'FlashLearn PWD – Full Backup',
        text: 'Full app backup from FlashLearn PWD.',
      );

      // Save last backup timestamp
      final settingsBox = Hive.box('settings');
      await settingsBox.put(
        'lastBackupDate',
        DateTime.now().toIso8601String(),
      );

      return true;
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'BackupService.create');
      return false;
    }
  }

  // ─── Restore Backup ─────────────────────────────────

  /// Opens file picker and restores from a `.flashlearn` backup file.
  /// Returns a [BackupRestoreResult] with status information.
  static Future<BackupRestoreResult> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        
      );

      if (result == null || result.files.isEmpty) {
        return const BackupRestoreResult(
          success: false,
          message: 'No file selected.',
        );
      }

      final path = result.files.single.path;
      if (path == null) {
        return const BackupRestoreResult(
          success: false,
          message: 'Could not read file.',
        );
      }

      final file = File(path);
      return await restoreFromFile(file);
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Error selecting file: $e',
      );
    }
  }

  /// Restores data from a backup file directly.
  static Future<BackupRestoreResult> restoreFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();

      // Decompress
      List<int> decompressed;
      try {
        decompressed = gzip.decode(bytes);
      } catch (_) {
        return const BackupRestoreResult(
          success: false,
          message: 'Invalid backup file. The file may be corrupted.',
        );
      }

      // Parse JSON
      Map<String, dynamic> backupData;
      try {
        backupData =
            jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;
      } catch (_) {
        return const BackupRestoreResult(
          success: false,
          message: 'Invalid backup format. Could not parse data.',
        );
      }

      // Version check
      final version = backupData['version'] as int? ?? 0;
      if (version > _backupVersion) {
        return const BackupRestoreResult(
          success: false,
          message:
              'This backup was created with a newer version of FlashLearn PWD. '
              'Please update the app first.',
        );
      }

      // Validate structure
      final boxes = backupData['boxes'] as Map<String, dynamic>?;
      if (boxes == null) {
        return const BackupRestoreResult(
          success: false,
          message: 'Invalid backup structure. No data found.',
        );
      }

      // Restore each box
      for (final boxName in _boxNames) {
        final boxData = boxes[boxName] as Map<String, dynamic>?;
        if (boxData == null) continue;

        final box = Hive.box(boxName);
        await box.clear(); // Clear existing data first

        for (final entry in boxData.entries) {
          final value = _deserializeValue(entry.value);
          await box.put(entry.key, value);
        }
      }

      final createdAt = backupData['createdAt'] as String? ?? 'Unknown';

      return BackupRestoreResult(
        success: true,
        message: 'Backup restored successfully!',
        backupDate: createdAt,
        profileCount: _countProfiles(boxes),
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        message: 'Failed to restore backup: $e',
      );
    }
  }

  // ─── Preview Backup ─────────────────────────────────

  /// Reads a backup file without restoring and returns summary info.
  static Future<BackupSummary?> previewBackup(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decompressed = gzip.decode(bytes);
      final backupData =
          jsonDecode(utf8.decode(decompressed)) as Map<String, dynamic>;

      final boxes = backupData['boxes'] as Map<String, dynamic>? ?? {};
      final profileCount = _countProfiles(boxes);

      // Count custom cards
      final customCardsBox = boxes['custom_cards'] as Map<String, dynamic>?;
      final cardsList = customCardsBox?['cards'] as List<dynamic>?;
      final cardCount = cardsList?.length ?? 0;

      return BackupSummary(
        version: backupData['version'] as int? ?? 0,
        createdAt: backupData['createdAt'] as String? ?? 'Unknown',
        profileCount: profileCount,
        customCardCount: cardCount,
        fileSizeBytes: bytes.length,
      );
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'BackupService.previewBackup');
      return null;
    }
  }

  // ─── Helpers ────────────────────────────────────────

  static int _countProfiles(Map<String, dynamic> boxes) {
    final profilesBox = boxes['profiles'] as Map<String, dynamic>?;
    if (profilesBox == null) return 0;
    final profiles = profilesBox['profiles'];
    if (profiles is List) return profiles.length;
    return 0;
  }

  /// Get the last backup date from settings.
  static String? getLastBackupDate() {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('lastBackupDate') as String?;
  }

  /// Recursively serialize Hive values to JSON-safe types.
  static dynamic _serializeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_serializeValue).toList();
    }
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _serializeValue(val)),
      );
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }

  /// Recursively deserialize JSON values back to Hive-compatible types.
  static dynamic _deserializeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_deserializeValue).toList();
    }
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _deserializeValue(val)),
      );
    }
    return value;
  }
}

/// Result of a backup restore operation.
class BackupRestoreResult {
  final bool success;
  final String message;
  final String? backupDate;
  final int? profileCount;

  const BackupRestoreResult({
    required this.success,
    required this.message,
    this.backupDate,
    this.profileCount,
  });
}

/// Summary of a backup file for preview.
class BackupSummary {
  final int version;
  final String createdAt;
  final int profileCount;
  final int customCardCount;
  final int fileSizeBytes;

  const BackupSummary({
    required this.version,
    required this.createdAt,
    required this.profileCount,
    required this.customCardCount,
    required this.fileSizeBytes,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
