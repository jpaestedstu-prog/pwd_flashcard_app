import 'package:flutter/widgets.dart';

import '../core/accessibility/focused_label.dart';

/// Lets a D-pad reach a control that is drawn with a bare [GestureDetector].
///
/// A [GestureDetector] answers fingers only. Three of the app's inputs move
/// keyboard focus instead: the arrow keys of a keyboard, a remote or a switch
/// box (on Android and in the web app), and the focus traversal that Gaze
/// Control and the game controller fall back on wherever a screen publishes
/// no grid of its own. None of them could land on such a control, so a deck,
/// a story or a tab that a finger opens was simply not there for them.
///
/// Wrapped in this, the control takes focus and Enter, Space, Select or a
/// controller's A press it — the same [ActivateIntent] a Material button
/// answers, which is also what gaze's blink and the controller's R1 send. It
/// draws nothing itself: the app-wide D-pad ring frames whatever holds focus
/// (`GazeFocusRingLayer`), so every control looks focused the same way.
class DpadFocusable extends StatelessWidget {
  const DpadFocusable({
    super.key,
    required this.onActivate,
    required this.child,
    this.focusNode,
    this.parentNode,
    this.autofocus = false,
  });

  /// What a press does — normally the very callback the tap runs. Null takes
  /// the control out of traversal, as a disabled Material button is.
  final VoidCallback? onActivate;

  final Widget child;
  final FocusNode? focusNode;

  /// Where this control sits in the focus tree, when that is not where it
  /// sits in the widget tree: a control floating above the router (the AI
  /// Buddy launcher) attaches under the shell, or no traversal from the hub
  /// could ever find it. See `dpadFloatingParent`.
  final FocusNode? parentNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final press = onActivate;
    return Actions(
      actions: <Type, Action<Intent>>{
        if (press != null) ...{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              press();
              return null;
            },
          ),
          // The web maps Enter to this one rather than ActivateIntent.
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              press();
              return null;
            },
          ),
        },
      },
      child: Focus(
        focusNode: focusNode,
        parentNode: parentNode,
        autofocus: autofocus,
        canRequestFocus: press != null,
        child: child,
      ),
    );
  }
}

/// Reads a panel of information aloud — the press behind a [DpadInfoStop].
///
/// Made by the screen (which knows the learner's language and voice) and
/// handed both to the panel and to the grid cell that stands for it, so a
/// key press on the panel and a blink or an R1 on its cell read the same
/// words. The panel attaches itself on every build; nothing is kept once it
/// is gone.
class DpadReadAloud {
  DpadReadAloud(this._speak);

  final void Function(String text) _speak;
  BuildContext? _panel;

  /// Speaks everything written on the panel, top to bottom.
  void read() {
    final panel = _panel;
    if (panel is! Element || !panel.mounted) return;
    final text = panelText(panel);
    if (text.isNotEmpty) _speak(text);
  }

  /// The words on [root], in reading order: explicit labels (what a screen
  /// reader says for a picture or a ring) and visible text, each once.
  static String panelText(Element root) {
    final parts = <String>[];
    void take(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      if (!FocusedLabel.pronounceable(text)) return;
      if (parts.isNotEmpty && parts.last == text) return;
      parts.add(text);
    }

    void visit(Element element) {
      final widget = element.widget;
      if (widget is Semantics && widget.properties.label != null) {
        // A labelled panel says what it means in one go; its pieces below
        // would only repeat it.
        take(widget.properties.label);
        if (widget.excludeSemantics || widget.properties.label!.length > 24) {
          return;
        }
      }
      if (widget is RichText) take(widget.text.toPlainText());
      element.visitChildren(visit);
    }

    visit(root);
    return parts
        .map((p) => RegExp(r'[.!?:]$').hasMatch(p) ? p : '$p.')
        .join(' ');
  }
}

/// A panel of information as a D-pad stop: Progress's charts, totals and
/// badges, which are not controls at all.
///
/// The arrow keys and the gaze / controller cursor only ever stop on things
/// that can be pressed, so a page that ends in information — Category
/// Progress, Recent Games, the badges — could never be brought into view by
/// a learner whose only input is a D-pad; the cursor wrapped to the top
/// first. As a stop it scrolls into view when reached, and pressing it reads
/// it aloud ([DpadReadAloud]).
class DpadInfoStop extends StatelessWidget {
  const DpadInfoStop({super.key, required this.reader, required this.child});

  final DpadReadAloud reader;
  final Widget child;

  @override
  Widget build(BuildContext context) => DpadFocusable(
    onActivate: reader.read,
    child: Builder(
      builder: (panel) {
        reader._panel = panel;
        return child;
      },
    ),
  );
}

/// A [GestureDetector] the D-pad can press too: the same arguments and the
/// same touch behaviour, inside a [DpadFocusable] that presses [onTap].
///
/// For the tap-only detectors that draw a card, a chip or a face, where the
/// tap is a multi-line closure: one word changes at the call site, and the
/// callback is still written once.
class DpadGestureDetector extends StatelessWidget {
  const DpadGestureDetector({
    super.key,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onLongPress,
    this.behavior,
    this.excludeFromSemantics = false,
    this.child,
  });

  final GestureTapCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressCallback? onLongPress;
  final HitTestBehavior? behavior;
  final bool excludeFromSemantics;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DpadFocusable(
    onActivate: onTap,
    child: GestureDetector(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onLongPress: onLongPress,
      behavior: behavior,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    ),
  );
}
