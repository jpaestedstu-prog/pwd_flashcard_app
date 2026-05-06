import 'enums.dart';

/// Holds all active filter/sort state for the student list.
class StudentFilter {
  final String searchQuery;
  final GradeLevel? gradeLevel;
  final String? section;
  final DisabilityType? disabilityType;
  final List<String> tags;
  final ActivityStatus activityStatus;
  final StudentSortField sortField;
  final bool sortAscending;

  const StudentFilter({
    this.searchQuery = '',
    this.gradeLevel,
    this.section,
    this.disabilityType,
    this.tags = const [],
    this.activityStatus = ActivityStatus.all,
    this.sortField = StudentSortField.name,
    this.sortAscending = true,
  });

  /// Number of active filters (excluding search and sort).
  int get activeFilterCount {
    int count = 0;
    if (gradeLevel != null) count++;
    if (section != null) count++;
    if (disabilityType != null) count++;
    if (tags.isNotEmpty) count++;
    if (activityStatus != ActivityStatus.all) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0 || searchQuery.isNotEmpty;

  StudentFilter copyWith({
    String? searchQuery,
    GradeLevel? Function()? gradeLevel,
    String? Function()? section,
    DisabilityType? Function()? disabilityType,
    List<String>? tags,
    ActivityStatus? activityStatus,
    StudentSortField? sortField,
    bool? sortAscending,
  }) {
    return StudentFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      gradeLevel: gradeLevel != null ? gradeLevel() : this.gradeLevel,
      section: section != null ? section() : this.section,
      disabilityType:
          disabilityType != null ? disabilityType() : this.disabilityType,
      tags: tags ?? this.tags,
      activityStatus: activityStatus ?? this.activityStatus,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Reset all filters to defaults (keeps sort).
  StudentFilter clearFilters() => StudentFilter(
        sortField: sortField,
        sortAscending: sortAscending,
      );
}
