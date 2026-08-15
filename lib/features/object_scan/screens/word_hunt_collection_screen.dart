import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart' show ttsServiceProvider;
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/achievements.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../navigation/nav_extensions.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/flashcard_image.dart';
import '../../../widgets/fullscreen_host.dart';
import '../../../widgets/rich_empty_states.dart';
import '../services/label_word_mapper.dart';
import '../services/object_scan_discovery_service.dart';
import '../widgets/discovered_word_sheet.dart';

/// "My Finds" — the payoff for Word Hunt: every word the learner has ever
/// photographed, grouped by category, next to the ones still out there.
///
/// Word Hunt has always *recorded* discoveries (they award stars and feed
/// Smart Review) but never showed them back, so a learner had no way to see
/// what they had collected or what was left to look for. This screen is that
/// collection, and doubles as the hunt's checklist: the "still to find" rows
/// are the target list.
///
/// The denominator is [LabelWordMapper.huntableCards] — the words the camera
/// is actually taught to recognise — not the whole vocabulary, which is full
/// of words no camera can see (Monday, Sorry, Proud).
class WordHuntCollectionScreen extends ConsumerStatefulWidget {
  const WordHuntCollectionScreen({super.key});

  @override
  ConsumerState<WordHuntCollectionScreen> createState() =>
      _WordHuntCollectionScreenState();
}

class _WordHuntCollectionScreenState
    extends ConsumerState<WordHuntCollectionScreen> {
  /// Rebuilt after a sheet closes so a word discovered elsewhere in the app
  /// (or a star claimed) is reflected without leaving the screen.
  Set<String> _discovered = const {};

  /// Populated once the FSL manifest has loaded, so found words can show the
  /// 🤟 badge that tells a Deaf learner a sign video exists.
  bool _fslReady = false;

  @override
  void initState() {
    super.initState();
    _discovered = ObjectScanDiscoveryService.discoveredWordIds(
      ref.read(profileProvider)?.id,
    );
    _loadFslBadges();
  }

  /// The 🤟 badges need the FSL manifest. If it cannot be read, the badges
  /// simply never appear — that is the right fallback, not an error.
  Future<void> _loadFslBadges() async {
    try {
      await FslAssetsService.load();
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _fslReady = true);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _discovered = ObjectScanDiscoveryService.discoveredWordIds(
        ref.read(profileProvider)?.id,
      );
    });
  }

  /// A found word re-opens the same sheet the camera shows, so every bridge
  /// out of a discovery (speak it, spell it, flashcard, FSL) is available on
  /// a revisit too. It is *not* logged as a new discovery — no star farming.
  Future<void> _openFound(Flashcard card) async {
    ref.read(hapticServiceProvider).lightTap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscoveredWordSheet(card: card),
    );
    _refresh();
  }

  /// "Start hunting" goes **back** to the camera rather than pushing a fresh
  /// one. Word Hunt is the route that opened this screen and it is still
  /// mounted underneath, holding the camera — pushing a second
  /// `ObjectScanScreen` would try to open a second session on the same lens
  /// and land on the "camera couldn't start" state.
  void _startHunting() => context.popOrGo('/object-scan');

  /// A not-yet-found word just says its name — enough to know what to look
  /// for, without handing over the reward for finding it.
  void _speakTarget(Flashcard card) {
    ref.read(hapticServiceProvider).lightTap();
    if (!ref.read(settingsProvider).ttsEnabled) return;
    ref.read(ttsServiceProvider).speakEnglish(card.wordEnglish);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    final profileId = ref.watch(profileProvider)?.id;
    final huntable = LabelWordMapper.huntableCards;

    // Words found before a vocabulary change may no longer be huntable; count
    // them anyway so the numerator can never exceed the denominator.
    final foundIds = _discovered;
    final total = {...LabelWordMapper.huntableCardIds, ...foundIds}.length;
    final found = foundIds.length;

    final byCategory = <FlashcardCategory, List<Flashcard>>{};
    for (final card in huntable) {
      byCategory.putIfAbsent(card.category, () => []).add(card);
    }
    // Categories the learner has already found something in float to the top,
    // most finds first: the collection is the reward, so it should not be
    // buried under a dozen sections of words they have never seen.
    int foundIn(List<Flashcard> cards) =>
        cards.where((c) => foundIds.contains(c.id)).length;
    final sections = byCategory.entries.toList()
      ..sort((a, b) {
        final byFound = foundIn(b.value).compareTo(foundIn(a.value));
        return byFound != 0 ? byFound : a.key.index.compareTo(b.key.index);
      });

    return Scaffold(
      backgroundColor: hc.background,
      appBar: fullscreenBar(
        ref,
        AppBar(
          leading: const AppBackButton(),
          title: Text(
            l10n.wordHuntCollectionTitle,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _ProgressHeader(
            found: found,
            total: total,
            starsToday: ObjectScanDiscoveryService.starsAwardedToday(profileId),
            findsToday: ObjectScanDiscoveryService.findsToday(profileId),
            huntStreak: ObjectScanDiscoveryService.huntStreak(profileId),
            onHunt: _startHunting,
          ),
          const SizedBox(height: 18),
          if (found == 0)
            // No action button here: the header's "Start hunting" is the same
            // call sitting directly above it, and two identical buttons a
            // thumb apart is exactly the kind of ambiguity this app's
            // learners do not need.
            RichEmptyState(
              emoji: '📷',
              title: l10n.wordHuntMyFinds,
              description: l10n.wordHuntCollectionEmpty,
              accentColor: AppColors.bannerWordHuntStart,
              compact: true,
            ),
          for (final entry in sections)
            _CategorySection(
              category: entry.key,
              cards: entry.value,
              foundIds: foundIds,
              fslReady: _fslReady,
              onFound: _openFound,
              onTarget: _speakTarget,
            ),
        ],
      ),
    );
  }
}

