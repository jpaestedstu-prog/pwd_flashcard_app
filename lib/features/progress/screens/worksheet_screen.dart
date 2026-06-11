import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/services/worksheet_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../widgets/app_back_button.dart';

/// Screen that lets users pick a worksheet type, category and difficulty,
/// then generates a printable/shareable PDF worksheet.
class WorksheetScreen extends ConsumerStatefulWidget {
  const WorksheetScreen({super.key});

  @override
  ConsumerState<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends ConsumerState<WorksheetScreen> {
  WorksheetType _selectedType = WorksheetType.wordTracing;
  FlashcardCategory _selectedCategory = FlashcardCategory.animals;
  GameDifficulty _selectedDifficulty = GameDifficulty.easy;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(fallbackRoute: '/progress'),
        title: Text(
          'Printable Worksheets',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────
            Text(
              'Create practice worksheets your students can print and use offline!',
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 24),

            // ─── Worksheet Type ────────────────
            _SectionTitle(label: 'Worksheet Type', hc: hc),
            const SizedBox(height: 12),
            ...WorksheetType.values.map((type) => _WorksheetTypeCard(
                  type: type,
                  isSelected: _selectedType == type,
                  hc: hc,
                  onTap: () => setState(() => _selectedType = type),
                )),
            const SizedBox(height: 24),

            // ─── Category ──────────────────────
            _SectionTitle(label: 'Category', hc: hc),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FlashcardCategory.values.map((cat) {
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: selected,
                  selectedColor: hc.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? hc.primary : hc.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ─── Difficulty ─────────────────────
            _SectionTitle(label: 'Difficulty', hc: hc),
            const SizedBox(height: 12),
            Row(
              children: GameDifficulty.values.map((diff) {
                final selected = diff == _selectedDifficulty;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _DifficultyButton(
                      difficulty: diff,
                      isSelected: selected,
                      hc: hc,
                      onTap: () =>
                          setState(() => _selectedDifficulty = diff),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ─── Generate Buttons ───────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _previewWorksheet,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.preview_rounded),
                    label: Text(_isGenerating ? 'Generating...' : 'Preview & Print'),
                    style: FilledButton.styleFrom(
                      backgroundColor: hc.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _shareWorksheet,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: hc.primary),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Future<void> _previewWorksheet() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await WorksheetService.generate(
        type: _selectedType,
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name:
            'FlashLearn_${_selectedType.label.replaceAll(' ', '_')}_${_selectedCategory.label}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareWorksheet() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await WorksheetService.generate(
        type: _selectedType,
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
      );
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'FlashLearn_${_selectedType.label.replaceAll(' ', '_')}_${_selectedCategory.label}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

// ─── Private Widgets ─────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.hc});
  final String label;
  final HCColor hc;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.titleSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: hc.textPrimary,
      ),
    );
  }
}

class _WorksheetTypeCard extends StatelessWidget {
  const _WorksheetTypeCard({
    required this.type,
    required this.isSelected,
    required this.hc,
    required this.onTap,
  });
  final WorksheetType type;
  final bool isSelected;
  final HCColor hc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? hc.primary.withValues(alpha: 0.08)
            : hc.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? hc.primary : hc.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? hc.primary : hc.textPrimary,
                        ),
                      ),
                      Text(
                        type.description,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: hc.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.difficulty,
    required this.isSelected,
    required this.hc,
    required this.onTap,
  });
  final GameDifficulty difficulty;
  final bool isSelected;
  final HCColor hc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wordCount = switch (difficulty) {
      GameDifficulty.easy => '6 words',
      GameDifficulty.medium => '8 words',
      GameDifficulty.hard => '12 words',
    };

    return Material(
      color: isSelected
          ? hc.primary.withValues(alpha: 0.1)
          : hc.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? hc.primary : hc.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                difficulty.label,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? hc.primary : hc.textPrimary,
                ),
              ),
              Text(
                wordCount,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
