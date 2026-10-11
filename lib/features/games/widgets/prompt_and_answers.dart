import 'package:flutter/widgets.dart';

/// A game's prompt above its answers — or, on a short wide screen (a phone
/// held sideways), the prompt beside its answers, both with the whole height.
///
/// Stacked on a phone held sideways, the answers of Word Match, Picture-Word
/// and Pronunciation got about 120 dp: two of four answers showed and the
/// rest were out of reach. Upright, nothing changes — [promptFlex] and
/// [answersFlex] share the height exactly as the games' own columns did
/// ([promptFlex] 0 keeps the prompt at its natural height, as Picture-Word's
/// word prompt is).
class PromptAndAnswers extends StatelessWidget {
  const PromptAndAnswers({
    super.key,
    required this.prompt,
    required this.answers,
    this.promptFlex = 1,
    this.answersFlex = 1,
    this.gap = 24,
  });

  final Widget prompt;
  final Widget answers;
  final int promptFlex;
  final int answersFlex;
  final double gap;

  /// Whether [box] is the short wide space that gets the side-by-side
  /// arrangement.
  static bool sideBySide(BoxConstraints box) =>
      box.maxWidth > box.maxHeight * 1.3 && box.maxHeight < 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (sideBySide(box)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: promptFlex == 0 ? 2 : promptFlex,
                child: promptFlex == 0
                    ? Center(child: SingleChildScrollView(child: prompt))
                    : prompt,
              ),
              SizedBox(width: gap * 0.75),
              Expanded(flex: promptFlex == 0 ? 3 : answersFlex, child: answers),
            ],
          );
        }
        return Column(
          children: [
            if (promptFlex == 0)
              prompt
            else
              Expanded(flex: promptFlex, child: prompt),
            SizedBox(height: gap),
            Expanded(flex: answersFlex, child: answers),
          ],
        );
      },
    );
  }
}
