import 'package:flutter/widgets.dart';

/// A text box lets go of the focus as a new screen opens over it or in its
/// place.
///
/// A tap, or a mouse click, on a button does not take the focus from a text
/// box: Flutter's buttons do not take focus when pressed. So the Name box of
/// the profile form still held it when "Let's Go!" opened the next screen,
/// and in a browser the page put the box's hidden text field back in focus
/// for a moment as the old screen went. NVDA read that field, which has no
/// name of its own and was gone a moment later: "unknown" (the NVDA log of 4
/// Nov; the page's focus log shows the field focused and removed within
/// 150 ms). Let go first, nothing is left to come back.
///
/// Only for a whole screen (a [PageRoute]). A pop-up over a form (the date
/// picker, a sheet) leaves the form's focus where it is, so the focus comes
/// back to the same field when it closes, as a keyboard user expects.
class TextFocusReleaseObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _release(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _release(newRoute);

  void _release(Route<dynamic>? opening) {
    if (opening is! PageRoute) return;
    final node = FocusManager.instance.primaryFocus;
    final context = node?.context;
    if (node == null || context == null || !context.mounted) return;
    if (!holdsText(context)) return;
    // A screen's own box, focused as it opens, keeps its focus.
    if (ModalRoute.of(context) == opening) return;
    node.unfocus();
  }

  /// Whether the focus at [context] is a text box's.
  static bool holdsText(BuildContext context) =>
      context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
