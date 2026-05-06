import 'models/models.dart';
import 'models/classroom.dart';
import 'models/classroom_member.dart';

/// Abstract data repository — implemented locally (Hive) and remotely (Firestore).
///
/// All methods use [Future] so that both sync-local and async-remote
/// implementations are supported through the same interface.
abstract class DataRepository {
  // ─── Profiles ──────────────────────────────────────────

  Future<List<UserProfile>> getProfiles();
  Future<void> saveProfile(UserProfile profile);
  Future<void> deleteProfile(String profileId);
  Future<String?> getActiveProfileId();
  Future<void> setActiveProfileId(String id);

  // ─── Settings ──────────────────────────────────────────

  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);

  // ─── Progress ──────────────────────────────────────────

  Future<LearningProgress> getProgress(String profileId);
  Future<void> saveProgress(LearningProgress progress);

  // ─── Custom Cards ──────────────────────────────────────

  Future<List<Flashcard>> getCustomCards();
  Future<void> saveCustomCard(Flashcard card);
  Future<void> deleteCustomCard(String cardId);

  // ─── Achievements ─────────────────────────────────────

  Future<Set<String>> getUnlockedAchievements(String profileId);
  Future<void> saveUnlockedAchievements(
      String profileId, Set<String> achievementIds);

  // ─── Shop ─────────────────────────────────────────────

  Future<Set<String>> getPurchasedItems(String profileId);
  Future<void> savePurchasedItems(String profileId, Set<String> itemIds);
  Future<String?> getEquippedItem(String profileId, String type);
  Future<void> saveEquippedItem(
      String profileId, String type, String? itemId);

  // ─── Tutorial / Daily Challenge ───────────────────────

  Future<bool> hasSeenTutorial(String profileId);
  Future<void> markTutorialSeen(String profileId);
  Future<String?> getDailyChallengeDate(String profileId);
  Future<void> saveDailyChallengeDate(String profileId, String date);
  Future<int> getDailyChallengeStreak(String profileId);

  // ─── Aggregate ────────────────────────────────────────

  Future<List<(UserProfile, LearningProgress)>> getAllProfilesWithProgress();

  // ─── Session Analytics ────────────────────────────────

  Future<List<Map<String, dynamic>>> getSessionLogs(String profileId);
  Future<void> addSessionLog(
      String profileId, Map<String, dynamic> session);

  // ─── Classrooms ────────────────────────────────────────

  Future<Classroom> createClassroom(Classroom classroom);
  Future<Classroom?> getClassroomById(String classroomId);
  Future<Classroom?> getClassroomByCode(String code);
  Future<List<Classroom>> getClassroomsByTeacher(String teacherId);
  Future<void> updateClassroom(Classroom classroom);
  Future<void> deleteClassroom(String classroomId);

  Future<void> addMember(ClassroomMember member);
  Future<List<ClassroomMember>> listMembers(String classroomId);
  Future<void> removeMember(String classroomId, String profileId);

  // ─── Data Management ──────────────────────────────────

  Future<void> clearAllData();
}
