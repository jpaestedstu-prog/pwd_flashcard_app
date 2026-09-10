import '../models/gamepad_button.dart';
import 'gamepad_actions.dart';

/// Every sentence the gamepad speaks, in both app languages.
///
/// Kept as a pure phrase builder — no TTS, no widgets — so the wording is
/// unit-testable and lives in exactly one place. For a learner who cannot see
/// the screen these strings *are* the interface, so they follow three rules:
///
/// * **Say where you are before what to do.** "Cards, 2 of 8" orients first.
/// * **Never ask a question without saying how to answer it.** Every prompt
///   ends with the two buttons that answer it, because A and B change meaning
///   while a question is open.
/// * **Count out loud.** "2 of 8" is the only way to know a list has an end.
class GamepadPhrases {
  /// 'en' or 'fil' — anything else falls back to English.
  final String locale;

  const GamepadPhrases(this.locale);

  bool get _fil => locale == 'fil';

  /// Spoken once, when a controller connects and the app is ready to drive.
  String welcome(String section) => _fil
      ? 'Kumusta, maligayang pagdating! Nasa $section section ka na ngayon. '
          'Pindutin ang Select para marinig ang gabay sa mga button.'
      : 'Hello, welcome! You\'re now in the $section section. '
          'Press Select any time to hear the button guide.';

  /// The confirm question. Always names both answer buttons.
  String sectionQuestion(String section) => _fil
      ? 'Gusto mo bang pumunta sa $section section? '
          'Pindutin ang A para sa oo, B para sa hindi.'
      : 'Do you want to go to the $section section? '
          'Press A for yes, B for no.';

  /// Confirmation that the move happened.
  String sectionEntered(String section) => _fil
      ? 'Nasa $section section ka na ngayon.'
      : 'You\'re now in the $section section.';

  /// Nothing to walk to — a shell with a single section (the guest Player).
  String get noSections => _fil
      ? 'Walang ibang section dito.'
      : 'There are no other sections here.';

  /// One item under the cursor. [position] is 1-based.
  ///
  /// [detail] is a second line the screen supplied — a translation, a hint —
  /// spoken after the position so the count stays in a predictable place.
  /// [unavailable] marks a control that is present but cannot be used: a
  /// learner who cannot see it greyed out needs to be told, or they will press
  /// it and conclude the controller is broken.
  String item(
    String label,
    int position,
    int total, {
    String? detail,
    bool unavailable = false,
  }) {
    final head = _fil
        ? '$label, $position ng $total.'
        : '$label, $position of $total.';
    final extra = (detail == null || detail.trim().isEmpty) ? '' : ' ${detail.trim()}';
    final blocked = unavailable
        ? (_fil ? ' Hindi pa magagamit.' : ' Not available yet.')
        : '';
    return '$head$extra$blocked';
  }

  /// Pressing a control that is present but disabled.
  String notAvailable(String label) => _fil
      ? '$label ay hindi pa magagamit.'
      : '$label is not available yet.';

  /// The full reading of a screen that published itself: its prose first, then
  /// what can be chosen.
  ///
  /// Prose leads because it is the part a learner cannot get any other way —
  /// the buttons can be discovered by stepping through them, but the question
  /// the quiz is asking cannot.
  String screenReading(String title, List<String> prose, List<String> choices) {
    final parts = <String>[];
    final heading = title.trim();
    if (heading.isNotEmpty) parts.add('$heading.');
    for (final line in prose) {
      final text = line.trim();
      if (text.isEmpty) continue;
      // Screens whose first line of prose *is* their title — both game pickers
      // do this — would otherwise open by saying the name twice, which sounds
      // like a stutter rather than a heading.
      if (text == heading) continue;
      // Screen copy is written for the eye and often ends in "!" or "?".
      // Appending a full stop regardless produced "Choose a mode below!." —
      // which some TTS voices actually pronounce.
      parts.add(_endsSentence(text) ? text : '$text.');
    }
    if (choices.isEmpty) {
      parts.add(_fil
          ? 'Walang mapipili dito. Pindutin ang L1 para bumalik.'
          : 'There is nothing to choose here. Press L1 to go back.');
    } else {
      final named = choices.take(maxSpokenItems).toList();
      final remaining = choices.length - named.length;
      final list = named.join(', ');
      final more = remaining <= 0
          ? ''
          : (_fil ? ', at $remaining pa' : ', and $remaining more');
      // "1 choices" is the kind of small wrongness that makes a synthetic
      // voice sound careless, and this line is read on every screen.
      final noun = choices.length == 1
          ? (_fil ? 'pagpipilian' : 'choice')
          : (_fil ? 'pagpipilian' : 'choices');
      parts.add(_fil
          ? 'May ${choices.length} $noun: $list$more.'
          : '${choices.length} $noun: $list$more.');
    }
    return parts.join(' ');
  }

