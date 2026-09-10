import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/shop_data.dart';
import '../l10n/app_localizations.dart';
import '../core/widgets/fit_text.dart';
import 'shop_badge.dart';

/// A visual theme preview card for the shop's Themes tab.
///
/// Shows a miniature mockup of the app using the theme's actual colors:
/// a mini "app bar", category cards, and color swatches so students can
/// see what the theme looks like before purchasing or equipping.
class ThemePreviewCard extends StatefulWidget {
  final ShopItem item;

  /// Whether to show the item's Filipino name. Defaults to English so a call
  /// site that has not been localised yet degrades to readable text.
  final bool isFilipino;

  /// What the learner's own settings mean for this theme, already worded —
  /// null when there is nothing to say.
  ///
  /// Carried as the sentence rather than as a bool so the screen reader gets
  /// it too. The card used to draw an info marker a sighted learner could
  /// hover and say nothing at all out loud, which left the learners most
  /// likely to have High Contrast on as the ones least likely to be told it
  /// overrides what they are about to buy.
  final String? adviceLine;

  final bool owned;

  /// How many stars short of this theme the learner is, 0 once they can pay.
  final int starsShort;
  final bool isEquipped;
  final VoidCallback onTap;

  bool get canAfford => starsShort <= 0;

  const ThemePreviewCard({
    super.key,
    required this.item,
    this.isFilipino = false,
    this.adviceLine,
    required this.owned,
    required this.starsShort,
    required this.isEquipped,
    required this.onTap,
  });

  /// The theme's signature colours, most distinctive first.
  ///
  /// Public so the Star Shop's buy dialog can show what a theme is *made of*
  /// without rebuilding this whole card inside a dialog. The palettes live
  /// here because this is the widget that draws them.
  static List<Color> swatchesFor(String id) {
    final p = _ThemePreviewCardState._paletteFor(id);
    return [p.primary, p.secondary, p.accent, p.primaryLight];
  }

  @override
  State<ThemePreviewCard> createState() => _ThemePreviewCardState();
}

