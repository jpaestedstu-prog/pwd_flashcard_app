import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/tts_service.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../games/widgets/pause_overlay.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
import '../models/multiplayer_models.dart';
import '../models/race_presentation.dart';
import '../widgets/race_cursor.dart';
import '../widgets/memory_race_player.dart';
import '../widgets/quiz_race_player.dart';
import '../widgets/race_result_view.dart';
import '../widgets/race_sign_launcher.dart';
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

  /// An FSL clip is on screen. Suspends the round's timers exactly like a
  /// pause — but *without* the pause menu, which would stack behind the
  /// video sheet.
  bool _mediaOpen = false;

  /// Hands-free highlight, shared with whichever player widget is on screen.
  /// Owned here because only one gaze camera may run app-wide, so the single
  /// [GazeScope] has to sit above the phase switcher.
  final RaceCursor _cursor = RaceCursor();

  /// Resolved on mount, not in `dispose` — `ref` is unusable once the element
  /// is unmounted, and silencing a half-read prompt is exactly a dispose-time
  /// job.
  late final TtsService _tts;

  List<MpQuestion> _questions = const [];
  List<MemoryCardSpec> _layout = const [];
  List<MpScrambleItem> _scramble = const [];

  /// Pass-and-play runs on one tablet, so both racers share the owning
  /// learner's policy. That is fair by construction: identical content,
  /// identical pacing, identical scoring rule for player 1 and player 2.
  RacePresentation get _policy => ref.read(racePresentationProvider);

  /// Show the sign for a round's word, freezing the round while it plays so a
  /// timed advance can't move on behind the video.
  Future<void> _showSign(String cardId) async {
    if (_mediaOpen) return;
    setState(() => _mediaOpen = true);
    try {
      await showRaceSign(context, ref, cardId);
    } finally {
      if (mounted) setState(() => _mediaOpen = false);
    }
  }

  /// Narrate through the learner's TTS voice in their reading language.
  void _speak(String text) {
    final tts = ref.read(ttsServiceProvider);
    // ignore: discarded_futures
    ref.read(settingsProvider).locale == 'fil'
        ? tts.speakFilipino(text)
        : tts.speakEnglish(text);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = ref.read(ttsServiceProvider);
    // Snapshot on mount, exactly like GazeScope does with its own settings —
    // a ring that appeared mid-match would be more confusing than helpful.
    _cursor.highlight = ref.read(gazeSettingsProvider).enabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't let a half-read prompt follow the learner off the screen.
    // ignore: discarded_futures
    _tts.stop();
    _cursor.dispose();
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  // ─── Hands-free control ───────────────────────────────
  // One GazeScope for the whole screen (only one camera may run app-wide), so
  // its actions follow the phase: Start on the way in, move/choose during the
  // race, and the two result buttons on the way out — a motor learner can
  // play a whole match end to end without a tap.

  List<GazeAction> _gazeActions() {
    switch (_phase) {
      case _Phase.setup:
        return [
          GazeAction(
            zone: GazeZone.down,
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            color: AppColors.success,
            onSelect: _start,
          ),
        ];
      case _Phase.intro:
        return [
          GazeAction(
            zone: GazeZone.down,
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            color: AppColors.success,
            onSelect: _beginTurn,
          ),
        ];
      case _Phase.playing:
        final live = !_paused && !_mediaOpen;
        return [
          GazeAction(
            zone: GazeZone.left,
            label: 'Prev',
            icon: Icons.chevron_left_rounded,
            color: AppColors.secondary,
            enabled: live && _cursor.canMove,
            onSelect: () => _cursor.move(-1),
          ),
          GazeAction(
            zone: GazeZone.right,
            label: 'Next',
            icon: Icons.chevron_right_rounded,
            color: AppColors.secondary,
            enabled: live && _cursor.canMove,
            onSelect: () => _cursor.move(1),
          ),
          GazeAction(
            zone: GazeZone.down,
            label: 'Choose',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            enabled: live && _cursor.canChoose,
            onSelect: _cursor.choose,
          ),
        ];
      case _Phase.result:
        return [
          GazeAction(
            zone: GazeZone.left,
            label: 'Done',
            icon: Icons.home_rounded,
            color: AppColors.secondary,
            onSelect: () => Navigator.of(context).maybePop(),
          ),
          GazeAction(
            zone: GazeZone.right,
            label: 'Rematch',
            icon: Icons.replay_rounded,
            color: AppColors.success,
            onSelect: _rematch,
          ),
        ];
    }
  }

  /// A blink commits whatever the current phase's main action is.
  void _onBlink() {
    switch (_phase) {
      case _Phase.setup:
        _start();
      case _Phase.intro:
        _beginTurn();
      case _Phase.playing:
        if (!_paused && !_mediaOpen) _cursor.choose();
      case _Phase.result:
        _rematch();
    }
  }

  void _beginTurn() => setState(() => _phase = _Phase.playing);

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
    final policy = _policy;
    final quizRounds = policy.rounds;
    final memoryPairs = policy.memoryPairs;
    switch (widget.mode) {
      case MpGameMode.quizRace:
        if (pool.length < 4) return false;
        _questions = buildQuizQuestions(pool, quizRounds, rng);
        _layout = const [];
        _scramble = const [];
      case MpGameMode.pictureRace:
        if (pool.length < 4) return false;
        _questions = buildPictureQuestions(pool, quizRounds, rng,
            emojiFor: FlashcardEmojis.forId);
        _layout = const [];
        _scramble = const [];
      case MpGameMode.trueFalseRace:
        if (pool.length < 2) return false;
        _questions = buildTrueFalseQuestions(pool, quizRounds, rng,
            yesLabel: isFilipino ? 'Tama' : 'True',
            noLabel: isFilipino ? 'Mali' : 'False');
        _layout = const [];
        _scramble = const [];
      case MpGameMode.memoryRace:
        if (pool.length < memoryPairs) return false;
        _layout = buildMemoryLayout(pool, memoryPairs, rng,
            emojiFor: FlashcardEmojis.forId);
        _questions = const [];
        _scramble = const [];
      case MpGameMode.scrambleRace:
        final items = buildScrambleItems(pool, policy.scrambleCount, rng,
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
    _announceTurn();
  }

  void _onFinished(int score) {
    if (_currentPlayer == 1) {
      setState(() {
        _p1Score = score;
        _currentPlayer = 2;
        _phase = _Phase.intro;
      });
      _announceTurn();
    } else {
      setState(() {
        _p2Score = score;
        _phase = _Phase.result;
      });
      _announceResult();
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
    _announceTurn();
  }

  /// Pass-and-play hands the tablet between two people. A learner who can't
  /// read the screen has no other way to know the turn just changed to them.
  void _announceTurn() {
    if (!_policy.speakPrompts) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    final name = _nameFor(_currentPlayer);
    _speak(isFilipino ? 'Handa ka na, $name?' : 'Ready, $name?');
  }

  void _announceResult() {
    if (!_policy.speakPrompts) return;
    final isFilipino = ref.read(settingsProvider).locale == 'fil';
    final outcome = computeOutcome(_p1Score, _p2Score);
    if (outcome == MpOutcome.draw) {
      _speak(isFilipino ? 'Tabla!' : "It's a draw!");
      return;
    }
    final winner = _nameFor(outcome == MpOutcome.player1 ? 1 : 2);
    _speak(isFilipino ? '$winner ang panalo!' : '$winner wins!');
  }

  String _nameFor(int player) {
    final c = player == 1 ? _p1 : _p2;
    final fallback = player == 1 ? 'Player 1' : 'Player 2';
    return c.text.trim().isEmpty ? fallback : c.text;
  }

  @override
  Widget build(BuildContext context) {
    final isFilipino = ref.watch(settingsProvider).locale == 'fil';
    final title = '${widget.mode.emoji} '
        '${isFilipino ? widget.mode.labelFilipino : widget.mode.label}';

    // Rebuilt on every cursor move so the scope's actions (and the highlight
    // ring inside the player) stay in step with where the learner is looking.
    return ListenableBuilder(
      listenable: _cursor,
      builder: (context, _) => GazeScope(
        actions: _gazeActions(),
        onBlink: _onBlink,
        child: _body(isFilipino, title),
      ),
    );
  }

  Widget _body(bool isFilipino, String title) {
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
                    player1Name: _nameFor(1),
                    player1Score: _p1Score,
                    player2Name: _nameFor(2),
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
    final name = _nameFor(_currentPlayer);
    final color = isP1 ? AppColors.info : AppColors.error;
    final emoji = isP1 ? '🔵' : '🔴';
    final title = isFilipino ? 'Handa ka na, $name?' : 'Ready, $name?';

    return GestureDetector(
      key: ValueKey('intro_${_currentPlayer}_$_matchSeq'),
      behavior: HitTestBehavior.opaque,
      onTap: _beginTurn,
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
                  title,
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
    final policy = _policy;
    // A clip on screen freezes the round exactly like a pause does.
    final frozen = _paused || _mediaOpen;
    if (widget.mode == MpGameMode.memoryRace) {
      return MemoryRacePlayer(
        key: key,
        layout: _layout,
        accentColor: color,
        isFilipino: isFilipino,
        isPaused: frozen,
        presentation: policy,
        onShowSign: _showSign,
        cursor: _cursor,
        onFinished: _onFinished,
      );
    }
    if (widget.mode == MpGameMode.scrambleRace) {
      return ScrambleRacePlayer(
        key: key,
        items: _scramble,
        accentColor: color,
        isFilipino: isFilipino,
        isPaused: frozen,
        presentation: policy,
        speak: _speak,
        onShowSign: _showSign,
        cursor: _cursor,
        onFinished: _onFinished,
      );
    }
    return QuizRacePlayer(
      key: key,
      questions: _questions,
      accentColor: color,
      isFilipino: isFilipino,
      isPaused: frozen,
      presentation: policy,
      speak: _speak,
      onShowSign: _showSign,
      cursor: _cursor,
      onFinished: _onFinished,
    );
  }
}
