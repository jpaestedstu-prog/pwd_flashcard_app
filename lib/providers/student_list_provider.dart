import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../data/models/student_filter.dart';
import 'app_providers.dart';

/// Manages filtered/sorted student list state for the educator views.
class StudentListNotifier extends Notifier<StudentFilter> {
  @override
  StudentFilter build() => const StudentFilter();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setGradeFilter(GradeLevel? grade) {
    state = state.copyWith(gradeLevel: () => grade);
  }

  void setSectionFilter(String? section) {
    state = state.copyWith(section: () => section);
  }

  void setDisabilityFilter(DisabilityType? type) {
    state = state.copyWith(disabilityType: () => type);
  }

  void setTagFilter(List<String> tags) {
    state = state.copyWith(tags: tags);
  }

  void setActivityFilter(ActivityStatus status) {
    state = state.copyWith(activityStatus: status);
  }

  void setSortField(StudentSortField field) {
    if (state.sortField == field) {
      // Toggle direction if same field
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      // Default direction based on the field
      final ascending = field == StudentSortField.name ||
          field == StudentSortField.gradeLevel ||
          field == StudentSortField.createdAt;
      state = state.copyWith(sortField: field, sortAscending: ascending);
    }
  }

  /// Set the sort field and explicit direction without toggling.
  void setSortFieldWithDirection(StudentSortField field, {required bool ascending}) {
    state = state.copyWith(sortField: field, sortAscending: ascending);
  }

  void clearFilters() {
    state = state.clearFilters();
  }
}

final studentFilterProvider =
    NotifierProvider<StudentListNotifier, StudentFilter>(
  StudentListNotifier.new,
);

/// Picks the right roster source based on the active profile's role.
///
/// Educators (teacher/parent) get a Firestore-backed list aggregated
/// across their classrooms — so they can see students from other devices.
/// Anyone else gets the local Hive list. While the educator fetch is
/// in flight — or if it fails — falls back to local Hive so the UI doesn't
/// flicker or, worse, break.
///
/// `valueOrNull`, not `value`: on an `AsyncError` the `value` getter *rethrows*
/// the error, so a roster fetch that failed (offline, a permissions error, a
/// missing box) took this provider down with it and every educator surface
/// watching it — the opposite of the fallback the paragraph above promises.
final _rosterSourceProvider =
    Provider<List<(UserProfile, LearningProgress)>>((ref) {
  final active = ref.watch(profileProvider);
  final allLocal = ref.watch(allProfilesWithProgressProvider);
  if (active != null && active.role.isEducator) {
    final remoteList = ref.watch(educatorRosterProvider(active.id)).valueOrNull;
    if (remoteList != null) return remoteList;
    // In flight, or the fetch failed (offline). Fall back to what local
    // enrolment can prove rather than to every learner on the device — on a
    // shared tablet the latter is another family's children. See
    // [localEducatorRoster].
    final local = localEducatorRoster(active.id, allLocal);
    if (local != null) return local;
  }
  return allLocal;
});

/// Every learner an educator may act on — classroom students plus home-group
/// children, guest players excluded — before any search/sort chrome.
///
/// Split out of [filteredStudentsProvider] so the other educator surfaces that
/// need a plain roster cannot drift from the documented `isEnrollableLearner`
/// rule by rolling their own filter. Assigning an assessment did exactly that:
/// it read local Hive for `role == UserRole.student`, which showed a Parent
/// "No students found" for a home group full of children and hid every
/// student who joined a teacher's class from another device.
final educatorLearnerRosterProvider =
    Provider<List<(UserProfile, LearningProgress)>>((ref) {
  return ref
      .watch(_rosterSourceProvider)
      .where((d) => d.$1.role.isEnrollableLearner && !d.$1.isGuestPlayer)
      .toList();
});

