import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart';
import '../../../navigation/app_router.dart' show rootNavigatorKey;
import '../../../providers/app_providers.dart' show settingsProvider;
import '../../gaze_control/logic/gaze_focus_driver.dart';
import '../../gaze_control/providers/gaze_home_grid.dart';
import '../../gaze_control/widgets/shell_modal_observer.dart';
import '../logic/gamepad_actions.dart';
import '../logic/gamepad_cursor.dart';
import '../logic/gamepad_debouncer.dart';
import '../logic/gamepad_speech.dart';
import '../logic/section_confirm.dart';
import '../models/gamepad_button.dart';
import '../providers/gamepad_sections.dart';
import '../providers/gamepad_practice.dart';
import '../providers/gamepad_screen.dart';
import '../providers/gamepad_settings_provider.dart';
import '../providers/gamepad_status_provider.dart';
import '../services/gamepad_announcer.dart';
import '../services/gamepad_key_injector.dart';

/// Drives the whole app from a Bluetooth game controller, speaking every move.
///
/// Wraps the app **above the router** (in `MaterialApp.builder`), for the same
/// reason the AI Companion and the cast pill live there: the controller has to
/// keep working across every screen, including the ones pushed on top of the
/// navigation shell, and a scope mounted inside the shell would go away the
/// moment a game or a dialog opened. It reaches the router through
/// [rootNavigatorKey] and the shell through [gamepadSections], so it needs no
/// `GoRouter` in scope.
///
/// ## What it reuses
/// Nothing about the *targets* is new. The hub screens already publish their
/// feature tiles to `gazeHomeGrid` for the hands-free gaze D-pad, and Flutter
/// already knows how to move focus around a dialog. This host walks the former
/// in reading order and falls back to the latter, so every screen the gaze
/// learner can reach is reachable with a controller on day one — and any screen
/// that adopts the grid later gets gamepad support for free.
///
/// ## The two modes
/// * **Grid mode** — a hub has published tiles and nothing is layered over it.
///   Up/down walk the tiles in reading order, and the tile draws the same focus
///   ring gaze uses.
/// * **Traversal mode** — a dialog, a game, a pushed screen. The same buttons
///   drive Flutter's directional focus traversal instead, which every Material
///   control supports out of the box. Without this, opening anything from a hub
///   would strand a learner who cannot see the screen.
class GamepadHost extends ConsumerStatefulWidget {
  final Widget child;

  const GamepadHost({super.key, required this.child});

  @override
  ConsumerState<GamepadHost> createState() => _GamepadHostState();
}

/// Zero-width and byte-order characters, which `trim` leaves behind.
final RegExp _invisible = RegExp('[\u200B-\u200D\u2060\uFEFF]');

/// At least one letter or digit, in any script — the test for whether a label
/// will actually be heard when spoken.
final RegExp _pronounceable = RegExp(r'[\p{L}\p{N}]', unicode: true);

class _GamepadHostState extends ConsumerState<GamepadHost> {
  final GamepadDebouncer _debouncer = GamepadDebouncer();
  final GamepadCursor _cursor = GamepadCursor();

  /// Separate cursor for a pushed screen's own published items.
  ///
  /// Kept apart from the hub-grid cursor so returning from a game lands the
  /// learner back on the tile they opened it from, rather than wherever they
  /// happened to be inside it.
  final GamepadCursor _screenCursor = GamepadCursor();
  final SectionConfirm _confirm = SectionConfirm();
  GamepadAnnouncer? _announcer;

  StreamSubscription<GamepadEvent>? _buttonSub;
  StreamSubscription<GamepadConnectionEvent>? _connectionSub;

  /// Android device ids currently attached.
  ///
  /// A set, not a flag, because **one physical pad can arrive as more than one
  /// device**. The X3 exposes a gamepad interface and a Consumer Control
  /// interface, and its id churns across reconnects (observed as device 80,
  /// then 81, on the same tablet). Counting devices rather than latching a
  /// boolean is what keeps a second arrival from being mistaken for a
  /// reconnection — which used to swallow the welcome entirely.
  final Set<int> _devices = {};

  bool get _connected => _devices.isNotEmpty;

  /// True once a real disconnect has been seen, so the *next* connection is
  /// greeted as a return rather than a first hello.
  bool _hadDisconnect = false;

  /// Whether the welcome has actually been spoken for the current connection.
  bool _welcomed = false;

  /// True while this host is the thing that last moved the shared highlight,
  /// so it can tell its own ring from one the gaze scope drew.
  bool _owningFocus = false;

  /// Last live-announcement sequence spoken, so each is said exactly once.
  int _lastLiveSeq = 0;

  /// The control currently held for hold-to-repeat, and its timer.
  GamepadButton? _heldButton;
  Timer? _repeatTimer;

  /// Repeats fired during the current hold, so a lost release cannot leave the
  /// cursor walking forever.
  int _repeatsFired = 0;

  /// When back was first pressed inside the practice screen, so a second press
  /// within a few seconds leaves.
  DateTime? _practiceExitArmedAt;

  /// True while left/right are nudging a value rather than walking sections.
  ///
  /// A slider cannot be *pressed*; it has to be moved a step at a time, and
  /// left/right are the only pair that reads as "less / more". Rather than
  /// steal them permanently — which would cost the learner section navigation
  /// everywhere — they change meaning only inside this mode, which is entered
  /// deliberately, announced on the way in and on the way out, and left by the
  /// same R1 that entered it.
  bool _adjusting = false;

