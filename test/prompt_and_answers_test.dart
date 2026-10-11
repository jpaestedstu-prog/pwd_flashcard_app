import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/games/widgets/prompt_and_answers.dart';

/// Word Match, Picture-Word and Pronunciation put their prompt above their
/// answers. Held sideways on a phone that left the answers ~120 dp and two
/// of four out of reach; there the prompt now sits beside the answers.

const _prompt = Key('prompt');
const _answers = Key('answers');

Future<void> _pump(WidgetTester tester, Size size, {int promptFlex = 3}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: PromptAndAnswers(
            promptFlex: promptFlex,
            answersFlex: 3,
            prompt: promptFlex == 0
                ? const SizedBox(key: _prompt, height: 80)
                : const SizedBox.expand(key: _prompt),
            answers: const SizedBox.expand(key: _answers),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('upright: stacked exactly as the games had it', (tester) async {
    await _pump(tester, const Size(360, 600));
    final prompt = tester.getRect(find.byKey(_prompt));
    final answers = tester.getRect(find.byKey(_answers));
    expect(prompt.height, answers.height);
    expect(answers.top - prompt.bottom, 24);
    expect(prompt.width, 360);
  });

  testWidgets('a short wide space: side by side, both full height',
      (tester) async {
    await _pump(tester, const Size(860, 300));
    final prompt = tester.getRect(find.byKey(_prompt));
    final answers = tester.getRect(find.byKey(_answers));
    expect(prompt.height, 300);
    expect(answers.height, 300);
    expect(answers.left, greaterThan(prompt.right));
  });

  testWidgets('a natural-height prompt stays natural upright', (tester) async {
    await _pump(tester, const Size(360, 600), promptFlex: 0);
    expect(tester.getSize(find.byKey(_prompt)).height, 80);
    expect(tester.getSize(find.byKey(_answers)).height, 600 - 80 - 24);
  });

  test('which spaces count as short and wide', () {
    expect(PromptAndAnswers.sideBySide(
        BoxConstraints.tight(const Size(860, 300))), isTrue);
    expect(PromptAndAnswers.sideBySide(
        BoxConstraints.tight(const Size(360, 600))), isFalse);
    // A big tablet sideways has the height to stack.
    expect(PromptAndAnswers.sideBySide(
        BoxConstraints.tight(const Size(1280, 700))), isFalse);
  });
}
