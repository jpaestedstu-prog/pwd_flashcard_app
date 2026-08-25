import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../data/models/enums.dart';
import '../models/notebook_models.dart';
import '../providers/notebook_provider.dart';
import '../../../widgets/app_back_button.dart';

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  FlashcardCategory? _selectedCategory;
  String _searchQuery = '';

  /// Whether the search field is on screen.
  ///
  /// The magnifier used to call a `_showSearchBar()` that set `_searchQuery`
  /// to `' '` and back to `''` in the same `setState`, and the field rendered
  /// only when the query was non-empty — so the button was inert. Visibility
  /// is its own piece of state now, independent of what has been typed.
  bool _searchOpen = false;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    if (_searchOpen) {
      // Focus the real field, not a throwaway node — the old code built a
      // fresh `FocusNode()` and asked the scope to focus that, which could
      // never put a caret in the search box.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchOpen) _searchFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notebookProvider);
    final notifier = ref.read(notebookProvider.notifier);
    final hc = HCColor.of(context);
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';

    // Apply filters. Search and the category chips now compose, instead of
    // search silently discarding the active category.
    final notes = notifier
        .search(_searchQuery)
        .where((n) => _selectedCategory == null || n.category == _selectedCategory)
        .toList();

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          isFilipino ? 'Aking Kuwaderno' : 'My Notebook',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
              color: _searchOpen ? hc.primary : hc.textSecondary,
            ),
            tooltip: isFilipino
                ? (_searchOpen ? 'Isara ang paghahanap' : 'Maghanap ng tala')
                : (_searchOpen ? 'Close search' : 'Search notes'),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notebook/editor'),
        icon: const Icon(Icons.add_rounded),
        label: Text(isFilipino ? 'Bagong Tala' : 'New Note'),
        backgroundColor: HCColor.of(context).primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ─── Search Bar ─────────────────────────────
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: isFilipino
                      ? 'Maghanap ng tala...'
                      : 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: isFilipino ? 'Isara' : 'Close',
                    onPressed: _toggleSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: hc.surfaceLight,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),

          // ─── Category Filter Chips ──────────────────
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(isFilipino ? 'Lahat' : 'All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = null),
                  ),
                ),
                ...FlashcardCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.label),
                        avatar: Icon(cat.icon, size: 16),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory =
                                _selectedCategory == cat ? null : cat),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Notes List ─────────────────────────────
          Expanded(
            child: notes.isEmpty
                // Centre the empty state, but let it scroll instead of
                // overflowing a short viewport at a large font scale.
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: _EmptyState(
                          hasFilter: _selectedCategory != null ||
                              _searchQuery.isNotEmpty,
                          isFilipino: isFilipino,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NoteCard(
                          note: note,
                          isFilipino: isFilipino,
                          onTap: () => context.push(
                            '/notebook/editor',
                            extra: note,
                          ),
                          onDelete: () =>
                              _confirmDelete(context, ref, note, isFilipino),
                        ),
                        // No per-index stagger: this list is lazy, so a card
                        // built after a scroll would start its delay only
                        // once it came into view and sit blank.
                      ).animate().fadeIn(duration: 350.ms).slideY(
                            begin: 0.06,
                            end: 0,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NoteEntry note,
    bool isFilipino,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFilipino ? 'Burahin ang tala?' : 'Delete Note?'),
        content: Text(
          isFilipino
              ? 'Sigurado ka bang burahin ang "${note.title}"?'
              : 'Are you sure you want to delete "${note.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isFilipino ? 'Burahin' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(notebookProvider.notifier).deleteNote(note.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final bool isFilipino;
  const _EmptyState({required this.hasFilter, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    return RichEmptyState(
      emoji: hasFilter ? '🔍' : '📓',
      title: hasFilter
          ? (isFilipino
              ? 'Walang talang tugma'
              : 'No notes match your filter')
          : (isFilipino ? 'Walang laman ang kuwaderno' : 'Your notebook is empty'),
      description: hasFilter
          ? (isFilipino
              ? 'Subukan ang ibang kategorya o i-clear ang paghahanap'
              : 'Try a different category or clear your search')
          : (isFilipino
              ? 'Pindutin ang + para gumawa ng unang tala!'
              : 'Tap + to create your first study note!'),
      accentColor: AppColors.info,
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteEntry note;
  final bool isFilipino;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.isFilipino,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final catColor = note.category?.color ?? hc.primary;

    return Semantics(
      button: true,
      label: isFilipino
          ? 'Tala: ${note.title}. ${note.isVoiceNote ? "Voice note. " : ""}'
              '${note.category != null ? "Kategorya: ${note.category!.label}. " : ""}'
              'Huling binago ${_formatDate(note.updatedAt, true)}.'
          : 'Note: ${note.title}. ${note.isVoiceNote ? "Voice note. " : ""}'
              '${note.category != null ? "Category: ${note.category!.label}. " : ""}'
              'Last edited ${_formatDate(note.updatedAt, false)}.',
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: catColor.withValues(alpha: 0.3), width: 0.5),
        ),
        color: hc.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  catColor.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
              border: Border(
                left: BorderSide(color: catColor, width: 4),
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isVoiceNote)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.mic_rounded,
                          size: 16, color: catColor),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        note.category!.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: catColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        size: 20, color: hc.textHint),
                    tooltip: isFilipino ? 'Mga pagpipilian' : 'Options',
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_rounded,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(isFilipino ? 'Burahin' : 'Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.content,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 12, color: hc.textHint),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(note.updatedAt, isFilipino),
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint,
                    ),
                  ),
                  if (note.linkedFlashcardIds.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.link_rounded, size: 12, color: hc.textHint),
                    const SizedBox(width: 4),
                    Text(
                      isFilipino
                          ? '${note.linkedFlashcardIds.length} nakaugnay'
                          : '${note.linkedFlashcardIds.length} linked',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isFilipino) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return isFilipino ? 'Ngayon lang' : 'Just now';
    if (diff.inHours < 1) {
      return isFilipino ? '${diff.inMinutes}m nakaraan' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return isFilipino ? '${diff.inHours}h nakaraan' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return isFilipino ? '${diff.inDays}d nakaraan' : '${diff.inDays}d ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
