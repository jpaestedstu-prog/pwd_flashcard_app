import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/avatar_data.dart';
import '../core/services/firebase_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../data/remote/firestore_repository.dart';

/// Represents one student's real-time status in a classroom session.
class StudentStatus {
  final String profileId;
  final String name;
  final String? avatarEmoji;
  final String currentActivity; // e.g. "Playing Word Match", "Viewing Flashcards"
  final int wordsLearned;
  final int starsEarned;
  final int gamesPlayed;
  final double averageAccuracy; // 0.0 – 1.0
  final DateTime lastActive;

  const StudentStatus({
    required this.profileId,
    required this.name,
    this.avatarEmoji,
    this.currentActivity = 'Idle',
    this.wordsLearned = 0,
    this.starsEarned = 0,
    this.gamesPlayed = 0,
    this.averageAccuracy = 0.0,
    required this.lastActive,
  });

  /// How long ago the student was last active.
  Duration get timeSinceActive => DateTime.now().difference(lastActive);

  /// Whether the student appears to be currently active (within last 2 minutes).
  bool get isActive => timeSinceActive.inMinutes < 2;
}

/// A classroom session snapshot with aggregated stats.
class ClassroomSnapshot {
  final DateTime timestamp;
  final List<StudentStatus> students;
  final String sessionId;

  const ClassroomSnapshot({
    required this.timestamp,
    required this.students,
    required this.sessionId,
  });

  int get totalStudents => students.length;
  int get activeStudents => students.where((s) => s.isActive).length;

  double get overallAccuracy {
    if (students.isEmpty) return 0;
    return students.map((s) => s.averageAccuracy).reduce((a, b) => a + b) /
        students.length;
  }

  int get totalGamesPlayed =>
      students.fold(0, (sum, s) => sum + s.gamesPlayed);

  int get totalWordsLearned =>
      students.fold(0, (sum, s) => sum + s.wordsLearned);

  int get totalStarsEarned =>
      students.fold(0, (sum, s) => sum + s.starsEarned);

  /// Which activities are most common across all students.
  Map<String, int> get categoryDistribution {
    final dist = <String, int>{};
    for (final s in students) {
      if (s.currentActivity.isNotEmpty && s.currentActivity != 'Idle') {
        dist[s.currentActivity] = (dist[s.currentActivity] ?? 0) + 1;
      }
    }
    return dist;
  }
}

/// State notifier that builds a classroom view from all profile data.
///
/// In a single-device (thesis) context this reads from local Hive storage,
/// making it useful for a teacher who has all student profiles on one device.
/// When [classroomId] is non-null the snapshot is scoped to students linked
/// to that classroom; when null the legacy single-device behaviour returns
/// every student profile on the device.
class ClassroomNotifier extends StateNotifier<ClassroomSnapshot> {
  /// Optional classroom scope. When null, includes every student profile.
  final String? classroomId;

  ClassroomNotifier({this.classroomId})
      : super(ClassroomSnapshot(
          timestamp: DateTime.now(),
          students: const [],
          sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        )) {
    refresh();
  }

