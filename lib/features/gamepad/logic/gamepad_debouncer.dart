import '../models/gamepad_button.dart';

/// Filters the raw controller stream down to the presses the learner *meant*.
///
/// Three real problems, all observed on the X3 (`GamePadPlus V3`):
///
/// 1. **The same press arrives twice.** The pad exposes two HID interfaces
///    which Android merges into one device: the gamepad interface reports the
///    D-pad as a hat switch (`ABS_HAT0X/Y`) while the Consumer Control
///    interface reports the very same press as `KEY_LEFT`/`KEY_UP`/… Both
///    reach the app, milliseconds apart, so an unfiltered stream moves the
///    cursor two steps per press.
/// 2. **Held buttons auto-repeat.** Android repeats a held key ~20×/second.
///    For a learner with a motor impairment — who may hold a button simply
///    because releasing it is hard — that turns one press into a stampede
///    through the whole screen.
/// 3. **Contact bounce.** A worn membrane can report a press twice in a few
///    milliseconds.
///
/// All three collapse into one rule: **a given control fires at most once per
/// [window]**. Different controls are independent, so genuinely fast play
/// (right, then A) is never swallowed — only a repeat of the *same* control is.
///
/// Pure: the clock is injected, so every case above is unit-testable with no
/// device and no waiting.
class GamepadDebouncer {
  /// How long a control stays "spent" after firing. 140 ms comfortably covers
  /// the dual-interface double-report (observed ~5–30 ms apart) and contact
  /// bounce, while staying well under a deliberate double-press (~250 ms+).
  ///
  /// Mutable so the host can retune it when the learner moves the slider
  /// **without discarding this filter's state**. Replacing the whole debouncer
  /// on a settings change wiped its record of what was already held, and any
  /// unrelated provider tick — a profile refresh, say — then let a duplicate
  /// report straight through as if it were a fresh press.
  Duration window;

  final DateTime Function() _now;

  /// How long a control may sit in [_held] with no traffic at all before a new
  /// press is believed over the hold.
  ///
  /// Bluetooth drops packets, and the packet most worth losing is the *release*
  /// — after which the control looks permanently held and stops responding
  /// forever. For a learner who cannot see the screen a silently dead button is
  /// the worst failure this class can produce: there is no visible cue, and no
  /// way to diagnose it beyond "the controller broke".
  ///
  /// A **gap** in the stream is what separates the two cases, not elapsed time:
  /// a genuinely held button keeps producing reports every ~50 ms, so it never
  /// goes quiet; a lost release leaves silence until the learner presses again.
  ///
  /// Deliberately far longer than any plausible gap between two reports of the
  /// *same* press. Duplicate reports land milliseconds apart on the wire — but
  /// the gap measured here is between the moments the app **processes** them,
  /// and that can stretch: a slow frame, a garbage-collection pause, or this
  /// tablet's power manager briefly freezing the process. At one second an
  /// ordinary stall was enough to make the second half of a duplicate look
  /// like a fresh press, moving the cursor twice. Five seconds cannot be
  /// reached by a stall, and still recovers a genuinely stuck button within a
  /// couple of presses.
  static const Duration staleHold = Duration(seconds: 5);

  final Map<GamepadButton, DateTime> _lastAccepted = {};

  /// When each control was last *seen* at all, accepted or not — the signal
  /// that distinguishes a held button from a lost release.
  final Map<GamepadButton, DateTime> _lastSeen = {};

  /// Controls currently held down, so a release can clear their debounce
  /// early — a deliberate press-release-press is always honoured in full even
  /// if it happens inside [window].
  final Set<GamepadButton> _held = {};

  GamepadDebouncer({
    this.window = const Duration(milliseconds: 140),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Whether [event] should be acted on. Releases never produce an action, but
  /// they do clear the hold state so the next press is accepted immediately.
  bool accept(GamepadEvent event) {
    if (!event.pressed) {
      _held.remove(event.button);
      // A clean release proves the press ended, so the next one is intentional
      // no matter how quickly it follows.
      _lastAccepted.remove(event.button);
      _lastSeen.remove(event.button);
      return false;
    }

    final now = _now();
    final seen = _lastSeen[event.button];
    _lastSeen[event.button] = now;

    if (_held.contains(event.button)) {
      // Quiet for long enough that a held button would have reported by now,
      // so the release was almost certainly lost. Believe the new press rather
      // than leaving the control dead.
      final wentQuiet = seen == null || now.difference(seen) >= staleHold;
      if (!wentQuiet) {
        // Still physically down: auto-repeat, or the duplicate report from the
        // pad's other HID interface. Never a new intent.
        return false;
      }
      _held.remove(event.button);
      _lastAccepted.remove(event.button);
    }

    final last = _lastAccepted[event.button];
    if (last != null && now.difference(last) < window) return false;

    _held.add(event.button);
    _lastAccepted[event.button] = now;
    return true;
  }

  /// Forgets all state — used when the controller disconnects, so a button
  /// that was held at the moment the link dropped isn't still considered down
  /// when the pad comes back.
  void reset() {
    _held.clear();
    _lastAccepted.clear();
    _lastSeen.clear();
  }
}
