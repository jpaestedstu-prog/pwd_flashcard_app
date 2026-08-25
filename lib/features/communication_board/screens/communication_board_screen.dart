import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../models/board_models.dart';
import '../models/board_presentation.dart';
import '../models/board_vocabulary.dart';
import '../models/saved_phrase.dart';
import '../providers/board_phrases_provider.dart';
import '../providers/custom_board_provider.dart';
import '../../../widgets/adult_gate_dialog.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../gaze_control/models/gaze_action.dart';
import '../../gaze_control/models/gaze_models.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';
import '../../gaze_control/widgets/gaze_scope.dart';

/// Wraps [index] into 0…count-1, handling negatives so a left move from the
/// first tile lands on the last. Returns 0 for an empty set. Pure + testable.
int wrapBoardIndex(int index, int count) {
  if (count <= 0) return 0;
  return ((index % count) + count) % count;
}

/// Viewport height below which the board drops its optional header furniture.
///
/// The large-type banner and the saved-phrase strip are both aids that sit
/// *above* the grid, and on a short viewport (a landscape phone, a split-screen
/// pane) their natural height plus the sentence strip plus the tabs is taller
/// than the screen — the Column then overflows and the tile grid, the thing the
/// learner actually came for, is squeezed to nothing. Below this height the
/// board keeps the strip and the grid and drops the rest.
const double kBoardCompactHeight = 520;

/// Talk Board — an AAC board. Tap picture tiles to build a sentence, then
/// press speak to hear it. What each learner sees is decided by
/// [BoardPresentation], not by this widget.
class CommunicationBoardScreen extends ConsumerStatefulWidget {
  const CommunicationBoardScreen({super.key});

  @override
  ConsumerState<CommunicationBoardScreen> createState() =>
      _CommunicationBoardScreenState();
}

