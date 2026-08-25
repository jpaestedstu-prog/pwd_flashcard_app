import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Types of collaborative activities
enum CollabActivityType {
  wordRelay,
  pictureGuess,
  signChallenge,
  storyBuilder,
}

extension CollabActivityTypeExt on CollabActivityType {
  /// English name, for logs, tests and any future export. Deliberately **not**
  /// what a learner reads — see [labelOf] — for the same reason `GameTypeX`
  /// keeps its English `.label`: one dataset must read the same whatever
  /// language the tablet is set to.
  String get label {
    switch (this) {
      case CollabActivityType.wordRelay:
        return 'Word Relay';
      case CollabActivityType.pictureGuess:
        return 'Picture Guess';
      case CollabActivityType.signChallenge:
        return 'Sign Challenge';
      case CollabActivityType.storyBuilder:
        return 'Story Builder';
    }
  }

  /// The learner-facing name. Use this, not [label], anywhere a child reads it.
  String labelOf(AppLocalizations l10n) {
    switch (this) {
      case CollabActivityType.wordRelay:
        return l10n.collabWordRelay;
      case CollabActivityType.pictureGuess:
        return l10n.collabPictureGuess;
      case CollabActivityType.signChallenge:
        return l10n.collabSignChallenge;
      case CollabActivityType.storyBuilder:
        return l10n.collabStoryBuilder;
    }
  }

  String get emoji {
    switch (this) {
      case CollabActivityType.wordRelay:
        return '🔤';
      case CollabActivityType.pictureGuess:
        return '🖼️';
      case CollabActivityType.signChallenge:
        return '🤟';
      case CollabActivityType.storyBuilder:
        return '📖';
    }
  }

  String get description {
    switch (this) {
      case CollabActivityType.wordRelay:
        return 'Take turns spelling words letter by letter';
      case CollabActivityType.pictureGuess:
        return 'One player describes, the other guesses the picture';
      case CollabActivityType.signChallenge:
        return 'Sign the word, then guess your partner\'s sign';
      case CollabActivityType.storyBuilder:
        return 'Build a story together, one sentence at a time';
    }
  }

  /// The learner-facing blurb. Use this, not [description].
  String descriptionOf(AppLocalizations l10n) {
    switch (this) {
      case CollabActivityType.wordRelay:
        return l10n.collabWordRelayDesc;
      case CollabActivityType.pictureGuess:
        return l10n.collabPictureGuessDesc;
      case CollabActivityType.signChallenge:
        return l10n.collabSignChallengeDesc;
      case CollabActivityType.storyBuilder:
        return l10n.collabStoryBuilderDesc;
    }
  }

  IconData get icon {
    switch (this) {
      case CollabActivityType.wordRelay:
        return Icons.abc_rounded;
      case CollabActivityType.pictureGuess:
        return Icons.image_rounded;
      case CollabActivityType.signChallenge:
        return Icons.sign_language_rounded;
      case CollabActivityType.storyBuilder:
        return Icons.auto_stories_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CollabActivityType.wordRelay:
        return Colors.blue;
      case CollabActivityType.pictureGuess:
        return Colors.orange;
      case CollabActivityType.signChallenge:
        return Colors.purple;
      case CollabActivityType.storyBuilder:
        return Colors.teal;
    }
  }

  /// Whether a round is one player cluing a hidden word for the other.
  ///
  /// These are the two activities with a describer and a guesser, so they are
  /// the two that rotate roles between rounds.
  bool get hasRoles =>
      this == CollabActivityType.pictureGuess ||
      this == CollabActivityType.signChallenge;

  /// Whether turns are scored against a right answer at all.
  ///
  /// Story Builder is deliberately open — there is no correct next sentence, so
  /// every contribution counts. Saying so here keeps the scoring honest instead
  /// of pretending an unchecked turn was "correct".
  bool get isOpenEnded => this == CollabActivityType.storyBuilder;
}

/// One round's target word, drawn from the learner's real deck.
///
/// [choices] is built by the screen (which owns the card pool) and always
/// contains [word], so the model can stay pure and still be asked "was that
/// right?".
@immutable
class CollabRound {
  /// The flashcard behind this round, for the picture and the FSL clip.
  final String cardId;

  /// The answer, as displayed.
  final String word;

  /// The word in Filipino, for the bilingual prompt. Falls back to [word].
  final String wordFilipino;

  /// Shuffled answer options for the tap-to-select surface, including [word].
  final List<String> choices;

