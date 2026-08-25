import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_dialogs.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/flashcard_image.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';
// The hands-free cursor and the FSL clip launcher both live under
// `multiplayer/` because the races needed them first. Neither is race-specific
// — RaceCursor is a bare ChangeNotifier and showRaceSign is the app's single
// FSL resolver — and duplicating them here would let Peer Collab's signing path
// drift away from Cards, Stories and Play Together, which is exactly what this
// rewrite is undoing.
import '../../multiplayer/widgets/race_cursor.dart';
import '../../multiplayer/widgets/race_sign_launcher.dart';
import '../models/collab_models.dart';
import '../models/collab_presentation.dart';
import '../services/collab_session_store.dart';

const _uuid = Uuid();

/// Peer Collab: two children, one tablet, working *together*.
///
/// The cooperative counterpart to Play Together's race. Every round has a real
/// flashcard behind it — its picture, its FSL clip, its word — answers are
/// checked, roles rotate, and every activity can be played entirely by tapping,
/// so a gaze or switch learner can take a full turn. See [CollabPresentation]
/// for how the surface adapts per accessibility category, and [CollabSession]
/// for the rules themselves, which live in the model so they can be tested
/// without a widget.
class PeerCollaborationScreen extends ConsumerStatefulWidget {
  const PeerCollaborationScreen({super.key});

  @override
  ConsumerState<PeerCollaborationScreen> createState() =>
      _PeerCollaborationScreenState();
}

