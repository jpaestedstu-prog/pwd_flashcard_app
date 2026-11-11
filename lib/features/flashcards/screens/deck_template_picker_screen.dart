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
import '../../../core/widgets/fit_text.dart';
import '../../../core/widgets/reflow_row.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../core/widgets/app_bar_title.dart';
import '../../../core/widgets/stagger_in.dart';

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
        message: _t(context).dtAdded(
          template.cardCount,
          template.nameOf(filipino: _fil(context)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: _t(context).dtFailed);
    } finally {
      if (mounted) setState(() => _cloning.remove(template.id));
    }
  }

  void _previewTemplate(DeckTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
    final columns = context.gridColumns;
    final cellWidth =
        (MediaQuery.sizeOf(context).width - 2 * padding - 16 * (columns - 1)) /
        columns;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: AppBarTitle(_t(context).dtTitle),
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
                      _t(context).dtHeading,
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(context).dtIntro,
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
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  // As tall as the tallest card's words need: see
                  // [_templateCardExtent]. The grid scrolls, so a taller
                  // row costs only scroll length.
                  mainAxisExtent: _templateCardExtent(
                    context,
                    templates,
                    cellWidth,
                  ),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final tmpl = templates[index];
                  return StaggerIn(
                    index: index,
                    step: const Duration(milliseconds: 80),
                    child: _TemplateCard(
                    template: tmpl,
                    isLoading: _cloning.contains(tmpl.id),
                    onPreview: () => _previewTemplate(tmpl),
                    onUseDeck: () => _cloneTemplate(tmpl),
                  ),
                    builder: (child, delay) => child.animate()
                      .fadeIn(duration: 350.ms, delay: delay)
                      .slideY(begin: 0.08, end: 0),
                  );
                }, childCount: templates.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How tall a template card has to be for every template's words at their
