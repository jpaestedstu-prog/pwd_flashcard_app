import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../widgets/app_snack_bar.dart';

/// Enhanced flashcard creator with image attachment and voice recording.
///
/// Adds the following over the basic [CreateFlashcardScreen]:
/// - Image picker (gallery) via file_picker
/// - Voice-to-text dictation for each text field via speech_to_text
/// - Audio pronunciation preview via TTS
/// - Live preview card with image
class EnhancedCreateFlashcardScreen extends ConsumerStatefulWidget {
  final Flashcard? editCard;

  const EnhancedCreateFlashcardScreen({super.key, this.editCard});

  @override
  ConsumerState<EnhancedCreateFlashcardScreen> createState() =>
      _EnhancedCreateFlashcardScreenState();
}

class _EnhancedCreateFlashcardScreenState
    extends ConsumerState<EnhancedCreateFlashcardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordEnController = TextEditingController();
  final _wordFlController = TextEditingController();
  final _exampleController = TextEditingController();
  FlashcardCategory _selectedCategory = FlashcardCategory.animals;
  bool _isSaving = false;

  // Image
  String? _imagePath;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  _DictationTarget? _activeTarget;

  // Audio preview
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get _isEditing => widget.editCard != null;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    if (widget.editCard != null) {
      _wordEnController.text = widget.editCard!.wordEnglish;
      _wordFlController.text = widget.editCard!.wordFilipino;
      _exampleController.text = widget.editCard!.exampleSentence ?? '';
      _selectedCategory = widget.editCard!.category;
      _imagePath = widget.editCard!.imageAsset;
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _activeTarget = null);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _activeTarget = null);
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wordEnController.dispose();
    _wordFlController.dispose();
    _exampleController.dispose();
    _speech.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Image Picker ───────────────────────────────────
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imagePath = result.files.first.path;
      });
    }
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  // ─── Voice Dictation ───────────────────────────────
  Future<void> _startDictation(_DictationTarget target) async {
    if (!_speechAvailable) {
      AppSnackBar.warning(context, message: 'Speech recognition not available on this device.');
      return;
    }

    setState(() => _activeTarget = target);

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords;
          switch (target) {
            case _DictationTarget.english:
              _wordEnController.text = text;
              break;
            case _DictationTarget.filipino:
              _wordFlController.text = text;
              break;
            case _DictationTarget.example:
              _exampleController.text = text;
              break;
          }
          setState(() => _activeTarget = null);
        }
      },
      localeId: target == _DictationTarget.filipino ? 'fil-PH' : 'en-US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void _stopDictation() {
    _speech.stop();
    setState(() => _activeTarget = null);
  }

  // ─── Save ──────────────────────────────────────────
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
      imageAsset: _imagePath,
      category: _selectedCategory,
      isCustom: true,
    );

    if (_isEditing) {
      await HiveService.updateCustomCard(card);
    } else {
      await HiveService.saveCustomCard(card);
    }

    if (mounted) {
      AppSnackBar.success(
        context,
        message: _isEditing ? 'Flashcard updated! \u270f\ufe0f' : 'Flashcard created! \ud83c\udf89',
      );
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Flashcard' : 'Create Flashcard',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_speechAvailable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.mic, size: 16, color: hc.success),
                label: Text(
                  'Voice Ready',
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.success,
                    fontSize: 10,
                  ),
                ),
                backgroundColor: hc.success.withValues(alpha: 0.1),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Live Preview Card ────────────────
              _EnhancedPreviewCard(
                wordEn: _wordEnController.text,
                wordFl: _wordFlController.text,
                category: _selectedCategory,
                imagePath: _imagePath,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

              const SizedBox(height: 24),

              // ─── Image Section ────────────────────
              _SectionLabel(label: 'Image', icon: Icons.image_rounded, hc: hc),
              const SizedBox(height: 8),
              _ImagePickerArea(
                imagePath: _imagePath,
                hc: hc,
                onPick: _pickImage,
                onRemove: _removeImage,
              ).animate(delay: 50.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ─── Category Selector ────────────────
              _SectionLabel(
                  label: 'Category', icon: Icons.category_rounded, hc: hc),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: FlashcardCategory.values.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat.label),
                        avatar: Icon(cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color),
                        selected: isSelected,
                        selectedColor: cat.color,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : hc.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ─── English Word ─────────────────────
              _VoiceTextField(
                label: 'Word (English)',
                hint: 'e.g. Butterfly',
                icon: Icons.abc_rounded,
                controller: _wordEnController,
                hc: hc,
                isListening: _activeTarget == _DictationTarget.english,
                speechAvailable: _speechAvailable,
                onMicPressed: () =>
                    _activeTarget == _DictationTarget.english
                        ? _stopDictation()
                        : _startDictation(_DictationTarget.english),
                onChanged: () => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a word' : null,
              ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ─── Filipino Word ────────────────────
              _VoiceTextField(
                label: 'Word (Filipino)',
                hint: 'e.g. Paru-paro',
                icon: Icons.translate_rounded,
                controller: _wordFlController,
                hc: hc,
                isListening: _activeTarget == _DictationTarget.filipino,
                speechAvailable: _speechAvailable,
                onMicPressed: () =>
                    _activeTarget == _DictationTarget.filipino
                        ? _stopDictation()
                        : _startDictation(_DictationTarget.filipino),
                onChanged: () => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Enter a translation'
                        : null,
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ─── Example Sentence ─────────────────
              _VoiceTextField(
                label: 'Example Sentence (optional)',
                hint: 'e.g. The butterfly is colorful.',
                icon: Icons.short_text_rounded,
                controller: _exampleController,
                hc: hc,
                isListening: _activeTarget == _DictationTarget.example,
                speechAvailable: _speechAvailable,
                onMicPressed: () =>
                    _activeTarget == _DictationTarget.example
                        ? _stopDictation()
                        : _startDictation(_DictationTarget.example),
                onChanged: () => setState(() {}),
                maxLines: 2,
              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              // ─── Save Button ──────────────────────
              SizedBox(
                width: double.infinity,
                height: 58,
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
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : _isEditing
                            ? 'Update Flashcard'
                            : 'Create Flashcard',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hc.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                  ),
                ),
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dictation Target Enum ──────────────────────────────

enum _DictationTarget { english, filipino, example }

// ─── Section Label ──────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final HCColor hc;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: hc.primary, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Image Picker Area ──────────────────────────────────

class _ImagePickerArea extends StatelessWidget {
  final String? imagePath;
  final HCColor hc;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerArea({
    required this.imagePath,
    required this.hc,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && !kIsWeb) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              File(imagePath!),
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _circleBtn(Icons.refresh_rounded, hc.info, onPick),
                const SizedBox(width: 6),
                _circleBtn(Icons.close_rounded, hc.error, onRemove),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hc.primary.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_rounded, size: 36, color: hc.primary),
          const SizedBox(height: 6),
          Text(
            'Tap to add an image',
            style: AppTypography.labelSmall.copyWith(
              color: hc.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: hc.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ─── Voice Text Field ───────────────────────────────────

class _VoiceTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final HCColor hc;
  final bool isListening;
  final bool speechAvailable;
  final VoidCallback onMicPressed;
  final VoidCallback onChanged;
  final String? Function(String?)? validator;
  final int maxLines;

  const _VoiceTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.hc,
    required this.isListening,
    required this.speechAvailable,
    required this.onMicPressed,
    required this.onChanged,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(label: label, icon: icon, hc: hc),
            const Spacer(),
            if (speechAvailable)
              _MicButton(
                isListening: isListening,
                hc: hc,
                onPressed: onMicPressed,
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
          decoration: InputDecoration(
            hintText: isListening ? 'Listening…' : hint,
            hintStyle: TextStyle(
              color: isListening ? hc.error : hc.textHint,
              fontStyle: isListening ? FontStyle.italic : FontStyle.normal,
            ),
            prefixIcon: Icon(icon, color: hc.primary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: hc.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.primary, width: 2),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          maxLines: maxLines,
          validator: validator,
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

// ─── Mic Button ─────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool isListening;
  final HCColor hc;
  final VoidCallback onPressed;

  const _MicButton({
    required this.isListening,
    required this.hc,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isListening
              ? hc.error.withValues(alpha: 0.15)
              : hc.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isListening ? hc.error : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 16,
              color: isListening ? hc.error : hc.primary,
            ),
            const SizedBox(width: 4),
            Text(
              isListening ? 'Stop' : 'Dictate',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isListening ? hc.error : hc.primary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Enhanced Preview Card ──────────────────────────────

class _EnhancedPreviewCard extends StatelessWidget {
  final String wordEn;
  final String wordFl;
  final FlashcardCategory category;
  final String? imagePath;

  const _EnhancedPreviewCard({
    required this.wordEn,
    required this.wordFl,
    required this.category,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && !kIsWeb;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            category.color,
            category.color.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          if (hasImage)
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Preview',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                if (!hasImage) ...[
                  Icon(category.icon, size: 44, color: Colors.white),
                  const SizedBox(height: 8),
                ],
                Text(
                  wordEn.isEmpty ? 'Your Word' : wordEn,
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wordFl.isEmpty ? 'Iyong Salita' : wordFl,
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
