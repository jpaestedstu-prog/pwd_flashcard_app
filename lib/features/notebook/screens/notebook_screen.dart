import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notebookProvider);
    final notifier = ref.read(notebookProvider.notifier);
    final hc = HCColor.of(context);

    // Apply filters
    List<NoteEntry> notes;
    if (_searchQuery.isNotEmpty) {
      notes = notifier.search(_searchQuery);
    } else {
      notes = notifier.filterByCategory(_selectedCategory);
    }

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'My Notebook',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: hc.textSecondary),
            tooltip: 'Search notes',
            onPressed: () => _showSearchBar(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notebook/editor'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note'),
        backgroundColor: HCColor.of(context).primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ─── Search Bar (conditionally visible) ─────
          if (_searchQuery.isNotEmpty || _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
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
                    label: const Text('All'),
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
                          onTap: () => context.push(
                            '/notebook/editor',
                            extra: note,
                          ),
                          onDelete: () => _confirmDelete(context, ref, note),
                        ),
                      ).animate().fadeIn(
                            duration: 350.ms,
                            delay: Duration(milliseconds: 50 * index),
                          ).slideY(begin: 0.06, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSearchBar() {
    setState(() {
      // Toggle search visibility by setting a non-empty initial state
      if (_searchQuery.isEmpty && _searchController.text.isEmpty) {
        _searchQuery = ' ';
        _searchQuery = '';
      }
    });
    // Focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, NoteEntry note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
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
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return RichEmptyState(
      emoji: hasFilter ? '🔍' : '📓',
      title: hasFilter
          ? 'No notes match your filter'
          : 'Your notebook is empty',
      description: hasFilter
          ? 'Try a different category or clear your search'
          : 'Tap + to create your first study note!',
      accentColor: AppColors.info,
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteEntry note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final catColor = note.category?.color ?? hc.primary;

    return Semantics(
      button: true,
      label: 'Note: ${note.title}. ${note.isVoiceNote ? "Voice note. " : ""}'
          '${note.category != null ? "Category: ${note.category!.label}. " : ""}'
          'Last edited ${_formatDate(note.updatedAt)}.',
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
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
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
                    _formatDate(note.updatedAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint,
                    ),
                  ),
                  if (note.linkedFlashcardIds.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.link_rounded, size: 12, color: hc.textHint),
                    const SizedBox(width: 4),
                    Text(
                      '${note.linkedFlashcardIds.length} linked',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
