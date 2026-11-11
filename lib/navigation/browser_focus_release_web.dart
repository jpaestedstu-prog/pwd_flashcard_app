import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'text_focus_release.dart';

/// A screen reader moves the page's focus to a button before it presses it.
///
/// While a text box holds Flutter's focus, its field in the page takes the
/// page's focus back the moment it loses it, so the button never kept it. The
/// press then opened a new screen, the field went with the old one, and NVDA
/// read a field that was no longer there: "unknown" (seen on 4 Nov, on the
/// Next and Let's Go! buttons right after typing a name, on some runs).
///
/// [TextFocusReleaseObserver] lets go as the new screen opens, which is too
/// late for this. So: as the page's focus leaves a text box for one of the
/// app's controls, the box lets go, and the control gets the focus it was
/// given. A mouse click on a control has already done the same to a text box.
void installBrowserFocusRelease() {
  web.document.addEventListener(
    'focusout',
    ((web.Event event) {
      final to = (event as web.FocusEvent).relatedTarget;
      final from = event.target;
      if (to == null || from == null) return;
      if (!(from as JSObject).isA<web.HTMLInputElement>() &&
          !from.isA<web.HTMLTextAreaElement>()) {
        return;
      }
      if (!(to as JSObject).isA<web.HTMLElement>()) return;
      final control = to as web.HTMLElement;
      // A semantics node of the app's: a text box's own field is an input.
      if (control.tagName.toLowerCase() != 'flt-semantics') return;
      scheduleMicrotask(() {
        final node = FocusManager.instance.primaryFocus;
        final context = node?.context;
        if (node == null || context == null || !context.mounted) return;
        if (!TextFocusReleaseObserver.holdsText(context)) return;
        node.unfocus();
        // After the field has gone: a frame is all it takes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (control.isConnected) control.focus();
        });
        WidgetsBinding.instance.scheduleFrame();
      });
    }).toJS,
    true.toJS,
  );
}
