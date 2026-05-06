import 'package:flutter/material.dart';

/// Types of collaborative activities
enum CollabActivityType {
  wordRelay,
  pictureGuess,
  signChallenge,
  storyBuilder,
}

extension CollabActivityTypeExt on CollabActivityType {
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

  String get labelFilipino {
    switch (this) {
      case CollabActivityType.wordRelay:
        return 'Word Relay';
      case CollabActivityType.pictureGuess:
        return 'Hulaan ang Larawan';
      case CollabActivityType.signChallenge:
        return 'Sign Challenge';
      case CollabActivityType.storyBuilder:
        return 'Story Builder';
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
        return 'Practice sign language together';
      case CollabActivityType.storyBuilder:
        return 'Build a story together, one sentence at a time';
    }
  }

  String get descriptionFilipino {
    switch (this) {
      case CollabActivityType.wordRelay:
        return 'Mag-spell ng salita nang isa-isang letra';
      case CollabActivityType.pictureGuess:
        return 'Isang manlalaro ang mag-describe, ang isa ang huhula';
      case CollabActivityType.signChallenge:
        return 'Mag-practice ng sign language nang magkasama';
      case CollabActivityType.storyBuilder:
        return 'Gumawa ng kwento nang magkasama, isang pangungusap sa isang pagkakataon';
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
}

/// Represents a turn in a collaborative activity
class CollabTurn {
  final int playerIndex; // 0 or 1
  final String content;
  final bool isCorrect;
  final DateTime timestamp;

  const CollabTurn({
    required this.playerIndex,
    required this.content,
    this.isCorrect = true,
    required this.timestamp,
  });
}

/// A collaborative session between two players
class CollabSession {
  final String id;
  final CollabActivityType activityType;
  final String player1Name;
  final String player2Name;
  final List<CollabTurn> turns;
  final int currentPlayerIndex;
  final String? targetWord;
  final int player1Score;
  final int player2Score;
  final int roundsTotal;
  final int roundsCurrent;
  final bool isComplete;

  const CollabSession({
    required this.id,
    required this.activityType,
    required this.player1Name,
    required this.player2Name,
    this.turns = const [],
    this.currentPlayerIndex = 0,
    this.targetWord,
    this.player1Score = 0,
    this.player2Score = 0,
    this.roundsTotal = 5,
    this.roundsCurrent = 1,
    this.isComplete = false,
  });

  String get currentPlayerName =>
      currentPlayerIndex == 0 ? player1Name : player2Name;

  CollabSession copyWith({
    List<CollabTurn>? turns,
    int? currentPlayerIndex,
    String? targetWord,
    int? player1Score,
    int? player2Score,
    int? roundsCurrent,
    bool? isComplete,
  }) {
    return CollabSession(
      id: id,
      activityType: activityType,
      player1Name: player1Name,
      player2Name: player2Name,
      turns: turns ?? this.turns,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      targetWord: targetWord ?? this.targetWord,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      roundsTotal: roundsTotal,
      roundsCurrent: roundsCurrent ?? this.roundsCurrent,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