class _CommunicationBoardScreenState
    extends ConsumerState<CommunicationBoardScreen> {
  /// The sentence strip — ordered list of tiles the user has tapped.
  final List<BoardTile> _sentence = [];

  /// Currently active category filter. Initialised from the learner's own
  /// category set, which for a trimmed board does not start at `greetings`.
  late BoardTileCategory _activeCategory;

  /// Whether to display Filipino labels on tiles (false = English).
  bool _useFilipino = false;

  /// Whether the TTS is currently speaking.
  bool _isSpeaking = false;

  /// Gaze cursor: the index of the highlighted tile in the active category.
  /// Only visible / used when Gaze Control is enabled; touch ignores it.
  int _cursorIndex = 0;

  /// Captured in [initState] so [dispose] can silence a sentence that is still
  /// being spoken as the learner leaves. Reading `ref` during dispose is not
  /// safe, and the board used to keep talking over the next screen.
  late final TtsService _tts;

  /// Stable keys per **tab + tile id** so the gaze cursor can scroll itself
  /// into view.
  ///
  /// Not the grid index: an `AnimatedSwitcher` keeps the outgoing category's
  /// grid mounted for the length of the cross-fade, so index-keyed GlobalKeys
  /// put the same key on two live tiles at once. The framework reparented them
  /// and reported "parts of the widget tree being truncated unexpectedly" on
  /// every single category tap.
  ///
  /// And not the tile id alone, which was the first fix: a tile id is unique
  /// in the *catalogue*, but a custom board can pull a seed tile forward, so
  /// `n01` legitimately appears on both the learner's own tab and Needs — and
  /// the two grids collide again the moment they cross-fade between those two
  /// tabs. The tab qualifies the key.
  final Map<String, GlobalKey> _tileKeys = {};

  GlobalKey _tileKey(BoardTileCategory category, String tileId) =>
      _tileKeys.putIfAbsent('${category.name}:$tileId', GlobalKey.new);

  /// Everything this learner can say, seed tabs plus their own board.
  BoardVocabulary get _vocabulary => ref.read(boardVocabularyProvider);

  BoardPresentation get _presentation => _vocabulary.presentation;

  @override
  void initState() {
    super.initState();
    _activeCategory = ref.read(boardVocabularyProvider).categories.first;
    _tts = ref.read(ttsServiceProvider);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// The tiles on screen right now, after the learner's per-category cap.
  ///
  /// Resolved through the presentation for the same reason `build` does: if a
  /// profile switch retires the tab we are sitting on, the gaze cursor must
  /// count the tiles the learner can actually see, not the ones a category
  /// they no longer have would have shown.
  List<BoardTile> get _visibleTiles {
    final v = _vocabulary;
    return v.tilesFor(v.resolveCategory(_activeCategory));
  }

  // ─── Gaze cursor navigation (hands-free) ─────────
  // The four head zones drive a moving highlight: left/right scrub the tiles,
  // up speaks the sentence, down adds the highlighted tile. A blink cycles to
  // the next category so a gaze-only learner can reach every word. Touch is
  // unaffected — this state is inert unless Gaze Control is on.

  void _moveCursor(int delta) {
    final count = _visibleTiles.length;
    setState(() => _cursorIndex = wrapBoardIndex(_cursorIndex + delta, count));
    _scrollCursorIntoView();
  }

  void _addCursorTile() {
    final tiles = _visibleTiles;
    if (_cursorIndex < 0 || _cursorIndex >= tiles.length) return;
    _addTile(tiles[_cursorIndex]);
  }

  void _gazeNextCategory() {
    _setCategory(_vocabulary.nextCategory(_activeCategory));
  }

  void _setCategory(BoardTileCategory cat) {
    setState(() {
      _activeCategory = cat;
      _cursorIndex = 0;
    });
  }

  void _scrollCursorIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final v = _vocabulary;
      final category = v.resolveCategory(_activeCategory);
      final tiles = v.tilesFor(category);
      if (_cursorIndex < 0 || _cursorIndex >= tiles.length) return;
      final key = '${category.name}:${tiles[_cursorIndex].id}';
      final ctx = _tileKeys[key]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<GazeAction> _gazeActions() {
    final hasTiles = _visibleTiles.isNotEmpty;
    return [
      GazeAction(
        zone: GazeZone.left,
        label: 'Prev',
        icon: Icons.chevron_left_rounded,
        color: AppColors.secondary,
        enabled: hasTiles,
        onSelect: () => _moveCursor(-1),
      ),
      GazeAction(
        zone: GazeZone.right,
        label: 'Next',
        icon: Icons.chevron_right_rounded,
        color: AppColors.secondary,
        enabled: hasTiles,
        onSelect: () => _moveCursor(1),
      ),
      GazeAction(
        zone: GazeZone.up,
        label: 'Speak',
        icon: Icons.play_circle_filled_rounded,
        color: AppColors.success,
        enabled: _sentence.isNotEmpty,
        onSelect: _speakSentence,
      ),
      GazeAction(
        zone: GazeZone.down,
        label: 'Add',
        icon: Icons.add_circle_rounded,
        color: AppColors.primary,
        enabled: hasTiles,
        onSelect: _addCursorTile,
      ),
    ];
  }

  // ─── Sentence Strip Actions ──────────────────────

  void _addTile(BoardTile tile) {
    final max = _presentation.maxSentenceLength;
    if (_sentence.length >= max) {
      // Used to return silently, which reads as a dead board: the learner taps
      // and nothing at all happens. Say why.
      ref.read(hapticServiceProvider).error();
      _announce(
        'That is as long as a sentence can be. Speak it or clear it.',
        warning: true,
      );
      return;
    }
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _sentence.add(tile));
    // Immediate audio confirmation for learners who cannot read the chip they
    // just added — the long-press-to-hear gesture is undiscoverable for them.
    if (_presentation.speakOnTap) _speakSingleTile(tile);
  }

  void _removeLast() {
    if (_sentence.isEmpty) return;
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _sentence.removeLast());
  }

  void _clearSentence() {
    if (_sentence.isEmpty) return;
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _sentence.clear());
  }

  /// Speak [text] in whichever language the board is currently showing.
  Future<void> _speakInBoardLanguage(String text) {
    final settings = ref.read(settingsProvider);
    if (_useFilipino || settings.locale == 'fil') {
      return _tts.speakFilipino(text);
    }
    return _tts.speakEnglish(text);
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty || _isSpeaking) return;

    final text = _sentence
        .map((t) => _useFilipino ? t.labelFil : t.label)
        .join('. ');

    setState(() => _isSpeaking = true);
    ref.read(hapticServiceProvider).success();

    await _speakInBoardLanguage(text);
    // Saying it is what makes it worth remembering — a sentence the learner
    // only assembled and then cleared was never a phrase.
    await ref.read(boardPhrasesProvider.notifier).record(List.of(_sentence));

    // flutter_tts is fire-and-forget, so the "speaking" icon runs on an
    // estimate. Scale it by the learner's own speech rate, or a slow speaker
    // is shown as finished less than half way through.
    final speed = ref.read(settingsProvider).ttsSpeed.clamp(0.1, 2.0);
    final estimate = (600 + text.length * 40) * (0.5 / speed);
    await Future.delayed(Duration(milliseconds: estimate.round()));
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _speakSingleTile(BoardTile tile) async {
    ref.read(hapticServiceProvider).lightTap();
    await _speakInBoardLanguage(_useFilipino ? tile.labelFil : tile.label);
  }

  // ─── Saved phrases ───────────────────────────────

  /// Load a saved phrase back into the strip and say it.
  ///
  /// Loading *and* speaking in one tap is the whole point: the learner saved
  /// this phrase because they say it often, and making them tap the phrase and
  /// then the speak button doubles the cost of the thing being optimised.
  Future<void> _usePhrase(SavedPhrase phrase) async {
    final tiles = phrase.resolve(_vocabulary.byId);
    if (tiles.isEmpty) return;
    setState(() {
      _sentence
        ..clear()
        ..addAll(tiles.take(_presentation.maxSentenceLength));
    });
    await _speakSentence();
  }

  /// Pin (or unpin) whatever is in the strip right now.
  Future<void> _togglePinCurrent() async {
    if (_sentence.isEmpty) return;
    final notifier = ref.read(boardPhrasesProvider.notifier);
    final id = SavedPhrase.idFor(_sentence);
    final alreadyPinned = _currentIsPinned(ref.read(boardPhrasesProvider));

    ref.read(hapticServiceProvider).success();
    if (alreadyPinned) {
      await notifier.togglePinned(id);
      _announce('Phrase unpinned.');
      return;
    }
    // `savePinned`, not `record` + `togglePinned`: record deliberately refuses
    // a brand-new one-tile sentence, and going through it would have left the
    // learner with a "Phrase saved." that saved nothing.
    await notifier.savePinned(List.of(_sentence));
    _announce('Phrase saved.');
  }

  /// Open the builder for this profile's own board.
  ///
  /// Behind [requireAdult]: the builder can empty a non-verbal learner's
  /// vocabulary in two taps, and this button sits in the app bar of a screen
  /// they use all day. A learner who taps it by accident is turned away
  /// without comment — no scolding copy, nothing that reads as a telling-off.
  ///
  /// A drill-down `push`, not a `go`: the learner came from Talk Board and
  /// Back has to return them to it. The board rebuilds itself when the builder
  /// saves, because both read `customBoardProvider`.
  Future<void> _openBuilder() async {
    ref.read(hapticServiceProvider).lightTap();
    final allowed = await requireAdult(
      context,
      ref,
      reason: 'to change this board',
    );
    if (!allowed || !mounted) return;
    if (context.mounted) context.push('/communication-board/builder');
  }

  /// True when the current sentence is already pinned.
  bool _currentIsPinned(List<SavedPhrase> phrases) {
    if (_sentence.isEmpty) return false;
    final id = SavedPhrase.idFor(_sentence);
    return phrases.any((p) => p.id == id && p.pinned);
  }

  /// A short spoken + on-screen notice.
  ///
  /// Spoken as well as shown because a snackbar is invisible to half the
  /// learners this board exists for, and shown as well as spoken because it is
  /// inaudible to the other half.
  void _announce(String message, {bool warning = false}) {
    if (!mounted) return;
    _speakInBoardLanguage(message);
    if (warning) {
      AppSnackBar.warning(context, message: message);
    } else {
      AppSnackBar.success(context, message: message);
    }
  }

  // ─── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final vocabulary = ref.watch(boardVocabularyProvider);
    final presentation = vocabulary.presentation;
    final phrases = ref.watch(boardPhrasesProvider);

    // A profile switch, or an adult emptying the custom board, can retire the
    // tab we are sitting on; land somewhere real rather than on an empty grid.
    final activeCategory = vocabulary.resolveCategory(_activeCategory);
    final tiles = vocabulary.tilesFor(activeCategory);
    final tabs = vocabulary.categories;

    // Only show the moving gaze cursor when hands-free control is enabled.
    final gazeEnabled = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return GazeScope(
      actions: _gazeActions(),
      onBlink: _gazeNextCategory,
      child: Scaffold(
        backgroundColor: hc.background,
        appBar: AppBar(
          // Matches the "Talk Board" tile every entry point uses; the screen
          // used to be titled "Communication Board", so a learner arrived
          // somewhere apparently different from what they tapped.
          title: Text(
            'Talk Board',
            style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: const AppBackButton(),
          actions: [
            // Build / edit this profile's own board.
            Semantics(
              button: true,
              label: vocabulary.hasCustomTab
                  ? 'Edit my board'
                  : 'Build my board',
              child: Tooltip(
                message: vocabulary.hasCustomTab
                    ? 'Edit my board'
                    : 'Build my board',
                child: IconButton(
                  onPressed: _openBuilder,
                  icon: Icon(
                    Icons.dashboard_customize_rounded,
                    size: 22,
                    color: hc.primary,
                  ),
                ),
              ),
            ),
            // Language toggle
            Semantics(
              button: true,
              label: _useFilipino ? 'Switch to English' : 'Switch to Filipino',
              child: Tooltip(
                message: _useFilipino
                    ? 'Switch to English'
                    : 'Switch to Filipino',
                child: TextButton.icon(
                  onPressed: () => setState(() => _useFilipino = !_useFilipino),
                  icon: Icon(
                    Icons.translate_rounded,
                    size: 20,
                    color: hc.primary,
                  ),
                  label: Text(
                    _useFilipino ? 'FIL' : 'EN',
                    style: AppTypography.labelMedium.copyWith(
                      color: hc.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < kBoardCompactHeight;
            final showBanner = presentation.showSentenceBanner &&
                !compact &&
                _sentence.isNotEmpty;
            final showPhrases = phrases.isNotEmpty && !compact;

            return Column(
              children: [
                // ─── Large-type sentence banner ─────────
                if (showBanner)
                  _SentenceBanner(
                    sentence: _sentence,
                    useFilipino: _useFilipino,
                  ),

                // ─── Sentence Strip ─────────────────────
                _SentenceStrip(
                  sentence: _sentence,
                  useFilipino: _useFilipino,
                  isSpeaking: _isSpeaking,
                  isPinned: _currentIsPinned(phrases),
                  onSpeak: _speakSentence,
                  onRemoveLast: _removeLast,
                  onClear: _clearSentence,
                  onTogglePin: _togglePinCurrent,
                  onTapTile: _speakSingleTile,
                ),

                // ─── Saved & recent phrases ─────────────
                if (showPhrases)
                  _PhraseStrip(
                    phrases: phrases,
                    useFilipino: _useFilipino,
                    padding: padding,
                    lookup: vocabulary.byId,
                    onUse: _usePhrase,
                  ),

                const SizedBox(height: 8),

                // ─── Category Tabs ──────────────────────
                SizedBox(
                  height: 52 * textScale.clamp(1.0, 1.6),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    itemCount: tabs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = tabs[index];
                      return _CategoryChip(
                        category: cat,
                        // The custom tab is labelled with the board's own
                        // name, so the learner sees "Bahay ni Ana", not
                        // "Custom".
                        label: vocabulary.labelFor(
                          cat,
                          useFilipino: _useFilipino,
                        ),
                        isActive: cat == activeCategory,
                        onTap: () => _setCategory(cat),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ─── Tile Grid ──────────────────────────
                // Deliberately NOT wrapped in an AnimatedSwitcher.
                //
                // It used to be, for a 250 ms cross-fade between tabs, and it
                // kept the outgoing grid mounted for that whole window. Two
                // live grids produced two separate defects: index-keyed tiles
                // collided across them, and switching A→B→A faster than the
                // fade left two children carrying the *same* `ValueKey`, which
                // trips "Duplicate keys found" and then truncates the tree.
                // The tabs still animate — changing the key rebuilds the grid,
                // so each tile re-runs its own staggered entrance — and only
                // one grid is ever alive, which removes the whole class.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: GridView.builder(
                      key: ValueKey(activeCategory),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            presentation.columns(isTablet: context.isTablet),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: boardTileAspectRatio(textScale),
                      ),
                      itemCount: tiles.length,
                      itemBuilder: (context, index) {
                        final tile = tiles[index];
                        return _BoardTileWidget(
                          key: _tileKey(activeCategory, tile.id),
                          tile: tile,
                          useFilipino: _useFilipino,
                          highlighted: gazeEnabled && index == _cursorIndex,
                          onTap: () => _addTile(tile),
                          onLongPress: () => _speakSingleTile(tile),
                          delay: index * 40,
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Large-type sentence banner ─────────────────────────

/// The sentence again, in the largest type that fits.
///
/// For a Deaf learner this is the half of the exchange TTS cannot carry: the
/// listener reads what the learner is saying. It is deliberately text-only —
/// the emoji are already right below in the strip.
class _SentenceBanner extends StatelessWidget {
  final List<BoardTile> sentence;
  final bool useFilipino;

  const _SentenceBanner({required this.sentence, required this.useFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final text = sentence
        .map((t) => useFilipino ? t.labelFil : t.label)
        .join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hc.primary.withValues(alpha: 0.35), width: 2),
      ),
      // Excluded from the semantics tree: the strip below already announces
      // every tile, and a screen reader repeating the whole sentence here
      // would read it twice.
      child: ExcludeSemantics(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLarge.copyWith(
            color: hc.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Saved & recent phrase strip ────────────────────────

/// One row of the learner's pinned and recent sentences.
///
/// Each chip is a single large target that loads *and* speaks the phrase; the
/// star is an indicator, not a button, so there is nothing small to hit and
/// nothing for a gaze dwell to land on by mistake. Pinning happens on the
/// sentence strip instead.
class _PhraseStrip extends StatelessWidget {
  final List<SavedPhrase> phrases;
  final bool useFilipino;
  final double padding;

  /// The learner's full vocabulary, so a phrase containing their own words
  /// resolves rather than quietly losing them.
  final BoardTileLookup lookup;

  final ValueChanged<SavedPhrase> onUse;

  const _PhraseStrip({
    required this.phrases,
    required this.useFilipino,
    required this.padding,
    required this.lookup,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    // Resolve first: a phrase whose every tile is gone — a retired seed word
    // or a custom tile an adult deleted — renders as an empty chip, so drop it
    // rather than show a blank.
    final entries = <(SavedPhrase, List<BoardTile>)>[
      for (final p in phrases)
        if (p.resolve(lookup) case final tiles when tiles.isNotEmpty) (p, tiles),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 46 * textScale.clamp(1.0, 1.6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (phrase, tiles) = entries[index];
          final label = tiles
              .map((t) => useFilipino ? t.labelFil : t.label)
              .join(' ');

          return Semantics(
            button: true,
            label: '${phrase.pinned ? 'Saved phrase' : 'Recent phrase'}: '
                '$label. Tap to say it.',
            child: GestureDetector(
              onTap: () => onUse(phrase),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: phrase.pinned
                      ? AppColors.warning.withValues(alpha: 0.14)
                      : hc.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: phrase.pinned
                        ? AppColors.warning
                        : hc.border,
                    width: phrase.pinned ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phrase.pinned) ...[
                      const Icon(Icons.star_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tiles.take(3).map((t) => t.emoji).join(),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Sentence Strip ─────────────────────────────────────

class _SentenceStrip extends StatelessWidget {
  final List<BoardTile> sentence;
  final bool useFilipino;
  final bool isSpeaking;
  final bool isPinned;
  final VoidCallback onSpeak;
  final VoidCallback onRemoveLast;
  final VoidCallback onClear;
  final VoidCallback onTogglePin;
  final ValueChanged<BoardTile> onTapTile;

  const _SentenceStrip({
    required this.sentence,
    required this.useFilipino,
    required this.isSpeaking,
    required this.isPinned,
    required this.onSpeak,
    required this.onRemoveLast,
    required this.onClear,
    required this.onTogglePin,
    required this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tiles in sentence
          Expanded(
            child: sentence.isEmpty
                ? Center(
                    child: Text(
                      'Tap tiles below to build a sentence',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sentence.asMap().entries.map((entry) {
                        final tile = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Semantics(
                            label: useFilipino ? tile.labelFil : tile.label,
                            button: true,
                            child: GestureDetector(
                              onTap: () => onTapTile(tile),
                              child: Chip(
                                avatar: Text(
                                  tile.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                label: Text(
                                  useFilipino ? tile.labelFil : tile.label,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: hc.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: hc.surfaceVariant,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),

          // Action buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speak button
              Semantics(
                button: true,
                label: 'Speak sentence',
                child: _CircleButton(
                  icon: isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.play_circle_filled_rounded,
                  color: sentence.isEmpty ? Colors.grey : AppColors.success,
                  onTap: sentence.isEmpty ? null : onSpeak,
                  size: 44,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Save / pin this sentence
                  Semantics(
                    button: true,
                    label: isPinned
                        ? 'Remove this sentence from saved phrases'
                        : 'Save this sentence',
                    child: _CircleButton(
                      icon: isPinned
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.warning,
                      onTap: sentence.isEmpty ? null : onTogglePin,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Backspace
                  Semantics(
                    button: true,
                    label: 'Remove last tile',
                    child: _CircleButton(
                      icon: Icons.backspace_rounded,
                      color: AppColors.secondary,
                      onTap: sentence.isEmpty ? null : onRemoveLast,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Clear all tiles',
                    child: _CircleButton(
                      icon: Icons.delete_sweep_rounded,
                      color: AppColors.error,
                      onTap: sentence.isEmpty ? null : onClear,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Small circle icon button ───────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const _CircleButton({
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: AppColors.textOnPrimary, size: size * 0.55),
      ),
    );
  }
}

// ─── Category Filter Chip ───────────────────────────────

class _CategoryChip extends StatelessWidget {
  final BoardTileCategory category;

  /// Already resolved by `BoardVocabulary.labelFor` — the custom tab shows the
  /// board's own name, which no enum can supply.
  final String label;

  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Semantics(
      button: true,
      label: '$label category',
      selected: isActive,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? hc.primary : hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? hc.primary : hc.border,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: hc.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive ? AppColors.textOnPrimary : hc.textPrimary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Board Tile Widget ──────────────────────────────────

class _BoardTileWidget extends StatelessWidget {
  final BoardTile tile;
  final bool useFilipino;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int delay;

  /// True when the gaze cursor is on this tile — draws a bold highlight ring so
  /// the learner can see where a "look down / Add" will land.
  final bool highlighted;

  const _BoardTileWidget({
    super.key,
    required this.tile,
    required this.useFilipino,
    required this.onTap,
    required this.onLongPress,
    this.delay = 0,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    // A custom tile whose adult left the Filipino field blank falls back to the
    // English word, so announcing both would read it out twice.
    final spoken = tile.label == tile.labelFil
        ? tile.label
        : '${tile.label}. ${tile.labelFil}';

    return Semantics(
      button: true,
      label: '$spoken. Tap to add, long press to hear.',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child:
            AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? hc.primary.withValues(alpha: 0.12)
                        : hc.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: highlighted
                          ? hc.primary
                          : hc.primary.withValues(alpha: 0.2),
                      width: highlighted ? 3 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hc.primary.withValues(
                          alpha: highlighted ? 0.35 : 0.08,
                        ),
                        blurRadius: highlighted ? 16 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // `boardTileAspectRatio` gives the cell room to grow with the
                  // font scale; these Flexibles are the backstop that keeps the
                  // tile from overflowing at a scale nobody anticipated.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tile.emoji,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            useFilipino ? tile.labelFil : tile.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(
                  duration: 250.ms,
                  delay: Duration(milliseconds: delay),
                )
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 250.ms,
                  delay: Duration(milliseconds: delay),
                ),
      ),
    );
  }
}
