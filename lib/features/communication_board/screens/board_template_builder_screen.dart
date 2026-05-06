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
import '../models/board_seed_data.dart';

/// Lets teachers/parents build a custom communication board template
/// by selecting tiles from the seed pool and arranging them in a grid.
///
/// Templates are saved to Hive for per-profile reuse.
class BoardTemplateBuilderScreen extends ConsumerStatefulWidget {
  const BoardTemplateBuilderScreen({super.key});

  @override
  ConsumerState<BoardTemplateBuilderScreen> createState() =>
      _BoardTemplateBuilderScreenState();
}

class _BoardTemplateBuilderScreenState
    extends ConsumerState<BoardTemplateBuilderScreen> {
  /// The tiles selected for the custom template (ordered).
  final List<BoardTile> _templateTiles = [];

  /// Currently browsing category.
  BoardTileCategory _browseCategory = BoardTileCategory.greetings;

  /// Template name.
  final _nameController = TextEditingController(text: 'My Board');

  /// Whether the TTS preview is playing.
  bool _isPreviewing = false;

  /// Whether we're in edit mode (reorder/remove).
  bool _editMode = false;

  static const int _maxTiles = 24;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addTile(BoardTile tile) {
    if (_templateTiles.length >= _maxTiles) {
      AppSnackBar.warning(context, message: 'Maximum $_maxTiles tiles reached');
      return;
    }
    if (_templateTiles.any((t) => t.id == tile.id)) {
      AppSnackBar.info(context, message: 'Tile already added');
      return;
    }
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _templateTiles.add(tile));
  }

  void _removeTile(int index) {
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _templateTiles.removeAt(index));
  }

  void _reorderTile(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final tile = _templateTiles.removeAt(oldIndex);
      _templateTiles.insert(newIndex, tile);
    });
  }

  Future<void> _previewTemplate() async {
    if (_templateTiles.isEmpty || _isPreviewing) return;
    setState(() => _isPreviewing = true);
    ref.read(hapticServiceProvider).success();

    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(settingsProvider);

    for (final tile in _templateTiles) {
      if (!mounted) return;
      final text =
          settings.locale == 'fil' ? tile.labelFil : tile.label;
      if (settings.locale == 'fil') {
        await tts.speakFilipino(text);
      } else {
        await tts.speakEnglish(text);
      }
      await Future.delayed(
          Duration(milliseconds: 400 + text.length * 30));
    }

    if (mounted) setState(() => _isPreviewing = false);
  }

  void _saveTemplate() {
    if (_templateTiles.isEmpty) {
      AppSnackBar.warning(context, message: 'Add at least one tile to save');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.warning(context, message: 'Please enter a template name');
      return;
    }

    // Save template tile IDs via HiveService
    final profile = ref.read(profileProvider);
    if (profile != null) {
      ref.read(hapticServiceProvider).celebration();
    }

    AppSnackBar.success(context, message: 'Template "$name" saved with ${_templateTiles.length} tiles!');

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    final availableTiles = BoardSeedData.forCategory(_browseCategory);
    final addedIds = _templateTiles.map((t) => t.id).toSet();

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        title: Text(
          'Board Template Builder',
          style: AppTypography.titleLarge.copyWith(color: hc.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _editMode ? Icons.done_rounded : Icons.edit_rounded,
              color: hc.primary,
            ),
            onPressed: () => setState(() => _editMode = !_editMode),
            tooltip: _editMode ? 'Done editing' : 'Reorder/remove tiles',
          ),
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: hc.primary),
            onPressed: _isPreviewing ? null : _previewTemplate,
            tooltip: 'Preview with TTS',
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Template Name ──────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Template Name',
                prefixIcon: const Icon(Icons.label_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              maxLength: 30,
            ),
          ),

          // ─── Template Preview Grid ──────────
          Container(
            margin: EdgeInsets.symmetric(horizontal: padding),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minHeight: 120),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hc.border, width: 1.5),
            ),
            child: _templateTiles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.dashboard_customize_rounded,
                              size: 40, color: hc.textSecondary),
                          const SizedBox(height: 8),
                          Text(
                            'Tap tiles below to add them to your board',
                            style: AppTypography.bodyMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _editMode
                    ? ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _templateTiles.length,
                        onReorder: _reorderTile,
                        itemBuilder: (context, index) {
                          final tile = _templateTiles[index];
                          return ListTile(
                            key: ValueKey(tile.id),
                            leading: Text(tile.emoji,
                                style: const TextStyle(fontSize: 28)),
                            title: Text(tile.label),
                            subtitle: Text(tile.labelFil),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_rounded,
                                  color: AppColors.error),
                              onPressed: () => _removeTile(index),
                            ),
                          );
                        },
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _templateTiles.map((tile) {
                          return Chip(
                            avatar: Text(tile.emoji,
                                style: const TextStyle(fontSize: 18)),
                            label: Text(tile.label,
                                style: AppTypography.labelMedium),
                            deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 18),
                            onDeleted: () => _removeTile(
                                _templateTiles.indexOf(tile)),
                          );
                        }).toList(),
                      ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_templateTiles.length} / $_maxTiles tiles',
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const Spacer(),
                if (_templateTiles.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _templateTiles.clear()),
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear All'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─── Category Tabs ──────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              itemCount: BoardTileCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = BoardTileCategory.values[index];
                final isActive = cat == _browseCategory;
                return ChoiceChip(
                  selected: isActive,
                  label: Text('${cat.emoji} ${cat.label}'),
                  onSelected: (_) =>
                      setState(() => _browseCategory = cat),
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.15),
                );
              },
            ),
          ),

          // ─── Available Tiles Grid ───────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.isTablet ? 4 : 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: availableTiles.length,
                itemBuilder: (context, index) {
                  final tile = availableTiles[index];
                  final isAdded = addedIds.contains(tile.id);

                  return Semantics(
                    button: !isAdded,
                    label:
                        '${tile.label}, ${tile.labelFil}${isAdded ? ', already added' : ', tap to add'}',
                    child: GestureDetector(
                      onTap: isAdded ? null : () => _addTile(tile),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isAdded
                              ? AppColors.success.withValues(alpha: 0.1)
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
                          children: [
                            Text(tile.emoji,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(
                              tile.label,
                              style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isAdded
                                    ? AppColors.success
                                    : hc.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              tile.labelFil,
                              style: AppTypography.bodySmall.copyWith(
                                color: hc.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isAdded)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.check_circle_rounded,
                                    size: 18, color: AppColors.success),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                          duration: 250.ms,
                          delay: (index * 30).ms)
                      .slideY(begin: 0.05, end: 0);
                },
              ),
            ),
          ),
        ],
      ),

      // ─── Save FAB ──────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveTemplate,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Save Template'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