  /// Whether a line already ends in sentence punctuation, so the reader does
  /// not staple a second full stop onto it.
  static bool _endsSentence(String text) {
    if (text.isEmpty) return false;
    return '.!?:'.contains(text[text.length - 1]);
  }

  /// The screen published nothing addressable.
  String get nothingHere => _fil
      ? 'Walang mapipiling item sa screen na ito. '
          'Pindutin ang L1 para bumalik.'
      : 'There are no items to choose on this screen. '
          'Press L1 to go back.';

  /// Opening something.
  String opening(String label) =>
      _fil ? 'Binubuksan ang $label.' : 'Opening $label.';

  /// A press that had nothing to press.
  String get nothingToOpen => _fil
      ? 'Walang mabubuksan dito.'
      : 'There is nothing to open here.';

  String get goingBack => _fil ? 'Bumabalik.' : 'Going back.';

  /// Back was pressed at the root — there is nowhere further back to go.
  String get cannotGoBack => _fil
      ? 'Ito na ang pangunahing screen. Walang mababalikan.'
      : 'You\'re at the main screen. There\'s nothing to go back to.';

  /// Answer to Start — "where am I?".
  String whereAmI(String section, String? item) {
    if (item == null) {
      return _fil
          ? 'Nasa $section section ka.'
          : 'You\'re in the $section section.';
    }
    return _fil
        ? 'Nasa $section section ka. Nakatutok sa $item.'
        : 'You\'re in the $section section. Focused on $item.';
  }

  /// How many items a screen reading will name before summarising the rest.
  /// A Home screen with every vocabulary category published can run past
  /// forty cells, and a two-minute monologue the learner cannot interrupt is
  /// worse than no list at all.
  static const int maxSpokenItems = 12;

  /// Answer to R2 — everything reachable here, read as one list.
  String screenContents(String section, List<String> items) {
    if (items.isEmpty) {
      return _fil
          ? 'Ang $section section. $nothingHere'
          : 'The $section section. $nothingHere';
    }
    final named = items.take(maxSpokenItems).toList();
    final remaining = items.length - named.length;
    final list = named.join(', ');
    final tail = remaining <= 0
        ? '.'
        : (_fil ? ', at $remaining pa.' : ', and $remaining more.');
    return _fil
        ? 'Ang $section section, may ${items.length} item: $list$tail'
        : 'The $section section, with ${items.length} items: $list$tail';
  }

  /// Answer to Select — the full control guide.
  String get buttonGuide => _fil
      ? 'Gabay sa mga button. '
          'D-pad kaliwa at kanan: lumipat ng section. '
          'D-pad taas at baba: lumipat ng item. '
          'X kaliwa, B kanan, Y taas, A baba, tulad ng D-pad. '
          'R1: buksan ang napiling item. '
          'L1: bumalik. '
          'R2: basahin ang buong screen. '
          'L2: ulitin ang huling sinabi. '
          'Start: nasaan ako. '
          'Select: ang gabay na ito. '
          'Kaliwang joystick: tulad ng D-pad. '
          'Kanang joystick pataas at pababa: mag-scroll; kaliwa at kanan: '
          'unang o huling item. '
          'Pindutin ang kaliwang joystick para bumalik sa Home. '
          'Pindutin ang kanang joystick para itigil ang pagsasalita.'
      : 'Button guide. '
          'D-pad left and right: move between sections. '
          'D-pad up and down: move between items. '
          'X is left, B is right, Y is up, A is down, the same as the D-pad. '
          'R1: open the item you are on. '
          'L1: go back. '
          'R2: read the whole screen. '
          'L2: repeat the last thing I said. '
          'Start: where am I. '
          'Select: this guide. '
          'Left joystick: the same as the D-pad. '
          'Right joystick up and down scrolls; left and right jump to the '
          'first or last item. '
          'Click the left joystick to go straight Home. '
          'Click the right joystick to stop me talking.';

