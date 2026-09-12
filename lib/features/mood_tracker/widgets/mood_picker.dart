import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/mood_models.dart';

/// A mood, and — when the learner wrote one — why they feel that way.
class MoodAnswer {
  const MoodAnswer(this.mood, {this.note});

  final MoodType mood;

  /// Trimmed and non-empty, or null: three spaces is not a note.
  final String? note;

  bool get hasNote => note != null;
}

/// The faces every "how do you feel?" question is answered with, plus the
/// optional **"Write why you feel this way"** field that goes with them.
///
/// One widget for all four places the question is asked — the after-step sheet,
/// the day-end sheet, the scheduled check-in pop-up and the routine
/// interstitial — because a shortcut that quietly offered a different
/// vocabulary, or dropped the note, would skew the very data the insights and
/// the educator's wellbeing view are drawn from.
///
/// Two shapes, decided by [showNote] (which is
/// `MoodPresentation.showNote` — off exactly where a keyboard is the obstacle
/// rather than the point):
///
///  * **Without a note: one tap answers.** A face *is* the answer, which is
///    the whole reason the quick faces exist.
///  * **With a note: a face selects, and Save answers.** The note has to be
///    typable after the face is chosen, so the answer cannot be sent on the
///    tap that chooses it. Saving with an empty field is a perfectly good
///    answer — the field says "optional" and means it.
class MoodPicker extends StatefulWidget {
  const MoodPicker({
    super.key,
    required this.choices,
    required this.showNote,
    required this.isFilipino,
    required this.onAnswer,
  });

  /// The learner's own face set (`MoodPresentation.choices`).
  final List<MoodType> choices;

  /// Offer the optional note field, and with it the two-step select-then-save.
  final bool showNote;

  final bool isFilipino;

