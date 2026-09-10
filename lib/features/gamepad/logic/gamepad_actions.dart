import '../models/gamepad_button.dart';

/// What a control does once the app has interpreted it.
enum GamepadAction {
  /// Offer the previous top-level section ("Do you want to go to …?").
  previousSection,

  /// Offer the next top-level section.
  nextSection,

  /// Move the reading cursor to the previous item on this screen.
  previousItem,

  /// Move the reading cursor to the next item on this screen.
  nextItem,

  /// Open / press whatever the cursor is on.
  activate,

  /// Leave the current screen (or close a sheet / dialog).
  back,

  /// Answer "yes" to the pending section question.
  answerYes,

  /// Answer "no" — decline, and offer the next section instead.
  answerNo,

  /// Speak everything reachable on this screen.
  readScreen,

  /// Say the last announcement again.
  repeatLast,

  /// Say where the learner is right now.
  whereAmI,

  /// Speak the full button guide.
  buttonGuide,

  /// Jump straight to the Home section.
  goHome,

  /// Stop the current announcement.
  stopSpeech,

  scrollUp,
  scrollDown,

  /// Jump the cursor to the first / last item on the screen.
  firstItem,
  lastItem,

  /// Nudge the value being adjusted down / up one step.
  decrease,
  increase,

  /// Leave the value alone and go back to moving around.
  finishAdjust,

  /// Deliberately ignored (e.g. the pad's own mode button).
  none,
}

/// Whether holding a control should keep [action] firing.
///
/// Only **movement** repeats, and only when the learner has opted in. The
/// distinction is not arbitrary: a repeated step through a list is recoverable
/// — the next press moves back — whereas a repeated *open*, *back* or *section
/// change* would fire a burst of navigation a blind learner cannot see coming
/// and cannot easily unwind. Answering a question is excluded for the same
/// reason: holding A must never answer the same question twice.
bool repeatsOnHold(GamepadAction action) {
  switch (action) {
    case GamepadAction.previousItem:
    case GamepadAction.nextItem:
    case GamepadAction.scrollUp:
    case GamepadAction.scrollDown:
    // Nudging a value is the other genuinely repeatable thing: dragging a
    // slider from one end to the other one press at a time would be absurd,
    // and every step is recoverable by nudging back.
    case GamepadAction.decrease:
    case GamepadAction.increase:
      return true;
    default:
      return false;
  }
}

/// Maps a physical control to the action it performs.
///
/// Pure and total: every [GamepadButton] resolves, so a control can never be
/// silently dead. [awaitingAnswer] is the one piece of context that changes the
/// mapping — while the app is asking "Do you want to go to the Cards section?",
/// **A** and **B** stop being directional and become *yes* / *no*. Every prompt
/// says so out loud ("press A for yes, B for no"), so a learner who cannot see
/// the screen is never guessing which mode the buttons are in.
///
/// ### The navigation model
/// Left/right walks the **sections** (Home · Cards · Games · Stories ·
/// Progress) and asks before switching; up/down walks the **items** inside the
/// current section. Item movement is deliberately *linear* (reading order)
/// rather than 2-D: a blind learner stepping through a 2-column tile grid with
/// only up/down would never reach the second column, so the cursor flattens the
/// grid the way a screen reader does.
GamepadAction resolveGamepadAction(
  GamepadButton button, {
  bool awaitingAnswer = false,
  bool adjusting = false,
}) {
  // While a value is being changed, left/right stop meaning "section" and
  // start meaning "less/more". This is a *mode*, and like the yes/no question
  // it is announced when it opens and when it closes — a learner is never left
  // guessing which meaning their next press will get.
  if (adjusting) {
    switch (button) {
      case GamepadButton.dpadLeft:
      case GamepadButton.x:
      case GamepadButton.leftStickLeft:
        return GamepadAction.decrease;
      case GamepadButton.dpadRight:
      case GamepadButton.b:
      case GamepadButton.leftStickRight:
        return GamepadAction.increase;
      case GamepadButton.r1:
      case GamepadButton.l1:
        return GamepadAction.finishAdjust;
      default:
        break;
    }
  }
  // While a question is on the table, the two answer buttons take priority
  // over their normal directional duty.
  if (awaitingAnswer) {
    switch (button) {
      case GamepadButton.a:
        return GamepadAction.answerYes;
      case GamepadButton.b:
        return GamepadAction.answerNo;
      default:
        break;
    }
  }

  switch (button) {
    // ── Sections: left / right ──────────────────────────────────────────
    case GamepadButton.dpadLeft:
    case GamepadButton.x:
    case GamepadButton.leftStickLeft:
      return GamepadAction.previousSection;

    case GamepadButton.dpadRight:
    case GamepadButton.b:
    case GamepadButton.leftStickRight:
      return GamepadAction.nextSection;

    // ── Items: up / down ────────────────────────────────────────────────
    case GamepadButton.dpadUp:
    case GamepadButton.y:
    case GamepadButton.leftStickUp:
      return GamepadAction.previousItem;

    case GamepadButton.dpadDown:
    case GamepadButton.a:
    case GamepadButton.leftStickDown:
      return GamepadAction.nextItem;

    // ── Open / leave ────────────────────────────────────────────────────
    case GamepadButton.r1:
      return GamepadAction.activate;
    case GamepadButton.l1:
      return GamepadAction.back;

    // ── Listening aids ──────────────────────────────────────────────────
    case GamepadButton.r2:
      return GamepadAction.readScreen;
    case GamepadButton.l2:
      return GamepadAction.repeatLast;
    case GamepadButton.start:
      return GamepadAction.whereAmI;
    case GamepadButton.select:
      return GamepadAction.buttonGuide;

    // ── Right stick: reading the long screens ───────────────────────────
    case GamepadButton.rightStickUp:
      return GamepadAction.scrollUp;
    case GamepadButton.rightStickDown:
      return GamepadAction.scrollDown;
    case GamepadButton.rightStickLeft:
      return GamepadAction.firstItem;
    case GamepadButton.rightStickRight:
      return GamepadAction.lastItem;

    // ── Stick clicks ────────────────────────────────────────────────────
    // "I'm lost" is the single most common panic for a learner who cannot see
    // the screen, so the left stick click is a one-press way back to Home.
    case GamepadButton.leftStickClick:
      return GamepadAction.goHome;
    // A long announcement the learner has already understood is worth being
    // able to cut off — otherwise they wait it out before every move.
    case GamepadButton.rightStickClick:
      return GamepadAction.stopSpeech;

    // The pad's own HID-profile switch. Reacting to it would fight the
    // hardware, so it is mapped to nothing on purpose.
    case GamepadButton.mode:
      return GamepadAction.none;
  }
}
