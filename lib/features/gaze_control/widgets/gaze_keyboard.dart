import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../logic/gaze_focus_driver.dart';
import '../services/gaze_metrics.dart';
import 'gaze_dpad_scope.dart';

/// What the gaze keyboard types into: a text field found through the focus,
/// or a screen's own [TextEditingController].
abstract class GazeKeyboardTarget {
  TextEditingValue get value;
  set value(TextEditingValue next);

  /// When letters are capitals, as the field asks: always (a code), at the
  /// start of each word or sentence, or never.
  TextCapitalization get capitalization => TextCapitalization.sentences;

  /// The field's "done" / "send" action, after the keyboard closes.
  void submit();
}

class _EditableTarget implements GazeKeyboardTarget {
  _EditableTarget(this.state);
  final EditableTextState state;

  @override
  TextEditingValue get value => state.textEditingValue;

  @override
  TextCapitalization get capitalization => state.widget.textCapitalization;

  @override
  set value(TextEditingValue next) =>
      // Same path as the system keyboard: formatters (max length, upper
      // case) and onChanged all run.
      state.userUpdateTextEditingValue(next, SelectionChangedCause.keyboard);

  @override
  void submit() {
    final action = state.widget.textInputAction ?? TextInputAction.done;
    state.performAction(action);
  }
}

class _ControllerTarget implements GazeKeyboardTarget {
  _ControllerTarget(this.controller, this.onSubmit);
  final TextEditingController controller;
  final VoidCallback? onSubmit;

  @override
  TextEditingValue get value => controller.value;

  @override
  TextCapitalization get capitalization => TextCapitalization.sentences;

  @override
  set value(TextEditingValue next) => controller.value = next;

  @override
  void submit() => onSubmit?.call();
}

/// The **gaze keyboard**: big keys a learner types with head moves and
/// blinks, with scanning, with one switch, or by naming a key aloud — the
/// same D-pad as every other gaze screen ([GazeDpadScope]), so it needs no
/// new gestures. The system keyboard is outside the app and cannot be driven
/// by gaze at all, so a hands-free learner could focus a text field and never
/// put a letter in it.
///
/// Opens by itself when gaze presses a text field ([openForFocus]); screens
/// that keep their own controller open it directly ([show]).
abstract final class GazeKeyboard {
  /// When the focused control is a text field, opens the gaze keyboard for it
  /// and returns true.
  static bool openForFocus() {
    final context = GazeFocusDriver.focused?.context;
    if (context == null) return false;
    final state = editableFor(context);
    if (state == null || state.widget.readOnly) return false;
    hideSystemKeyboard();
    _open(context, _EditableTarget(state), hint: null);
    return true;
  }

  /// Opens the gaze keyboard over [controller]; [onSubmit] runs on Done.
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    String? hint,
    VoidCallback? onSubmit,
  }) {
    hideSystemKeyboard();
    return _open(context, _ControllerTarget(controller, onSubmit), hint: hint);
  }

  /// The text field [context] belongs to, if any.
  static EditableTextState? editableFor(BuildContext context) {
    final above = context.findAncestorStateOfType<EditableTextState>();
    if (above != null) return above;
    EditableTextState? found;
    void visit(Element e, int depth) {
      if (found != null || depth > 24) return;
      if (e is StatefulElement && e.state is EditableTextState) {
        found = e.state as EditableTextState;
        return;
      }
      e.visitChildren((c) => visit(c, depth + 1));
    }

    if (context is Element) context.visitChildren((c) => visit(c, 1));
    return found;
  }

  /// The system keyboard covers half the screen — the half gaze is steering —
  /// and cannot itself be steered by gaze.
  static void hideSystemKeyboard() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide').ignore();
  }

  static Future<void> _open(
    BuildContext context,
    GazeKeyboardTarget target, {
    required String? hint,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (_) => GazeKeyboardSheet(target: target, hint: hint),
    );
    // Focus goes back to the field, which raises the system keyboard again —
    // keep it down, as when gaze first reached the field.
    WidgetsBinding.instance.addPostFrameCallback((_) => hideSystemKeyboard());
    WidgetsBinding.instance.scheduleFrame();
  }
}

enum _Layer { letters, numbers }

/// The sheet itself. Public for tests.
class GazeKeyboardSheet extends StatefulWidget {
  const GazeKeyboardSheet({super.key, required this.target, this.hint});

  final GazeKeyboardTarget target;

  /// What is being typed ("Message", a field's label).
  final String? hint;

  @override
  State<GazeKeyboardSheet> createState() => _GazeKeyboardSheetState();
}

class _GazeKeyboardSheetState extends State<GazeKeyboardSheet> {
  _Layer _layer = _Layer.letters;

  /// The next letter is upper case (start of the text, after a sentence, or
  /// the shift key).
  bool _shift = false;
  bool _shiftLocked = false;

  static const _letterRows = [
    ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
    ['H', 'I', 'J', 'K', 'L', 'M', 'N'],
    ['O', 'P', 'Q', 'R', 'S', 'T', 'U'],
    ['V', 'W', 'X', 'Y', 'Z', 'Ñ'],
  ];
  static const _numberRows = [
    ['1', '2', '3', '4', '5', '6', '7'],
    ['8', '9', '0', '.', ',', '?', '!'],
    ['-', '’', '@', '/', '(', ')', ':'],
  ];

  @override
  void initState() {
    super.initState();
    // A field of capitals (a join code) shows capitals throughout, so the
    // keys look like what lands in the field.
    if (widget.target.capitalization == TextCapitalization.characters) {
      _shift = true;
      _shiftLocked = true;
    } else {
      _shift = _wantsCapital(widget.target.value);
    }
  }

