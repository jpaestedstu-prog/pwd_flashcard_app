import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../models/composer_presentation.dart';
import '../models/messaging_models.dart';

/// The sticker and sign pickers, drawn **inside** the thread for a learner
/// driving the app with their head.
///
/// The pickers used to be modal sheets, which a gaze D-pad cannot reach: the
/// scope walks the screen's own cells, so with a sheet open the highlight
/// kept moving over the chips *behind* it. The composer even promised "each
/// sticker is its own gaze cell" — it was not. In the thread, the panel's
/// tiles are the screen's cells: the Messages screen hands the scope these
/// rows while a panel is open, and every tile draws the focus ring.
///
/// Layouts are fixed-column grids so the rows the scope walks are the rows
/// the learner sees.

/// Stickers per gaze row.
const int kStickerColumns = 4;

/// Sign topics and words per gaze row.
const int kSignColumns = 3;

/// The sticker grid.
class InlineStickerPanel extends StatelessWidget {
  final bool isFilipino;
  final bool Function(int index) isFocused;
  final bool closeFocused;
  final ValueChanged<String> onPick;
  final VoidCallback onClose;

  const InlineStickerPanel({
    super.key,
    required this.isFilipino,
    required this.isFocused,
    required this.closeFocused,
    required this.onPick,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const stickers = MessageStickers.all;
    return _PanelFrame(
      title: isFilipino ? 'Pumili ng sticker' : 'Pick a sticker',
      isFilipino: isFilipino,
      closeFocused: closeFocused,
      onClose: onClose,
      children: [
        for (var row = 0; row * kStickerColumns < stickers.length; row++)
          Row(
            children: [
              for (var col = 0; col < kStickerColumns; col++)
                Expanded(
                  child: row * kStickerColumns + col < stickers.length
                      ? Padding(
                          padding: const EdgeInsets.all(4),
                          child: GazeTile(
                            focused: isFocused(row * kStickerColumns + col),
                            semanticsLabel:
                                MessageStickerNames.nameOf(
                                  stickers[row * kStickerColumns + col],
                                  isFilipino: isFilipino,
                                ) ??
                                stickers[row * kStickerColumns + col],
                            onTap: () =>
                                onPick(stickers[row * kStickerColumns + col]),
                            child: Text(
                              stickers[row * kStickerColumns + col],
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
      ],
    );
  }
}

/// The sign picker in two steps: a topic, then a word in it. Walking 140
/// words one cell at a time is not a picker; a dozen topics then a dozen
/// words is.
class InlineSignPanel extends StatelessWidget {
  final bool isFilipino;

  /// Null while the signable words load.
  final List<Flashcard>? signable;

  /// The open topic, or null for the topic list.
  final FlashcardCategory? category;
  final bool Function(int index) isFocused;
  final bool closeFocused;
  final bool backFocused;
  final ValueChanged<FlashcardCategory> onCategory;
  final ValueChanged<String> onWord;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const InlineSignPanel({
    super.key,
    required this.isFilipino,
    required this.signable,
    required this.category,
    required this.isFocused,
    required this.closeFocused,
    required this.backFocused,
    required this.onCategory,
    required this.onWord,
    required this.onBack,
    required this.onClose,
  });

  /// The topics that have at least one signable word, in enum order.
  static List<FlashcardCategory> topicsOf(List<Flashcard> signable) {
    final present = {for (final c in signable) c.category};
    return [
      for (final c in FlashcardCategory.values)
        if (present.contains(c)) c,
    ];
  }

  /// The signable words in [category], A to Z.
  static List<Flashcard> wordsIn(
    List<Flashcard> signable,
    FlashcardCategory category,
  ) => [
    for (final c in signable)
      if (c.category == category) c,
  ];

  @override
  Widget build(BuildContext context) {
    final list = signable;
    final open = category;
    final title = open == null
        ? (isFilipino ? 'Pumili ng paksa' : 'Pick a topic')
        : '${open.emoji} ${isFilipino ? open.labelFilipino : open.label}';

    final List<Widget> rows;
    if (list == null) {
      rows = [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (open == null) {
      final topics = topicsOf(list);
      rows = _grid(topics.length, (i) {
        final t = topics[i];
        return GazeTile(
          focused: isFocused(i),
          semanticsLabel: isFilipino ? t.labelFilipino : t.label,
          onTap: () => onCategory(t),
          child: Text(
            '${t.emoji} ${isFilipino ? t.labelFilipino : t.label}',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge,
          ),
        );
      });
    } else {
      final words = wordsIn(list, open);
      rows = _grid(words.length, (i) {
        final w = words[i];
        return GazeTile(
          focused: isFocused(i),
          semanticsLabel: isFilipino
              ? 'Senyas para sa ${w.wordFilipino}'
              : 'Sign for ${w.wordEnglish}',
          onTap: () => onWord(w.wordEnglish),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                w.wordEnglish,
                textAlign: TextAlign.center,
                style: AppTypography.labelLarge,
              ),
              Text(
                w.wordFilipino,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        );
      });
    }

    return _PanelFrame(
      title: title,
      isFilipino: isFilipino,
      closeFocused: closeFocused,
      onClose: onClose,
      backLabel: open == null
          ? null
          : (isFilipino ? 'Ibang paksa' : 'Other topics'),
      backFocused: backFocused,
      onBack: onBack,
      children: rows,
    );
  }

  static List<Widget> _grid(int count, Widget Function(int i) tile) => [
    for (var row = 0; row * kSignColumns < count; row++)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var col = 0; col < kSignColumns; col++)
            Expanded(
              child: row * kSignColumns + col < count
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: tile(row * kSignColumns + col),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
  ];
}

/// The panel's chrome: a title, the rows, and the Close (and Back) buttons
/// the gaze walk ends on.
class _PanelFrame extends StatelessWidget {
  final String title;
  final bool isFilipino;
  final bool closeFocused;
  final VoidCallback onClose;
  final String? backLabel;
  final bool backFocused;
  final VoidCallback? onBack;
  final List<Widget> children;

  const _PanelFrame({
    required this.title,
    required this.isFilipino,
    required this.closeFocused,
    required this.onClose,
    required this.children,
    this.backLabel,
    this.backFocused = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      decoration: BoxDecoration(
        color: hc.surface,
        border: Border(top: BorderSide(color: hc.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (backLabel != null && onBack != null) ...[
                  Expanded(
                    child: GazeTile(
                      focused: backFocused,
                      semanticsLabel: backLabel!,
                      onTap: onBack!,
                      child: Text(backLabel!, style: AppTypography.labelLarge),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: GazeTile(
                    focused: closeFocused,
                    semanticsLabel: isFilipino ? 'Isara' : 'Close',
                    onTap: onClose,
                    child: Text(
                      isFilipino ? 'Isara' : 'Close',
                      style: AppTypography.labelLarge,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable, gaze-focusable tile. Scrolls itself into view when the gaze
/// highlight lands on it, so a row below the fold is never walked blind.
class GazeTile extends StatefulWidget {
  final bool focused;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget child;

  const GazeTile({
    super.key,
    required this.focused,
    required this.semanticsLabel,
    required this.onTap,
    required this.child,
  });

  @override
  State<GazeTile> createState() => _GazeTileState();
}

class _GazeTileState extends State<GazeTile> {
  @override
  void didUpdateWidget(GazeTile old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: hc.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: widget.focused
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide(color: hc.border),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
