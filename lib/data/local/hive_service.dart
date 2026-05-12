import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/active_time_log.dart';
import '../models/child_alarm.dart';
import '../models/child_time_limit.dart';
import '../models/models.dart';
import '../models/enums.dart';
import '../models/classroom.dart';
import '../models/classroom_member.dart';
import '../models/home_group.dart';
import '../models/home_group_member.dart';
import '../../features/mood_tracker/models/mood_models.dart';
import '../../features/messaging/models/messaging_models.dart';
import '../../features/goals/models/goal_model.dart';
import '../../features/word_of_day/models/word_of_day_models.dart';
import '../../features/focus_mode/models/focus_mode_models.dart';
import '../../features/parent_teacher_notes/models/parent_teacher_note_models.dart';
import '../../core/services/sync_queue/sync_queue_storage.dart';

/// Manages all local Hive storage operations
class HiveService {
  static const String _profilesBox = 'profiles';
  static const String _settingsBox = 'settings';
  static const String _progressBox = 'progress';
  static const String _customCardsBox = 'custom_cards';
  static const String _sessionsBox = 'sessions';
  static const String _classroomsBox = 'classrooms';
  static const String _membersBox = 'classroom_members';
  static const String _homeGroupsBox = 'home_groups';
  static const String _homeGroupMembersBox = 'home_group_members';
  static const String _childAlarmsBox = 'child_alarms';
  static const String _childTimeLimitsBox = 'child_time_limits';
  static const String _activeTimeLogsBox = 'active_time_logs';

