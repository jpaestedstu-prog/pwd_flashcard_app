import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firebase_service.dart';
import '../models/classroom.dart';
import '../models/classroom_member.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repository.dart';

/// Remote (Cloud Firestore) implementation of [DataRepository].
///
/// Mirrors the collection structure documented in [FirebaseService].
/// All writes use `set(..., merge: true)` so local → remote pushes are
/// idempotent (matches the previous Postgres `upsert` semantics).
class FirestoreRepository implements DataRepository {
  const FirestoreRepository();

  FirebaseFirestore get _db => FirebaseService.db;

  /// Anonymous-auth uid for the device making this write. Stamped onto
  /// every owner-scoped doc so [firestore.rules](firestore.rules) can
  /// verify the writer. Returns null if sign-in hasn't completed (offline
  /// first launch); the resulting write will be rejected by the rules
  /// once it reaches the server, which is the correct behavior.
  String? get _uid => FirebaseService.currentUid;

  // ─── Profiles ──────────────────────────────────────────

  @override
  Future<List<UserProfile>> getProfiles() async {
    final snap = await _db.collection('profiles').get();
    return snap.docs.map((d) => _profileFromMap(d.data())).toList();
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    // Player profiles never reach Firestore — defensive guard for callers
    // that bypass the LocalRepository queue.
    if (profile.isGuestPlayer) return;
    await _db.collection('profiles').doc(profile.id).set({
      'id': profile.id,
      'name': profile.name,
      'role': profile.role.index,
      'avatar_index': profile.avatarIndex,
      'created_at': profile.createdAt.toIso8601String(),
      'disability_type': profile.disabilityType.index,
      'classroom_id': profile.classroomId,
      'is_guest_player': profile.isGuestPlayer,
      'owner_uid': profile.ownerUid ?? _uid,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    // Cascade: every per-profile collection / document is removed so the
    // delete is a true "this profile no longer exists anywhere" operation.
    // Subcollections (achievements/items, shop_purchases/items) need their
    // documents enumerated and deleted in a batch.
    final batch = _db.batch();

    // Owner-scoped top-level docs keyed by profile id.
    batch.delete(_db.collection('profiles').doc(profileId));
    batch.delete(_db.collection('progress').doc(profileId));
    batch.delete(_db.collection('app_state').doc('tutorial_seen_$profileId'));
    batch.delete(_db.collection('app_state').doc('daily_challenge_$profileId'));
    batch.delete(_db.collection('app_state').doc('daily_streak_$profileId'));

    // Equipped-item docs are keyed `${profileId}_${type}`. We don't know
    // every type up-front, so query by profile_id and delete what we find.
    final equipped = await _db
        .collection('shop_equipped')
        .where('profile_id', isEqualTo: profileId)
        .get();
    for (final d in equipped.docs) {
      batch.delete(d.reference);
    }

    // Drop classroom membership rows for this profile.
    final memberships = await _db
        .collection('classroom_members')
        .where('profile_id', isEqualTo: profileId)
        .get();
    for (final d in memberships.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();

    // Subcollections need their own per-doc deletes.
    final achievements = await _db
        .collection('achievements')
        .doc(profileId)
        .collection('items')
        .get();
    if (achievements.docs.isNotEmpty) {
      final aBatch = _db.batch();
      for (final d in achievements.docs) {
        aBatch.delete(d.reference);
      }
      await aBatch.commit();
    }

    final purchases = await _db
        .collection('shop_purchases')
        .doc(profileId)
        .collection('items')
        .get();
    if (purchases.docs.isNotEmpty) {
      final pBatch = _db.batch();
      for (final d in purchases.docs) {
        pBatch.delete(d.reference);
      }
      await pBatch.commit();
    }
  }

  UserProfile _profileFromMap(Map<String, dynamic> r) {
    return UserProfile(
      id: r['id'] as String,
      name: r['name'] as String,
      role: UserRole.values[(r['role'] as int?) ?? 0],
      avatarIndex: (r['avatar_index'] as int?) ?? 0,
      createdAt: DateTime.parse(r['created_at'] as String),
      disabilityType:
          DisabilityType.values[(r['disability_type'] as int?) ?? 0],
      classroomId: r['classroom_id'] as String?,
      isGuestPlayer: (r['is_guest_player'] as bool?) ?? false,
      ownerUid: r['owner_uid'] as String?,
    );
  }

  /// Fetch a single profile by id. Returns null if it doesn't exist.
  Future<UserProfile?> getProfileById(String profileId) async {
    final doc = await _db.collection('profiles').doc(profileId).get();
    if (!doc.exists) return null;
    return _profileFromMap(doc.data()!);
  }

  /// Fetch every student profile + progress for a classroom.
  ///
  /// Used by teacher dashboards on devices that don't have those students
  /// in their local Hive (e.g. teacher's tablet vs. student's phone).
  Future<List<(UserProfile, LearningProgress)>>
      getStudentsWithProgressByClassroom(String classroomId) async {
    final members = await listMembers(classroomId);
    final results = <(UserProfile, LearningProgress)>[];
    for (final m in members) {
      final profile = await getProfileById(m.profileId);
      if (profile == null) continue;
      // Skip player-mode profiles defensively — they shouldn't be enrolled
      // anyway, but ignore them if a stale row sneaks through.
      if (profile.isGuestPlayer) continue;
      final progress = await getProgress(m.profileId);
      results.add((profile, progress));
    }
    return results;
  }

  @override
  Future<String?> getActiveProfileId() async {
    // Per-device pointer — keyed by uid so two devices on the same project
    // don't trample each other's active profile.
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection('app_state').doc('active_profile_$uid').get();
    if (!doc.exists) return null;
    return doc.data()?['value'] as String?;
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('app_state').doc('active_profile_$uid').set({
      'key': 'active_profile_$uid',
      'value': id,
      'owner_uid': uid,
    });
  }

  // ─── Settings ──────────────────────────────────────────

  @override
  Future<AppSettings> getSettings() async {
    // Per-device settings keyed by uid (was 'default' before auth landed —
    // single shared doc would clash across devices on the same project).
    final uid = _uid;
    if (uid == null) return const AppSettings();
    final doc = await _db.collection('settings').doc(uid).get();
    if (!doc.exists) return const AppSettings();
    final r = doc.data() ?? const <String, dynamic>{};
    return AppSettings(
      fontScale: (r['font_scale'] as num?)?.toDouble() ?? 1.0,
      highContrastMode: r['high_contrast'] as bool? ?? false,
      darkMode: r['dark_mode'] as bool? ?? false,
      ttsEnabled: r['tts_enabled'] as bool? ?? true,
      ttsSpeed: (r['tts_speed'] as num?)?.toDouble() ?? 0.5,
      reducedMotion: r['reduced_motion'] as bool? ?? false,
      soundEffects: r['sound_effects'] as bool? ?? true,
      speechToText: r['speech_to_text'] as bool? ?? false,
      locale: r['locale'] as String? ?? 'en',
      notificationsEnabled: r['notifications_enabled'] as bool? ?? true,
      reminderHour: r['reminder_hour'] as int? ?? 9,
      reminderMinute: r['reminder_minute'] as int? ?? 0,
      voiceNavigation: r['voice_navigation'] as bool? ?? false,
      adaptiveDifficulty: r['adaptive_difficulty'] as bool? ?? true,
    );
  }

  @override
  Future<void> saveSettings(AppSettings s) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('settings').doc(uid).set({
      'id': uid,
      'owner_uid': uid,
      'font_scale': s.fontScale,
      'high_contrast': s.highContrastMode,
      'dark_mode': s.darkMode,
      'tts_enabled': s.ttsEnabled,
      'tts_speed': s.ttsSpeed,
      'reduced_motion': s.reducedMotion,
      'sound_effects': s.soundEffects,
      'speech_to_text': s.speechToText,
      'locale': s.locale,
      'notifications_enabled': s.notificationsEnabled,
      'reminder_hour': s.reminderHour,
      'reminder_minute': s.reminderMinute,
      'voice_navigation': s.voiceNavigation,
      'adaptive_difficulty': s.adaptiveDifficulty,
    }, SetOptions(merge: true));
  }

  // ─── Progress ──────────────────────────────────────────

  @override
  Future<LearningProgress> getProgress(String profileId) async {
    final doc = await _db.collection('progress').doc(profileId).get();
    if (!doc.exists) {
      return LearningProgress(
        profileId: profileId,
        lastActivityDate: DateTime.now(),
      );
    }
    final r = doc.data() ?? const <String, dynamic>{};
    final catRaw = r['category_progress'] as Map<String, dynamic>? ?? {};
    final scoresRaw = r['recent_scores'] as List<dynamic>? ?? [];
    final wordsRaw = r['learned_word_ids'] as List<dynamic>? ?? [];

    return LearningProgress(
      profileId: profileId,
      wordsLearned: (r['words_learned'] as int?) ?? 0,
      learnedWordIds: Set<String>.from(wordsRaw.map((e) => e.toString())),
      streakDays: (r['streak_days'] as int?) ?? 0,
      lastActivityDate:
          DateTime.tryParse(r['last_activity'] as String? ?? '') ??
              DateTime.now(),
      categoryProgress:
          catRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      recentScores: scoresRaw
          .map((s) => GameScore.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      totalStars: (r['total_stars'] as int?) ?? 0,
      spentStars: (r['spent_stars'] as int?) ?? 0,
    );
  }

  @override
  Future<void> saveProgress(LearningProgress p) async {
    await _db.collection('progress').doc(p.profileId).set({
      'profile_id': p.profileId,
      'words_learned': p.wordsLearned,
      'learned_word_ids': p.learnedWordIds.toList(),
      'streak_days': p.streakDays,
      'last_activity': p.lastActivityDate.toIso8601String(),
      'category_progress': p.categoryProgress,
      'recent_scores': p.recentScores.map((s) => s.toJson()).toList(),
      'total_stars': p.totalStars,
      'spent_stars': p.spentStars,
      'owner_uid': _uid,
    }, SetOptions(merge: true));
  }

  // ─── Custom Cards ──────────────────────────────────────

  @override
  Future<List<Flashcard>> getCustomCards() async {
    final snap = await _db.collection('custom_cards').get();
    return snap.docs.map((d) {
      final r = d.data();
      return Flashcard(
        id: r['id'] as String,
        wordEnglish: r['word_english'] as String,
        wordFilipino: r['word_filipino'] as String,
        exampleSentence: r['example_sentence'] as String?,
        imageAsset: r['image_asset'] as String?,
        category: FlashcardCategory.values[(r['category'] as int?) ?? 0],
        isCustom: true,
      );
    }).toList();
  }

  @override
  Future<void> saveCustomCard(Flashcard card) async {
    await _db.collection('custom_cards').doc(card.id).set({
      'id': card.id,
      'word_english': card.wordEnglish,
      'word_filipino': card.wordFilipino,
      'example_sentence': card.exampleSentence,
      'image_asset': card.imageAsset,
      'category': card.category.index,
      'owner_uid': _uid,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCustomCard(String cardId) async {
    await _db.collection('custom_cards').doc(cardId).delete();
  }

  // ─── Achievements ─────────────────────────────────────

  @override
  Future<Set<String>> getUnlockedAchievements(String profileId) async {
    final snap = await _db
        .collection('achievements')
        .doc(profileId)
        .collection('items')
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  @override
  Future<void> saveUnlockedAchievements(
      String profileId, Set<String> achievementIds) async {
    final batch = _db.batch();
    final col = _db
        .collection('achievements')
        .doc(profileId)
        .collection('items');
    for (final id in achievementIds) {
      batch.set(col.doc(id), {
        'profile_id': profileId,
        'achievement_id': id,
        'unlocked_at': FieldValue.serverTimestamp(),
        'owner_uid': _uid,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─── Shop ─────────────────────────────────────────────

  @override
  Future<Set<String>> getPurchasedItems(String profileId) async {
    final snap = await _db
        .collection('shop_purchases')
        .doc(profileId)
        .collection('items')
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  @override
  Future<void> savePurchasedItems(
      String profileId, Set<String> itemIds) async {
    final batch = _db.batch();
    final col = _db
        .collection('shop_purchases')
        .doc(profileId)
        .collection('items');
    for (final id in itemIds) {
      batch.set(col.doc(id), {
        'profile_id': profileId,
        'item_id': id,
        'owner_uid': _uid,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<String?> getEquippedItem(String profileId, String type) async {
    final doc = await _db
        .collection('shop_equipped')
        .doc('${profileId}_$type')
        .get();
    if (!doc.exists) return null;
    return doc.data()?['item_id'] as String?;
  }

  @override
  Future<void> saveEquippedItem(
      String profileId, String type, String? itemId) async {
    final ref = _db.collection('shop_equipped').doc('${profileId}_$type');
    if (itemId == null) {
      await ref.delete();
    } else {
      await ref.set({
        'profile_id': profileId,
        'type': type,
        'item_id': itemId,
        'owner_uid': _uid,
      }, SetOptions(merge: true));
    }
  }

  // ─── Tutorial / Daily Challenge ───────────────────────

  @override
  Future<bool> hasSeenTutorial(String profileId) async {
    final doc = await _db
        .collection('app_state')
        .doc('tutorial_seen_$profileId')
        .get();
    return doc.exists && doc.data()?['value'] == 'true';
  }

  @override
  Future<void> markTutorialSeen(String profileId) async {
    await _db.collection('app_state').doc('tutorial_seen_$profileId').set({
      'key': 'tutorial_seen_$profileId',
      'value': 'true',
      'owner_uid': _uid,
    });
  }

  @override
  Future<String?> getDailyChallengeDate(String profileId) async {
    final doc = await _db
        .collection('app_state')
        .doc('daily_challenge_$profileId')
        .get();
    if (!doc.exists) return null;
    return doc.data()?['value'] as String?;
  }

  @override
  Future<void> saveDailyChallengeDate(
      String profileId, String date) async {
    await _db
        .collection('app_state')
        .doc('daily_challenge_$profileId')
        .set({
      'key': 'daily_challenge_$profileId',
      'value': date,
      'owner_uid': _uid,
    });
  }

  @override
  Future<int> getDailyChallengeStreak(String profileId) async {
    final doc = await _db
        .collection('app_state')
        .doc('daily_streak_$profileId')
        .get();
    if (!doc.exists) return 0;
    return int.tryParse(doc.data()?['value'] as String? ?? '') ?? 0;
  }

  // ─── Aggregate ────────────────────────────────────────

  @override
  Future<List<(UserProfile, LearningProgress)>>
      getAllProfilesWithProgress() async {
    final profiles = await getProfiles();
    final results = <(UserProfile, LearningProgress)>[];
    for (final p in profiles) {
      final progress = await getProgress(p.id);
      results.add((p, progress));
    }
    return results;
  }

  // ─── Session Analytics ────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getSessionLogs(
      String profileId) async {
    final snap = await _db
        .collection('session_logs')
        .where('profile_id', isEqualTo: profileId)
        .orderBy('date', descending: true)
        .limit(200)
        .get();
    return snap.docs.map((d) {
      final r = d.data();
      return <String, dynamic>{
        'date': r['date'],
        'durationSeconds': r['duration_seconds'],
        'gamesPlayed': r['games_played'],
        'cardsReviewed': r['cards_reviewed'],
      };
    }).toList();
  }

  @override
  Future<void> addSessionLog(
      String profileId, Map<String, dynamic> session) async {
    await _db.collection('session_logs').add({
      'profile_id': profileId,
      'date': session['date'],
      'duration_seconds': session['durationSeconds'],
      'games_played': session['gamesPlayed'],
      'cards_reviewed': session['cardsReviewed'],
      'owner_uid': _uid,
    });
  }

  // ─── Classrooms ────────────────────────────────────────

  /// Best-effort audit write. Audit failures must never block the user
  /// action that triggered them — wrapped in try/catch and discarded on
  /// failure. The audit log is for *teacher visibility into past
  /// changes*, not a transactional invariant.
  Future<void> _writeClassroomAudit(
    String classroomId,
    String eventType,
    Map<String, dynamic> details,
  ) async {
    try {
      await _db
          .collection('classroom_audit')
          .doc(classroomId)
          .collection('events')
          .add({
        'event_type': eventType,
        'actor_uid': _uid,
        'classroom_id': classroomId,
        'details': details,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit is observational; swallow.
    }
  }

  @override
  Future<Classroom> createClassroom(Classroom c) async {
    await _db.collection('classrooms').doc(c.id).set(c.toJson());
    await _writeClassroomAudit(c.id, 'created', {
      'name': c.name,
      'code': c.code,
      'teacher_id': c.teacherId,
    });
    return c;
  }

  @override
  Future<Classroom?> getClassroomById(String classroomId) async {
    final doc = await _db.collection('classrooms').doc(classroomId).get();
    if (!doc.exists) return null;
    return Classroom.fromJson(Map<String, dynamic>.from(doc.data()!));
  }

  @override
  Future<Classroom?> getClassroomByCode(String code) async {
    final snap = await _db
        .collection('classrooms')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Classroom.fromJson(Map<String, dynamic>.from(snap.docs.first.data()));
  }

  @override
  Future<List<Classroom>> getClassroomsByTeacher(String teacherId) async {
    // Keep the query index-light (where-only) and sort in memory.
    final snap = await _db
        .collection('classrooms')
        .where('teacher_id', isEqualTo: teacherId)
        .get();
    final classrooms = snap.docs
        .map((d) => Classroom.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    classrooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return classrooms;
  }

  @override
  Future<void> updateClassroom(Classroom c) async {
    await _db.collection('classrooms').doc(c.id).set(
          c.toJson(),
          SetOptions(merge: true),
        );
    await _writeClassroomAudit(c.id, 'updated', {
      'name': c.name,
      'code': c.code,
    });
  }

  @override
  Future<void> deleteClassroom(String classroomId) async {
    // Cascade: delete every member doc that references this classroom.
    final members = await _db
        .collection('classroom_members')
        .where('classroom_id', isEqualTo: classroomId)
        .get();
    final batch = _db.batch();
    for (final d in members.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('classrooms').doc(classroomId));
    await batch.commit();
    await _writeClassroomAudit(classroomId, 'deleted', {
      'cascaded_members': members.docs.length,
    });
  }

  @override
  Future<void> addMember(ClassroomMember m) async {
    final docId = '${m.classroomId}_${m.profileId}';
    await _db
        .collection('classroom_members')
        .doc(docId)
        .set(m.toJson(), SetOptions(merge: true));
    await _writeClassroomAudit(m.classroomId, 'member_added', {
      'profile_id': m.profileId,
      'display_name': m.displayName,
    });
  }

  @override
  Future<List<ClassroomMember>> listMembers(String classroomId) async {
    // Keep the query index-light (where-only) and sort in memory.
    final snap = await _db
        .collection('classroom_members')
        .where('classroom_id', isEqualTo: classroomId)
        .get();
    final members = snap.docs
        .map((d) =>
            ClassroomMember.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();
    members.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return members;
  }

  @override
  Future<void> removeMember(String classroomId, String profileId) async {
    await _db
        .collection('classroom_members')
        .doc('${classroomId}_$profileId')
        .delete();
    await _writeClassroomAudit(classroomId, 'member_removed', {
      'profile_id': profileId,
    });
  }

  // ─── Data Management ──────────────────────────────────

  @override
  Future<void> clearAllData() async {
    // Best-effort: iterate top-level collections and delete every doc.
    // Subcollections (achievements/items, shop_purchases/items) are left
    // dangling — pair this with manual Firestore console cleanup if you
    // need a hard reset for QA.
    const topLevel = [
      'profiles',
      'progress',
      'custom_cards',
      'shop_equipped',
      'session_logs',
      'app_state',
      'classrooms',
      'classroom_members',
      'settings',
    ];
    for (final name in topLevel) {
      final snap = await _db.collection(name).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
