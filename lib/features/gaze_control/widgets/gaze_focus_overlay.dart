import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart' show AppColors;
import '../logic/gaze_focus_driver.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// What the traversal ring's hint chip should tell the learner.
enum GazeRingHint {
  /// Head moves steer, a blink presses.
  move,

  /// Head moves steer, look-up presses (blinks don't select).
  moveLookUp,

  /// Scanning: the controls light up in turn, a blink presses.
  scan,
}

/// Shows a hands-free learner where the focus traversal fallback currently is.
///
/// Material's own focus highlight is a faint overlay tint designed for a
/// sighted keyboard user glancing at a form — far too quiet to steer by when
/// moving your head is the only input you have. This paints the same bright
/// ring the D-pad uses on hub tiles, so the two modes look like one feature.
///
/// Each gaze scope owns one of these handles; the ring itself is drawn once,
/// by [GazeFocusRingLayer] above the router. It used to be an entry in the
/// root [Overlay], which put it *under* any dialog opened after it appeared —
/// a page that opened a confirm dialog hid the ring behind the dialog's scrim,
/// exactly when the learner needed it.
class GazeFocusOverlay {
  bool _showing = false;

  /// Whether this handle is currently asking for the ring.
  bool get isShowing => _showing;

  /// Asks for the ring, with the hint that fits the learner's input, and
  /// whether the highlight is on the Back pill ([exitFocused]) rather than on
  /// a control. Safe to call repeatedly; the newest call wins.
  void show(
    BuildContext context, {
    GazeRingHint hint = GazeRingHint.move,
    bool exitFocused = false,
  }) {
    final state = _RingState(hint, exitFocused);
    if (!_showing) {
      _showing = true;
      _GazeRingRequests.instance.add(state);
    } else {
      _GazeRingRequests.instance.retitle(state);
    }
  }

  /// Withdraws this handle's request. Safe to call when it never asked.
  void hide() {
    if (!_showing) return;
    _showing = false;
    _GazeRingRequests.instance.remove();
  }
}

/// The app-wide tally of scopes that want the traversal ring.
///
/// Scopes ask and withdraw from initState, timers and — crucially — dispose,
/// where touching another widget's state would throw, so the visible value is
/// published from a microtask once the current frame's work is done.
class _GazeRingRequests {
  _GazeRingRequests._();
  static final _GazeRingRequests instance = _GazeRingRequests._();

  int _count = 0;
  _RingState _state = const _RingState(GazeRingHint.move, false);
  bool _publishScheduled = false;

  /// Null while no scope wants the ring; otherwise what it should show.
  final ValueNotifier<_RingState?> visible = ValueNotifier(null);

  void add(_RingState state) {
    _count++;
    _state = state;
    _schedule();
  }

  void retitle(_RingState state) {
    _state = state;
    _schedule();
  }

  void remove() {
    if (_count > 0) _count--;
    _schedule();
  }

  void _schedule() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    scheduleMicrotask(() {
      _publishScheduled = false;
      visible.value = _count > 0 ? _state : null;
    });
  }
}

/// What the ring layer draws: the hint, and whether the Back pill is lit.
@immutable
class _RingState {
  const _RingState(this.hint, this.exitFocused);
  final GazeRingHint hint;
  final bool exitFocused;

  @override
  bool operator ==(Object other) =>
      other is _RingState &&
      other.hint == hint &&
      other.exitFocused == exitFocused;

  @override
  int get hashCode => Object.hash(hint, exitFocused);
}

/// Draws the gaze traversal ring above every route, dialog and sheet.
///
/// Installed once, in `MaterialApp.builder`, around the app. Renders nothing
/// (beyond its child) until a gaze scope asks for the ring.
class GazeFocusRingLayer extends StatelessWidget {
  const GazeFocusRingLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ValueListenableBuilder<_RingState?>(
          valueListenable: _GazeRingRequests.instance.visible,
          // Above the router there is no Material at all, and text without
          // one is drawn in Flutter's red-yellow "missing Material" style.
          builder: (context, state, _) => state == null
              ? const SizedBox.shrink()
              : Material(
                  type: MaterialType.transparency,
                  child: _GazeFocusRing(
                    hint: state.hint,
                    exitFocused: state.exitFocused,
                  ),
                ),
        ),
      ],
    );
  }
}

class _GazeFocusRing extends StatefulWidget {
  const _GazeFocusRing({required this.hint, required this.exitFocused});

  final GazeRingHint hint;

  /// The highlight is on the Back pill, not on a control.
  final bool exitFocused;

  @override
  State<_GazeFocusRing> createState() => _GazeFocusRingState();
}

class _GazeFocusRingState extends State<_GazeFocusRing> {
  Rect? _rect;
  Timer? _followTimer;

  /// The ring sits outside whatever is scrolling beneath it, so no
  /// notification reaches it when the content moves — and a focus change is
  /// not the only thing that moves a control. Without this the ring detaches
  /// from its button the moment the page scrolls (including the ensure-visible
  /// animation the driver itself triggers). Re-reading a rect is cheap; this
  /// just keeps them glued together.
  static const Duration _followInterval = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    // Focus may already have settled before the ring was inserted; read it
    // after this frame, once the covering route has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _followTimer = Timer.periodic(_followInterval, (_) => _sync());
  }

  @override
  void dispose() {
    _followTimer?.cancel();
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  /// The focus change itself fires before the new control has necessarily been
  /// laid out, so read the rect on the following frame.
  void _onFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    final next = GazeFocusDriver.focusedRect;
    if (next == _rect) return;
    setState(() => _rect = next);
  }

  String _hintText(BuildContext context) {
    final t = _t(context);
    return switch (widget.hint) {
      GazeRingHint.move => t.gzFocusHint,
      GazeRingHint.moveLookUp => t.gzFocusHintLookUp,
      GazeRingHint.scan => t.gzFocusHintScan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.exitFocused ? null : _rect;
    return IgnorePointer(
      child: Stack(
        children: [
          // The way out of whatever is showing, where a back button belongs.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _BackPill(
                  label: _t(context).back,
                  focused: widget.exitFocused,
                ),
              ),
            ),
          ),
          if (rect != null && !rect.isEmpty)
            // Sit slightly outside the control so the ring frames it rather
            // than covering its label.
            Positioned.fromRect(
              rect: rect.inflate(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          // The mode is unfamiliar and the ring alone doesn't explain it, so
          // say what the gestures do — the same reassurance the shell's
          // "Look ◀ ▶ to choose" chip gives on the hubs.
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _hintText(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The traversal's way out: lit while the highlight rests on it. Purely
/// visual — touch has the surface's own back button and scrim.
class _BackPill extends StatelessWidget {
  const _BackPill({required this.label, required this.focused});

  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: focused ? AppColors.accent : Colors.black54,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? AppColors.accent : Colors.white24,
          width: focused ? 3 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
