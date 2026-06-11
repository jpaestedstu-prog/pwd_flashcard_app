import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../providers/mood_provider.dart';
import '../../../providers/app_providers.dart';
import '../models/mood_models.dart';

class MoodCheckInScreen extends ConsumerStatefulWidget {
  const MoodCheckInScreen({super.key});

  @override
  ConsumerState<MoodCheckInScreen> createState() => _MoodCheckInScreenState();
}

class _MoodCheckInScreenState extends ConsumerState<MoodCheckInScreen> {
  MoodType? _selectedMood;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    if (_selectedMood == null) return;
    setState(() => _saving = true);

    await ref.read(moodProvider.notifier).addMood(
          mood: _selectedMood!,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );

    ref.read(hapticServiceProvider).success();

    if (mounted) {
      AppSnackBar.success(context, message: 'Mood recorded! ${_selectedMood!.emoji}');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Paano ang Pakiramdam Mo?' : 'How Are You Feeling?'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Prompt text
              Text(
                isFilipino
                    ? 'Piliin ang emoji na nararamdaman mo ngayon'
                    : 'Tap the emoji that matches how you feel right now',
                style: AppTypography.bodyLarge.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 28),
              // Mood grid
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: MoodType.values.map((mood) {
                  final isSelected = _selectedMood == mood;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: '${mood.label} mood',
                    child: GestureDetector(
                      onTap: () {
                        ref.read(hapticServiceProvider).lightTap();
                        setState(() => _selectedMood = mood);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: context.responsiveTier<double>(
                          phone: 100,
                          tablet: 130,
                          large: 160,
                          xl: 180,
                          ultra: 200,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: context.responsiveTier<double>(
                            phone: 14,
                            tablet: 18,
                            large: 22,
                            xl: 26,
                          ),
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? mood.color.withValues(alpha: 0.2)
                              : hc.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? mood.color
                                : hc.border,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: mood.color.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: mood.color.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: mood.color.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Text(
                                mood.emoji,
                                style: TextStyle(
                                  fontSize: context.isTablet ? 44 : 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isFilipino ? mood.labelFilipino : mood.label,
                              style: AppTypography.labelMedium.copyWith(
                                color: isSelected
                                    ? mood.darkColor
                                    : hc.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(
                    begin: 0.05,
                    end: 0,
                  ),
              const SizedBox(height: 28),
              // Note field
              if (_selectedMood != null) ...[
                Semantics(
                  label: isFilipino
                      ? 'Opsyonal na tala tungkol sa pakiramdam mo'
                      : 'Optional note about how you feel',
                  child: TextField(
                    controller: _noteController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: isFilipino
                          ? 'Isulat kung bakit ganyan ang pakiramdam mo (opsyonal)...'
                          : 'Write why you feel this way (optional)...',
                      filled: true,
                      fillColor: hc.surface,
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
                        borderSide: BorderSide(
                          color: _selectedMood!.color,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 24),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Semantics(
                    button: true,
                    label: isFilipino ? 'I-save ang mood' : 'Save mood',
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveMood,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_selectedMood!.emoji,
                              style: const TextStyle(fontSize: 22)),
                      label: Text(
                        isFilipino ? 'I-save ang Mood' : 'Save My Mood',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMood!.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              ],
              const SizedBox(height: 16),
              // View history link
              TextButton.icon(
                onPressed: () => context.push('/mood-history'),
                icon: const Icon(Icons.history_rounded),
                label: Text(isFilipino ? 'Tingnan ang Kasaysayan' : 'View Mood History'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