class _PeerCollaborationScreenState
    extends ConsumerState<PeerCollaborationScreen>
    with WidgetsBindingObserver {
  CollabSession? _session;

  final _inputController = TextEditingController();
  // Owned by a controller rather than an `onChanged` field: returning to the
  // picker rebuilds an empty TextField, so a plain field kept a name the user
  // could no longer see and silently started the next game with it.
  final _player2Controller = TextEditingController();

  /// Hands-free cursor over whatever the current turn's tap targets are. Lives
  /// on the screen because only one `GazeScope` (and one camera) may run.
  final RaceCursor _cursor = RaceCursor();

  late final TtsService _tts;

  /// An unfinished session this pair can carry on with, read once on mount.
  CollabResumeSnapshot? _resume;

  /// The tap targets for the turn in play. Recomputed only when the session
  /// changes, never in `build` — letter choices are shuffled, and reshuffling
  /// them on every repaint would move the buttons under the learner's finger.
  List<String> _choices = const [];

  /// The last checked turn's outcome, held just long enough to show a tick or
  /// a cross. Null for open-ended turns and clues.
  bool? _lastAnswerCorrect;

  /// An FSL sheet or the leave dialog is up, so the gaze scope should stand
  /// down.
  bool _mediaOpen = false;

  String get _player2Name => _player2Controller.text.trim();

  CollabPresentation get _p => ref.read(collabPresentationProvider);

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  /// Which word of a bilingual card to put in front of the learner. Read from
  /// `Localizations` rather than settings so it always matches the strings
  /// around it.
  bool get _isFilipino => Localizations.localeOf(context).languageCode == 'fil';

  String? get _profileId => ref.read(profileProvider)?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = ref.read(ttsServiceProvider);
    // Snapshot on mount, exactly like GazeScope does with its own settings — a
    // ring that appeared mid-session would confuse more than it helps.
    _cursor.highlight = ref.read(gazeSettingsProvider).enabled;
    _resume = CollabSessionStore.read(_profileId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't let a half-read prompt follow the learner off the screen.
    // ignore: discarded_futures
    _tts.stop();
    _cursor.dispose();
    _inputController.dispose();
    _player2Controller.dispose();
    super.dispose();
  }

  /// Pressing Home is how a young learner actually leaves, so save the place
  /// then — but deliberately **not** on `inactive`: a permission sheet or the
  /// app switcher passing over the screen is not leaving. Same rule as
  /// `GamePauseMixin.onBackgrounded`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveSession();
    }
  }

  // ─── Session lifecycle ────────────────────────────────

  void _saveSession() {
    final session = _session;
    if (session == null) return;
    CollabSessionStore.save(profileId: _profileId, session: session);
  }

  void _startSession(CollabActivityType activity, String player1Name) {
    if (_player2Name.isEmpty) {
      AppSnackBar.warning(context, message: _l10n.collabEnterPlayer2Name);
      return;
    }

    final presentation = _p;
    final rounds = _buildRounds(activity, presentation);
    if (rounds.isEmpty) {
      AppSnackBar.warning(context, message: _l10n.collabNoWords);
      return;
    }

    // ignore: discarded_futures
    ref.read(hapticServiceProvider).mediumTap();
    _applySession(
      CollabSession(
        id: _uuid.v4(),
        activityType: activity,
        player1Name: player1Name,
        player2Name: _player2Name,
        rounds: rounds,
      ),
    );
  }

  /// Draw one card per round from the learner's real deck — this is what
  /// replaced the hardcoded twenty-word English list, and it is why a round can
  /// show a picture and a sign at all.
  List<CollabRound> _buildRounds(
    CollabActivityType activity,
    CollabPresentation presentation,
  ) {
    final all = ref.read(allFlashcardsProvider);
    if (all.isEmpty) return const [];

    final random = Random();
    final pool = [...all]..shuffle(random);

    // Word Relay spells the target out one letter per turn, so a long word is
    // both a long round and a wide row of blanks. Prefer short words, but fall
    // back to the whole pool rather than failing to start.
    var targetPool = pool;
    if (activity == CollabActivityType.wordRelay) {
      final short = pool.where((c) => c.wordEnglish.length <= 8).toList();
      if (short.length >= presentation.rounds) targetPool = short;
    }

    final count = min(presentation.rounds, targetPool.length);
    return _roundsFor(targetPool.take(count).toList(), presentation);
  }

  /// Wrap [cards] as rounds, drawing fresh answer options from the live pool.
  List<CollabRound> _roundsFor(
    List<Flashcard> cards,
    CollabPresentation presentation,
  ) {
    final pool = ref.read(allFlashcardsProvider);
    final random = Random();

    return cards.map((card) {
      // Distractors come from the same pool so the options always look like
      // words this learner is actually studying.
      final others =
          pool
              .where(
                (c) => c.id != card.id && c.wordEnglish != card.wordEnglish,
              )
              .map((c) => c.wordEnglish)
              .toSet()
              .toList()
            ..shuffle(random);
      final choices = <String>[
        card.wordEnglish,
        ...others.take(max(0, presentation.choiceCount - 1)),
      ]..shuffle(random);

      return CollabRound(
        cardId: card.id,
        word: card.wordEnglish,
        wordFilipino: card.wordFilipino,
        choices: choices,
      );
    }).toList();
  }

  /// Rebuild the saved session and drop back into it.
  void _resumeSession(CollabResumeSnapshot snapshot) {
    // Resolve the saved ids against the **whole** card pool, never against a
    // freshly dealt hand — a fresh deal is a different random set, so a lookup
    // against it misses every id and silently restarts at round one.
    final byId = {for (final c in ref.read(allFlashcardsProvider)) c.id: c};
    final cards = <Flashcard>[];
    for (final id in snapshot.cardIds) {
      final card = byId[id];
      if (card == null) break;
      cards.add(card);
    }

    if (cards.length != snapshot.cardIds.length) {
      // A card the snapshot leans on is gone (a deleted custom card, or an
      // older build's deck). Say so plainly rather than dropping the pair into
      // a session missing a round.
      CollabSessionStore.clear(_profileId);
      setState(() => _resume = null);
      AppSnackBar.warning(context, message: _l10n.collabNoWords);
      return;
    }

    _player2Controller.text = snapshot.player2Name;
    CollabSessionStore.clear(_profileId);
    setState(() => _resume = null);
    _applySession(
      snapshot.toSession(id: _uuid.v4(), rounds: _roundsFor(cards, _p)),
    );
  }

  void _startOver() {
    CollabSessionStore.clear(_profileId);
    setState(() => _resume = null);
  }

  /// The one place a session is replaced: keeps the tap targets, the narration
  /// and the announcement in step with the turn actually in play.
  void _applySession(CollabSession session, {bool? answerWasCorrect}) {
    setState(() {
      _session = session;
      _lastAnswerCorrect = answerWasCorrect;
      _choices = _choicesFor(session);
    });
    _inputController.clear();
    // Nothing to come back to once it is finished.
    if (session.isComplete) CollabSessionStore.clear(_profileId);
    _narrate(session);
  }

  void _submit(String content) {
    final session = _session;
    if (session == null || session.isComplete || content.trim().isEmpty) return;

    final before = session;
    final next = session.applyTurn(content);
    if (identical(next, session)) return;

    final turn = next.turns.last;
    final checked = turn.isChecked;
    final haptics = ref.read(hapticServiceProvider);
    if (_p.haptics) {
      // ignore: discarded_futures
      checked
          ? (turn.isCorrect ? haptics.success() : haptics.error())
          : haptics.lightTap();
    }

    if (checked && !turn.isCorrect && before.activityType.hasRoles) {
      // Say the answer rather than leaving a wrong guess unexplained — the
      // round has already moved on.
      AppSnackBar.info(
        context,
        message: _l10n.collabAnswerWas(before.currentRound?.word ?? ''),
      );
    }

    _applySession(next, answerWasCorrect: checked ? turn.isCorrect : null);
  }

  void _playAgain() {
    CollabSessionStore.clear(_profileId);
    setState(() {
      _session = null;
      _choices = const [];
      _lastAnswerCorrect = null;
    });
  }

  // ─── Leaving ──────────────────────────────────────────

  /// True when Back can just leave: there is no session in play to lose.
  bool get _canLeaveFreely => _session == null || _session!.isComplete;

  /// Two children mid-round should not lose their place to a stray Back press
  /// — and if they do mean it, the place is kept rather than thrown away.
  Future<void> _confirmLeave() async {
    if (_canLeaveFreely) {
      if (mounted) await Navigator.of(context).maybePop();
      return;
    }

    setState(() => _mediaOpen = true);
    final l10n = _l10n;
    final leave = await showAnimatedConfirmDialog(
      context,
      title: l10n.collabLeaveTitle,
      content: l10n.collabLeaveBody,
      confirmLabel: l10n.collabLeaveConfirm,
      cancelLabel: l10n.collabKeepPlaying,
      emoji: '🤝',
    );
    if (!mounted) return;
    setState(() => _mediaOpen = false);

    if (leave == true) {
      _saveSession();
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ─── Alternative channels ─────────────────────────────

  void _narrate(CollabSession session) {
    final presentation = _p;
    if (session.isComplete) return;
    final line = _promptLine(session);
    if (presentation.speakPrompts) {
      // ignore: discarded_futures
      _tts.speak(line);
    }
    if (presentation.announce) {
      // Wraps the (deprecated-but-still-functional) SemanticsService.announce;
      // its replacement isn't available on the bundled Flutter SDK yet. Same
      // call, and same comment, as LiveSessionScreen._announce.
      // ignore: deprecated_member_use
      SemanticsService.announce(line, TextDirection.ltr);
    }
  }

  /// The single sentence that describes the turn in play — spoken, announced to
  /// the screen reader, and shown as the turn banner, so all three channels say
  /// the same thing.
  String _promptLine(CollabSession session) {
    final l10n = _l10n;
    final who = session.currentPlayerName;
    if (session.isCluePhase) {
      return l10n.collabPromptDescribe(
        who,
        session.nameOf(session.guesserIndex),
      );
    }
    return switch (session.activityType) {
      CollabActivityType.wordRelay => l10n.collabPromptNextLetter(who),
      CollabActivityType.storyBuilder => l10n.collabPromptAddSentence(who),
      CollabActivityType.pictureGuess ||
      CollabActivityType.signChallenge => l10n.collabPromptGuess(who),
    };
  }

  Future<void> _speakCurrent() async {
    final session = _session;
    if (session == null) return;
    await _tts.speak(_promptLine(session));
  }

  Future<void> _showSign(String cardId) async {
    setState(() => _mediaOpen = true);
    try {
      await showRaceSign(context, ref, cardId);
    } finally {
      if (mounted) setState(() => _mediaOpen = false);
    }
  }

  // ─── Tap targets ──────────────────────────────────────

  /// What the player to move can tap. Guessing rounds reuse the options built
  /// with the round; Word Relay needs fresh letters each blank, and Story
  /// Builder a phrase bank made from the round's own word so that even the
  /// open-ended activity practises real vocabulary.
  List<String> _choicesFor(CollabSession session) {
    final round = session.currentRound;
    if (round == null) return const [];

    if (session.isCluePhase) return _clueBank(session);

    return switch (session.activityType) {
      CollabActivityType.wordRelay => _letterChoices(session),
      CollabActivityType.storyBuilder => _phraseBank(
        _isFilipino ? round.wordFilipino : round.word,
      ).take(_p.choiceCount).toList(),
      CollabActivityType.pictureGuess ||
      CollabActivityType.signChallenge => round.choices,
    };
  }

  /// Ready-made written clues for the round's card.
  ///
  /// The describer can always *say* or *sign* their clue — the picture and the
  /// FSL clip are right there — but a written one used to need a keyboard,
  /// which is exactly what a motor, cognitive or gaze learner does not have.
  /// These are tappable, so writing a clue is open to every profile; the
  /// free-text field beside them stays the way to write your own.
  ///
  /// Drawn from the card rather than invented, so a clue is always true: its
  /// category, its first letter, its length. None of them names the word.
  List<String> _clueBank(CollabSession session) {
    final round = session.currentRound;
    if (round == null) return const [];
    final l10n = _l10n;
    final card = _cardFor(round.cardId);
    final word = round.word.trim();

    // The facts live in the model so they can be tested without a widget — see
    // [CollabClueFacts]. This method only decides how to word them.
    final facts = CollabClueFacts.of(word);

    return <String>[
      if (card != null) l10n.collabClueCategory(card.category.labelOf(l10n)),
      if (facts.firstLetter.isNotEmpty)
        l10n.collabClueFirstLetter(facts.firstLetter),
      if (facts.isUsable) l10n.collabClueLength(facts.letterCount),
    ].take(_p.choiceCount).toList();
  }

  /// The describer's "I showed it — take the tablet" button.
  String _passLabel(CollabSession session) =>
      _l10n.collabPassSpoken(session.nameOf(session.guesserIndex));

  List<String> _letterChoices(CollabSession session) {
    final expected = session.expectedLetter;
    if (expected == null) return const [];
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    final letters = <String>{expected};
    while (letters.length < _p.choiceCount) {
      letters.add(alphabet[random.nextInt(alphabet.length)]);
    }
    final list = letters.map((l) => l.toUpperCase()).toList()..shuffle(random);
    return list;
  }

  List<String> _phraseBank(String word) {
    final l10n = _l10n;
    return [
      l10n.collabPhraseBig(word),
      l10n.collabPhraseISee(word),
      l10n.collabPhraseHappy(word),
      l10n.collabPhraseWeLike(word),
    ];
  }

  // ─── Hands-free control ───────────────────────────────

  List<GazeAction> _gazeActions() {
    final l10n = _l10n;
    final session = _session;
    final live = !_mediaOpen;

    if (session == null || session.isComplete) {
      return [
        GazeAction(
          zone: GazeZone.down,
          label: session == null ? l10n.gazeChoose : l10n.playAgain,
          icon: session == null
              ? Icons.check_circle_rounded
              : Icons.replay_rounded,
          color: AppColors.success,
          enabled: live && _cursor.canChoose,
          onSelect: _cursor.choose,
        ),
      ];
    }

    return [
      GazeAction(
        zone: GazeZone.left,
        label: l10n.gazePrev,
        icon: Icons.chevron_left_rounded,
        color: AppColors.secondary,
        enabled: live && _cursor.canMove,
        onSelect: () => _cursor.move(-1),
      ),
      GazeAction(
        zone: GazeZone.right,
        label: l10n.gazeNext,
        icon: Icons.chevron_right_rounded,
        color: AppColors.secondary,
        enabled: live && _cursor.canMove,
        onSelect: () => _cursor.move(1),
      ),
      GazeAction(
        zone: GazeZone.down,
        label: l10n.gazeChoose,
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        enabled: live && _cursor.canChoose,
        onSelect: _cursor.choose,
      ),
    ];
  }

  void _onBlink() {
    if (_mediaOpen) return;
    if (_cursor.canChoose) _cursor.choose();
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final presentation = ref.watch(collabPresentationProvider);
    final padding = context.pagePadding;
    final session = _session;

    // Rebuilt on every cursor move so the scope's actions and the highlight
    // ring stay in step with where the learner is looking.
    return ListenableBuilder(
      listenable: _cursor,
      builder: (context, _) => GazeScope(
        actions: _gazeActions(),
        onBlink: _onBlink,
        child: PopScope(
          // Free to leave whenever there is nothing in play to lose; otherwise
          // intercept and ask.
          canPop: _canLeaveFreely,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('🤝 Peer Collab'),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                if (presentation.canSpeak &&
                    session != null &&
                    !session.isComplete)
                  IconButton(
                    onPressed: _speakCurrent,
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: l10n.collabHearAgain,
                  ),
              ],
            ),
            body: session == null
                ? _buildActivitySelection(presentation, l10n, padding)
                : session.isComplete
                ? _buildCompletion(session, l10n, padding)
                : _buildActiveSession(session, presentation, l10n, padding),
          ),
        ),
      ),
    );
  }

  // ─── Picker ───────────────────────────────────────────

  Widget _buildActivitySelection(
    CollabPresentation presentation,
    AppLocalizations l10n,
    double padding,
  ) {
    final hc = HCColor.of(context);
    final profile = ref.read(profileProvider);
    final activities = presentation.activities;
    final resume = _resume;
    final adaptations = presentation.adaptations;

    // Publish the picker's hands-free targets. The resume card's Continue, when
    // it is showing, is the first of them.
    final actions = <VoidCallback>[
      if (resume != null) () => _resumeSession(resume),
      for (final activity in activities)
        () => _startSession(activity, profile?.name ?? 'Player 1'),
    ];
    _cursor.attach(
      count: actions.length,
      enabled: !_mediaOpen,
      onChoose: () {
        final index = _cursor.index;
        if (index >= 0 && index < actions.length) actions[index]();
      },
    );
    final activityCursorOffset = resume != null ? 1 : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.withValues(alpha: 0.1),
                  Colors.purple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                const Text('🤝', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  l10n.collabLearnTogether,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.collabTeamTagline,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                if (adaptations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _AdaptationNote(
                    note: l10n.collabSetUpForYou(
                      adaptations
                          .map((a) => _adaptationLabel(a, l10n))
                          .join(', '),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          if (resume != null) ...[
            const SizedBox(height: 16),
            _ResumeCard(
              snapshot: resume,
              l10n: l10n,
              focused: _cursor.isFocused(0),
              onContinue: () => _resumeSession(resume),
              onStartOver: _startOver,
            ).animate().fadeIn(duration: 350.ms),
          ],

          const SizedBox(height: 20),

          Text(
            l10n.collabPlayer2NameLabel,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            textField: true,
            label: l10n.collabPlayer2NameSemantics,
            child: TextField(
              controller: _player2Controller,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.collabPlayer2NameHint,
                prefixIcon: const Icon(Icons.person_add_rounded, size: 20),
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
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            l10n.collabChooseActivity,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...activities.asMap().entries.map((entry) {
            final idx = entry.key;
            final activity = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _ActivityCard(
                        activity: activity,
                        l10n: l10n,
                        focused: _cursor.isFocused(idx + activityCursorOffset),
                        onStart: () => _startSession(
                          activity,
                          profile?.name ?? 'Player 1',
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: (idx * 80).ms)
                      .slideX(begin: 0.04, end: 0),
            );
          }),
        ],
      ),
    );
  }

  String _adaptationLabel(CollabAdaptation a, AppLocalizations l10n) =>
      switch (a) {
        CollabAdaptation.tapToAnswer => l10n.collabAdaptTapToAnswer,
        CollabAdaptation.readAloud => l10n.collabAdaptReadAloud,
        CollabAdaptation.biggerButtons => l10n.collabAdaptBiggerButtons,
        CollabAdaptation.shorterSession => l10n.collabAdaptShorter,
      };

  // ─── Live session ─────────────────────────────────────

  Widget _buildActiveSession(
    CollabSession session,
    CollabPresentation presentation,
    AppLocalizations l10n,
    double padding,
  ) {
    return Column(
      children: [
        // One scroll region for the whole board — status, turn banner and the
        // activity itself. At a 2.0x font scale the two chrome pieces alone are
        // ~490px on a 640px-tall phone, so anything that pins them squeezes the
        // activity to nothing and then bursts the column anyway. Only the
        // answer bar stays put, because that is the part the learner must
        // always be able to reach.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                _StatusBar(
                  session: session,
                  l10n: l10n,
                  padding: padding,
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 12),
                _TurnBanner(
                  line: _promptLine(session),
                  correct: _lastAnswerCorrect,
                  padding: padding,
                ),
                const SizedBox(height: 12),
                _buildActivityContent(session, presentation, l10n, padding),
              ],
            ),
          ),
        ),

        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: _AnswerBar(
            choices: _choices,
            focusedIndex: _cursor.index,
            showRing: _cursor.highlight,
            bigTargets: presentation.bigTargets,
            allowFreeText: presentation.allowFreeText,
            controller: _inputController,
            accent: session.activityType.color,
            hint: _inputHint(session, l10n),
            submitLabel: l10n.collabSubmitAnswer,
            // Cluing aloud or in sign is a separate, always-available way to
            // finish the turn, so it gets its own button rather than sitting in
            // the row of written clues.
            trailingLabel: session.isCluePhase ? _passLabel(session) : null,
            onTrailing: () => _submit(CollabSession.spokenClue),
            onChoose: _submit,
            padding: padding,
            attach: (count, onChoose) => _cursor.attach(
              count: count,
              enabled: !_mediaOpen,
              onChoose: onChoose,
            ),
          ),
        ),
      ],
    );
  }

  String _inputHint(CollabSession session, AppLocalizations l10n) {
    if (session.isCluePhase) return l10n.collabHintClue;
    return switch (session.activityType) {
      CollabActivityType.wordRelay => l10n.collabHintLetter,
      CollabActivityType.storyBuilder => l10n.collabHintSentence,
      CollabActivityType.pictureGuess ||
      CollabActivityType.signChallenge => l10n.collabHintGuess,
    };
  }

  Widget _buildActivityContent(
    CollabSession session,
    CollabPresentation presentation,
    AppLocalizations l10n,
    double padding,
  ) {
    final round = session.currentRound;
    if (round == null) return const SizedBox.shrink();
    final card = _cardFor(round.cardId);

    switch (session.activityType) {
      case CollabActivityType.wordRelay:
        return _RelayBoard(
          session: session,
          card: card,
          showPicture: presentation.showPictures,
          showFsl: presentation.showFsl,
          onShowSign: () => _showSign(round.cardId),
          l10n: l10n,
          padding: padding,
        );

      case CollabActivityType.storyBuilder:
        return _StoryFeed(session: session, l10n: l10n, padding: padding);

      case CollabActivityType.pictureGuess:
      case CollabActivityType.signChallenge:
        return _GuessBoard(
          session: session,
          card: card,
          // The describer sees the word; the guesser must not. For Sign
          // Challenge the picture stays hidden even from the describer — the
          // sign is the clue, not the drawing.
          reveal: session.isCluePhase,
          showPicture:
              presentation.showPictures &&
              session.activityType == CollabActivityType.pictureGuess,
          showFsl: presentation.showFsl,
          onShowSign: () => _showSign(round.cardId),
          l10n: l10n,
          padding: padding,
        );
    }
  }

  Flashcard? _cardFor(String id) {
    for (final card in ref.read(allFlashcardsProvider)) {
      if (card.id == id) return card;
    }
    return null;
  }

  // ─── Finish ───────────────────────────────────────────

  Widget _buildCompletion(
    CollabSession session,
    AppLocalizations l10n,
    double padding,
  ) {
    final hc = HCColor.of(context);

    _cursor.attach(count: 1, enabled: !_mediaOpen, onChoose: _playAgain);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)).animate().scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 500.ms,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.collabGreatTeamwork,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            // One team number, not a winner — the whole point of the feature.
            Text(
              l10n.collabPointsTogether(
                session.teamScore,
                session.maxTeamScore,
              ),
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hc.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Both names are free text — Player 1 is the profile name,
                  // Player 2 is typed on the picker — so each column has to be
                  // held to half the card. Unflexed, a 26-character profile
                  // name shoved Player 2's whole column 223px off the right of
                  // a 360-wide screen, taking their score with it.
                  Expanded(
                    child: _ScoreColumn(
                      name: session.player1Name,
                      score: session.player1Score,
                      emoji: '📘',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ScoreColumn(
                      name: session.player2Name,
                      score: session.player2Score,
                      emoji: '📗',
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: _RingWrap(
                focused: _cursor.isFocused(0),
                child: ElevatedButton.icon(
                  onPressed: _playAgain,
                  icon: const Icon(Icons.replay_rounded, color: Colors.white),
                  label: Text(
                    l10n.playAgain,
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Pieces ─────────────────────────────────────────────

/// "Continue where you left off?" — deliberately the same vocabulary the Games
/// hub uses, so resuming reads identically wherever a learner meets it.
class _ResumeCard extends StatelessWidget {
  final CollabResumeSnapshot snapshot;
  final AppLocalizations l10n;
  final bool focused;
  final VoidCallback onContinue;
  final VoidCallback onStartOver;

  const _ResumeCard({
    required this.snapshot,
    required this.l10n,
    required this.focused,
    required this.onContinue,
    required this.onStartOver,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final accent = snapshot.activityType.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.resumeBadge,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  snapshot.activityType.labelOf(l10n),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.resumeTitle,
            style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.resumeRoundProgress(
              snapshot.roundNumber,
              snapshot.roundsTotal,
            ),
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          // Wrap so the two buttons stack instead of bursting at a big font
          // scale — the same rule the answer row follows.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RingWrap(
                focused: focused,
                child: FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(l10n.resumeContinue),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                ),
              ),
              TextButton(
                onPressed: onStartOver,
                child: Text(l10n.resumeStartOver),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "here is what we changed for you" line on the picker.
class _AdaptationNote extends StatelessWidget {
  final String note;
  const _AdaptationNote({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.accessibility_new_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round counter and the team total.
class _StatusBar extends StatelessWidget {
  final CollabSession session;
  final AppLocalizations l10n;
  final double padding;

  const _StatusBar({
    required this.session,
    required this.l10n,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final accent = session.activityType.color;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(
            session.activityType.emoji,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.activityType.labelOf(l10n),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hc.textPrimary,
                  ),
                ),
                Text(
                  l10n.resumeRoundProgress(
                    session.roundsCurrent,
                    session.roundsTotal,
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${session.teamScore}',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Text(
                l10n.collabTeam,
                style: AppTypography.labelSmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Whose turn it is, plus the tick or cross for the turn just played.
class _TurnBanner extends StatelessWidget {
  final String line;
  final bool? correct;
  final double padding;

  const _TurnBanner({
    required this.line,
    required this.correct,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct == null
        ? AppColors.primary
        : (correct! ? AppColors.success : AppColors.error);
    final icon = correct == null
        ? Icons.arrow_forward_rounded
        : (correct! ? Icons.check_circle_rounded : Icons.cancel_rounded);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          // Player names are free text (Player 2 is typed in on the picker,
          // Player 1 is the profile name), so this Text has to be able to give:
          // unconstrained it burst the row by 233px at a 2.0x font scale on a
          // 360-wide phone.
          Flexible(
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Word Relay: the picture, the blanks, and the FSL clip for the word.
class _RelayBoard extends StatelessWidget {
  final CollabSession session;
  final Flashcard? card;
  final bool showPicture;
  final bool showFsl;
  final VoidCallback onShowSign;
  final AppLocalizations l10n;
  final double padding;

  const _RelayBoard({
    required this.session,
    required this.card,
    required this.showPicture,
    required this.showFsl,
    required this.onShowSign,
    required this.l10n,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final round = session.currentRound!;
    final revealed = session.revealed;

    // Non-scrolling: the session's single scroll view owns the whole board.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showPicture && card != null) ...[
            FlashcardImage(card: card!, size: 64),
            const SizedBox(height: 12),
          ],
          Text(
            l10n.collabWordToSpell,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          // Wrap rather than Row: the boxes are a fixed 36px, so an 8-letter
          // word overflowed a 360-wide phone.
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 6,
            children: List.generate(round.word.length, (i) {
              final isRevealed = i < revealed.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 36,
                height: 44,
                decoration: BoxDecoration(
                  color: isRevealed
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : hc.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRevealed ? AppColors.primary : hc.border,
                    width: isRevealed ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    isRevealed ? revealed[i].toUpperCase() : '_',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isRevealed ? AppColors.primary : hc.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (showFsl) ...[
            const SizedBox(height: 16),
            _SignButton(onPressed: onShowSign, label: l10n.collabWatchTheSign),
          ],
        ],
      ),
    );
  }
}

/// Picture Guess / Sign Challenge: the word for the describer, "???" and the
/// clue for the guesser.
class _GuessBoard extends StatelessWidget {
  final CollabSession session;
  final Flashcard? card;
  final bool reveal;
  final bool showPicture;
  final bool showFsl;
  final VoidCallback onShowSign;
  final AppLocalizations l10n;
  final double padding;

  const _GuessBoard({
    required this.session,
    required this.card,
    required this.reveal,
    required this.showPicture,
    required this.showFsl,
    required this.onShowSign,
    required this.l10n,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final round = session.currentRound!;
    final accent = session.activityType.color;

    // Null when the describer clued aloud or in sign — see
    // [CollabSession.writtenClue], which filters the marker so no widget can
    // render it as a hint.
    final clue = session.writtenClue;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (reveal && showPicture && card != null) ...[
            FlashcardImage(card: card!),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  reveal
                      ? (session.activityType == CollabActivityType.pictureGuess
                            ? l10n.collabWordToDescribe
                            : l10n.collabSignToShow)
                      : l10n.collabWhatIsTheWord,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reveal ? round.word.toUpperCase() : '???',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: reveal ? accent : hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // The describer's own reference clip. Sign Challenge is the one
          // activity where this is the whole point, so it is offered first.
          if (reveal && showFsl) ...[
            const SizedBox(height: 16),
            _SignButton(onPressed: onShowSign, label: l10n.collabWatchTheSign),
          ],
          if (!reveal && clue != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.collabClueLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clue.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Story Builder: the story so far.
class _StoryFeed extends StatelessWidget {
  final CollabSession session;
  final AppLocalizations l10n;
  final double padding;

  const _StoryFeed({
    required this.session,
    required this.l10n,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.collabBuildStoryTogether,
            textAlign: TextAlign.center,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (session.turns.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  l10n.collabStartTheStory,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            ),
          ...session.turns.map((turn) {
            final isPlayer1 = turn.playerIndex == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlayer1 ? '📘' : '📗',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.nameOf(turn.playerIndex),
                          style: AppTypography.labelSmall.copyWith(
                            color: hc.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          turn.content,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms);
          }),
        ],
      ),
    );
  }
}

/// "Watch the sign" — the same FSL sheet Cards, Stories and Play Together open.
class _SignButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _SignButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.sign_language_rounded, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// The answer surface: tappable choices, and a keyboard only where typing is
/// not itself the barrier.
///
/// This is the change that makes Peer Collab reachable by a gaze or switch
/// learner at all — see [CollabPresentation.tapToSelect].
class _AnswerBar extends StatelessWidget {
  final List<String> choices;
  final int focusedIndex;
  final bool showRing;
  final bool bigTargets;
  final bool allowFreeText;
  final TextEditingController controller;
  final Color accent;
  final String hint;
  final String submitLabel;

  /// An extra action shown below the choices and reachable by the hands-free
  /// cursor as its **last** target. Null hides it. Used for "I showed it — pass
  /// to X", which is a different kind of thing from the written clues above it.
  final String? trailingLabel;
  final VoidCallback onTrailing;

  final ValueChanged<String> onChoose;
  final double padding;
  final void Function(int count, VoidCallback onChoose) attach;

  const _AnswerBar({
    required this.choices,
    required this.focusedIndex,
    required this.showRing,
    required this.bigTargets,
    required this.allowFreeText,
    required this.controller,
    required this.accent,
    required this.hint,
    required this.submitLabel,
    required this.trailingLabel,
    required this.onTrailing,
    required this.onChoose,
    required this.padding,
    required this.attach,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    final trailing = trailingLabel;

    // Publish this turn's targets to the screen's gaze cursor: the choices, and
    // then the trailing action if there is one.
    attach(choices.length + (trailing == null ? 0 : 1), () {
      if (focusedIndex < 0) return;
      if (focusedIndex < choices.length) {
        onChoose(choices[focusedIndex]);
      } else if (trailing != null) {
        onTrailing();
      }
    });

    return Container(
      padding: EdgeInsets.fromLTRB(padding, 10, padding, 10),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(top: BorderSide(color: hc.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wrap, so a long phrase bank at a big font scale flows onto more
            // rows instead of bursting the width.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: List.generate(choices.length, (i) {
                return _ChoiceButton(
                  // Stable handle for the widget tests, which drive a whole
                  // session by tapping — the one input path every accessibility
                  // category shares.
                  key: ValueKey('collabChoice$i'),
                  label: choices[i],
                  accent: accent,
                  big: bigTargets,
                  focused: showRing && focusedIndex == i,
                  onTap: () => onChoose(choices[i]),
                );
              }),
            ),
            if (allowFreeText) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: hint,
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: onChoose,
                        decoration: InputDecoration(
                          hintText: hint,
                          filled: true,
                          fillColor: hc.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: hc.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: hc.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: submitLabel,
                    child: IconButton.filled(
                      onPressed: () => onChoose(controller.text),
                      icon: const Icon(Icons.check_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _RingWrap(
                  focused: showRing && focusedIndex == choices.length,
                  child: OutlinedButton.icon(
                    onPressed: onTrailing,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(trailing, textAlign: TextAlign.center),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(
                        vertical: bigTargets ? 16 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final Color accent;
  final bool big;
  final bool focused;
  final VoidCallback onTap;

  const _ChoiceButton({
    super.key,
    required this.label,
    required this.accent,
    required this.big,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return _RingWrap(
      focused: focused,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(minWidth: big ? 84 : 64),
            padding: EdgeInsets.symmetric(
              horizontal: big ? 20 : 14,
              vertical: big ? 16 : 10,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style:
                  (big ? AppTypography.titleMedium : AppTypography.titleSmall)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hands-free highlight ring.
class _RingWrap extends StatelessWidget {
  final bool focused;
  final Widget child;

  const _RingWrap({required this.focused, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!focused) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success, width: 3),
      ),
      padding: const EdgeInsets.all(2),
      child: child,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final CollabActivityType activity;
  final AppLocalizations l10n;
  final bool focused;
  final VoidCallback onStart;

  const _ActivityCard({
    required this.activity,
    required this.l10n,
    required this.focused,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return _RingWrap(
      focused: focused,
      child: Semantics(
        button: true,
        label: activity.labelOf(l10n),
        child: InkWell(
          onTap: onStart,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activity.color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: activity.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      activity.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.labelOf(l10n),
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity.descriptionOf(l10n),
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_filled_rounded,
                  color: activity.color,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final int score;
  final String emoji;

  const _ScoreColumn({
    required this.name,
    required this.score,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelMedium.copyWith(
            color: hc.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
