import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';

class CreateFlashcardScreen extends ConsumerStatefulWidget {
  final Flashcard? editCard;

  const CreateFlashcardScreen({super.key, this.editCard});

  @override
  ConsumerState<CreateFlashcardScreen> createState() =>
      _CreateFlashcardScreenState();
}

class _CreateFlashcardScreenState
    extends ConsumerState<CreateFlashcardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordEnController = TextEditingController();
  final _wordFlController = TextEditingController();
  final _exampleController = TextEditingController();
  FlashcardCategory _selectedCategory = FlashcardCategory.animals;
  bool _isSaving = false;

  bool get _isEditing => widget.editCard != null;

  @override
  void initState() {
    super.initState();
    if (widget.editCard != null) {
      _wordEnController.text = widget.editCard!.wordEnglish;
      _wordFlController.text = widget.editCard!.wordFilipino;
      _exampleController.text = widget.editCard!.exampleSentence ?? '';
      _selectedCategory = widget.editCard!.category;
    }
  }

  @override
  void dispose() {
    _wordEnController.dispose();
    _wordFlController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final card = Flashcard(
      id: _isEditing ? widget.editCard!.id : const Uuid().v4(),
      wordEnglish: _wordEnController.text.trim(),
      wordFilipino: _wordFlController.text.trim(),
      exampleSentence: _exampleController.text.trim().isEmpty
          ? null
          : _exampleController.text.trim(),
      category: _selectedCategory,
      isCustom: true,
    );

    if (_isEditing) {
      await HiveService.updateCustomCard(card);
    } else {
      await HiveService.saveCustomCard(card);
    }

    if (mounted) {
      AppSnackBar.success(context, message: _isEditing ? 'Flashcard updated! ✏️' : 'Flashcard created! 🎉');
      context.pop(true); // return true to signal a change was made
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Edit Flashcard' : 'Create Flashcard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview card
              _PreviewCard(
                wordEn: _wordEnController.text,
                wordFl: _wordFlController.text,
                category: _selectedCategory,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1, end: 0),

              const SizedBox(height: 28),

              // Category selector
              Text('Category', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FlashcardCategory.values.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat.label),
                    avatar: Icon(cat.icon, size: 18, color: isSelected ? Colors.white : cat.color),
                    selected: isSelected,
                    selectedColor: cat.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : hc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                }).toList(),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms),

              const SizedBox(height: 24),

              // Word (English)
              Text('Word (English)', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _wordEnController,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. Butterfly',
                  prefixIcon: Icon(Icons.abc_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a word' : null,
                onChanged: (_) => setState(() {}),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 20),

              // Word (Filipino)
              Text('Word (Filipino)', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _wordFlController,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. Paru-paro',
                  prefixIcon: Icon(Icons.translate_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a translation' : null,
                onChanged: (_) => setState(() {}),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 20),

              // Example sentence
              Text('Example Sentence (optional)',
                  style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _exampleController,
                style: AppTypography.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'e.g. The butterfly is colorful.',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 36),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSaving
                      ? 'Saving...'
                      : _isEditing
                          ? 'Update Flashcard'
                          : 'Create Flashcard'),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 500.ms)
                  .slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String wordEn;
  final String wordFl;
  final FlashcardCategory category;

  const _PreviewCard({
    required this.wordEn,
    required this.wordFl,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            category.color,
            category.color.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: category.color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Preview',
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Icon(category.icon, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            wordEn.isEmpty ? 'Your Word' : wordEn,
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            wordFl.isEmpty ? 'Iyong Salita' : wordFl,
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
