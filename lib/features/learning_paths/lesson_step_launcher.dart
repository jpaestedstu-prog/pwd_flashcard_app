import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../data/models/learning_path.dart';

/// Launches the activity for a single [LessonStep] within [path].
///
/// Shared routing logic for both the lesson timeline ([LessonScreen]) and the
/// winding lesson trail ([LessonTrailScreen]) so a step always opens the same
/// way regardless of which view the learner tapped it from.
void launchLessonStep(BuildContext context, LessonStep step, LearningPath path) {
  final stepIndex = path.steps.indexOf(step);
  final totalSteps = path.steps.length;

  switch (step.type) {
    case LessonStepType.flashcards:
      context.push(
        '/learning-path-viewer/${path.category.index}'
        '?pathId=${path.id}&stepIndex=$stepIndex&totalSteps=$totalSteps',
      );
      break;
    case LessonStepType.game:
    case LessonStepType.quiz:
      if (step.gameType != null) {
        final gameRoute = switch (step.gameType!) {
          GameType.wordMatch => 'word-match',
          GameType.spellingBee => 'spelling-bee',
          GameType.memoryMatch => 'memory-match',
          GameType.dragAndDrop => 'drag-drop',
          GameType.flashcardQuiz => 'flashcard-quiz',
          GameType.pronunciation => 'pronunciation',
          GameType.sentenceBuilder => 'sentence-builder',
          GameType.storyQuiz => 'flashcard-quiz',
          GameType.tracing => 'tracing',
          GameType.fslPractice => 'fsl-practice',
          GameType.jigsawPuzzle => 'jigsaw-puzzle',
          GameType.pictureWord => 'picture-word',
        };
        final difficulty = step.gameDifficulty?.name ?? 'medium';
        context.push(
          '/games/$gameRoute?difficulty=$difficulty&categories=${path.category.index}',
        );
      }
      break;
    case LessonStepType.story:
      context.push('/stories');
      break;
    case LessonStepType.smartReview:
      context.push('/smart-review');
      break;
  }
}
