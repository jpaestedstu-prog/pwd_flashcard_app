import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/word_of_day_models.dart';
import '../services/word_of_day_service.dart';
import '../../../widgets/flashcard_image.dart';

class WordOfDayScreen extends ConsumerStatefulWidget {
  const WordOfDayScreen({super.key});

  @override
  ConsumerState<WordOfDayScreen> createState() => _WordOfDayScreenState();
}

class _WordOfDayScreenState extends ConsumerState<WordOfDayScreen> {
  late WordOfDay _word;
  bool _flipped = false;
  bool _learned = false;

  @override
  void initState() {
    super.initState();
    _word = WordOfDayService.today();
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _learned = WordOfDayService.hasLearnedToday(profile.id);
    }
  }

  Future<void> _markLearned() async {
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    await WordOfDayService.markLearned(profile.id);
    ref.read(hapticServiceProvider).success();
    setState(() => _learned = true);
    if (mounted) {
      AppSnackBar.success(context, message: 'Word learned! ${_word.emoji}');
    }
  }

  void _speak(String text) {
    final settings = ref.read(settingsProvider);
    if (settings.ttsEnabled) {
      ref.read(ttsServiceProvider).speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final profile = ref.watch(profileProvider);
    final totalLearned = profile != null
        ? WordOfDayService.totalLearned(profile.id)
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Salita ng Araw' : 'Word of the Day'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // ─── Date Banner ──────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hc.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: hc.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(DateTime.now(), isFilipino),
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.primary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ─── Word Card ────────────────────────
              GestureDetector(
                onTap: () {
                  setState(() => _flipped = !_flipped);
                  ref.read(hapticServiceProvider).lightTap();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _flipped
                      ? _buildBackCard(hc, isFilipino)
                      : _buildFrontCard(hc, isFilipino),
                ),
              ).animate().scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),

              const SizedBox(height: 12),

              Text(
                isFilipino ? 'I-tap para i-flip' : 'Tap to flip',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // ─── Example Sentence ─────────────────
              if (_word.exampleSentence != null &&
                  _word.exampleSentence!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hc.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: hc.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 20,
                            color: hc.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFilipino ? 'Halimbawa' : 'Example',
                            style: AppTypography.labelMedium.copyWith(
                              color: hc.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _word.exampleSentence!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // ─── Actions ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: isFilipino ? 'Basahin nang malakas' : 'Read aloud',
                      child: OutlinedButton.icon(
                        onPressed: () => _speak(_word.wordEnglish),
                        icon: const Icon(Icons.volume_up_rounded),
                        label: Text(isFilipino ? 'Pakinggan' : 'Listen'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _learned
                          ? (isFilipino ? 'Natutunan na' : 'Already learned')
                          : (isFilipino
                                ? 'Markahan bilang natutunan'
                                : 'Mark as learned'),
                      child: FilledButton.icon(
                        onPressed: _learned ? null : _markLearned,
                        icon: Icon(
                          _learned
                              ? Icons.check_circle_rounded
                              : Icons.school_rounded,
                        ),
                        label: Text(
                          _learned
                              ? (isFilipino ? 'Natutunan na!' : 'Learned!')
                              : (isFilipino ? 'Natutunan Ko' : 'I Learned It'),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              const SizedBox(height: 32),

              // ─── Stats Row ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hc.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hc.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatTile(
                      emoji: '📚',
                      value: '$totalLearned',
                      label: isFilipino
                          ? 'Salitang Natutunan'
                          : 'Words Learned',
                      color: hc.success,
                    ),
                    Container(width: 1, height: 40, color: hc.border),
                    _StatTile(
                      emoji: _word.emoji,
                      value: _word.category,
                      label: isFilipino ? 'Kategorya' : 'Category',
                      color: hc.primary,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(HCColor hc, bool isFilipino) {
    return Card(
      key: const ValueKey('front'),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hc.primary.withValues(alpha: 0.15),
              hc.secondary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlashcardPictureById(
              cardId: _word.cardId,
              fallback: _word.emoji,
              extent: 74,
            ),
            const SizedBox(height: 16),
            Text(
              _word.wordEnglish,
              style: AppTypography.headlineLarge.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: hc.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'English',
                style: AppTypography.labelSmall.copyWith(color: hc.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(HCColor hc, bool isFilipino) {
    return Card(
      key: const ValueKey('back'),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hc.accent.withValues(alpha: 0.15),
              hc.warning.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlashcardPictureById(
              cardId: _word.cardId,
              fallback: _word.emoji,
              extent: 74,
            ),
            const SizedBox(height: 16),
            Text(
              _word.wordFilipino,
              style: AppTypography.headlineLarge.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: hc.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Filipino',
                style: AppTypography.labelSmall.copyWith(color: hc.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d, bool isFilipino) {
    final months = isFilipino
        ? [
            'Ene',
            'Peb',
            'Mar',
            'Abr',
            'May',
            'Hun',
            'Hul',
            'Ago',
            'Set',
            'Okt',
            'Nob',
            'Dis',
          ]
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
