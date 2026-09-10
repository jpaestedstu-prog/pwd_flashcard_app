import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/sound_pack.dart';
import '../../../core/accessibility/sound_service.dart';
import '../../../core/services/celebration_style.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/shop_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/celebration_confetti.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/theme_preview_card.dart';

/// Shows what a shop item actually *is*, before any stars change hands.
///
/// The buy dialog used to show the item's emoji at 56 px and nothing else,
/// which is fine for an avatar (the emoji is the product) and useless for
/// everything else: a rainbow emoji does not tell you what the Rainbow border
/// looks like around your own face, a firework emoji does not tell you how
/// Fireworks moves, and a gamepad emoji tells a learner nothing at all about
/// what the Chiptune pack sounds like. Those are 20-35 star purchases made
/// blind.
///
/// So each type previews itself in its own terms — a border is drawn on the
/// learner's own avatar, a title is drawn as the badge it becomes, an effect
/// is *played*, and a pack is *heard*.
class ShopItemPreview extends ConsumerStatefulWidget {
  const ShopItemPreview({
    super.key,
    required this.item,
    required this.isFilipino,
  });

  final ShopItem item;
  final bool isFilipino;

  @override
  ConsumerState<ShopItemPreview> createState() => _ShopItemPreviewState();
}

class _ShopItemPreviewState extends ConsumerState<ShopItemPreview> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );

  /// Cancelled on dispose: the preview plays two sounds a beat apart, and the
  /// learner can close the dialog between them.
  Timer? _secondNote;

  @override
  void dispose() {
    _confetti.dispose();
    _secondNote?.cancel();
    super.dispose();
  }

  /// The style this learner would actually get, reduced motion included —
  /// previewing a burst the app would never fire would be a lie.
  CelebrationStyle get _previewStyle {
    final style = CelebrationStyle.forItemId(widget.item.id);
    return ref.read(settingsProvider).reducedMotion ? style.calmed() : style;
  }

  /// Two effects a beat apart — one pack sound is not enough to tell Nature
  /// from Space, and "correct then star" is the pair a learner hears most.
  void _playPack(SoundPack pack) {
    final sound = ref.read(soundServiceProvider);
    sound.play(SoundEffect.correct, pack: pack);
    _secondNote?.cancel();
    _secondNote = Timer(
      const Duration(milliseconds: 420),
      () => sound.play(SoundEffect.starEarned, pack: pack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.item.localizedName(widget.isFilipino);

    return Semantics(
      container: true,
      label: l10n.previewOf(name),
      child: switch (widget.item.type) {
        ShopItemType.avatar => _avatar(equippedAvatarId: widget.item.id),
        ShopItemType.border => _avatar(equippedBorderId: widget.item.id),
        ShopItemType.title => _title(name),
        ShopItemType.theme => _theme(),
        ShopItemType.celebration => _celebration(l10n),
        ShopItemType.soundPack => _soundPack(l10n),
      },
    );
  }

  /// The learner's own face, wearing the thing they are looking at — with
  /// whatever they already have equipped filling the other slot, so the
  /// preview is the combination they will actually see.
  Widget _avatar({String? equippedAvatarId, String? equippedBorderId}) {
    final progress = ref.read(progressProvider.notifier);
    return CosmeticAvatar(
      avatarIndex: ref.read(profileProvider)?.avatarIndex ?? 0,
      equippedAvatarId:
          equippedAvatarId ?? progress.getEquippedItemId(ShopItemType.avatar),
      equippedBorderId:
          equippedBorderId ?? progress.getEquippedItemId(ShopItemType.border),
      radius: 36,
    );
  }

  /// The badge the title becomes on the dashboard and the leaderboard, drawn
  /// the same way both of those draw it.
  Widget _title(String name) {
    final hc = HCColor.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item.emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: hc.primary.withValues(alpha: hc.isDark ? 0.24 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hc.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            name,
            style: AppTypography.labelMedium.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _theme() => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final color in ThemePreviewCard.swatchesFor(widget.item.id))
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: HCColor.of(context).border),
              ),
            ),
        ],
      );

  Widget _celebration(AppLocalizations l10n) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sized in both directions, and that is load-bearing in two ways.
          // The box holds only the emoji and the particles — no text — so a
          // fixed height is safe at every font size. And AlertDialog measures
          // its content with intrinsics, which a Stack passes down to
          // ConfettiWidget's LayoutBuilder — an assertion, not a warning, that
          // took the whole dialog down. A tight width answers the intrinsic
          // query without asking the children anything.
          SizedBox(
            width: 200,
            height: 92,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Center(
                  child: Text(
                    widget.item.emoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                CelebrationConfetti(
                  controller: _confetti,
                  style: _previewStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _confetti.play,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(l10n.seeIt),
          ),
        ],
      );

  Widget _soundPack(AppLocalizations l10n) {
    final pack = SoundPack.forItemId(widget.item.id);
    // Sound Effects off silences every pack. The button says so by going flat
    // rather than playing nothing and leaving the learner to guess; the
    // dialog's advice line spells out why.
    final audible = ref.watch(settingsProvider).soundEffects;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.item.emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: audible ? () => _playPack(pack) : null,
          icon: Icon(
            audible ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            size: 20,
          ),
          label: Text(l10n.hearIt),
        ),
      ],
    );
  }
}
