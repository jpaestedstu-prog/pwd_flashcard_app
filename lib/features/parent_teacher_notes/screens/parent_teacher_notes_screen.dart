import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../data/local/hive_service.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/parent_teacher_note_models.dart';
import '../services/notes_cloud_service.dart';

class ParentTeacherNotesScreen extends ConsumerStatefulWidget {
  /// When set, the screen is scoped to a single learner — used by the
  /// per-child entry points (e.g. the Parent Dashboard child card). When
  /// null, an educator sees every learner on their roster.
  ///
  /// A learner id is only honoured if it is actually on the caller's
  /// roster, so a hand-typed deep link can't widen access.
  final String? studentId;

  /// Display name for the scoped learner, passed via `?name=` so the app
  /// bar can title itself without a lookup. Cosmetic only.
  final String? studentName;

  const ParentTeacherNotesScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  ConsumerState<ParentTeacherNotesScreen> createState() =>
      _ParentTeacherNotesScreenState();
}

class _ParentTeacherNotesScreenState
    extends ConsumerState<ParentTeacherNotesScreen> {
  static const _cloud = ParentTeacherNotesCloudService();

  List<ParentTeacherNote> _notes = [];
  NoteCategory? _filterCategory;

  /// Roster the educator may write notes about: (id, name) pairs.
  /// Empty for learners, who only ever see their own notes.
  List<(String, String)> _roster = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  /// The learners whose notes this profile may see.
  ///
  /// - learner (student / child): only themselves.
  /// - educator (teacher / parent): only learners on **their own roster**.
  ///
  /// This deliberately does NOT read every profile on the device. The old
  /// implementation did, which on a shared tablet showed a teacher the notes
  /// about another family's children (and vice versa). It also filtered on
  /// `role == student`, so a parent's `child`-role children were dropped
  /// entirely — the parent saw nothing and any note they wrote was filed
  /// against their own profile id.
  Future<List<(String, String)>> _visibleLearners() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return const [];

    if (!profile.role.isEducator) {
      return [(profile.id, profile.name)];
    }

    // Firestore-backed roster so learners enrolled from another device are
    // included; falls back to local Hive when the fetch fails (offline).
    List<(UserProfile, LearningProgress)> pairs = const [];
    try {
      pairs = await ref.read(educatorRosterProvider(profile.id).future);
    } on Exception catch (e) {
      debugPrint('parent-teacher notes: roster fetch failed: $e');
    }
    if (pairs.isEmpty) {
      pairs = HiveService.getAllProfilesWithProgress();
    }

    return pairs
        .map((p) => p.$1)
        .where((p) => p.role.isEnrollableLearner && !p.isGuestPlayer)
        .map((p) => (p.id, p.name))
        .toList()
      ..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
  }

  /// Read every relevant learner's bucket from Hive AND pull from
  /// Firestore (so notes authored on another device show up here).
  Future<void> _loadNotes() async {
    final roster = await _visibleLearners();
    if (!mounted) return;

    // Honour the scoped id only when it's on the roster — otherwise fall
    // back to the full roster rather than trusting the URL.
    final scoped = widget.studentId;
    final visible = (scoped != null && roster.any((r) => r.$1 == scoped))
        ? roster.where((r) => r.$1 == scoped).toList()
        : roster;

    setState(() => _roster = visible);
    final learnerIds = visible.map((r) => r.$1).toList();
    if (learnerIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Show local data immediately to avoid a blank screen during the
    // network round-trip.
    final localMerged = <ParentTeacherNote>[];
    for (final id in learnerIds) {
      localMerged.addAll(HiveService.getNotesForStudent(id));
    }
    localMerged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _notes = localMerged);

    // Then refresh from cloud — overwrites Hive and our state.
    final fresh = <ParentTeacherNote>[];
    for (final id in learnerIds) {
      fresh.addAll(await _cloud.hydrateFromCloud(id));
    }
    fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) {
      setState(() {
        _notes = fresh;
        _loading = false;
      });
    }
  }

  /// Display name for a note's subject, resolved from the roster we already
  /// loaded. Null when the id isn't on the roster (shouldn't happen — the
  /// notes are fetched per roster id — so the card just omits the name).
  String? _learnerNameFor(String studentProfileId) => _roster
      .where((r) => r.$1 == studentProfileId)
      .map((r) => r.$2)
      .firstOrNull;

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

    // When scoped to one learner, name them in the title so the educator can
    // see at a glance which child they're writing about.
    final scopedName = widget.studentId != null
        ? (widget.studentName ??
            _roster
                .where((r) => r.$1 == widget.studentId)
                .map((r) => r.$2)
                .firstOrNull)
        : null;
    final title = scopedName != null
        ? (isFilipino ? 'Mga Tala — $scopedName' : 'Notes — $scopedName')
        : (isFilipino ? 'Mga Tala ng Magulang-Guro' : 'Parent-Teacher Notes');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // Nothing to write a note against until the roster resolves — showing
      // the FAB early opens an editor with an empty learner picker, which
      // used to file the note against the author's own profile id.
      floatingActionButton: isEducator && _roster.isNotEmpty
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
              child: _loading && notes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : notes.isEmpty
                      ? _buildEmptyState(hc, isFilipino, isEducator)
                      // The entrance animation lives on the list, not the
                      // rows: `ListView.builder` rebuilds a row every time it
                      // scrolls back into view, so a per-row staggered
                      // `.animate()` replays from opacity 0 and notes blink out
                      // mid-scroll.
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
                              // Only an educator browsing their whole roster
                              // needs to be told who a note is about — a
                              // learner is reading notes about themselves,
                              // and a scoped view already says so in the
                              // app bar.
                              learnerName: (isEducator && scopedName == null)
                                  ? _learnerNameFor(note.studentProfileId)
                                  : null,
                            );
                          },
                        ).animate().fadeIn(duration: 300.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(HCColor hc, bool isFilipino, bool isEducator) {
    // An educator with nobody on their roster can't write a note at all, so
    // "tap + to add a note" would point at a button that isn't there.
    final noRoster = isEducator && _roster.isEmpty;

    final String body;
    if (noRoster) {
      body = isFilipino
          ? 'Magdagdag muna ng mag-aaral sa iyong klase o home group.'
          : 'Add a learner to your class or home group first.';
    } else if (isEducator) {
      body = isFilipino
          ? 'Mag-tap ng + para magdagdag ng tala para sa isang mag-aaral.'
          : 'Tap + to add a note about a learner.';
    } else {
      body = isFilipino
          ? 'Makikita rito ang mga tala mula sa guro at magulang.'
          : 'Notes from your teacher and parent will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(noRoster ? '👥' : '📝',
                style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              noRoster
                  ? (isFilipino ? 'Walang mag-aaral' : 'No learners yet')
                  : (isFilipino ? 'Walang tala pa' : 'No notes yet'),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: hc.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<_NoteEditorResult?> _showNoteEditor(BuildContext context) async {
    final hc = HCColor.of(context);
    final settings = ref.read(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final contentController = TextEditingController();
    NoteCategory selectedCategory = NoteCategory.general;

    // Learners this educator may write about — the same roster the list is
    // scoped to, so the picker can never file a note against someone off
    // the roster (or, when the screen is scoped to one child, anyone else).
    final studentProfiles = _roster;
    String? selectedStudentId =
        studentProfiles.isNotEmpty ? studentProfiles.first.$1 : null;

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
                        value: p.$1,
                        child: Text(p.$2),
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

  /// Who the note is about. Null when the screen is scoped to a single
  /// learner, since the app bar already names them.
  final String? learnerName;

  const _NoteCard({
    required this.note,
    required this.hc,
    required this.isFilipino,
    required this.isAuthor,
    required this.onDelete,
    this.learnerName,
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

            // Footer — author, plus who the note is about. Without the
            // learner name the all-roster view is a flat list with no way
            // to tell which of six students a note refers to. Omitted when
            // the screen is already scoped to one learner (the app bar
            // says so) to avoid repeating it on every card.
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: hc.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    note.authorName,
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (learnerName != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded,
                      size: 12, color: hc.textHint),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      learnerName!,
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