  /// A controller has connected — but the app is not yet ready to say where
  /// the learner is (no section published). Kept short; the full welcome
  /// follows once a screen is up.
  String connected(String name) => _fil
      ? 'Nakakonekta ang controller.'
      : 'Controller connected.';

  String get disconnected => _fil
      ? 'Nadiskonekta ang controller. Gamitin ang touch screen, o i-on muli '
          'ang controller para magpatuloy.'
      : 'Controller disconnected. Use the touch screen, or switch the '
          'controller back on to carry on.';

  String reconnected(String section) => _fil
      ? 'Bumalik ang controller. Nasa $section section ka pa rin.'
      : 'Controller reconnected. You\'re still in the $section section.';

  String get goingHome => _fil ? 'Pauwi sa Home.' : 'Going to Home.';

  String get scrolledToEnd =>
      _fil ? 'Dulo na ng screen.' : 'That\'s the end of the screen.';

  String get scrolledToTop =>
      _fil ? 'Itaas na ng screen.' : 'That\'s the top of the screen.';

  /// Spoken when the learner steps onto a screen the gamepad can only drive
  /// with plain focus movement (a dialog, a game, a pushed screen).
  String get traversalMode => _fil
      ? 'Bagong screen. Gamitin ang D-pad taas at baba para maghanap, R1 para '
          'piliin, L1 para bumalik.'
      : 'New screen. Use D-pad up and down to look around, R1 to choose, '
          'L1 to go back.';

  /// Nothing was said yet, so there is nothing to repeat.
  String get nothingToRepeat =>
      _fil ? 'Wala pa akong sinasabi.' : 'I haven\'t said anything yet.';

  // ── Memory Match ─────────────────────────────────────────────────────────
  // A memory game played by ear is a game about *positions*, so every card is
  // announced by its number. That number is the learner's only handle on the
  // board — it is what they will remember and come back to.

  /// One card on the memory board. [word] is null while it is face down.
  String memoryCard(
    int position,
    int total, {
    String? word,
    bool matched = false,
  }) {
    if (matched) {
      return _fil
          ? 'Card $position ng $total, $word, tugma na.'
          : 'Card $position of $total, $word, already matched.';
    }
    if (word != null) {
      return _fil
          ? 'Card $position ng $total, $word, nakabukas.'
          : 'Card $position of $total, $word, face up.';
    }
    return _fil
        ? 'Card $position ng $total, nakatalikod.'
        : 'Card $position of $total, face down.';
  }

  /// The board's state, for the screen reading.
  String memoryProgress(int found, int pairs) => _fil
      ? 'Hanapin ang magkatugmang pares. $found sa $pairs ang nahanap.'
      : 'Find the matching pairs. $found of $pairs found.';

  /// A card was turned over.
  String memoryRevealed(int position, String word) => _fil
      ? 'Card $position, $word.'
      : 'Card $position, $word.';

  String memoryMatched(String word) =>
      _fil ? 'Tugma! $word.' : 'Match! $word.';

  String get memoryNoMatch =>
      _fil ? 'Hindi tugma. Subukan muli.' : 'Not a match. Try again.';

  /// The control that replays a spoken word.
  ///
  /// Not the app's `playAgain` ("Play Again"), which means *play the game*
  /// again — a control has to be named for what it does, and to a learner
  /// working purely by ear that distinction is the difference between hearing
  /// the word and losing their round.
  String get hearWordAgain =>
      _fil ? 'Pakinggan muli ang salita.' : 'Hear the word again.';