  const CollabRound({
    required this.cardId,
    required this.word,
    required this.wordFilipino,
    this.choices = const [],
  });

  /// Case- and whitespace-insensitive answer check.
  bool accepts(String answer) =>
      answer.trim().toLowerCase() == word.trim().toLowerCase();
}

/// The true things about a round's word that a ready-made clue is built from.
///
/// Pure and separate from the wording so the *facts* can be tested without a
/// widget or a locale. They have to be exactly right: a clue a child cannot
/// rely on is worse than no clue, and the first version counted the space in
/// "Partly Cloudy" and told them it had thirteen letters.
@immutable
class CollabClueFacts {
  /// The word's opening letter, upper-cased. Empty for an empty word.
  final String firstLetter;

  /// How many letters a child would count. Whitespace is **not** a letter —
  /// several cards are two words.
  final int letterCount;

  const CollabClueFacts({
    required this.firstLetter,
    required this.letterCount,
  });

  factory CollabClueFacts.of(String word) {
    final trimmed = word.trim();
    return CollabClueFacts(
      firstLetter: trimmed.isEmpty ? '' : trimmed[0].toUpperCase(),
      letterCount: trimmed.replaceAll(RegExp(r'\s'), '').length,
    );
  }

  /// Whether there is anything worth saying about this word at all.
  bool get isUsable => letterCount > 0;
}

/// A single contribution by one player.
@immutable
class CollabTurn {
  final int playerIndex; // 0 or 1
  final String content;

  /// Whether this turn was *checked and right*. Always true for an open-ended
  /// activity and for a clue, both of which have no wrong answer — read it
  /// together with [isChecked] before showing a tick.
  final bool isCorrect;

  /// Whether this turn was scored against a right answer at all.
  final bool isChecked;

  /// A describer's clue rather than a guess.
  final bool isClue;

  final DateTime timestamp;

  const CollabTurn({
    required this.playerIndex,
    required this.content,
    this.isCorrect = true,
    this.isChecked = false,
    this.isClue = false,
    required this.timestamp,
  });
}

/// A cooperative session between two players sharing one device.
///
/// The rules live here as **pure functions** — [applyTurn] takes a session and
/// an answer and returns the next session — so the whole of Peer Collab's
/// behaviour is unit-testable without a widget, and the screen holds no game
/// logic beyond calling it.
///
/// Cooperative, not competitive: a right guess scores for *both* players,
/// because the describer earned it as much as the guesser. The screen shows one
/// team total; the per-player counts are kept so each child can see they
/// contributed.
@immutable
class CollabSession {
  final String id;
  final CollabActivityType activityType;
  final String player1Name;
  final String player2Name;

  /// One target per round, fixed when the session starts. Rotating through this
  /// list is what gives each round a different word.
  final List<CollabRound> rounds;

  /// 0-based index into [rounds]. Equals `rounds.length` once finished.
  final int roundIndex;

  final int currentPlayerIndex;
  final List<CollabTurn> turns;
  final int player1Score;
  final int player2Score;

  /// Word Relay: the letters of the current round's word revealed so far.
  final String revealed;

  /// Word Relay: consecutive wrong attempts at the *current* letter.
  final int wrongAttempts;

  /// Guessing activities: the describer has given their clue, so it is the
  /// guesser's turn.
  final bool clueGiven;

  const CollabSession({
    required this.id,
    required this.activityType,
    required this.player1Name,
    required this.player2Name,
    required this.rounds,
    this.roundIndex = 0,
    this.currentPlayerIndex = 0,
    this.turns = const [],
    this.player1Score = 0,
    this.player2Score = 0,
    this.revealed = '',
    this.wrongAttempts = 0,
    this.clueGiven = false,
  });

  /// Recorded as a clue's content when the describer clued **out loud or in
  /// sign** and simply passed the tablet, rather than typing anything.
  ///
  /// It exists so the guesser is never shown the pass button's own label
  /// ("Done — pass to Ben") dressed up as a hint. Kept here rather than in the
  /// screen so the rule travels with the turn it describes.
  static const String spokenClue = '__spoken__';

  /// After two wrong tries the letter is given away — no point, but the pair
  /// never gets stuck on one blank. Free-text entry could otherwise loop
  /// forever, and a learner who needs the tap surface needs a way out too.
  static const int mercyAfterWrongAttempts = 2;

  int get roundsTotal => rounds.length;

