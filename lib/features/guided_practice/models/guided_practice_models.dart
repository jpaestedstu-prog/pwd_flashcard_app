import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// Types of steps in a guided practice session
enum PracticeStepType {
  flashcardReview,
  listenAndRepeat,
  fillInBlank,
  matchPair,
  miniQuiz,
}

extension PracticeStepTypeX on PracticeStepType {
  String get label => switch (this) {
        PracticeStepType.flashcardReview => 'Review',
        PracticeStepType.listenAndRepeat => 'Listen & Repeat',
        PracticeStepType.fillInBlank => 'Fill in the Blank',
        PracticeStepType.matchPair => 'Match',
        PracticeStepType.miniQuiz => 'Quiz',
      };

  String get labelFilipino => switch (this) {
        PracticeStepType.flashcardReview => 'Suriin',
        PracticeStepType.listenAndRepeat => 'Pakinggan at Ulitin',
        PracticeStepType.fillInBlank => 'Punan ang Patlang',
        PracticeStepType.matchPair => 'Ipares',
        PracticeStepType.miniQuiz => 'Pagsusulit',
      };

  String get emoji => switch (this) {
        PracticeStepType.flashcardReview => '📖',
        PracticeStepType.listenAndRepeat => '🔊',
        PracticeStepType.fillInBlank => '✏️',
        PracticeStepType.matchPair => '🔗',
        PracticeStepType.miniQuiz => '❓',
      };
}

/// A single step in a guided practice session
class PracticeStep {
  final PracticeStepType type;
  final Flashcard targetCard;
  final String? hint;
  final List<String>? options; // For quiz / match steps
  final bool isCompleted;
  final bool? wasCorrect;

  const PracticeStep({
    required this.type,
    required this.targetCard,
    this.hint,
    this.options,
    this.isCompleted = false,
    this.wasCorrect,
  });

  PracticeStep copyWith({
    bool? isCompleted,
    bool? wasCorrect,
  }) {
    return PracticeStep(
      type: type,
      targetCard: targetCard,
      hint: hint,
      options: options,
      isCompleted: isCompleted ?? this.isCompleted,
      wasCorrect: wasCorrect ?? this.wasCorrect,
    );
  }
}

/// A complete guided practice session
class GuidedPracticeSession {
  final FlashcardCategory category;
  final List<PracticeStep> steps;
  final int currentStepIndex;
  final int correctCount;
  final DateTime startedAt;

  const GuidedPracticeSession({
    required this.category,
    required this.steps,
    this.currentStepIndex = 0,
    this.correctCount = 0,
    required this.startedAt,
  });

  PracticeStep get currentStep => steps[currentStepIndex];
  bool get isComplete => currentStepIndex >= steps.length;
  int get totalSteps => steps.length;
  double get progress =>
      totalSteps > 0 ? currentStepIndex / totalSteps : 0.0;
  int get starsEarned {
    if (totalSteps == 0) return 0;
    final ratio = correctCount / totalSteps;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.7) return 2;
    if (ratio >= 0.5) return 1;
    return 0;
  }

  GuidedPracticeSession copyWith({
    List<PracticeStep>? steps,
    int? currentStepIndex,
    int? correctCount,
  }) {
    return GuidedPracticeSession(
      category: category,
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      correctCount: correctCount ?? this.correctCount,
      startedAt: startedAt,
    );
  }
}
