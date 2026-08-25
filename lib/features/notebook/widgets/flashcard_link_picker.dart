import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';

/// Picks the flashcards a study note is about.
///
/// [NoteEntry.linkedFlashcardIds] has existed since the notebook shipped, and
/// the note card has always rendered a "N linked" footer for it — but nothing
/// could ever put an id in the list. A note saying "keep mixing these up" was
/// stranded from the words it was about.
///
/// Returns the chosen ids, or null if the sheet was dismissed.
Future<List<String>?> showFlashcardLinkPicker(
  BuildContext context, {
  required List<String> initialIds,
  FlashcardCategory? preferredCategory,
  required bool isFilipino,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FlashcardLinkPicker(
      initialIds: initialIds,
      preferredCategory: preferredCategory,
      isFilipino: isFilipino,
    ),
  );
}

class _FlashcardLinkPicker extends ConsumerStatefulWidget {
  final List<String> initialIds;
  final FlashcardCategory? preferredCategory;
  final bool isFilipino;

  const _FlashcardLinkPicker({
    required this.initialIds,
    required this.preferredCategory,
    required this.isFilipino,
  });

  @override
  ConsumerState<_FlashcardLinkPicker> createState() =>
      _FlashcardLinkPickerState();
}

class _FlashcardLinkPickerState extends ConsumerState<_FlashcardLinkPicker> {
  late Set<String> _selected;
  late FlashcardCategory? _category;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialIds};
    // Opens on the note's own category when it has one — the words a note is
    // about are almost always the ones it is filed under.
    _category = widget.preferredCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Flashcard> _visible(List<Flashcard> all) {
    final q = _query.trim().toLowerCase();
    return all.where((c) {
      if (_category != null && c.category != _category) return false;
      if (q.isEmpty) return true;
      return c.wordEnglish.toLowerCase().contains(q) ||
          c.wordFilipino.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isFilipino = widget.isFilipino;
    final all = ref.watch(allFlashcardsProvider);
    final visible = _visible(all);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: hc.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isFilipino ? 'Iugnay ang mga salita' : 'Link words',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    isFilipino
                        ? '${_selected.length} napili'
                        : '${_selected.length} selected',
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isFilipino ? 'Maghanap...' : 'Search words...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: hc.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(isFilipino ? 'Lahat' : 'All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final cat in FlashcardCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.label),
                        selected: _category == cat,
                        onSelected: (_) => setState(
                          () => _category = _category == cat ? null : cat,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isFilipino
                              ? 'Walang salitang tugma.'
                              : 'No words match.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: hc.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final card = visible[i];
                        final checked = _selected.contains(card.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) => setState(() {
                            if (v ?? false) {
                              _selected.add(card.id);
                            } else {
                              _selected.remove(card.id);
                            }
                          }),
                          title: Text(
                            card.wordEnglish,
                            style: AppTypography.bodyMedium
                                .copyWith(color: hc.textPrimary),
                          ),
                          subtitle: Text(
                            '${card.wordFilipino} · ${card.category.label}',
                            style: AppTypography.labelSmall
                                .copyWith(color: hc.textSecondary),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(context, _selected.toList()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isFilipino ? 'Tapos' : 'Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
