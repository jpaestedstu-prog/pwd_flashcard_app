import '../models/gamepad_button.dart';

/// What a control does once the app has interpreted it.
enum GamepadAction {
  /// Move the highlight one step up / down / left / right: to the
  /// neighbouring tile on a hub, and anywhere else exactly as an arrow key
  /// moves the focus — a slider under the highlight turns its value with
  /// left and right, as it does for a keyboard.
  moveUp,
  moveDown,
  moveLeft,
  moveRight,

  /// Offer the previous / next top-level section ("Do you want to go to …?").
  previousSection,
  nextSection,

  /// Step to the previous / next control in reading order, one at a time —
  /// the alternative to moving by direction, for a learner who needs a
  /// single, predictable "next".
  previousItem,
  nextItem,

  /// Press whatever has the highlight.
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

  /// Jump the highlight to the first / last control on the screen.
  firstItem,
  lastItem,

  /// Deliberately ignored (e.g. the pad's own mode button).
  none,
}

/// Whether holding a control should keep [action] firing.
///
/// Only **movement** repeats, and only when the learner has opted in. The
/// distinction is not arbitrary: a repeated step is recoverable — the next
/// press moves back — whereas a repeated *press*, *back* or *section change*
/// would fire a burst of navigation a blind learner cannot see coming and
/// cannot easily unwind. Answering a question is excluded for the same
/// reason: holding A must never answer the same question twice.
bool repeatsOnHold(GamepadAction action) {
  switch (action) {
    case GamepadAction.moveUp:
    case GamepadAction.moveDown:
    case GamepadAction.moveLeft:
    case GamepadAction.moveRight:
    case GamepadAction.previousItem:
    case GamepadAction.nextItem:
    case GamepadAction.scrollUp:
    case GamepadAction.scrollDown:
      return true;
    default:
      return false;
  }
}

/// Maps a physical control to the action it performs.
///
/// Pure and total: every [GamepadButton] resolves, so a control can never be
/// silently dead. **One control, one job:**
///
/// | Control | Job |
/// |---|---|
/// | D-pad ▲ ▼ ◀ ▶ | move the highlight that way |
/// | Left stick | the same as the D-pad — the one deliberate duplicate, which [leftStickMoves] turns off |
/// | A | press what is highlighted — and *yes*, when a question is asked |
/// | B | go back or close — and *no*, when a question is asked |
/// | X | read the whole screen |
/// | Y | say the last thing again |
/// | L1 / R1 | previous / next section |
/// | L2 / R2 | previous / next item, one at a time in reading order |
/// | Start | where am I |
/// | Select | the button guide |
/// | Right stick ▲ ▼ | scroll the page |
/// | Right stick ◀ ▶ | first / last item |
/// | Left stick click | go to Home |
/// | Right stick click | stop talking |
///
/// The face buttons used to double as a second D-pad (A down, Y up, X and B
/// left and right), so the same press both moved and confirmed depending on
/// the moment — and the D-pad's left and right switched *sections*, so moving
/// across a row was impossible. Now the D-pad only moves, A only confirms and
/// B only cancels; *yes* and *no* are A's and B's own meanings applied to a
/// question, and every question says so out loud.
GamepadAction resolveGamepadAction(
  GamepadButton button, {
  bool awaitingAnswer = false,
  bool leftStickMoves = true,
}) {
  // While a question is on the table, confirming answers it and cancelling
  // declines it.
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
    // ── Moving: the D-pad, and the left stick unless turned off ─────────
    case GamepadButton.dpadUp:
      return GamepadAction.moveUp;
    case GamepadButton.dpadDown:
      return GamepadAction.moveDown;
    case GamepadButton.dpadLeft:
      return GamepadAction.moveLeft;
    case GamepadButton.dpadRight:
      return GamepadAction.moveRight;
    case GamepadButton.leftStickUp:
      return leftStickMoves ? GamepadAction.moveUp : GamepadAction.none;
    case GamepadButton.leftStickDown:
      return leftStickMoves ? GamepadAction.moveDown : GamepadAction.none;
    case GamepadButton.leftStickLeft:
      return leftStickMoves ? GamepadAction.moveLeft : GamepadAction.none;
    case GamepadButton.leftStickRight:
      return leftStickMoves ? GamepadAction.moveRight : GamepadAction.none;

    // ── Confirming and cancelling ───────────────────────────────────────
    case GamepadButton.a:
      return GamepadAction.activate;
    case GamepadButton.b:
      return GamepadAction.back;

    // ── Listening ───────────────────────────────────────────────────────
    case GamepadButton.x:
      return GamepadAction.readScreen;
    case GamepadButton.y:
      return GamepadAction.repeatLast;
    case GamepadButton.start:
      return GamepadAction.whereAmI;
    case GamepadButton.select:
      return GamepadAction.buttonGuide;

    // ── Sections and the one-at-a-time list ─────────────────────────────
    case GamepadButton.l1:
      return GamepadAction.previousSection;
    case GamepadButton.r1:
      return GamepadAction.nextSection;
    case GamepadButton.l2:
      return GamepadAction.previousItem;
    case GamepadButton.r2:
      return GamepadAction.nextItem;

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

/// The controls that move the highlight, by direction — the D-pad's, and the
/// left stick's when it moves too.
bool isLeftStickMove(GamepadButton button) => switch (button) {
  GamepadButton.leftStickUp ||
  GamepadButton.leftStickDown ||
  GamepadButton.leftStickLeft ||
  GamepadButton.leftStickRight => true,
  _ => false,
};

/// A and B exchanged, for a Nintendo-layout pad (`swapConfirmButtons`): its
/// bottom button reports as B, and "press A for yes" would otherwise answer
/// no. Every other control passes through.
GamepadButton swapConfirmButton(GamepadButton button) => switch (button) {
  GamepadButton.a => GamepadButton.b,
  GamepadButton.b => GamepadButton.a,
  _ => button,
};