  /// 1-based, and clamped so a finished session still reads "5/5" rather than
  /// "6/5".
  int get roundsCurrent =>
      isComplete ? roundsTotal : (roundIndex + 1).clamp(1, roundsTotal);

  bool get isComplete => roundIndex >= rounds.length;

  /// The round being played, or null once the session is over.
  CollabRound? get currentRound =>
      isComplete ? null : rounds[roundIndex];

  /// Which player clues this round. Alternates every round, so both children
  /// get to describe — the old build left Player 1 describing all five rounds.
  int get describerIndex => activityType.hasRoles ? roundIndex % 2 : -1;

  int get guesserIndex => describerIndex == 0 ? 1 : 0;

  /// True when the player to move is cluing rather than answering.
  bool get isCluePhase => activityType.hasRoles && !clueGiven;

  /// The clue the describer **wrote** for the round in play, or null when they
  /// clued aloud or in sign instead (or have not clued yet).
  ///
  /// A round holds at most one clue, and [clueGiven] resets with the round, so
  /// the most recent clue turn is always this round's. [spokenClue] is filtered
  /// here rather than in the widget so nothing downstream can accidentally
  /// render the marker as if it were a hint.
  CollabTurn? get writtenClue {
    if (!activityType.hasRoles || !clueGiven) return null;
    for (final turn in turns.reversed) {
      if (!turn.isClue) continue;
      final text = turn.content.trim();
      if (text.isEmpty || text == spokenClue) return null;
      return turn;
    }
    return null;
  }

  String get currentPlayerName => nameOf(currentPlayerIndex);

  String nameOf(int index) => index == 0 ? player1Name : player2Name;

  /// The pair's combined score — what the finish card leads with.
  int get teamScore => player1Score + player2Score;

  /// The highest [teamScore] this session could reach, so the finish card can
  /// say "8 of 10" instead of a bare number.
  int get maxTeamScore => switch (activityType) {
        // Both players score on a right guess, once per round.
        CollabActivityType.pictureGuess ||
        CollabActivityType.signChallenge =>
          rounds.length * 2,
        // One point per letter, to whoever placed it.
        CollabActivityType.wordRelay =>
          rounds.fold(0, (sum, r) => sum + r.word.length),
        // One point per contribution, two per round.
        CollabActivityType.storyBuilder => rounds.length * 2,
      };

  /// Word Relay: the letter the next turn has to produce, or null when the
  /// round's word is complete.
  String? get expectedLetter {
    final round = currentRound;
    if (round == null || activityType != CollabActivityType.wordRelay) {
      return null;
    }
    if (revealed.length >= round.word.length) return null;
    return round.word[revealed.length].toLowerCase();
  }

  /// Apply one contribution and return the resulting session.
  ///
  /// Pure: no clock beyond [now], no I/O, no randomness. Everything the screen
  /// needs to render the outcome — whether it was right, whose turn it is now,
  /// which round we are on — is derivable from the session it returns.
  CollabSession applyTurn(String content, {DateTime? now}) {
    final round = currentRound;
    final text = content.trim();
    if (round == null || text.isEmpty) return this;
    final stamp = now ?? DateTime.now();

    return switch (activityType) {
      CollabActivityType.wordRelay => _applyRelayTurn(round, text, stamp),
      CollabActivityType.storyBuilder => _applyStoryTurn(text, stamp),
      CollabActivityType.pictureGuess ||
      CollabActivityType.signChallenge =>
        _applyGuessTurn(round, text, stamp),
    };
  }

  // ─── Per-activity rules ───────────────────────────────

  /// One letter per turn, checked against the word. Only ever reveals a single
  /// letter, so a multi-character answer can no longer fill every blank at
  /// once, and a wrong letter reveals nothing at all.
  CollabSession _applyRelayTurn(
      CollabRound round, String text, DateTime stamp) {
    final expected = expectedLetter;
    if (expected == null) return this;

    // Forgiving on shape, strict on the letter: a learner who types the whole
    // word is treated as offering its first letter.
    final offered = text[0].toLowerCase();
    final correct = offered == expected;
    final mercy =
        !correct && wrongAttempts + 1 >= mercyAfterWrongAttempts;

    final nextRevealed =
        correct || mercy ? revealed + round.word[revealed.length] : revealed;
    final roundDone = nextRevealed.length >= round.word.length;

    return _record(
      turn: CollabTurn(
        playerIndex: currentPlayerIndex,
        content: text[0].toUpperCase(),
        isCorrect: correct,
        isChecked: true,
        timestamp: stamp,
      ),
      // Only a genuine hit scores; a given-away letter does not.
      scoreTo: correct ? currentPlayerIndex : null,
      advanceRound: roundDone,
      nextRevealed: roundDone ? '' : nextRevealed,
      // Reset the counter whenever the blank moves on.
      nextWrongAttempts: correct || mercy ? 0 : wrongAttempts + 1,
    );
  }