  /// Initialize Hive and open all boxes
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_profilesBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_progressBox);
    await Hive.openBox(_customCardsBox);
    await Hive.openBox(_sessionsBox);
    await Hive.openBox(_classroomsBox);
    await Hive.openBox(_membersBox);
    await Hive.openBox(_homeGroupsBox);
    await Hive.openBox(_homeGroupMembersBox);
    await Hive.openBox(_childAlarmsBox);
    await Hive.openBox(_childTimeLimitsBox);
    await Hive.openBox(_activeTimeLogsBox);
    // Open the sync queue box for offline change tracking
    await SyncQueueStorage.init();
    // One-shot migration to per-student note keys. Idempotent.
    await migrateNotesToStudentKeyedV1();
  }

  // ─── Profile ──────────────────────────────────────────

  static Box get _profileBox => Hive.box(_profilesBox);

  static List<Map<String, dynamic>> getProfiles() {
    final profiles = _profileBox.get('profiles', defaultValue: <dynamic>[]);
    return List<Map<String, dynamic>>.from(
      (profiles as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final profiles = getProfiles();
    // Remove existing profile with the same ID (upsert)
    profiles.removeWhere((p) => p['id'] == profile.id);
    profiles.add({
      'id': profile.id,
      'name': profile.name,
      'role': profile.role.index,
      'avatarIndex': profile.avatarIndex,
      'createdAt': profile.createdAt.toIso8601String(),
      'disabilityType': profile.disabilityType.index,
      'pin': profile.pin,
      'pinHash': profile.pinHash,
      'pinSalt': profile.pinSalt,
      'pinHashAlgorithm': profile.pinHashAlgorithm,
      'failedAttempts': profile.failedAttempts,
      'lockedUntil': profile.lockedUntil?.toIso8601String(),
      'recoveryCodeHash': profile.recoveryCodeHash,
      'recoveryCodeSalt': profile.recoveryCodeSalt,
      'gradeLevel': profile.gradeLevel?.index,
      'section': profile.section,
      'birthDate': profile.birthDate?.toIso8601String(),
      'tags': profile.tags,
      'classroomId': profile.classroomId,
      'homeGroupId': profile.homeGroupId,
      'isGuestPlayer': profile.isGuestPlayer,
      'learningLevel': profile.learningLevel?.index,
      'learningLevelOverriddenBy': profile.learningLevelOverriddenBy,
      'learningLevelOverriddenAt':
          profile.learningLevelOverriddenAt?.toIso8601String(),
      'ownerUid': profile.ownerUid,
    });
    await _profileBox.put('profiles', profiles);
  }

  /// Patch a single field on a profile map without round-tripping the whole
  /// UserProfile object. Used by the PIN dialog to update lockout state on
  /// every keystroke without redundant work.
  static Future<void> _patchProfile(
      String profileId, Map<String, dynamic> patch) async {
    final profiles = getProfiles();
    final idx = profiles.indexWhere((p) => p['id'] == profileId);
    if (idx == -1) return;
    profiles[idx] = {...profiles[idx], ...patch};
    await _profileBox.put('profiles', profiles);
  }

  static Future<void> bumpFailedAttempts(
      String profileId, DateTime? lockedUntil) async {
    final profiles = getProfiles();
    final idx = profiles.indexWhere((p) => p['id'] == profileId);
    if (idx == -1) return;
    final current = (profiles[idx]['failedAttempts'] as int?) ?? 0;
    await _patchProfile(profileId, {
      'failedAttempts': current + 1,
      'lockedUntil': lockedUntil?.toIso8601String(),
    });
  }

  static Future<void> clearFailedAttempts(String profileId) async {
    await _patchProfile(profileId, {
      'failedAttempts': 0,
      'lockedUntil': null,
    });
  }

  /// Returns a fully-deserialized profile by id, or null if not found.
  /// Used by the PIN dialog to read fresh `failedAttempts`/`lockedUntil`
  /// state on every open without re-loading the entire profile list.
  static UserProfile? getProfileById(String profileId) {
    final profiles = getProfiles();
    final data = profiles.firstWhere(
      (p) => p['id'] == profileId,
      orElse: () => const {},
    );
    if (data.isEmpty) return null;
    try {
      final roleIndex = data['role'] as int;
      if (roleIndex < 0 || roleIndex >= UserRole.values.length) return null;
      return _deserializeProfile(
        data,
        roleIndex,
        data['disabilityType'] as int?,
        data['gradeLevel'] as int?,
        data['tags'] as List?,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HiveService.getProfileById: corrupted entry: $e');
      }
      return null;
    }
  }

  static UserProfile _deserializeProfile(
    Map<String, dynamic> data,
    int roleIndex,
    int? disabilityIndex,
    int? gradeLevelIndex,
    List? rawTags,
  ) {
    return UserProfile(
      id: data['id'],
      name: data['name'],
      role: UserRole.values[roleIndex],
      avatarIndex: data['avatarIndex'] ?? 0,
      createdAt: DateTime.parse(data['createdAt']),
      disabilityType: (disabilityIndex != null &&
              disabilityIndex >= 0 &&
              disabilityIndex < DisabilityType.values.length)
          ? DisabilityType.values[disabilityIndex]
          : DisabilityType.none,
      pin: data['pin'] as String?,
      pinHash: data['pinHash'] as String?,
      pinSalt: data['pinSalt'] as String?,
      pinHashAlgorithm: data['pinHashAlgorithm'] as String?,
      failedAttempts: (data['failedAttempts'] as int?) ?? 0,
      lockedUntil: data['lockedUntil'] != null
          ? DateTime.tryParse(data['lockedUntil'] as String)
          : null,
      recoveryCodeHash: data['recoveryCodeHash'] as String?,
      recoveryCodeSalt: data['recoveryCodeSalt'] as String?,
      gradeLevel: (gradeLevelIndex != null &&
              gradeLevelIndex >= 0 &&
              gradeLevelIndex < GradeLevel.values.length)
          ? GradeLevel.values[gradeLevelIndex]
          : null,
      section: data['section'] as String?,
      birthDate: data['birthDate'] != null
          ? DateTime.tryParse(data['birthDate'] as String)
          : null,
      tags: rawTags != null
          ? List<String>.from(rawTags.map((e) => e.toString()))
          : const [],
      classroomId: data['classroomId'] as String?,
      homeGroupId: data['homeGroupId'] as String?,
      isGuestPlayer: data['isGuestPlayer'] as bool? ?? false,
      learningLevel: () {
        final idx = data['learningLevel'] as int?;
        if (idx == null || idx < 0 || idx >= LearningLevel.values.length) {
          return null;
        }
        return LearningLevel.values[idx];
      }(),
      learningLevelOverriddenBy:
          data['learningLevelOverriddenBy'] as String?,
      learningLevelOverriddenAt: data['learningLevelOverriddenAt'] != null
          ? DateTime.tryParse(data['learningLevelOverriddenAt'] as String)
          : null,
      ownerUid: data['ownerUid'] as String?,
    );
  }

  static String? getActiveProfileId() {
    return _profileBox.get('activeProfileId');
  }

  static Future<void> setActiveProfileId(String id) async {
    await _profileBox.put('activeProfileId', id);
  }

  /// Clear the active profile id — used when the educator evicts the
  /// learner from a class / home group so the next app launch lands on
  /// the role-selection screen instead of an orphaned profile.
  static Future<void> clearActiveProfileId() async {
    await _profileBox.delete('activeProfileId');
  }

  static bool get hasProfiles => getProfiles().isNotEmpty;

  /// Deletes a profile by ID and its associated progress data.
  static Future<void> deleteProfile(String profileId) async {
    final profiles = getProfiles();
    profiles.removeWhere((p) => p['id'] == profileId);
    await _profileBox.put('profiles', profiles);
    // Clear active profile if it was the deleted one
    if (getActiveProfileId() == profileId) {
      await _profileBox.delete('activeProfileId');
    }
    // Remove associated progress
    _progressCache.remove(profileId);
    final progressBox = Hive.box(_progressBox);
    await progressBox.delete(profileId);
    await progressBox.delete('achievements_$profileId');
  }

  // ─── Settings ──────────────────────────────────────────

  static Box get _settBox => Hive.box(_settingsBox);

  static AppSettings getSettings() {
    return AppSettings(
      fontScale: _settBox.get('fontScale', defaultValue: 1.0),
      highContrastMode: _settBox.get('highContrastMode', defaultValue: false),
      darkMode: _settBox.get('darkMode', defaultValue: false),
      ttsEnabled: _settBox.get('ttsEnabled', defaultValue: true),
      ttsSpeed: _settBox.get('ttsSpeed', defaultValue: 0.5),
      reducedMotion: _settBox.get('reducedMotion', defaultValue: false),
      soundEffects: _settBox.get('soundEffects', defaultValue: true),
      speechToText: _settBox.get('speechToText', defaultValue: false),
      locale: _settBox.get('locale', defaultValue: 'en'),
      notificationsEnabled: _settBox.get('notificationsEnabled', defaultValue: true),
      reminderHour: _settBox.get('reminderHour', defaultValue: 9),
      reminderMinute: _settBox.get('reminderMinute', defaultValue: 0),
      voiceNavigation: _settBox.get('voiceNavigation', defaultValue: false),
      adaptiveDifficulty: _settBox.get('adaptiveDifficulty', defaultValue: true),
      vocabReviewEnabled: _settBox.get('vocabReviewEnabled', defaultValue: false),
    );
  }

  static Future<void> saveSettings(AppSettings settings) async {
    await _settBox.put('fontScale', settings.fontScale);
    await _settBox.put('highContrastMode', settings.highContrastMode);
    await _settBox.put('darkMode', settings.darkMode);
    await _settBox.put('ttsEnabled', settings.ttsEnabled);
    await _settBox.put('ttsSpeed', settings.ttsSpeed);
    await _settBox.put('reducedMotion', settings.reducedMotion);
    await _settBox.put('soundEffects', settings.soundEffects);
    await _settBox.put('speechToText', settings.speechToText);
    await _settBox.put('locale', settings.locale);
    await _settBox.put('notificationsEnabled', settings.notificationsEnabled);
    await _settBox.put('reminderHour', settings.reminderHour);
    await _settBox.put('reminderMinute', settings.reminderMinute);
    await _settBox.put('voiceNavigation', settings.voiceNavigation);
    await _settBox.put('adaptiveDifficulty', settings.adaptiveDifficulty);
    await _settBox.put('vocabReviewEnabled', settings.vocabReviewEnabled);
  }

  /// Generic setting getter — read any key from the settings box.
  static dynamic getSetting(String key) => _settBox.get(key);

  /// Generic setting setter — write any key to the settings box.
  static Future<void> saveSetting(String key, dynamic value) async {
    await _settBox.put(key, value);
  }

  // ─── Progress ──────────────────────────────────────────

  static Box get _progBox => Hive.box(_progressBox);

  // In-memory cache to avoid repeated Hive reads + deserialization.
  // Bounded by profile count (typically < 50) so no eviction needed.
  static final Map<String, LearningProgress> _progressCache = {};

  /// Invalidate the cached progress for a profile (call after saves).
  static void invalidateProgressCache([String? profileId]) {
    if (profileId != null) {
      _progressCache.remove(profileId);
    } else {
      _progressCache.clear();
    }
  }

  static LearningProgress getProgress(String profileId) {
    // Return cached value if available
    final cached = _progressCache[profileId];
    if (cached != null) return cached;

    final data = _progBox.get(profileId);
    if (data == null) {
      return LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
      );
    }
    final map = Map<String, dynamic>.from(data as Map);
    // Restore recent scores
    final rawScores = map['recentScores'] as List? ?? [];
    final scores = <GameScore>[];
    for (final e in rawScores) {
      try {
        final m = Map<String, dynamic>.from(e as Map);
        final gameTypeIndex = m['gameType'] as int;
        if (gameTypeIndex < 0 || gameTypeIndex >= GameType.values.length) continue;
        scores.add(GameScore(
          gameType: GameType.values[gameTypeIndex],
          score: m['score'] as int,
          total: m['total'] as int,
          starsEarned: m['starsEarned'] as int,
          date: DateTime.parse(m['date'] as String),
          durationSeconds: m['durationSeconds'] as int?,
        ));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('HiveService: Skipping corrupted score entry: $e');
        }
        continue;
      }
    }
    // Restore unique learned word IDs
    final rawWordIds = map['learnedWordIds'] as List? ?? [];
    final wordIds = Set<String>.from(rawWordIds.map((e) => e.toString()));

    final progress = LearningProgress(
      profileId: profileId,
      wordsLearned: wordIds.isNotEmpty ? wordIds.length : (map['wordsLearned'] ?? 0),
      learnedWordIds: wordIds,
      streakDays: map['streakDays'] ?? 0,
      lastActivityDate: DateTime.parse(map['lastActivityDate']),
      totalStars: map['totalStars'] ?? 0,
      spentStars: map['spentStars'] ?? 0,
      categoryProgress: Map<String, double>.from(map['categoryProgress'] ?? {}),
      recentScores: scores,
    );

    _progressCache[profileId] = progress;
    return progress;
  }

  static Future<void> saveProgress(LearningProgress progress) async {
    // Invalidate cache before persisting so subsequent reads are fresh.
    _progressCache.remove(progress.profileId);
    await _progBox.put(progress.profileId, {
      'wordsLearned': progress.wordsLearned,
      'learnedWordIds': progress.learnedWordIds.toList(),
      'streakDays': progress.streakDays,
      'lastActivityDate': progress.lastActivityDate.toIso8601String(),
      'totalStars': progress.totalStars,
      'spentStars': progress.spentStars,
      'categoryProgress': progress.categoryProgress,
      'recentScores': progress.recentScores.map((s) => {
        'gameType': s.gameType.index,
        'score': s.score,
        'total': s.total,
        'starsEarned': s.starsEarned,
        'date': s.date.toIso8601String(),
        'durationSeconds': s.durationSeconds,
      }).toList(),
    });
  }

  // ─── Custom Cards ──────────────────────────────────────

  static Box get _customBox => Hive.box(_customCardsBox);

  static List<Flashcard> getCustomCards() {
    final cards = _customBox.get('cards', defaultValue: <dynamic>[]);
    final result = <Flashcard>[];
    for (final e in (cards as List)) {
      try {
        final m = Map<String, dynamic>.from(e as Map);
        final catIndex = m['category'] as int;
        if (catIndex < 0 || catIndex >= FlashcardCategory.values.length) continue;
        result.add(Flashcard(
          id: m['id'],
          wordEnglish: m['wordEnglish'],
          wordFilipino: m['wordFilipino'],
          exampleSentence: m['exampleSentence'],
          imageAsset: m['imageAsset'],
          category: FlashcardCategory.values[catIndex],
          isCustom: true,
        ));
      } catch (_) {
        // Skip corrupted card entries
        continue;
      }
    }
    return result;
  }

  static Future<void> saveCustomCard(Flashcard card) async {
    final cards = _customBox.get('cards', defaultValue: <dynamic>[]);
    final list = List<dynamic>.from(cards as List);
    list.add({
      'id': card.id,
      'wordEnglish': card.wordEnglish,
      'wordFilipino': card.wordFilipino,
      'exampleSentence': card.exampleSentence,
      'imageAsset': card.imageAsset,
      'category': card.category.index,
    });
    await _customBox.put('cards', list);
  }

  static Future<void> updateCustomCard(Flashcard card) async {
    final cards = _customBox.get('cards', defaultValue: <dynamic>[]);
    final list = List<dynamic>.from(cards as List);
    final idx = list.indexWhere((e) => (e as Map)['id'] == card.id);
    if (idx == -1) return;
    list[idx] = {
      'id': card.id,
      'wordEnglish': card.wordEnglish,
      'wordFilipino': card.wordFilipino,
      'exampleSentence': card.exampleSentence,
      'imageAsset': card.imageAsset,
      'category': card.category.index,
    };
    await _customBox.put('cards', list);
  }

  static Future<void> deleteCustomCard(String cardId) async {
    final cards = _customBox.get('cards', defaultValue: <dynamic>[]);
    final list = List<dynamic>.from(cards as List);
    list.removeWhere((e) => (e as Map)['id'] == cardId);
    await _customBox.put('cards', list);
  }

  // ─── Achievements ──────────────────────────────────────

  static Set<String> getUnlockedAchievements(String profileId) {
    final data = _progBox.get('achievements_$profileId');
    if (data == null) return {};
    return Set<String>.from(data as List);
  }

  static Future<void> saveUnlockedAchievements(
      String profileId, Set<String> ids) async {
    await _progBox.put('achievements_$profileId', ids.toList());
  }

  // ─── Tutorial ──────────────────────────────────────────

  static bool hasSeenTutorial(String profileId) {
    return _progBox.get('tutorial_$profileId', defaultValue: false) as bool;
  }

  static Future<void> markTutorialSeen(String profileId) async {
    await _progBox.put('tutorial_$profileId', true);
  }

  // ─── Collapsed Categories ─────────────────────────────

  static Set<String> getCollapsedCategories(String profileId) {
    final raw = _progBox.get('collapsed_cats_$profileId');
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  static Future<void> saveCollapsedCategories(
    String profileId,
    Set<String> collapsed,
  ) async {
    await _progBox.put('collapsed_cats_$profileId', collapsed.toList());
  }

  /// Per-screen tutorial tracking (e.g. 'flashcard_viewer', 'game_hub', 'progress').
  static bool hasSeenScreenTutorial(String profileId, String screenId) {
    return _progBox.get('tutorial_${screenId}_$profileId', defaultValue: false) as bool;
  }

  static Future<void> markScreenTutorialSeen(String profileId, String screenId) async {
    await _progBox.put('tutorial_${screenId}_$profileId', true);
  }

  /// Reset all tutorial flags for a profile (re-run tutorials).
  static Future<void> resetAllTutorials(String profileId) async {
    await _progBox.put('tutorial_$profileId', false);
    for (final screen in ['flashcard_viewer', 'game_hub', 'progress']) {
      await _progBox.put('tutorial_${screen}_$profileId', false);
    }
  }

  // ─── Daily Challenge ───────────────────────────────────

  /// Returns the date key (e.g. "2026-02-13") of the last completed challenge.
  static String? getDailyChallengeDate(String profileId) {
    return _progBox.get('daily_date_$profileId') as String?;
  }

  static Future<void> saveDailyChallengeDate(
      String profileId, String dateKey) async {
    await _progBox.put('daily_date_$profileId', dateKey);
    // Also record in history set for the calendar view
    final history = getDailyChallengeHistory(profileId);
    history.add(dateKey);
    await _progBox.put(
        'daily_history_$profileId', history.toList());
  }

  /// Returns the set of all date keys where the daily challenge was completed.
  static Set<String> getDailyChallengeHistory(String profileId) {
    final raw =
        _progBox.get('daily_history_$profileId', defaultValue: <dynamic>[]);
    return Set<String>.from((raw as List).map((e) => e.toString()));
  }

  static int getDailyChallengeStreak(String profileId) {
    return _progBox.get('daily_streak_$profileId', defaultValue: 0) as int;
  }

  static Future<void> incrementDailyChallengeStreak(String profileId) async {
    final current = getDailyChallengeStreak(profileId);
    await _progBox.put('daily_streak_$profileId', current + 1);
  }

  static Future<void> resetDailyChallengeStreak(String profileId) async {
    await _progBox.put('daily_streak_$profileId', 0);
  }

  // ─── Daily Login Rewards ──────────────────────────────

  /// Returns the date key of the last claimed login reward, or null.
  static String? getLoginRewardDate(String profileId) {
    return _progBox.get('login_reward_date_$profileId') as String?;
  }

  static Future<void> saveLoginRewardDate(
      String profileId, String dateKey) async {
    await _progBox.put('login_reward_date_$profileId', dateKey);
  }

  static int getLoginRewardStreak(String profileId) {
    return _progBox.get('login_reward_streak_$profileId', defaultValue: 0)
        as int;
  }

  static Future<void> saveLoginRewardStreak(
      String profileId, int streak) async {
    await _progBox.put('login_reward_streak_$profileId', streak);
  }

  // ─── All Profiles with Progress (for multi-student dashboard) ────

  static List<(UserProfile, LearningProgress)> getAllProfilesWithProgress() {
    final profiles = getProfiles();
    final result = <(UserProfile, LearningProgress)>[];
    for (final data in profiles) {
      try {
        final roleIndex = data['role'] as int;
        if (roleIndex < 0 || roleIndex >= UserRole.values.length) continue;
        final disabilityIndex = data['disabilityType'] as int?;
        final gradeLevelIndex = data['gradeLevel'] as int?;
        final rawTags = data['tags'] as List?;
        final profile = _deserializeProfile(data, roleIndex,
            disabilityIndex, gradeLevelIndex, rawTags);
        final progress = getProgress(profile.id);
        result.add((profile, progress));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('HiveService: Skipping corrupted profile entry: $e');
        }
        continue;
      }
    }
    return result;
  }
  // ─── Classrooms ────────────────────────────────────────

  static Box get _classBox => Hive.box(_classroomsBox);
  static Box get _memberBox => Hive.box(_membersBox);

  /// Cache or upsert a classroom locally (used as offline fallback for
  /// students who have already viewed the class on this device, and for
  /// teachers managing their own classes).
  static Future<void> cacheClassroom(Classroom c) async {
    await _classBox.put(c.id, c.toJson());
  }

  static Future<void> deleteClassroomLocal(String classroomId) async {
    await _classBox.delete(classroomId);
    // Cascade: drop all member rows for this classroom.
    final members = getMembers(classroomId);
    for (final m in members) {
      await _memberBox.delete('${m.classroomId}:${m.profileId}');
    }
  }

  static Classroom? getCachedClassroom(String classroomId) {
    final raw = _classBox.get(classroomId);
    if (raw == null) return null;
    try {
      return Classroom.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return null;
    }
  }

  static Classroom? getCachedClassroomByCode(String code) {
    for (final key in _classBox.keys) {
      final raw = _classBox.get(key);
      if (raw is Map && raw['code'] == code) {
        try {
          return Classroom.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static List<Classroom> getClassroomsByTeacher(String teacherId) {
    final result = <Classroom>[];
    for (final key in _classBox.keys) {
      final raw = _classBox.get(key);
      if (raw is Map && raw['teacher_id'] == teacherId) {
        try {
          result.add(Classroom.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          continue;
        }
      }
    }
    return result;
  }

  static Future<void> addMemberLocal(ClassroomMember m) async {
    await _memberBox.put('${m.classroomId}:${m.profileId}', m.toJson());
  }

  static Future<void> removeMemberLocal(
      String classroomId, String profileId) async {
    await _memberBox.delete('$classroomId:$profileId');
  }

  static List<ClassroomMember> getMembers(String classroomId) {
    final result = <ClassroomMember>[];
    final prefix = '$classroomId:';
    for (final key in _memberBox.keys) {
      if (key.toString().startsWith(prefix)) {
        final raw = _memberBox.get(key);
        if (raw is Map) {
          try {
            result.add(ClassroomMember.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {
            continue;
          }
        }
      }
    }
    return result;
  }

  // ─── Home Groups ───────────────────────────────────────
  //
  // Parallel of the classrooms cache. Parents own home groups; children
  // join via 6-char code. Same separation lets us deploy stricter rules
  // for one without affecting the other.

  static Box get _hgBox => Hive.box(_homeGroupsBox);
  static Box get _hgMemberBox => Hive.box(_homeGroupMembersBox);

  static Future<void> cacheHomeGroup(HomeGroup g) async {
    await _hgBox.put(g.id, g.toJson());
  }

  static Future<void> deleteHomeGroupLocal(String groupId) async {
    await _hgBox.delete(groupId);
    final members = getHomeGroupMembers(groupId);
    for (final m in members) {
      await _hgMemberBox.delete('${m.homeGroupId}:${m.profileId}');
    }
  }

  static HomeGroup? getCachedHomeGroup(String groupId) {
    final raw = _hgBox.get(groupId);
    if (raw == null) return null;
    try {
      return HomeGroup.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return null;
    }
  }

  static HomeGroup? getCachedHomeGroupByCode(String code) {
    for (final key in _hgBox.keys) {
      final raw = _hgBox.get(key);
      if (raw is Map && raw['code'] == code) {
        try {
          return HomeGroup.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  static List<HomeGroup> getHomeGroupsByOwner(String ownerProfileId) {
    final result = <HomeGroup>[];
    for (final key in _hgBox.keys) {
      final raw = _hgBox.get(key);
      if (raw is Map && raw['owner_profile_id'] == ownerProfileId) {
        try {
          result.add(HomeGroup.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          continue;
        }
      }
    }
    return result;
  }

  static Future<void> addHomeGroupMemberLocal(HomeGroupMember m) async {
    await _hgMemberBox.put('${m.homeGroupId}:${m.profileId}', m.toJson());
  }

  static Future<void> removeHomeGroupMemberLocal(
      String homeGroupId, String profileId) async {
    await _hgMemberBox.delete('$homeGroupId:$profileId');
  }

  static List<HomeGroupMember> getHomeGroupMembers(String homeGroupId) {
    final result = <HomeGroupMember>[];
    final prefix = '$homeGroupId:';
    for (final key in _hgMemberBox.keys) {
      if (key.toString().startsWith(prefix)) {
        final raw = _hgMemberBox.get(key);
        if (raw is Map) {
          try {
            result.add(
                HomeGroupMember.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {
            continue;
          }
        }
      }
    }
    return result;
  }

  // ─── Child Alarms (per-child, set by parent/teacher) ──

  static Box get _alarmsBox => Hive.box(_childAlarmsBox);

  static Future<void> cacheChildAlarm(ChildAlarm a) async {
    await _alarmsBox.put(a.id, a.toJson());
  }

  static Future<void> deleteChildAlarmLocal(String alarmId) async {
    await _alarmsBox.delete(alarmId);
  }

  /// Look up a single alarm by id. Returns null if not cached locally.
  /// Used by the alarm-tap handler — Firestore may not have streamed
  /// yet when the OS launches the app from a notification.
  static ChildAlarm? getChildAlarmById(String alarmId) {
    final raw = _alarmsBox.get(alarmId);
    if (raw == null) return null;
    try {
      return ChildAlarm.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return null;
    }
  }

  /// All cached alarms targeting [childProfileId]. Used by the child's
  /// device on cold start before the Firestore stream lands.
  static List<ChildAlarm> getChildAlarmsForChild(String childProfileId) {
    final result = <ChildAlarm>[];
    for (final key in _alarmsBox.keys) {
      final raw = _alarmsBox.get(key);
      if (raw is Map && raw['child_profile_id'] == childProfileId) {
        try {
          result.add(ChildAlarm.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          continue;
        }
      }
    }
    return result;
  }

  // ─── Child Time Limits ────────────────────────────────

  static Box get _limitsBox => Hive.box(_childTimeLimitsBox);

  static Future<void> cacheChildTimeLimit(ChildTimeLimit l) async {
    await _limitsBox.put(l.childProfileId, l.toJson());
  }

  static Future<void> deleteChildTimeLimitLocal(String childProfileId) async {
    await _limitsBox.delete(childProfileId);
  }

  /// Cached limit for [childProfileId], or null if none has been set.
  static ChildTimeLimit? getChildTimeLimit(String childProfileId) {
    final raw = _limitsBox.get(childProfileId);
    if (raw == null) return null;
    try {
      return ChildTimeLimit.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return null;
    }
  }

  // ─── PIN Unlock Grace (local, per child) ──────────────
  //
  // The lock screen's PIN unlock cannot write to Firestore as the
  // educator-setter from the child's device (Firestore rules require the
  // writer to own the setter profile). The grace is therefore stored
  // locally and treated as authoritative by [lockStateProvider]. A
  // best-effort Firestore mirror still runs from the lock screen so the
  // educator can audit usage when their own device happens to own the
  // setter — but the rule rejection no longer leaks to the user.

  static String _pinGraceKey(String childProfileId) =>
      'pin_grace:$childProfileId';

  /// Persist a PIN unlock grace window for [childProfileId]. ISO-8601 so
  /// the value survives Hive's typed-box round trip without a custom
  /// adapter.
  static Future<void> setPinUnlockGrace(
      String childProfileId, DateTime until) async {
    await _settBox.put(_pinGraceKey(childProfileId), until.toIso8601String());
  }

  /// Read the active grace (or null if never set / unparseable). Note:
  /// expired graces are still returned — the caller compares against
  /// `DateTime.now()` so the lock provider's recompute logic stays in
  /// one place.
  static DateTime? getPinUnlockGrace(String childProfileId) {
    final raw = _settBox.get(_pinGraceKey(childProfileId));
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Drop the grace (e.g. on sign-out or when a learner picks a new
  /// child profile on the device).
  static Future<void> clearPinUnlockGrace(String childProfileId) async {
    await _settBox.delete(_pinGraceKey(childProfileId));
  }

  // ─── Active Time Logs (foreground-minute counter) ─────

  static Box get _timeLogsBox => Hive.box(_activeTimeLogsBox);

  /// Read today's (or [dayKey]'s) counter for [profileId]. Returns a
  /// zero-valued log if nothing has been written yet so the caller can
  /// just compare `.minutesUsed` without null checks.
  static ActiveTimeLog getActiveTimeLog(String profileId, String dayKey) {
    final docId = '${profileId}_$dayKey';
    final raw = _timeLogsBox.get(docId);
    if (raw == null) {
      return ActiveTimeLog(
        profileId: profileId,
        dayKey: dayKey,
        lastIncrementAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    try {
      return ActiveTimeLog.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return ActiveTimeLog(
        profileId: profileId,
        dayKey: dayKey,
        lastIncrementAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
  }

  static Future<void> saveActiveTimeLog(ActiveTimeLog log) async {
    await _timeLogsBox.put(log.docId, log.toJson());
  }

  /// Increment today's foreground-minute counter for [profileId].
  /// Idempotent within the same wall-clock minute (caller passes the
  /// minute as part of [dayKey] / [now]).
  static Future<ActiveTimeLog> incrementActiveTime({
    required String profileId,
    required String dayKey,
    required DateTime now,
  }) async {
    final current = getActiveTimeLog(profileId, dayKey);
    final updated = current.copyWith(
      minutesUsed: current.minutesUsed + 1,
      lastIncrementAt: now,
    );
    await saveActiveTimeLog(updated);
    return updated;
  }

  /// Find every parent/teacher profile linked to [childProfileId] via
  /// either a classroom or a home group. The lock screen tries each in
  /// turn so the first matching PIN dismisses the lock.
  ///
  /// Offline fallback for `unlockingEducatorsProvider`. Local-only —
  /// the cross-device case goes through Firestore.
  static List<UserProfile> getEducatorsLinkedToChild(String childProfileId) {
    final result = <UserProfile>[];
    final seen = <String>{};

    UserProfile? lookup(String? id) {
      if (id == null) return null;
      return getProfileById(id);
    }

    // Classroom path: classroom_members → classroom → teacher_id
    for (final key in _memberBox.keys) {
      if (!key.toString().endsWith('_$childProfileId')) continue;
      final raw = _memberBox.get(key);
      if (raw is! Map) continue;
      final classroomId = raw['classroom_id'] as String?;
      if (classroomId == null) continue;
      final classroom = getCachedClassroom(classroomId);
      final teacher = lookup(classroom?.teacherId);
      if (teacher != null && seen.add(teacher.id)) result.add(teacher);
    }

    // Home-group path: home_group_members → home_group → owner_profile_id
    for (final key in _hgMemberBox.keys) {
      if (!key.toString().endsWith(':$childProfileId')) continue;
      final raw = _hgMemberBox.get(key);
      if (raw is! Map) continue;
      final groupId = raw['home_group_id'] as String?;
      if (groupId == null) continue;
      final group = getCachedHomeGroup(groupId);
      final parent = lookup(group?.ownerProfileId);
      if (parent != null && seen.add(parent.id)) result.add(parent);
    }

    return result;
  }

  // ─── Reset All Data ────────────────────────────────────

  static Future<void> clearAllData() async {
    _progressCache.clear();
    await _profileBox.clear();
    await _progBox.clear();
    await _customBox.clear();
    await _settBox.clear();
    await _sessBox.clear();
    await _classBox.clear();
    await _memberBox.clear();
    await _hgBox.clear();
    await _hgMemberBox.clear();
    await _alarmsBox.clear();
    await _limitsBox.clear();
    await _timeLogsBox.clear();
  }

  // ─── Shop / Purchases ──────────────────────────────────

  static Set<String> getPurchasedItems(String profileId) {
    final data = _progBox.get('purchases_$profileId');
    if (data == null) return {};
    return Set<String>.from(data as List);
  }

  static Future<void> savePurchasedItems(
      String profileId, Set<String> itemIds) async {
    await _progBox.put('purchases_$profileId', itemIds.toList());
  }

  // ─── Equipped Items ───────────────────────────────────

  /// Get the currently equipped item ID for a given type (avatar, theme, border).
  static String? getEquippedItem(String profileId, String type) {
    return _progBox.get('equipped_${type}_$profileId') as String?;
  }

  /// Set the equipped item for a given type. Pass null to unequip.
  static Future<void> saveEquippedItem(
      String profileId, String type, String? itemId) async {
    if (itemId == null) {
      await _progBox.delete('equipped_${type}_$profileId');
    } else {
      await _progBox.put('equipped_${type}_$profileId', itemId);
    }
  }

  // ─── Session Analytics ─────────────────────────────────

  static Box get _sessBox => Hive.box(_sessionsBox);

  static List<Map<String, dynamic>> getSessionLogs(String profileId) {
    final data = _sessBox.get('sessions_$profileId', defaultValue: <dynamic>[]);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<void> addSessionLog(
      String profileId, Map<String, dynamic> session) async {
    final sessions = getSessionLogs(profileId);
    sessions.add(session);
    // Keep only last 90 days of sessions
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    sessions.removeWhere((s) {
      final date = DateTime.tryParse(s['date'] as String? ?? '');
      return date != null && date.isBefore(cutoff);
    });
    await _sessBox.put('sessions_$profileId', sessions);
  }

  // ─── Engagement Tracking ─────────────────────────────

  static List<Map<String, dynamic>> getEngagementLogs(String profileId) {
    final data =
        _sessBox.get('engagement_$profileId', defaultValue: <dynamic>[]);
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<void> addEngagementLog(
      String profileId, Map<String, dynamic> log) async {
    final logs = getEngagementLogs(profileId);
    logs.add(log);
    // Keep only last 90 days of engagement logs
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    logs.removeWhere((l) {
      final date = DateTime.tryParse(l['date'] as String? ?? '');
      return date != null && date.isBefore(cutoff);
    });
    await _sessBox.put('engagement_$profileId', logs);
  }

  // ─── Learning Path Progress ────────────────────────────

  static Map<String, dynamic>? getLearningPathProgress(
      String profileId, String pathId) {
    final data = _progBox.get('lp_${profileId}_$pathId');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> saveLearningPathProgress(
      String profileId, String pathId, Map<String, dynamic> progress) async {
    await _progBox.put('lp_${profileId}_$pathId', progress);
  }

  static Map<String, Map<String, dynamic>> getAllLearningPathProgress(
      String profileId) {
    final result = <String, Map<String, dynamic>>{};
    final keys = _progBox.keys.where(
      (k) => k.toString().startsWith('lp_${profileId}_'),
    );
    for (final key in keys) {
      final pathId = key.toString().replaceFirst('lp_${profileId}_', '');
      final data = _progBox.get(key);
      if (data != null) {
        result[pathId] = Map<String, dynamic>.from(data as Map);
      }
    }
    return result;
  }

  // ─── FSL Video View Tracking ────────────────────────────

  /// Record that a user watched an FSL video for a given word.
  static Future<void> recordFslVideoView(
      String profileId, String category, String word) async {
    final key = 'fsl_views_$profileId';
    final raw = _progBox.get(key);
    final views = raw != null
        ? List<Map<String, dynamic>>.from(
            (raw as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];
    views.add({
      'category': category,
      'word': word,
      'date': DateTime.now().toIso8601String(),
    });
    await _progBox.put(key, views);
  }

  /// Get all FSL video views for this profile.
  static List<Map<String, dynamic>> getFslVideoViews(String profileId) {
    final raw = _progBox.get('fsl_views_$profileId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
        (raw as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  /// Get the number of unique FSL words viewed by this profile.
  static int fslUniqueWordsViewed(String profileId) {
    final views = getFslVideoViews(profileId);
    final unique = views.map((v) => '${v['category']}_${v['word']}').toSet();
    return unique.length;
  }

  // ─── Mood Tracker ──────────────────────────────────────

  /// Get mood entries for a profile. Returns typed MoodEntry list.
  static List<MoodEntry> getMoodEntries(String profileId) {
    final raw = _progBox.get('mood_entries_$profileId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map((j) => MoodEntry.fromJson(j)).toList();
  }

  /// Save mood entries for a profile.
  static Future<void> saveMoodEntries(
      String profileId, List<MoodEntry> entries) async {
    await _progBox.put(
      'mood_entries_$profileId',
      entries.map((e) => e.toJson()).toList(),
    );
  }

  // ─── Stickers ──────────────────────────────────────────

  /// Get the set of owned sticker IDs for a profile.
  static Set<String> getOwnedStickers(String profileId) {
    final raw = _progBox.get('stickers_$profileId');
    if (raw == null) return {};
    return Set<String>.from(raw as List);
  }

  /// Save owned sticker IDs for a profile.
  static Future<void> saveOwnedStickers(
      String profileId, Set<String> ids) async {
    await _progBox.put('stickers_$profileId', ids.toList());
  }

  // ─── Messaging ──────────────────────────────────────────

  /// Get all messages for a profile.
  static Future<List<LocalMessage>> getMessages(String profileId) async {
    final raw = _progBox.get('messages_$profileId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map((j) => LocalMessage.fromJson(j)).toList();
  }

  /// Save all messages for a profile.
  static Future<void> saveMessages(
      String profileId, List<LocalMessage> messages) async {
    await _progBox.put(
      'messages_$profileId',
      messages.map((m) => m.toJson()).toList(),
    );
  }

  // ─── Goals ───────────────────────────────────────────

  /// Get all learning goals for a profile.
  static List<LearningGoal> getGoals(String profileId) {
    final raw = _progBox.get('goals_$profileId');
    if (raw == null) return [];
    final result = <LearningGoal>[];
    for (final e in (raw as List)) {
      try {
        final m = Map<String, dynamic>.from(e as Map);
        result.add(LearningGoal.fromJson(m));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// Save all learning goals for a profile.
  static Future<void> saveGoals(
      String profileId, List<LearningGoal> goals) async {
    await _progBox.put(
      'goals_$profileId',
      goals.map((g) => g.toJson()).toList(),
    );
  }

  // ─── Helpers ──────────────────────────────────────────

  /// Get all profiles as raw maps (used by Messaging to enumerate users).
  static List<Map<String, dynamic>> getAllProfiles() {
    return getProfiles();
  }

  // ─── Word of the Day ────────────────────────────────

  /// Get Word of Day history records for a profile.
  static List<WordOfDayRecord> getWordOfDayHistory(String profileId) {
    final raw = _progBox.get('wotd_history_$profileId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map((j) => WordOfDayRecord.fromJson(j)).toList();
  }

  /// Save Word of Day history records for a profile.
  static Future<void> saveWordOfDayHistory(
      String profileId, List<WordOfDayRecord> records) async {
    await _progBox.put(
      'wotd_history_$profileId',
      records.map((r) => r.toJson()).toList(),
    );
  }

  // ─── Focus Mode Sessions ────────────────────────────

  /// Get focus session history for a profile.
  static List<FocusSession> getFocusSessions(String profileId) {
    final raw = _progBox.get('focus_sessions_$profileId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map((j) => FocusSession.fromJson(j)).toList();
  }

  /// Save focus sessions for a profile.
  static Future<void> saveFocusSessions(
      String profileId, List<FocusSession> sessions) async {
    await _progBox.put(
      'focus_sessions_$profileId',
      sessions.map((s) => s.toJson()).toList(),
    );
  }

  // ─── Parent-Teacher Notes ───────────────────────────
  //
  // Storage is keyed by `studentProfileId` (not author) so a teacher and
  // a parent writing about the same kid land in the same bucket and can
  // see each other's notes. Cloud mirror lives in Firestore at
  // parent_teacher_notes/{studentId}/notes/{noteId} (see ParentTeacherNotesCloudService).

  /// Notes about a specific student (regardless of who authored them).
  static List<ParentTeacherNote> getNotesForStudent(String studentId) {
    final raw = _progBox.get('pt_notes_$studentId');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ).map((j) => ParentTeacherNote.fromJson(j)).toList();
  }

  /// Append a note to its student's bucket. Writes the whole bucket back
  /// (Hive doesn't have native list-append for boxed lists).
  static Future<void> appendNoteForStudent(ParentTeacherNote note) async {
    final existing = getNotesForStudent(note.studentProfileId);
    // De-dup by id in case the cloud mirror replays the same note.
    existing.removeWhere((n) => n.id == note.id);
    existing.add(note);
    await _progBox.put(
      'pt_notes_${note.studentProfileId}',
      existing.map((n) => n.toJson()).toList(),
    );
  }

  /// Remove one note from a student's bucket.
  static Future<void> removeNoteForStudent(
      String noteId, String studentId) async {
    final existing = getNotesForStudent(studentId);
    existing.removeWhere((n) => n.id == noteId);
    await _progBox.put(
      'pt_notes_$studentId',
      existing.map((n) => n.toJson()).toList(),
    );
  }

  /// Replace the entire bucket — used by cloud hydration to overwrite
  /// stale local state with the authoritative server set.
  static Future<void> replaceNotesForStudent(
      String studentId, List<ParentTeacherNote> notes) async {
    await _progBox.put(
      'pt_notes_$studentId',
      notes.map((n) => n.toJson()).toList(),
    );
  }

  /// One-shot: re-key any pre-Phase-C notes (stored under the author's id)
  /// into per-student buckets. Idempotent — gated by a flag in the
  /// settings box. Safe to call on every boot.
  static Future<void> migrateNotesToStudentKeyedV1() async {
    const flagKey = 'pt_notes_student_keyed_v1_done';
    final settings = Hive.box(_settingsBox);
    if (settings.get(flagKey, defaultValue: false) == true) return;

    // Snapshot keys first — we'll mutate the box as we go.
    final allKeys = _progBox.keys.where((k) =>
        k is String && k.startsWith('pt_notes_')).cast<String>().toList();

    // Group every existing note by its inner studentProfileId.
    final byStudent = <String, List<ParentTeacherNote>>{};
    for (final key in allKeys) {
      final raw = _progBox.get(key);
      if (raw is! List) continue;
      for (final entry in raw) {
        if (entry is! Map) continue;
        try {
          final note = ParentTeacherNote.fromJson(
            Map<String, dynamic>.from(entry),
          );
          byStudent.putIfAbsent(note.studentProfileId, () => []).add(note);
        } catch (_) {
          // Corrupted entry — skip, not worth blocking migration.
        }
      }
      // Clear the old author-keyed bucket so we don't double-count if a
      // future re-migration ever runs.
      await _progBox.delete(key);
    }

    for (final entry in byStudent.entries) {
      // De-dup by note id (same note authored by both teacher and parent
      // would only have happened by accident, but defend anyway).
      final seen = <String>{};
      final unique = entry.value.where((n) => seen.add(n.id)).toList();
      await _progBox.put(
        'pt_notes_${entry.key}',
        unique.map((n) => n.toJson()).toList(),
      );
    }

    await settings.put(flagKey, true);
  }
}