  /// The finished answer. Called once per answer: on the tap of a face when
  /// there is no note field, on Save when there is.
  final ValueChanged<MoodAnswer> onAnswer;

  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker> {
  final TextEditingController _note = TextEditingController();

  final FocusNode _noteFocus = FocusNode();

  /// Pending [_revealSave], cancelled on dispose — a widget test that ends
  /// while it is in flight would otherwise fail on a pending timer.
  Timer? _reveal;

  MoodType? _selected;

  /// The keyboard height as of the last build, so the reveal can follow the
  /// keyboard down instead of guessing when it has finished sliding in.
  double? _lastInset;

  @override
  void initState() {
    super.initState();
    _noteFocus.addListener(() {
      if (_noteFocus.hasFocus) _revealSave(afterKeyboard: true);
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _noteFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Scrolls Save back into view.
  ///
  /// Both places this widget lives are short, scrollable boxes — a bottom
  /// sheet and a dialog — and both shrink to make room for the keyboard. On
  /// the tablet that left the learner typing a sentence with the Save button
  /// off the bottom of the pop-up: everything still reachable by scrolling,
  /// but the one control they now need was the one they could not see.
  ///
  /// [afterKeyboard] waits for the keyboard's entrance animation, because the
  /// box is still being resized while it slides in and a scroll computed
  /// mid-animation lands in the wrong place.
  ///
  /// Scrolls to the bottom rather than to the button itself: the way out
  /// ("Not now" / "Later" / "Skip") sits just below Save, and a learner who
  /// has decided not to answer after all should be able to see that too.
  void _revealSave({bool afterKeyboard = false, bool jump = false}) {
    void run() {
      if (!mounted) return;
      // No Scrollable — a caller that lays this out at full height — means
      // nothing to scroll and nothing to fix.
      final position = Scrollable.maybeOf(context)?.position;
      if (position == null || !position.hasContentDimensions) return;
      if (jump) {
        position.jumpTo(position.maxScrollExtent);
      } else {
        position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }

    if (afterKeyboard) {
      // A backstop for the rare case where the keyboard never reports an
      // inset (a hardware keyboard, a desktop window): the inset-tracking in
      // [build] does the work everywhere else.
      _reveal?.cancel();
      _reveal = Timer(const Duration(milliseconds: 350), run);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }

  void _tap(MoodType mood) {
    if (!widget.showNote) {
      widget.onAnswer(MoodAnswer(mood));
      return;
    }
    final first = _selected == null;
    setState(() => _selected = mood);
    // The field and Save appear below the faces on the first pick, which in a
    // short sheet can be below the fold.
    if (first) _revealSave();
  }

  void _save() {
    final mood = _selected;
    if (mood == null) return;
    final text = _note.text.trim();
    widget.onAnswer(MoodAnswer(mood, note: text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isFilipino = widget.isFilipino;
    final selected = _selected;

    // Follow the keyboard. It slides in over a few hundred milliseconds, and
    // the box this widget lives in is re-laid-out at every step of that — so
    // a single scroll fired when focus arrives lands against a scroll extent
    // that is about to change, and stops short with Save still off-screen
    // (measured on the tablet). Re-scrolling on each inset instead tracks it
    // all the way down.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _lastInset) {
      _lastInset = inset;
      if (widget.showNote && _noteFocus.hasFocus) _revealSave(jump: true);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FaceGrid(
          choices: widget.choices,
          selected: selected,
          isFilipino: isFilipino,
          onTap: _tap,
        ),
        if (widget.showNote && selected != null) ...[
          const SizedBox(height: 16),
          Semantics(
            label: isFilipino
                ? 'Opsyonal na tala tungkol sa pakiramdam mo'
                : 'Optional note about how you feel',
            child: TextField(
              controller: _note,
              focusNode: _noteFocus,
              maxLines: 3,
              minLines: 2,
              maxLength: 200,
              textInputAction: TextInputAction.newline,
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              decoration: InputDecoration(
                // The same words as the full Mood Check-In screen, so the
                // field a learner meets in a pop-up is the field they already
                // know from the screen.
                hintText: isFilipino
                    ? 'Isulat kung bakit ganyan ang pakiramdam mo '
                          '(opsyonal)...'
                    : 'Write why you feel this way (optional)...',
                filled: true,
                fillColor: hc.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: hc.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: hc.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: selected.darkColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true,
              label: isFilipino
                  ? 'I-save ang pakiramdam mo'
                  : 'Save how you feel',
              excludeSemantics: true,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Text(
                  selected.emoji,
                  style: const TextStyle(fontSize: 20),
                  textScaler: const TextScaler.linear(1.0),
                ),
                label: Text(
                  isFilipino ? 'I-save' : 'Save',
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  // `darkColor`, not `color`: the label is white, and white on
                  // the pale happy / tired swatches fails contrast badly.
                  backgroundColor: selected.darkColor,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FaceGrid extends StatelessWidget {
  const _FaceGrid({
    required this.choices,
    required this.selected,
    required this.isFilipino,
    required this.onTap,
  });

  final List<MoodType> choices;
  final MoodType? selected;
  final bool isFilipino;
  final ValueChanged<MoodType> onTap;

  @override
  Widget build(BuildContext context) {
    // Fewer faces buy bigger targets, matching the Home card.
    final size = choices.length <= 3 ? 76.0 : 60.0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final mood in choices)
          _Face(
            mood: mood,
            size: size,
            selected: mood == selected,
            isFilipino: isFilipino,
            onTap: () => onTap(mood),
          ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.mood,
    required this.size,
    required this.selected,
    required this.isFilipino,
    required this.onTap,
  });

  final MoodType mood;
  final double size;
  final bool selected;
  final bool isFilipino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final tint = hc.hc ? hc.primary : (hc.isDark ? mood.darkColor : mood.color);
    final label = mood.labelOf(isFilipino: isFilipino);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      // Its own Material: this is rendered in a route above the app's, and a
      // bare InkWell there has no ink to splash on.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    // The chosen face is filled and ringed harder than the
                    // rest: with a note field on screen the selection has to
                    // survive the learner looking away at the keyboard.
                    color: tint.withValues(
                      alpha: selected
                          ? (hc.hc ? 0.45 : 0.38)
                          : (hc.hc ? 0.30 : 0.18),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: tint, width: selected ? 4 : 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mood.emoji,
                    style: TextStyle(
                      fontSize: size * 0.45,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  // Comfortably wider than the circle, because the label is
                  // what has to fit — not the face. Tied to the circle it was
                  // 68px, and "Frustrated" is one word wider than that, so
                  // Flutter broke it mid-word ("Frustrat / ed").
                  width: size + 40,
                  child: Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
