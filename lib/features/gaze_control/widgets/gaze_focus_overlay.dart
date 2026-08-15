import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart' show AppColors;
import '../logic/gaze_focus_driver.dart';

/// Shows a hands-free learner where the focus traversal fallback currently is.
///
/// Material's own focus highlight is a faint overlay tint designed for a
/// sighted keyboard user glancing at a form — far too quiet to steer by when
/// moving your head is the only input you have. This paints the same bright
/// ring the D-pad uses on hub tiles, so the two modes look like one feature.
///
/// It lives in the **root [Overlay]**, not in the widget that creates it: the
/// scope driving traversal (the nav shell) sits *below* the dialog or pushed
/// page being traversed, so anything it painted itself would be hidden behind
/// the very thing the ring is pointing at.
class GazeFocusOverlay {
  OverlayEntry? _entry;

  /// Whether the ring is currently installed.
  bool get isShowing => _entry != null;

  /// Inserts the ring above every route. Safe to call repeatedly.
  void show(BuildContext context) {
    if (_entry != null) return;
    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) return;
    final entry = OverlayEntry(builder: (_) => const _GazeFocusRing());
    _entry = entry;
    overlay.insert(entry);
  }

  /// Removes the ring. Safe to call when it was never shown.
  void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _GazeFocusRing extends StatefulWidget {
  const _GazeFocusRing();

  @override
  State<_GazeFocusRing> createState() => _GazeFocusRingState();
}

class _GazeFocusRingState extends State<_GazeFocusRing> {
  Rect? _rect;
  Timer? _followTimer;

  /// The ring lives in the root overlay, outside whatever is scrolling beneath
  /// it, so no notification reaches it when the content moves — and a focus
  /// change is not the only thing that moves a control. Without this the ring
  /// detaches from its button the moment the page scrolls (including the
  /// ensure-visible animation the driver itself triggers). Re-reading a rect is
  /// cheap; this just keeps them glued together.
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

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return IgnorePointer(
      child: Stack(
        children: [
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
            left: 0,
            right: 0,
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
                    child: const Text(
                      'Look ◀ ▶ ▲ ▼ to move · blink to press',
                      style: TextStyle(color: Colors.white, fontSize: 13),
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
