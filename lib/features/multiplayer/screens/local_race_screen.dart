import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../games/widgets/pause_overlay.dart';
import '../models/multiplayer_models.dart';
import '../widgets/memory_race_player.dart';
import '../widgets/quiz_race_player.dart';
import '../widgets/race_result_view.dart';
import '../widgets/scramble_race_player.dart';

/// Same-device "pass-and-play" race. Two players share one tablet: Player 1
/// plays the whole challenge, then Player 2 plays the **identical** content,
/// then the head-to-head result is shown. No internet required, and — like the
/// rest of "Play Together" — no stars/XP/streak are awarded.
class LocalRaceScreen extends ConsumerStatefulWidget {
  final MpGameMode mode;
  const LocalRaceScreen({super.key, required this.mode});

  @override
  ConsumerState<LocalRaceScreen> createState() => _LocalRaceScreenState();
}

enum _Phase { setup, intro, playing, result }

class _LocalRaceScreenState extends ConsumerState<LocalRaceScreen>
    with WidgetsBindingObserver {
  final _p1 = TextEditingController(text: 'Player 1');
  final _p2 = TextEditingController(text: 'Player 2');

  _Phase _phase = _Phase.setup;
  int _currentPlayer = 1;
  int _p1Score = 0;
  int _p2Score = 0;
  int _matchSeq = 0;
  bool _paused = false;

  List<MpQuestion> _questions = const [];
  List<MemoryCardSpec> _layout = const [];
  List<MpScrambleItem> _scramble = const [];

  static const int _quizRounds = 6;
  static const int _memoryPairs = 6;
  static const int _scrambleCount = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-pause when the app leaves the foreground mid-game.
    if (state != AppLifecycleState.resumed &&
        _phase == _Phase.playing &&
        !_paused) {
      setState(() => _paused = true);
    }
  }

  bool _buildContent() {
    final pool = ref.read(allFlashcardsProvider);
    final rng = Random();
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    switch (widget.mode) {
      case MpGameMode.quizRace:
        if (pool.length < 4) return false;
        _questions = buildQuizQuestions(pool, _quizRounds, rng);
        _layout = const [];
        _scramble = const [];
      case MpGameMode.pictureRace:
        if (pool.length < 4) return false;
        _questions = buildPictureQuestions(pool, _quizRounds, rng,
            emojiFor: FlashcardEmojis.forId);
        _layout = const [];
        _scramble = const [];
      case MpGameMode.trueFalseRace:
        if (pool.length < 2) return false;
        _questions = buildTrueFalseQuestions(pool, _quizRounds, rng,
            yesLabel: isFilipino ? 'Tama' : 'True',
            noLabel: isFilipino ? 'Mali' : 'False');
        _layout = const [];
        _scramble = const [];
      case MpGameMode.memoryRace:
        if (pool.length < _memoryPairs) return false;
        _layout = buildMemoryLayout(pool, _memoryPairs, rng,
            emojiFor: FlashcardEmojis.forId);
        _questions = const [];
        _scramble = const [];
      case MpGameMode.scrambleRace:
        final items = buildScrambleItems(pool, _scrambleCount, rng,
            emojiFor: FlashcardEmojis.forId);
        if (items.isEmpty) return false;
        _scramble = items;
        _questions = const [];
        _layout = const [];
    }
    return true;
  }

  void _start() {
    if (!_buildContent()) {
      AppSnackBar.warning(context,
          message: 'Not enough words to play yet — add a few flashcards first!');
      return;
    }
    setState(() {
      _matchSeq++;
      _currentPlayer = 1;
      _p1Score = 0;
      _p2Score = 0;
      _phase = _Phase.intro;
    });
  }

  void _onFinished(int score) {
    if (_currentPlayer == 1) {
      setState(() {
        _p1Score = score;
        _currentPlayer = 2;
        _phase = _Phase.intro;
      });
    } else {
      setState(() {
        _p2Score = score;
        _phase = _Phase.result;
      });
    }
  }

  void _rematch() {
    if (!_buildContent()) return;
    setState(() {
      _matchSeq++;
      _currentPlayer = 1;
      _p1Score = 0;
      _p2Score = 0;
      _phase = _Phase.intro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final title = '${widget.mode.emoji} '
        '${isFilipino ? widget.mode.labelFilipino : widget.mode.label}';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.transparent,
            elevation: 0,
            // During play the top-left control is the Pause button (its menu is
            // the way out). Outside play the default back arrow handles leaving.
            leading: _phase == _Phase.playing
                ? IconButton(
                    tooltip: isFilipino ? 'I-pause' : 'Pause',
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    onPressed: () => setState(() => _paused = true),
                  )
                : null,
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_phase) {
                _Phase.setup => _buildSetup(isFilipino),
                _Phase.intro => _buildIntro(isFilipino),
                _Phase.playing => _buildPlaying(isFilipino),
                _Phase.result => RaceResultView(
                    key: const ValueKey('result'),
                    player1Name:
                        _p1.text.trim().isEmpty ? 'Player 1' : _p1.text,
                    player1Score: _p1Score,
                    player2Name:
                        _p2.text.trim().isEmpty ? 'Player 2' : _p2.text,
                    player2Score: _p2Score,
                    mode: widget.mode,
                    isFilipino: isFilipino,
                    onRematch: _rematch,
                    onHome: () => Navigator.of(context).maybePop(),
                  ),
              },
            ),
          ),
        ),
        if (_paused && _phase == _Phase.playing)
          PauseOverlay(
            onResume: () => setState(() => _paused = false),
            onRestart: () {
              setState(() => _paused = false);
              _start();
            },
            onQuit: () async => Navigator.of(context).maybePop(),
          ),
      ],
    );
  }

  Widget _buildSetup(bool isFilipino) {
    return SingleChildScrollView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.mode.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            isFilipino ? 'Sino ang maglalaro?' : "Who's playing?",
            style: AppTypography.titleLarge
                .copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isFilipino
                ? 'Palitan ang tablet pagkatapos ng unang manlalaro.'
                : 'Pass the tablet after the first player finishes.',
            style: AppTypography.bodyMedium
                .copyWith(color: HCColor.of(context).textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _nameField(_p1, isFilipino ? 'Manlalaro 1' : 'Player 1',
              AppColors.info, '🔵'),
          const SizedBox(height: 12),
          _nameField(_p2, isFilipino ? 'Manlalaro 2' : 'Player 2',
              AppColors.error, '🔴'),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: Text(isFilipino ? 'Simulan!' : 'Start!'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField(
      TextEditingController c, String label, Color color, String emoji) {
    return TextField(
      controller: c,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        labelText: label,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  Widget _buildIntro(bool isFilipino) {
    final isP1 = _currentPlayer == 1;
    final name = isP1
        ? (_p1.text.trim().isEmpty ? 'Player 1' : _p1.text)
        : (_p2.text.trim().isEmpty ? 'Player 2' : _p2.text);
    final color = isP1 ? AppColors.info : AppColors.error;
    final emoji = isP1 ? '🔵' : '🔴';

    return GestureDetector(
      key: ValueKey('intro_${_currentPlayer}_$_matchSeq'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _phase = _Phase.playing),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isFilipino ? 'Handa ka na, $name?' : 'Ready, $name?',
                  style: AppTypography.displaySmall
                      .copyWith(fontWeight: FontWeight.w900, color: color),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isFilipino ? 'Pindutin para magsimula' : 'Tap to start',
                  style: AppTypography.titleMedium
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaying(bool isFilipino) {
    final color = _currentPlayer == 1 ? AppColors.info : AppColors.error;
    final key = ValueKey('play_${_currentPlayer}_$_matchSeq');
    if (widget.mode == MpGameMode.memoryRace) {
      return MemoryRacePlayer(
        key: key,
        layout: _layout,
        accentColor: color,
        isFilipino: isFilipino,
        isPaused: _paused,
        onFinished: _onFinished,
      );
    }
    if (widget.mode == MpGameMode.scrambleRace) {
      return ScrambleRacePlayer(
        key: key,
        items: _scramble,
        accentColor: color,
        isFilipino: isFilipino,
        isPaused: _paused,
        onFinished: _onFinished,
      );
    }
    return QuizRacePlayer(
      key: key,
      questions: _questions,
      accentColor: color,
      isFilipino: isFilipino,
      isPaused: _paused,
      onFinished: _onFinished,
    );
  }
}
