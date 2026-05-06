import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../models/notebook_models.dart';
import '../providers/notebook_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteEntry? existingNote;
  const NoteEditorScreen({super.key, this.existingNote});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  FlashcardCategory? _selectedCategory;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingNote != null;
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?.content ?? '');
    _selectedCategory = widget.existingNote?.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/notebook');
            }
          },
        ),
        title: Text(
          _isEditing ? 'Edit Note' : 'New Note',
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
              onPressed: _saveNote,
              icon: const Icon(Icons.check_rounded, color: AppColors.textOnPrimary),
              label: Text(
                'Save',
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
                hintText: 'Note title...',
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
              'Category (optional)',
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
                  label: const Text('None'),
                  selected: _selectedCategory == null,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = null),
                ),
                ...FlashcardCategory.values.map((cat) => ChoiceChip(
                      label: Text(cat.label),
                      avatar: Icon(cat.icon, size: 16),
                      selected: _selectedCategory == cat,
                      onSelected: (_) => setState(() =>
                          _selectedCategory =
                              _selectedCategory == cat ? null : cat),
                    )),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Content Field ────────────────────
            TextField(
              controller: _contentController,
              style: AppTypography.bodyMedium.copyWith(
                color: hc.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Write your study notes here...',
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
    );
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      AppSnackBar.warning(context, message: 'Please add a title or content');
      return;
    }

    final now = DateTime.now();
    final notifier = ref.read(notebookProvider.notifier);

    if (_isEditing && widget.existingNote != null) {
      notifier.updateNote(widget.existingNote!.copyWith(
        title: title.isNotEmpty ? title : 'Untitled',
        content: content,
        category: () => _selectedCategory,
        updatedAt: now,
      ));
    } else {
      notifier.addNote(NoteEntry(
        id: 'note_${now.millisecondsSinceEpoch}',
        title: title.isNotEmpty ? title : 'Untitled',
        content: content,
        category: _selectedCategory,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/notebook');
    }
  }
}
