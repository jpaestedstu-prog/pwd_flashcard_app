import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_snack_bar.dart';
import '../data/deck_template_seed_data.dart';
import '../models/deck_template.dart';

/// Browse and clone pre-built flashcard deck templates into a learner's
/// custom deck. Educator/parent-facing — gated by the calling screen.
class DeckTemplatePickerScreen extends ConsumerStatefulWidget {
  const DeckTemplatePickerScreen({super.key});

  @override
  ConsumerState<DeckTemplatePickerScreen> createState() =>
      _DeckTemplatePickerScreenState();
}

class _DeckTemplatePickerScreenState
    extends ConsumerState<DeckTemplatePickerScreen> {
  final Set<String> _cloning = {};

  Future<void> _cloneTemplate(DeckTemplate template) async {
    if (_cloning.contains(template.id)) return;
    setState(() => _cloning.add(template.id));

    const uuid = Uuid();
    try {
      for (final stub in template.cards) {
        final card = stub.toFlashcard(
          id: '${template.id}_${uuid.v4()}',
          category: template.category,
        );
        await HiveService.saveCustomCard(card);
      }
      ref.invalidate(allFlashcardsProvider);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        message: 'Added ${template.cardCount} cards from ${template.name}',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: 'Could not add template');
    } finally {
      if (mounted) setState(() => _cloning.remove(template.id));
    }
  }

  void _previewTemplate(DeckTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) =>
          _TemplatePreviewSheet(template: template, onUseDeck: () {
        Navigator.pop(sheetContext);
        _cloneTemplate(template);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const templates = DeckTemplateSeedData.all;
    final padding = context.pagePadding;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Deck Templates'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pre-built decks for quick setup',
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Use this deck" to copy these bilingual cards into your custom deck.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.gridColumns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: (1.05 /
                          MediaQuery.textScalerOf(context).scale(1.0))
                      .clamp(0.75, 1.4),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final tmpl = templates[index];
                  return _TemplateCard(
                    template: tmpl,
                    isLoading: _cloning.contains(tmpl.id),
                    onPreview: () => _previewTemplate(tmpl),
                    onUseDeck: () => _cloneTemplate(tmpl),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: (80 * index).ms)
                      .slideY(begin: 0.08, end: 0);
                }, childCount: templates.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final DeckTemplate template;
  final bool isLoading;
  final VoidCallback onPreview;
  final VoidCallback onUseDeck;

  const _TemplateCard({
    required this.template,
    required this.isLoading,
    required this.onPreview,
    required this.onUseDeck,
  });

  @override
  Widget build(BuildContext context) {
    final dark = HSLColor.fromColor(template.color)
        .withLightness(
          (HSLColor.fromColor(template.color).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dark, template.color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(template.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${template.cardCount} cards',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  template.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: isLoading ? null : onPreview,
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Preview'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onUseDeck,
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: Text(isLoading ? 'Adding…' : 'Use deck'),
                      style: FilledButton.styleFrom(
                        backgroundColor: template.color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePreviewSheet extends StatelessWidget {
  final DeckTemplate template;
  final VoidCallback onUseDeck;

  const _TemplatePreviewSheet({
    required this.template,
    required this.onUseDeck,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: HCColor.of(context).border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(template.icon, color: template.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name, style: AppTypography.headlineSmall),
                      Text(
                        template.nameFil,
                        style: AppTypography.bodySmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${template.cardCount} cards',
                  style: AppTypography.labelMedium.copyWith(
                    color: HCColor.of(context).textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: template.cards.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final card = template.cards[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: template.color.withValues(alpha: 0.15),
                      foregroundColor: template.color,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(
                      card.wordEnglish,
                      style: AppTypography.titleMedium,
                    ),
                    subtitle: Text(
                      card.wordFilipino,
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onUseDeck,
              icon: const Icon(Icons.add_rounded),
              label: Text('Use this deck (${template.cardCount} cards)'),
              style: FilledButton.styleFrom(
                backgroundColor: template.color,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