  @override
  void initState() {
    super.initState();
    gazeHomeGrid.addListener(_onGridChanged);
    gamepadSections.addListener(_onSectionsChanged);
    gamepadScreen.addListener(_onScreenChanged);
    // Deferred: reading providers and starting a platform channel during the
    // first build of the app root would fire notifications mid-build.
    scheduleMicrotask(_evaluate);
  }

  @override
  void dispose() {
    gazeHomeGrid.removeListener(_onGridChanged);
    gamepadSections.removeListener(_onSectionsChanged);
    _arrival?.cancel();
    gamepadScreen.removeListener(_onScreenChanged);
    _stopRepeat();
    _buttonSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  /// The learner's own speech speed. Deliberately the app's existing per-profile
  /// `ttsSpeed` rather than a second, competing gamepad-only dial: a learner
  /// who needs slow speech needs it everywhere, and two sliders that both claim
  /// to set the speaking rate is a support call waiting to happen.
  double get _speechRate {
    try {
      return ref.read(settingsProvider).ttsSpeed;
    } catch (_) {
      return 0.5;
    }
  }

  GamepadPhrases get _phrases {
    String locale = 'en';
    try {
      locale = ref.read(settingsProvider).locale;
    } catch (_) {
      // Settings not ready (early boot / tests) — English is the safe default.
    }
    return GamepadPhrases(locale);
  }

  // ── Wiring ──────────────────────────────────────────────────────────────

  /// Starts or stops listening as the learner's settings change.
  void _evaluate() {
    if (!mounted) return;
    final settings = ref.read(gamepadSettingsProvider);
    final service = ref.read(gamepadServiceProvider);

    if (!settings.enabled) {
      _buttonSub?.cancel();
      _buttonSub = null;
      _connectionSub?.cancel();
      _connectionSub = null;
      _devices.clear();
      _welcomed = false;
      _hadDisconnect = false;
      service.setCaptureEnabled(false);
      return;
    }

    // Retune in place — never replace. A new debouncer would forget which
    // controls are currently held, and the next duplicate report would sail
    // through as a second press.
    _debouncer.window = settings.dedupeWindow;

    _announcer ??= GamepadAnnouncer(ref.read(ttsServiceProvider));
    // The provider rebuilds its service when the profile's audio settings
    // change, so re-point the announcer rather than letting it hold a stale
    // engine that no longer reflects the learner's preferences.
    _announcer!.tts = ref.read(ttsServiceProvider);
    _announcer!.enabled = settings.speak;
    _announcer!.locale = _phrases.locale;
    _announcer!.rate = _speechRate;

    if (_buttonSub != null) return; // Already listening.

    service.start();
    // Capture is what makes the native side swallow controller keys instead of
    // letting Flutter's focus traversal also react to them. Only switched on
    // once we are genuinely listening, so a pad is never left dead.
    service.setCaptureEnabled(true);
    _buttonSub = service.buttons.listen(_onButton);
    _connectionSub = service.connections.listen(_onConnection);

    // Catch up on controllers that connected before this host was listening.
    //
    // [GamepadService.connections] is a broadcast stream and therefore does not
    // replay. The native bridge reports already-paired pads the moment it is
    // first listened to — and this host can mount *after* that, or remount when
    // a gate above it swaps its child. Either way the subscription above hears
    // nothing, `_devices` stays empty, and the learner picks up a controller
    // that never greets them and reports "no controller" everywhere.
    if (_devices.isEmpty && service.hasController) {
      _devices.addAll(service.connectedIds);
      _maybeWelcome();
    }
    if (kDebugMode) {
      debugPrint(
        'Gamepad: listening, devices=$_devices '
        'hasController=${service.hasController} '
        'grid=${gazeHomeGrid.hasGrid} sections=${gamepadSections.labels.length}',
      );
    }
  }

  void _onConnection(GamepadConnectionEvent event) {
    if (!mounted) return;
    if (event.connected) {
      final wasEmpty = _devices.isEmpty;
      _devices.add(event.deviceId);
      // The pad's *second* interface arriving is not a new controller, and
      // announcing it would talk over whatever the learner is doing.
      if (!wasEmpty) return;
      _debouncer.reset();
      // A pad that comes back mid-session gets a shorter, more useful line
      // than the full welcome — the learner already knows where they are, they
      // just need to know the controller is working again.
      if (_hadDisconnect) {
        _hadDisconnect = false;
        _welcomed = true;
        final section = gamepadSections.currentLabel;
        _say(
          section == null
              ? _phrases.connected(event.name)
              : _phrases.reconnected(section),
        );
      } else {
        _maybeWelcome();
      }
    } else {
      _devices.remove(event.deviceId);
      // Losing one of a pad's two interfaces is not losing the pad. Only speak
      // when nothing is left to drive the app with.
      if (_devices.isNotEmpty) return;
      _hadDisconnect = true;
      _welcomed = false;
      _stopRepeat();
      // A button held at the moment the link dropped must not still count as
      // held when the pad comes back.
      _debouncer.reset();
      _confirm.cancel();
      _say(_phrases.disconnected);
    }
  }

  /// The welcome waits for a section to exist. A controller often connects on
  /// the splash or profile picker, before any hub has published — announcing
  /// "you are in the null section" there would be worse than a short silence.
  void _maybeWelcome() {
    if (!_connected || _welcomed) return;
    final section = gamepadSections.currentLabel;
    if (section == null) return;
    _welcomed = true;
    _say(_phrases.welcome(section));
  }

  void _onGridChanged() {
    if (!mounted) return;
    _cursor.setRows(_gridRows());
    // Follow a focus change that came from somewhere else — a touch, or the
    // gaze cursor — so the next button press continues from whatever the
    // learner last heard rather than from a stale spot.
    final row = gazeHomeGrid.focusRow;
    final col = gazeHomeGrid.focusCol;
    if (row != null && col != null && !_owningFocus) {
      _cursor.moveTo(row, col);
    }
    _owningFocus = false;
  }

  /// The foreground screen re-published, or posted a live announcement.
  void _onScreenChanged() {
    if (!mounted) return;

    // A live message is the screen narrating itself as it changes — a quiz
    // result, the next question, a story sentence. Compared by *sequence*, not
    // by text, so the same words twice running ("Correct!") are still spoken
    // the second time.
    final seq = gamepadScreen.liveSequence;
    if (seq != _lastLiveSeq) {
      _lastLiveSeq = seq;
      final message = gamepadScreen.liveMessage;
      if (message != null) _say(message);
    }

    // A change to the floating list re-shapes the *hub* cursor as well — that
    // is where floating items live.
    _cursor.setRows(_gridRows());

    // Re-shape the reading cursor. Clamped rather than reset, so a screen
    // rebuilding (a timer tick, an animation) does not throw the learner back
    // to the first choice mid-round.
    final count = gamepadScreen.items.length;
    _screenCursor.setRows([count]);
    if (count == 0) {
      _screenCursor.first();
      return;
    }
    // A fresh publication with no focus yet starts at the top.
    if (gamepadScreen.focusedIndex == null) {
      _screenCursor.first();
      gamepadScreen.setFocus(0);
    }
  }

  void _onSectionsChanged() {
    if (!mounted) return;
    _confirm.sync(
      sections: gamepadSections.labels,
      current: gamepadSections.currentIndex,
    );
    _maybeWelcome();
  }

  // ── Input ───────────────────────────────────────────────────────────────

  void _onButton(GamepadEvent event) {
    if (!mounted) return;

    // Releases are read *before* the debouncer, which reports them as "no
    // action". Hold-to-repeat needs to see them: the release is the only signal
    // that the learner has let go.
    if (!event.pressed) {
      if (event.button == _heldButton) _stopRepeat();
      _debouncer.accept(event);
      return;
    }
    if (!_debouncer.accept(event)) return;

    final settings = ref.read(gamepadSettingsProvider);
    // Some pads report the bottom face button as B rather than A, which would
    // silently turn "press A for yes" into "no".
    final button = settings.swapConfirmButtons
        ? _swapAB(event.button)
        : event.button;

    final action = resolveGamepadAction(
      button,
      awaitingAnswer: _confirm.awaitingAnswer && settings.confirmSectionChange,
      adjusting: _adjusting,
    );

    if (kDebugMode) {
      debugPrint('Gamepad ${button.name} -> ${action.name}');
    }

    // The practice screen wants the raw presses so it can name them, without
    // the app navigating underneath.
    if (gamepadPractice.value) {
      // Back is the exception, but it takes **two** presses there. Once, and a
      // learner exploring what L1 does would be ejected by the very press they
      // were trying to learn about — which is the one thing practice mode
      // exists to make safe. The count lives here rather than in the practice
      // screen because the host is always alive: the screen announces the
      // press, this decides when it actually leaves, so the mode can never
      // become somewhere a learner cannot get out of.
      if (action != GamepadAction.back) return;
      final now = DateTime.now();
      final armed = _practiceExitArmedAt;
      if (armed == null || now.difference(armed) > const Duration(seconds: 4)) {
        _practiceExitArmedAt = now;
        return;
      }
      _practiceExitArmedAt = null;
    }

    if (settings.vibrate && action != GamepadAction.none) {
      _haptic();
    }
    _run(action, settings.confirmSectionChange);

    // A new press supersedes whatever was held before it.
    _stopRepeat();
    if (settings.holdToRepeat && repeatsOnHold(action)) {
      _heldButton = event.button;
      _repeatsFired = 0;
      _repeatTimer = Timer(settings.repeatDelay, () {
        _repeatTimer = Timer.periodic(settings.repeatRate, (_) {
          if (!mounted || _heldButton == null) {
            _stopRepeat();
            return;
          }
          // A repeat that only ends when a release arrives is a repeat that
          // never ends if the release is *lost* — and Bluetooth loses packets,
          // which is exactly why the debouncer already has a stale-hold escape
          // on the press side. Without this cap a dropped release would walk
          // the cursor through the list indefinitely, and a learner who cannot
          // see the screen would hear the app talking to itself with no idea
          // which button to press to stop it.
          if (++_repeatsFired >= _maxRepeats) {
            _stopRepeat();
            return;
          }
          _run(action, settings.confirmSectionChange);
        });
      });
    }
  }

  /// Ceiling on one hold's repeats.
  ///
  /// Generous on purpose: at the default 350 ms rate this is about 21 seconds
  /// of continuous holding, comfortably more than crossing the longest screen
  /// in the app (Home publishes 42 cells). Anything beyond it is a stuck
  /// button, not an intention.
  static const int _maxRepeats = 60;

  /// Ends any hold-repeat in progress.
  ///
  /// Called on release, on a new press, on disconnect and on dispose — a timer
  /// left running after the pad has gone would walk the cursor on its own,
  /// which to a learner who cannot see the screen looks exactly like the app
  /// having a mind of its own.
  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _heldButton = null;
    _repeatsFired = 0;
  }

