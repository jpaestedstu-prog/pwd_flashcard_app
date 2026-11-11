import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// One row of the button guide.
@immutable
class GamepadGuideEntry {
  /// What the learner presses, as printed on the controller.
  final String control;

  /// What it does, in the same voice the app uses out loud.
  final String meaning;

  const GamepadGuideEntry(this.control, this.meaning);
}

/// A titled block of the guide.
@immutable
class GamepadGuideGroup {
  final String title;
  final List<GamepadGuideEntry> entries;

  const GamepadGuideGroup(this.title, this.entries);
}

/// The complete control map, as data — one job per control.
///
/// Kept as a const list rather than inline widgets so a test can assert that
/// every [GamepadButton] with a real action appears here — a control that
/// works but is documented nowhere is, for a blind learner, a control that
/// does not exist.
const List<GamepadGuideGroup> kGamepadGuide = [
  GamepadGuideGroup('Moving around', [
    GamepadGuideEntry(
      'D-pad ▲ ▼ ◀ ▶',
      'Move the highlight up, down, left or right — to the tile beside it, '
          'or the control below it. A slider under the highlight turns with '
          '◀ and ▶.',
    ),
    GamepadGuideEntry(
      'Left joystick',
      'The same as the D-pad. It can be turned off above, for a learner who '
          'knocks it by accident.',
    ),
    GamepadGuideEntry(
      'L2 / R2',
      'The previous or next item, one at a time in reading order — for a '
          'learner who wants a single, predictable “next”. Each is read out '
          'with its position.',
    ),
    GamepadGuideEntry(
      'L1 / R1',
      'The previous or next section. The app asks before it switches — “Do '
          'you want to go to the Cards section?”',
    ),
  ]),
  GamepadGuideGroup('Choosing and leaving', [
    GamepadGuideEntry('A', 'Choose what is highlighted — press it, or open it'),
    GamepadGuideEntry('B', 'Go back, or close what is open'),
    GamepadGuideEntry(
      'A and B when a question is asked',
      'A answers yes and B answers no — confirm and cancel, as always. Every '
          'question says so out loud.',
    ),
  ]),
  GamepadGuideGroup('Listening', [
    GamepadGuideEntry('X', 'Read the whole screen — every item on it'),
    GamepadGuideEntry('Y', 'Say the last thing again'),
    GamepadGuideEntry('Start', 'Where am I? — the section and the item'),
    GamepadGuideEntry('Select', 'Speak this button guide'),
    GamepadGuideEntry(
      'Right joystick click',
      'Stop talking — cuts a long announcement short',
    ),
  ]),
  GamepadGuideGroup('Getting around faster', [
    GamepadGuideEntry('Right joystick ▲ / ▼', 'Scroll the page'),
    GamepadGuideEntry(
      'Right joystick ◀ / ▶',
      'Jump to the first or last item on the screen',
    ),
    GamepadGuideEntry('Left joystick click', 'Go straight to Home'),
  ]),
];

/// [kGamepadGuide] in Filipino — the same controls in the same order, so the
/// page a Filipino learner reads matches what the controller does.
const List<GamepadGuideGroup> kGamepadGuideFilipino = [
  GamepadGuideGroup('Paggalaw', [
    GamepadGuideEntry(
      'D-pad ▲ ▼ ◀ ▶',
      'Igalaw ang highlight pataas, pababa, pakaliwa o pakanan — sa katabing '
          'tile, o sa control sa ibaba nito. Ang slider na naka-highlight ay '
          'binabago ng ◀ at ▶.',
    ),
    GamepadGuideEntry(
      'Kaliwang joystick',
      'Tulad ng D-pad. Mapapatay ito sa itaas, para sa mag-aaral na '
          'natatamaan ito nang hindi sinasadya.',
    ),
    GamepadGuideEntry(
      'L2 / R2',
      'Ang nakaraan o susunod na item, isa-isa ayon sa pagkakasunod — para sa '
          'mag-aaral na gusto ng iisang tiyak na “susunod”. Binabasa ang bawat '
          'isa kasama ang puwesto nito.',
    ),
    GamepadGuideEntry(
      'L1 / R1',
      'Ang nakaraan o susunod na section. Nagtatanong muna ang app bago '
          'lumipat — “Gusto mo bang pumunta sa section ng Mga Kard?”',
    ),
  ]),
  GamepadGuideGroup('Pagpili at pag-alis', [
    GamepadGuideEntry('A', 'Piliin ang naka-highlight — pindutin o buksan ito'),
    GamepadGuideEntry('B', 'Bumalik, o isara ang nakabukas'),
    GamepadGuideEntry(
      'A at B kapag may tanong',
      'Ang A ay oo at ang B ay hindi — kumpirma at kanselahin, gaya ng dati. '
          'Sinasabi ito nang malakas sa bawat tanong.',
    ),
  ]),
  GamepadGuideGroup('Pakikinig', [
    GamepadGuideEntry('X', 'Basahin ang buong screen — lahat ng item dito'),
    GamepadGuideEntry('Y', 'Ulitin ang huling sinabi'),
    GamepadGuideEntry('Start', 'Nasaan ako? — ang section at ang item'),
    GamepadGuideEntry('Select', 'Sabihin ang gabay na ito sa mga button'),
    GamepadGuideEntry(
      'Pindot sa kanang joystick',
      'Tumigil sa pagsasalita — pinuputol ang mahabang anunsyo',
    ),
  ]),
  GamepadGuideGroup('Mas mabilis na paggalaw', [
    GamepadGuideEntry('Kanang joystick ▲ / ▼', 'Mag-scroll sa pahina'),
    GamepadGuideEntry(
      'Kanang joystick ◀ / ▶',
      'Tumalon sa una o huling item sa screen',
    ),
    GamepadGuideEntry('Pindot sa kaliwang joystick', 'Dumiretso sa Home'),
  ]),
];

/// The button guide, rendered as a readable page.
///
/// Every row is a [Semantics] pair so a learner using TalkBack alongside the
/// controller hears "A, choose what is highlighted" as one utterance rather
/// than two disconnected fragments.
class GamepadGuide extends StatelessWidget {
  const GamepadGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group
            in Localizations.localeOf(context).languageCode == 'fil'
                ? kGamepadGuideFilipino
                : kGamepadGuide) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              group.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: HCColor.of(context).readable(AppColors.primaryDark),
              ),
            ),
          ),
          for (final entry in group.entries)
            _GuideRow(control: entry.control, meaning: entry.meaning),
        ],
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  final String control;
  final String meaning;

  const _GuideRow({required this.control, required this.meaning});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        control,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: HCColor.of(context).readable(AppColors.primaryDark),
        ),
      ),
    );
    const meaningStyle = TextStyle(fontSize: 13, height: 1.35);
    return Semantics(
      label: '$control. $meaning',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Side by side while the meaning keeps ~14 characters a line
            // beside the chip; else the chip goes above it. A long control
            // name ("A and B while a question is asked") at large text on a
            // phone squeezed the meaning to one letter a line, or past the
            // edge. 0.58 em a character, as FitText estimates.
            final scaler = MediaQuery.textScalerOf(context);
            final chipWidth =
                (control.length * 0.58 * scaler.scale(12.5) + 22)
                    .clamp(74.0, constraints.maxWidth * 0.45);
            final meaningRoom = constraints.maxWidth - chipWidth - 12;
            if (meaningRoom < 14 * 0.58 * scaler.scale(13)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chip,
                  const SizedBox(height: 4),
                  Text(meaning, style: meaningStyle),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                  child: chip,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(meaning, style: meaningStyle),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
