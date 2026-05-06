import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/enums.dart';
import '../data/models/student_filter.dart';
import '../providers/student_list_provider.dart';

/// Reusable search + filter bar for the student list.
///
/// Includes a search field, horizontally scrollable filter chips,
/// and a sort dropdown. Reads/writes state via [studentFilterProvider].
class StudentFilterBar extends ConsumerStatefulWidget {
  const StudentFilterBar({super.key});

  @override
  ConsumerState<StudentFilterBar> createState() => _StudentFilterBarState();
}

class _StudentFilterBarState extends ConsumerState<StudentFilterBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(studentFilterProvider);
    final hc = HCColor.of(context);
    final availableSections = ref.watch(availableSectionsProvider);
    final availableTags = ref.watch(availableTagsProvider);

    // Sync controller if filter was cleared externally
    if (filter.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Search Field ─────────────────────
        TextField(
          controller: _searchController,
          onChanged: (v) =>
              ref.read(studentFilterProvider.notifier).setSearchQuery(v),
          decoration: InputDecoration(
            hintText: 'Search students...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: filter.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(studentFilterProvider.notifier)
                          .setSearchQuery('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.textSecondary.withValues(alpha: 0.2)),
            ),
            filled: true,
            fillColor: hc.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Sort + Filter Row ────────────────
        Row(
          children: [
            // Sort button
            _SortButton(filter: filter),
            const SizedBox(width: 8),
            // Filter chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Grade level
                    _FilterChipDropdown<GradeLevel>(
                      label: filter.gradeLevel?.label ?? 'Grade',
                      isActive: filter.gradeLevel != null,
                      items: GradeLevel.values,
                      itemLabel: (g) => g.label,
                      onSelected: (g) => ref
                          .read(studentFilterProvider.notifier)
                          .setGradeFilter(
                              g == filter.gradeLevel ? null : g),
                    ),
                    const SizedBox(width: 6),

                    // Disability type
                    _FilterChipDropdown<DisabilityType>(
                      label: filter.disabilityType?.label ?? 'Accessibility',
                      isActive: filter.disabilityType != null,
                      items: DisabilityType.values,
                      itemLabel: (d) => '${d.emoji} ${d.label}',
                      onSelected: (d) => ref
                          .read(studentFilterProvider.notifier)
                          .setDisabilityFilter(
                              d == filter.disabilityType ? null : d),
                    ),
                    const SizedBox(width: 6),

                    // Activity status
                    _FilterChipDropdown<ActivityStatus>(
                      label: filter.activityStatus.label,
                      isActive:
                          filter.activityStatus != ActivityStatus.all,
                      items: ActivityStatus.values,
                      itemLabel: (a) => a.label,
                      onSelected: (a) => ref
                          .read(studentFilterProvider.notifier)
                          .setActivityFilter(a),
                    ),

                    // Section (only show if sections exist)
                    if (availableSections.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _FilterChipDropdown<String>(
                        label: filter.section ?? 'Section',
                        isActive: filter.section != null,
                        items: availableSections,
                        itemLabel: (s) => s,
                        onSelected: (s) => ref
                            .read(studentFilterProvider.notifier)
                            .setSectionFilter(
                                s == filter.section ? null : s),
                      ),
                    ],

                    // Tags (only show if tags exist)
                    if (availableTags.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _TagFilterChip(
                        availableTags: availableTags,
                        selectedTags: filter.tags,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        // ─── Active filters summary ──────────
        if (filter.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  '${ref.watch(filteredStudentsProvider).length} results',
                  style: AppTypography.labelSmall
                      .copyWith(color: hc.textSecondary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    ref.read(studentFilterProvider.notifier).clearFilters();
                  },
                  child: Text(
                    'Clear all',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Sort Button ──────────────────────────────────────

class _SortButton extends ConsumerWidget {
  final StudentFilter filter;
  const _SortButton({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<StudentSortField>(
      onSelected: (field) =>
          ref.read(studentFilterProvider.notifier).setSortField(field),
      itemBuilder: (_) => StudentSortField.values
          .map((f) => PopupMenuItem(
                value: f,
                child: Row(
                  children: [
                    Icon(f.icon, size: 18,
                        color: f == filter.sortField
                            ? AppColors.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(f.label,
                        style: f == filter.sortField
                            ? const TextStyle(fontWeight: FontWeight.w700)
                            : null),
                    if (f == filter.sortField) ...[
                      const Spacer(),
                      Icon(
                        filter.sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              filter.sortField.label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              filter.sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic Filter Chip with popup ─────────────────────

class _FilterChipDropdown<T> extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;

  const _FilterChipDropdown({
    required this.label,
    required this.isActive,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items
          .map((item) => PopupMenuItem(
                value: item,
                child: Text(itemLabel(item)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.textHint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? AppColors.primary : HCColor.of(context).textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tag Filter Chip (multi-select) ─────────────────────

class _TagFilterChip extends ConsumerWidget {
  final List<String> availableTags;
  final List<String> selectedTags;

  const _TagFilterChip({
    required this.availableTags,
    required this.selectedTags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = selectedTags.isNotEmpty;
    return PopupMenuButton<String>(
      onSelected: (tag) {
        final current = List<String>.from(selectedTags);
        if (current.contains(tag)) {
          current.remove(tag);
        } else {
          current.add(tag);
        }
        ref.read(studentFilterProvider.notifier).setTagFilter(current);
      },
      itemBuilder: (_) => availableTags
          .map((tag) => CheckedPopupMenuItem(
                value: tag,
                checked: selectedTags.contains(tag),
                child: Text(tag),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.textHint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? 'Tags (${selectedTags.length})' : 'Tags',
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? AppColors.primary : HCColor.of(context).textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