/// Provides the filtered and sorted student list.
final filteredStudentsProvider =
    Provider<List<(UserProfile, LearningProgress)>>((ref) {
  final filter = ref.watch(studentFilterProvider);

  var students = ref.watch(educatorLearnerRosterProvider);

  // Search filter
  if (filter.searchQuery.isNotEmpty) {
    final q = filter.searchQuery.toLowerCase();
    students = students.where((d) {
      final profile = d.$1;
      return profile.name.toLowerCase().contains(q) ||
          (profile.section?.toLowerCase().contains(q) ?? false) ||
          profile.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  // Grade level filter
  if (filter.gradeLevel != null) {
    students =
        students.where((d) => d.$1.gradeLevel == filter.gradeLevel).toList();
  }

  // Section filter
  if (filter.section != null) {
    students =
        students.where((d) => d.$1.section == filter.section).toList();
  }

  // Disability type filter
  if (filter.disabilityType != null) {
    students = students
        .where((d) => d.$1.disabilityType == filter.disabilityType)
        .toList();
  }

  // Tags filter (match any)
  if (filter.tags.isNotEmpty) {
    students = students
        .where(
            (d) => d.$1.tags.any((t) => filter.tags.contains(t)))
        .toList();
  }

  // Activity status filter
  final now = DateTime.now();
  switch (filter.activityStatus) {
    case ActivityStatus.activeToday:
      students = students
          .where(
              (d) => now.difference(d.$2.lastActivityDate).inHours < 24)
          .toList();
      break;
    case ActivityStatus.activeThisWeek:
      students = students
          .where(
              (d) => now.difference(d.$2.lastActivityDate).inDays < 7)
          .toList();
      break;
    case ActivityStatus.inactive7Days:
      students = students
          .where(
              (d) => now.difference(d.$2.lastActivityDate).inDays >= 7)
          .toList();
      break;
    case ActivityStatus.all:
      break;
  }

  // Sort
  final ascending = filter.sortAscending;
  students.sort((a, b) {
    int result;
    switch (filter.sortField) {
      case StudentSortField.name:
        result = a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
      case StudentSortField.gradeLevel:
        final aGrade = a.$1.gradeLevel?.sortOrder ?? -1;
        final bGrade = b.$1.gradeLevel?.sortOrder ?? -1;
        result = aGrade.compareTo(bGrade);
      case StudentSortField.wordsLearned:
        result = a.$2.wordsLearned.compareTo(b.$2.wordsLearned);
      case StudentSortField.streakDays:
        result = a.$2.streakDays.compareTo(b.$2.streakDays);
      case StudentSortField.stars:
        result = a.$2.totalStars.compareTo(b.$2.totalStars);
      case StudentSortField.lastActive:
        result = a.$2.lastActivityDate.compareTo(b.$2.lastActivityDate);
      case StudentSortField.averageAccuracy:
        result = _avgAccuracy(a.$2).compareTo(_avgAccuracy(b.$2));
      case StudentSortField.createdAt:
        result = a.$1.createdAt.compareTo(b.$1.createdAt);
    }
    return ascending ? result : -result;
  });

  return students;
});

double _avgAccuracy(LearningProgress p) {
  if (p.recentScores.isEmpty) return 0.0;
  return p.recentScores
          .map((s) => s.total > 0 ? s.score / s.total : 0.0)
          .reduce((a, b) => a + b) /
      p.recentScores.length;
}

/// Provides all unique sections found in student profiles.
final availableSectionsProvider = Provider<List<String>>((ref) {
  final allData = ref.watch(_rosterSourceProvider);
  final sections = <String>{};
  for (final (profile, _) in allData) {
    if (profile.role == UserRole.student && profile.section != null) {
      sections.add(profile.section!);
    }
  }
  final sorted = sections.toList()..sort();
  return sorted;
});

/// Provides all unique tags found in student profiles.
final availableTagsProvider = Provider<List<String>>((ref) {
  final allData = ref.watch(_rosterSourceProvider);
  final tags = <String>{};
  for (final (profile, _) in allData) {
    if (profile.role == UserRole.student) {
      tags.addAll(profile.tags);
    }
  }
  final sorted = tags.toList()..sort();
  return sorted;
});