/// size, in a cell [cellWidth] wide.
///
/// The cards used a fixed width-to-height ratio, which tied their height to
/// their width: on a 7-inch tablet a two-column cell was too short for its
/// description, and the text was shrunk to 7 px to fit (8 Nov). Measured
/// instead, the tallest card sets the row height, and no card shrinks its
/// words.
double _templateCardExtent(
  BuildContext context,
  List<DeckTemplate> templates,
  double cellWidth,
) {
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final defaults = DefaultTextStyle.of(context).style;
  final filipino = _fil(context);
  double heightOf(String text, TextStyle style, double width, {int? maxLines}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: defaults.merge(style)),
      textDirection: direction,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: width < 1 ? 1 : width);
    final h = painter.height;
    painter.dispose();
    return h;
  }

  final t = _t(context);
  final theme = Theme.of(context);
  // The two buttons share a row, or stack: the card's ReflowRow decides, by
  // its own rule (the row is the card's width less 8 on each side).
  final rowWidth = cellWidth - 16;
  const gap = 12.0; // ReflowRow's spacing, across or down
  final stacked = ReflowRow.stacksAt(
    context,
    width: rowWidth,
    labels: [t.dtPreview, t.dtUseDeck],
    labelFontSize: 14,
    tilePadding: 72,
  );
  final buttonWidth = stacked ? rowWidth : (rowWidth - gap) / 2;
  // A button is its label's lines plus the theme's padding above and below,
  // and never under the theme's minimum: the filled button's label line and
  // its 18 above and below come to 58 at normal text, not 56.
  double buttonHeight(ButtonStyle? style, String label, TextStyle? text) {
    const states = <WidgetState>{};
    final padding = style?.padding?.resolve(states)?.resolve(direction) ??
        EdgeInsets.zero;
    final minimum = style?.minimumSize?.resolve(states)?.height ?? 0;
    final textStyle = text ?? style?.textStyle?.resolve(states);
    // 18 for the icon and 8 between it and the label.
    final lines = heightOf(
      label,
      textStyle ?? const TextStyle(),
      buttonWidth - padding.horizontal - 18 - 8,
    );
    final h = lines + padding.vertical;
    return h > minimum ? h : minimum;
  }

  final preview = buttonHeight(
    theme.textButtonTheme.style,
    t.dtPreview,
    theme.textTheme.labelLarge,
  );
  // While a deck is being added the same button says "Adding…".
  final use = buttonHeight(theme.filledButtonTheme.style, t.dtUseDeck, null);
  final adding = buttonHeight(theme.filledButtonTheme.style, t.dtAdding, null);
  final useDeck = use > adding ? use : adding;
  final buttons = 8 +
      (stacked
          ? preview + gap + useDeck
          : (preview > useDeck ? preview : useDeck));

  var tallest = 0.0;
  for (final template in templates) {
    final name = heightOf(
      template.nameOf(filipino: filipino),
      AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
      cellWidth - 32 - 44 - 12,
      maxLines: 2,
    );
    final count = heightOf(
      t.dtCards(template.cardCount),
      AppTypography.labelSmall,
      cellWidth - 32 - 44 - 12,
    );
    final header = 16 + (name + count < 44 ? 44 : name + count) + 12;
    final description = 12 +
        heightOf(
          template.descriptionOf(filipino: filipino),
          AppTypography.bodySmall,
          cellWidth - 32,
        ) +
        8;
    final total = header + description + buttons;
    if (total > tallest) tallest = total;
  }
  // A little room for rounding, and never shorter than the old cards were at
  // their size.
  return tallest + 4;
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
      child: Semantics(
        container: true,
        // Opens the template's preview: a screen reader says "button".
        // Here, inside the Card: a Card is a node of its own, so a role
        // put around it landed on the list instead.
        button: true,
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
                          // Two lines, shrinking first: one cut "Mga
                          // Pangunahing Salitang Filipino" short at the
                          // largest Font Size (30 Oct).
                          FitText(
                            template.nameOf(filipino: _fil(context)),
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _t(context).dtCards(template.cardCount),
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
                  child: FitText(
                    template.descriptionOf(filipino: _fil(context)),
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                // Stacks instead of squeezing. Two icon+label buttons sharing a
                // card this narrow leave each label about 44px, and "Preview"
                // needs roughly twice that at 2.0x — no font step can close that
                // gap, so the row reflows to a column and each button gets the
                // full width instead. The card scrolls, so the cost is height.
                child: ReflowRow(
                  labelFontSize: 14,
                  // What the label does *not* get: the 18px icon, its gap, and
                  // the button's own horizontal padding on both sides. Erring
                  // high on purpose — ReflowRow stacks when the estimate says
                  // the label will not fit, and a row that stacks a little too
                  // eagerly costs height on a screen that scrolls, while one
                  // that stacks too late shows a learner "Previe / w".
                  tilePadding: 72,
                  labels: [_t(context).dtPreview, _t(context).dtUseDeck],
                  children: [
                    TextButton.icon(
                      onPressed: isLoading ? null : onPreview,
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      // A button label measures intrinsics, so the style step
                      // rather than FitText. It only trims the last few pixels
                      // now that ReflowRow gives the label a full-width row.
                      label: Text(
                        _t(context).dtPreview,
                        style: fittedStyle(
                          context,
                          _t(context).dtPreview,
                          Theme.of(context).textTheme.labelLarge,
                          // "Preview" is seven characters and still does not fit
                          // half a button row at 2x, so the default
                          // eight-character trigger never fired for it.
                          longWord: 6,
                        ),
                      ),
                    ),
                    FilledButton.icon(
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
                      label: Text(isLoading ? _t(context).dtAdding : _t(context).dtUseDeck),
                      style: FilledButton.styleFrom(
                        backgroundColor: HCColor.of(context).fillFor(template.color),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                      Text(
                        template.nameOf(filipino: _fil(context)),
                        style: AppTypography.headlineSmall,
                      ),
                      // The other language underneath, as the cards show it.
                      Text(
                        template.nameOf(filipino: !_fil(context)),
                        style: AppTypography.bodySmall.copyWith(
                          color: HCColor.of(context).textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _t(context).dtCards(template.cardCount),
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
              label: Text(_t(context).dtUseThis(template.cardCount)),
              style: FilledButton.styleFrom(
                backgroundColor: HCColor.of(context).fillFor(template.color),
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

bool _fil(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fil';