class _ThemePreviewCardState extends State<ThemePreviewCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.95);
  void _onTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  /// Resolve the theme's palette from its ID.
  static _ThemePalette _paletteFor(String id) {
    return switch (id) {
      'theme_ocean' => const _ThemePalette(
          primary: Color(0xFF0288D1),
          primaryLight: Color(0xFFB3E5FC),
          secondary: Color(0xFF00838F),
          accent: Color(0xFF4DD0E1),
          background: Color(0xFFF0F9FF),
          surface: Color(0xFFFFFFFF),
          card: Color(0xFFF5FBFF),
        ),
      'theme_sunset' => const _ThemePalette(
          primary: Color(0xFFE65100),
          primaryLight: Color(0xFFFFCC80),
          secondary: Color(0xFFD81B60),
          accent: Color(0xFFFF7043),
          background: Color(0xFFFFF8F0),
          surface: Color(0xFFFFFFFF),
          card: Color(0xFFFFF5EE),
        ),
      'theme_forest' => const _ThemePalette(
          primary: Color(0xFF2E7D32),
          primaryLight: Color(0xFFA5D6A7),
          secondary: Color(0xFF5D4037),
          accent: Color(0xFF66BB6A),
          background: Color(0xFFF1F8E9),
          surface: Color(0xFFFFFFFF),
          card: Color(0xFFF5FBF2),
        ),
      'theme_galaxy' => const _ThemePalette(
          primary: Color(0xFF5C6BC0),
          primaryLight: Color(0xFFC5CAE9),
          secondary: Color(0xFF7B1FA2),
          accent: Color(0xFFAB47BC),
          background: Color(0xFFF5F0FF),
          surface: Color(0xFFFFFFFF),
          card: Color(0xFFF8F5FF),
        ),
      _ => const _ThemePalette(
          primary: AppColors.primary,
          primaryLight: AppColors.primaryLight,
          secondary: AppColors.secondary,
          accent: AppColors.accent,
          background: AppColors.background,
          surface: AppColors.surface,
          card: AppColors.cardBackground,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(widget.item.id);
    final l10n = AppLocalizations.of(context)!;

    final price = '${widget.item.cost} ${l10n.stars}';
    final status = widget.isEquipped
        ? l10n.equipped
        : widget.owned
            ? l10n.tapToEquip
            : widget.canAfford
                ? price
                : '$price, ${l10n.starsToGo(widget.starsShort)}';

    return Semantics(
      button: true,
      label: '${widget.item.localizedName(widget.isFilipino)}, '
          '${widget.item.localizedDescription(widget.isFilipino)}, $status'
          '${widget.adviceLine == null ? "" : ". ${widget.adviceLine}"}',
      // A bare GestureDetector is invisible to Flutter's focus traversal, which
      // is how gaze and a D-pad reach controls on a route that publishes no
      // gaze grid — the Star Shop included. Every other shelf is built from
      // InkWells and was reachable; Themes was the one tab a hands-free
      // learner could open and then do nothing on. Same fix as the game
      // pickers: FocusableActionDetector supplies the focus node and the
      // ActivateIntent handling, and changes nothing visually.
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Card(
            elevation: widget.isEquipped ? 6 : 3,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: widget.isEquipped
                    ? palette.primary
                    : widget.owned
                        ? AppColors.success
                        : widget.canAfford
                            ? widget.item.color.withValues(alpha: 0.5)
                            : AppColors.border,
                width: widget.isEquipped ? 2.5 : widget.owned ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // ── Mini app preview ──
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _MiniAppPreview(palette: palette)),
                      if (widget.adviceLine case final advice?)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Tooltip(
                            message: advice,
                            child: const Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.info),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Info footer ──
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: AppColors.surface,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Emoji + Name. The row is Flexible so a long name at a
                        // large font scale wraps inside the footer instead of
                        // pushing the price chip past the card's edge, and gets
                        // two lines before it resorts to an ellipsis — "Ocean
                        // Theme" truncated to "Ocea…" exactly for the learners
                        // who chose the biggest font.
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(widget.item.emoji,
                                  style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Flexible(
                                // Item names split as "Flamin / go" beside the
                                // emoji at a large text scale.
                                child: FitText(
                                  widget.item.localizedName(widget.isFilipino),
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: widget.isEquipped
                                        ? palette.primary
                                        : widget.owned
                                            ? AppColors.success
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Status / Price badge. The same pill the item
                        // shelves wear, tinted to the theme being previewed.
                        if (widget.isEquipped)
                          ShopBadge.equipped(context, color: palette.primary)
                        else if (widget.owned)
                          ShopBadge.owned(context)
                        else
                          ShopBadge.price(
                            context,
                            cost: widget.item.cost,
                            canAfford: widget.canAfford,
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
      ),
    );
  }
}

// ─── Mini App Preview ─────────────────────────────────

class _MiniAppPreview extends StatelessWidget {
  final _ThemePalette palette;

  const _MiniAppPreview({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.background,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Mini app bar
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Mini card rows
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    color: palette.primary,
                    lightColor: palette.primaryLight,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _MiniCard(
                    color: palette.secondary,
                    lightColor: palette.accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Mini button + progress bar
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Color swatch strip
          Row(
            children: [
              _Swatch(color: palette.primary),
              _Swatch(color: palette.secondary),
              _Swatch(color: palette.accent),
              _Swatch(color: palette.primaryLight),
              _Swatch(color: palette.background),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final Color color;
  final Color lightColor;

  const _MiniCard({required this.color, required this.lightColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, lightColor],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 4,
            width: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;

  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}


// ─── Theme Palette Data ───────────────────────────────

class _ThemePalette {
  final Color primary;
  final Color primaryLight;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;

  const _ThemePalette({
    required this.primary,
    required this.primaryLight,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
  });
}