  /// Rebuild the snapshot from local storage (student profiles only).
  void refresh() {
    final profilesWithProgress = HiveService.getAllProfilesWithProgress();

    // Only include student profiles — skip teacher/parent profiles.
    // Also exclude guest "player mode" profiles regardless of scope.
    final studentProfiles = profilesWithProgress
        .where((pair) =>
            pair.$1.role == UserRole.student &&
            !pair.$1.isGuestPlayer &&
            (classroomId == null || pair.$1.classroomId == classroomId))
        .toList();

    final students = studentProfiles.map((pair) {
      final profile = pair.$1;
      final progress = pair.$2;

      // Compute average accuracy from recent scores
      double avgAccuracy = 0;
      if (progress.recentScores.isNotEmpty) {
        avgAccuracy = progress.recentScores
                .map((s) => s.total > 0 ? s.score / s.total : 0.0)
                .reduce((a, b) => a + b) /
            progress.recentScores.length;
      }

      // Determine current activity from session logs
      final sessions = HiveService.getSessionLogs(profile.id);
      String activity = 'Idle';
      if (sessions.isNotEmpty) {
        final last = sessions.last;
        final dateStr = last['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr);
        final duration = (last['durationSeconds'] as int?) ?? 0;
        if (date != null) {
          final sessionEnd = date.add(Duration(seconds: duration));
          final elapsed = DateTime.now().difference(sessionEnd);
          if (elapsed.inMinutes < 5) {
            final games = (last['gamesPlayed'] as int?) ?? 0;
            final cards = (last['cardsReviewed'] as int?) ?? 0;
            if (games > 0) {
              activity = 'Playing Games';
            } else if (cards > 0) {
              activity = 'Reviewing Flashcards';
            } else {
              activity = 'Studying';
            }
          }
        }
      }

      return StudentStatus(
        profileId: profile.id,
        name: profile.name,
        avatarEmoji: AvatarData.getAvatar(profile.avatarIndex).emoji,
        currentActivity: activity,
        wordsLearned: progress.wordsLearned,
        starsEarned: progress.totalStars,
        gamesPlayed: progress.recentScores.length,
        averageAccuracy: avgAccuracy,
        lastActive: progress.lastActivityDate,
      );
    }).toList();

    // Sort: active students first, then by name
    students.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    state = ClassroomSnapshot(
      timestamp: DateTime.now(),
      students: students,
      sessionId: state.sessionId,
    );
  }
}

/// Provider for the classroom dashboard.
///
/// Default (non-family) form keeps backward compatibility — it returns
/// every student profile on the device, just like before.
final classroomProvider =
    StateNotifierProvider<ClassroomNotifier, ClassroomSnapshot>((ref) {
  return ClassroomNotifier();
});

/// Family-scoped local variant. Returns only students whose `classroomId`
/// is already on this device's Hive. Useful as an offline fallback or for
/// single-device demo use.
final classroomScopedProvider = StateNotifierProvider.family<
    ClassroomNotifier, ClassroomSnapshot, String>((ref, classroomId) {
  return ClassroomNotifier(classroomId: classroomId);
});

/// Firestore-backed snapshot aggregating every student across every
/// classroom a teacher owns.
///
/// This is what the teacher's main dashboard should use — the students
/// live on different devices, so Hive on the teacher's device can't see
/// them. We fetch the rosters from Firestore directly.
final teacherDashboardSnapshotProvider =
    FutureProvider.family<ClassroomSnapshot, String>(
        (ref, teacherId) async {
  if (!FirebaseService.isConfigured) {
    return ref.read(classroomProvider);
  }
  const remote = FirestoreRepository();
  final classrooms = await remote.getClassroomsByTeacher(teacherId);
  final allStatuses = <StudentStatus>[];
  for (final c in classrooms) {
    final pairs =
        await remote.getStudentsWithProgressByClassroom(c.id);
    for (final pair in pairs) {
      final UserProfile profile = pair.$1;
      final progress = pair.$2;
      double avgAccuracy = 0;
      if (progress.recentScores.isNotEmpty) {
        avgAccuracy = progress.recentScores
                .map((s) => s.total > 0 ? s.score / s.total : 0.0)
                .reduce((a, b) => a + b) /
            progress.recentScores.length;
      }
      final elapsed = DateTime.now().difference(progress.lastActivityDate);
      final activity = elapsed.inMinutes < 5 ? 'Studying' : 'Idle';
      allStatuses.add(StudentStatus(
        profileId: profile.id,
        name: profile.name,
        avatarEmoji: AvatarData.getAvatar(profile.avatarIndex).emoji,
        currentActivity: activity,
        wordsLearned: progress.wordsLearned,
        starsEarned: progress.totalStars,
        gamesPlayed: progress.recentScores.length,
        averageAccuracy: avgAccuracy,
        lastActive: progress.lastActivityDate,
      ));
    }
  }
  allStatuses.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return ClassroomSnapshot(
    timestamp: DateTime.now(),
    students: allStatuses,
    sessionId: teacherId,
  );
});

/// Firestore-backed snapshot for a specific classroom.
///
/// Pulls the member roster + every member's profile and progress directly
/// from Firestore. This is what the teacher's dashboard should use when
/// the students live on different devices.
///
/// When Firebase isn't configured, falls back to the local Hive snapshot
/// so single-device demos still render something.
final classroomFirestoreSnapshotProvider =
    FutureProvider.family<ClassroomSnapshot, String>(
        (ref, classroomId) async {
  if (!FirebaseService.isConfigured) {
    // Local fallback: rebuild the same shape from Hive.
    return ref.read(classroomScopedProvider(classroomId));
  }

  const remote = FirestoreRepository();
  final pairs =
      await remote.getStudentsWithProgressByClassroom(classroomId);

  final students = pairs.map((pair) {
    final UserProfile profile = pair.$1;
    final progress = pair.$2;

    double avgAccuracy = 0;
    if (progress.recentScores.isNotEmpty) {
      avgAccuracy = progress.recentScores
              .map((s) => s.total > 0 ? s.score / s.total : 0.0)
              .reduce((a, b) => a + b) /
          progress.recentScores.length;
    }

    // Activity inferred from time since last progress update — sessions
    // logs aren't reliably available across devices, so fall back to the
    // last activity date.
    final elapsed = DateTime.now().difference(progress.lastActivityDate);
    final activity = elapsed.inMinutes < 5 ? 'Studying' : 'Idle';

    return StudentStatus(
      profileId: profile.id,
      name: profile.name,
      avatarEmoji: AvatarData.getAvatar(profile.avatarIndex).emoji,
      currentActivity: activity,
      wordsLearned: progress.wordsLearned,
      starsEarned: progress.totalStars,
      gamesPlayed: progress.recentScores.length,
      averageAccuracy: avgAccuracy,
      lastActive: progress.lastActivityDate,
    );
  }).toList()
    ..sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });

  return ClassroomSnapshot(
    timestamp: DateTime.now(),
    students: students,
    sessionId: classroomId,
  );
});