  /// Entering value-adjust mode. Names the new meaning of the buttons, the
  /// same way the yes/no question does — this is a mode, and an unannounced
  /// mode is how a learner loses track of what their controller does.
  String adjustEnter(String label) => _fil
      ? 'Isinasaayos ang $label. Kaliwa at kanan para baguhin. '
          'R1 kapag tapos na.'
      : 'Adjusting $label. Left and right to change. R1 when done.';

  /// Leaving it again, with the value that was settled on.
  String adjustDone(String label) =>
      _fil ? 'Tapos na. $label' : 'Done. $label';

  /// The value did not move, because it is already at one end.
  ///
  /// Only truthful because every slider the controller can reach now changes
  /// its spoken label on every step — an unchanged label used to mean "the
  /// bucket name covers two stops", and saying "that is as far as it goes"
  /// there would have been a lie.
  String get adjustAtLimit =>
      _fil ? 'Iyan na ang dulo.' : "That's as far as it goes.";

  /// The value, followed by the at-the-end note, punctuated properly.
  String adjustAtLimitFor(String label) {
    final head = label.trim();
    final stop = _endsSentence(head) ? head : '$head.';
    return '$stop $adjustAtLimit';
  }

  /// Pressed on something that cannot be nudged.
  String get adjustUnavailable => _fil
      ? 'Hindi ito mababago gamit ang kaliwa at kanan.'
      : 'This one cannot be changed with left and right.';

  /// Nothing has been spelled yet — "Answer:" on its own reads as a bare
  /// colon, which tells a learner nothing about whether their first letter
  /// registered.
  String get spellingEmpty => _fil
      ? 'Wala pang naibaybay.'
      : 'Nothing spelled yet.';

  /// The name of a control as printed on the pad, for the practice screen.
  String buttonName(GamepadButton button) {
    switch (button) {
      case GamepadButton.dpadLeft:
        return _fil ? 'D-pad kaliwa' : 'D-pad left';
      case GamepadButton.dpadRight:
        return _fil ? 'D-pad kanan' : 'D-pad right';
      case GamepadButton.dpadUp:
        return _fil ? 'D-pad taas' : 'D-pad up';
      case GamepadButton.dpadDown:
        return _fil ? 'D-pad baba' : 'D-pad down';
      case GamepadButton.a:
        return 'A';
      case GamepadButton.b:
        return 'B';
      case GamepadButton.x:
        return 'X';
      case GamepadButton.y:
        return 'Y';
      case GamepadButton.l1:
        return 'L1';
      case GamepadButton.l2:
        return 'L2';
      case GamepadButton.r1:
        return 'R1';
      case GamepadButton.r2:
        return 'R2';
      case GamepadButton.select:
        return 'Select';
      case GamepadButton.start:
        return 'Start';
      case GamepadButton.leftStickClick:
        return _fil ? 'Pindot ng kaliwang joystick' : 'Left joystick click';
      case GamepadButton.rightStickClick:
        return _fil ? 'Pindot ng kanang joystick' : 'Right joystick click';
      case GamepadButton.leftStickLeft:
        return _fil ? 'Kaliwang joystick kaliwa' : 'Left joystick left';
      case GamepadButton.leftStickRight:
        return _fil ? 'Kaliwang joystick kanan' : 'Left joystick right';
      case GamepadButton.leftStickUp:
        return _fil ? 'Kaliwang joystick taas' : 'Left joystick up';
      case GamepadButton.leftStickDown:
        return _fil ? 'Kaliwang joystick baba' : 'Left joystick down';
      case GamepadButton.rightStickLeft:
        return _fil ? 'Kanang joystick kaliwa' : 'Right joystick left';
      case GamepadButton.rightStickRight:
        return _fil ? 'Kanang joystick kanan' : 'Right joystick right';
      case GamepadButton.rightStickUp:
        return _fil ? 'Kanang joystick taas' : 'Right joystick up';
      case GamepadButton.rightStickDown:
        return _fil ? 'Kanang joystick baba' : 'Right joystick down';
      case GamepadButton.mode:
        return _fil ? 'Mode' : 'Mode';
    }
  }

