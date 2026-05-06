import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/parent_teacher_note_models.dart';
import '../services/notes_cloud_service.dart';

class ParentTeacherNotesScreen extends ConsumerStatefulWidget {
  const ParentTeacherNotesScreen({super.key});

  @override
  ConsumerState<ParentTeacherNotesScreen> createState() =>
      _ParentTeacherNotesScreenState();
}

class _ParentTeacherNotesScreenState
    extends ConsumerState<ParentTeacherNotesScreen> {
  static const _cloud = ParentTeacherNotesCloudService();

  List<ParentTeacherNote> _notes = [];
  NoteCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// IDs of every student whose notes this profile should see.
  /// - student: just themselves (notes others wrote about them)
  /// - educator (teacher/parent): every student profile on this device
  List<String> _studentIdsForCurrentProfile() {
    final profile = ref.read(profileProvider);
    if (profile == null) return const [];
    if (profile.role == UserRole.student) {
      return [profile.id];
    }
    return HiveService.getProfiles()
        .where((p) => UserRole.values[p['role'] as int] == UserRole.student)
        .map((p) => p['id'] as String)
        .toList();
  }

  /// Read every relevant student's bucket from Hive AND pull from
  /// Firestore (so notes authored on another device show up here).
  Future<void> _loadNotes() async {
    final studentIds = _studentIdsForCurrentProfile();
    if (studentIds.isEmpty) return;

    // Show local data immediately to avoid a blank screen during the
    // network round-trip.
    final localMerged = <ParentTeacherNote>[];
    for (final id in studentIds) {
      localMerged.addAll(HiveService.getNotesForStudent(id));
    }
    localMerged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _notes = localMerged);

    // Then refresh from cloud — overwrites Hive and our state.
    final fresh = <ParentTeacherNote>[];
    for (final id in studentIds) {
      fresh.addAll(await _cloud.hydrateFromCloud(id));
    }
    fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _notes = fresh);
  }

  List<ParentTeacherNote> get _filteredNotes {
    if (_filterCategory == null) return _notes;
    return _notes.where((n) => n.category == _filterCategory).toList();
  }

  Future<void> _addNote() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final result = await _showNoteEditor(context);
    if (result == null) return;

    final note = ParentTeacherNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorProfileId: profile.id,
      authorName: profile.name,
      studentProfileId: result.studentId ?? profile.id,
      content: result.content,
      category: result.category,
      createdAt: DateTime.now(),
    );

    await _cloud.saveNote(note);
    _notes.insert(0, note);
    ref.read(hapticServiceProvider).success();
    setState(() {});

    if (mounted) {
      final settings = ref.read(settingsProvider);
      final isFilipino = settings.locale == 'fil';
      AppSnackBar.success(
        context,
        message:
            isFilipino ? 'Naidagdag ang tala!' : 'Note added successfully!',
      );
    }
  }

  Future<void> _deleteNote(ParentTeacherNote note) async {
    _notes.removeWhere((n) => n.id == note.id);
    await _cloud.deleteNote(note.id, note.studentProfileId);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final profile = ref.watch(profileProvider);
    final isEducator =
        profile?.role == UserRole.teacher || profile?.role == UserRole.parent;

    final notes = _filteredNotes;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Mga Tala ng Magulang-Guro' : 'Parent-Teacher Notes'),
      ),
      floatingActionButton: isEducator
          ? FloatingActionButton.extended(
              onPressed: _addNote,
              icon: const Icon(Icons.add_rounded),
              label: Text(isFilipino ? 'Bagong Tala' : 'New Note'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Filter Chips ──────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: isFilipino ? 'Lahat' : 'All',
                      emoji: '📋',
                      isSelected: _filterCategory == null,
                      onTap: () => setState(() => _filterCategory = null),
                      hc: hc,
                    ),
                    const SizedBox(width: 8),
                    ...NoteCategory.values.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: isFilipino ? cat.labelFilipino : cat.label,
                            emoji: cat.emoji,
                            isSelected: _filterCategory == cat,
                            onTap: () =>
                                setState(() => _filterCategory = cat),
                            hc: hc,
                          ),
                        )),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // ─── Notes List ──────────────────
            Expanded(
              child: notes.isEmpty
                  ? _buildEmptyState(hc, isFilipino, isEducator)
                  : ListView.builder(
                      padding: EdgeInsets.all(padding),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return _NoteCard(
                          note: note,
                          hc: hc,
                          isFilipino: isFilipino,
                          isAuthor: note.authorProfileId == profile?.id,
                          onDelete: () => _deleteNote(note),
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 50 * index),
                              duration: 300.ms,
                            )
                            .slideX(begin: 0.05, end: 0);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(HCColor hc, bool isFilipino, bool isEducator) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            isFilipino ? 'Walang tala pa' : 'No notes yet',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEducator
                ? (isFilipino
                    ? 'Mag-tap ng + para magdagdag ng tala para sa isang mag-aaral.'
                    : 'Tap + to add a note about a student.')
                : (isFilipino
                    ? 'Makikita rito ang mga tala mula sa guro.'
                    : 'Notes from the teacher will appear here.'),
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<_NoteEditorResult?> _showNoteEditor(BuildContext context) async {
    final hc = HCColor.of(context);
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final contentController = TextEditingController();
    NoteCategory selectedCategory = NoteCategory.general;

    // Get student profiles for selection
    final allProfiles = HiveService.getProfiles();
    final studentProfiles = allProfiles
        .where((p) => UserRole.values[p['role'] as int] == UserRole.student)
        .toList();
    String? selectedStudentId =
        studentProfiles.isNotEmpty ? studentProfiles.first['id'] as String : null;

    return showModalBottomSheet<_NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hc.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isFilipino ? 'Bagong Tala' : 'New Note',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Student selection
                if (studentProfiles.isNotEmpty) ...[
                  Text(
                    isFilipino ? 'Mag-aaral' : 'Student',
                    style: AppTypography.labelMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStudentId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: studentProfiles.map((p) {
                      return DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() => selectedStudentId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Category selection
                Text(
                  isFilipino ? 'Kategorya' : 'Category',
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NoteCategory.values.map((cat) {
                    final isSelected = selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? hc.primary.withValues(alpha: 0.2)
                              : hc.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? hc.primary : hc.border,
                          ),
                        ),
                        child: Text(
                          '${cat.emoji} ${isFilipino ? cat.labelFilipino : cat.label}',
                          style: AppTypography.labelMedium.copyWith(
                            color: isSelected ? hc.primary : hc.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Content
                Text(
                  isFilipino ? 'Nilalaman ng Tala' : 'Note Content',
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: isFilipino
                        ? 'Isulat ang iyong tala dito...'
                        : 'Write your note here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: isFilipino ? 'I-save ang tala' : 'Save note',
                    child: FilledButton.icon(
                      onPressed: () {
                        final content = contentController.text.trim();
                        if (content.isEmpty) return;
                        Navigator.of(context).pop(_NoteEditorResult(
                          content: content,
                          category: selectedCategory,
                          studentId: selectedStudentId,
                        ));
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: Text(isFilipino ? 'I-save' : 'Save Note'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteEditorResult {
  final String content;
  final NoteCategory category;
  final String? studentId;

  const _NoteEditorResult({
    required this.content,
    required this.category,
    this.studentId,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  final HCColor hc;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? hc.primary.withValues(alpha: 0.2)
                : hc.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? hc.primary : hc.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected ? hc.primary : hc.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final ParentTeacherNote note;
  final HCColor hc;
  final bool isFilipino;
  final bool isAuthor;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.hc,
    required this.isFilipino,
    required this.isAuthor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hc.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${note.category.emoji} ${isFilipino ? note.category.labelFilipino : note.category.label}',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(note.createdAt, isFilipino),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                if (isAuthor) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: hc.error,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              note.content,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: hc.textSecondary),
                const SizedBox(width: 4),
                Text(
                  note.authorName,
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFilipino ? 'Burahin ang Tala?' : 'Delete Note?'),
        content: Text(
          isFilipino
              ? 'Hindi na ito maibabalik.'
              : 'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isFilipino ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: HCColor.of(context).error,
            ),
            child: Text(isFilipino ? 'Burahin' : 'Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d, bool isFilipino) {
    final months = isFilipino
        ? ['Ene', 'Peb', 'Mar', 'Abr', 'May', 'Hun',
           'Hul', 'Ago', 'Set', 'Okt', 'Nob', 'Dis']
        : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
