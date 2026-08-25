import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/stt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../models/notebook_models.dart';
import '../providers/notebook_provider.dart';
import '../widgets/flashcard_link_picker.dart';
import '../../../widgets/app_back_button.dart';
import '../../../navigation/nav_extensions.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteEntry? existingNote;

  /// Pre-fill for a brand-new note started somewhere else in the app — from a
  /// flashcard, say. Ignored when [existingNote] is set, which is an edit.
  final NoteDraft? draft;

  const NoteEditorScreen({super.key, this.existingNote, this.draft});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  FlashcardCategory? _selectedCategory;
  bool _isEditing = false;

  /// Flashcards this note is about. Persisted to
  /// [NoteEntry.linkedFlashcardIds], which nothing could write until now.
  List<String> _linkedIds = const [];

  /// What was on screen when the editor opened, so the exit guard can tell a
  /// real edit from an accidental tap.
  late final String _initialTitle;
  late final String _initialContent;
  FlashcardCategory? _initialCategory;
  List<String> _initialLinkedIds = const [];

  // ─── Dictation ──────────────────────────────────────
  bool _listening = false;
  bool _dictationUsed = false;

  /// Where the content field ended before dictation started, so each new
  /// partial hypothesis replaces the last one instead of stacking up.
  String _contentBeforeDictation = '';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingNote != null;
    _titleController = TextEditingController(
      text: widget.existingNote?.title ?? widget.draft?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingNote?.content ?? '',
    );
    final draft = _isEditing ? null : widget.draft;
    _selectedCategory = widget.existingNote?.category ?? draft?.category;
    _linkedIds = List.of(
      widget.existingNote?.linkedFlashcardIds ??
          draft?.linkedFlashcardIds ??
          const <String>[],
    );
    _initialLinkedIds = List.of(_linkedIds);

    _initialTitle = _titleController.text;
    _initialContent = _contentController.text;
    _initialCategory = _selectedCategory;
    _dictationUsed = widget.existingNote?.isVoiceNote ?? false;
  }

  @override
  void dispose() {
    // Never leave the microphone open behind a closed screen.
    if (_listening) ref.read(sttServiceProvider).cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Set once the note has been written to storage, so the exit guard cannot
  /// ask a learner to confirm discarding work that is already saved.
  bool _saved = false;

  bool get _isDirty =>
      !_saved &&
      (_titleController.text != _initialTitle ||
          _contentController.text != _initialContent ||
          _selectedCategory != _initialCategory ||
          !_sameIds(_linkedIds, _initialLinkedIds));

  static bool _sameIds(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  // ─── Dictation ──────────────────────────────────────

  /// Speak a note instead of typing it.
  ///
  /// [NoteEntry] has carried an `isVoiceNote` flag since the feature shipped,
  /// and the note card has always drawn a microphone for it — but nothing
  /// could ever set it, because typing was the only way in. For a learner
  /// with a motor impairment, or one who reads and writes below their spoken
  /// vocabulary, that made the notebook the one study tool they could not
  /// actually use.
  Future<void> _toggleDictation(bool isFilipino) async {
    final stt = ref.read(sttServiceProvider);

    if (_listening) {
      await stt.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await stt.init();
    if (!mounted) return;
    if (!available) {
      AppSnackBar.warning(
        context,
        message: isFilipino
            ? 'Hindi available ang mikropono sa device na ito.'
            : 'Speech input is not available on this device.',
      );
      return;
    }

    _contentBeforeDictation = _contentController.text;
    // `_dictationUsed` is set when words actually arrive, not here: opening
    // the mic and saying nothing should not brand the note with a microphone
    // it never used.
    setState(() => _listening = true);

    await stt.startListening(
      locale: isFilipino ? 'fil-PH' : 'en-US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (text, isFinal) {
        if (!mounted || text.isEmpty) return;
        _dictationUsed = true;
        final separator =
            _contentBeforeDictation.isEmpty || _contentBeforeDictation.endsWith('\n')
                ? ''
                : ' ';
        _contentController.text = '$_contentBeforeDictation$separator$text';
        _contentController.selection = TextSelection.collapsed(
          offset: _contentController.text.length,
        );
        if (isFinal) {
          // Bank the final transcript so a second burst appends to it.
          _contentBeforeDictation = _contentController.text;
          setState(() => _listening = false);
        }
      },
    );
  }

  /// Choose which flashcards this note is about.
  Future<void> _pickLinkedWords(bool isFilipino) async {
    final picked = await showFlashcardLinkPicker(
      context,
      initialIds: _linkedIds,
      // Scoped to the note's category when it has one, so the list opens on
      // the words the note is most likely about.
      preferredCategory: _selectedCategory,
      isFilipino: isFilipino,
    );
    if (picked == null || !mounted) return;
    setState(() => _linkedIds = picked);
  }

  // ─── Exit guard ─────────────────────────────────────

  /// Ask before throwing away unsaved work.
  ///
  /// The back button used to pop straight out, so a learner who wrote a page
  /// and hit back lost all of it with no warning and no undo.
  Future<bool> _confirmDiscard(bool isFilipino) async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFilipino ? 'Itapon ang mga pagbabago?' : 'Discard changes?'),
        content: Text(
          isFilipino
              ? 'Hindi pa na-save ang tala mo.'
              : 'Your note has not been saved yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFilipino ? 'Magpatuloy sa pagsulat' : 'Keep writing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isFilipino ? 'Itapon' : 'Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard(isFilipino) && mounted) {
          if (!context.mounted) return;
          context.popOrGo('/notebook');
        }
      },
      child: Scaffold(
        backgroundColor: hc.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: AppBackButton(
            fallbackRoute: '/notebook',
            // The hook AppBackButton already exposes for exactly this:
            // returning false cancels the pop and leaves the draft on screen.
            onBeforePop: () => _confirmDiscard(isFilipino),
          ),
          title: Text(
            _isEditing
                ? (isFilipino ? 'I-edit ang Tala' : 'Edit Note')
                : (isFilipino ? 'Bagong Tala' : 'New Note'),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () => _saveNote(isFilipino),
                icon: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textOnPrimary,
                ),
                label: Text(
                  isFilipino ? 'I-save' : 'Save',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.04),
                Colors.transparent,
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Title Field ──────────────────────
                TextField(
                  controller: _titleController,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: isFilipino ? 'Pamagat ng tala...' : 'Note title...',
                    hintStyle: AppTypography.titleMedium.copyWith(
                      color: hc.textHint,
                    ),
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const Divider(),

                // ─── Category Selector ────────────────
                const SizedBox(height: 8),
                Text(
                  isFilipino ? 'Kategorya (opsyonal)' : 'Category (optional)',
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(isFilipino ? 'Wala' : 'None'),
                      selected: _selectedCategory == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = null),
                    ),
                    ...FlashcardCategory.values.map(
                      (cat) => ChoiceChip(
                        label: Text(cat.label),
                        avatar: Icon(cat.icon, size: 16),
                        selected: _selectedCategory == cat,
                        onSelected: (_) => setState(
                          () => _selectedCategory = _selectedCategory == cat
                              ? null
                              : cat,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── Linked words ─────────────────────
                _LinkedWordsField(
                  linkedIds: _linkedIds,
                  isFilipino: isFilipino,
                  onEdit: () => _pickLinkedWords(isFilipino),
                  onRemove: (id) =>
                      setState(() => _linkedIds = [..._linkedIds]..remove(id)),
                ),

                const SizedBox(height: 20),

                // ─── Dictate ──────────────────────────
                _DictateButton(
                  listening: _listening,
                  isFilipino: isFilipino,
                  onPressed: () => _toggleDictation(isFilipino),
                ),

                const SizedBox(height: 12),

                // ─── Content Field ────────────────────
                TextField(
                  controller: _contentController,
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textPrimary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: isFilipino
                        ? 'Isulat o sabihin ang iyong tala dito...'
                        : 'Write or speak your study notes here...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: hc.textHint,
                    ),
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveNote(bool isFilipino) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      AppSnackBar.warning(
        context,
        message: isFilipino
            ? 'Magdagdag ng pamagat o nilalaman'
            : 'Please add a title or content',
      );
      return;
    }

    final now = DateTime.now();
    final notifier = ref.read(notebookProvider.notifier);
    final fallbackTitle = isFilipino ? 'Walang Pamagat' : 'Untitled';

    if (_isEditing && widget.existingNote != null) {
      notifier.updateNote(
        widget.existingNote!.copyWith(
          title: title.isNotEmpty ? title : fallbackTitle,
          content: content,
          category: () => _selectedCategory,
          updatedAt: now,
          isVoiceNote: _dictationUsed,
          linkedFlashcardIds: _linkedIds,
        ),
      );
    } else {
      notifier.addNote(
        NoteEntry(
          id: 'note_${now.millisecondsSinceEpoch}',
          title: title.isNotEmpty ? title : fallbackTitle,
          content: content,
          category: _selectedCategory,
          createdAt: now,
          updatedAt: now,
          isVoiceNote: _dictationUsed,
          linkedFlashcardIds: _linkedIds,
        ),
      );
    }

    // Saved — the exit guard has nothing left to protect.
    _saved = true;
    context.popOrGo('/notebook');
  }
}

/// The dictation toggle, with its live state spelled out rather than implied
/// by an icon colour alone.
class _DictateButton extends StatelessWidget {
  final bool listening;
  final bool isFilipino;
  final VoidCallback onPressed;

  const _DictateButton({
    required this.listening,
    required this.isFilipino,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final label = listening
        ? (isFilipino ? 'Nakikinig… pindutin para itigil' : 'Listening… tap to stop')
        : (isFilipino ? 'Sabihin ang tala' : 'Speak your note');

    return Semantics(
      button: true,
      toggled: listening,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
          color: listening ? AppColors.error : hc.primary,
        ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: listening ? AppColors.error : hc.primary,
          side: BorderSide(
            color: (listening ? AppColors.error : hc.primary)
                .withValues(alpha: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// The words a note is about, with a way to change them.
///
/// Reads the card titles live from [allFlashcardsProvider] rather than
/// storing them on the note, so a renamed or removed card can never leave a
/// stale word behind. An id that no longer resolves is simply dropped from
/// the display — the note keeps it, in case the card comes back.
class _LinkedWordsField extends ConsumerWidget {
  final List<String> linkedIds;
  final bool isFilipino;
  final VoidCallback onEdit;
  final ValueChanged<String> onRemove;

  const _LinkedWordsField({
    required this.linkedIds,
    required this.isFilipino,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final byId = {for (final c in ref.watch(allFlashcardsProvider)) c.id: c};
    final resolved = [
      for (final id in linkedIds)
        if (byId[id] != null) byId[id]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isFilipino
                    ? 'Mga kaugnay na salita (opsyonal)'
                    : 'Linked words (optional)',
                style: AppTypography.labelMedium.copyWith(
                  color: hc.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(
                resolved.isEmpty
                    ? (isFilipino ? 'Magdagdag' : 'Add')
                    : (isFilipino ? 'Baguhin' : 'Change'),
              ),
            ),
          ],
        ),
        if (resolved.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final card in resolved)
                InputChip(
                  label: Text(card.wordEnglish),
                  avatar: Icon(card.category.icon, size: 16),
                  onDeleted: () => onRemove(card.id),
                  deleteButtonTooltipMessage:
                      isFilipino ? 'Alisin' : 'Remove link',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
