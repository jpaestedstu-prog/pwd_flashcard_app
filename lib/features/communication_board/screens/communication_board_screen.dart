import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../models/board_models.dart';
import '../models/board_seed_data.dart';
import '../../../widgets/app_back_button.dart';
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

/// AAC Communication Board — tap picture tiles to build sentences,
/// then press the speak button to hear them via TTS.
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

  /// Currently active category filter.
  BoardTileCategory _activeCategory = BoardTileCategory.greetings;

  /// Whether to display Filipino labels on tiles (false = English).
  bool _useFilipino = false;

  /// Whether the TTS is currently speaking.
  bool _isSpeaking = false;

  /// Gaze cursor: the index of the highlighted tile in the active category.
  /// Only visible / used when Gaze Control is enabled; touch ignores it.
  int _cursorIndex = 0;

  /// Stable keys per tile index so the gaze cursor can scroll itself into view.
  final Map<int, GlobalKey> _tileKeys = {};

  GlobalKey _tileKey(int index) => _tileKeys.putIfAbsent(index, GlobalKey.new);

  // ─── Gaze cursor navigation (hands-free) ─────────
  // The four head zones drive a moving highlight: left/right scrub the tiles,
  // up speaks the sentence, down adds the highlighted tile. A blink cycles to
  // the next category so a gaze-only learner can reach every word. Touch is
  // unaffected — this state is inert unless Gaze Control is on.

  void _moveCursor(int delta) {
    final count = BoardSeedData.forCategory(_activeCategory).length;
    setState(() => _cursorIndex = wrapBoardIndex(_cursorIndex + delta, count));
    _scrollCursorIntoView();
  }

  void _addCursorTile() {
    final tiles = BoardSeedData.forCategory(_activeCategory);
    if (_cursorIndex < 0 || _cursorIndex >= tiles.length) return;
    _addTile(tiles[_cursorIndex]);
  }

  void _gazeNextCategory() {
    const cats = BoardTileCategory.values;
    final next = cats[(cats.indexOf(_activeCategory) + 1) % cats.length];
    _setCategory(next);
  }

  void _setCategory(BoardTileCategory cat) {
    setState(() {
      _activeCategory = cat;
      _cursorIndex = 0;
    });
  }

  void _scrollCursorIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tileKeys[_cursorIndex]?.currentContext;
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
    final hasTiles = BoardSeedData.forCategory(_activeCategory).isNotEmpty;
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
    if (_sentence.length >= 12) return; // max sentence length
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _sentence.add(tile));
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

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty || _isSpeaking) return;

    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(settingsProvider);
    final text = _sentence
        .map((t) => _useFilipino ? t.labelFil : t.label)
        .join('. ');

    setState(() => _isSpeaking = true);
    ref.read(hapticServiceProvider).success();

    if (_useFilipino || settings.locale == 'fil') {
      await tts.speakFilipino(text);
    } else {
      await tts.speakEnglish(text);
    }

    // TTS is fire-and-forget; give a rough delay proportional to length
    await Future.delayed(Duration(milliseconds: 600 + text.length * 40));
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _speakSingleTile(BoardTile tile) async {
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(settingsProvider);
    final text = _useFilipino ? tile.labelFil : tile.label;

    ref.read(hapticServiceProvider).lightTap();

    if (_useFilipino || settings.locale == 'fil') {
      await tts.speakFilipino(text);
    } else {
      await tts.speakEnglish(text);
    }
  }

  // ─── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final tiles = BoardSeedData.forCategory(_activeCategory);
    // Only show the moving gaze cursor when hands-free control is enabled.
    final gazeEnabled = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled),
    );

    return GazeScope(
      actions: _gazeActions(),
      onBlink: _gazeNextCategory,
      child: Scaffold(
        backgroundColor: hc.background,
        appBar: AppBar(
          title: Text(
            'Communication Board',
            style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: const AppBackButton(),
          actions: [
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
        body: Column(
          children: [
            // ─── Sentence Strip ─────────────────────
            _SentenceStrip(
              sentence: _sentence,
              useFilipino: _useFilipino,
              isSpeaking: _isSpeaking,
              onSpeak: _speakSentence,
              onRemoveLast: _removeLast,
              onClear: _clearSentence,
              onTapTile: _speakSingleTile,
            ),

            const SizedBox(height: 8),

            // ─── Category Tabs ──────────────────────
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: padding),
                itemCount: BoardTileCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = BoardTileCategory.values[index];
                  final isActive = cat == _activeCategory;
                  return _CategoryChip(
                    category: cat,
                    isActive: isActive,
                    useFilipino: _useFilipino,
                    onTap: () => _setCategory(cat),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ─── Tile Grid ──────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: GridView.builder(
                    key: ValueKey(_activeCategory),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: context.isTablet ? 4 : 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (context, index) {
                      final tile = tiles[index];
                      return _BoardTileWidget(
                        key: _tileKey(index),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sentence Strip ─────────────────────────────────────

class _SentenceStrip extends StatelessWidget {
  final List<BoardTile> sentence;
  final bool useFilipino;
  final bool isSpeaking;
  final VoidCallback onSpeak;
  final VoidCallback onRemoveLast;
  final VoidCallback onClear;
  final ValueChanged<BoardTile> onTapTile;

  const _SentenceStrip({
    required this.sentence,
    required this.useFilipino,
    required this.isSpeaking,
    required this.onSpeak,
    required this.onRemoveLast,
    required this.onClear,
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
              // Backspace
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Remove last tile',
                    child: _CircleButton(
                      icon: Icons.backspace_rounded,
                      color: AppColors.warning,
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
  final bool isActive;
  final bool useFilipino;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isActive,
    required this.useFilipino,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Semantics(
      button: true,
      label: '${category.label} category',
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
                useFilipino ? category.labelFil : category.label,
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

    return Semantics(
      button: true,
      label: '${tile.label}. ${tile.labelFil}. Tap to add, long press to hear.',
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tile.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 6),
                      Padding(
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