  /// Open by design — see [CollabActivityTypeExt.isOpenEnded]. A round is two
  /// contributions, one each.
  CollabSession _applyStoryTurn(String text, DateTime stamp) {
    final turnsThisRound = turns.length - (roundIndex * 2);
    return _record(
      turn: CollabTurn(
        playerIndex: currentPlayerIndex,
        content: text,
        timestamp: stamp,
      ),
      scoreTo: currentPlayerIndex,
      advanceRound: turnsThisRound + 1 >= 2,
    );
  }

  /// Describer clues, guesser answers, the guess is checked. A right guess
  /// scores for both — that is the cooperative bit.
  CollabSession _applyGuessTurn(
      CollabRound round, String text, DateTime stamp) {
    if (isCluePhase) {
      return _record(
        turn: CollabTurn(
          playerIndex: currentPlayerIndex,
          content: text,
          isClue: true,
          timestamp: stamp,
        ),
        nextClueGiven: true,
      );
    }

    final correct = round.accepts(text);
    return _record(
      turn: CollabTurn(
        playerIndex: currentPlayerIndex,
        content: text,
        isCorrect: correct,
        isChecked: true,
        timestamp: stamp,
      ),
      scoreBoth: correct,
      // Right or wrong the pair moves on: the answer is shown either way, and
      // a round that cannot end is a round a child can be trapped in.
      advanceRound: true,
      nextClueGiven: false,
    );
  }

  // ─── Shared bookkeeping ───────────────────────────────

  /// Appends [turn], applies its scoring, and works out who moves next.
  ///
  /// Turn order is the one rule every activity shares: within a round players
  /// alternate, and a new round opens with whoever that round's roles say
  /// starts it (the describer for a guessing activity, otherwise the player
  /// whose turn it is to lead).
  CollabSession _record({
    required CollabTurn turn,
    int? scoreTo,
    bool scoreBoth = false,
    bool advanceRound = false,
    bool? nextClueGiven,
    String? nextRevealed,
    int? nextWrongAttempts,
  }) {
    var p1 = player1Score;
    var p2 = player2Score;
    if (scoreBoth) {
      p1 += 1;
      p2 += 1;
    } else if (scoreTo == 0) {
      p1 += 1;
    } else if (scoreTo == 1) {
      p2 += 1;
    }

    final nextRoundIndex = advanceRound ? roundIndex + 1 : roundIndex;
    final finished = nextRoundIndex >= rounds.length;

    final int nextPlayer;
    if (finished) {
      nextPlayer = currentPlayerIndex;
    } else if (advanceRound) {
      // A new round opens with whoever leads it, and the lead alternates round
      // by round so neither child always goes first. For a guessing activity
      // that same alternation *is* [describerIndex], which is why the describer
      // rotates without needing a rule of its own.
      nextPlayer = nextRoundIndex % 2;
    } else {
      nextPlayer = currentPlayerIndex == 0 ? 1 : 0;
    }

    return copyWith(
      turns: [...turns, turn],
      roundIndex: nextRoundIndex,
      currentPlayerIndex: nextPlayer,
      player1Score: p1,
      player2Score: p2,
      revealed: advanceRound ? '' : (nextRevealed ?? revealed),
      wrongAttempts: advanceRound ? 0 : (nextWrongAttempts ?? wrongAttempts),
      clueGiven: advanceRound ? false : (nextClueGiven ?? clueGiven),
    );
  }

  CollabSession copyWith({
    List<CollabRound>? rounds,
    int? roundIndex,
    int? currentPlayerIndex,
    List<CollabTurn>? turns,
    int? player1Score,
    int? player2Score,
    String? revealed,
    int? wrongAttempts,
    bool? clueGiven,
  }) {
    return CollabSession(
      id: id,
      activityType: activityType,
      player1Name: player1Name,
      player2Name: player2Name,
      rounds: rounds ?? this.rounds,
      roundIndex: roundIndex ?? this.roundIndex,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      turns: turns ?? this.turns,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      revealed: revealed ?? this.revealed,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      clueGiven: clueGiven ?? this.clueGiven,
    );
  }
}
