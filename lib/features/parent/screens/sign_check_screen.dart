import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../core/widgets/safe_scaffold.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_action_bar.dart';
import '../../../widgets/fsl_loading_overlay.dart';
import '../../../widgets/fsl_video_sheet.dart';

/// Where an educator checks a learner's "I can sign this" claims.
///
/// The learner's claim is self-report — there is no sign-recognition model in
/// this app, and for production practice there is no automatic grader that
/// could stand in for a human watching. That is not a gap to apologise for: a
/// teacher watching a Deaf learner sign and saying "yes, that's it" is the
/// actual assessment, and the app's job is to make it quick and to record it.
///
/// The pairing is what makes the data worth collecting. A claim on its own is
/// a belief; a claim plus a confirmation is a *calibration* measurement — how
/// well a learner's sense of their own production matches an expert's. The two
/// are stored separately and never overwrite each other, so the comparison
/// survives the learner changing their mind.
class SignCheckScreen extends ConsumerStatefulWidget {
  /// The learner being checked.
  final String learnerId;
  final String learnerName;

  const SignCheckScreen({
    super.key,
    required this.learnerId,
    required this.learnerName,
  });

  @override
  ConsumerState<SignCheckScreen> createState() => _SignCheckScreenState();
}

class _SignCheckScreenState extends ConsumerState<SignCheckScreen> {
  Map<String, SignMastery> _mastery = const {};
  Map<String, SignVerification> _verifications = const {};
  bool _isResolving = false;

