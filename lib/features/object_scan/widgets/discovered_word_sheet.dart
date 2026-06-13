import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/fsl_fullscreen_player.dart';

/// Bottom sheet shown when a Word Hunt detection is tapped: the word in
/// English + Filipino with its meaning, plus one-tap bridges into the
/// existing learning tools (TTS, spelling game, flashcards, pronunciation
/// practice, FSL video). The word is read aloud automatically on open.
class DiscoveredWordSheet extends ConsumerStatefulWidget {
  final Flashcard card;
  final bool isNewDiscovery;
  final bool starAwarded;

  /// Speak the word once with TTS as soon as the sheet appears (the "reads
  /// the word aloud" step) — the manual 🔊 buttons stay available either way.
  /// Honored only when the app's `ttsEnabled` setting is on. Tests that don't
  /// wire up TTS/settings pass false to keep the sheet inert.
  final bool autoSpeak;

  const DiscoveredWordSheet({
    super.key,
    required this.card,
    this.isNewDiscovery = false,
    this.starAwarded = false,
    this.autoSpeak = true,
  });

  @override
  ConsumerState<DiscoveredWordSheet> createState() =>
      _DiscoveredWordSheetState();
}

class _DiscoveredWordSheetState extends ConsumerState<DiscoveredWordSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSpeak());
  }

  /// Reads the discovered word aloud once, right after the sheet lays out.
  /// Short-circuits on [DiscoveredWordSheet.autoSpeak] before touching any
  /// provider, so widget tests that don't set up TTS/settings stay green.
  void _autoSpeak() {
    if (!widget.autoSpeak || !mounted) return;
    if (!ref.read(settingsProvider).ttsEnabled) return;
    ref.read(ttsServiceProvider).speakEnglish(widget.card.wordEnglish);
  }

  /// Any learning action from a discovery counts as learning activity for
  /// the streak — same surgical pattern as the AI Tutor.
  void _recordActivity() {
    ref.read(progressProvider.notifier).recordDailyActivity();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = widget.card;
    final isNewDiscovery = widget.isNewDiscovery;
    final starAwarded = widget.starAwarded;
    final categoryIndex = card.category.index;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isNewDiscovery) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bannerWordHuntStart.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    starAwarded ? l10n.wordHuntNewWord : l10n.wordHuntGreatFind,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.bannerWordHuntEnd,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                FlashcardEmojis.forId(card.id),
                style: const TextStyle(fontSize: 64),
              ),
              Text(
                card.wordEnglish,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                card.wordFilipino,
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (card.definition != null) ...[
                const SizedBox(height: 10),
                Text(
                  '${l10n.wordHuntMeaning}: ${card.definition}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (card.exampleSentence != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${l10n.example}: ${card.exampleSentence}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SheetAction(
                      emoji: '🔊',
                      label: l10n.wordHuntSpeakEnglish,
                      onTap: () {
                        _recordActivity();
                        ref.read(ttsServiceProvider).speakEnglish(
                              card.exampleSentence == null
                                  ? card.wordEnglish
                                  : '${card.wordEnglish}. ${card.exampleSentence}',
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetAction(
                      emoji: '🗣️',
                      label: l10n.wordHuntSpeakFilipino,
                      onTap: () {
                        _recordActivity();
                        ref
                            .read(ttsServiceProvider)
                            .speakFilipino(card.wordFilipino);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SheetAction(
                      emoji: '🔤',
                      label: l10n.spellingBee,
                      onTap: () {
                        _recordActivity();
                        // Single-word round for this discovery. Words with
                        // spaces/hyphens can't be letter-scrambled (mirrors
                        // the game's own filter) — those fall back to a
                        // category round instead.
                        final spellable = !card.wordEnglish.contains(' ') &&
                            !card.wordEnglish.contains('-');
                        context.push(
                          '/games/spelling-bee?difficulty=easy&categories=$categoryIndex'
                          '${spellable ? '&word=${card.id}' : ''}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetAction(
                      emoji: '🃏',
                      label: l10n.wordHuntFlashcards,
                      onTap: () {
                        _recordActivity();
                        // Show just this word's card.
                        context.push(
                          '/learning-path-viewer/$categoryIndex?word=${card.id}',
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SheetAction(
                      emoji: '🎤',
                      label: l10n.pronunciationPractice,
                      onTap: () {
                        _recordActivity();
                        // Single listen-and-pick round for this discovery.
                        context.push(
                          '/games/pronunciation?difficulty=easy&categories=$categoryIndex'
                          '&word=${card.id}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _FslAction(card: card)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FSL button that only appears when the word actually has a sign video.
class _FslAction extends ConsumerWidget {
  final Flashcard card;
  const _FslAction({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<VideoSource?>(
      future: FslAssetsService.videoSourceFor(card),
      builder: (context, snapshot) {
        final source = snapshot.data;
        if (source == null) return const SizedBox.shrink();
        return _SheetAction(
          emoji: '🤟',
          label: l10n.fsl,
          onTap: () {
            ref.read(progressProvider.notifier).recordDailyActivity();
            openFslFullscreenPlayer(
              context,
              videoSource: source,
              wordEnglish: card.wordEnglish,
              wordFilipino: card.wordFilipino,
            );
          },
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bannerWordHuntStart.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          // PWD-friendly tap target: at least 56 dp tall with large type.
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
