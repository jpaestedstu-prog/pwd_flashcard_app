import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/error_handler.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'hive_service.dart';

/// Handles exporting and importing individual student profiles as JSON files.
///
/// The export includes the profile data, learning progress, achievements,
/// purchased items, and equipped items — everything needed to fully
/// restore a student on another device.
class ProfileExportService {
  ProfileExportService._();

  /// Export format version for forward compatibility.
  static const int _formatVersion = 1;

  // ─── Export ────────────────────────────────────────────

  /// Exports a single student profile (with all associated data) to a
  /// JSON file and opens the platform share sheet.
  static Future<void> exportProfile(UserProfile profile) async {
    final progress = HiveService.getProgress(profile.id);
    final achievements = HiveService.getUnlockedAchievements(profile.id);
    final purchases = HiveService.getPurchasedItems(profile.id);

    // Collect equipped items
    final equipped = <String, String?>{};
    for (final type in ['avatar', 'theme', 'border']) {
      equipped[type] = HiveService.getEquippedItem(profile.id, type);
    }

    final data = <String, dynamic>{
      'formatVersion': _formatVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'profile': _profileToMap(profile),
      'progress': _progressToMap(progress),
      'achievements': achievements.toList(),
      'purchases': purchases.toList(),
      'equipped': equipped,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getTemporaryDirectory();
    final safeName = profile.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/student_${safeName}_$timestamp.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Student Profile – ${profile.name}',
      text: 'Student profile "${profile.name}" exported from FlashLearn PWD.',
    );
  }

  // ─── Import ────────────────────────────────────────────