  /// What an action does, in one short phrase.
  ///
  /// Derived from the same [resolveGamepadAction] the app actually runs, so
  /// the practice screen can never teach a mapping that is no longer true.
  String actionName(GamepadAction action) {
    switch (action) {
      case GamepadAction.previousSection:
        return _fil ? 'Nakaraang section.' : 'Previous section.';
      case GamepadAction.nextSection:
        return _fil ? 'Susunod na section.' : 'Next section.';
      case GamepadAction.previousItem:
        return _fil ? 'Nakaraang item.' : 'Previous item.';
      case GamepadAction.nextItem:
        return _fil ? 'Susunod na item.' : 'Next item.';
      case GamepadAction.activate:
        return _fil ? 'Buksan ang napili.' : 'Open the item you are on.';
      case GamepadAction.back:
        return _fil ? 'Bumalik.' : 'Go back.';
      case GamepadAction.answerYes:
        return _fil ? 'Sagot na oo.' : 'Answer yes.';
      case GamepadAction.answerNo:
        return _fil ? 'Sagot na hindi.' : 'Answer no.';
      case GamepadAction.readScreen:
        return _fil ? 'Basahin ang buong screen.' : 'Read the whole screen.';
      case GamepadAction.repeatLast:
        return _fil ? 'Ulitin ang huling sinabi.' : 'Say the last thing again.';
      case GamepadAction.whereAmI:
        return _fil ? 'Nasaan ako.' : 'Where am I.';
      case GamepadAction.buttonGuide:
        return _fil ? 'Ang gabay sa mga button.' : 'The button guide.';
      case GamepadAction.goHome:
        return _fil ? 'Pumunta sa Home.' : 'Go to Home.';
      case GamepadAction.stopSpeech:
        return _fil ? 'Itigil ang pagsasalita.' : 'Stop me talking.';
      case GamepadAction.scrollUp:
        return _fil ? 'Mag-scroll pataas.' : 'Scroll up.';
      case GamepadAction.scrollDown:
        return _fil ? 'Mag-scroll pababa.' : 'Scroll down.';
      case GamepadAction.firstItem:
        return _fil ? 'Unang item.' : 'First item.';
      case GamepadAction.lastItem:
        return _fil ? 'Huling item.' : 'Last item.';
      case GamepadAction.decrease:
        return _fil ? 'Bawasan ang halaga.' : 'Turn the value down.';
      case GamepadAction.increase:
        return _fil ? 'Dagdagan ang halaga.' : 'Turn the value up.';
      case GamepadAction.finishAdjust:
        return _fil ? 'Tapusin ang pagsasaayos.' : 'Finish adjusting.';
      case GamepadAction.none:
        return _fil
            ? 'Wala itong ginagawa sa app na ito.'
            : 'This one does nothing in this app.';
    }
  }

  /// Spoken as the practice screen opens.
  String get practiceIntro => _fil
      ? 'Pagsasanay sa controller. Pindutin ang kahit anong button at sasabihin '
          'ko kung ano ito. Walang mangyayari sa app. Pindutin ang L1 nang '
          'dalawang beses para umalis.'
      : 'Controller practice. Press any button and I will tell you what it is. '
          'Nothing else will happen. Press L1 twice to leave.';

  /// Spoken when the learner has tried every control.
  String practiceProgress(int tried, int total) => _fil
      ? 'Nasubukan mo na ang $tried sa $total.'
      : 'You have tried $tried of $total.';

  String get practiceComplete => _fil
      ? 'Nasubukan mo na ang lahat ng button. Magaling!'
      : 'You have tried every control. Well done!';

  /// The cursor landed on a control with no readable name.
  ///
  /// Not a nice thing to have to say, but the alternative is worse: **silence**.
  /// A learner who cannot see the screen reads a silent press as a broken
  /// button and stops trusting the controller, so every move has to make a
  /// sound even when the app cannot name what it moved to.
  String get unnamedItem =>
      _fil ? 'Item na walang pangalan.' : 'Unnamed item.';
}
