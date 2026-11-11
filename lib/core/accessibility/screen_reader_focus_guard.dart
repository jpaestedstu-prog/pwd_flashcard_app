import 'package:flutter/widgets.dart';

import '../../navigation/dpad_keys.dart' show isInTextField;
import 'voice_navigation_service.dart';

/// Lets go of a keyboard or controller focus that has scrolled out of sight
/// while a screen reader is running.
///
/// Found with TalkBack on the tablet (28 Oct): a learner who had moved with
/// the D-pad and then swiped with TalkBack was pulled back to the control the
/// D-pad had left focused. Flutter tells TalkBack about the focused control
/// again whenever that control scrolls back into the tree, and TalkBack moves
/// there: walking Home forward, "What is this in Filipino?" jumped to
/// "Stories" and the three answers in between were never read. With the
/// stale focus let go once it is out of sight, nothing can pull TalkBack
/// back, and the next D-pad press starts again from what is on screen.
///
/// Only a focus inside the list that scrolled, only once it is wholly out of
/// view, never a text field being typed in (that would close its keyboard),
/// and never without a screen reader — for everyone else the D-pad's place
/// is kept exactly as before.
class ScreenReaderFocusGuard extends StatelessWidget {
  const ScreenReaderFocusGuard({super.key, required this.child});

  final Widget child;

  /// Whether a screen reader is reading the screen. A seam for tests.
  @visibleForTesting
  static bool Function() screenReaderOn =
      () => VoiceNavigationService.isScreenReaderOn;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _judgeAfterLayout(notification.context);
        }
        return false;
      },
      child: child,
    );
  }

  static BuildContext? _pending;

  /// Judged once the list has been laid out at its new place: while it
  /// scrolls, the focused control still stands where the last frame left
  /// it, and a jump (TalkBack's own scroll to what it reads next) was never
  /// judged at all — the D-pad focus stayed, and so did the pull back to it.
  /// One check a frame, however many notices the scroll sent.
  static void _judgeAfterLayout(BuildContext? scrollContext) {
    if (scrollContext == null || !screenReaderOn()) return;
    final first = _pending == null;
    _pending = scrollContext;
    if (!first) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _pending;
      _pending = null;
      if (context != null && context.mounted) letGoIfOutOfSight(context);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Lets go of the primary focus if it sits inside [scrollContext] (the
  /// list that scrolled) and no longer overlaps it. Returns whether it did.
  @visibleForTesting
  static bool letGoIfOutOfSight(BuildContext? scrollContext) {
    if (scrollContext == null || !scrollContext.mounted || !screenReaderOn()) {
      return false;
    }
    final node = FocusManager.instance.primaryFocus;
    final focused = node?.context;
    if (node == null || focused == null || node is FocusScopeNode) {
      return false;
    }
    if (isInTextField(node)) return false;
    var inside = false;
    focused.visitAncestorElements((element) {
      if (identical(element, scrollContext)) {
        inside = true;
        return false;
      }
      return true;
    });
    if (!inside) return false;
    final viewport = scrollContext.findRenderObject();
    final box = focused.findRenderObject();
    if (viewport is! RenderBox ||
        box is! RenderBox ||
        !viewport.attached ||
        !box.attached ||
        !viewport.hasSize ||
        !box.hasSize) {
      return false;
    }
    final shown = MatrixUtils.transformRect(
      viewport.getTransformTo(null),
      Offset.zero & viewport.size,
    );
    final where = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    // A control scrolled far out of its list is kept alive off stage, its
    // rectangle not a number, and a NaN rectangle "overlaps" everything: it
    // was never let go.
    if (where.isFinite && shown.overlaps(where)) return false;
    // To the enclosing scope: no control holds the focus until the next
    // press, so there is nothing for Flutter to re-announce.
    node.unfocus();
    return true;
  }
}
