import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/stt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/sign_interpreter_models.dart';
import '../services/sign_gloss_service.dart';
import '../services/sign_usage_log_service.dart';
import '../widgets/sentence_sign_player.dart';

/// Speech→Sign interpreter: speak (or type) a sentence and the app plays the
/// matching FSL sign videos in order, with captions. Built for the hearing
/// side of the conversation — a parent or teacher talks, the learner watches
/// the signs.
class SignInterpreterScreen extends ConsumerStatefulWidget {
  const SignInterpreterScreen({super.key});

  @override
  ConsumerState<SignInterpreterScreen> createState() =>
      _SignInterpreterScreenState();
}

class _SignInterpreterScreenState extends ConsumerState<SignInterpreterScreen> {
  final TextEditingController _textController = TextEditingController();

  String _locale = 'en-US';
  bool _listening = false;
  bool _handledFinal = false;
  String _transcript = '';
  DateTime? _sessionStart;
  List<SignPlayItem>? _items;

  @override
  void dispose() {
    _textController.dispose();
    ref.read(sttServiceProvider).cancel();
    super.dispose();
  }

  // ─── Input handling ───────────────────────────────────

  Future<void> _toggleMic(SignGlossService gloss) async {
    final stt = ref.read(sttServiceProvider);
    if (_listening) {
      await stt.stopListening();
      if (mounted && !_handledFinal && _transcript.trim().isNotEmpty) {
        _handleTranscript(gloss, _transcript, source: 'mic');
      }
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await stt.init();
    if (!available) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message: 'Speech recognition is not available on this device.',
        );
      }
      return;
    }

    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _listening = true;
      _handledFinal = false;
      _transcript = '';
      _items = null;
      _sessionStart = DateTime.now();
    });

    await stt.startListening(
      locale: _locale,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
        if (isFinal && !_handledFinal && text.trim().isNotEmpty) {
          setState(() => _listening = false);
          _handleTranscript(gloss, text, source: 'mic');
        }
      },
    );
  }

  void _submitTyped(SignGlossService gloss) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _transcript = text);
    _sessionStart ??= DateTime.now();
    _handleTranscript(gloss, text, source: 'typed');
  }

  void _handleTranscript(
    SignGlossService gloss,
    String text, {
    required String source,
  }) {
    _handledFinal = true;
    final items = gloss.glossify(text);
    setState(() => _items = items);

    final profile = ref.read(profileProvider);
    if (profile != null) {
      final start = _sessionStart;
      final durationMs =
          start != null ? DateTime.now().difference(start).inMilliseconds : 0;
      SignUsageLogService.logEvent(
        profile.id,
        SignUsageEvent(
          timestamp: DateTime.now(),
          locale: _locale,
          source: source,
          tokenCount: items.length,
          matchedCount: items.where((i) => i.isMatched).length,
          unmatchedWords: items
              .where((i) => !i.isMatched)
              .map((i) => i.word)
              .toList(),
          durationMs: durationMs,
        ),
      );
    }
    _sessionStart = null;
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final glossAsync = ref.watch(signGlossServiceProvider);
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Salita → Senyas' : 'Speech to Sign'),
      ),
      body: SafeArea(
        child: glossAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              'Could not load the sign vocabulary.',
              style: AppTypography.bodyLarge.copyWith(color: hc.textSecondary),
            ),
          ),
          data: (gloss) => SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Spoken language toggle ────────────
                Center(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en-US', label: Text('English')),
                      ButtonSegment(value: 'fil-PH', label: Text('Filipino')),
                    ],
                    selected: {_locale},
                    onSelectionChanged: (selection) =>
                        setState(() => _locale = selection.first),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── Transcript + mic card ─────────────
                _buildMicCard(gloss, hc),
                const SizedBox(height: 12),

                // ─── Typed input fallback ──────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitTyped(gloss),
                        decoration: InputDecoration(
                          hintText: isFilipino
                              ? 'O i-type ang pangungusap…'
                              : 'Or type a sentence…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Show signs for the typed sentence',
                      child: IconButton.filled(
                        onPressed: () => _submitTyped(gloss),
                        icon: const Icon(Icons.sign_language_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Result ────────────────────────────
                if (_items != null) _buildResult(hc) else _buildHint(hc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicCard(SignGlossService gloss, HCColor hc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _listening
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.5),
          width: _listening ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            _transcript.isEmpty
                ? (_listening ? 'Listening…' : 'Tap the mic and speak')
                : _transcript,
            style: AppTypography.titleMedium.copyWith(
              color: _transcript.isEmpty ? hc.textSecondary : hc.textPrimary,
              fontStyle:
                  _transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: _listening ? 'Stop listening' : 'Start listening',
            child: GestureDetector(
              onTap: () => _toggleMic(gloss),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _listening
                        ? [AppColors.error, AppColors.warning]
                        : [AppColors.primary, AppColors.primaryLight],
                  ),
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              )
                  .animate(
                    target: _listening ? 1 : 0,
                    onComplete: (c) {
                      if (_listening) c.repeat(reverse: true);
                    },
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 600.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(HCColor hc) {
    final items = _items!;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'No sign words found in that sentence — try simpler words like '
          '"dog", "eat", or "red".',
          style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final unmatched =
        items.where((i) => !i.isMatched).map((i) => i.word).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SentenceSignPlayer(items: items),
        if (unmatched.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'No sign yet for: ${unmatched.join(', ')}',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildHint(HCColor hc) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const Text('🗣️ → 🤟', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Speak or type a sentence and watch it in sign language.\n'
            'Works best with vocabulary words — animals, food, colors, '
            'numbers, feelings…',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