  static GamepadButton _swapAB(GamepadButton b) => switch (b) {
        GamepadButton.a => GamepadButton.b,
        GamepadButton.b => GamepadButton.a,
        _ => b,
      };

  void _run(GamepadAction action, bool confirmSections) {
    // Any action that is not an answer abandons a pending question, so a stale
    // "do you want to go to Games?" can never be answered by an A press the
    // learner meant for something else entirely. The informational actions are
    // exempt: hearing the guide or repeating a line should not lose your place.
    const keepsQuestion = {
      GamepadAction.answerYes,
      GamepadAction.answerNo,
      GamepadAction.previousSection,
      GamepadAction.nextSection,
      GamepadAction.repeatLast,
      GamepadAction.buttonGuide,
      GamepadAction.stopSpeech,
      GamepadAction.none,
    };
    if (_confirm.awaitingAnswer && !keepsQuestion.contains(action)) {
      _confirm.cancel();
    }

    // Doing anything unrelated leaves adjust mode, so left/right can never
    // still be nudging a slider the learner has walked away from. Silent on
    // purpose: the action they just asked for announces itself, and that is
    // what tells them the mode is over.
    const keepsAdjusting = {
      GamepadAction.decrease,
      GamepadAction.increase,
      GamepadAction.finishAdjust,
      GamepadAction.repeatLast,
      GamepadAction.buttonGuide,
      GamepadAction.stopSpeech,
      GamepadAction.none,
    };
    if (_adjusting && !keepsAdjusting.contains(action)) {
      _adjusting = false;
      _stopRepeat();
    }

    switch (action) {
      case GamepadAction.previousSection:
        _offerSection(-1, confirmSections);
      case GamepadAction.nextSection:
        _offerSection(1, confirmSections);
      case GamepadAction.answerYes:
        _acceptSection();
      case GamepadAction.answerNo:
        _declineSection();
      case GamepadAction.previousItem:
        _moveItem(-1);
      case GamepadAction.nextItem:
        _moveItem(1);
      case GamepadAction.firstItem:
        _jumpItem(first: true);
      case GamepadAction.lastItem:
        _jumpItem(first: false);
      case GamepadAction.activate:
        _activate();
      case GamepadAction.back:
        _back();
      case GamepadAction.readScreen:
        _readScreen();
      case GamepadAction.whereAmI:
        _whereAmI();
      case GamepadAction.buttonGuide:
        _say(_phrases.buttonGuide);
      case GamepadAction.repeatLast:
        final announcer = _announcer;
        if (announcer?.lastMessage == null) {
          _say(_phrases.nothingToRepeat);
        } else {
          announcer!.repeat();
        }
      case GamepadAction.stopSpeech:
        _announcer?.silence();
      case GamepadAction.goHome:
        _goHome();
      case GamepadAction.scrollUp:
        _scroll(-1);
      case GamepadAction.scrollDown:
        _scroll(1);
      case GamepadAction.decrease:
        _adjust(TraversalDirection.left);
      case GamepadAction.increase:
        _adjust(TraversalDirection.right);
      case GamepadAction.finishAdjust:
        _endAdjust();
      case GamepadAction.none:
        break;
    }
  }