/// The "12 of 65" banner: the one number a collecting learner comes here for,
/// plus today's remaining camera stars so the daily cap is never a mystery.
class _ProgressHeader extends StatelessWidget {
  final int found;
  final int total;
  final int starsToday;
  final int findsToday;
  final int huntStreak;
  final VoidCallback onHunt;

  const _ProgressHeader({
    required this.found,
    required this.total,
    required this.starsToday,
    required this.findsToday,
    required this.huntStreak,
    required this.onHunt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final complete = total > 0 && found >= total;
    final nextMilestone = nextHuntMilestone(found);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bannerWordHuntStart, AppColors.bannerWordHuntEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.wordHuntFoundOf(found, total),
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : found / total,
              minHeight: 12,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            complete
                ? l10n.wordHuntAllFound
                : l10n.wordHuntStarsToday(
                    starsToday,
                    ObjectScanDiscoveryService.dailyStarCap,
                  ),
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          // Streak, today's tally and the next badge — the three things that
          // make coming back tomorrow worth it. A Wrap so they reflow instead
          // of overflowing at a large text scale.
          const SizedBox(height: 10),
          // A chip can be wider than the screen at a 2.0x text scale, and a
          // Wrap hands its children unbounded width — so cap each one to the
          // row and let the text ellipsize inside it.
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (huntStreak > 0)
                  _HeaderChip(
                    emoji: '🔥',
                    label: l10n.wordHuntStreakDays(huntStreak),
                    maxWidth: constraints.maxWidth,
                  ),
                if (findsToday > 0)
                  _HeaderChip(
                    emoji: '📸',
                    label: l10n.wordHuntFindsToday(findsToday),
                    maxWidth: constraints.maxWidth,
                  ),
                if (nextMilestone != null)
                  _HeaderChip(
                    emoji: nextMilestone.emoji,
                    label: l10n.wordHuntNextBadge(
                      nextMilestone.finds - found,
                      nextMilestone.title,
                    ),
                    maxWidth: constraints.maxWidth,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.bannerWordHuntEnd,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onHunt,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                l10n.wordHuntStartHunting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill in the progress header: emoji + one short phrase.
class _HeaderChip extends StatelessWidget {
  final String emoji;
  final String label;

  /// Widest the pill may get — the enclosing row, so a long phrase at a big
  /// text scale ellipsizes instead of overflowing.
  final double maxWidth;

  const _HeaderChip({
    required this.emoji,
    required this.label,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category: its found words first, then the ones still out there.
///
/// The "still to find" list is capped — sixty-odd unfound words listed in full
/// is a wall, not a checklist, and this app's learners are the last people who
/// should have to wade through one. The count below the cap says how many more
/// are out there.
class _CategorySection extends StatelessWidget {
  /// Most "still to find" words shown per category before the "+N more" line.
  static const int maxTargetsShown = 6;

  final FlashcardCategory category;
  final List<Flashcard> cards;
  final Set<String> foundIds;
  final bool fslReady;
  final void Function(Flashcard) onFound;
  final void Function(Flashcard) onTarget;

  const _CategorySection({
    required this.category,
    required this.cards,
    required this.foundIds,
    required this.fslReady,
    required this.onFound,
    required this.onTarget,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context)!;
    final found = [
      for (final c in cards)
        if (foundIds.contains(c.id)) c,
    ];
    final missing = [
      for (final c in cards)
        if (!foundIds.contains(c.id)) c,
    ];
    final color = hc.categoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 26, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.label,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${found.length}/${cards.length}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (found.isNotEmpty)
            _WordTileGrid(
              cards: found,
              accent: color,
              dimmed: false,
              fslReady: fslReady,
              onTap: onFound,
            ),
          if (missing.isNotEmpty) ...[
            if (found.isNotEmpty) const SizedBox(height: 12),
            Text(
              l10n.wordHuntStillToFind,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _WordTileGrid(
              cards: missing.take(maxTargetsShown).toList(),
              accent: color,
              dimmed: true,
              fslReady: fslReady,
              onTap: onTarget,
            ),
            if (missing.length > maxTargetsShown) ...[
              const SizedBox(height: 6),
              Text(
                '+${missing.length - maxTargetsShown} more',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Responsive tile grid. A [Wrap] rather than a GridView so a tile can grow
/// with the text scale instead of clipping — the whole page is one scrollable
/// [ListView], so nothing is ever hidden below the fold.
class _WordTileGrid extends StatelessWidget {
  final List<Flashcard> cards;
  final Color accent;
  final bool dimmed;
  final bool fslReady;
  final void Function(Flashcard) onTap;

  const _WordTileGrid({
    required this.cards,
    required this.accent,
    required this.dimmed,
    required this.fslReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on a phone, three once there is room — one column at a
        // big text scale, where two would truncate every word.
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = scale >= 1.6
            ? 1
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _WordTile(
                  card: card,
                  accent: accent,
                  dimmed: dimmed,
                  showFsl:
                      fslReady &&
                      !dimmed &&
                      FslAssetsService.hasAnyVideoSource(card),
                  onTap: () => onTap(card),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WordTile extends StatelessWidget {
  final Flashcard card;
  final Color accent;
  final bool dimmed;
  final bool showFsl;
  final VoidCallback onTap;

  const _WordTile({
    required this.card,
    required this.accent,
    required this.dimmed,
    required this.showFsl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label:
          '${card.wordEnglish}, ${card.wordFilipino}'
          '${dimmed ? '' : ', ${l10n.wordHuntFound}'}',
      child: Material(
        color: dimmed
            ? hc.surfaceVariant
            : Color.alphaBlend(accent.withValues(alpha: 0.18), hc.surface),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            // PWD-friendly tap target with room for two lines of large type.
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dimmed ? hc.border : accent,
                width: dimmed ? 1 : 2,
              ),
            ),
            child: Row(
              children: [
                Opacity(
                  // Not-yet-found words keep their picture but faded, so the
                  // list reads as a checklist rather than a locked vault.
                  opacity: dimmed ? 0.45 : 1,
                  child: FlashcardPicture(card: card, extent: 40),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.wordEnglish,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: dimmed ? hc.textSecondary : hc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        card.wordFilipino,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showFsl)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('🤟', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
