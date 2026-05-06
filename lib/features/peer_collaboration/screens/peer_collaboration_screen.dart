import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../providers/app_providers.dart';
import '../models/collab_models.dart';

const _uuid = Uuid();

class PeerCollaborationScreen extends ConsumerStatefulWidget {
  const PeerCollaborationScreen({super.key});

  @override
  ConsumerState<PeerCollaborationScreen> createState() =>
      _PeerCollaborationScreenState();
}

class _PeerCollaborationScreenState
    extends ConsumerState<PeerCollaborationScreen> {
  CollabSession? _session;
  final _inputController = TextEditingController();
  String _player2Name = '';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? '🤝 Peer Collab' : '🤝 Peer Collab'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _session != null
          ? _buildActiveSession(isFilipino, padding)
          : _buildActivitySelection(isFilipino, padding),
    );
  }

  Widget _buildActivitySelection(bool isFilipino, double padding) {
    final hc = HCColor.of(context);
    final profile = ref.read(profileProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
              border: Border.all(
                color: Colors.indigo.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                const Text('🤝', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  isFilipino
                      ? 'Matuto nang magkasama!'
                      : 'Learn Together!',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFilipino
                      ? 'Pumili ng activity at mag-invite ng kaibigan sa parehong device'
                      : 'Pick an activity and invite a friend on the same device',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: hc.textSecondary),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 20),

          // Player 2 name input
          Text(
            isFilipino ? "Pangalan ng Player 2:" : "Player 2's Name:",
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                isFilipino ? 'Pangalan ng Player 2' : "Player 2's name",
            child: TextField(
              onChanged: (v) => _player2Name = v.trim(),
              decoration: InputDecoration(
                hintText: isFilipino ? 'I-type ang pangalan...' : 'Enter name...',
                prefixIcon:
                    const Icon(Icons.person_add_rounded, size: 20),
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

          // Activity cards
          Text(
            isFilipino ? 'Pumili ng Activity' : 'Choose an Activity',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...CollabActivityType.values.asMap().entries.map((entry) {
            final idx = entry.key;
            final activity = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityCard(
                activity: activity,
                isFilipino: isFilipino,
                onStart: () => _startSession(activity, profile?.name ?? 'Player 1'),
              ).animate()
                  .fadeIn(duration: 350.ms, delay: (idx * 80).ms)
                  .slideX(begin: 0.04, end: 0),
            );
          }),
        ],
      ),
    );
  }

  void _startSession(CollabActivityType activity, String player1Name) {
    if (_player2Name.isEmpty) {
      AppSnackBar.warning(context, message: ref.read(settingsProvider).locale == 'fil'
              ? 'Maglagay ng pangalan ng Player 2'
              : 'Enter Player 2\'s name');
      return;
    }

    final words = [
      'apple', 'banana', 'cat', 'dog', 'elephant', 'fish', 'grape',
      'house', 'ice', 'juice', 'key', 'lemon', 'moon', 'nest',
      'orange', 'pencil', 'queen', 'rain', 'sun', 'tree',
    ];
    final random = Random();

    ref.read(hapticServiceProvider).mediumTap();
    setState(() {
      _session = CollabSession(
        id: _uuid.v4(),
        activityType: activity,
        player1Name: player1Name,
        player2Name: _player2Name,
        targetWord: words[random.nextInt(words.length)],
      );
    });
  }

  Widget _buildActiveSession(bool isFilipino, double padding) {
    final session = _session!;
    final hc = HCColor.of(context);

    if (session.isComplete) {
      return _buildCompletion(isFilipino, padding);
    }

    return Column(
      children: [
        // Status bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: padding),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: session.activityType.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: session.activityType.color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Text(session.activityType.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFilipino
                          ? session.activityType.labelFilipino
                          : session.activityType.label,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      '${isFilipino ? 'Round' : 'Round'} ${session.roundsCurrent}/${session.roundsTotal}',
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                  ],
                ),
              ),
              // Scores
              Column(
                children: [
                  Text(
                    '${session.player1Score} - ${session.player2Score}',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: session.activityType.color,
                    ),
                  ),
                  Text(isFilipino ? 'Puntos' : 'Score',
                      style: AppTypography.labelSmall
                          .copyWith(color: hc.textSecondary)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Current turn indicator
        Container(
          margin: EdgeInsets.symmetric(horizontal: padding),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                isFilipino
                    ? "Turn ni ${session.currentPlayerName}"
                    : "${session.currentPlayerName}'s Turn",
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Activity-specific content
        Expanded(
          child: _buildActivityContent(session, isFilipino, padding),
        ),

        // Input area
        Container(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
          decoration: BoxDecoration(
            color: hc.surface,
            border: Border(top: BorderSide(color: hc.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: isFilipino ? 'Isulat ang sagot' : 'Enter your answer',
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: (_) => _submitTurn(),
                    decoration: InputDecoration(
                      hintText: _getHint(session.activityType, isFilipino),
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
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: isFilipino ? 'Isumite' : 'Submit',
                child: IconButton.filled(
                  onPressed: _submitTurn,
                  icon: const Icon(Icons.check_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: session.activityType.color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getHint(CollabActivityType type, bool isFilipino) {
    switch (type) {
      case CollabActivityType.wordRelay:
        return isFilipino ? 'I-type ang susunod na letra...' : 'Type the next letter...';
      case CollabActivityType.pictureGuess:
        return isFilipino ? 'I-describe o hulaan...' : 'Describe or guess...';
      case CollabActivityType.signChallenge:
        return isFilipino ? 'I-type ang sign...' : 'Type the sign meaning...';
      case CollabActivityType.storyBuilder:
        return isFilipino ? 'Idagdag ang susunod na pangungusap...' : 'Add the next sentence...';
    }
  }

  Widget _buildActivityContent(
      CollabSession session, bool isFilipino, double padding) {
    final hc = HCColor.of(context);

    switch (session.activityType) {
      case CollabActivityType.wordRelay:
        // Show the target word to guesser only via hint
        final revealedLetters = session.turns.map((t) => t.content).join();
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isFilipino ? 'Salitang i-spell:' : 'Word to spell:',
                style: AppTypography.bodyMedium
                    .copyWith(color: hc.textSecondary),
              ),
              const SizedBox(height: 12),
              // Show blanks with revealed letters
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(session.targetWord?.length ?? 0, (i) {
                  final isRevealed = i < revealedLetters.length;
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
                        color: isRevealed
                            ? AppColors.primary
                            : hc.border,
                        width: isRevealed ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isRevealed
                            ? revealedLetters[i].toUpperCase()
                            : '_',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isRevealed
                              ? AppColors.primary
                              : hc.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                isFilipino
                    ? 'I-type ang susunod na letra!'
                    : 'Type the next letter!',
                style: AppTypography.bodyMedium
                    .copyWith(color: hc.textPrimary),
              ),
            ],
          ),
        );

      case CollabActivityType.storyBuilder:
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(
              isFilipino
                  ? 'Buuin ang kwento nang magkasama!'
                  : 'Build the story together!',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: hc.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...session.turns.asMap().entries.map((entry) {
              final turn = entry.value;
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
                            isPlayer1
                                ? session.player1Name
                                : session.player2Name,
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            turn.content,
                            style: AppTypography.bodyMedium
                                .copyWith(color: hc.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms);
            }),
            if (session.turns.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    isFilipino
                        ? 'Magsimula ng kwento!'
                        : 'Start the story!',
                    style: AppTypography.bodyMedium
                        .copyWith(color: hc.textSecondary),
                  ),
                ),
              ),
          ],
        );

      default:
        // Generic turn display for pictureGuess and signChallenge
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            if (session.targetWord != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: session.activityType.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      session.activityType == CollabActivityType.pictureGuess
                          ? (isFilipino ? 'Salitang i-describe:' : 'Word to describe:')
                          : (isFilipino ? 'Sign na ipakita:' : 'Sign to show:'),
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    // Only show to current describer
                    if (session.currentPlayerIndex == 0)
                      Text(
                        session.targetWord!.toUpperCase(),
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: session.activityType.color,
                        ),
                      )
                    else
                      Text(
                        isFilipino ? '???' : '???',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hc.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...session.turns.map((turn) {
              final isPlayer1 = turn.playerIndex == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment:
                      isPlayer1 ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPlayer1
                          ? hc.surface
                          : session.activityType.color
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hc.border),
                    ),
                    child: Text(
                      turn.content,
                      style: AppTypography.bodyMedium
                          .copyWith(color: hc.textPrimary),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms);
            }),
          ],
        );
    }
  }

  void _submitTurn() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _session == null) return;

    final session = _session!;
    final turn = CollabTurn(
      playerIndex: session.currentPlayerIndex,
      content: text,
      timestamp: DateTime.now(),
    );

    final newTurns = [...session.turns, turn];
    final nextPlayer = session.currentPlayerIndex == 0 ? 1 : 0;
    ref.read(hapticServiceProvider).lightTap();

    // Check if round is complete (both players had a turn)
    bool roundComplete = newTurns.length >= session.roundsCurrent * 2;
    int newRound = session.roundsCurrent;
    int p1Score = session.player1Score;
    int p2Score = session.player2Score;

    if (roundComplete) {
      // Award points to both players for participation
      p1Score += 1;
      p2Score += 1;
      newRound = session.roundsCurrent + 1;
    }

    final isComplete = newRound > session.roundsTotal;

    setState(() {
      _session = session.copyWith(
        turns: newTurns,
        currentPlayerIndex: nextPlayer,
        player1Score: p1Score,
        player2Score: p2Score,
        roundsCurrent: isComplete ? session.roundsTotal : newRound,
        isComplete: isComplete,
      );
    });

    _inputController.clear();
  }

  Widget _buildCompletion(bool isFilipino, double padding) {
    final session = _session!;
    final hc = HCColor.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64))
                .animate()
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms),
            const SizedBox(height: 16),
            Text(
              isFilipino ? 'Natapos na!' : 'Activity Complete!',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Score card
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
                  _ScoreColumn(
                    name: session.player1Name,
                    score: session.player1Score,
                    emoji: '📘',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'VS',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  _ScoreColumn(
                    name: session.player2Name,
                    score: session.player2Score,
                    emoji: '📗',
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // Play again button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _session = null),
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                label: Text(
                  isFilipino ? 'Maglaro Ulit' : 'Play Again',
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
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final CollabActivityType activity;
  final bool isFilipino;
  final VoidCallback onStart;

  const _ActivityCard({
    required this.activity,
    required this.isFilipino,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Semantics(
      button: true,
      label: isFilipino ? activity.labelFilipino : activity.label,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: activity.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activity.color.withValues(alpha: 0.15),
            ),
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
                  child: Text(activity.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFilipino ? activity.labelFilipino : activity.label,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFilipino
                          ? activity.descriptionFilipino
                          : activity.description,
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_filled_rounded,
                  color: activity.color, size: 32),
            ],
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