  // ── Adjusting a value ───────────────────────────────────────────────────

  /// Whether the focused control is something left/right can nudge.
  ///
  /// Detected from the widget tree rather than declared per screen: the app
  /// has sliders in half a dozen places and gains more over time, and a
  /// slider that nobody remembered to mark up would simply be unusable.
  bool get _focusedIsAdjustable {
    final context = GazeFocusDriver.focused?.context;
    if (context is! Element) return false;
    // Focus usually sits *inside* the Slider (its own internal focus node), so
    // look up as well as down.
    var found = false;
    void visit(Element element, int depth) {
      if (found || depth > 12) return;
      if (element.widget is Slider) {
        found = true;
        return;
      }
      element.visitChildren((child) => visit(child, depth + 1));
    }

    visit(context, 0);
    if (found) return true;
    var hops = 0;
    context.visitAncestorElements((ancestor) {
      if (hops++ >= 12) return false;
      if (ancestor.widget is Slider) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  void _beginAdjust() {
    _adjusting = true;
    final label = _labelOfFocused();
    _say(_phrases.adjustEnter(label ?? _phrases.unnamedItem));
  }

  void _endAdjust() {
    if (!_adjusting) return;
    _adjusting = false;
    _stopRepeat();
    final label = _labelOfFocused();
    _say(_phrases.adjustDone(label ?? ''));
  }

  /// Nudges the focused control one step, then reads it back.
  ///
  /// The read-back is [_labelOfFocused] rather than a value the host tracks:
  /// a settings row's own label already carries its value ("Speech Speed.
  /// Normal"), so the learner hears exactly what a sighted user sees, and the
  /// host never has to know what any particular slider measures.
  void _adjust(TraversalDirection direction) {
    final before = _labelOfFocused();
    if (!GamepadKeyInjector.sendArrow(direction)) {
      _say(_phrases.adjustUnavailable);
      _adjusting = false;
      return;
    }
    // Read back after the frame the adjustment lands in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final after = _labelOfFocused();
      if (after == null || after.isEmpty) {
        _say(_phrases.unnamedItem);
        return;
      }
      // Every reachable slider now changes its spoken label on every step, so
      // an unchanged label means the value really is at its end — worth
      // saying, because otherwise the learner hears the same words twice and
      // cannot tell a limit from a dead button.
      _say(after == before ? _phrases.adjustAtLimitFor(after) : after);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  // ── Sections ────────────────────────────────────────────────────────────

  void _offerSection(int delta, bool confirmSections) {
    _syncSections();
    if (gamepadSections.labels.length < 2) {
      _say(_phrases.noSections);
      return;
    }
    final target =
        delta > 0 ? _confirm.offerNext() : _confirm.offerPrevious();
    if (target == null) {
      _say(_phrases.noSections);
      return;
    }
    if (!confirmSections) {
      // Confirmation turned off: move immediately, still saying where we
      // landed. A sighted learner using the pad for convenience does not need
      // to answer a question every time they change tab.
      _confirm.accept();
      _commitSection(target);
      return;
    }
    _say(_phrases.sectionQuestion(_confirm.pendingLabel ?? ''));
  }

  void _acceptSection() {
    final target = _confirm.accept();
    if (target == null) return;
    _commitSection(target);
  }

  void _declineSection() {
    final next = _confirm.decline();
    if (next == null) return;
    _say(_phrases.sectionQuestion(_confirm.pendingLabel ?? ''));
  }

  void _commitSection(int index) {
    final label = gamepadSections.labels.length > index
        ? gamepadSections.labels[index]
        : null;
    if (!gamepadSections.select(index)) return;
    // The new hub publishes its grid a frame or two later; start its reading
    // cursor at the top so the first up/down press lands on item one.
    _cursor.first();
    if (label != null) _say(_phrases.sectionEntered(label));
  }

  void _goHome() {
    _syncSections();
    if (!gamepadSections.hasSections) {
      _say(_phrases.noSections);
      return;
    }
    _confirm.cancel();
    _cursor.first();
    if (gamepadSections.select(0)) {
      _say(_phrases.goingHome);
    }
  }

  void _syncSections() {
    _confirm.sync(
      sections: gamepadSections.labels,
      current: gamepadSections.currentIndex,
    );
  }

  // ── Items ───────────────────────────────────────────────────────────────

  /// Whether the published tile grid is the right thing to steer right now.
  ///
  /// A hub keeps its grid published while a dialog or a pushed screen sits on
  /// top of it, so "a grid exists" is not enough — driving it under an open
  /// sheet is exactly the bug `shellModalObserver` was written to catch for
  /// gaze. The root navigator being able to pop means something is layered
  /// above the shell; the observer catches sheets pushed onto the shell's own
  /// inner navigator, which the root one cannot see.
  bool get _gridMode {
    if (!gazeHomeGrid.hasGrid) return false;
    if (shellModalObserver.isCovering) return false;
    if (_anythingPushed) return false;
    return true;
  }

  /// The navigator that owns the topmost route.
  ///
  /// **Not always the root one.** go_router pushes several game and activity
  /// routes onto the *shell's* inner navigator, and there
  /// `rootNavigatorKey.currentState.canPop()` is false even while a game is
  /// filling the screen — so back reported "there is nothing to go back to"
  /// from inside a game, stranding a learner who had no other way out.
  ///
  /// The focused widget lives inside whatever route is actually on top, so its
  /// nearest [Navigator] is the one to act on. Falls back to the root when
  /// nothing is focused.
  NavigatorState? get _activeNavigator {
    final context = GazeFocusDriver.focused?.context;
    if (context != null && context.mounted) {
      final nav = Navigator.maybeOf(context);
      if (nav != null) return nav;
    }
    return rootNavigatorKey.currentState;
  }

  /// Whether any route is layered over the navigation shell, on either
  /// navigator.
  bool get _anythingPushed {
    final root = rootNavigatorKey.currentState;
    if (root != null && root.canPop()) return true;
    final active = _activeNavigator;
    return active != null && active.canPop();
  }

  /// The foreground screen has published its own controls and prose, so it —
  /// not the hub behind it — is what the controller drives.
  ///
  /// Takes priority over [_gridMode] because a screen only publishes while it
  /// is genuinely on top: [GamepadScreenRegistrar] withdraws its publication
  /// the moment a dialog covers it, and clears on dispose.
  bool get _screenMode => gamepadScreen.hasContent;

  /// The hub's own rows, plus one extra row for anything floating above it.
  ///
  /// Appended rather than merged so a floating control is always *last* — a
  /// learner stepping through Home reaches all forty-two tiles first and the
  /// tutor button at the end, never the other way round.
  List<int> _gridRows() => [
        ...gazeHomeGrid.rowLengths,
        if (gamepadScreen.floating.isNotEmpty) gamepadScreen.floating.length,
      ];

  /// The floating item at the cursor, or null when the cursor is on a real
  /// hub tile.
  GamepadItem? _floatingAt(int row, int col) {
    if (row < gazeHomeGrid.rows.length) return null;
    final floating = gamepadScreen.floating;
    if (col < 0 || col >= floating.length) return null;
    return floating[col];
  }

  /// Screen items exist to be walked, as opposed to a screen that published
  /// only prose (a story page with nothing to press).
  bool get _screenHasItems =>
      _screenMode && gamepadScreen.items.isNotEmpty;

  void _moveItem(int delta) {
    if (_screenHasItems) {
      _screenCursor.setRows([gamepadScreen.items.length]);
      delta > 0 ? _screenCursor.next() : _screenCursor.previous();
      gamepadScreen.setFocus(_screenCursor.index);
      _announceScreenItem();
      return;
    }
    if (_gridMode) {
      _cursor.setRows(_gridRows());
      if (_cursor.isEmpty) {
        _say(_phrases.nothingHere);
        return;
      }
      delta > 0 ? _cursor.next() : _cursor.previous();
      _publishCursor();
      _announceCurrentItem();
      return;
    }
    final moved = GazeFocusDriver.move(
          delta > 0 ? TraversalDirection.down : TraversalDirection.up,
        ) ||
        GazeFocusDriver.moveFirst();
    if (moved) {
      _announceFocused();
    } else {
      _say(_phrases.nothingHere);
    }
  }

  void _jumpItem({required bool first}) {
    if (_screenHasItems) {
      _screenCursor.setRows([gamepadScreen.items.length]);
      first ? _screenCursor.first() : _screenCursor.last();
      gamepadScreen.setFocus(_screenCursor.index);
      _announceScreenItem();
      return;
    }
    if (!_gridMode) {
      _say(_phrases.nothingHere);
      return;
    }
    _cursor.setRows(_gridRows());
    if (_cursor.isEmpty) {
      _say(_phrases.nothingHere);
      return;
    }
    first ? _cursor.first() : _cursor.last();
    _publishCursor();
    _announceCurrentItem();
  }

  void _announceScreenItem() {
    if (!ref.read(gamepadSettingsProvider).announceItems) return;
    final item = gamepadScreen.itemAt(_screenCursor.index);
    if (item == null) return;
    _say(
      _phrases.item(
        item.label,
        _screenCursor.index + 1,
        gamepadScreen.items.length,
        detail: item.detail,
        unavailable: !item.enabled,
      ),
    );
  }

  void _publishCursor() {
    // Mark the next registry notification as self-inflicted, so [_onGridChanged]
    // does not treat our own move as an external focus change and re-sync on
    // top of it.
    _owningFocus = true;
    gazeHomeGrid.setFocus(_cursor.row, _cursor.col);
  }

  void _announceCurrentItem() {
    if (!ref.read(gamepadSettingsProvider).announceItems) return;
    final floating = _floatingAt(_cursor.row, _cursor.col);
    if (floating != null) {
      _say(
        _phrases.item(
          floating.label,
          _cursor.index + 1,
          _cursor.length,
          detail: floating.detail,
          unavailable: !floating.enabled,
        ),
      );
      return;
    }
    final cell = gazeHomeGrid.cellAt(_cursor.row, _cursor.col);
    if (cell == null) return;
    _say(_phrases.item(cell.label, _cursor.index + 1, _cursor.length));
  }

  /// Speaks whatever the focus traversal just landed on.
  ///
  /// Deferred a frame because Flutter applies a focus change asynchronously —
  /// reading the focused node immediately after moving still returns the node
  /// the learner just left, which would announce the wrong control.
  void _announceFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final label = _labelOfFocused();
      // Never leave a press silent. A control Flutter can focus but the app
      // cannot name still has to make a sound, or the learner reads the
      // silence as a broken button.
      _say(label == null || label.isEmpty ? _phrases.unnamedItem : label);
    });
    // [addPostFrameCallback] does **not** request a frame — it only queues work
    // for the next one that happens anyway. Moving focus does not always dirty
    // anything (a screen with no `Focus`-rebuilding widgets above the target
    // schedules nothing), and the callback then sits in the queue indefinitely:
    // the learner presses a button and hears silence, which is precisely the
    // failure this fallback exists to prevent. Ask for the frame explicitly.
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Best-effort name for the focused control.
  ///
  /// Prefers an explicit [Semantics] label (what a screen reader would say),
  /// then falls back to the first piece of visible text inside it — which for
  /// a Material button, list tile or dialog action is exactly its caption.
  String? _labelOfFocused() {
    final context = GazeFocusDriver.focused?.context;
    if (context is! Element) return null;

    // The focused widget itself is the best answer when it has one. Searched
    // deep: a Material control's subtree (InkWell → Semantics → Padding → Row →
    // Text …) routinely runs fifteen elements or more before reaching its
    // caption, and a shallow cap silently reported every button as unnamed.
    final own = _labelWithin(context, maxDepth: 30);
    if (own != null) return own;

    // Focus often lands on a bare `Focus`/`InkWell` node whose label lives on a
    // wrapper just above it — a `Semantics` around the whole tile, say. Walking
    // a few levels up recovers those. Strictly bounded: hop far enough and the
    // search escapes into the page scaffold and starts confidently reading out
    // the app-bar title for every control on the screen, which is worse than
    // admitting the control is unnamed.
    // Walking up, two different kinds of evidence get two different budgets.
    //
    // An **explicit** `Semantics(label:)` is a deliberate statement about the
    // whole subtree, so it is trusted a long way up: a settings row wraps its
    // icon, title, subtitle *and* its Switch in one label, and the Switch that
    // takes focus sits a dozen elements below it. At six hops those rows all
    // announced "Unnamed item" while a screen reader read them perfectly.
    //
    // **Scraped text** is a guess, so it stays close: hop far enough and the
    // search escapes into the page scaffold and reads the app-bar title out
    // for every control on the screen.
    String? found;
    var hops = 0;
    context.visitAncestorElements((ancestor) {
      hops++;
      if (hops > _labelAncestorHops) return false;
      final own = _labelOfWidget(ancestor.widget);
      if (own != null) {
        found = own;
        return false;
      }
      if (hops <= _labelTextHops) {
        found = _labelWithin(ancestor, maxDepth: 12);
        if (found != null) return false;
      }
      return true;
    });
    return found;
  }

  /// First readable name inside [root]'s subtree: an explicit [Semantics] label
  /// (what a screen reader would say) or the first visible [Text], which for a
  /// Material button, list tile or dialog action is exactly its caption.
  ///
  /// Depth-bounded so a search that starts high in the tree cannot walk the
  /// entire page.
  /// How far up to look for an explicit `Semantics` / `Tooltip` label.
  static const int _labelAncestorHops = 14;

  /// How far up to look for *scraped* text — deliberately much shorter.
  static const int _labelTextHops = 3;

  /// A label carried by the widget itself, if it declares one.
  String? _labelOfWidget(Widget widget) {
    String? candidate;
    if (widget is Semantics) candidate = widget.properties.label;
    if (widget is Tooltip) candidate = widget.message;
    if (candidate == null) return null;
    final text = candidate.replaceAll(_invisible, '').trim();
    if (text.isEmpty || !_pronounceable.hasMatch(text)) return null;
    return text;
  }

  String? _labelWithin(Element root, {required int maxDepth}) {
    String? found;

    void take(String? value) {
      if (found != null) return;
      if (value == null) return;
      // Zero-width characters survive `trim`, so a spacer `Text` reads as a
      // perfectly valid label and then announces absolutely nothing.
      final text = value.replaceAll(_invisible, '').trim();
      if (text.isEmpty) return;
      // Must contain something a voice can pronounce. Plenty of captions are
      // decorative — a flag emoji on a banner, a bare chevron — and speaking
      // one is indistinguishable from silence to the learner it matters to.
      // Falling through to the next candidate (or to "Unnamed item") at least
      // tells them the press registered.
      if (!_pronounceable.hasMatch(text)) return;
      found = text;
    }

    void visit(Element element, int depth) {
      if (found != null || depth > maxDepth) return;
      final widget = element.widget;
      // In preference order: what a screen reader would say, then a tooltip,
      // then whatever is actually written on the control.
      if (widget is Semantics) take(widget.properties.label);
      if (widget is Tooltip) take(widget.message);
      if (widget is Text) take(widget.data ?? widget.textSpan?.toPlainText());
      // Text ultimately builds a RichText; screens that style a caption with
      // spans have no plain `Text` widget to find at all.
      if (widget is RichText) take(widget.text.toPlainText());
      if (widget is Icon) take(widget.semanticLabel);
      if (widget is Image) take(widget.semanticLabel);
      if (found != null) return;
      element.visitChildren((child) => visit(child, depth + 1));
    }

    root.visitChildren((child) => visit(child, 1));
    return found;
  }

  // ── Acting ──────────────────────────────────────────────────────────────

  void _activate() {
    if (_screenHasItems) {
      _screenCursor.setRows([gamepadScreen.items.length]);
      final item = gamepadScreen.itemAt(_screenCursor.index);
      if (item != null) {
        if (!item.enabled) {
          _say(_phrases.notAvailable(item.label));
          return;
        }
        // Only the name, not "Opening …". On a hub that phrasing is right
        // because a screen is about to appear; inside a quiz the same words
        // would talk over the game announcing whether the answer was correct.
        _say(item.label);
        _hapticSuccess();
        item.onActivate();
        return;
      }
    }
    if (_gridMode) {
      _cursor.setRows(_gridRows());
      final floating = _floatingAt(_cursor.row, _cursor.col);
      if (floating != null) {
        if (!floating.enabled) {
          _say(_phrases.notAvailable(floating.label));
          return;
        }
        _say(_phrases.opening(floating.label));
        _hapticSuccess();
        floating.onActivate();
        return;
      }
      final cell = gazeHomeGrid.cellAt(_cursor.row, _cursor.col);
      if (cell != null) {
        _say(_phrases.opening(cell.label));
        _hapticSuccess();
        cell.onActivate();
        return;
      }
    }
    // A slider is not something to press — pressing it is how the learner asks
    // to *change* it.
    if (_focusedIsAdjustable) {
      _beginAdjust();
      return;
    }
    final before = GazeFocusDriver.focused;
    final beforeLabel = _labelOfFocused();
    if (GazeFocusDriver.activate()) {
      _hapticSuccess();
      _announceChangedLabel(before, beforeLabel);
      return;
    }
    // A freshly-opened dialog often has focus resting on its bare scope node
    // with nothing to press — pull focus onto its first control so the
    // learner's press is never simply swallowed.
    if (GazeFocusDriver.moveFirst()) {
      _announceFocused();
      return;
    }
    _say(_phrases.nothingToOpen);
  }

  /// Reads a control back after pressing it, but only if pressing it changed
  /// what the control says about itself.
  ///
  /// This is how a switch reports its new state. It deliberately does not
  /// announce anything when the press *navigated* — the focus node will have
  /// changed — because the screen that just opened is about to introduce
  /// itself, and two voices at once is worse than one.
  void _announceChangedLabel(FocusNode? before, String? beforeLabel) {
    if (before == null) return;
    final saidBefore = _saidSeq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(GazeFocusDriver.focused, before)) return;
      final after = _labelOfFocused();
      if (after == null || after.isEmpty || after == beforeLabel) return;
      _say(after);
    });
    WidgetsBinding.instance.scheduleFrame();
    _breakArrivalSilence(saidBefore, beforeLabel);
  }

  /// Says where the learner has landed, when nothing else did.
  ///
  /// Screens that publish themselves narrate their own arrival, and games say
  /// something the moment they start; those are always better than anything
  /// the host could invent, so this only speaks when the screen has stayed
  /// silent. Without it, pressing a row like "Game Controller" opened the
  /// sub-screen with no sound at all — indistinguishable, without sight, from
  /// a button that does nothing.
  ///
  /// The wait is generous because the registrar that adopts a pushed screen
  /// polls, so a screen that *does* introduce itself may take a beat to do so.
  /// Speaking too early would put two voices on the same moment, which is the
  /// one outcome worse than a pause.
  void _breakArrivalSilence(int saidBefore, String? pressedLabel) {
    _arrival?.cancel();
    _arrival = Timer(_arrivalGrace, () {
      if (!mounted) return;
      // Something spoke — the screen introduced itself, or the control read
      // itself back. Either way the learner is not sitting in silence.
      if (_saidSeq != saidBefore) return;
      // A screen that published its own content is read by R2 and stepped
      // through with the D-pad; it is not silent, it is waiting.
      if (_screenMode) return;

      // A freshly pushed route leaves focus on its own scope node. Pulling
      // focus onto the first real control is what a screen reader does on
      // arrival, and it means the learner's next D-pad press starts from the
      // top of the screen rather than from nowhere.
      final onScopeNode = _labelOfFocused() == null;
      if (onScopeNode) GazeFocusDriver.moveFirst();

      // What to say is the *destination*, named from the control that opened
      // it — not whatever happens to hold focus now. The first focusable on a
      // pushed screen is usually its back button, and "Back" tells a learner
      // who cannot see the screen nothing at all about where they have landed.
      if (pressedLabel != null && pressedLabel.isNotEmpty) {
        _say(_phrases.opening(_headline(pressedLabel)));
        return;
      }
      // Focus changes apply asynchronously, so a node just moved to is not
      // readable until the next frame — asked for explicitly, because moving
      // focus does not always dirty anything.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _saidSeq != saidBefore) return;
        final arrived = _labelOfFocused();
        if (arrived == null || arrived.isEmpty) return;
        _say(arrived);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  /// The naming half of a label, dropping the descriptive tail.
  ///
  /// Row labels read "Game Controller. Navigate by Bluetooth gamepad, with
  /// spoken feedback" — right when the learner is choosing, far too much when
  /// all that is being confirmed is which screen just opened.
  String _headline(String label) {
    final stop = label.indexOf('. ');
    return stop <= 0 ? label : label.substring(0, stop);
  }

  /// How long to wait for a screen to introduce itself before doing it for it.
  static const Duration _arrivalGrace = Duration(milliseconds: 1200);
  Timer? _arrival;

  void _back() {
    final nav = _activeNavigator;
    if (nav == null || !nav.canPop()) {
      _say(_phrases.cannotGoBack);
      return;
    }
    _say(_phrases.goingBack);
    // maybePop rather than pop, so a screen with unsaved work can still put up
    // its own confirmation instead of being torn away.
    nav.maybePop();
  }

  void _readScreen() {
    final section = gamepadSections.currentLabel ?? '';
    // A screen that published itself gets read properly: its prose first —
    // the question, the sentence, the prompt — then what can be chosen. This
    // is the whole point of the narration half of the bridge; without it the
    // controller could operate a quiz without ever saying what it asked.
    if (_screenMode) {
      _say(
        _phrases.screenReading(
          gamepadScreen.title ?? section,
          gamepadScreen.narration,
          [for (final item in gamepadScreen.items) item.label],
        ),
      );
      return;
    }
    if (!_gridMode) {
      final label = _labelOfFocused();
      _say(label == null ? _phrases.traversalMode : '$label. ${_phrases.traversalMode}');
      return;
    }
    final labels = <String>[
      for (final row in gazeHomeGrid.rows)
        for (final cell in row) cell.label,
      for (final item in gamepadScreen.floating) item.label,
    ];
    _say(_phrases.screenContents(section, labels));
  }

  void _whereAmI() {
    if (_screenMode) {
      final title = gamepadScreen.title ?? gamepadSections.currentLabel ?? '';
      final item = _screenHasItems
          ? gamepadScreen.itemAt(_screenCursor.index)?.label
          : null;
      _say(_phrases.whereAmI(title, item));
      return;
    }
    final section = gamepadSections.currentLabel;
    if (section == null) {
      _say(_phrases.nothingHere);
      return;
    }
    String? item;
    if (_gridMode) {
      item = gazeHomeGrid.cellAt(_cursor.row, _cursor.col)?.label;
    } else {
      item = _labelOfFocused();
    }
    _say(_phrases.whereAmI(section, item));
  }

  void _scroll(int direction) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(size.width / 2, size.height / 2),
        scrollDelta: Offset(0, direction * 320.0),
      ),
    );
  }

  // ── Output ──────────────────────────────────────────────────────────────

  void _say(String text) {
    _saidSeq++;
    _announcer?.say(text);
  }

  /// Counts everything spoken, so a later check can ask "has anything been
  /// said since?" without caring what it was.
  int _saidSeq = 0;

  void _haptic() {
    try {
      ref.read(hapticServiceProvider).selectionClick();
    } catch (_) {
      // No haptics in tests / on a device without a vibrator.
    }
  }

  void _hapticSuccess() {
    try {
      ref.read(hapticServiceProvider).success();
    } catch (_) {
      // As above.
    }
  }

  @override
  Widget build(BuildContext context) {
    // React live to the learner's settings — a profile switch on a shared
    // tablet changes all of these, and a controller must never be left running
    // under the previous learner's preferences. Deferred to a microtask
    // because provider listeners can fire mid-build.
    ref.listen(gamepadSettingsProvider, (_, _) {
      scheduleMicrotask(_evaluate);
    });
    // The speech-speed slider lives in the app's own settings, so watch it too
    // — otherwise moving it would not reach the announcer until something else
    // happened to re-evaluate.
    ref.listen<double>(
      settingsProvider.select((s) => s.ttsSpeed),
      (_, _) => scheduleMicrotask(_evaluate),
    );
    return widget.child;
  }
}
