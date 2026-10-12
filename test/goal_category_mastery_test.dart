import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/goals/models/goal_model.dart';
import 'package:pwdpwdpwd/features/goals/services/goal_service.dart';

/// A "Reach 80% mastery in Animals" goal counts the share of the category's
/// words the learner has actually learned. It used to read
/// `categoryProgress`, a rolling accuracy average: five perfect three-question
/// games completed a goal over a category of twenty words.
void main() {
  LearningGoal goal(GoalType type, {FlashcardCategory? category}) => LearningGoal(
        id: 'g',
        title: 'goal',
        type: type,
        targetValue: 80,
        createdAt: DateTime(2026, 10, 13),
        category: category,
        createdBy: 'learner',
      );

  // Very accurate on the few words played.
  final progress = LearningProgress(
    profileId: 'p',
    wordsLearned: 4,
    lastActivityDate: DateTime(2026, 10, 13),
    categoryProgress: {FlashcardCategory.animals.label: 0.95},
  );

  test('counts the words learned, not accuracy', () {
    final value = GoalService.computeCurrentValue(
      goal(GoalType.categoryMastery, category: FlashcardCategory.animals),
      progress,
      {FlashcardCategory.animals: 0.2},
    );
    expect(value, 20);
  });

  test('completes once most of the words are learned', () {
    final value = GoalService.computeCurrentValue(
      goal(GoalType.categoryMastery, category: FlashcardCategory.animals),
      progress,
      {FlashcardCategory.animals: 0.85},
    );
    expect(value, 85);
    expect(
      goal(GoalType.categoryMastery, category: FlashcardCategory.animals)
          .copyWith(currentValue: value)
          .isCompleted,
      isTrue,
    );
  });

  test('a category not started counts nothing', () {
    expect(
      GoalService.computeCurrentValue(
        goal(GoalType.categoryMastery, category: FlashcardCategory.colorsAndShapes),
        progress,
        {FlashcardCategory.animals: 0.85},
      ),
      0,
    );
  });

  test('other goals are unchanged', () {
    expect(
      GoalService.computeCurrentValue(goal(GoalType.wordsLearned), progress, const {}),
      4,
    );
  });
}