  /// Hide words the educator has already ruled on, so a long list collapses to
  /// just the outstanding work.
  bool _pendingOnly = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _mastery = HiveService.fslMastery(widget.learnerId);
      _verifications = HiveService.fslVerifications(widget.learnerId);
    });
  }

  Future<void> _record(Flashcard card, SignVerification verdict) async {
    final educator = ref.read(profileProvider);
    if (educator == null) return;
    final current =
        _verifications[HiveService.fslWordKey(
          card.category.label,
          card.wordEnglish,
        )];
    await HiveService.setFslVerification(
      widget.learnerId,
      card.category.label,
      card.wordEnglish,
      // Tapping the standing verdict clears it back to unreviewed, so a
      // mis-tap on someone else's record is undoable.
      current == verdict ? SignVerification.unreviewed : verdict,
      verifierId: educator.id,
      verifierRole: educator.role.name,
    );
    if (mounted) _reload();
  }

  /// Plays the reference clip so the educator can check the learner against the
  /// same video the learner practised from.
  Future<void> _watch(Flashcard card) async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    final source = await FslAssetsService.videoSourceFor(card);
    if (!mounted) return;
    setState(() => _isResolving = false);
    if (source == null) {
      await showFslUnavailableSheet(
        context,
        wordEnglish: card.wordEnglish,
        unreachable: FslAssetsService.hasAnyVideoSource(card),
      );
      return;
    }
    if (!mounted) return;
    await showFslVideoSheet(
      context,
      videoSource: source,
      wordEnglish: card.wordEnglish,
      wordFilipino: card.wordFilipino,
      // No `onMasteryChanged`: the claim belongs to the learner. An educator
      // records a verdict, never edits what the learner said about themselves.
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    // Only words the learner has actually claimed. "Not yet" is deliberately
    // included — a learner working on a sign is exactly who a teacher should
    // spend a minute with, and hiding them would make this a victory-lap list.
    final claimed =
        SeedData.allFlashcards.where((c) {
          final m =
              _mastery[HiveService.fslWordKey(c.category.label, c.wordEnglish)];
          return m == SignMastery.canSign || m == SignMastery.learning;
        }).toList()..sort(
          (a, b) => a.wordEnglish.toLowerCase().compareTo(
            b.wordEnglish.toLowerCase(),
          ),
        );

    SignVerification verdictOf(Flashcard c) =>
        _verifications[HiveService.fslWordKey(
          c.category.label,
          c.wordEnglish,
        )] ??
        SignVerification.unreviewed;

    final visible = _pendingOnly
        ? claimed
              .where((c) => verdictOf(c) == SignVerification.unreviewed)
              .toList()
        : claimed;

    final confirmed = claimed
        .where((c) => verdictOf(c) == SignVerification.confirmed)
        .length;
    final pending = claimed
        .where((c) => verdictOf(c) == SignVerification.unreviewed)
        .length;

    return Stack(
      children: [
        SafeScaffold(
          appBar: AppBar(title: const Text('Sign Check')),
          // The body is already a ListView, so opt out of SafeScaffold's own
          // SingleChildScrollView — nesting the two gives the list unbounded
          // height and the Scaffold fails layout entirely, leaving a blank
          // screen under a working app bar. SafeScaffold still applies the
          // SafeArea, width cap and page padding.
          scrollable: false,
          body: ListView(
            padding: EdgeInsets.symmetric(vertical: context.pagePadding),
            children: [
              ProPanel(
                title: '${widget.learnerName}’s claims',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claimed.isEmpty
                          ? '${widget.learnerName} has not marked any signs yet. '
                                'Claims appear here after they use "I can sign '
                                'this" in the dictionary or finish a Sign It round.'
                          : 'Watch the reference clip, ask ${widget.learnerName} '
                                'to sign it, then record what you saw. Confirming '
                                'is what earns them the sign.',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                    if (claimed.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            label: '$confirmed confirmed',
                            color: hc.success,
                          ),
                          _Pill(label: '$pending to check', color: hc.warning),
                          _Pill(
                            label: '${claimed.length} claimed',
                            color: hc.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilterChip(
                        label: const Text('Only ones I haven’t checked'),
                        selected: _pendingOnly,
                        onSelected: (v) => setState(() => _pendingOnly = v),
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        labelStyle: _pendingOnly
                            ? const TextStyle(color: Colors.white)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty && claimed.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Nothing left to check. Nice work.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
                ),
              for (final card in visible)
                _ClaimRow(
                  card: card,
                  claim:
                      _mastery[HiveService.fslWordKey(
                        card.category.label,
                        card.wordEnglish,
                      )] ??
                      SignMastery.notSet,
                  verdict: verdictOf(card),
                  onWatch: () => _watch(card),
                  onConfirm: () => _record(card, SignVerification.confirmed),
                  onNeedsPractice: () =>
                      _record(card, SignVerification.notConfirmed),
                ),
            ],
          ),
        ),
        if (_isResolving) const FslLoadingOverlay(),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ClaimRow extends StatelessWidget {
  final Flashcard card;
  final SignMastery claim;
  final SignVerification verdict;
  final VoidCallback onWatch;
  final VoidCallback onConfirm;
  final VoidCallback onNeedsPractice;

  const _ClaimRow({
    required this.card,
    required this.claim,
    required this.verdict,
    required this.onWatch,
    required this.onConfirm,
    required this.onNeedsPractice,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ProPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  card.category.icon,
                  color: card.category.color,
                  size: context.scaleIcon(20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.wordEnglish,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        // The learner's own words, quoted back — the educator
                        // is ruling on a specific claim, not grading in general.
                        claim == SignMastery.canSign
                            ? 'Says: “I can sign this”'
                            : 'Says: “Not yet”',
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_circle_rounded),
                  tooltip: 'Watch the reference sign',
                  color: AppColors.secondaryDark,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppActionBar(
              equalWidth: true,
              children: [
                verdict == SignVerification.notConfirmed
                    ? FilledButton.icon(
                        onPressed: onNeedsPractice,
                        style: FilledButton.styleFrom(
                          backgroundColor: hc.warning,
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Needs practice'),
                      )
                    : OutlinedButton.icon(
                        onPressed: onNeedsPractice,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Needs practice'),
                      ),
                verdict == SignVerification.confirmed
                    ? FilledButton.icon(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: hc.success,
                        ),
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Confirmed'),
                      )
                    : OutlinedButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Confirm'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
