import 'package:flutter/widgets.dart';

/// Closes the on-screen keyboard and waits, briefly, until it has left.
///
/// For a dialog opened straight after typing: the date picker after a name
/// field. Flutter's date picker has a fixed size, and on a phone held
/// sideways a keyboard still on its way out leaves it too little height, so
/// it overflowed until the keyboard was gone (the landscape phone walk caught
/// it; a 200 dp keyboard is enough). Gives up after [timeout], so a keyboard
/// that never reports leaving cannot hold the dialog back.
///
/// Uses the view captured before waiting, never [context] after it.
Future<void> closeKeyboardFirst(
  BuildContext context, {
  Duration timeout = const Duration(milliseconds: 600),
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final view = View.maybeOf(context);
  if (view == null) return;
  const step = Duration(milliseconds: 50);
  for (
    var waited = Duration.zero;
    waited < timeout && view.viewInsets.bottom > 0;
    waited += step
  ) {
    await Future<void>.delayed(step);
  }
}
