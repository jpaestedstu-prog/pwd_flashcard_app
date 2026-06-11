import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/quiz_race_player.dart';

/// Verifies the pause behaviour the player widgets expose: while `isPaused` is
/// true the post-answer auto-advance must NOT fire (otherwise the game would
/// advance behind the pause overlay), and it must resume cleanly afterwards.
void main() {
  testWidgets('QuizRacePlayer suspends auto-advance while paused',
      (tester) async {
    int finishedScore = -1;
    const questions = [
      MpQuestion(
        prompt: 'dog',
        promptLabel: 'What is this in Filipino?',
        options: ['aso', 'pusa'],
        correctIndex: 0,
      ),
    ];

    Widget build(bool paused) => MaterialApp(
          home: Scaffold(
            body: QuizRacePlayer(
              questions: questions,
              isPaused: paused,
              onFinished: (s) => finishedScore = s,
            ),
          ),
        );

    await tester.pumpWidget(build(false));
    await tester.tap(find.text('aso'));
    await tester.pump(); // register the answer (schedules the 900ms advance)

    // Pause before the advance fires.
    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(finishedScore, -1, reason: 'must not finish while paused');

    // Resume → the owed advance reschedules and fires.
    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(finishedScore, 1, reason: 'finishes after resuming');
  });
}
