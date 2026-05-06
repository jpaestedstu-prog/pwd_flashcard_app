import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../data/local/seed_stories.dart' show SeedStories, Story;
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';

/// Paginated story reader with TTS and vocabulary highlights.
class StoryReaderScreen extends ConsumerStatefulWidget {
  final String storyId;
  const StoryReaderScreen({super.key, required this.storyId});

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  Story? _story;
  int _currentSentence = 0;
  bool _showFilipino = false;
  bool _isSpeaking = false;
  TtsService? _ttsRef;

  @override
  void initState() {
    super.initState();
    _story = SeedStories.all.where((s) => s.id == widget.storyId).firstOrNull;
  }

  @override
  void dispose() {
    _ttsRef?.stop();
    super.dispose();
  }

  bool get _isLastSentence {
    final story = _story;
    if (story == null) return true;
    return _currentSentence >= story.sentencesEn.length - 1;
  }

  void _speakCurrent() {
    final story = _story;
    if (story == null) return;

    final tts = ref.read(ttsServiceProvider);
    _ttsRef = tts; // cache for safe dispose
    final settings = ref.read(settingsProvider);
    if (!settings.ttsEnabled) return;

    setState(() => _isSpeaking = true);
    final text = _showFilipino
        ? story.sentencesFil[_currentSentence]
        : story.sentencesEn[_currentSentence];

    if (_showFilipino) {
      tts.speakFilipino(text);
    } else {
      tts.speakEnglish(text);
    }
    // Reset speaking state when TTS finishes
    tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _nextSentence() {
    if (_isLastSentence) return;
    setState(() => _currentSentence++);
    _speakCurrent();
  }

  void _prevSentence() {
    if (_currentSentence <= 0) return;
    setState(() => _currentSentence--);
    _speakCurrent();
  }

  void _goToQuiz() {
    final story = _story;
    if (story == null) return;
    context.push('/stories/quiz/${story.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_story == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.storyNotFound)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: HCColor.of(context).textSecondary),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.storyNotFoundMsg, style: AppTypography.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(AppLocalizations.of(context)!.goBack),
              ),
            ],
          ),
        ),
      );
    }
    final hc = HCColor.of(context);
    final sentenceEn = _story!.sentencesEn[_currentSentence];
    final sentenceFil = _story!.sentencesFil[_currentSentence];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
        title: Text(_story!.titleEn),
        actions: [
          // Language toggle
          Semantics(
            label: _showFilipino ? 'Switch to English' : 'Switch to Filipino',
            child: TextButton(
              onPressed: () => setState(() => _showFilipino = !_showFilipino),
              child: Text(
                _showFilipino ? '🇵🇭 FIL' : '🇺🇸 EN',
                style: AppTypography.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Progress indicator
              Semantics(
                label:
                    'Sentence ${_currentSentence + 1} of ${_story!.sentencesEn.length}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: _story!.category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            (_currentSentence + 1) / _story!.sentencesEn.length,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _story!.category.color,
                                _story!.category.color.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: _story!.category.color.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentSentence + 1} / ${_story!.sentencesEn.length}',
                style: AppTypography.labelSmall
                    .copyWith(color: hc.textSecondary),
              ),

              const Spacer(),

              // ─── Story Card ──────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      hc.surface,
                      _story!.category.color.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: hc.hc
                      ? Border.all(color: AppColors.hcPrimary, width: 2)
                      : Border.all(
                          color: _story!.category.color.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: _story!.category.color.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Emoji
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _story!.category.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _story!.category.color.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(_story!.emoji, style: const TextStyle(fontSize: 48)),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 24),
                    // Sentence
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _showFilipino ? sentenceFil : sentenceEn,
                        key: ValueKey('$_currentSentence-$_showFilipino'),
                        style: AppTypography.headlineSmall.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_showFilipino) ...[
                      const SizedBox(height: 12),
                      Text(
                        sentenceEn,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    // TTS button
                    Semantics(
                      label: 'Read aloud',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _story!.category.color.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: IconButton.filled(
                          onPressed: _speakCurrent,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isSpeaking
                                ? const Icon(Icons.volume_up_rounded,
                                    key: ValueKey('speaking'))
                                : const Icon(Icons.volume_up_outlined,
                                    key: ValueKey('silent')),
                          ),
                          iconSize: 32,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                _story!.category.color.withValues(alpha: 0.15),
                            foregroundColor: _story!.category.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ─── Navigation Controls ─────────────
              Row(
                children: [
                  // Previous
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentSentence > 0 ? _prevSentence : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(AppLocalizations.of(context)!.back),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Next or Quiz
                  Expanded(
                    child: _isLastSentence
                        ? ElevatedButton.icon(
                            onPressed: _goToQuiz,
                            icon:
                                const Icon(Icons.quiz_rounded),
                            label: Text(AppLocalizations.of(context)!.takeQuiz),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _story!.category.color,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _nextSentence,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(AppLocalizations.of(context)!.next),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