  /// Opens a file picker for the user to select a JSON profile file,
  /// parses it, and saves the profile + all associated data to Hive.
  ///
  /// Returns a result record: `(success, message)`.
  static Future<({bool success, String message})> importProfile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) {
      return (success: false, message: 'No file selected');
    }

    try {
      final path = result.files.single.path;
      if (path == null) {
        return (success: false, message: 'Could not read file');
      }

      final file = File(path);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data is! Map<String, dynamic>) {
        return (success: false, message: 'Invalid file format');
      }

      // Validate format
      if (!data.containsKey('profile') || !data.containsKey('progress')) {
        return (
          success: false,
          message: 'This file does not contain a valid student profile',
        );
      }

      final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
      final progressMap = Map<String, dynamic>.from(data['progress'] as Map);

      // Parse profile
      final profile = _profileFromMap(profileMap);

      // Check for duplicate ID
      final existing = HiveService.getProfiles();
      final duplicate = existing.any((p) => p['id'] == profile.id);

      if (duplicate) {
        return (
          success: false,
          message:
              'A profile with this ID already exists. Delete it first or export from a different device.',
        );
      }

      // Save profile
      await HiveService.saveProfile(profile);

      // Save progress
      final progress = _progressFromMap(profile.id, progressMap);
      await HiveService.saveProgress(progress);

      // Save achievements
      if (data['achievements'] is List) {
        final achievements = Set<String>.from(
          (data['achievements'] as List).map((e) => e.toString()),
        );
        if (achievements.isNotEmpty) {
          await HiveService.saveUnlockedAchievements(profile.id, achievements);
        }
      }

      // Save purchases
      if (data['purchases'] is List) {
        final purchases = Set<String>.from(
          (data['purchases'] as List).map((e) => e.toString()),
        );
        if (purchases.isNotEmpty) {
          await HiveService.savePurchasedItems(profile.id, purchases);
        }
      }

      // Save equipped items
      if (data['equipped'] is Map) {
        final equipped = Map<String, dynamic>.from(data['equipped'] as Map);
        for (final entry in equipped.entries) {
          if (entry.value is String) {
            await HiveService.saveEquippedItem(
              profile.id,
              entry.key,
              entry.value as String,
            );
          }
        }
      }

      return (
        success: true,
        message: 'Successfully imported "${profile.name}"',
      );
    } catch (e, stack) {
      ErrorHandler.report(e, stack, 'ProfileImport');
      return (success: false, message: 'Error reading file: ${e.toString()}');
    }
  }

  // ─── Serialisation helpers ─────────────────────────────

  static Map<String, dynamic> _profileToMap(UserProfile p) => {
    'id': p.id,
    'name': p.name,
    'role': p.role.index,
    'avatarIndex': p.avatarIndex,
    'createdAt': p.createdAt.toIso8601String(),
    'disabilityType': p.disabilityType.index,
    'pin': p.pin,
    'gradeLevel': p.gradeLevel?.index,
    'section': p.section,
    'birthDate': p.birthDate?.toIso8601String(),
    'tags': p.tags,
    'interests': p.interests.map((c) => c.index).toList(),
  };

  static UserProfile _profileFromMap(Map<String, dynamic> m) {
    final roleIndex = m['role'] as int;
    final disabilityIndex = m['disabilityType'] as int?;
    final gradeLevelIndex = m['gradeLevel'] as int?;
    final rawTags = m['tags'] as List?;
    final rawInterests = m['interests'] as List?;
    return UserProfile(
      id: m['id'] as String,
      name: m['name'] as String,
      role: UserRole.values[roleIndex.clamp(0, UserRole.values.length - 1)],
      avatarIndex: m['avatarIndex'] as int? ?? 0,
      createdAt: DateTime.parse(m['createdAt'] as String),
      disabilityType:
          (disabilityIndex != null &&
              disabilityIndex >= 0 &&
              disabilityIndex < DisabilityType.values.length)
          ? DisabilityType.values[disabilityIndex]
          : DisabilityType.none,
      pin: m['pin'] as String?,
      gradeLevel:
          (gradeLevelIndex != null &&
              gradeLevelIndex >= 0 &&
              gradeLevelIndex < GradeLevel.values.length)
          ? GradeLevel.values[gradeLevelIndex]
          : null,
      section: m['section'] as String?,
      birthDate: m['birthDate'] != null
          ? DateTime.tryParse(m['birthDate'] as String)
          : null,
      tags: rawTags != null
          ? List<String>.from(rawTags.map((e) => e.toString()))
          : const [],
      interests: rawInterests == null
          ? const []
          : [
              for (final e in rawInterests)
                if ((e is int ? e : int.tryParse(e.toString())) case final i?
                    when i >= 0 && i < FlashcardCategory.values.length)
                  FlashcardCategory.values[i],
            ],
    );
  }

  static Map<String, dynamic> _progressToMap(LearningProgress p) => {
    'wordsLearned': p.wordsLearned,
    'learnedWordIds': p.learnedWordIds.toList(),
    'streakDays': p.streakDays,
    'lastActivityDate': p.lastActivityDate.toIso8601String(),
    'totalStars': p.totalStars,
    'spentStars': p.spentStars,
    // Lifetime high-water marks. A backup that omits them restores a
    // learner who has "never" had a long streak or tried a second game —
    // which costs them XP, their level, and their badges.
    'bestStreakDays': p.effectiveBestStreak,
    'gamesPlayed': p.effectiveGamesPlayed,
    'playedGameTypes': gameTypeNames(p.effectivePlayedGameTypes),
    'gameBestStars': p.effectiveGameBestStars,
    'categoryProgress': p.categoryProgress,
    'recentScores': p.recentScores
        .map(
          (s) => {
            'gameType': s.gameType.index,
            'score': s.score,
            'total': s.total,
            'starsEarned': s.starsEarned,
            'date': s.date.toIso8601String(),
            'durationSeconds': s.durationSeconds,
          },
        )
        .toList(),
  };

  static LearningProgress _progressFromMap(
    String profileId,
    Map<String, dynamic> m,
  ) {
    final rawScores = m['recentScores'] as List? ?? [];
    final scores = <GameScore>[];
    for (final e in rawScores) {
      try {
        final sm = Map<String, dynamic>.from(e as Map);
        final gameTypeIndex = sm['gameType'] as int;
        if (gameTypeIndex < 0 || gameTypeIndex >= GameType.values.length) {
          continue;
        }
        scores.add(
          GameScore(
            gameType: GameType.values[gameTypeIndex],
            score: sm['score'] as int,
            total: sm['total'] as int,
            starsEarned: sm['starsEarned'] as int,
            date: DateTime.parse(sm['date'] as String),
            durationSeconds: sm['durationSeconds'] as int?,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    final rawWordIds = m['learnedWordIds'] as List? ?? [];
    final wordIds = Set<String>.from(rawWordIds.map((e) => e.toString()));

    return LearningProgress(
      profileId: profileId,
      wordsLearned: wordIds.isNotEmpty
          ? wordIds.length
          : (m['wordsLearned'] ?? 0),
      learnedWordIds: wordIds,
      streakDays: m['streakDays'] ?? 0,
      lastActivityDate: DateTime.parse(m['lastActivityDate'] as String),
      totalStars: m['totalStars'] ?? 0,
      spentStars: m['spentStars'] ?? 0,
      // Absent from backups written before these were exported; the model's
      // `effective*` getters heal the 0 from whatever the row still holds.
      bestStreakDays: m['bestStreakDays'] ?? 0,
      gamesPlayed: m['gamesPlayed'] ?? 0,
      playedGameTypes: gameTypesFromNames(m['playedGameTypes']),
      gameBestStars: ((m['gameBestStars'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      categoryProgress: Map<String, double>.from(m['categoryProgress'] ?? {}),
      recentScores: scores,
    );
  }
}
