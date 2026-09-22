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

/// The complete control map, as data.
///
/// Kept as a const list rather than inline widgets so a test can assert that
/// every [GamepadButton] with a real action appears here — a control that
/// works but is documented nowhere is, for a blind learner, a control that
/// does not exist.
const List<GamepadGuideGroup> kGamepadGuide = [
  GamepadGuideGroup('Moving around', [
    GamepadGuideEntry(
      'D-pad ◀ / ▶',
      'Move between sections. The app asks before it switches — “Do you want '
          'to go to the Cards section?”',
    ),
    GamepadGuideEntry(
      'D-pad ▲ / ▼',
      'Move between the items on the current screen, one at a time, in '
          'reading order. Each one is read out with its position.',
    ),
    GamepadGuideEntry(
      'Left joystick',
      'The same as the D-pad — push left or right for sections, up or down '
          'for items.',
    ),
  ]),
  GamepadGuideGroup('Face buttons', [
    GamepadGuideEntry('X (left)', 'Previous section — same as D-pad ◀'),
    GamepadGuideEntry('B (right)', 'Next section — same as D-pad ▶'),
    GamepadGuideEntry('Y (up)', 'Previous item — same as D-pad ▲'),
    GamepadGuideEntry('A (down)', 'Next item — same as D-pad ▼'),
    GamepadGuideEntry(
      'A and B while a question is asked',
      'A answers yes, B answers no. Every question says so out loud, so the '
          'change is never a surprise.',
    ),
  ]),
  GamepadGuideGroup('Choosing and leaving', [
    GamepadGuideEntry('R1', 'Open the item you are on'),
    GamepadGuideEntry('L1', 'Go back, or close what is open'),
  ]),
  GamepadGuideGroup('Listening', [
    GamepadGuideEntry('R2', 'Read the whole screen — every item on it'),
    GamepadGuideEntry('L2', 'Say the last thing again'),
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
      'D-pad ◀ / ▶',
      'Lumipat ng section. Nagtatanong muna ang app bago lumipat — “Gusto mo '
          'bang pumunta sa section ng Mga Kard?”',
    ),
    GamepadGuideEntry(
      'D-pad ▲ / ▼',
      'Lumipat sa mga item sa kasalukuyang screen, isa-isa, ayon sa '
          'pagkakasunod. Binabasa ang bawat isa kasama ang puwesto nito.',
    ),
    GamepadGuideEntry(
      'Kaliwang joystick',
      'Tulad ng D-pad — itulak pakaliwa o pakanan para sa section, pataas o '
          'pababa para sa item.',
    ),
  ]),
  GamepadGuideGroup('Mga button sa harap', [
    GamepadGuideEntry('X (kaliwa)', 'Nakaraang section — tulad ng D-pad ◀'),
    GamepadGuideEntry('B (kanan)', 'Susunod na section — tulad ng D-pad ▶'),
    GamepadGuideEntry('Y (taas)', 'Nakaraang item — tulad ng D-pad ▲'),
    GamepadGuideEntry('A (baba)', 'Susunod na item — tulad ng D-pad ▼'),
    GamepadGuideEntry(
      'A at B habang may tanong',
      'Ang A ay oo, ang B ay hindi. Sinasabi ito nang malakas sa bawat tanong, '
          'kaya hindi ito nakagugulat.',
    ),
  ]),
  GamepadGuideGroup('Pagpili at pag-alis', [
    GamepadGuideEntry('R1', 'Buksan ang item na kinalalagyan mo'),
    GamepadGuideEntry('L1', 'Bumalik, o isara ang nakabukas'),
  ]),
  GamepadGuideGroup('Pakikinig', [
    GamepadGuideEntry('R2', 'Basahin ang buong screen — lahat ng item dito'),
    GamepadGuideEntry('L2', 'Ulitin ang huling sinabi'),
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
/// controller hears "R1, open the item you are on" as one utterance rather
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: AppColors.primaryDark,
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
    return Semantics(
      label: '$control. $meaning',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  meaning,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