  /// Whether the next letter starts a sentence — or a word, for a field that
  /// capitalises words (a name). Never for a field that wants none.
  bool _wantsCapital(TextEditingValue v) {
    final caps = widget.target.capitalization;
    if (caps == TextCapitalization.none) return false;
    final caret = v.selection.isValid ? v.selection.start : v.text.length;
    final upto = v.text.substring(0, caret.clamp(0, v.text.length));
    final before = upto.trimRight();
    if (before.isEmpty) return true;
    if (caps == TextCapitalization.words && upto.endsWith(' ')) return true;
    return before.endsWith('.') || before.endsWith('?') || before.endsWith('!');
  }

  TextSelection _selectionOf(TextEditingValue v) => v.selection.isValid
      ? v.selection
      : TextSelection.collapsed(offset: v.text.length);

  void _insert(String text) {
    final v = widget.target.value;
    final sel = _selectionOf(v);
    final next = v.text.replaceRange(sel.start, sel.end, text);
    widget.target.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    GazeMetrics.instance.keyTyped();
    setState(() {
      if (!_shiftLocked) _shift = _wantsCapital(widget.target.value);
    });
  }

  void _letter(String upper) {
    _insert(_shift ? upper : upper.toLowerCase());
  }

  void _backspace() {
    final v = widget.target.value;
    final sel = _selectionOf(v);
    if (sel.start != sel.end) {
      widget.target.value = TextEditingValue(
        text: v.text.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
      );
    } else if (sel.start > 0) {
      // Remove one whole character, even an emoji (several code units).
      final head = v.text.substring(0, sel.start).characters;
      final kept = head.skipLast(1).toString();
      widget.target.value = TextEditingValue(
        text: kept + v.text.substring(sel.start),
        selection: TextSelection.collapsed(offset: kept.length),
      );
    }
    GazeMetrics.instance.keyTyped();
    setState(() {
      if (!_shiftLocked) _shift = _wantsCapital(widget.target.value);
    });
  }

  void _toggleShift() {
    setState(() {
      if (_shift && !_shiftLocked) {
        _shiftLocked = true;
      } else if (_shiftLocked) {
        _shiftLocked = false;
        _shift = false;
      } else {
        _shift = true;
      }
    });
  }

  void _close() => Navigator.of(context).maybePop();

  void _done() {
    _close();
    // After the sheet is gone, so the field's own action (send, search, next
    // field) runs on the screen it belongs to.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.target.submit());
  }

  List<List<GazeDpadCell>> _rows(AppLocalizations t) {
    final keys = _layer == _Layer.letters ? _letterRows : _numberRows;
    return [
      for (final row in keys)
        [
          for (final k in row)
            GazeDpadCell(
              label: _layer == _Layer.letters && !_shift ? k.toLowerCase() : k,
              onActivate: () =>
                  _layer == _Layer.letters ? _letter(k) : _insert(k),
            ),
          if (_layer == _Layer.letters && identical(row, keys.last))
            GazeDpadCell(label: t.gzkShift, onActivate: _toggleShift),
        ],
      [
        GazeDpadCell(label: t.gzkSpace, onActivate: () => _insert(' ')),
        GazeDpadCell(label: t.gzkDelete, onActivate: _backspace),
        GazeDpadCell(
          label: _layer == _Layer.letters ? '123' : 'ABC',
          onActivate: () => setState(
            () => _layer = _layer == _Layer.letters
                ? _Layer.numbers
                : _Layer.letters,
          ),
        ),
        GazeDpadCell(label: t.gzkDone, onActivate: _done),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final rows = _rows(t);
    final height = MediaQuery.sizeOf(context).height;
    // The limit goes outside the gaze scope, which fills whatever it is given:
    // inside it, the sheet grew to the whole screen — the conversation hidden
    // and the Back pill under the status bar.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.72),
      child: GazeDpadScope(
        rows: rows,
        onExit: _close,
        exitLabel: t.back,
        builder: (context, gaze) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 52, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Preview(target: widget.target, hint: widget.hint),
                const SizedBox(height: 10),
                for (var r = 0; r < rows.length; r++)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          for (var c = 0; c < rows[r].length; c++)
                            Expanded(
                              // The bottom row's wide keys (Space, Done).
                              flex: r == rows.length - 1 && (c == 0 || c == 3)
                                  ? 2
                                  : 1,
                              child: _Key(
                                label: rows[r][c].label,
                                focused: gaze.isFocused(r, c),
                                onTap: rows[r][c].onActivate,
                                accent: r == rows.length - 1 && c == 3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What has been typed so far, so a learner can see it while the keyboard
/// covers the field.
class _Preview extends StatelessWidget {
  const _Preview({required this.target, this.hint});

  final GazeKeyboardTarget target;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final text = target.value.text;
    return Semantics(
      liveRegion: true,
      label: text.isEmpty ? (hint ?? '') : text,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hc.primary.withValues(alpha: 0.4), width: 2),
        ),
        child: Text(
          text.isEmpty ? (hint ?? '') : '$text▏',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            color: text.isEmpty ? hc.textHint : hc.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.focused,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final bool focused;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final fill = accent ? hc.fillFor(AppColors.primary) : hc.surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        elevation: focused ? 6 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused ? AppColors.accent : hc.primary.withValues(alpha: 0.15),
                width: focused ? 3 : 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: accent ? Colors.white : hc.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
