import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../models/board_models.dart';
import '../models/board_presentation.dart';
import '../models/board_seed_data.dart';
import '../models/custom_board.dart';
import '../providers/custom_board_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Builds the **active profile's** own Talk Board tab.
///
/// Two things go on this board:
///
///   * seed tiles pulled forward, so "I need help" and "Bathroom" sit on the
///     first tab instead of two tabs away, and
///   * tiles authored right here — "Ate Maria", "Sir Kevin", this particular
///     school — which is the half no seed catalogue can ever supply.
///
/// Edits happen on a working copy and are committed by Save, so the learner's
/// live board never passes through a half-finished state. Reached from Talk
/// Board's app bar; it writes to whichever profile is signed in, which is what
/// makes "a parent sets this up on their child's profile" work.
class BoardTemplateBuilderScreen extends ConsumerStatefulWidget {
  const BoardTemplateBuilderScreen({super.key});

  @override
  ConsumerState<BoardTemplateBuilderScreen> createState() =>
      _BoardTemplateBuilderScreenState();
}

class _BoardTemplateBuilderScreenState
    extends ConsumerState<BoardTemplateBuilderScreen> {
  /// The working copy: the board's tiles, in order.
  final List<BoardTile> _tiles = [];

  /// Currently browsing seed category.
  BoardTileCategory _browseCategory = BoardTileCategory.greetings;

  final _nameController = TextEditingController();

  bool _isPreviewing = false;

  /// Reorder/remove mode.
  bool _editMode = false;

  /// True once the working copy differs from what is stored, so Back can warn
  /// instead of silently discarding an adult's work.
  bool _dirty = false;

  /// Captured in [initState]; reading `ref` in [dispose] is not safe and a
  /// preview left running would talk over the next screen.
  late final TtsService _tts;

  static const int _maxTiles = kMaxCustomBoardTiles;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    // Load the board that already exists — the builder used to open blank
    // every time, so "editing" your board meant rebuilding it from scratch.
    final board = ref.read(customBoardProvider);
    _nameController.text = board.name;
    _tiles.addAll(board.resolvedTiles);
  }

  @override
  void dispose() {
    _tts.stop();
    _nameController.dispose();
    super.dispose();
  }

  void _markDirty() => _dirty = true;

  // ─── Working-copy edits ──────────────────────────

  void _addSeedTile(BoardTile tile) {
    if (_tiles.length >= _maxTiles) {
      AppSnackBar.warning(context, message: _t(context).bbMax(_maxTiles));
      return;
    }
    if (_tiles.any((t) => t.id == tile.id)) {
      AppSnackBar.info(context, message: _t(context).bbAlready);
      return;
    }
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _tiles.add(tile);
      _markDirty();
    });
  }

  void _removeTile(int index) {
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _tiles.removeAt(index);
      _markDirty();
    });
  }

  void _reorderTile(int oldIndex, int newIndex) {
    // `onReorderItem` (not the obsolete `onReorder`) already adjusts newIndex
    // for the removed item, so this is a plain move.
    setState(() {
      final tile = _tiles.removeAt(oldIndex);
      _tiles.insert(newIndex, tile);
      _markDirty();
    });
  }

  Future<void> _previewBoard() async {
    if (_tiles.isEmpty || _isPreviewing) return;
    setState(() => _isPreviewing = true);
    ref.read(hapticServiceProvider).success();

    final fil = ref.read(settingsProvider).locale == 'fil';

    for (final tile in _tiles) {
      if (!mounted) return;
      final text = fil ? tile.labelFil : tile.label;
      if (fil) {
        await _tts.speakFilipino(text);
      } else {
        await _tts.speakEnglish(text);
      }
      await Future.delayed(Duration(milliseconds: 400 + text.length * 30));
    }

    if (mounted) setState(() => _isPreviewing = false);
  }

  // ─── Authoring a tile ────────────────────────────

  Future<void> _createCustomTile() async {
    if (_tiles.length >= _maxTiles) {
      AppSnackBar.warning(context, message: _t(context).bbMax(_maxTiles));
      return;
    }
    final tile = await showDialog<BoardTile>(
      context: context,
      builder: (_) => const _CustomTileDialog(),
    );
    if (tile == null || !mounted) return;

    ref.read(hapticServiceProvider).success();
    setState(() {
      _tiles.add(tile);
      _markDirty();
    });
    AppSnackBar.success(context, message: _t(context).bbAdded(tile.label));
  }

  Future<void> _editCustomTile(int index) async {
    final existing = _tiles[index];
    if (!existing.isCustom) return;

    final tile = await showDialog<BoardTile>(
      context: context,
      builder: (_) => _CustomTileDialog(existing: existing),
    );
    if (tile == null || !mounted) return;

    setState(() {
      _tiles[index] = tile;
      _markDirty();
    });
  }

  // ─── Commit ──────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.warning(context, message: _t(context).bbNeedName);
      return;
    }

    final board = CustomBoard(
      name: name,
      tileIds: _tiles.map((t) => t.id).toList(),
      // Only the authored tiles are stored inline; seed entries are ids that
      // re-resolve, so a later seed wording fix reaches boards already built.
      customTiles: [
        for (final t in _tiles)
          if (t.isCustom) t,
      ],
      updatedAt: DateTime.now(),
    );

    await ref.read(customBoardProvider.notifier).replace(board);
    if (!mounted) return;

    _dirty = false;
    ref.read(hapticServiceProvider).celebration();
    AppSnackBar.success(
      context,
      message: _tiles.isEmpty
          // Saving an empty board is a legitimate way to remove the tab, so
          // say what actually happened rather than claiming a save of nothing.
          ? _t(context).bbCleared
          : _t(context).bbSaved(name, _tiles.length),
    );
    context.popOrGo('/communication-board');
  }

  /// Guards Back when there is unsaved work.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context).bbDiscardTitle),
        content: Text(
          _t(context).bbDiscardBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_t(context).bbKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_t(context).abDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // ─── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final availableTiles = BoardSeedData.forCategory(_browseCategory);
    final addedIds = _tiles.map((t) => t.id).toSet();

    return PopScope(
      canPop: false,
      // Guards the Android system back gesture; the in-app Back button is
      // guarded by AppBackButton.onBeforePop above.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        // `context.mounted`, not `mounted`: this is `build`'s context, which
        // the State's own mounted flag does not speak for.
        if (!discard || !context.mounted) return;
        context.popOrGo('/communication-board');
      },
      child: Scaffold(
        backgroundColor: hc.background,
        appBar: AppBar(
          title: Text(
            _t(context).bbMyBoard,
            style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          // `onBeforePop` returning false cancels the pop, which is exactly
          // the unsaved-changes guard — no bespoke back handling needed.
          leading: AppBackButton(onBeforePop: _confirmDiscard),
          actions: [
            IconButton(
              icon: Icon(
                _editMode ? Icons.done_rounded : Icons.edit_rounded,
                color: hc.primary,
              ),
              onPressed: () => setState(() => _editMode = !_editMode),
              tooltip: _editMode ? _t(context).bbDoneEditing : _t(context).bbReorder,
            ),
            IconButton(
              icon: Icon(Icons.play_arrow_rounded, color: hc.primary),
              onPressed: _isPreviewing || _tiles.isEmpty ? null : _previewBoard,
              tooltip: _t(context).bbPreview,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // The header above the tile grid — name field, preview box,
            // counter row, tabs — is taller than a landscape phone, and the
            // grid is the Expanded child that gets squeezed. Below this height
            // everything optional in the header shrinks so the grid keeps a
            // usable share.
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final compact =
                constraints.maxHeight < 520 * textScale.clamp(1.0, 1.6);
            // The board-so-far box grows with its contents — a row of chips at
            // the 2.0x font scale is far taller than the empty-state hint — and
            // it sits above the Expanded tile grid, so left unbounded it pushes
            // the whole Column past the viewport. Cap it at a third of the
            // height and let it scroll inside that.
            final previewMin = compact ? 40.0 : 120.0;

            return Column(
              children: [
                // Everything above the tile grid — name field, board box,
                // counter row, authoring button — lives in one bounded
                // scroll region.
                //
                // Each of these was capped individually before, and every
                // cap had to be re-tuned whenever a row was added or the
                // font scale moved; the grid below is Expanded, so a
                // header that outgrows its share pushes the Column past
                // the viewport. Bounding the header once makes that
                // structurally impossible: past this height it scrolls.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ─── Board name ──────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: padding,
                            vertical: 8,
                          ),
                          child: TextField(
                            controller: _nameController,
                            onChanged: (_) => _markDirty(),
                            decoration: InputDecoration(
                              // It becomes the tab label on Talk Board, so say so.
                              labelText: _t(context).bbNameField,
                              prefixIcon: const Icon(Icons.label_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              isDense: compact,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: compact ? 8 : 12,
                              ),
                            ),
                            maxLength: 30,
                            // The character counter is a whole line of chrome for a
                            // field nobody overruns; it is the first thing to go.
                            buildCounter: compact
                                ? (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) => null
                                : null,
                          ),
                        ),

                        // ─── The board so far ────────────
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: padding),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(minHeight: previewMin),
                          decoration: BoxDecoration(
                            color: hc.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: hc.border, width: 1.5),
                          ),
                          child: _tiles.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(compact ? 4 : 24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!compact) ...[
                                          Icon(
                                            Icons.dashboard_customize_rounded,
                                            size: 40,
                                            color: hc.textSecondary,
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        Text(
                                          _t(context).bbTapBelow,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: hc.textSecondary,
                                              ),
                                          textAlign: TextAlign.center,
                                          maxLines: compact ? 1 : 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _editMode
                              ? ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _tiles.length,
                                  onReorderItem: _reorderTile,
                                  itemBuilder: (context, index) {
                                    final tile = _tiles[index];
                                    // Its own Material: the row is tappable now,
                                    // and ListTile paints ink on the nearest
                                    // Material — which is behind the decorated
                                    // container above, so the ripple would be
                                    // invisible (and Flutter asserts about it).
                                    return Material(
                                      key: ValueKey(tile.id),
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        leading: Text(
                                          tile.emoji,
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        title: Text(tile.label),
                                        subtitle: Text(
                                          tile.isCustom
                                              ? _t(context).bbMyWord(tile.labelFil)
                                              : tile.labelFil,
                                        ),
                                        // Only authored tiles are editable; a seed
                                        // tile's wording belongs to the app.
                                        onTap: tile.isCustom
                                            ? () => _editCustomTile(index)
                                            : null,
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.remove_circle_rounded,
                                            color: HCColor.of(context).graphic(AppColors.error),
                                          ),
                                          tooltip: _t(context).bbRemove(tile.label),
                                          onPressed: () => _removeTile(index),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _tiles.map((tile) {
                                    return Chip(
                                      avatar: Text(
                                        tile.emoji,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      // `fittedStyle`, not `FitText`: a Chip in
                                      // a Wrap measures intrinsics, where a
                                      // LayoutBuilder throws.
                                      label: Text(
                                        tile.label,
                                        style: fittedStyle(
                                          context,
                                          tile.label,
                                          AppTypography.labelMedium,
                                        ),
                                      ),
                                      backgroundColor: tile.isCustom
                                          ? AppColors.primary.withValues(
                                              alpha: 0.14,
                                            )
                                          : null,
                                      deleteIcon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onDeleted: () =>
                                          _removeTile(_tiles.indexOf(tile)),
                                    );
                                  }).toList(),
                                ),
                        ),

                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: padding,
                            vertical: compact ? 2 : 8,
                          ),
                          child: Row(
                            children: [
                              // Expanded, not Spacer-and-fixed: at the 2.0x font scale
                              // the counter plus "Clear All" is wider than a 360 dp
                              // phone, and the counter is the half that can shorten.
                              Expanded(
                                child: Text(
                                  _t(context).bbCount(_tiles.length, _maxTiles),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: hc.textSecondary,
                                  ),
                                ),
                              ),
                              // Icon-only when compact: at 2.0x on a 360 dp
                              // phone a labelled "Clear All" plus the
                              // authoring button is wider than the row even
                              // with the counter squeezed to nothing.
                              if (_tiles.isNotEmpty)
                                compact
                                    ? IconButton(
                                        onPressed: () => setState(() {
                                          _tiles.clear();
                                          _markDirty();
                                        }),
                                        icon: const Icon(
                                          Icons.clear_all_rounded,
                                        ),
                                        tooltip: _t(context).tbClearAll,
                                        visualDensity: VisualDensity.compact,
                                      )
                                    : TextButton.icon(
                                        onPressed: () => setState(() {
                                          _tiles.clear();
                                          _markDirty();
                                        }),
                                        icon: const Icon(
                                          Icons.clear_all_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _t(context).bbClearAll,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              // Too short for a row of its own — ride along here so the
                              // action is never simply unavailable.
                              if (compact)
                                IconButton(
                                  onPressed: _createCustomTile,
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                  ),
                                  tooltip: _t(context).bbMakeWord,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),

                        if (!compact) ...[
                          const Divider(height: 1),

                          // ─── Make your own word ──────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              8,
                              padding,
                              0,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _createCustomTile,
                                // Hand-built instead of OutlinedButton.icon: that packs
                                // icon and label into a Row with no give, and at 2.0x
                                // on a 360 dp phone the label ran 99 px off the right.
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_circle_outline_rounded),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _t(context).bbMakeWord,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ─── Seed category tabs ──────────
                SizedBox(
                  height: compact ? 42 : 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: compact ? 2 : 8,
                    ),
                    itemCount: BoardTileCategoryX.seedValues.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = BoardTileCategoryX.seedValues[index];
                      final isActive = cat == _browseCategory;
                      return ChoiceChip(
                        selected: isActive,
                        label: Text(
                          '${cat.emoji} ${Localizations.localeOf(context).languageCode == 'fil' ? cat.labelFil : cat.label}',
                        ),
                        onSelected: (_) =>
                            setState(() => _browseCategory = cat),
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                      );
                    },
                  ),
                ),

                // ─── Available seed tiles ────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.isTablet ? 4 : 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        // A builder tile stacks one more line than a board tile
                        // (English AND Filipino), so it needs the same
                        // font-scale-aware height, minus a little.
                        childAspectRatio:
                            boardTileAspectRatio(
                              MediaQuery.textScalerOf(context).scale(1.0),
                            ) -
                            0.06,
                      ),
                      itemCount: availableTiles.length,
                      itemBuilder: (context, index) {
                        final tile = availableTiles[index];
                        final isAdded = addedIds.contains(tile.id);

                        return Semantics(
                              button: !isAdded,
                              label:
                                  '${tile.label}, ${tile.labelFil}, '
                                  '${isAdded ? _t(context).bbAlreadyAdded : _t(context).bbTapToAdd}',
                              child: GestureDetector(
                                onTap: isAdded
                                    ? null
                                    : () => _addSeedTile(tile),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isAdded
                                        ? AppColors.success.withValues(
                                            alpha: 0.1,
                                          )
                                        : hc.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isAdded
                                          ? AppColors.success
                                          : hc.border,
                                      width: isAdded ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            tile.emoji,
                                            style: const TextStyle(
                                              fontSize: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Flexible(
                                        // The phrase this tile will say, in a
                                        // fixed-width picker cell -- it was
                                        // splitting "af / ternoon".
                                        child: FitText(
                                          tile.label,
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isAdded
                                                    ? HCColor.of(context).successText
                                                    : hc.textPrimary,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          tile.labelFil,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: hc.textSecondary,
                                              ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isAdded)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: HCColor.of(context).graphic(AppColors.success),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 250.ms, delay: (index * 30).ms)
                            .slideY(begin: 0.05, end: 0);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // ─── Save ──────────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: Text(_t(context).bbSaveBoard),
          backgroundColor: HCColor.of(context).primary,
          foregroundColor: HCColor.of(context).textOnPrimary,
        ),
      ),
    );
  }
}

// ─── Authoring dialog ───────────────────────────────────

/// Creates or edits one authored tile: an English word, an optional Filipino
/// one, and a picture from [kCustomTileEmoji].
///
/// Pops the finished [BoardTile], or null if cancelled. Editing keeps the
/// tile's id so saved phrases that already reference it keep resolving.
class _CustomTileDialog extends StatefulWidget {
  const _CustomTileDialog({this.existing});

  final BoardTile? existing;

  @override
  State<_CustomTileDialog> createState() => _CustomTileDialogState();
}

class _CustomTileDialogState extends State<_CustomTileDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late final TextEditingController _labelFil = TextEditingController(
    text: widget.existing?.labelFil ?? '',
  );
  late String _emoji = widget.existing?.emoji ?? kCustomTileEmoji.first;

  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _labelFil.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validateCustomTile(
      label: _label.text,
      labelFil: _labelFil.text,
      emoji: _emoji,
      filipino: Localizations.localeOf(context).languageCode == 'fil',
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      buildCustomTile(
        label: _label.text,
        labelFil: _labelFil.text,
        emoji: _emoji,
        id: widget.existing?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return AlertDialog(
      title: Text(widget.existing == null ? _t(context).bbMakeWord : _t(context).bbEditWord),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _label,
                autofocus: true,
                maxLength: kMaxCustomTileLabel,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _t(context).bbWordEn,
                  hintText: _t(context).bbWordEnHint,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              TextField(
                controller: _labelFil,
                maxLength: kMaxCustomTileLabel,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _t(context).bbWordFil,
                  hintText: _t(context).bbWordFilHint,
                ),
              ),
              const SizedBox(height: 8),
              Text(_t(context).bbPicture, style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              // A fixed palette, not a system emoji keyboard: it renders the
              // same on every device and an adult can scan it in one look.
              SizedBox(
                height: 180,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: kCustomTileEmoji.length,
                  itemBuilder: (context, index) {
                    final e = kCustomTileEmoji[index];
                    final selected = e == _emoji;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: _t(context).bbPictureN(index + 1),
                      child: GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? hc.primary.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? hc.primary : hc.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).errorText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(context).cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? _t(context).tbAdd : _t(context).gmSave),
        ),
      ],
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
