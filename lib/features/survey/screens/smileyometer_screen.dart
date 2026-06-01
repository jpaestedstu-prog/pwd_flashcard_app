import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../widgets/app_snack_bar.dart';
import '../../../providers/app_providers.dart';
import '../models/smileyometer_models.dart';
import '../services/smileyometer_service.dart';

/// Child-friendly Smileyometer feedback screen for learners.
///
/// Big tappable faces, minimal text — captures the learner's own experience
/// (reported descriptively, not as a usability score). See [SusSurveyScreen]
/// for the teacher-facing usability instrument.
class SmileyometerScreen extends ConsumerStatefulWidget {
  const SmileyometerScreen({super.key});

  @override
  ConsumerState<SmileyometerScreen> createState() => _SmileyometerScreenState();
}

class _SmileyometerScreenState extends ConsumerState<SmileyometerScreen> {
  late final List<int> _ratings =
      List.filled(SmileyometerQuestions.english.length, 0);
  bool _saving = false;

  bool get _allAnswered => _ratings.every((r) => r > 0);

  Future<void> _submit() async {
    if (!_allAnswered || _saving) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    setState(() => _saving = true);
    final result = SmileyometerService.createResult(
      profileId: profile.id,
      ratings: List.from(_ratings),
    );
    await SmileyometerService.saveResult(result);
    ref.read(hapticServiceProvider).success();

    if (mounted) {
      final isFilipino = ref.read(settingsProvider).locale == 'fil';
      AppSnackBar.success(
        context,
        message: isFilipino ? 'Salamat sa iyong feedback!' : 'Thanks for your feedback!',
      );
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final padding = context.pagePadding;
    final questions =
        isFilipino ? SmileyometerQuestions.filipino : SmileyometerQuestions.english;
    final faceLabels = isFilipino
        ? SmileyometerQuestions.faceLabelsFilipino
        : SmileyometerQuestions.faceLabelsEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Kumusta?' : 'How was it?'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFilipino
                    ? 'Pindutin ang mukha na pinakaangkop sa iyong nararamdaman.'
                    : 'Tap the face that matches how you feel.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...List.generate(questions.length, (q) {
                return _QuestionBlock(
                  question: questions[q],
                  faceLabels: faceLabels,
                  selected: _ratings[q],
                  onSelect: (value) {
                    ref.read(hapticServiceProvider).selectionClick();
                    setState(() => _ratings[q] = value);
                  },
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: 80 * q),
                    );
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _allAnswered && !_saving ? _submit : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isFilipino ? 'Tapos na!' : 'Done!'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final String question;
  final List<String> faceLabels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _QuestionBlock({
    required this.question,
    required this.faceLabels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: AppTypography.titleSmall
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(SmileyometerQuestions.faces.length, (i) {
                final value = i + 1;
                final isSelected = selected == value;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: faceLabels[i],
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelect(value),
                      child: AnimatedContainer(
                        duration: 150.ms,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              SmileyometerQuestions.faces[i],
                              style: TextStyle(fontSize: isSelected ? 44 : 38),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              faceLabels[i],
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                color: isSelected ? AppColors.primary : null,
                                fontWeight:
                                    isSelected ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
